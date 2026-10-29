"""Mede quantos códigos de uma lista o catálogo acha.

A lista é um CSV com uma coluna `gtin` (e, se quiser, `descricao`): por
exemplo, os códigos dos cupons fiscais (NFC-e) do mantenedor. Não acessa a
rede.

Uso, da raiz do repositório:

    py -3 tool/catalogo/cobertura.py codigos.csv
    py -3 tool/catalogo/cobertura.py codigos.csv --catalogo outro.sqlite
"""
import argparse
import csv
import os
import sqlite3
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from catalogo import codigo  # noqa: E402
from gerar import SAIDA_PADRAO  # noqa: E402


def medir(lista_csv, catalogo_sqlite):
    with open(lista_csv, encoding="utf-8") as arquivo:
        lista = list(csv.DictReader(arquivo))
    # O cupom às vezes traz o código com zero à esquerda ("07896...", que
    # `codigo` reduz ao EAN-13) ou sem código válido; conta só os válidos.
    amostra = []
    for item in lista:
        code = codigo(item.get("gtin") or "")
        if code:
            amostra.append((code, item.get("descricao", "")))
    db = sqlite3.connect(f"file:{catalogo_sqlite}?mode=ro", uri=True)
    achados = com_tamanho = com_marca = com_tipo = 0
    fontes = {}
    faltam = []
    for code, descricao in amostra:
        row = db.execute(
            "SELECT brand, size_value, kind, source FROM catalog_packages WHERE barcode = ?", (code,)
        ).fetchone()
        if row is None:
            faltam.append((code, descricao))
            continue
        achados += 1
        com_marca += row[0] is not None
        com_tamanho += row[1] is not None
        com_tipo += row[2] is not None
        fontes[row[3]] = fontes.get(row[3], 0) + 1
    total = len(amostra)
    if total == 0:
        print("nenhum código válido na lista")
        return

    def pct(n):
        return f"{n}/{total} ({100 * n / total:.0f}%)"

    print(f"códigos válidos na lista: {total} (de {len(lista)} linhas)")
    print(f"achados no catálogo: {pct(achados)}  {fontes}")
    print(f"  com marca: {pct(com_marca)}")
    print(f"  com tamanho: {pct(com_tamanho)}")
    print(f"  com tipo: {pct(com_tipo)}")
    print("não achados:")
    for code, descricao in faltam:
        print(f"  {code}  {descricao}")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("lista", help="CSV com a coluna gtin")
    parser.add_argument("--catalogo", default=SAIDA_PADRAO, help="arquivo SQLite do catálogo")
    args = parser.parse_args()
    medir(args.lista, args.catalogo)


if __name__ == "__main__":
    main()
