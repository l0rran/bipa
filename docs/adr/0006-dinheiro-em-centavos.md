# 0006. Representar dinheiro em centavos

- Status: Aceito
- Data: 2026-10-27

## Contexto

Preços são somados, comparados e divididos (preço por quilo). Com `double`, `0.1 + 0.2 != 0.3`, e erros de arredondamento aparecem em comparações e totais.

## Decisão

Todo valor monetário é um `Money`, que guarda centavos em `int`. No banco, colunas `*_cents` do tipo `INTEGER`. Conversões de e para texto passam por `Money.tryParse` e `Money.format` (formato brasileiro).

## Consequências

- Comparações e somas são exatas.
- Divisões (preço por unidade) arredondam para o centavo mais próximo em um único lugar (`UnitPrice`).
- `double` só aparece em quantidades físicas (1,5 kg), nunca em valores.
