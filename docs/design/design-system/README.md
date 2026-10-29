# Bipa: design system

> **Cópia exportada** do design system **Bipa** publicado no claude.ai (o link está em [identidade-visual.md](../identidade-visual.md)), em 28/10/2026, para agentes e pessoas sem acesso à página. A versão publicada é a fonte da verdade: se as duas divergirem, vale a publicada, e esta cópia deve ser exportada de novo.
>
> - Guia e imagem de cada componente: [`componentes/`](componentes/). O HTML das prévias, o CSS (`bundle.css`), o comportamento (`bundle.js`) e os tipos (`index.d.ts`) ficam em [`fonte/`](fonte/).
> - Os tokens são o [`design/tokens.json`](../../../design/tokens.json) do repositório, que é idêntico ao do design system.
> - Os logos ficam em [`logos/`](logos/).

O Bipa ajuda a cuidar da despensa e a pagar menos no mercado sem digitar quase nada: aponta a câmera, *bip*, e o preço, o produto e o estoque se atualizam. A identidade vem da etiqueta de oferta do varejo brasileiro: o amarelo do preço é a cor da marca, sobre uma base clara e neutra, num tom calmo e confiável. É um app que cuida do seu dinheiro, e o preço é o herói.

## Princípios

1. **Um gesto, um registro.** Toda tela tem uma ação óbvia e grande. Se o usuário precisa digitar, a câmera não fez o trabalho dela.
2. **O preço é o herói.** Valores aparecem grandes, em `display`, sobre a etiqueta `price`. O resto da tela é neutro para o preço falar.
3. **Confiável antes de divertido.** Neutros sóbrios, cor só onde tem significado e animações curtas. A leveza fica na voz e no "bip", não na decoração.
4. **Referência primeiro, do nosso jeito depois.** Antes de desenhar algo novo, pesquisamos como outros apps resolvem (mercado, lista, banco, scanners, sistemas da Apple e do Google) e adaptamos ao contexto do Bipa: offline, uma mão, dentro do mercado. Cada componente registra no seu guia as referências e o que fizemos diferente.
5. **Calma por padrão.** Cada coisa só ganha atenção quando precisa. Em cada tela há no máximo um elemento com destaque (um cartão ou um botão cheio). Cada informação aparece por um sinal só: se o item está em "Acabando", a linha não repete o estado com selo e barra. As cores de estado se resumem ao coral para alerta e ao verde para o que deu certo, e o amarelo da marca fica para bipar e comprar. Controles aparecem quando a pessoa toca, e os números importantes aparecem como números, não escondidos numa frase.
6. **Mostrar em vez de escrever.** Como na home do iFood, quase não há texto solto: todo texto faz parte de um componente. Produtos têm imagem, locais são categorias com arte, quantidade é um medidor e "na lista" é um selo. Quando o componente é só texto, a tipografia trabalha: uma linha pequena, o essencial grande e uma pílula com o detalhe.
7. **Todo texto precisa se justificar.** Antes de pôr um texto na tela, três perguntas: **é o lugar dele?** **É necessário?** **Dá para dizer o mesmo de outra forma** (ícone, número, cor, forma, posição ou um componente que já existe) **sem prejudicar a compreensão?** Se outro elemento já diz a mesma coisa, o texto sai. Três limites: rótulos da navegação e de ações que apagam algo ficam com texto, não se troca texto por ícone ambíguo, e todo elemento visual tem rótulo acessível.
8. **Um acento por tela.** Cada tela tem uma cor de destaque, e o resto é neutro. No Início, o amarelo (`brand`) fica para as ações de marca (o botão de bipar, "Ir às compras" e a barra da compra), o coral (`alert`) só marca o que está abaixo do "ter sempre", e todo o resto (locais, "+", "na lista", régua, links) é `ink` e cinzas. O verde é da economia e o `place` é dos mercados, cada um na sua tela.
9. **Funciona com uma mão, no corredor.** Ações principais no terço inferior da tela, alvos de toque com no mínimo 48px, contraste alto para a luz fria do mercado.

## Voz e tom

O Bipa fala como alguém que entende de mercado: direto, em segunda pessoa (você), cordial e sem gírias.

| Situação | Escreva | Evite |
| --- | --- | --- |
| Preço salvo | **Bipou!** R$ 7,99 no Atacarejo. | Registro efetuado com sucesso. |
| Estoque baixo | Acabando: arroz, café e leite. | Itens abaixo do nível mínimo de estoque. |
| Menor preço | Mais barato aqui · economize R$ 1,20 | Este é o estabelecimento com o menor valor registrado. |
| Erro de leitura | Não encontramos o preço. Aproxime a câmera da etiqueta. | Falha no reconhecimento óptico de caracteres. |
| Permissão | Para saber em qual mercado você está, o Bipa precisa da sua localização. | O aplicativo requer acesso à localização. |

**Erros que resolvem.** Toda mensagem de erro diz o que aconteceu e o que fazer em seguida, com um botão para isso, e nunca bloqueia sem saída. Ao reescrever assim as mensagens e remover pontos de bloqueio, o iFood viu 54% a mais de compras concluídas.

Botões dizem exatamente o que acontece ("Salvar e bipar outro", "Usei um"). Números sempre no formato brasileiro: R$ 1.234,56, 1,5 kg, 27/10.

## Cores

Os tokens têm nome de função, não de cor (ADR 0009 do repositório): trocar a paleta não muda nenhum nome no código. A marca é o amarelo da etiqueta, e há quatro cores com significado fixo:

| Token | Cor | Papel | Onde aparece |
| --- | --- | --- | --- |
| `brand` | Amarelo `#F6C445` | A marca e a ação de bipar | Botão de bipar, botão principal, "Ir às compras", barra da compra, aba ativa (`brand-soft`). Sempre com `on-brand` (escuro) por cima |
| `price` | O mesmo amarelo | Preço | Etiqueta de preço, promoção "de/por" |
| `alert` | Coral `#E8573A` | Atenção | Medidor abaixo do "ter sempre", selo de "Acabando" (`alert-soft`), erros (`alert-text`) |
| `positive-text` | Verde | Economia | "Mais barato aqui", economia do mês (`positive-soft`) |
| `place` | Azul-ardósia | Lugar | Só na tela de mercados: mapa, distância (`place-soft`) |
| `ink` | Quase preto | Texto e ações comuns | Texto principal, ícones e botões neutros |

Regras:
- Superfícies são neutras (`ground`, `surface`). Uma tela raramente usa mais de duas cores além dos neutros.
- Texto sobre cor usa o token `on-*` correspondente. Texto colorido sobre fundo neutro usa as variantes `*-text`, que passam 4.5:1.
- O amarelo nunca é usado como texto sobre fundo claro (não tem contraste): sobre ele vai sempre texto escuro, e quando a marca precisa aparecer em texto usa `brand-text`. Erros usam `alert-text` com ícone e mensagem, e ações destrutivas pedem confirmação.

## Tipografia

- **Manrope** (`display`): títulos e preços, em 700–800. Geométrica e firme, com números claros.
- **Figtree** (`body`): todo o resto. Legível em tamanhos pequenos.
- **JetBrains Mono** (`mono`): só para códigos de barras e números de conferência.

Preços usam sempre algarismos tabulares, para alinharem em listas. No app as fontes vão embutidas (o app é offline), não baixadas do Google Fonts.

## Forma e elevação

- **Arredondado, sem exagero:** `radius-lg` (20px) em cartões e folhas, `radius-md` (14px) em campos, `radius-pill` em botões, chips, stepper e navegação.
- **Raios concêntricos:** um elemento dentro de outro usa o raio externo menos o espaço entre eles (cartão de 20 com 8 de respiro → item de 12 a 14), para os cantos ficarem paralelos.
- **Vidro só sobre conteúdo:** `surface-glass` com desfoque de 18px na barra de navegação e em controles sobre a câmera; nunca em cartões.
- **Sem contornos pesados:** botões secundários usam um contorno interno de `stroke-control` em `line`; o resto se separa por cor de superfície.
- **Elevada** (`shadow-raised`): só no que se toca e importa: botão principal, botão de bipar e etiqueta de preço.
- **Flutuante** (`shadow-float`): folhas inferiores, aviso "Bipou!" e a barra de navegação.
- **Foco** (`shadow-focus`): anel escuro translúcido de 3px no tema claro (amarelo no escuro) em qualquer controle focado pelo teclado.
- Cartões de lista não têm sombra: ficam em `surface` sobre `ground`, com divisórias `line`.

## Ícones

Material Symbols **Rounded**, preenchimento 0, peso 500, tamanho 24px (20px em chips). No Flutter são os `Icons.*_rounded`, que já vêm no SDK e funcionam offline. Ícones herdam a cor do texto ao lado; ícone colorido só quando carrega significado (localização em `place`, alerta em `alert-text`).

## Movimento

O Bipa é animado, mas nunca lento: tudo que muda de estado anima, e nada passa de 600ms.

| Token | Valor | Uso |
| --- | --- | --- |
| `duration-fast` | 120ms | Resposta ao toque |
| `duration-base` | 220ms | Troca de estado, números rolando |
| `duration-slow` | 380ms | Entradas, folhas, indicador da aba |
| `duration-celebrate` | 600ms | O "Bipou!" e a contagem do preço |
| `easing-standard` | `cubic-bezier(0.2, 0, 0, 1)` | Padrão |
| `easing-spring` | `cubic-bezier(0.34, 1.56, 0.64, 1)` | Mola com leve exagero: toques, números, indicadores |
| `easing-exit` | `cubic-bezier(0.3, 0, 1, 1)` | Saídas |

Padrões:
- **Toque:** todo controle encolhe levemente (88–96%) com mola e volta ao soltar.
- **Números rolam:** quantidade e preço trocam com rolagem vertical; o preço lido conta de 0 até o valor.
- **Indicadores deslizam:** a aba ativa e seleções em grupos de botões deslizam até o novo item, em vez de piscar.
- **Bipou!:** salvar um preço toca o `BipFeedback` com vibração leve (`HapticFeedback.lightImpact`).
- **Listas** entram em cascata (60ms entre itens); **folhas** sobem com mola.
- **Carregamento** usa `Skeleton` no formato do conteúdo, nunca um spinner solto.
- Com "reduzir movimento" ativo no aparelho, as animações viram cortes instantâneos ou fades.

## Logo

O símbolo é a etiqueta de gôndola: uma etiqueta `brand` (o amarelo do preço) com o furo à esquerda, o mesmo da `PriceTag`, e um "b" em `ink`, sobre um quadrado arredondado `ink`. É o mesmo desenho do ícone do app. Use sobre `ground`, `surface` ou fotos escuras; nunca distorça nem troque as cores. Para usos em uma cor (marca d'água, carimbo), use `bipa-symbol-mono.svg` em `ink`: a etiqueta cheia, com o furo e o "b" vazados. O nome "Bipa" acompanha o símbolo em Manrope 800, com a altura do "b".

> **Pendente no design system publicado.** Em 28/10/2026 o mantenedor escolheu a proposta 1 · Etiqueta para o ícone do app, e o símbolo mudou nesta cópia (`logos/bipa-symbol.svg`, `logos/bipa-symbol-mono.svg` e este parágrafo). A página publicada no claude.ai ainda mostra o símbolo antigo (quatro barras e o laser coral) e **precisa receber a mesma mudança**; depois disso, exporte a cópia de novo. As quatro barras continuam só como indicador de carregamento (`.bipa-loader`).

## Componentes

| Componente | Uso |
| --- | --- |
| Button | Ações: principal (amarelo com texto escuro, com carregando e concluído), neutro (`ink`), secundário e tonal; seletor segmentado. |
| PriceTag | O preço, sempre: normal com preço por unidade, de/por, no app/clube, leve X pague Y e menor preço; histórico de preço. |
| StockStepper | Lista do estoque: miniatura, nome e medidor de nível; tocar abre −/+ e "Pôr na lista"; deslizar dá baixa ou põe na lista. |
| ProductCard | Prateleira de produtos (Acabando): imagem, medidor no canto e "+" para pôr na lista. |
| SearchBar | Busca no topo com o botão de bipar dentro. |
| ListPreview | A lista no Início: miniaturas do que tem nela, quantidade, total estimado e "Ir às compras"; cabeçalho de seção. |
| ShoppingBar | A compra em andamento, fixa acima da navegação: progresso da lista e total bipado. |
| FilterChips | Filtro de uma escolha: locais como categorias com arte (Início) ou chips (listas longas). |
| MarketChip | Mercado e distância (vidro sobre a câmera); preço por mercado com a idade do preço; sua lista em cada mercado. |
| ScanNavBar | Barra de vidro que encolhe ao rolar, com indicador deslizante e o botão de bipar (menu no toque longo). |
| ScanFrame | Visor da câmera: procurando, trava no código, clarão e confirmação. |
| ScanTray | Bandeja do modo carrinho: itens bipados em sequência e o total do que você vai levar. |
| BipFeedback | A confirmação animada de preço salvo, com Desfazer. |
| InsightCard | Carrossel do Início: "Hora de repor" (título tipográfico com a arte, régua do ciclo e três números) e "Economia do mês"; a fonte fica no ⓘ. |
| ShoppingList | Adicionar com um toque e lista na ordem dos corredores do mercado. |
| Skeleton | Placeholder de carregamento com brilho. |

Nas prévias, os componentes são HTML com classes `bipa-*` (estilos em `components/bundle.css`) e comportamento em `window.Bipa` (`components/bundle.js`): cada um tem `enhance(el)`, que liga estados e animações. Envolva o conjunto em `.bipa-root`.

## No Flutter

Os tokens viram um `ThemeExtension` (`BipaColors`, `BipaShadows`) ao lado do `ColorScheme` do Material 3: `brand` é o `primary`, `place` o `secondary`, `brand-text` o `error`, `ground` o fundo do `Scaffold`. Raios, espaçamentos e estilos de texto ficam em classes de constantes (`BipaRadius`, `BipaSpacing`) e no `TextTheme`. Durações e curvas viram `BipaMotion` (`Duration` e `Cubic`), e cada componente das prévias tem um widget equivalente com o mesmo comportamento.

## Referências

Apps e sistemas que estudamos e o que levamos de cada um. Os detalhes de cada componente estão no guia dele.

| Referência | O que levamos |
| --- | --- |
| iFood / iFood Mercado | Home quase sem texto solto, categorias com imagem e nome embaixo, prateleiras de produtos com "+", tipografia expressiva; lista que serve para qualquer mercado, lista por foto e voz, barra da compra em andamento, erros que resolvem |
| Scandit e Open Food Facts | Confirmação de leitura com som, vibração e visual; pausa de 150ms; leitura contínua; produto desconhecido sem erro |
| Walmart Scan & Go | Total acumulado durante a compra |
| Bring! e AnyList | Adicionar com um toque; lista na ordem dos corredores |
| Baymard (mercados online) | Stepper só quando há interação; permitir digitar a quantidade |
| Monzo e Revolut | Insights com um número em destaque, o porquê explicado e cartões dispensáveis |
| Linear e Shortcut (redesenhos de 2025) | "Não disputar atenção que não foi conquistada", estrutura sentida e não vista, menos ícones e separadores, cor só com função |
| Flo (ciclo menstrual) | Ciclo, duração média e última data como indicadores rápidos de ler, em vez de gráficos |
| Menor Preço Brasil e Preço da Hora (Sefaz) | Preço vindo da NFC-e, busca por código de barras, raio de 30 km, data da última venda, histórico do preço |
| Basket (EUA) | Comparar a lista inteira entre mercados; pedir ao usuário para confirmar só os preços que mais mudam |
| Pantry Check e NoWaste | Baixa rápida, consumido ou desperdiçado, validade; das reclamações: falta de desfazer, ações destrutivas próximas e itens perdidos ao adicionar em lote |
| Grocy e Barcode Buddy | Modos de leitura (usei, comprei, abri, pôr na lista) que voltam sozinhos ao padrão; quantidade por embalagem |
| Listonic | Sugerir os itens de sempre (66% das listas se repetem), voz e widget na tela inicial |
| Material 3 Expressive e Android 16 | Movimento com mola, formas que mudam, menu do botão flutuante, notificação ao vivo |
| iOS 26 (Liquid Glass) | Barra flutuante de vidro que encolhe ao rolar; raios concêntricos |
| Wonderous (Flutter) | Linguagem visual própria, gestos familiares, acessibilidade desde o início |
| Referências de interface enviadas pelo Wesley | Busca em destaque com botão dentro, banner com imagem e pontos, seções com contagem e "Ver tudo", listas com ícone em quadro |
| Apple (indicadores de capacidade) | Medidor que enche até o total, cor que muda no nível baixo, rótulo acessível por extenso |
| Etiquetas de gôndola no Brasil | Preço por unidade de medida, preço no app/clube, leve X pague Y |

## Guias exportados

| Componente | Guia | Imagem |
| --- | --- | --- |
| BipFeedback | [BipFeedback.md](componentes/BipFeedback.md) | [BipFeedback.png](componentes/BipFeedback.png) |
| Button | [Button.md](componentes/Button.md) | [Button.png](componentes/Button.png) |
| FilterChips | [FilterChips.md](componentes/FilterChips.md) | [FilterChips.png](componentes/FilterChips.png) |
| InsightCard | [InsightCard.md](componentes/InsightCard.md) | [InsightCard.png](componentes/InsightCard.png) |
| ListPreview | [ListPreview.md](componentes/ListPreview.md) | [ListPreview.png](componentes/ListPreview.png) |
| MarketChip | [MarketChip.md](componentes/MarketChip.md) | [MarketChip.png](componentes/MarketChip.png) |
| PriceTag | [PriceTag.md](componentes/PriceTag.md) | [PriceTag.png](componentes/PriceTag.png) |
| ProductCard | [ProductCard.md](componentes/ProductCard.md) | [ProductCard.png](componentes/ProductCard.png) |
| ScanFrame | [ScanFrame.md](componentes/ScanFrame.md) | [ScanFrame.png](componentes/ScanFrame.png) |
| ScanNavBar | [ScanNavBar.md](componentes/ScanNavBar.md) | [ScanNavBar.png](componentes/ScanNavBar.png) |
| ScanTray | [ScanTray.md](componentes/ScanTray.md) | [ScanTray.png](componentes/ScanTray.png) |
| SearchBar | [SearchBar.md](componentes/SearchBar.md) | [SearchBar.png](componentes/SearchBar.png) |
| ShoppingBar | [ShoppingBar.md](componentes/ShoppingBar.md) | [ShoppingBar.png](componentes/ShoppingBar.png) |
| ShoppingList | [ShoppingList.md](componentes/ShoppingList.md) | [ShoppingList.png](componentes/ShoppingList.png) |
| Skeleton | [Skeleton.md](componentes/Skeleton.md) | [Skeleton.png](componentes/Skeleton.png) |
| StockStepper | [StockStepper.md](componentes/StockStepper.md) | [StockStepper.png](componentes/StockStepper.png) |
| Cover | | [Cover.png](componentes/Cover.png) |
