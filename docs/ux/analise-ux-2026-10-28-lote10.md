# Análise de UX do Bipa (lote 10)

> Análise feita no commit `47edb8d`, sobre o que entrou depois de `79fc21f`: a busca sem acento e por palavra (G4) e o recorte do texto da etiqueta antes da escolha de produto, a idade do preço velho em Produtos (F5), o "Quanto deu…" sem artigo, com anúncio e erro (D10), abrir o destino criado ao mover e o nome da embalagem sem rótulo (G5), o aviso da câmera que espera o TalkBack (AB11), o toast com pausa ao toque, 10 s nas ações grandes e o "Tempo para agir" do Android (H13), a linha do tempo com animações removidas (H14), os avisos por cima das folhas (H15), a barra da compra no lugar do bipar acima de 160% (H12), o anel que respira duas vezes e para (H16), o aviso em duas linhas com o local (AB12), a folha "Arrumar" só com o não conferido (AB13), os Ajustes e a pergunta do relatório de falhas. Os caminhos e o "o que a pessoa vive" descrevem o app desse commit. As análises anteriores estão em [analise-ux-2026-10-28.md](analise-ux-2026-10-28.md) (lote 7), [analise-ux-2026-10-28-lote8.md](analise-ux-2026-10-28-lote8.md) e [analise-ux-2026-10-28-lote9.md](analise-ux-2026-10-28-lote9.md).

Oct 28, 2026 · @Wesley

## Resumo

O lote fecha todos os doze achados do lote 9 e o H11. Os avisos ficaram honestos com o tempo: param sob o dedo, esperam o TalkBack, seguem o "Tempo para agir" e aparecem por cima das folhas. A busca acha "Açúcar" por "acucar", e o aviso da câmera não corta mais o local. O que sobrou nasce das próprias correções:

1. **O recorte da etiqueta tira a variedade do granel, e a segunda variedade cai no produto da primeira (G6, alto, provável).** "BANANA PRATA KG" vira o produto "Banana"; depois, "BANANA NANICA KG" abre a escolha com "Banana" e sem "Cadastrar". O G4 trocou o produto duplicado por produtos fundidos, e o preço do granel não tem embalagem para mover depois.
2. **O cartão do consentimento diz menos do que vai (H17, médio).** "Vai só o tipo do erro e o modelo do celular", enquanto os Ajustes listam também versões, idioma, fuso e onde o erro aconteceu. Pela LGPD, consentimento dado sobre informação incompleta pode ser nulo.
3. **O item cujo local a pessoa escolheu no aviso perde a pergunta do "ter sempre" (AB14, médio).** A folha "Arrumar" faz duas coisas, o local e o "ter sempre", e a regra do AB13 (proposta pelo próprio lote 9) só pensou na primeira.
4. **A busca do Início ainda diferencia acento (G7, médio).** "acucar" diz "Nenhum resultado" no Início e acha o "Açúcar" na aba Produtos.
5. **O cartão do relatório de falhas empurra "Acabando" para baixo e chega junto com o fim da compra (H18, baixo).**

O primeiro protege dado e não pede quadro. O segundo é uma frase no ARB e precisa vir antes do primeiro build com DSN.

## Situação dos achados anteriores

Das três análises anteriores saíram 56 achados. Este lote resolveu AB11, AB12, AB13, D10, F5, G4, G5, H11, H12, H13, H14, H15 e H16. Hoje são 54 resolvidos, 2 parciais (H1 e H3) e nenhum aberto; nenhum regrediu. Quatro dos resolvidos abriram achados novos (AB13 → AB14; G4 → G6 e G7; G5 → G8). Abaixo, só os itens que este lote tocou ou que não estão fechados; os demais seguem como na análise do lote 9. "Conferido" quer dizer lido no código deste commit.

| ID | Achado anterior | Situação | O que mudou |
| --- | --- | --- | --- |
| AB11 | Aviso da câmera some com o TalkBack | Resolvido (conferido) | `BipaNoticeTimer` em `camera_page.dart` usa a regra de `bipaToastTimeout`: com leitor de tela e botão, não sai sozinho. A espera do par (o anel) não estica. |
| AB12 | Local corta com nome longo | Resolvido (conferido) | `LiveReadChip.title`: o nome em cima (corta), "1 na Despensa ▾" embaixo, sem `maxLines`. `cameraAtHomePlaced` sem o nome. |
| AB13 | Folha só com três itens | Resolvido, com achado novo (conferido) | `HomeArrivals.mayArrange` e `placeChosen`: a folha lista o item novo cujo local ninguém escolheu no aviso, sem mínimo. O "ter sempre" ficou de fora para quem escolheu (AB14). |
| D10 | Acabamentos do "Quanto deu…" | Resolvido (conferido) | "Quanto deu {name}?", a conta de volta em região viva depois de 700 ms sem digitar e `ErrorLine` com `liveRegion` ao salvar um valor que não vale. |
| F5 | Preço velho sem idade em Produtos | Resolvido (conferido) | `HeadlinePrice.observedAt` e `_valueNote` em `products_page.dart`: "o kg · há 152 dias" a partir de `priceStaleAfterDays`. |
| G4 | Seletor não acha nome com acento | Resolvido, com achados novos (conferido) | `matchesProductSearch` (palavra por palavra, sem acento, com marcas e código) no repositório; `sameSearchWords` tira o "Cadastrar"; "Cadastrar" vai para o fim; a Lista compara com `foldText`. O recorte da etiqueta abriu G6; o Início ficou de fora (G7). |
| G5 | Sem caminho para o destino ao mover | Resolvido, com achado novo (conferido) | Destino criado na hora abre por cima (`openProductId`); a confirmação diz "a embalagem de código final 4321" ou "a embalagem sem nome". Desfazer na tela do destino em G8. |
| H1 | Abas com dois visuais | Parcial (conferido) | Falta o seletor de produto (`product_picker_sheet.dart:123-181`, `TextField`, `ListTile` e `CircleAvatar`) e os formulários. |
| H3 | Alturas fixas com texto dentro | Parcial | O teste a 200% ganhou o Início com o cartão e os Ajustes. A câmera e o carrinho continuam fora. |
| H11 | Stepper falha calado | Resolvido (conferido) | Com H15, a falha aparece por cima da folha do item e da folha "Arrumar". |
| H12 | Bipar e barra da compra empilhados | Resolvido (conferido) | `aboveReplacesScan` em `scan_nav_bar.dart`; a `ShoppingBar` ganha `onLongPress` e o `onLongPressHint` acima de 160%. Na Lista, sem a barra, o bipar flutuante volta. |
| H13 | Desfazer some em 4 s | Resolvido (conferido) | `BipaToastClock` para sob o dedo; `BipaToastDuration.long` em tirar comprados, terminar a compra, mover e apagar embalagem; `RecommendedTimeouts` lê `getRecommendedTimeoutMillis` pelo canal `dev.l0rran.bipa/accessibility`. |
| H14 | Linha do tempo vazia com animações removidas | Resolvido (conferido) | `AnimationBehavior.preserve` e a linha some com `disableAnimations`. O `_CountdownRing` da câmera fica parado com movimento reduzido. |
| H15 | Falha atrás da folha | Resolvido (conferido) | `BipaSheetToasts` em todas as folhas que gravam, menos a escolha de produto, que não grava. |
| H16 | Anel respira para sempre | Resolvido, com achado novo (conferido) | `ScanRingBreath`: duas vezes ao aparecer, sem fim com casa e lista vazias, parado na compra e com movimento reduzido. Recomeça a cada volta de tela cheia (H19). |

## Problemas por jornada

Caminhos relativos ao repositório. Tudo foi avaliado lendo o código, sem compilar. Gravidade: crítico perde dado ou bloqueia a tarefa; alto é dado errado ou caminho principal confuso; médio é atrito; baixo é acabamento. "Provável" quando o efeito depende de rodar o app ou do que o OCR lê.

### A e B. Primeira carga e em casa

**AB14. Quem escolhe o local no aviso perde a pergunta do "ter sempre" (médio).**

- **Onde:** `HomeArrivals.placeChosen` e `toArrange` em `lib/features/stock/domain/home_arrivals.dart`, chamados por `_choosePlace` em `lib/features/prices/presentation/camera_page.dart:646-667`. A folha (`arrange_arrivals_sheet.dart`, `_ArrivalEditor`) abre os chips de local **e** o stepper do "ter sempre"; a escolha do aviso (`pickStockLocation`) só tem os locais.
- **O que a pessoa vive:** guarda a compra com dois produtos novos, atum e azeite. No aviso do atum, toca em "1 na Despensa ▾" e escolhe Despensa mesmo, para confirmar. Ao fechar a câmera, a folha mostra só o azeite, onde ela marca "ter sempre 1". O atum fica sem "ter sempre": quando acabar, não entra em "Acabando" nem na lista, e nada avisa. Quem conferiu com mais cuidado é quem perde a pergunta.
- **Por que importa:** o "ter sempre" é o que liga o estoque à lista (o coral de "Acabando" só existe abaixo dele). A regra do AB13 foi proposta no lote 9 olhando só o local; ela trata "conferido" como "local e ter sempre conferidos". Antes do lote, com três ou mais itens, todos passavam pela folha.
- **O que fazer:** a escolha que abre do aviso usa o mesmo editor da folha (`_ArrivalEditor`: chips de local e, embaixo, o "ter sempre"), e o item só sai da folha quando o local foi escolhido ali. Assim o aviso e a folha fazem a mesma coisa, e a regra do AB13 continua de pé. Desenhar no quadro "CapturaCasaLocal" a escolha com o stepper antes do código.

Sobre a pergunta de a folha sem mínimo cansar: ela só aparece quando entra um produto que não estava em casa, o que fica raro depois das primeiras semanas, e com um item ela é a única pergunta do "ter sempre" no caminho. O problema é o contrário, o item que sai dela sem ter passado pelo "ter sempre".

### D. Câmera do bipar e modo carrinho

**G6. O recorte da etiqueta tira a variedade do granel, e a variedade seguinte cai no mesmo produto (alto, provável).**

- **Onde:** `productQueryFromLabel` em `lib/features/products/domain/package_suggestion.dart:165-215`, chamado por `pickProductForLabel` (`product_picker_sheet.dart:55-74`) nos três caminhos do granel e da leitura pela metade: `camera_page.dart:252` e `:427`, `cart_mode_page.dart:158` e `:597`. Duas regras se somam: (1) o recorte guarda só a primeira palavra e as da lista `_traits` ("carioca", "integral"…), que não tem "prata", "nanica", "italiano", "patinho", "mussarela", "condensado"; (2) quando um produto tem todas as palavras do nome na etiqueta, a escolha abre com o nome dele (`PackageSuggestion.from`), e `sameSearchWords` então tira o "Cadastrar". O "Cadastrar" do granel cria o produto direto com o texto do campo (`createProductByWeight(name)`), sem a conferência que a "Embalagem nova" tem.
- **O que a pessoa vive:** no carrinho, toca no aviso de "BANANA PRATA KG R$ 6,99". A escolha abre com "Banana"; sem nenhum produto, a linha é "Cadastrar Banana", e ela toca. Na semana seguinte, lê "BANANA NANICA KG R$ 4,49". A escolha abre com "Banana", mostra o produto "Banana" e nenhum "Cadastrar"; o título diz só "R$ 4,49/kg", sem o "NANICA" da etiqueta. Ela toca em "Banana". O histórico agora mistura prata e nanica, o menor preço de Produtos é o da nanica, e a comparação entre mercados compara frutas diferentes. O mesmo vale para "QUEIJO MUSSARELA" e "QUEIJO PRATO" (vira "Queijo"), "CARNE MOIDA PATINHO" e "CARNE ACEM" ("Carne"), "TOMATE ITALIANO" e "TOMATE CARMEM" ("Tomate"). O próprio `CreateProductByWeight` dá "Banana prata" e "Tomate italiano" como exemplos de nome.
- **Por que importa:** o G4 queria evitar o produto duplicado; o caminho mais à mão agora funde dois. Fundido é pior que duplicado: o duplicado tem "Juntar com…", e o preço de granel não tem embalagem, então "Mover embalagem" não o tira dali (as observações são imutáveis, ADR 0007). E o produto novo nasce sem acento ("Feijao carioca", "Pao", "Macarrao"), porque a etiqueta não tem acento e o recorte só o guarda quando ela tem; o nome aparece assim no Início, na Lista e em Produtos.
- **O que fazer:**
  1. No granel, o recorte guarda todas as palavras que não são ruído (número, tamanho, embalagem): etiqueta de balança quase nunca traz marca, e uma palavra a mais custa menos que uma variedade a menos. "Banana prata", "Queijo mussarela".
  2. A regra (2) só abre com o nome do produto quando a etiqueta não tem palavra além das dele, da marca e do ruído; com uma palavra a mais ("nanica"), abre com o recorte e o "Cadastrar Banana nanica" fica no fim da lista, depois de "Banana".
  3. A escolha mostra embaixo do título o que a etiqueta disse ("Na etiqueta: BANANA NANICA"), para a pessoa comparar com a linha que vai tocar.
  4. Um dicionário curto de acentos para as palavras mais comuns de mercado (feijão, pão, açúcar, macarrão, maçã, limão, mamão, melão, café, acém, filé), aplicado só ao nome de produto novo, até o catálogo do ADR 0024 dar os nomes.
  5. Testes em `package_suggestion_test.dart` com "BANANA NANICA KG" e `['Banana']`, e "QUEIJO PRATO KG" e `['Queijo mussarela']`.

### G. Produto e embalagens

**G7. A busca do Início ainda diferencia acento e não olha a marca (médio).**

- **Onde:** `_visible` em `lib/features/stock/presentation/home_page.dart:192-200`: `entry.product.name.toLowerCase().contains(query)`. É a única busca de produto que ficou fora do `matchesProductSearch` (`lib/features/products/domain/product_search.dart`).
- **O que a pessoa vive:** na cozinha, procura "acucar" em "Buscar na sua casa" para ver quanto tem. O Início diz que não há nada; na aba Produtos, a mesma palavra acha o "Açúcar refinado". "feijao carioca" e "carioca feijao" também não acham "Feijão carioca" no Início, e "pilao" não acha o café pela marca.
- **Por que importa:** o Início é a busca mais usada e a que responde "tenho em casa?". Uma resposta errada ali vira compra repetida, e as duas abas dão respostas diferentes para a mesma palavra.
- **O que fazer:** filtrar com `matchesProductSearch(query, name: entry.product.name)`, com as marcas se o `StockEntry` as tiver. Teste de widget com "acucar".

**G8. Desfazer o mover, já na tela do produto novo, deixa a pessoa em "Produto não encontrado" (baixo).**

- **Onde:** `_showUndoThenOfferDelete` em `lib/features/products/presentation/product_detail_page.dart:198-230`: mostra o aviso com Desfazer por 10 s (`BipaToastDuration.long`) e, logo depois, abre o destino criado (`push(Routes.productDetail(openProductId))`). O aviso é do `ScaffoldMessenger` do app e continua sobre a tela nova. `MovePackage.undo` apaga o produto criado quando ele fica vazio (`move_package.dart:57-66`), e `ProductDetailPage` mostra então o `EmptyState` "Produto não encontrado" com um `AppBar` do Material (linhas 70-75).
- **O que a pessoa vive:** move o código do Ninho para um produto novo, "Leite Ninho". A tela do Ninho abre, e ela percebe que escolheu a embalagem errada; toca em Desfazer no aviso. A tela vira "Produto não encontrado", com uma barra de outro visual, e ela precisa voltar para ver a embalagem de volta na origem.
- **O que fazer:** o Desfazer, quando o destino foi aberto, fecha essa tela antes de desfazer (`Navigator.pop` se a rota do destino ainda estiver em cima) e deixa a pessoa no produto de origem, que é onde a embalagem volta.

### H. Consistência e acessibilidade

**H17. O cartão do relatório de falhas diz que vai menos do que vai (médio).**

- **Onde:** `crashAskWhy` em `lib/core/l10n/app_pt.arb`: "Vai só o tipo do erro e o modelo do celular." Os Ajustes (`settingsCrashSent1` e `2`) dizem "O tipo do erro e onde ele aconteceu no código" e "Versão do app e do Android, modelo do celular, idioma e fuso", o que bate com o filtro (`safeContextKeys` em `crash_report_scrubber.dart`: `device`, `os`, `app`, `culture`…, e os rastros de ciclo de vida).
- **O que a pessoa vive:** toca em "Mandar" no Início acreditando que sai só o modelo do celular. Se um dia abre os Ajustes, lê uma lista maior.
- **Por que importa:** o cartão é onde o consentimento é dado. A LGPD diz que o consentimento é nulo se a informação dada tiver conteúdo enganoso ou não for apresentada com transparência (art. 9º, § 1º), e o ônus de provar que foi válido é do app (art. 8º, § 2º). Os dados são inofensivos; o "só" é que não é verdade.
- **O que fazer:** tirar o "só" e não listar pela metade: "Vão o erro e dados do celular, como modelo e versão. Seus produtos, preços e lugares ficam aqui." E "Ajustes" no fim da frase vira link para a lista completa. Corrigir antes do primeiro build com DSN (roadmap, "Criar o projeto no Sentry").

**H18. O cartão do relatório de falhas empurra "Acabando" para baixo e chega junto com o fim da compra (baixo, provável).**

- **Onde:** `home_page.dart:308-312`: o `CrashReportingAskCard` fica entre os locais e "Acabando", sem condição além de `askCrashReportingProvider`, que liga assim que a primeira compra tem fim (`hasFinishedTripProvider`). O quadro "InicioRelatorioFalhas" foi desenhado sem "Acabando" na tela.
- **O que a pessoa vive:** termina a primeira compra e volta ao Início. Ao mesmo tempo aparecem o aviso "Compra terminada · Desfazer" (10 s), o anel do bipar respirando (volta de tela cheia, H19) e o cartão novo, com uns 230 dp. Num celular de 360 × 640, o título, a busca, a prévia da lista, os locais e o cartão ocupam a tela, e "Acabando", a informação que o Início existe para dar, fica abaixo da dobra até ela responder. Se ela não responde, fica assim em toda abertura; e o cartão aparece também no meio de uma busca.
- **Por que importa:** "Calma por padrão: um destaque por tela e números importantes à vista" (`CLAUDE.md`). O cartão é neutro, como o quadro pede, mas ocupa o lugar do que tem cor.
- **O que fazer:** pôr o cartão depois de "Acabando" (entre "Acabando" e "Em casa"), esconder durante a busca, e ligá-lo na abertura seguinte do app depois da primeira compra, não no instante em que ela termina. Registrar no quadro a tela com "Acabando".

**H19. O anel recomeça a cada volta de uma tela cheia (baixo).**

- **Onde:** `_ScanButtonState._onTickerModeChanged` em `scan_nav_bar.dart`: quando os tickers da barra voltam, o anel respira duas vezes. O produto, o mercado, os Ajustes e a câmera são rotas de cima (`router.dart:42-81`), então cada volta liga os tickers de novo.
- **O que a pessoa vive:** na aba Produtos, confere o preço de cinco produtos, um depois do outro. A cada "voltar", o anel pulsa por 4,8 s no canto. O mesmo ao voltar da câmera, logo depois de bipar.
- **O que fazer:** é a regra decidida ("quando a barra aparece… ou a pessoa volta da câmera ou de outra tela cheia", `ScanNavBar.md`). Propor ao design system que o anel respire só ao abrir o app e ao voltar do fundo, e não nas voltas de navegação. Fica abaixo dos 5 s do WCAG 2.2.2 nos dois casos; o que muda é quantas vezes por minuto.

### Conferido sem achado

- **Toasts duplicados e o TalkBack (provável).** Numa folha aberta sobre a câmera, o `ScaffoldMessenger` desenha uma cópia atrás e outra por cima (`BipaSheetToasts`). A barreira da folha modal bloqueia a semântica do que está atrás dela, então o leitor de tela só encontra a cópia de cima. As cópias dividem o mesmo `BipaToastClock`, e um Desfazer não roda duas vezes (`acted`). Vale conferir no aparelho.
- **Engrenagem dos Ajustes.** Fica no canto do título do Início, no botão redondo `surface` das outras telas, com o rótulo "Ajustes", e o cartão cita "Ajustes". Em build sem DSN, ela abre uma tela só com a versão; está decidido no `processo.md`.
- **Toque longo da barra da compra.** Não se vê, mas o leitor de tela anuncia o "Mais opções" (`onLongPressHint`), e os três itens do menu (carrinho, guardar e dar baixa em casa) têm outro caminho. Até 160% a barra não tem toque longo, como o guia diz.

## Divergências com o design system e o protótipo

O design system vale sobre o código. As cópias do repositório estão à frente das publicadas (`estado.md`); o que segue é o que sobra além disso.

- **"InicioRelatorioFalhas" sem "Acabando":** o quadro põe o cartão "no lugar do carrossel de insights" numa casa sem nada acabando; no app, ele fica acima de "Acabando". Proposta em H18.
- **Escolha de produto fora do design system:** `product_picker_sheet.dart` continua com `TextField`, `ListTile` e `CircleAvatar` em `brandSoft`. O item "H1 (resto)" do roadmap fala só dos formulários; incluir o seletor, que agora é por onde passa todo o granel.
- **"Cadastrar" do granel sem conferência:** a "Embalagem nova" mostra a sugestão para a pessoa conferir (`PackageSuggestion`: "É só uma sugestão"); o "Cadastrar" do granel cria o produto direto com o texto do campo. Ver G6.
- **`ScanNavBar.md`:** o vidro do bundle tem `saturate(1.5)`; o código não, e o guia não diz que é de propósito (já no lote 9).
- **`estado.md`:** "Próximos passos" ainda lista os achados do lote 9 como a fazer, e a lista do teste no aparelho não tem o lote 10 (o "Tempo para agir", o toque longo da barra com letra grande, o cartão com DSN, o recorte do granel).

## Referência primeiro, do nosso jeito depois

Seguindo [processo.md](../design/processo.md), o que outras fontes fazem nos pontos novos.

| Problema | Referência | O que levamos | O que fazemos diferente |
| --- | --- | --- | --- |
| Texto do consentimento | **LGPD**, art. 8º, § 2º, e art. 9º, § 1º ([texto da lei](https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm)); **iOS** (Análises e Melhorias, no `processo.md`) | O que se diz na hora do sim é o que vai, sem "só"; a lista completa a um toque | O cartão fica curto e manda para os Ajustes, onde a lista já está aberta, sem página à parte |
| Nome de produto a partir de etiqueta | A "Embalagem nova" do próprio Bipa (`PackageSuggestion`, ADR 0013) | A sugestão recortada, conferida antes de salvar | No granel, a variedade é parte do nome: o recorte tira tamanho e ruído, não palavras que distinguem o produto |
| Revisão ao fim de uma captura em lote | **Pantry Check** e **Adobe Scan** (no `processo.md`, "Quando aparece Arrumar o que entrou") | Não perguntar de novo o que já foi respondido | "Respondido" é o local **e** o "ter sempre": a escolha no aviso usa o mesmo editor da folha |

## Lotes sugeridos

Em ordem. Os dois primeiros não pedem quadro.

1. **Granel sem fundir variedades** (G6, G7). Recorte do granel com todas as palavras, "Cadastrar" quando a etiqueta tem palavra a mais, o texto da etiqueta na escolha, acentos comuns no nome novo e a busca do Início com `matchesProductSearch`.
2. **Consentimento honesto** (H17, H18). Uma frase no ARB e o link para os Ajustes, o cartão depois de "Acabando" e na abertura seguinte. Antes de gerar o build com DSN.
3. **"Ter sempre" no aviso da câmera** (AB14). Quadro "CapturaCasaLocal" com o editor da folha na escolha do local, depois o código.
4. **Acabamentos** (G8, H19). O Desfazer que volta para a origem; a regra do anel começa no design system.

## O que funciona bem (manter)

- **O tempo do aviso numa função só.** `bipaToastTimeout` decide para o `bipa-toast` e para o aviso da câmera: espera o leitor de tela quando há botão, respeita o "Tempo para agir" do Android (lido de novo a cada volta do fundo) e usa o maior dos tempos. O anel da espera do par fica fora, com o motivo escrito.
- **A pausa sob o dedo nas cópias do aviso.** Um relógio dividido pelas cópias (tela e folha, ou duas telas na transição), com a primeira a chegar ao fim tirando o aviso.
- **O aviso de duas linhas só quando precisa.** O nome corta, o local nunca, e o leitor de tela ouve número, nome, local e "trocar o local" numa frase.
- **A busca por palavra com a regra no domínio.** `matchesProductSearch` e `sameSearchWords` testadas à parte, e o "Cadastrar" depois dos resultados.
- **A idade do preço só quando importa,** com o mesmo limiar de F1 e F4.
- **Ajustes com o que vai e o que nunca vai abertos sob o interruptor,** e o × do cartão que diz o que faz ("Fechar sem mandar").
- **Um amarelo só com letra grande na compra,** sem tirar nenhum caminho: o menu do bipar continua no toque longo, anunciado ao leitor de tela.

## Fontes

Base interna: `CLAUDE.md`, `docs/estado.md`, `docs/roadmap.md`, o ADR 0025, `docs/design/processo.md`, os guias `BipFeedback.md`, `ScanNavBar.md` e `ShoppingBar.md`, `docs/design/design-system/fonte/bundle.css`, o protótipo em `docs/design/prototipo/` (README e os quadros InicioRelatorioFalhas, Ajustes, ArrumarEntrouRegra, CapturaCasaLocalNomeLongo e NavLetraGrandeCompra) e o código em `lib/` e `test/` no commit `47edb8d` (diff `79fc21f..47edb8d`). Nada foi compilado; as alturas de H18 foram estimadas pelo layout.

Referências externas:

- [Lei 13.709/2018 (LGPD), texto oficial](https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm)
- [LegJur: LGPD, art. 9º](https://www.legjur.com/legislacao/art/lei_00137092018-9)
- [W3C: Understanding SC 2.2.2 Pause, Stop, Hide](https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html)
