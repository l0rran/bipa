# ScanNavBar

Barra de navegação flutuante, de vidro, com o botão de bipar no centro: um toque abre a câmera, segurar abre o menu de leitura.

## Referências

- **iOS 26 (Liquid Glass):** barras flutuam sobre o conteúdo numa camada translúcida e encolhem ao rolar, deixando o conteúdo em primeiro plano.
- **Material 3 Expressive:** menu do botão flutuante com itens que entram em sequência e o ícone que vira "fechar"; movimento com física de mola e formas que se transformam.

## Anatomia

- Pílula a 12px das bordas, fundo `surface-glass` com desfoque de 18px e `shadow-float`.
- Quatro destinos: Início, Produtos, Mercados e Lista. A aba ativa tem o fundo `brand-soft` (indicador que desliza) e ícone `brand-text`.
- **Botão de bipar:** círculo de 64px em `brand` com `shadow-raised` e um anel que respira, 40px acima da barra.
- **Menu do bipar** (toque longo de 420ms): véu `scrim` e três pílulas em `surface` empilhadas acima do botão: Modo carrinho, Dar baixa em casa e Ler cupom fiscal.

## Movimento

- O indicador desliza até a aba tocada com mola (`duration-slow`).
- **Rolando para baixo** a barra encolhe para 52px, os rótulos somem e o botão de bipar diminui para 56px; **rolando para cima** volta ao normal.
- **Pressionando** o botão de bipar, ele muda de círculo para "squircle" (raio 30%) e encolhe para 94%. Ao abrir o menu, o ícone gira 135° e vira um "×"; as pílulas sobem uma após a outra com 50ms entre elas.
- O anel que respira para enquanto o menu está aberto.

## Regras

- Um toque no botão sempre abre a câmera direto, sem perguntas.
- Os itens do menu são atalhos: tudo o que eles fazem também existe nas telas.
- O desfoque só funciona sobre conteúdo; no Flutter, `BackdropFilter` com `ImageFilter.blur(18)` dentro de um `ClipRRect`.

## Markup

`nav.bipa-nav.bipa-nav--glass` com `.bipa-nav__indicator`, `button.bipa-nav__dest` (`__icon`, `__label`), `button.bipa-scan` (`__icon` com `__glyph` e `__close`) e `.bipa-scan-menu` de `button.bipa-scan-menu__item[data-action]`. `Bipa.ScanNavBar.enhance(nav, { scroller, scrim })` emite `bipa:scan` (com `detail.action` quando vem do menu).
