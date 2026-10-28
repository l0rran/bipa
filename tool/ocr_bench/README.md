# Banco de testes do OCR de etiquetas

Mede o `PriceTagParser` sem precisar do Flutter, com um port em Python ([price_tag_parser.py](price_tag_parser.py)) mantido em sincronia com o Dart. Foi assim que as regras de atacado, cartão e varejo (ADR 0011) foram validadas antes de irem para o app.

| Arquivo | Para quê |
| --- | --- |
| `price_tag_parser.py` | Port do parser em Dart. Mudou o Dart, mude aqui também. |
| `testes.py` | Os mesmos casos de `test/features/prices/domain/price_tag_parser_test.dart`, incluindo as etiquetas reais. |
| `etiquetas_reais.py` | Fotos reais de etiquetas do Assaí, transcritas linha a linha com a posição de cada linha. |
| `make_tags.py` | Gera etiquetas sintéticas nos formatos brasileiros (17 layouts) e as "fotografa" com perspectiva, luz irregular, reflexo, desfoque e compressão. |
| `run_ocr.py` | Roda o parser nas etiquetas sintéticas em quatro cenários e mostra o acerto por layout. |

## Como rodar

```sh
cd tool/ocr_bench
python3 testes.py                    # só o parser, sem dependências

# Banco completo: precisa de opencv-python, pytesseract, numpy, Pillow e do Tesseract
# com o modelo de português (por.traineddata) em ./tessdata ou em $BIPA_TESSDATA.
python3 make_tags.py /tmp/etiquetas
python3 run_ocr.py /tmp/etiquetas
```

## Cenários do `run_ocr.py`

- **ideal_frag:** OCR perfeito em que cada elemento impresso vira uma linha. Os centavos sobrescritos chegam separados do inteiro.
- **ideal_linha:** OCR perfeito com os elementos lado a lado agrupados, como o ML Kit costuma fazer.
- **tess_limpa e tess_foto:** Tesseract na etiqueta limpa e na foto simulada. O Tesseract é bem mais fraco que o ML Kit em fotos, então esses números são um piso, não uma previsão do app.

## Resultado em 27/10/2026

| Cenário | Antes (parser 0.1) | Agora |
| --- | --- | --- |
| ideal_frag | 32% | 100% |
| ideal_linha | 65% | 100% |
| tess_limpa | 44% | 78% |
| tess_foto | 29% | 38% |
| Etiquetas reais do Assaí (6, transcritas) | 3 de 6 | 6 de 6 |

As falhas que sobram são do Tesseract: dígitos grandes lidos como lixo, texto branco sobre fundo colorido e fotos muito borradas.

## Fotos reais

As fotos não ficam no repositório. Os casos `mlkit_*` de `etiquetas_reais.py` são a saída do próprio ML Kit, rodado no emulador sobre recortes de vídeo: mostram o que chega ao parser quando os rótulos pequenos não são lidos.

Para acrescentar uma etiqueta real, transcreva o que um bom OCR leria em `etiquetas_reais.py` (texto e caixa de cada linha) e copie o caso para os testes em Dart. Com uma foto nítida, dá para rodar o Tesseract nela também, mas recortes de vídeo com etiquetas de 150 px não são lidos por nenhum OCR.
