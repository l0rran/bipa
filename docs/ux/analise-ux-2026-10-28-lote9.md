# Análise de UX do Bipa (lote 9)

> Análise feita no commit `aca7390`, sobre o que entrou depois de `1a0c7a0`: a barra de navegação igual ao design system e com letra grande (A até 160%, B acima), a rodada de letra grande (H9, H10 e formulários), mover e apagar embalagem (G2, ADR 0022), o ícone novo, o Sentry com consentimento (ADR 0025), a folha "Arrumar o que entrou" (AB5), o local dentro do aviso da câmera (AB9), o granel na bandeja e o "Quanto deu…" (D9), a aba Produtos (H1), o `bipa-toast` no lugar dos snackbars, a etiqueta com furo, "Editar embalagem" com os campos da "Embalagem nova" e o chip do modo na câmera de casa (C1, C2). Os caminhos e o "o que a pessoa vive" descrevem o app desse commit. As análises anteriores estão em [analise-ux-2026-10-28.md](analise-ux-2026-10-28.md) (lote 7, AB1 a H7) e [analise-ux-2026-10-28-lote8.md](analise-ux-2026-10-28-lote8.md) (lote 8, AB9 a H11).

Oct 28, 2026 · @Wesley

## Resumo

O lote fecha quase tudo o que estava aberto. A câmera de casa ficou calma: um aviso por bipe, o local dentro dele, o modo à vista no topo e a folha de arrumar só no fim. Mover e apagar embalagem têm confirmação, Desfazer e a oferta de apagar o produto vazio, nessa ordem. Os problemas que sobraram estão nas bordas:

1. **A busca de produto ignora acento só na ordem, não na procura (G4, alto).** O seletor de produto recebe o nome lido da etiqueta ("FEIJAO CARIOCA"), não acha "Feijão carioca" e oferece cadastrar outro. O mesmo seletor serve ao granel e ao "Mover embalagem", então o caminho que o app sugere cria produto duplicado.
2. **O aviso da câmera de casa some em 4 s mesmo com o TalkBack (AB11, médio).** O `bipa-toast` espera quem usa leitor de tela, mas o aviso do visor, que agora tem dois botões ("trocar o local" e "Desfazer"), tem relógio próprio e não espera.
3. **O local some do aviso quando o nome é comprido (AB12, médio, provável).** O texto tem uma linha só e o local vem no fim: "Leite condensado Moça 395 g · 1 na Desp…". A informação que o botão troca é a que corta.
4. **Com letra acima de 160%, durante a compra, dois botões amarelos empilhados levam ao mesmo lugar (H12, médio, provável).** O bipar flutuante fica logo acima do "Continuar" da barra da compra, e a parte de baixo da tela passa de um terço da altura. O quadro "NavLetraGrande" não desenha esse caso.
5. **O Desfazer passou de "até tocar" para 4 s, sem nada que o estique (H13, médio).** É a decisão S1, coerente com o design system, mas "Tirar comprados" não tem confirmação e tira a lista inteira de marcados, e o app não lê o "Tempo para agir" do Android.

O primeiro é barato e protege dado: vale fazer antes do resto. O segundo é uma condição a mais num relógio. O terceiro e o quarto pedem quadro.

## Situação dos achados anteriores

Dos 44 achados das duas análises anteriores, este lote resolveu AB5, AB9, D9, G2, H8, H9 e H10, e avançou H1 e H3. Hoje são 41 resolvidos, 3 parciais (H1, H3 e H11) e nenhum aberto; nenhum regrediu. Dois dos resolvidos abriram achados novos (AB9 → AB11 e AB12; H8 → H12), e a migração para o `bipa-toast` mudou o tempo de todo Desfazer (H13). Abaixo, só os itens que este lote tocou ou que ainda não estão fechados; os demais seguem como na análise do lote 8. "Conferido" quer dizer lido no código deste commit.

| ID | Achado anterior | Situação | O que mudou |
| --- | --- | --- | --- |
| AB3 | "Usei um" tira a linha de vista | Resolvido (conferido) | O aviso com Desfazer fica até o toque com TalkBack (`showBipaToast`, `persist`); sem ele, 4 s (H13). |
| AB5 | Primeira carga deixa locais sem uso | Resolvido (conferido) | `ArrangeArrivalsSheet` ao fechar a câmera de "Guardar em casa" com 3 ou mais produtos novos (`camera_page.dart`, `_closeAfterArranging`). Borda em AB13. |
| AB9 | Local sugerido erra e não se diz | Resolvido, com achados novos (conferido) | O aviso diz "1 na Despensa ▾" e o texto é um botão que abre `pickStockLocation`. Some com TalkBack (AB11) e corta com nome longo (AB12). |
| AB10 | Folha do item mostra Despensa | Resolvido | ADR 0021 e esquema 14 (lote anterior). |
| D7 | Acabamentos do carrinho e da câmera | Resolvido (conferido) | C1: o ícone do aviso diz a casa e o número diz o sentido. C2: `CameraModeChip` no topo. |
| D8 | Valor do granel vira preço por kg | Resolvido | `RecordTripPrice` sem observação para pesagem (lote anterior). |
| D9 | Preço por kg no lugar do valor | Resolvido (conferido) | Traço na etiqueta, "R$ 8,99/kg" sob o nome com a balança, toque no nome desligado e `showWeighedValueDialog` com a conta de volta. Acabamentos em D10. |
| G2 | Embalagem no produto errado | Resolvido, com achados novos (conferido) | "Mover embalagem…" e "Apagar embalagem" no menu, com confirmação, Desfazer e a oferta de apagar o produto vazio num segundo aviso (`product_detail_page.dart:127-276`). Busca do destino em G4; acabamentos em G5. |
| H1 | Abas com dois visuais | Parcial (conferido) | `products_page.dart` com `BipaSearchBar`, `PriceRowList` e o bipar na busca. Faltam a busca sem acento (G4), os formulários e o seletor de produto (`product_picker_sheet.dart`, ainda em `ListTile` e `CircleAvatar`). |
| H2 | Erros sem saída e fora do ARB | Resolvido | `DomainErrorCode` e `AsyncValueView` com `onRetry` em Produtos. |
| H3 | Alturas fixas com texto dentro | Parcial | Formulários cobertos pelo teste a 200%. A câmera e o carrinho continuam fora ("não montam em teste", roadmap). |
| H8 | Rótulos da navegação cortam | Resolvido, com achado novo (conferido) | `_fitLabels` encolhe os quatro por igual, balão no toque longo, sem encolher a partir de 130% ou com TalkBack, bipar flutuante acima de 160%. B durante a compra em H12. |
| H9 | Nome perde para o preço | Resolvido (conferido) | `isLargeText` libera o nome em `stock_list.dart`, `shopping_list.dart`, `product_card.dart` e na bandeja. |
| H10 | Teste mede estouro, não leitura | Resolvido (conferido) | `large_text_test.dart` roda a 411 e 360 dp e falha com `didExceedMaxLines` em nomes e rótulos. |
| H11 | Stepper falha calado | Parcial (conferido) | Os steppers avisam, mas o aviso de falha dentro de uma folha aparece atrás dela (H15, provável). |
| (barra) | Barra igual ao design system | Resolvido (conferido) | 68 px, desfoque 18 e o anel `bipa-breathe`, que para com movimento reduzido. A saturação do vidro ficou de fora (roadmap). |

## Problemas por jornada

Caminhos relativos ao repositório. Tudo foi avaliado lendo o código, sem compilar. Gravidade: crítico perde dado ou bloqueia a tarefa; alto é dado errado ou caminho principal confuso; médio é atrito; baixo é acabamento. "Provável" quando o efeito depende de rodar o app.

### A e B. Primeira carga e em casa

**AB11. O aviso da câmera de casa some em 4 s mesmo com o TalkBack (médio).**

- **Onde:** `lib/features/prices/presentation/camera_page.dart`, `_showNotice`: `_noticeTimer = Timer(duration, _clearNotice)`, com `duration` de 4 s (`_undoFor`) quando o aviso tem Desfazer ou o local. Nada olha `MediaQuery.accessibleNavigationOf`. Compare com `lib/core/design_system/components/bipa_toast.dart:32-39`, que deixa o aviso com ação na tela até o toque quando há leitor de tela (WCAG 2.2.1).
- **O que a pessoa vive:** com o TalkBack, bipa o leite em "Guardar em casa". O `LiveReadChip` é `liveRegion`, então ela ouve "+1, Leite integral 1 L · 1 na Despensa, trocar o local". Para chegar ao botão ela desliza uma ou duas vezes; antes disso o aviso some e o foco cai na dica. O mesmo vale para o Desfazer do aviso em "Dar baixa em casa". Os dois botões que este lote pôs no aviso não são alcançáveis para quem mais depende do texto.
- **Por que importa:** é a regra que o próprio app escreveu para o `bipa-toast`, quebrada no componente vizinho. E o local errado só se corrige depois, item a item, ou na folha de arrumar, que só vem com três itens novos.
- **O que fazer:** em `_showNotice`, com `accessibleNavigation`, não ligar o relógio quando o aviso tem `onTap` ou `onDetailTap`: ele fica até o próximo bipe ou até a pessoa agir, como o `bipa-toast`. Um teste de widget com `MediaQueryData(accessibleNavigation: true)` cobre.

**AB12. O local é a parte do aviso que corta quando o nome é longo (médio, provável).**

- **Onde:** `LiveReadChip._withDetailButton` em `lib/core/design_system/components/scan_tray.dart`: o `detail` tem `maxLines: 1` abaixo de 130% de letra e `TextOverflow.ellipsis`. O texto vem de `cameraAtHomePlaced` em `app_pt.arb:1053`, "{name} · {count} na Despensa", com o local no fim. Quando a lista não muda, o "Desfazer" divide a mesma linha.
- **O que a pessoa vive:** num celular de 360 dp, bipa o "Leite condensado Moça 395 g". O aviso tem uns 330 dp: ícone, "+1", o nome e o Desfazer já passam disso, e o que aparece é "Leite condensado Moça 395 g · 1 na D…". A seta para baixo continua lá, mas o que ela troca não aparece. Nomes de mercado costumam ter marca e tamanho, então o caso é comum.
- **Por que importa:** o local é a razão de o texto ser um botão (AB9). Cortado, a pessoa não sabe se precisa trocar, e a sugestão volta a ser silenciosa.
- **O que fazer:** o corte deve cair no nome, nunca no local. Dois caminhos: (a) o local antes, "Na Despensa · Leite condensado Moça…", com o nome cortando; ou (b) duas linhas sempre que há local, o nome em cima (cortando) e "1 na Despensa ▾" embaixo. A (b) segue o `ScanTrayItem` com `meta`, que já tem uma segunda linha. Escolher no quadro "CapturaCasaLocal" antes do código.

**AB13. Com bipes rápidos, só a folha confere o local, e ela só vem com três itens (baixo, provável).**

- **Onde:** `camera_page.dart`: cada bipe chama `_showNotice` e troca o aviso anterior; `HomeArrivals.minimumToArrange = 3` (`lib/features/stock/domain/home_arrivals.dart`).
- **O que a pessoa vive:** guarda a compra da semana: 12 itens, um bipe a cada 2 s, dois deles novos (atum e lasanha). O aviso do atum dura até o bipe seguinte, uns 2 s, e ela não olha. Ao fechar a câmera, nada aparece, porque foram só dois novos. A lasanha ficou na Despensa. No caso oposto, ela troca o local de cada um dos três novos pelo aviso, e a folha aparece mesmo assim, com tudo já feito.
- **O que fazer:** contar para a folha os itens novos cujo aviso foi trocado por outro bipe antes de 4 s e cujo local ninguém tocou, sem o mínimo de três; e tirar da folha o item cujo local a pessoa já escolheu no aviso. Assim, a folha aparece quando há algo a conferir, e só então.

### D. Câmera do bipar e modo carrinho

**D10. Acabamentos do "Quanto deu…" (baixo).**

- **Onde:** `cartWeighingTitle` em `app_pt.arb:1240` ("Quanto deu o {name}?") e `lib/core/widgets/weighed_value_dialog.dart`.
- **O que a pessoa vive e o que fazer:**
  - "Quanto deu o Banana prata?", "Quanto deu o Carne moída?". O app já tirou o artigo de "Onde fica Leite integral 1 L?" pelo mesmo motivo (o gênero do produto não é conhecido, README do protótipo). Usar "Quanto deu {name}?" ou "Quanto deu a pesagem?", com o nome embaixo.
  - A conta de volta ("1,38 kg a R$ 8,99/kg") muda a cada dígito, mas não é `liveRegion`: com o TalkBack, ela só é ouvida se a pessoa sair do campo. Marcar o `Semantics` de `_back` como região viva, só quando o peso muda.
  - "Salvar" com "0" ou com um valor que não se lê não faz nada, sem dizer por quê. Desligar o botão enquanto o valor não vale.

### F. Preços e mercados

**F5. A lista de Produtos mostra um preço de meses atrás como se fosse de hoje (médio).**

- **Onde:** `lib/features/prices/domain/product_headline_price.dart` (`headlinePrice`: o menor entre os mais recentes de cada mercado, sem olhar a data) e `lib/features/products/presentation/products_page.dart` (`_row`: `value` e `valueNote` sem idade).
- **O que a pessoa vive:** o café Pilão aparece a R$ 14,90 na lista de Produtos. É o preço de uma promoção do Atacarejo de cinco meses atrás; nos outros mercados, há duas semanas, está a R$ 19,90. Na tela do produto, a etiqueta diz "Atacarejo · há 152 dias" (F4), mas a lista, que é onde a pessoa passa o olho para lembrar quanto custa, não diz nada.
- **Por que importa:** "a idade do preço sempre à vista" é a lição do benchmark (`processo.md`), e F1 e F4 já a aplicaram em Mercados e no produto. A lista agora mostra um preço em cada linha, então ela é o lugar mais visto do preço.
- **O que fazer:** a mesma regra de F4: a partir de 30 dias, a nota da linha vira a idade ("há 5 meses"), em `inkMuted`, no lugar do "o kg" ou abaixo dele. Ou escolher, para a linha, o menor preço entre os dos últimos 30 dias e só cair no mais antigo quando não houver outro. A primeira é uma linha no quadro "Produtos"; a segunda muda o que o número quer dizer e pede decisão.

### G. Produto e embalagens

**G4. O seletor de produto não acha nome com acento e oferece cadastrar outro (alto).**

- **Onde:** `DriftProductRepository.watchAll` em `lib/features/products/data/drift_product_repository.dart:38-56` (`name.like('%termo%')`), usado pela aba Produtos e por `lib/features/products/presentation/product_picker_sheet.dart`. O `LIKE` do SQLite só ignora maiúsculas em letras ASCII ([documentação do SQLite](https://www.sqlite.org/lang_expr.html#like)): "A" não casa com "ã", "C" não casa com "ç". No seletor, `exact` (linha 121) usa `foldText`, mas só entre os resultados que o `LIKE` já trouxe, então nunca vê o produto que não casou. Mercados filtra com `foldText` (`markets_page.dart:44`).
- **O que a pessoa vive:** no carrinho, lê a etiqueta do granel "FEIJAO CARIOCA R$ 8,49 o kg" e toca no aviso. O seletor abre com "FEIJAO CARIOCA" já digitado (`initialQuery: read.nameHint`; as etiquetas vêm em caixa alta e sem acento, como o exemplo "ARROZ BRANCO TIO JOAO 5KG" em `package_suggestion.dart`). O "Feijão carioca" que ela cadastrou não aparece, e a primeira linha é "Cadastrar FEIJAO CARIOCA". Ela toca, e o preço por kg vai para um produto novo. Na tela do produto, o mesmo em "Mover embalagem…": procura "acucar" e o destino oferecido é um "acucar" novo. Na aba Produtos, "acucar" diz "Nenhum produto encontrado."
- **Por que importa:** produto duplicado divide o histórico de preços e o estoque, e o conserto ("Juntar com…") não tem Desfazer. O caminho errado é o que o próprio app sugere, com o texto da etiqueta pré-preenchido.
- **O que fazer:** filtrar em Dart com `foldText`, palavra por palavra (todas as palavras do termo, em qualquer ordem, contidas no nome ou na marca), como Mercados e `PackageSuggestion` já fazem. A lista inteira já é carregada para ordenar, então não há custo novo. O código de barras continua por igualdade. Teste com "acucar", "FEIJAO CARIOCA" e "carioca feijao". O roadmap já tem a parte da aba Produtos em "H1 (resto)"; este achado estende ao seletor, que é onde o dado se perde.

**G5. Depois de mover, a pessoa fica no produto de origem, sem caminho para o destino (baixo).**

- **Onde:** `_movePackage` e `_showUndoThenOfferDelete` em `lib/features/products/presentation/product_detail_page.dart:127-228`; `packageMoveTitle` em `app_pt.arb:1516`.
- **O que a pessoa vive:** move o código do Leite Ninho do "Leite integral" para um produto novo, "Leite Ninho". O aviso diz "Embalagem movida para Leite Ninho." e some em 4 s; ela continua na tela do "Leite integral". Para conferir se os preços foram junto ou pôr uma foto no Ninho, volta à aba Produtos e procura. Se a embalagem não tem marca nem tamanho, o diálogo pergunta "Mover 7891000100103 para Leite Ninho?".
- **O que fazer:** quando o destino foi criado na hora, abrir o destino depois de mover, como o "Juntar com…" já faz (`pushReplacement`), e deixar a oferta de apagar o produto vazio para a volta. No diálogo, sem rótulo, usar "esta embalagem" em vez do código cru.

### H. Consistência e acessibilidade

**H12. Bipar flutuante e barra da compra empilhados, com o mesmo destino (médio, provável).**

- **Onde:** `ScanNavBar._buildFloating` em `lib/core/design_system/components/scan_nav_bar.dart:346-390`: a coluna põe o bipar (64 + 12 de folga), depois `above` (a `ShoppingBar`, em `home_shell.dart:90-108`) e depois a pílula. Durante a compra, `onScan` abre o modo carrinho (`home_shell.dart:112`), o mesmo que o "Continuar" da barra da compra.
- **O que a pessoa vive:** com a letra do Android em 200% num celular de 360 dp, começa uma compra e volta ao Início. Embaixo, à direita, o botão amarelo de bipar; logo abaixo, a barra amarela da compra com "Continuar ›" no mesmo canto; embaixo, a navegação. Pelas medidas do código (bipar 76, barra da compra em duas linhas uns 110, pílula uns 77, margens e a barra de gestos), a parte de baixo ocupa por volta de 300 dp, perto de 40% da tela (estimado). Os dois amarelos levam ao carrinho.
- **Por que importa:** "Um destaque por tela" e "um sinal por informação" (`identidade-visual.md`): dois botões de marca, um em cima do outro, para a mesma ação. Quem usa letra grande perde mais espaço justamente onde o conteúdo já é escasso. O quadro "NavLetraGrande" desenha B só sem compra, então o código decidiu sozinho.
- **O que fazer:** em B, durante a compra, o bipar flutuante sai, e a barra da compra assume o papel dele: tocar abre o carrinho, como hoje, e segurar abre o menu do bipar (o `onScanLongPress`). Ganha uns 76 dp e fica um amarelo só. É a regra do Material 3 de um botão flutuante por tela, com a barra da compra no lugar do botão. Desenhar o quadro "NavLetraGrande, durante a compra" antes.

**H13. O Desfazer agora some em 4 s, e nada o estica (médio).**

- **Onde:** `bipaToastDuration` (4 s) em `lib/core/design_system/components/bipa_toast.dart:9`, usado por todas as chamadas com ação; `finish_shopping.dart:63` usa 6 s. Antes deste lote, no Flutter 3.47, o snackbar com ação ficava até o toque (`persist`). "Tirar comprados" (`shopping_list_page.dart:167-188`) não pede confirmação.
- **O que a pessoa vive:** na Lista, com 14 itens marcados, toca em "Tirar comprados" sem querer, ao rolar. "14 itens saíram da lista · Desfazer" fica 4 s; ela está com o carrinho na outra mão e não toca a tempo, e os 14 itens somem sem caminho de volta. Quem ativou o "Tempo para agir" do Android (Acessibilidade, um minuto, por exemplo) e não usa o TalkBack recebe os mesmos 4 s.
- **Por que importa:** a troca seguiu o design system (decisão S1), e 4 s é o "curto" do Material. Mas o Desfazer é a única proteção das ações sem confirmação, e o Android tem um ajuste próprio para isso: `AccessibilityManager.getRecommendedTimeoutMillis` devolve o tempo que a pessoa pediu para controles que somem sozinhos ([Android Developers](https://developer.android.com/reference/kotlin/android/view/accessibility/AccessibilityManager)). O Flutter não o lê sozinho.
- **O que fazer:** três passos, do mais barato ao mais caro. (1) O tempo para enquanto o dedo está sobre o aviso, como o relógio já para no aviso da câmera ao tocar no local. (2) Ações que mexem em muitos registros de uma vez (tirar comprados, apagar embalagem com preços, mover) usam o tempo maior, como "Terminar compra". (3) Ler o tempo recomendado do Android por um canal de plataforma e usar o maior dos dois. Registrar a regra no `BipFeedback.md`, onde o `bipa-toast` está descrito.

**H14. Com "Remover animações", a linha do tempo do aviso esvazia na hora (baixo, provável).**

- **Onde:** `_BipaToastState._timeLeft` em `bipa_toast.dart:80-105`: um `AnimationController` com o comportamento padrão (`AnimationBehavior.normal`). Quando o Android pede menos animação, o Flutter encurta esse tipo de animação para uma fração da duração. O aviso continua 4 s na tela, porque o tempo vem do `ScaffoldMessenger`.
- **O que a pessoa vive:** com "Remover animações" ligado, toca "Usei um". O aviso aparece com a linha do tempo já vazia, e o Desfazer parece ter vencido, mas ainda funciona por 4 s.
- **O que fazer:** `animationBehavior: AnimationBehavior.preserve` no controlador da linha do tempo (ela é um relógio, não decoração), ou esconder a linha com `disableAnimations`, como o anel do bipar faz. Conferir o mesmo no anel de espera do aviso da câmera (`_CountdownRing`).

**H15. O aviso de falha dentro de uma folha aparece atrás dela (baixo, provável).**

- **Onde:** `_guard` em `lib/features/stock/presentation/arrange_arrivals_sheet.dart:67-75` e o tratamento de H11 em `stock_item_sheet.dart:51`: os dois usam o `ScaffoldMessenger` da tela de baixo. O aviso é desenhado pelo `Scaffold` dessa tela, que fica sob a folha modal.
- **O que a pessoa vive:** na folha "Arrumar o que entrou", toca em "Geladeira" e o banco falha. O chip não muda, e o "Não deu para salvar" sai embaixo da folha, coberto por ela. Ao fechar a folha, o aviso já foi.
- **O que fazer:** envolver o conteúdo das duas folhas num `ScaffoldMessenger` com `Scaffold` transparente, ou mostrar a falha dentro da própria folha (uma linha de texto acima do botão). Testar com o repositório falso que lança.

**H16. O anel do bipar respira para sempre, em todas as abas (baixo).**

- **Onde:** `_ScanButtonState._breath.repeat()` em `scan_nav_bar.dart:706-731`, como o `bipa-breathe` do design system (`bundle.css:207`, `infinite`).
- **O que a pessoa vive:** o Início, os Produtos e a Lista têm um movimento contínuo no canto do olho enquanto ela lê. Durante a compra, o anel pulsa ao lado da barra amarela, que já é o destaque da tela. O app também nunca fica parado: um quadro novo a cada 16 ms enquanto a navegação está à vista.
- **Por que importa:** "Calma por padrão" e o WCAG 2.2.2 (movimento automático por mais de 5 s precisa de pausa). O movimento reduzido do Android resolve para quem o liga, mas a regra de calma vale para todos.
- **O que fazer:** levar ao design system uma regra mais curta: o anel respira algumas vezes ao abrir o app, ou só quando a casa e a lista estão vazias (o convite ao primeiro bipe), e para depois. É uma mudança do design system primeiro, e só depois do código.

## Divergências com o design system e o protótipo

O design system vale sobre o código. As cópias do repositório estão à frente das publicadas (`estado.md`); o que segue é o que sobra além disso.

- **`processo.md`, "Trocar o local no aviso da câmera":** ainda descreve o chip à parte ("A troca é um chip à parte", "O chip é o mesmo chip de vidro do mercado"). A decisão aprovada é o texto do aviso como botão (README do protótipo, quadro "CapturaCasaLocal"). Atualizar o "Do nosso jeito" para quem ler o processo não desfazer a decisão.
- **`processo.md`, "Navegação com letra grande":** termina em "duas propostas para o mantenedor escolher". Registrar a decisão "A até 160%, B acima" e o balão também em B.
- **NavLetraGrande sem a compra:** B foi desenhado sem a barra da compra. Proposta em H12.
- **CapturaComprei e CapturaUsei sem o chip do modo:** a decisão C2 está feita no app (`CameraModeChip`), e o README diz que os quadros ainda não foram refeitos.
- **Seletor de produto fora do design system:** `product_picker_sheet.dart` usa `TextField` com `OutlineInputBorder`, `ListTile` e `CircleAvatar` em `brandSoft` para "Cadastrar…". É a folha que o granel, o mover e o "Embalagem nova" usam. Entra no "H1 (resto)", junto com os formulários: a mesma busca do `BipaSearchBar` e as linhas do `PriceRowList`.
- **`ScanNavBar.md`:** ainda sem o balão e o bipar flutuante (pendente no README do protótipo). A saturação do vidro (`saturate(1.5)`) ficou de fora do código; registrar no guia se for de propósito.
- **`BipFeedback.md`:** descreve o `bipa-toast` com a linha do tempo, mas não diz o que acontece com leitor de tela (o código fica até o toque) nem com movimento reduzido (H14). Duas linhas no guia.
- **Pergunta do relatório de falhas (ADR 0025):** sem quadro. A proposta do ADR é um cartão no Início depois da primeira compra. Para não disputar o destaque do Início, o cartão deve ser neutro (sem `brand`), com os dois botões de mesmo peso que o ADR pede, e só aparecer quando a prateleira de "Acabando" e o insight não estiverem com destaque.

## Referência primeiro, do nosso jeito depois

Seguindo [processo.md](../design/processo.md), o que outras fontes fazem nos pontos novos.

| Problema | Referência | O que levamos | O que fazemos diferente |
| --- | --- | --- | --- |
| Quanto tempo dura o Desfazer | **Android** (`getRecommendedTimeoutMillis` e o ajuste "Tempo para agir", [Android Developers](https://developer.android.com/reference/kotlin/android/view/accessibility/AccessibilityManager)); **Compose Material 3** (`SnackbarDuration` curta, longa ou indefinida, e o botão de dispensar quando é indefinida, [referência da API](https://kotlinlang.org/api/compose-multiplatform/material3/androidx.compose.material3/-snackbar-host-state/show-snackbar.html)); **WCAG 2.2.1** ([tempo ajustável](https://www.w3.org/WAI/WCAG22/Understanding/timing-adjustable.html)) | Respeitar o tempo que a pessoa pediu no sistema e parar o relógio enquanto ela toca | Mantemos a linha do tempo de 4 s do design system como padrão, porque o aviso que não sai cobre a barra da compra e a navegação; o tempo cresce só quando o sistema pede ou a ação mexe em muitos registros |
| Busca com o texto da etiqueta | **SQLite** (`LIKE` só ignora caixa em ASCII, [documentação](https://www.sqlite.org/lang_expr.html#like)); **Mercados** (o próprio Bipa, `foldText`) | Comparar sem acento e sem caixa, e por palavra, como `PackageSuggestion` | O seletor não oferece "Cadastrar" enquanto houver um produto com as mesmas palavras sem acento |
| Dois botões de marca no canto da tela | **Material 3** (um botão flutuante por tela, [guia do FAB](https://m3.material.io/components/floating-action-button/guidelines)); **iOS 26** (o acessório de baixo entra na barra minimizada, na análise do lote 8) | Um botão de marca só, e o acessório da compra no lugar dele | A barra da compra herda o toque longo do bipar, para o menu não sumir com a letra grande |
| Movimento contínuo | **WCAG 2.2.2** ([pausar, parar, esconder](https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html)); "calma por padrão" (Linear e Shortcut, em `identidade-visual.md`) | Movimento com começo e fim | O anel continua como assinatura do bipar, mas só como convite, não como estado permanente |

## Lotes sugeridos

Em ordem. Os dois primeiros não pedem quadro.

1. **Busca que acha o que já existe** (G4, com o "H1 (resto)" da busca). Filtro com `foldText` e por palavra no repositório ou no provider, o seletor sem "Cadastrar" quando há um produto com as mesmas palavras, testes com "acucar" e "FEIJAO CARIOCA".
2. **Aviso da câmera para quem usa TalkBack** (AB11, H14). O relógio do aviso não corre com `accessibleNavigation` quando há botão; a linha do tempo do `bipa-toast` com `AnimationBehavior.preserve`. Uma linha no `BipFeedback.md`.
3. **Desfazer com tempo honesto** (H13, H15). Pausa ao tocar, tempo maior para ações em lote, "Tempo para agir" do Android, e os avisos de falha visíveis dentro das folhas. Regra no `BipFeedback.md` antes.
4. **Local que não corta** (AB12, AB13). Escolher no quadro "CapturaCasaLocal" entre o local primeiro e as duas linhas; a folha de arrumar conta o que ninguém conferiu.
5. **Letra grande durante a compra** (H12). Quadro "NavLetraGrande, durante a compra", e depois o código.
6. **Preço velho na lista** (F5). Uma linha no quadro "Produtos" com a idade a partir de 30 dias.
7. **Acabamentos** (D10, G5, H16) e os textos de `processo.md`. O H16 começa no design system.

## O que funciona bem (manter)

- **Mover e apagar embalagem na ordem certa.** Confirmação que diz quantos preços vão junto, Desfazer que tira também o que a movida criou (item zerado, produto novo vazio) e a oferta de apagar o produto num segundo aviso, que só vem se ninguém desfez e se o produto continua vazio (`isProductEmpty` de novo antes de oferecer).
- **A câmera de casa com um sinal por coisa.** O número diz o sentido, o ícone diz a casa, o chip do topo diz o modo, e o Desfazer vai para o aviso quando a lista não muda, sem um snackbar repetindo o fato.
- **"Arrumar o que entrou" sem botão de salvar.** Cada toque grava, o item não pula de grupo enquanto a pessoa mexe nele, e fechar é pular. Um bipe desfeito ou um produto apagado no meio do caminho saem da conta.
- **O `bipa-toast` que espera quem usa leitor de tela,** com o motivo escrito no código (WCAG 2.2.1).
- **A barra com letra grande decidida por conta, não por chute.** `_fitLabels` mede os quatro rótulos com o peso do selecionado, para nada mudar de tamanho ao trocar de aba, e o teste falha com `didExceedMaxLines` a 360 dp.
- **O granel honesto.** Traço até a pesagem, o preço por kg com a balança sob o nome, fora do total, e a conta de volta no diálogo para pegar um "124,0".
- **Relatório de falhas desligado até a pessoa dizer sim,** com a limpeza como função pura e testada, e sem pergunta na primeira abertura.

## Fontes

Base interna: `CLAUDE.md`, `docs/estado.md`, `docs/roadmap.md`, `CHANGELOG.md`, os ADRs 0021, 0022 e 0025, `docs/design/identidade-visual.md`, `docs/design/processo.md`, os guias `BipFeedback.md`, `ScanNavBar.md` e `ScanTray.md`, `docs/design/design-system/fonte/bundle.css`, o protótipo em `docs/design/prototipo/` (README, "Divergências resolvidas", "Variantes de componente" e os quadros NavLetraGrande, CapturaCasaLocal, ArrumarEntrou, ModoCarrinhoGranelBandeja, ModoCarrinhoGranelValor e Produtos) e o código em `lib/` no commit `aca7390` (diff `1a0c7a0..aca7390`). Nada foi compilado; as medidas de H12 e a largura do aviso em AB12 foram estimadas pelo layout e pela fonte.

Referências externas:

- [Android Developers: AccessibilityManager, `getRecommendedTimeoutMillis`](https://developer.android.com/reference/kotlin/android/view/accessibility/AccessibilityManager)
- [Compose Material 3: `SnackbarHostState.showSnackbar`](https://kotlinlang.org/api/compose-multiplatform/material3/androidx.compose.material3/-snackbar-host-state/show-snackbar.html)
- [SQLite: o operador LIKE](https://www.sqlite.org/lang_expr.html#like)
- [Material 3: botão flutuante](https://m3.material.io/components/floating-action-button/guidelines)
- [W3C: Understanding SC 2.2.1 Timing Adjustable](https://www.w3.org/WAI/WCAG22/Understanding/timing-adjustable.html)
- [W3C: Understanding SC 2.2.2 Pause, Stop, Hide](https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html)
