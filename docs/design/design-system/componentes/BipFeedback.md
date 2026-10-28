# BipFeedback

A confirmação de que um preço foi salvo: um círculo verde aparece com mola, o check se desenha, uma onda se expande e um aviso sobe com o resumo.

## Sequência

1. Círculo `positive-soft` cresce de 0 a 1 (`duration-slow`, `easing-spring`).
2. O check em `positive-text` se desenha (`duration-slow`, a partir de 180ms).
3. Uma onda em `positive-text` se expande e some (`duration-celebrate`).
4. O aviso em `ink` com texto `ground` sobe 16px (a partir de 380ms): "**Bipou!** R$ 7,99 no Atacarejo Vila Nova".

## Referências

- **Scandit:** confirmar com som, vibração e visual juntos; esperar 150ms antes de seguir para a pessoa sentir que leu.
- **Snackbar com ação (Material):** quando algo é salvo sem pedir confirmação, oferecer "Desfazer" por alguns segundos. No modo carrinho os preços salvam direto, então o desfazer é obrigatório.

## Regras

- Toca junto com vibração leve e um bip curto (respeita o volume de mídia e pode ser desligado).
- O aviso tem **"Desfazer"** em `price` e uma linha de tempo que esvazia em 4s; depois disso o registro fica.
- Passados os 4s, o aviso sai descendo; tocar nele (fora do Desfazer) abre o produto.
- Com "reduzir movimento", tudo aparece já no estado final.
- O contêiner tem `role="status"` para leitores de tela anunciarem o resumo.
