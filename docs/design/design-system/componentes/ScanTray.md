# ScanTray

A bandeja do **modo carrinho**: a câmera continua aberta e cada bip empilha um item aqui, com o total do que você vai levar.

## Referências

- **Scandit SparkScan:** escaneamento contínuo com um botão grande e translúcido flutuando sobre o app, sem abrir e fechar a câmera a cada item.
- **Walmart Scan & Go:** total acumulado enquanto você compra, que ajuda a ficar no orçamento. A maior reclamação do app é produto sem código, como hortifrúti a granel.

## Do jeito do Bipa

- A leitura da **etiqueta por OCR resolve o granel**: "Banana prata (kg)" entra pelo preço da gôndola.
- Cada item tem um **"levar"** (ligado por padrão). Desligado, o preço fica registrado para comparação, mas não entra no total nem no estoque.
- Ao finalizar ("Terminei"), os itens com "levar" somam 1 no estoque de casa e a lista de compras risca o que foi pego.

## Anatomia

- Folha em `surface` com raio `radius-lg` só no topo, `shadow-float` e alça `line`.
- Cabeçalho: "Carrinho" (Manrope 800, 18px), contador que rola ("3 itens bipados") e o total "Vou levar" (Manrope 800, 22px).
- Itens em `ground` com raio `radius-md` (concêntrico: 20 da folha − 8 de respiro ≈ 14): nome, preço numa mini etiqueta `price` e o interruptor "levar" (`brand` quando ligado).
- Mostra os 4 últimos; arrastar a alça para cima expande a lista inteira.

## Movimento

- Item novo entra no topo descendo 14px com mola; os outros abrem espaço.
- O contador rola e o total conta do valor antigo para o novo (`duration-slow`).
- O interruptor desliza com mola; desligado, o item fica a 45% de opacidade.

## Markup

`.bipa-tray` com `__handle`, `__head` (`__title`, `__count` com `.bipa-roll.bipa-tray__count-value`, `__total-value`) e `__list` de `.bipa-tray__item[data-cents]` (nome, `__item-price`, `button.bipa-toggle[role=switch]`). `Bipa.ScanTray.enhance(el)` devolve `{ add({ name, cents }) }`.
