# Identidade visual

A referência completa e interativa (cores nos dois temas, tipografia, componentes com prévia) está no **Bipa Design System**, no Claude:
https://claude.ai/artifact/UgbPTJ2wLHMP5FmPcC7E8G

As telas de referência estão no protótipo **Bipa App Telas**:
https://claude.ai/artifact/Pefns8PVVY8nFXTq8Z6Gd3

Os dois links são privados: compartilhe pelo menu Share de cada página para outras pessoas abrirem.

Este arquivo resume o que o código precisa saber. Se ele e o design system divergirem, o design system vale, e este arquivo e `lib/core/design_system/` devem ser corrigidos.

## Conceito

O varejo brasileiro: o vermelho das redes de supermercado e o amarelo da etiqueta de oferta, num tom sério e confiável. É um app que cuida do dinheiro de quem usa; a leveza fica na voz e no "bip", não na decoração.

## Cores

| Token | Claro | Escuro | Papel |
| --- | --- | --- | --- |
| `ground` | `#F5F5F6` | `#131317` | Fundo das telas |
| `surface` | `#FFFFFF` | `#1D1D23` | Cartões, folhas, navegação |
| `surfaceSunken` | `#EBEBEE` | `#27272F` | Campos, chips, stepper |
| `line` | `#D9D9DE` | `#35353F` | Divisórias e contorno de secundários |
| `ink` | `#1C1B22` | `#F3F2F6` | Texto e ícones |
| `inkMuted` | `#5E5D68` | `#A9A8B5` | Texto secundário |
| `red` | `#C8102E` | `#FF5A6A` | Marca, ação principal, aba ativa |
| `onRed` | `#FFFFFF` | `#1C1B22` | Texto sobre `red` |
| `redText` | `#B00E28` | `#FF8A95` | Vermelho em texto, erros |
| `redSoft` | `#FBE4E7` | `#3D1A1F` | Fundo da aba ativa |
| `yellow` | `#F6C445` | `#F6C445` | **Só preço** (etiqueta) |
| `onYellow` | `#1C1B22` | `#1C1B22` | Texto sobre `yellow` |
| `amber` | `#E08A00` | `#F2A93B` | Atenção: contador de "acabando" |
| `amberText` | `#9A5B00` | `#F5B95E` | Âmbar em texto |
| `amberSoft` | `#FDF0D9` | `#3A2A12` | Fundo de "Acabando" |
| `slate` | `#34507A` | `#8FA9D6` | Lugar: mercados, distância |
| `onSlate` | `#FFFFFF` | `#131317` | Texto sobre `slate` |
| `slateSoft` | `#E6ECF5` | `#232C3D` | Fundo de chips de lugar |
| `greenText` | `#1A7A4A` | `#5FD69A` | Economia: menor preço |
| `greenSoft` | `#DFF3E8` | `#17301F` | Fundo do selo de menor preço |

Mapeamento para o `ColorScheme` do Material 3: `primary` = `red`, `onPrimary` = `onRed`, `secondary` = `slate`, `error` = `redText`, `surface` = `surface`, e o fundo do `Scaffold` = `ground`.

O vermelho é a marca, não sinal de erro. Erros usam `redText` sempre com ícone e mensagem; ações destrutivas pedem confirmação.

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

## Ícones e movimento

- Material Symbols Rounded (`Icons.*_rounded`), 24px.
- "Bip" ao salvar ou somar: escala 1 → 1,04 → 1 em 200ms, com `HapticFeedback.lightImpact()`.
- Respeitar `MediaQuery.disableAnimations`: com ele ativo, só fade.

## Voz

Direta, em "você", cordial e sem gírias. "Bipou!", "Acabando", "Mais barato aqui". Botões dizem o que acontece ("Salvar preço", "Usei um"). Mais exemplos no README do design system.
