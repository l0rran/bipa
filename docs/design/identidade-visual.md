# Identidade visual

A referência completa e interativa (cores nos dois temas, tipografia, componentes com prévia) está no **Bipa Design System**, no Claude:
https://claude.ai/artifact/UgbPTJ2wLHMP5FmPcC7E8G

As telas de referência estão no protótipo **Bipa App Telas**:
https://claude.ai/artifact/Pefns8PVVY8nFXTq8Z6Gd3

Os dois links são privados: compartilhe pelo menu Share de cada página para outras pessoas abrirem. Para quem não tem acesso, incluindo agentes rodando fora do claude.ai, há uma cópia exportada no repositório: [design-system/](design-system/README.md), com os guias e as imagens dos componentes, e [prototipo/](prototipo/README.md), com a imagem e o HTML de cada tela.

Este arquivo resume o que o código precisa saber. Se ele e o design system divergirem, o design system vale, e este arquivo e `lib/core/design_system/` devem ser corrigidos.

## Conceito

A etiqueta de oferta do varejo brasileiro: o amarelo do preço é a cor da marca, sobre uma base clara e neutra, num tom calmo e confiável. É um app que cuida do dinheiro de quem usa e o preço é o herói; a leveza fica na voz e no "bip", não na decoração.

## Calma por padrão

Cada coisa só ganha atenção quando precisa:

- **Um destaque por tela.** No máximo um elemento com ênfase, seja um cartão de insight ou um botão cheio.
- **Um sinal por informação.** Se o item está na seção "Acabando", a linha não repete o estado com selo, barra e cor de fundo.
- **Um acento por tela.** Cada tela tem uma cor de destaque, e o resto é neutro. Na Casa, o amarelo (`brand`) fica para as ações de marca (o botão de bipar, "Ir às compras" e a barra da compra), o coral (`alert`) só marca o que está abaixo do "ter sempre", e todo o resto (locais, "+", "na lista", régua, links) fica em `ink` e cinzas. O verde (`positive`) é da economia e o azul-ardósia (`place`) é dos mercados, cada um no seu lugar.
- **Controles aparecem ao tocar.** Em repouso, as linhas mostram só informação. O −/+ e o "Pôr na lista" abrem no item tocado, e o uso mais comum ("Usei um") também é um gesto de deslizar.
- **Números como números.** O que decide uma ação (há quanto tempo comprou, de quanto em quanto tempo compra, quanto tem em casa) aparece como número com rótulo, nunca escondido no meio de uma frase.
- **Textos inteiros.** Nomes de produto quebram em até duas linhas em vez de serem cortados, e a medida nunca fica sozinha na linha de baixo ("395 g" usa espaço inseparável).

### Todo texto precisa se justificar

Antes de pôr um texto na tela, responda três perguntas:

1. **É o lugar dele?** Talvez ele pertença a outra tela, ao detalhe do produto ou ao ⓘ.
2. **É necessário?** Se outro elemento já diz o mesmo (a seção, a régua, o medidor, a arte), o texto sai.
3. **Dá para dizer de outra forma sem prejudicar a compreensão?** Por exemplo, com ícone, número, cor, forma, posição ou um componente que já existe.

Limites: rótulos da navegação e de ações que apagam algo ficam com texto, não se troca texto por ícone ambíguo, e todo elemento visual tem rótulo acessível. Como na home do iFood, quase não há texto solto. Quando o componente é só texto, a tipografia faz o trabalho: uma linha pequena e o essencial grande.

Referências: os redesenhos do Linear e do Shortcut em 2025 ("não dispute uma atenção que você não conquistou") e os testes do Flo (indicadores rápidos de ler funcionaram melhor que gráficos detalhados). O processo e as demais referências estão em [processo.md](processo.md).

## Cores

Os tokens têm nome de função, não de cor ([ADR 0009](../adr/0009-cores-semanticas-e-paleta-trocavel.md)). No Flutter, todos ficam em `lib/core/design_system/bipa_palette.dart`, e trocar a paleta é editar esse arquivo.

| Token | Claro | Escuro | Papel |
| --- | --- | --- | --- |
| `ground` | `#F5F5F3` | `#0D0E11` | Fundo das telas |
| `surface` | `#FFFFFF` | `#17191D` | Cartões, folhas, navegação |
| `surfaceSunken` | `#EDEDEA` | `#22252B` | Campos, miniaturas, stepper |
| `line` | `#DCDCD7` | `#2D3138` | Divisórias, contornos, medidor em dia |
| `ink` | `#1C1B1F` | `#F3F3F5` | Texto, ícones e botões neutros |
| `inkMuted` | `#5F5E66` | `#9EA2AA` | Texto secundário |
| `brand` | `#F6C445` | `#F6C445` | Marca: bipar, botão principal, barra da compra |
| `onBrand` | `#1C1B1F` | `#1C1B1F` | Texto sobre `brand` (escuro) |
| `brandText` | `#7A5800` | `#F6C445` | A marca em texto sobre fundo claro |
| `brandSoft` | `#FDF1CF` | `#3A3015` | Fundo da aba ativa |
| `price` | `#F6C445` | `#F6C445` | Etiqueta de preço (igual à marca) |
| `onPrice` | `#1C1B1F` | `#1C1B1F` | Texto sobre a etiqueta |
| `alert` | `#E8573A` | `#FF7B66` | Alerta: abaixo do "ter sempre" |
| `onAlert` | `#1C1B1F` | `#1C1B1F` | Texto sobre `alert` |
| `alertText` | `#B8402A` | `#FF8F7D` | Alerta em texto, erros |
| `alertSoft` | `#FCE4DD` | `#3D1E19` | Fundo de selos de alerta |
| `place` | `#34507A` | `#8FA9D6` | Lugar, só na tela de mercados |
| `onPlace` | `#FFFFFF` | `#131317` | Texto sobre `place` |
| `placeSoft` | `#E6ECF5` | `#232C3D` | Fundo de destaques de lugar |
| `positiveText` | `#1A7A4A` | `#5FD69A` | Economia: menor preço |
| `positiveSoft` | `#DFF3E8` | `#17301F` | Fundo do selo de economia |

Mapeamento para o `ColorScheme` do Material 3: `primary` = `brand`, `onPrimary` = `onBrand`, `error` = `alertText`, `surface` = `surface`, e o fundo do `Scaffold` = `ground`.

O amarelo nunca é usado como texto sobre fundo claro, porque não tem contraste: sobre ele vai sempre texto escuro (`onBrand`), e quando a marca precisa aparecer em texto usa `brandText`. Erros usam `alertText` sempre com ícone e mensagem; ações destrutivas pedem confirmação. O tema escuro existe nos tokens, mas o app nasce no claro.

### Logo

O símbolo é um bloco amarelo (`brand`) com quatro barras de código em `ink`, cortadas por uma linha coral (`alert`): o laser do leitor.

## Tipografia

| Estilo | Fonte | Tamanho/altura | Peso | Uso |
| --- | --- | --- | --- | --- |
| `priceHero` | Manrope | 44/48 | 800 | Preço na captura |
| `headline` | Manrope | 28/34 | 800 | Título de tela |
| `title` | Manrope | 20/26 | 700 | Seções |
| `price` | Manrope | 20/24 | 800 | Preço em listas |
| `bodyLarge` | Figtree | 17/24 | 600 | Nome de produto |
| `body` | Figtree | 15/22 | 400 | Texto corrido |
| `label` | Figtree | 14/18 | 700 | Botões, abas |
| `caption` | Figtree | 12/16 | 600 | Metadados |
| `barcode` | JetBrains Mono | 13/16 | 500 | Códigos EAN |

Preços sempre com `FontFeature.tabularFigures()`. As três famílias são livres (SIL Open Font License) e vão embutidas em `assets/fonts/`.

## Forma, espaço e elevação

- Espaços: 4, 8, 12, 16, 24, 32. Margem lateral das telas: 16.
- Raios: 8 (chips), 14 (campos), 20 (cartões e folhas), pílula (botões, stepper, navegação).
- **Elevada:** sombra suave `0 2px 6px` a 16%, só no botão principal, botão de bipar e etiqueta de preço. Pressionado: desce 1px e perde a sombra.
- **Flutuante:** sombra `0 8px 24px` a 12% para folhas e a barra de navegação.
- Botões secundários: contorno de 1,5px em `line`. Cartões de lista sem sombra.

## Ícones

Material Symbols Rounded (`Icons.*_rounded`), 24px.

## Movimento

Tudo que muda de estado anima, e nada passa de 600ms. No código, estes valores ficam em `BipaMotion`.

| Token | Valor | Uso |
| --- | --- | --- |
| `durationFast` | 120ms | Resposta ao toque |
| `durationBase` | 220ms | Troca de estado, números rolando |
| `durationSlow` | 380ms | Entradas, folhas, indicador da aba |
| `durationCelebrate` | 600ms | "Bipou!" e contagem do preço |
| `easingStandard` | `Cubic(0.2, 0, 0, 1)` | Padrão |
| `easingSpring` | `Cubic(0.34, 1.56, 0.64, 1)` | Mola: toques, números, indicadores |
| `easingExit` | `Cubic(0.3, 0, 1, 1)` | Saídas |

Padrões que os widgets do design system implementam:

- **Toque:** controles encolhem para 88–96% com mola e voltam ao soltar.
- **Números rolam:** quantidade e preço trocam com rolagem vertical (`AnimatedSwitcher` com `SlideTransition`); o preço lido conta de 0 até o valor.
- **Indicadores deslizam:** a aba ativa da navegação desliza com mola até o destino.
- **Botão principal com estados:** normal, carregando e concluído (check desenhado), sem mudar de largura.
- **BipFeedback:** ao salvar um preço, círculo verde com mola, check desenhado, onda e aviso "Bipou!", com `HapticFeedback.lightImpact()`.
- **Listas** entram em cascata (60ms entre itens); **folhas** sobem com mola.
- **Skeleton** com brilho no formato do conteúdo, só se a espera passar de 200ms.
- Com `MediaQuery.disableAnimations`, as animações viram cortes ou fades.

## Componentes

A referência de comportamento de cada um são as prévias interativas do design system (o `bundle.js` define as animações em JavaScript, que o Flutter reproduz).

| Componente | No Flutter | Resumo |
| --- | --- | --- |
| Button | `BipaButton`, `BipaSegmented` | Principal, secundário, tonal e neutro. A forma muda ao pressionar, o carregamento usa as barras do símbolo, e há um seletor segmentado |
| PriceTag | `PriceTag` | Etiqueta amarela: normal com preço por unidade, de/por, no app/clube, leve X pague Y e menor preço |
| SearchBar | `BipaSearchBar` | Busca no topo com o botão de bipar dentro |
| ListPreview | `ListPreview`, `SectionHeader` | A lista na Casa: miniaturas, quantidade, total estimado e "Ir às compras"; cabeçalho de seção com contagem e "Ver tudo" |
| ShoppingBar | `ShoppingBar` | A compra em andamento, fixa acima da navegação: progresso e total bipado |
| FilterChips | `PlaceFilter` | Locais como categorias com arte (Casa) ou chips (listas longas) |
| ProductCard | `ProductCard` | Prateleira de Acabando: imagem, medidor no canto e "+" |
| StockStepper | `StockList`, `StockGauge`, `StockStepper` | Lista do estoque com miniatura, nome e medidor de nível; tocar abre −/+ e "Pôr na lista"; deslizar dá baixa |
| InsightCard | `InsightCard`, `BipaCarousel` | Carrossel: "Hora de repor" (título tipográfico com arte, régua do ciclo e três números) e "Economia do mês"; fonte no ⓘ |
| MarketChip | `MarketChip` | Mercado e distância, com destaque quando você está nele |
| ScanNavBar | `ScanNavBar` | Barra de vidro com o botão de bipar; o toque longo abre o menu |
| ScanFrame e ScanTray | `ScanFrame`, `ScanTray` | Visor que trava no código e bandeja do modo carrinho com o total |
| BipFeedback | `BipFeedback` | "Bipou!" com Desfazer por 4s |
| ShoppingList | `ShoppingList` | Adicionar com um toque e lista na ordem dos corredores |
| Skeleton | `Skeleton` | Placeholder com brilho |

O medidor de nível compara a quantidade com o **"ter sempre"** (hoje `minimumQuantity`): o item está acabando quando fica **abaixo** desse número. Ao implementar, `StockItem.isLow` passa de `quantity <= minimum` para `quantity < minimum`, e o texto "mínimo" vira "ter sempre".

## Voz

Direta, em "você", cordial e sem gírias. "Bipou!", "Acabando", "Mais barato aqui". Botões dizem o que acontece ("Salvar preço", "Usei um"). Erros dizem o que aconteceu e o que fazer em seguida, sempre com uma saída. Mais exemplos no README do design system.
