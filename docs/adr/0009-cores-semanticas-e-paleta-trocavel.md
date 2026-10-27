# 0009. Usar cores semânticas, com a paleta trocável num lugar só

- Status: Aceito
- Data: 2026-10-27

## Contexto

A paleta do Bipa mudou várias vezes durante o protótipo: vermelho e âmbar, petróleo, terracota, lima, tema escuro e, por fim, o amarelo da etiqueta sobre o claro. Ela ainda pode mudar. Os tokens antigos têm nome de cor (`red`, `amber`), o que obriga a renomear código quando a marca deixa de ser vermelha, e cor escrita direto nos widgets torna a troca um trabalho de busca e substituição.

## Decisão

- **Os tokens têm nome de função, não de cor:** `brand`, `onBrand`, `brandSoft`, `alert`, `onAlert`, `alertSoft`, `positive`, `place`, `price` (a etiqueta), `ground`, `surface`, `surfaceSunken`, `line`, `ink`, `inkMuted`. Trocar a marca de vermelho para amarelo não muda nenhum nome no código.
- **A paleta é uma fonte só:** as cores ficam em um único arquivo, `lib/core/design_system/bipa_palette.dart`, com uma instância por tema (`BipaPalette.light`, `BipaPalette.dark`). De preferência, esse arquivo é gerado a partir do `tokens.json` do design system, para o código e o Claude não divergirem.
- **`BipaColors` é um `ThemeExtension`** montado a partir da paleta, com `copyWith` e `lerp` (a troca de tema anima). O `ColorScheme` do Material 3 é derivado da mesma paleta: `brand` vira `primary`, e assim por diante.
- **Widgets só leem cores do tema:** `context.colors.brand`. Nenhum `Color(0xFF...)` ou `Colors.red` fora de `bipa_palette.dart`. Uma regra própria com `custom_lint`, ou uma busca por `Color(0x` no CI, aponta as exceções.
- **Contraste vem junto:** cada cor de fundo tem o seu par "on" (`brand`/`onBrand`). Um teste verifica o contraste mínimo de 4,5:1 para texto em todos os pares, nos dois temas.

## Consequências

- Mudar a paleta inteira é editar `bipa_palette.dart` (ou o `tokens.json` e gerar de novo). Os widgets não mudam.
- Um tema alternativo, como o escuro ou um de alto contraste, é só outra instância de `BipaPalette`.
- No design system do Claude, os tokens de cor serão renomeados para os nomes semânticos quando a paleta for aprovada, para os dois lados falarem a mesma língua.
- Exige disciplina na revisão: cor escrita direto num widget é motivo para pedir mudança no pull request.
