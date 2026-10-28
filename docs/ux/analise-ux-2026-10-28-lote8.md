# Análise de UX do Bipa (lote 8)

> Análise feita no commit `3972e8e`, sobre o que entrou depois de `bafcacc`: local sugerido pela categoria (AB5, parte), exceções do domínio pelo ARB (H2), letra grande (H3), barra de navegação que encolhe ao rolar, granel com o preço por kg na bandeja (D3) e as correções da compilação. Os caminhos, as linhas e o "o que a pessoa vive" descrevem o app desse commit. O que já foi feito fica no [CHANGELOG](../../CHANGELOG.md), e o que falta, em [roadmap.md](../roadmap.md#ajustes-de-ux-análise-de-28102026). A análise anterior, com os códigos AB1 a H7, está em [analise-ux-2026-10-28.md](analise-ux-2026-10-28.md).

Oct 28, 2026 · @Wesley

## Resumo

O lote fecha o que prometia: o granel entra na bandeja, a letra a 200% não estoura nenhuma tela principal, os erros do domínio vêm do ARB e a barra encolhe como no design system. Os problemas novos estão nas bordas dessas mesmas mudanças:

1. **O valor pago pelo granel vira preço por kg no histórico (D8, alto).** A linha do granel convida a digitar o que se pagou, e o carrinho grava esse total como observação do produto, contra o que o ADR 0018 decidiu.
2. **A estimativa do granel parece o preço da linha (D9, médio).** O "R$ 8,99/kg" ocupa o lugar do valor, com o mesmo contorno do preço estimado que entra no total, e o leitor de tela diz "estimado" de um preço lido hoje.
3. **O local sugerido erra itens comuns, em silêncio (AB9, médio).** Leite de caixinha e atum em lata vão para a Geladeira, congelados vão para a Despensa, e nada diz onde o item foi parar.
4. **Letra grande: a navegação corta e os nomes perdem para os preços (H8, H9, médio).** Os rótulos da barra são cortados a partir de uns 120% num celular de 360 dp, a barra compacta os tira de vez, e na bandeja e na lista o nome do produto vira "Café / torr…" para o preço caber.

O primeiro é barato e protege dado: vale fazer antes do resto. O segundo e o quarto pedem quadro no protótipo antes do código.

## Situação dos achados anteriores

Dos 36 achados da análise anterior, 30 estão resolvidos, 4 parciais e 2 abertos. Nenhum regrediu, mas dois dos resolvidos neste lote abriram achados novos (D3 → D8 e D9; H3 → H8 e H9). Os marcados "conferido" foram lidos no código deste commit; os demais vêm do CHANGELOG e foram conferidos por amostra.

| ID | Achado anterior | Situação | O que mudou |
| --- | --- | --- | --- |
| AB1 | "Usei um" e "Comprei um" diferentes por controle | Resolvido (conferido) | Stepper com "Uma embalagem a menos/a mais". O aviso ao fechar a linha só aparece no toque (`estado.md`). |
| AB2 | "Comprei" só com a casa vazia | Resolvido (conferido) | "Guardar em casa" no menu do bipar (`home_shell.dart`). |
| AB3 | "Usei um" tira a linha de vista | Resolvido | A linha fica enquanto o aviso aparece; com TalkBack o aviso não expira (`estado.md`). |
| AB4 | Deslizar para a direita sem aviso | Resolvido | Aviso com Desfazer. |
| AB5 | Primeira carga deixa locais sem uso | Parcial | Local pela categoria; erra itens comuns e não se mostra (AB9, AB10). Falta a folha "Arrumar o que entrou". |
| AB6 | Chip "Ter sempre" é a única porta | Resolvido (conferido) | Botão "⋯ Mais do item" no editor da linha. |
| AB7 | Casa vazia abre o modo de preço | Resolvido (conferido) | O aviso de espera da câmera oferece "Guardar em casa" (`camera_page.dart:363`). |
| AB8 | Guia do cartão diverge | Resolvido | `ProductCard.md` atualizado. |
| CE1 | Preços sem mercado perdidos | Resolvido (conferido) | Tabela `trip_prices` (ADR 0020). |
| CE2 | Marcado antes entra no estoque | Resolvido (conferido) | `isCheckedSince` no fim e no cancelamento. |
| CE3 | "3×" sai inteiro com um bipe | Resolvido (conferido) | "1 de 3" na bandeja e na lista. |
| CE4 | Totais ignoram o sem preço | Resolvido | "sem preço de N" na bandeja e na prévia. |
| CE5 | Chip mostra um mercado que a compra não usa | Resolvido | A compra começa no mercado do chip. |
| CE6 | Quantidade só no toque longo | Resolvido (conferido) | `list_entry_text.dart` entende "2 leite". |
| CE7 | Acabamentos da compra | Resolvido | "a menos que em", "8 no carrinho", cancelar na folha. |
| D1 | Trocar de mercado deixa preços no errado | Resolvido (conferido) | "Levar os N preços lidos para…?" |
| D2 | Disparo abre o formulário antigo | Resolvido (conferido) | `capture_price_page.dart` saiu; uma câmera só. |
| D3 | Granel não entra no carrinho | Resolvido, com achados novos | Entra na bandeja com o preço por kg (D8, D9). |
| D4 | A mesma etiqueta vai para o próximo produto | Resolvido (conferido) | `live_tag_router.dart:127`. |
| D5 | Leitura pela metade sem saída | Resolvido | Avisos de espera viram botão. |
| D6 | Produto da balança errado sem correção | Resolvido (conferido) | `_swapWeighed`; ressalvas em `estado.md`. |
| D7 | Acabamentos do carrinho | Resolvido | Alça com direção, um sinal de estimado, Desfazer no visor. |
| F1 | Duas idades com o mesmo nome | Resolvido | "atualizado há N dias" e idade só a partir de 30 dias. |
| F2 | Barra curta contradiz o selo | Resolvido | Sem barra para o incompleto. |
| F3 | Preço errado só se corrige no carrinho | Resolvido (conferido) | `price_sheet.dart` com "Corrigir o preço". |
| F4 | Preço em destaque sem onde nem quando | Resolvido | Mercado e idade a partir de 30 dias. |
| G1 | "Editar" muda a embalagem mais recente | Resolvido (conferido) | "Editar produto" e "Editar embalagem". |
| G2 | Embalagem no produto errado | Aberto | No roadmap, com ADR. |
| G3 | "Registrar preço" escolhe a embalagem | Resolvido | Pergunta quando há mais de uma. |
| H1 | Abas com dois visuais | Aberto (conferido) | `products_page.dart` ainda usa `AppBar` e `SearchBar` do Material. |
| H2 | Erros sem saída e fora do ARB | Parcial (conferido) | `DomainErrorCode` + `domainErrorText`; o stepper do produto avisa. O mesmo stepper no Início e na folha do item segue calado (H11). |
| H3 | Alturas fixas com texto dentro | Parcial (conferido) | Mínimas no lugar de fixas e teste a 200%. A navegação corta e os nomes elidem (H8, H9, H10). |
| H4 | Leitor de tela lê sinais ao pé da letra | Resolvido | "o quilo", "não definido", nome do produto como título. |
| H5 | Linhas que parecem levar a algum lugar | Resolvido | Comparação e alfinetes abrem o mercado. |
| H6 | "Apagar" no botão amarelo | Resolvido (conferido) | `confirmDestructive` nos quatro diálogos. |
| H7 | Idade negativa | Resolvido (conferido) | `calendarDaysSince` em todas as telas. |

## Problemas por jornada

Caminhos relativos ao repositório. Tudo foi avaliado lendo o código, sem compilar. Gravidade: crítico perde dado ou bloqueia a tarefa; alto é dado errado ou caminho principal confuso; médio é atrito; baixo é acabamento. "Provável" quando o efeito depende de rodar o app.

### A e B. Primeira carga e em casa

**AB9. O local sugerido erra itens comuns e não diz onde pôs o item (médio).**

- **Onde:** `lib/features/stock/domain/suggested_location.dart`, que mapeia o `ProductKind` (`lib/core/catalog/product_kind.dart`) para o local; o teste `test/features/stock/domain/suggested_location_test.dart` fixa "Leite integral 1 L" e "Atum" na Geladeira. O aviso do visor em "Guardar em casa" diz só "Leite · 12 em casa" (`cameraAtHome`).
- **O que a pessoa vive:** na primeira carga, bipa o fardo de leite de caixinha, duas latas de atum, uma de sardinha, o Ovomaltine e a lasanha congelada. Leite, atum, sardinha e Ovomaltine ("ovo" casa com o começo da palavra) vão para a Geladeira; a lasanha ("lasanha" é massa) e o frango congelado ("frango" é carne, Geladeira) não chegam ao Freezer, que só recebe sorvete. Ela descobre ao filtrar por Despensa e não achar o leite. Para corrigir, abre cada linha, toca "⋯" e escolhe o local: três toques por item.
- **Por que importa:** o leite de caixinha é o item mais repetido da lista, e errá-lo a cada compra de um produto novo ensina que o filtro de locais não é confiável. A sugestão silenciosa é a "categoria automática sem revisão" que as avaliações do Pantry Check criticam (`processo.md`).
- **O que fazer:** antes do `ProductKind`, palavras que decidem o local sozinhas: "congelad" vai para o Freezer; "longa vida", "UHT", "em pó", "de coco", "lata" e "enlatad" vão para a Despensa; "atum" e "sardinha" saem da Geladeira. Corrigir o teste. E dizer onde o item entrou: o aviso do visor vira "Leite · 12 na Geladeira", e tocar no local abre a escolha (a mesma `Wrap` de `ChoiceChip` da folha do item). Assim a correção acontece na hora, sem lote de arrumação.

**AB10. A folha do item mostra Despensa, e o item nasce em outro lugar (baixo).**

- **Onde:** `lib/features/stock/presentation/stock_item_sheet.dart:84-90`: sem item em casa, o marcador de posição usa `StockLocation.pantry`; o repositório cria com `_suggestedLocationFor` (`drift_stock_repository.dart:263`). E `remove` apaga a linha do estoque, junto com o local escolhido.
- **O que a pessoa vive:** na tela do Leite, que nunca esteve em casa, toca em "Em casa". A folha marca "Despensa". Ela toca no "+", e o chip pula para "Geladeira" sem ela ter tocado nele. Em outro caso, corrige o atum para Despensa, usa "Tirar de casa" quando acaba, e na próxima compra ele volta para a Geladeira.
- **O que fazer:** usar `suggestedLocation(product.name)` no marcador de posição da folha. Ao tirar de casa, guardar o local escolhido (zerar a quantidade e esconder, ou lembrar o local por produto), como o Grocy faz com o local padrão do produto.

### D. Câmera do bipar e modo carrinho

**D8. O valor digitado do granel ou da pesagem entra no histórico como preço do produto (alto).**

- **Onde:** `lib/features/shopping_list/presentation/cart_mode_page.dart` (`_typePrice`, chamado por `onPriceTap` de toda linha da bandeja) → `RecordTripPrice` (`record_trip_price.dart`), que sempre chama `RegisterPriceObservation` quando a compra tem mercado. O `perKilo` só existe no `TripPrice`; a observação gravada não sabe se o valor é por kg, por pacote ou o total de uma pesagem.
- **O que a pessoa vive:** lê "TOMATE ITALIANO R$ 8,99 o kg" e escolhe o produto. A bandeja ganha "Tomate italiano · R$ 8,99/kg" e o total diz "sem preço de 1 item". O tomate é pesado no caixa (o caso que o ADR 0018 descreve), e ela paga R$ 12,40 por 1,38 kg. Toca na etiqueta da linha, que abre "Digitar o preço", e digita 12,40. O carrinho fica certo, mas o histórico do tomate naquele mercado ganha uma observação manual de R$ 12,40, mais recente que a de R$ 8,99. Como o produto é vendido por kg, a tela do produto e a comparação de Mercados passam a tratar o tomate como R$ 12,40/kg (provável: depende de como o produto sem embalagem é exibido). O mesmo vale para corrigir o valor de uma etiqueta da balança que grava o peso.
- **Por que importa:** dado errado e silencioso no centro do app, e contra a decisão escrita no ADR 0018 ("O valor da pesagem não vira observação de preço"). Este lote tornou o caminho natural: a etiqueta da linha mostra um número e convida ao toque.
- **O que fazer:** na linha sem embalagem de um produto por peso (a do granel e a da pesagem), digitar o preço só firma o valor do carrinho e guarda o `TripPrice` como pesagem, sem observação. Um parâmetro em `RecordTripPrice` (por exemplo `weighing: true`) que pula o `_register`, com teste. O título do diálogo pode dizer "Quanto deu o Tomate italiano?" para separar do preço da gôndola.

**D9. O preço por kg ocupa o lugar do valor da linha, com o sinal do preço estimado (médio).**

- **Onde:** `cart_mode_page.dart` (o `price` da linha do granel vira `pricePerKilo`, e `priceEstimated` fica verdadeiro), `ScanTrayItem` em `lib/core/design_system/components/scan_tray.dart` (a etiqueta vazada é documentada como "o preço do histórico, não o lido hoje") e o rótulo `cartPricePerKiloEstimated` ("R$ 8,99 por quilo, estimado").
- **O que a pessoa vive:** a bandeja mostra "Leite R$ 5,99" vazado (do histórico, somado ao total com "≈") e, duas linhas abaixo, "Tomate italiano R$ 8,99/kg" com o mesmo contorno, mas fora do total. Quem confere a soma de cabeça conta o tomate. Com TalkBack, ouve "R$ 8,99 por quilo, estimado", quando o R$ 8,99 foi lido agora e o que falta é o peso. Tocar no nome do tomate abre "Quantidade", e "2× Tomate italiano" entra em casa como duas embalagens.
- **Por que importa:** um sinal com dois sentidos opostos (Nielsen 4) e uma estimativa que parece valor pago, o risco que a tarefa pedia para vigiar. A linha não tem quadro no protótipo, então o código decidiu sozinho.
- **O que fazer:** a etiqueta da linha fica para o valor da linha: no granel, "—" para digitar, como qualquer item sem preço. O "R$ 8,99/kg" desce para uma linha discreta sob o nome ("R$ 8,99/kg · pesa no caixa"), e o leitor de tela ouve "Tomate italiano, 8,99 o quilo, falta o valor da pesagem". O toque no nome do granel não abre quantidade (uma pesagem é sempre uma). Desenhar o quadro "Modo carrinho: granel na bandeja" antes.

### H. Consistência e acessibilidade

**H8. Os rótulos da navegação cortam com letra grande, e a barra compacta os tira de vez (médio).**

- **Onde:** `lib/core/design_system/components/scan_nav_bar.dart` (`_Destination`: `Text` com `maxLines: 1` e o corte padrão, em `Expanded` de `(largura − 24 − 76) / 4`, 65 dp num celular de 360 dp) e `lib/app/home_shell.dart` (`ScanNavBarCompactController`). O teste `test/accessibility/large_text_test.dart` deixa a barra de fora, dito no próprio comentário.
- **O que a pessoa vive:** com a fonte do Android em 130% num Galaxy A de 360 dp, a barra mostra "Início", "Produt", "Merca", "Lista" (provável a partir de uns 120%). Ao rolar o Início, os rótulos somem por completo, e só voltam ao rolar para cima. Durante a compra, a barra da compra cresce para duas linhas por rótulo com letra grande (`ShoppingBar`, `lines = 2`), e as duas barras juntas passam de um terço da tela; encolher devolve só 20 px, porque o espaço da barra no layout não muda.
- **Por que importa:** o `CLAUDE.md` pede texto na navegação, e quem aumenta a letra é quem mais precisa dele. A troca da barra compacta (rótulos por espaço) quase não paga: o conteúdo continua reservando a altura da barra normal.
- **O que fazer:** com `textScaler` acima de 1,3 ou com `MediaQuery.accessibleNavigation`, a barra não encolhe. Os rótulos usam `ShrinkToFit` (são quatro palavras curtas e fixas) em vez de cortar. Na compra, a barra compacta pode recolher a barra da compra para uma linha só (total e progresso), como o acessório que vai para dentro da barra minimizada no iOS 26. Incluir a `ScanNavBar` no teste de letra grande.

**H9. Com letra grande, o nome do produto perde para o preço (médio, provável).**

- **Onde:** `ScanTrayItem` (`scan_tray.dart`: nome com `maxLines: 2` e reticências; etiqueta com até 45% da linha), `ShoppingListRow` (`shopping_list.dart`: nome com `maxLines: 2`; preço até 35% e quantidade até 30%) e `StockGauge` (`stock_gauge.dart`: o número cabe no anel de tamanho fixo e não cresce).
- **O que a pessoa vive:** a 200% num celular de 360 dp, o nome na bandeja fica com uns 64 dp ao lado de "R$ 27,90" e do interruptor: "1 de 3 / Leite…", "Café / torr…". Na lista, "Detergente líquido neutro" vira "Deter / gente…". O preço, que encolhe até caber, fica legível; o nome, que diz o que é, não. No Início, o número do medidor fica do tamanho de sempre, por mais que a letra cresça.
- **Por que importa:** contradiz "Textos inteiros" da identidade visual (nomes quebram em até duas linhas em vez de serem cortados, na letra normal) e a meta do WCAG 1.4.4. Na loja, a pessoa precisa saber qual linha desligar ou corrigir.
- **O que fazer:** acima de 1,3, as linhas da bandeja e da lista empilham: o nome inteiro na primeira linha, sem limite, e preço e interruptor na segunda, como o `Wrap` já faz nos botões. O medidor do Início ganha o número fora do anel com letra grande, ou o anel cresce junto.

**H10. O teste de letra grande mede estouro, não leitura (baixo).**

- **Onde:** `test/accessibility/large_text_test.dart`: largura de 411 dp, só falha com `RenderFlex overflow`, sem a barra de navegação, sem o carrinho inteiro, a câmera e os formulários (estes já no roadmap como "H3 (formulários)").
- **O que a pessoa vive:** nada diretamente; mas H8 e H9 passam no teste, porque reticência, corte com `maxLines` e `FittedBox` não são erros de layout.
- **O que fazer:** rodar também a 360 dp; procurar `RenderParagraph` com `didExceedMaxLines` nos nomes de produto e nos rótulos da navegação; montar o `HomeShell` com uma compra em andamento.

**H11. O mesmo stepper falha calado fora da tela do produto (baixo).**

- **Onde:** `home_page.dart` (`_adjust`) e `stock_item_sheet.dart` (`_adjust`, `_setTarget`, os `ChoiceChip` de local): sem `try`, ao contrário de `product_detail_page.dart`, que agora mostra `stockAdjustFailed`.
- **O que a pessoa vive:** com o banco ocupado ou cheio, toca "+" na linha do Início e o número não muda, sem aviso. Na tela do produto, o mesmo toque avisa.
- **O que fazer:** a mesma captura com `stockAdjustFailed` nos dois lugares e no local da folha (um `stockLocationFailed` ou um texto genérico "Não deu para salvar. Tente de novo.").

## Divergências com o design system e o protótipo

O design system vale sobre o código. As três primeiras já estão no roadmap.

- **Barra de navegação:** 72 px no código contra 68 no design system; desfoque 14 contra `blur(18px) saturate(1.5)`; sem o anel que respira no botão de bipar (`bundle.css`, `.bipa-scan::before`, que também precisa parar com movimento reduzido).
- **Histerese da barra compacta:** o design system troca com 4 px de rolagem (`bundle.js:467`), o código com 8. A diferença é razoável no toque, mas o `ScanNavBar.md` deveria registrá-la.
- **Barra compacta com letra grande e com TalkBack:** o design system não diz o que acontece. Proposta em H8.
- **Linha do granel na bandeja:** sem quadro no protótipo (`ModoCarrinhoGranel.png` só mostra o aviso). O roadmap pede para desenhar "a linha do granel com o preço por kg estimado"; a proposta é desenhar já a versão de D9, com o preço por kg sob o nome.
- **Etiqueta vazada:** o `ScanTray.md` não define o vazado; o código o usa para "preço do histórico" e para "preço por kg". Escrever no guia um sentido só.
- **Local no aviso do visor:** "Leite · 12 na Geladeira" (AB9) não tem quadro; entra no `Captura` ou num quadro novo de "Guardar em casa".
- **Letra grande:** a identidade visual não tem regra para linhas com nome e preço acima de 130%. A regra de H9 (empilhar) vira uma linha em "Textos inteiros".

## Referência primeiro, do nosso jeito depois

Seguindo [processo.md](../design/processo.md), o que outros apps fazem nos três pontos novos.

| Problema | Referência | O que levamos | O que fazemos diferente |
| --- | --- | --- | --- |
| Barra que encolhe ao rolar | **iOS 26** (`tabBarMinimizeBehavior(.onScrollDown)`): a barra minimizada mostra só a aba atual, e o acessório de baixo vai para dentro dela, em linha ([Donny Wals](https://www.donnywals.com/exploring-tab-bars-on-ios-26-with-liquid-glass/)); a Apple só minimiza quando o conteúdo é bem maior que a tela ([fórum da Apple](https://developer.apple.com/forums/thread/809945)) | Encolher só quando há o que rolar, e levar junto o que está acima da barra (a barra da compra) | Não encolher com letra grande nem com TalkBack, porque ali o rótulo é a informação; os quatro destinos continuam visíveis |
| Valor do granel antes da pesagem | **Instacart**: o item por peso mostra o preço por unidade de peso e um total estimado pelo peso pedido, que é ajustado depois da pesagem ([ajuda da Instacart](https://instacart.com/help/section/pricing)) | Separar o preço por kg (certo) do valor da linha (desconhecido até a pesagem), e só firmar o valor com a pesagem | Não pedimos o peso, para não acrescentar um passo na loja: o valor fica "—" e o total diz "sem preço de 1 item", em vez de inventar um estimado |
| Local do item novo | **Pantry Check**: os locais são da pessoa, e relatos descrevem bipar tudo e só depois atribuir locais ([App Store](https://apps.apple.com/us/app/id966702368)). **Grocy**: cada produto tem um local padrão, usado em toda compra | Lembrar o local por produto, mesmo depois de "Tirar de casa" (AB10) | Sugerir na hora pela categoria, e dizer onde pôs com um toque para trocar (AB9), em vez de uma tela de arrumação no fim |
| Letra grande | **Android 14**: fonte até 200%, com escala não linear, e a recomendação de testar no máximo ([Android Developers](https://developer.android.com/about/versions/14/features)) | Testar a 200% e a 360 dp | Empilhar nome e preço em vez de encolher o preço e cortar o nome (H9) |

## Lotes sugeridos

Em ordem. Os dois primeiros são pequenos e quase sem tela nova.

1. **Granel que não suja o histórico** (D8). `RecordTripPrice` com pesagem sem observação, teste cobrindo granel e pesagem, e o título "Quanto deu…?". Sem protótipo.
2. **Local que acerta e se diz** (AB9, AB10). Palavras que decidem o local antes do `ProductKind`, teste corrigido, o local no aviso do visor com toque para trocar, o marcador da folha pela sugestão e o local lembrado depois de "Tirar de casa". O aviso pede uma linha no protótipo.
3. **Granel honesto na bandeja** (D9). Quadro "Modo carrinho: granel na bandeja" no protótipo, o sentido único da etiqueta vazada no `ScanTray.md`, e depois o código.
4. **Letra grande de verdade** (H8, H9, H10). Barra que não encolhe com letra grande, rótulos que encolhem em vez de cortar, linhas que empilham acima de 130%, e o teste a 360 dp com a barra e com `didExceedMaxLines`. Regra nova em "Textos inteiros" antes.
5. **Barra igual ao design system** (já no roadmap). 68 px, desfoque 18 com saturação e o anel, que para com movimento reduzido.
6. **Falhas que avisam** (H11). Captura no stepper do Início e na folha do item.

## O que funciona bem (manter)

- **A barra compacta é cuidadosa.** Histerese contra tremor, zona de 24 px no topo, volta ao trocar de aba e ao abrir o menu do bipar, ignora listas horizontais e abas escondidas, e troca sem animar com movimento reduzido.
- **O granel não perde a pesagem.** A etiqueta sem código lida logo depois não firma a linha do granel (`settledByTripPrices`, com teste), e a etiqueta da balança cai na mesma linha.
- **Erros do domínio sem texto no código.** `DomainErrorCode` mantém o domínio sem Flutter, e um `switch` exaustivo garante que todo código tem texto.
- **Letra grande sem estouro.** Alturas mínimas, `Wrap` nos botões e a barra da compra em duas linhas cobrem as telas principais, com teste.
- **Sugestão de local barata e testada.** Reaproveita a classificação do ícone e da seção, só vale para o item que nasce, e a escolha da pessoa nunca é sobrescrita.

## Fontes

Base interna: `CLAUDE.md`, `docs/estado.md`, `docs/roadmap.md`, `CHANGELOG.md`, os ADRs 0018 e 0020, `docs/design/identidade-visual.md`, `docs/design/processo.md`, os guias `ScanNavBar.md` e `ScanTray.md`, `docs/design/design-system/fonte/bundle.css` e `bundle.js`, o protótipo em `docs/design/prototipo/telas/` e o código em `lib/` no commit `3972e8e` (diff `bafcacc..3972e8e`). Nada foi compilado; os achados "prováveis" dependem de rodar o app, e as larguras de texto foram estimadas pela fonte e pelo layout.

Referências externas:

- [Donny Wals: tab bars no iOS 26 com Liquid Glass](https://www.donnywals.com/exploring-tab-bars-on-ios-26-with-liquid-glass/)
- [Apple Developer Forums: tabBarMinimizeBehavior no iOS 26](https://developer.apple.com/forums/thread/809945)
- [Instacart: preços e itens vendidos por peso](https://instacart.com/help/section/pricing)
- [Pantry Check (App Store)](https://apps.apple.com/us/app/id966702368)
- [Android 14: escala de fonte até 200%](https://developer.android.com/about/versions/14/features)
- [W3C: Understanding SC 1.4.4 Resize Text](https://www.w3.org/WAI/WCAG21/Understanding/resize-text.html)
