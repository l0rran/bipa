# Gerador do catálogo de produtos

Gera `assets/catalog/catalogo.sqlite`, o catálogo só de leitura que vai no APK (ADR 0024): os produtos vendidos no Brasil do Open Food Facts, do Open Beauty Facts e do Open Products Facts, com nome, marca, tamanho e categoria. O arquivo sai sob a ODbL; o aviso fica em `assets/catalog/LICENSE-ODbL.txt` e na tabela `catalog_meta`.

| Arquivo | Para quê |
| --- | --- |
| `gerar.py` | Baixa os dumps, guarda o recorte brasileiro no cache e gera o SQLite. |
| `catalogo.py` | As regras: código válido, nome, marca, tamanho e unidade, tipo de produto. |
| `categorias.py` | A tabela de `categories_tags` do Open Food Facts para o `ProductKind` do app. |
| `testes.py` | Confere as regras, sem rede e sem dependências. |
| `cobertura.py` | Mede quantos códigos de uma lista (os cupons, por exemplo) o catálogo acha. |

## Como rodar

Da raiz do repositório, com Python 3.10 ou mais novo. Só a biblioteca padrão, nada para instalar.

```sh
py -3 tool/catalogo/testes.py                 # as regras
py -3 tool/catalogo/gerar.py                  # baixa os dumps (cerca de 1,7 GB) e gera o arquivo
py -3 tool/catalogo/gerar.py --sem-baixar     # gera de novo do recorte já baixado
py -3 tool/catalogo/cobertura.py codigos.csv  # mede a cobertura de uma lista com a coluna gtin
```

O download leva uns 7 minutos. O recorte fica em `tool/catalogo/cache/` (fora do git, cerca de 1,5 MB). Mudou uma regra: acrescente um caso em `testes.py`, rode os testes e gere de novo com `--sem-baixar`.

## A fonte

Os dumps noturnos de cada projeto, baixados sem passar pela API. O Open Food Facts pede o dump para quem precisa de mais que algumas centenas de produtos, e a API tem limite por minuto ([dados](https://world.openfoodfacts.org/data), [API](https://openfoodfacts.github.io/documentation/docs/Product-Opener/api/)). Como só arquivos estáticos são baixados, as requisições não mandam identificação do app.

| Fonte | Arquivo | Tamanho | Por quê |
| --- | --- | --- | --- |
| Open Food Facts (`off`) | `static.openfoodfacts.org/data/en.openfoodfacts.org.products.csv.gz` | 1,5 GB | O JSONL é bem maior. O Parquet do Hugging Face (`openfoodfacts/product-database`, 8 GB) tem o nome por idioma, mas ler só as colunas pedidas pela rede leva dezenas de milhares de requisições (4.768 grupos de linhas): a tentativa passou de 20 minutos sem terminar. |
| Open Beauty Facts (`obf`) | `static.openbeautyfacts.org/data/openbeautyfacts-products.jsonl.gz` | 100 MB | Sai toda noite e traz `product_name_pt`. O CSV sai uma vez por semana. |
| Open Products Facts (`opf`) | `static.openproductsfacts.org/data/openproductsfacts-products.jsonl.gz` | 40 MB | Idem. Não está no Hugging Face. |

O script lê cada dump enquanto baixa e grava só os produtos brasileiros. O CSV do Open Food Facts não tem `product_name_pt`: o nome é o `product_name`, que nos produtos brasileiros quase sempre está em português.

Fora do catálogo: o Open Pet Food Facts (ração), que tem outra sigla de fonte e ficaria fora do formato combinado com o app; a ração que está no Open Food Facts entra.

## O recorte

- **Quem entra:** o Brasil em `countries_tags` ou o prefixo GS1 brasileiro (789 e 790), menos os produtos marcados como obsoletos.
- **Código:** o mesmo teste do `Gtin.isValid` do app (ADR 0005): 8, 12, 13 ou 14 dígitos e o dígito verificador. Ficam de fora os códigos internos de loja (EAN-13 começado em 2, como a etiqueta da balança, ADR 0018, e o UPC-A interno 02 e 04) e os quase só zero. O GTIN-14 começado em 0 vira o EAN-13 que a câmera lê. O código repetido em duas bases fica com o da primeira, na ordem off, obf, opf.
- **Nome:** `product_name_pt`, senão `product_name`, sem o HTML escapado ("&quot;"), com pelo menos uma letra e até 120 caracteres. Sem nome, o produto não entra.
- **Marca:** a primeira de `brands` ("Nestlé, Ninho" vira "Nestlé").
- **Quantidade:** o texto como veio ("500 g", "6 x 1 L"), até 40 caracteres.
- **Tamanho e unidade:** lidos da quantidade, com as unidades do app (`g`, `kg`, `ml`, `l`, `un`). Mantém a unidade escrita (1 kg fica 1 kg). Um pacote "6 x 1 L" é 6 l, o total, como o preço dele. cl, dl e cc viram ml; rolos, sachês, cápsulas e fraldas viram un; miligrama é dose e fica de fora. Sem tamanho legível na quantidade, usa o `product_quantity` (g ou ml) e, por último, o fim do nome ("Pão de forma 400g"), como a etiqueta (ADR 0013).
- **Tipo:** a primeira regra de `categorias.py` cujo rótulo está nas `categories_tags`, das mais específicas para as mais gerais, na lógica de `ProductKind.of` (leite condensado é doce, leite longa vida é de prateleira, café não é bebida). Tudo o que vem do Open Beauty Facts sem categoria conhecida é `hygiene`. Sem regra, fica `NULL`, e o app deduz pelo nome com `ProductKind.of`.

## O formato

SQLite com `PRAGMA user_version = 1`, combinado com o leitor do app:

```sql
CREATE TABLE catalog_packages (barcode TEXT PRIMARY KEY, name TEXT NOT NULL, brand TEXT,
  quantity TEXT, size_value REAL, size_unit TEXT, kind TEXT, source TEXT NOT NULL) WITHOUT ROWID;
CREATE TABLE catalog_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
```

- `size_unit` é `g`, `kg`, `ml`, `l` ou `un` (o `MeasureUnit` do app escreve o litro como "L").
- `kind` é o nome do enum `ProductKind` (`dairy`, `shelfStable`...) ou `NULL`.
- `source` é `off`, `obf` ou `opf`.
- `catalog_meta` tem `generated_at` (ISO 8601, UTC), `sources` (`off:2026-10-29,obf:...,opf:...`, a data em que cada dump foi baixado), `license` (`ODbL 1.0`), `attribution` e `count`.

Mudar o formato exige subir o `user_version` e mudar o leitor do app junto.

## Resultado em 29/10/2026

Comando: `py -3 tool/catalogo/gerar.py`, com os dumps de 29/10/2026.

| | off | obf | opf | Total |
| --- | --- | --- | --- | --- |
| Brasileiros no dump | 43.416 | 852 | 684 | |
| No catálogo (nome e código válidos) | 39.845 | 515 | 584 | 40.944 |
| Com marca | 28.397 | 429 | 50 | 28.876 (71%) |
| Com tamanho | 19.551 | 339 | 264 | 20.154 (49%) |
| Com tipo | 8.618 | 515 | 9 | 9.142 (22%) |

- **Tamanho do arquivo:** 2,70 MB (2.703.360 bytes), bem abaixo do limite de 15 MB. Não foi preciso encolher nada, e o arquivo vai no git, para o build funcionar sem rodar o script.
- **Tipo:** só 22% têm tipo porque três de cada quatro produtos brasileiros não têm nenhuma categoria no Open Food Facts. Para esses, o app deduz pelo nome.
- **Qualidade:** os dados são colaborativos. Há nomes em caixa alta (cerca de 2.400), nomes curtos ("Whey") e produtos de outros países com o Brasil marcado. A folha de conferir mostra tudo antes de salvar (ADR 0005).
- **Open Products Facts:** a maioria dos 584 não é de mercado (pilhas, eletrônicos); só 9 ganham tipo. Fica porque pesa pouco.

## Cobertura

Pendente: a medição com os códigos dos cupons fiscais do mantenedor, como o ADR 0024 pede. Basta um CSV com a coluna `gtin` (e, se quiser, `descricao`):

```sh
py -3 tool/catalogo/cobertura.py cupons.csv
```

O script diz quantos códigos o catálogo acha e quantos deles vêm com marca, tamanho e tipo, e lista os que faltam.
