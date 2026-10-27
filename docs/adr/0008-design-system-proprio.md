# 0008. Criar um design system próprio sobre o Material 3

- Status: Aceito
- Data: 2026-10-27

## Contexto

O protótipo usava o Material 3 padrão com uma cor semente, o que deixa o app genérico. A proposta do Bipa pede uma identidade vibrante e divertida, mas os componentes do Material (acessibilidade, campos, navegação) continuam valiosos.

## Decisão

- A identidade fica documentada no [Bipa Design System](../design/identidade-visual.md): cores, tipografia, forma, movimento, voz e componentes.
- No código, `lib/core/design_system/` traduz os tokens: um `ThemeExtension` (`BipaColors`) com as cores da marca, o `ColorScheme` do Material 3 derivado deles, `TextTheme` com as fontes da marca e constantes de espaçamento e raio.
- Componentes próprios (`BipaButton`, `PriceTag`, `StockStepper`, `MarketChip`, `ScanNavBar`) ficam no design system; telas de features só os combinam.
- Fontes embutidas como assets do app (o app é offline). Nada de baixar fontes em tempo de execução.

## Consequências

- Mudar uma cor ou raio é trocar um token, não procurar valores espalhados.
- Componentes do Material continuam funcionando com a aparência do Bipa, via tema.
- O design system no Claude e o código precisam andar juntos: mudanças de token são feitas nos dois, no mesmo pull request.
