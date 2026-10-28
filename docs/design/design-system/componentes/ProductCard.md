# ProductCard

O cartão de produto da prateleira "Acabando": imagem grande, medidor no canto e um "+" para pôr na lista. É o que mais se aproxima de uma vitrine, e quase não tem texto.

## Referências

- **iFood / iFood Mercado:** prateleiras horizontais de produtos com foto, nome embaixo e o botão de adicionar sobre a imagem.
- **Bring!:** um toque para pôr na lista.

## Do jeito do Bipa

- Em vez do preço, o canto mostra o **medidor de nível** (o mesmo da lista), porque no Início o que importa é quanto resta.
- O **"+"** é a única ação. Tocado, vira um check e o item vai para a lista.
- Tocar no resto do cartão abre o produto.

## Anatomia

- **Arte:** quadrada, `surface`, raio `radius-lg`, com a foto do produto ou o ícone da categoria (46px).
- **Medidor:** 36px no canto superior esquerdo, sobre um círculo `surface`.
- **"+":** 36px no canto inferior direito, `surface` com `shadow-raised` e ícone `ink`. Quando marcado, fica cheio em `ink` com o check. O amarelo fica para o bipar e para "Ir às compras".
- **Nome:** Figtree 600 14px, até duas linhas.
- Os cartões têm 116px de largura e encaixam ao rolar (`scroll-snap`).

## Markup

`.bipa-cards` > `article.bipa-pcard[data-place]` (+ `.is-out`) com `.bipa-pcard__art` (ícone ou `img`, `.bipa-gauge.is-low|.is-out` e `button.bipa-pcard__add[aria-pressed]` com `.is-off` e `.is-on`) e `.bipa-pcard__name`. `Bipa.ProductCard.enhance(card)` emite `bipa:list` com `{ onList }`. O selo de contagem do título da seção é `.bipa-count` (`--alert` para âmbar).

## Imagem do produto

Produto aparece por imagem sempre que possível, e o nome fica embaixo. A imagem vem, nesta ordem:

1. **A foto da pessoa**, tirada ao bipar ou na tela do produto e guardada no aparelho.
2. **A foto da embalagem no Open Food Facts**, pelo código de barras, baixada uma vez quando houver internet (crédito à fonte na tela do produto).
3. **O ícone da categoria** (leite, café, arroz, limpeza...), deduzido do nome, em quadro neutro.

Nunca usar uma foto genérica de "produto": ela daria a entender que é a foto real. O ícone deixa claro que é a categoria. A mesma regra vale para a miniatura da lista (StockStepper) e da prévia da lista (ListPreview).
