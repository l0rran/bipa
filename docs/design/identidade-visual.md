# Identidade visual

A referência completa e interativa (cores nos dois temas, tipografia, componentes com prévia) está no **Bipa Design System**, no Claude:
https://claude.ai/artifact/UgbPTJ2wLHMP5FmPcC7E8G

As telas de referência estão no protótipo **Bipa App Telas**:
https://claude.ai/artifact/Pefns8PVVY8nFXTq8Z6Gd3

Os dois links são privados: compartilhe pelo menu Share de cada página para outras pessoas abrirem.

Este arquivo resume o que o código precisa saber. Se ele e o design system divergirem, o design system vale, e este arquivo e `lib/core/design_system/` devem ser corrigidos.

## Conceito

O corredor do supermercado: a etiqueta amarela de oferta, o laser vermelho do leitor do caixa e o "bip" que diz que deu certo. Vibrante e divertido, mas com poucas coisas fazendo barulho por tela.

## Cores

| Token | Claro | Escuro | Papel |
| --- | --- | --- | --- |
| `ground` | `#F2F7F3` | `#121019` | Fundo das telas |
| `surface` | `#FFFFFF` | `#1C1A27` | Cartões, folhas, navegação |
| `surfaceSunken` | `#E4EEE7` | `#262335` | Campos, chips, trilhos |
| `line` | `#CFDCD3` | `#34304A` | Divisórias |
| `ink` | `#1A1630` | `#F3F1FF` | Texto e contorno adesivo |
| `inkMuted` | `#5B5770` | `#ABA6C2` | Texto secundário |
| `green` | `#00B865` | `#2EE68A` | Marca, ação principal |
| `onGreen` | `#1A1630` | `#0B1F14` | Texto sobre `green` |
| `greenText` | `#007A43` | `#2EE68A` | Verde em texto (menor preço) |
| `greenSoft` | `#D8F5E6` | `#173726` | Fundo de confirmação |
| `yellow` | `#FFD23F` | `#FFD84D` | **Só preço e oferta** |
| `onYellow` | `#1A1630` | `#1A1630` | Texto sobre `yellow` |
| `tomato` | `#FF5A3C` | `#FF6F52` | Laser, acabando, excluir |
| `tomatoText` | `#C7341A` | `#FF8A70` | Tomate em texto |
| `tomatoSoft` | `#FFE3DC` | `#40201A` | Fundo de "Acabando" |
| `grape` | `#5B3DF5` | `#A08BFF` | Lugar: mercados, distância |
| `onGrape` | `#FFFFFF` | `#121019` | Texto sobre `grape` |
| `grapeSoft` | `#ECE8FF` | `#2C2552` | Fundo de chips de lugar |

Mapeamento para o `ColorScheme` do Material 3: `primary` = `green`, `onPrimary` = `onGreen`, `secondary` = `grape`, `error` = `tomatoText`, `surface` = `surface`, e o fundo do `Scaffold` = `ground`.

## Tipografia

| Estilo | Fonte | Tamanho/altura | Peso | Uso |
| --- | --- | --- | --- | --- |
| `priceHero` | Bricolage Grotesque | 44/44 | 800 | Preço na captura |
| `headline` | Bricolage Grotesque | 30/34 | 800 | Título de tela |
| `title` | Bricolage Grotesque | 22/28 | 700 | Seções |
| `price` | Bricolage Grotesque | 20/24 | 800 | Preço em listas |
| `bodyLarge` | Figtree | 17/24 | 600 | Nome de produto |
| `body` | Figtree | 15/22 | 400 | Texto corrido |
| `label` | Figtree | 14/18 | 700 | Botões, abas |
| `caption` | Figtree | 12/16 | 600 | Metadados |
| `barcode` | JetBrains Mono | 13/16 | 500 | Códigos EAN |

Preços sempre com `FontFeature.tabularFigures()`. As três famílias são livres (SIL Open Font License) e vão embutidas em `assets/fonts/`.

## Forma, espaço e elevação

- Espaços: 4, 8, 12, 16, 24, 32. Margem lateral das telas: 16.
- Raios: 10 (chips), 16 (campos), 24 (cartões e folhas), pílula (botões, stepper, navegação).
- **Adesivo:** contorno de 2px em `ink` + sombra sólida `0 3px 0` em `ink`. Só no botão principal, botão de bipar e etiqueta de preço. Pressionado: desce 3px e perde a sombra.
- **Flutuação:** sombra difusa `0 8px 24px` a 14% para folhas e a barra de navegação.

## Ícones e movimento

- Material Symbols Rounded (`Icons.*_rounded`), 24px.
- "Bip" ao salvar ou somar: escala 1 → 1,08 → 1 em 280ms, curva elástica, com `HapticFeedback.lightImpact()`.
- Respeitar `MediaQuery.disableAnimations`: com ele ativo, só fade.

## Voz

Curta, em "você", amigável e sem formalidade. "Bipou!", "Tá acabando", "Mais barato aqui". Botões dizem o que acontece ("Salvar preço", "Usei um"). Mais exemplos no README do design system.
