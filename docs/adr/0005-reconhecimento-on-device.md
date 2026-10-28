# 0005. Reconhecer etiquetas e códigos no aparelho com ML Kit

- Status: Aceito
- Data: 2026-10-27

## Contexto

Ler código de barras e etiqueta de preço pela câmera é o que diferencia o app, e precisa funcionar offline, rápido e sem custo por leitura.

## Decisão

- **Código de barras** com ML Kit Barcode Scanning (pelo `mobile_scanner` na câmera ao vivo e pelo `google_mlkit_barcode_scanning` em fotos).
- **Texto da etiqueta** com ML Kit Text Recognition (modelo latino, embutido no app).
- A **interpretação** do texto (qual número é o preço, promoção de/por, preço por quilo) fica no `PriceTagParser`, em Dart puro, coberto por testes.
- Todo código lido é validado pelo dígito verificador do GTIN antes de ser usado.

## Consequências

- Nenhuma imagem sai do aparelho para reconhecimento.
- O APK cresce alguns megabytes com os modelos embutidos.
- O motor de OCR pode ser trocado sem mexer nas regras, porque o parser recebe apenas linhas de texto com posição e altura (`OcrLine`).
- A leitura é sempre uma sugestão: a interface mostra o resultado para o usuário conferir antes de salvar.

Atualização (28/10/2026): o código de barras ao vivo passou a ser lido pelo ML Kit nos quadros do plugin `camera` (ADR 0012), em todas as telas; o `mobile_scanner` saiu.
