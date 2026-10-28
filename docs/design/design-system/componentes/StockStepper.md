# StockStepper

A lista do estoque. Cada linha mostra uma miniatura, o nome e o medidor de nível, quase sem texto. Os controles aparecem quando você toca no item.

## Por que assim

- **iFood:** a home quase não tem texto solto. Todo texto faz parte de um componente, e cada item tem imagem.
- **Apple (diretrizes de indicadores de capacidade):** o preenchimento mostra quanto há em relação ao total, a cor muda quando o nível fica baixo, e os rótulos acessíveis dizem o valor por extenso.
- **Linear (redesenho de 2025):** atenção só para o que é a tarefa e cor só com função.
- **Baymard:** o −/+ só aparece quando o item está em uso.
- **Pantry Check (avaliações):** ações destrutivas perto do ajuste e falta de desfazer são as maiores reclamações.

## Anatomia

- **Miniatura** (`.bipa-thumb`, 44px, raio 14px): a foto do produto ou o ícone da categoria em `surface-sunken`. Quando o item está na lista, ganha um selo `ink` com check no canto, em vez do texto "na lista".
- **Nome:** Figtree 600 16px, quebra em até duas linhas e nunca é cortado no meio.
- **Medidor** (`.bipa-gauge`, 40px): um anel com o número dentro. O anel enche até o **"ter sempre"**, a quantidade que a pessoa quer ter em casa:
  - **Em dia** (no "ter sempre" ou acima): anel fechado em `line`, número em `ink`.
  - **Acabando** (abaixo do "ter sempre"): o arco em `alert` mostra a fração, e o número fica em `alert-text`.
  - **Acabou:** anel tracejado em coral (`alert`) com "0", e a miniatura esmaece.
- **Editor** (`.bipa-shelf__editor`): o stepper −/+ e "Pôr na lista", só no item aberto.
- **Local:** não se repete em cada linha. Ele vira o filtro por categorias no topo (FilterChips).

## Regras

- **Mostrar em vez de escrever:** quantidade, estado e "na lista" aparecem por componentes (anel, cor, selo), não por frases como "2 de 4" ou "Acabou".
- **Uma cor de alerta:** o coral (`alert`). O amarelo da marca fica para as ações de bipar e comprar.
- **Nenhum botão em repouso:** tocar abre o editor ali mesmo, um item por vez.
- **"Ter sempre"** substitui "mínimo": o item está acabando quando fica abaixo desse número. No código, `StockItem.isLow` passa a ser `quantity < minimumQuantity`.

## Gestos

- **Deslizar para a esquerda:** "Usei um", que também põe na lista o que ficou abaixo do "ter sempre" (ADR 0019). **Para a direita:** "Pôr na lista" ou "Tirar da lista". A ação vale ao passar de 30% da largura, e o aviso diz o que mudou e oferece **Desfazer**.
- Segurar − ou + repete. No app, tocar no número do stepper abre o teclado numérico.
- Todo gesto tem um caminho equivalente por botão.

## Movimento

- O arco do medidor anima até o novo valor com mola; o número do stepper rola.
- O editor abre com mola, e o selo de "na lista" entra com um salto.

## Acessibilidade

- O medidor tem `role="img"` com o estado por extenso ("2 de 4 un", "Acabou").
- A linha é um botão com `aria-expanded`. O − e o + do stepper corrigem a quantidade e não mexem na lista: "Uma embalagem a menos" e "Uma embalagem a mais". "Usei um" e "Comprei um" ficam para os gestos e a câmera, que também mudam a lista.

## Markup

`.bipa-shelf` > `.bipa-shelf__item[data-value][data-min][data-unit][data-place]` com `.bipa-swipe__under` (opcional), `button.bipa-shelf__row` (`.bipa-thumb` com `__badge`, `.bipa-shelf__name` e `.bipa-gauge[style="--p: N"]` com o `svg` de dois círculos e `__value`) e `.bipa-shelf__editor` > `div` > `.bipa-stepper` + `button.bipa-shelf__list`. Ligue com `Bipa.StockStepper.enhance(shelf)` e `Bipa.SwipeRow.enhance(item)`. Os eventos são `bipa:change`, `bipa:list` e `bipa:swipe`.
