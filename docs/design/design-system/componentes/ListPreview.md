# ListPreview

A lista de compras na Casa. Em vez de um número solto, o cartão mostra **o que** tem na lista (miniaturas dos produtos), quantos itens, quanto deve custar e uma ação só.

## Por que assim

O bloco de número anterior ("7 itens" sobre amarelo) era abstrato: não dizia o quê, deixava o meio vazio com ícone e seta de enfeite, competia com a etiqueta de preço e repetia a aba Lista. As referências:

- **iFood / iFood Mercado:** produtos aparecem por imagem, e a sacola mostra o que já foi escolhido.
- **Apps de lista** (Bring!, Listonic): a lista é reconhecida pelos itens, não pela contagem.

## Anatomia

- **Número:** "7 itens" em Manrope 800 26px, com "≈ R$ 84,30" (o total estimado pelos últimos preços registrados) embaixo em `ink-muted`.
- **Miniaturas:** até três produtos em círculos de 40px sobrepostos, com contorno `surface`, e um "+4" no último. Entram em cascata com um salto.
- **"Ir às compras":** o botão de largura total em `brand` com texto `on-brand`. É a única ação do cartão, e abre o modo compra.
- Cartão em `surface`, raio `radius-lg`, sem sombra.

## Regras

- Some quando a lista está vazia: no lugar, a Casa mostra direto os insights.
- Durante uma compra, o cartão sai do topo e dá lugar à barra da compra (ShoppingBar).
- O total leva "≈" porque é uma estimativa; o total real aparece na barra da compra.

## Cabeçalho de seção

A Casa usa o cabeçalho de seção (`.bipa-section-head`): título, selo de contagem (`.bipa-count`, em `alert-soft` quando é alerta) e "Ver tudo" em `ink` à direita.

## Markup

`a.bipa-listprev` com `__num` (`strong` + `small`, `span`), `__thumbs` (`i` com ícone ou `img`, `--i` para a cascata) e `__go`.
