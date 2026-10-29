"""Gera assets/catalog/catalogo.sqlite a partir do Open Food Facts (ADR 0024).

Uso, da raiz do repositório:

    py -3 tool/catalogo/gerar.py                 # baixa os dumps e gera
    py -3 tool/catalogo/gerar.py --sem-baixar    # gera de novo do recorte já baixado

Duas etapas, só com a biblioteca padrão do Python:

1. Baixar. Lê os dumps noturnos dos três projetos enquanto baixa, sem gravar
   o dump inteiro, e guarda na pasta de cache (padrão: tool/catalogo/cache,
   fora do git) só os produtos brasileiros, com os campos que o app usa:
   - Open Food Facts (alimentos): o CSV, cerca de 1,5 GB comprimido. O JSONL
     e o Parquet são bem maiores, e ler o Parquet remoto por partes pede
     dezenas de milhares de requisições.
   - Open Beauty Facts (higiene) e Open Products Facts (limpeza): o JSONL,
     cerca de 100 MB e 40 MB, que sai toda noite e traz o nome em português.
2. Gerar. Lê o cache, aplica as regras de catalogo.py e grava o SQLite no
   formato combinado com o leitor do app (user_version 1).

Só arquivos estáticos, sem a API: o Open Food Facts pede o dump para quem
precisa de mais que algumas centenas de produtos, e o User-Agent próprio só
para a API. Por isso as requisições daqui não mandam identificação do app.
"""
import argparse
import csv
import datetime
import gzip
import io
import json
import os
import sqlite3
import sys
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import catalogo  # noqa: E402

DUMPS = {
    "off": "https://static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv.gz",
    "obf": "https://static.openbeautyfacts.org/data/openbeautyfacts-products.jsonl.gz",
    "opf": "https://static.openproductsfacts.org/data/openproductsfacts-products.jsonl.gz",
}

# A ordem decide o código repetido em duas bases: fica o da primeira.
FONTES = ["off", "obf", "opf"]

CAMPOS = [
    "code", "product_name_pt", "product_name", "brands", "quantity", "product_quantity",
    "product_quantity_unit", "categories_tags",
]

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(os.path.dirname(AQUI))
CACHE_PADRAO = os.path.join(AQUI, "cache")
SAIDA_PADRAO = os.path.join(RAIZ, "assets", "catalog", "catalogo.sqlite")

LICENSE = "ODbL 1.0"
ATTRIBUTION = "Contém informações do Open Food Facts, disponíveis sob a ODbL"


def _lista(valor):
    """As tags do CSV vêm numa string separada por vírgula; as do JSONL, numa lista."""
    if isinstance(valor, list):
        return valor
    return [t for t in (valor or "").split(",") if t]


def _produtos_csv(resposta):
    csv.field_size_limit(1 << 30)
    texto = io.TextIOWrapper(gzip.GzipFile(fileobj=resposta), encoding="utf-8", newline="")
    linhas = csv.reader(texto, delimiter="\t", quoting=csv.QUOTE_NONE)
    cabecalho = next(linhas)
    for valores in linhas:
        yield dict(zip(cabecalho, valores))


def _produtos_jsonl(resposta):
    texto = io.TextIOWrapper(gzip.GzipFile(fileobj=resposta), encoding="utf-8")
    for linha in texto:
        yield json.loads(linha)


def baixar(cache, fontes):
    os.makedirs(cache, exist_ok=True)
    caminho_datas = os.path.join(cache, "datas.json")
    datas = {}
    if os.path.exists(caminho_datas):
        with open(caminho_datas, encoding="utf-8") as arquivo:
            datas = json.load(arquivo)
    for fonte in FONTES:
        if fonte not in fontes:
            continue
        url = DUMPS[fonte]
        print(f"{fonte}: lendo {url}", flush=True)
        ler = _produtos_csv if url.endswith(".csv.gz") else _produtos_jsonl
        destino = os.path.join(cache, f"{fonte}.jsonl.gz")
        total = brasileiros = 0
        with urllib.request.urlopen(url) as resposta, gzip.open(destino + ".tmp", "wt", encoding="utf-8") as saida:
            for produto in ler(resposta):
                total += 1
                if str(produto.get("obsolete") or "").lower() in ("1", "true", "on"):
                    continue
                if not catalogo.eh_brasileiro(produto.get("code"), _lista(produto.get("countries_tags"))):
                    continue
                brasileiros += 1
                item = {campo: produto.get(campo) for campo in CAMPOS}
                item["categories_tags"] = _lista(item["categories_tags"])
                saida.write(json.dumps(item, ensure_ascii=False) + "\n")
        os.replace(destino + ".tmp", destino)
        print(f"{fonte}: {brasileiros} brasileiros de {total}", flush=True)
        datas[fonte] = datetime.date.today().isoformat()
        with open(caminho_datas, "w", encoding="utf-8") as arquivo:
            json.dump(datas, arquivo)


def ler_cache(caminho, fonte):
    with gzip.open(caminho, "rt", encoding="utf-8") as arquivo:
        for texto in arquivo:
            p = json.loads(texto)
            yield catalogo.linha(
                fonte,
                p["code"],
                catalogo.nome(p["product_name_pt"], p["product_name"]),
                p["brands"],
                p["quantity"],
                p["product_quantity"],
                p["product_quantity_unit"],
                p["categories_tags"],
            )


def gerar(cache, saida, fontes):
    with open(os.path.join(cache, "datas.json"), encoding="utf-8") as arquivo:
        datas = json.load(arquivo)
    linhas = {}
    contagem = {}
    for fonte in FONTES:
        if fonte not in fontes:
            continue
        contagem[fonte] = 0
        for item in ler_cache(os.path.join(cache, f"{fonte}.jsonl.gz"), fonte):
            if item and item["barcode"] not in linhas:
                linhas[item["barcode"]] = item
                contagem[fonte] += 1

    os.makedirs(os.path.dirname(saida), exist_ok=True)
    if os.path.exists(saida):
        os.remove(saida)
    db = sqlite3.connect(saida)
    db.executescript(
        """
        CREATE TABLE catalog_packages (barcode TEXT PRIMARY KEY, name TEXT NOT NULL, brand TEXT,
          quantity TEXT, size_value REAL, size_unit TEXT, kind TEXT, source TEXT NOT NULL) WITHOUT ROWID;
        CREATE TABLE catalog_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
        """
    )
    colunas = ["barcode", "name", "brand", "quantity", "size_value", "size_unit", "kind", "source"]
    db.executemany(
        f"INSERT INTO catalog_packages VALUES ({', '.join('?' * len(colunas))})",
        ([linhas[c][k] for k in colunas] for c in sorted(linhas)),
    )
    meta = {
        "generated_at": datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat(),
        "sources": ",".join(f"{f}:{datas[f]}" for f in FONTES if f in contagem),
        "license": LICENSE,
        "attribution": ATTRIBUTION,
        "count": str(len(linhas)),
    }
    db.executemany("INSERT INTO catalog_meta VALUES (?, ?)", meta.items())
    db.execute("PRAGMA user_version = 1")
    db.commit()
    db.execute("VACUUM")
    db.close()
    tamanho = os.path.getsize(saida)
    print(f"{saida}: {len(linhas)} produtos, {tamanho / 1e6:.2f} MB")
    for fonte, n in contagem.items():
        print(f"  {fonte}: {n}")
    return contagem, tamanho


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--cache", default=CACHE_PADRAO, help="pasta do recorte baixado")
    parser.add_argument("--saida", default=SAIDA_PADRAO, help="arquivo SQLite gerado")
    parser.add_argument("--sem-baixar", action="store_true", help="usa o recorte já baixado")
    parser.add_argument("--fontes", default=",".join(FONTES), help="fontes a incluir (padrão: off,obf,opf)")
    args = parser.parse_args()
    fontes = set(args.fontes.split(","))
    if not args.sem_baixar:
        baixar(args.cache, fontes)
    gerar(args.cache, args.saida, fontes)


if __name__ == "__main__":
    main()
