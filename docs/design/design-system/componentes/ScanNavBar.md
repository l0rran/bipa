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

> **Proposta, aguarda revisão: o anel respira e para (H16).** Hoje o anel (`bipa-breathe`, 2,4 s) respira sem fim, em todas as abas: um movimento contínuo no canto do olho enquanto a pessoa lê, e ao lado da barra amarela durante a compra, que já é o destaque da tela. A regra proposta:
>
> - **Dois ciclos (4,8 s) quando a barra aparece** (o app abre, ou a pessoa volta da câmera ou de outra tela cheia), e o anel para no estado de repouso, sem o halo. Trocar de aba não recomeça. Dois ciclos ficam abaixo dos 5 s do WCAG 2.2.2 ("pausar, parar, esconder"), então não é preciso um controle para parar.
> - **Sem fim só enquanto a casa e a lista estão vazias:** aí o anel é o convite ao primeiro bipe, e não há nada para ler ao lado. Com o primeiro item, vale a regra de cima.
> - **Não respira durante a compra:** a barra da compra é o destaque, e o bipar fica parado.
> - Com movimento reduzido, nunca respira, como hoje.
>
> A alternativa considerada era respirar até o primeiro bipe do dia. Ela guarda um estado a mais (o dia do último bipe) e, para quem não bipa todo dia, deixa o anel contínuo de novo; a regra por aparição não guarda nada. Aprovada, a regra entra no guia e no design system publicado no claude.ai, e só depois no código (`_ScanButtonState` em `scan_nav_bar.dart`).
- **Segurando um destino** (toque longo), o ícone e o rótulo aparecem grandes num balão de vidro acima da barra, como o Large Content Viewer do iOS. O balão some ao soltar, e o toque longo do destino não abre o menu do bipar, que é só do botão do meio.

## Letra grande

Decidido em 28/10/2026 ([NavLetraGrande](../../prototipo/telas/NavLetraGrande.png)): **A até 160%, B acima.**

- **Até 160% de letra (A):** a anatomia de sempre. O rótulo cresce até 130%, como no `NavigationBar` do Flutter, e depois encolhe até o maior dos quatro caber, todos no mesmo tamanho (medidos com o peso do selecionado, para nada mudar ao trocar de aba). Nunca reticências.
- **Acima de 160% (B):** o bipar sai do meio e flutua acima da barra, à direita, a 12px da pílula, com o mesmo tamanho (64px) e o mesmo menu no toque longo, que sai dele. Os quatro destinos dividem a largura da pílula, e os rótulos crescem até caber e só depois encolhem. A pílula cresce com o rótulo, a partir dos 68px.
- O balão do rótulo grande vale em A e em B, porque em B os rótulos ainda encolhem num celular estreito.
- **A barra não encolhe ao rolar** a partir de 130% de letra ou com o TalkBack ligado: o rótulo é a informação, e quem aumenta a letra é quem mais precisa dele.

## Regras

- Um toque no botão sempre abre a câmera direto, sem perguntas.
- Os itens do menu são atalhos: tudo o que eles fazem também existe nas telas.
- O desfoque só funciona sobre conteúdo; no Flutter, `BackdropFilter` com `ImageFilter.blur(18)` dentro de um `ClipRRect`.
- Os rótulos ficam com texto em qualquer tamanho de letra: não se troca rótulo da navegação por ícone sozinho.

> **Pendente no design system publicado.** O toque longo nos destinos e a seção "Letra grande" entraram nesta cópia em 28/10/2026, com a decisão do quadro [NavLetraGrande](../../prototipo/telas/NavLetraGrande.png) e o que o app já faz (`ScanNavBar` em `lib/core/design_system/components/scan_nav_bar.dart`). A página publicada no claude.ai precisa receber a mesma mudança, que muda a anatomia do componente acima de 160%.

## Markup

`nav.bipa-nav.bipa-nav--glass` com `.bipa-nav__indicator`, `button.bipa-nav__dest` (`__icon`, `__label`), `button.bipa-scan` (`__icon` com `__glyph` e `__close`) e `.bipa-scan-menu` de `button.bipa-scan-menu__item[data-action]`. `Bipa.ScanNavBar.enhance(nav, { scroller, scrim })` emite `bipa:scan` (com `detail.action` quando vem do menu).
