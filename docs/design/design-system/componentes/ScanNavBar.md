# ScanNavBar

Barra de navegação flutuante, de vidro, com o botão de bipar no centro: um toque abre a câmera, segurar abre o menu de leitura.

## Referências

- **iOS 26 (Liquid Glass):** barras flutuam sobre o conteúdo numa camada translúcida e encolhem ao rolar, deixando o conteúdo em primeiro plano.
- **Material 3 Expressive:** menu do botão flutuante com itens que entram em sequência e o ícone que vira "fechar"; movimento com física de mola e formas que se transformam.

## Anatomia

- Pílula a 12px das bordas, fundo `surface-glass` com desfoque de 18px e `shadow-float`.
- Quatro destinos: Início, Produtos, Mercados e Lista. A aba ativa tem o fundo `brand-soft` (indicador que desliza) e ícone `brand-text`.
- **Botão de bipar:** círculo de 64px em `brand` com `shadow-raised` e um anel que respira, 40px acima da barra.
- **Menu do bipar** (toque longo de 420ms): véu `scrim` e quatro pílulas em `surface` empilhadas acima do botão: Modo carrinho, Guardar em casa, Dar baixa em casa e Ler cupom fiscal.

## Movimento

- O indicador desliza até a aba tocada com mola (`duration-slow`).
- **Rolando para baixo** a barra encolhe para 52px, os rótulos somem e o botão de bipar diminui para 56px; **rolando para cima** volta ao normal.
- **Pressionando** o botão de bipar, ele muda de círculo para "squircle" (raio 30%) e encolhe para 94%. Ao abrir o menu, o ícone gira 135° e vira um "×"; as pílulas sobem uma após a outra com 50ms entre elas.
- O anel que respira para enquanto o menu está aberto.
- **Quando o anel respira** (H16, decidido em 28/10/2026): um movimento contínuo no canto do olho briga com a calma por padrão, então o anel (`bipa-breathe`, 2,4 s) tem começo e fim.
  - **Dois ciclos (4,8 s) quando a barra aparece** (o app abre ou volta do fundo, ou a pessoa volta da câmera ou de outra tela cheia), e o anel para no estado de repouso, sem o halo. Trocar de aba não recomeça. Dois ciclos ficam abaixo dos 5 s do WCAG 2.2.2 ("pausar, parar, esconder"), então não é preciso um controle para parar.
  - **Sem fim só enquanto a casa e a lista estão vazias:** aí o anel é o convite ao primeiro bipe, e não há nada para ler ao lado. Com o primeiro item, o ciclo em curso termina e vale a regra de cima.
  - **Parado durante a compra:** a barra da compra é o destaque, e o bipar fica parado.
  - **Com movimento reduzido, nunca respira**, nem é desenhado.
  - A alternativa considerada era respirar até o primeiro bipe do dia. Ela guarda um estado a mais (o dia do último bipe) e, para quem não bipa todo dia, deixa o anel contínuo de novo; a regra por aparição não guarda nada.
- **Segurando um destino** (toque longo), o ícone e o rótulo aparecem grandes num balão de vidro acima da barra, como o Large Content Viewer do iOS. O balão some ao soltar, e o toque longo do destino não abre o menu do bipar, que é só do botão do meio.

## Letra grande

Decidido em 28/10/2026 ([NavLetraGrande](../../prototipo/telas/NavLetraGrande.png)): **A até 160%, B acima.**

- **Até 160% de letra (A):** a anatomia de sempre. O rótulo cresce até 130%, como no `NavigationBar` do Flutter, e depois encolhe até o maior dos quatro caber, todos no mesmo tamanho (medidos com o peso do selecionado, para nada mudar ao trocar de aba). Nunca reticências.
- **Acima de 160% (B):** o bipar sai do meio e flutua acima da barra, à direita, a 12px da pílula, com o mesmo tamanho (64px) e o mesmo menu no toque longo, que sai dele. Os quatro destinos dividem a largura da pílula, e os rótulos crescem até caber e só depois encolhem. A pílula cresce com o rótulo, a partir dos 68px.
- **Acima de 160%, durante a compra** (H12, decidido em 28/10/2026, decisão A do quadro [NavLetraGrandeCompra](../../prototipo/telas/NavLetraGrandeCompra.png)): o bipar flutuante sai, e a barra da compra (`ShoppingBar`) fica no lugar dele, logo acima da pílula: um amarelo só no canto da tela, e 76px a mais para o conteúdo. A barra continua como é, com "Continuar" escrito (texto na navegação), e ganha o toque longo do bipar, que abre o mesmo menu, ancorado nela: o "×" no fim da barra e as pílulas acima dela, alinhadas ao "×". O leitor de tela anuncia o toque longo ("mais opções"). O espaço reservado no layout deixa de incluir o bipar. Na Lista, onde a barra da compra não aparece, o bipar flutua como sempre; até 160%, nada muda.
- O balão do rótulo grande vale em A e em B, porque em B os rótulos ainda encolhem num celular estreito.
- **A barra não encolhe ao rolar** a partir de 130% de letra ou com o TalkBack ligado: o rótulo é a informação, e quem aumenta a letra é quem mais precisa dele.

## Regras

- Um toque no botão sempre abre a câmera direto, sem perguntas.
- Os itens do menu são atalhos: tudo o que eles fazem também existe nas telas.
- O desfoque só funciona sobre conteúdo; no Flutter, `BackdropFilter` com `ImageFilter.blur(18)` dentro de um `ClipRRect`.
- Os rótulos ficam com texto em qualquer tamanho de letra: não se troca rótulo da navegação por ícone sozinho.

> **Pendente no design system publicado.** O toque longo nos destinos e a seção "Letra grande" entraram nesta cópia em 28/10/2026, com a decisão do quadro [NavLetraGrande](../../prototipo/telas/NavLetraGrande.png) e o que o app já faz (`ScanNavBar` em `lib/core/design_system/components/scan_nav_bar.dart`). Na mesma data entraram a barra da compra no lugar do bipar flutuante (H12) e a regra de quando o anel respira (H16), que no CSS publicado ainda é `infinite`. A página publicada no claude.ai precisa receber as mesmas mudanças, que mudam a anatomia do componente acima de 160% e o movimento do anel.

## Markup

`nav.bipa-nav.bipa-nav--glass` com `.bipa-nav__indicator`, `button.bipa-nav__dest` (`__icon`, `__label`), `button.bipa-scan` (`__icon` com `__glyph` e `__close`) e `.bipa-scan-menu` de `button.bipa-scan-menu__item[data-action]`. `Bipa.ScanNavBar.enhance(nav, { scroller, scrim })` emite `bipa:scan` (com `detail.action` quando vem do menu).
