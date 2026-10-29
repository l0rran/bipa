# Análise de UX do Bipa (lote 11)

> Análise feita no commit `b88c49c`, sobre o que entrou depois de `c55b679`: o recorte da etiqueta que guarda a variedade do granel, tira só ruído e marcas conhecidas e acentua as palavras comuns, com a dica "Na etiqueta" e o "Criar" da variedade na escolha de produto (G6); a busca do Início com `matchesProductSearch` (G7); o texto do cartão do relatório de falhas sem "só", o link "O que vai" e a lista dos Ajustes conferida com o filtro (H17); o cartão depois de "Acabando" e só na abertura seguinte à compra (H18); e o Desfazer do mover que fecha o produto criado e volta à origem (G8). Os caminhos e o "o que a pessoa vive" descrevem o app desse commit. As análises anteriores estão em [lote 7](analise-ux-2026-10-28.md), [lote 8](analise-ux-2026-10-28-lote8.md), [lote 9](analise-ux-2026-10-28-lote9.md) e [lote 10](analise-ux-2026-10-28-lote10.md).

Oct 29, 2026 · @Wesley

## Resumo

O lote fecha G6, G7, H17 e G8, e H18 fica parcial. A variedade do granel não cai mais no produto da primeira ("BANANA NANICA" oferece "Criar “Banana nanica”" depois de "Banana"), o nome novo nasce com acento, a busca do Início acha "Açúcar" por "acucar", e o cartão do consentimento não promete menos do que vai. O que sobrou é pequeno e, de novo, nasce das próprias correções:

1. **Uma palavra diferente na etiqueta esconde o produto que já existe (G9, médio, provável).** Guardar todas as palavras do granel resolveu a fusão, mas a busca pede todas elas: "LIMAO TAITI KG" não mostra o "Limão tahiti" cadastrado em outro mercado, e "MUSSARELA TIROLEZ KG" não mostra o "Queijo mussarela". A escolha abre só com "Criar", e o produto se duplica.
2. **Voltar do produto criado tira o Desfazer da tela (G10, médio).** Quando a origem fica vazia, o aviso "ficou sem embalagem · Apagar produto" entra assim que a pessoa volta, no lugar do Desfazer, que ainda tinha segundos para correr.
3. **O nome novo sai com meio acento (G11, baixo).** "PAO FRANCES KG" vira "Pão frances"; o dicionário cobre bem o empacotado e deixa de fora palavras de balança como francês, linguiça, abóbora, grão e suíno.
4. **O cartão do relatório continua no meio da busca (H18, resto, baixo).** Com a pessoa buscando, ele fica entre "Nada com esse nome" (ou "Acabando") e os resultados de "Em casa", que descem para baixo do teclado.

Os dois primeiros são correções de regra, sem quadro. Nenhum bloqueia o build com DSN: o texto do cartão está honesto.

## Situação dos achados anteriores

Das quatro análises anteriores saíram 63 achados. Este lote resolveu G6, G7, G8 e H17, e H18 ficou parcial. Hoje são 58 resolvidos, 3 parciais (H1, H3 e H18) e 2 abertos (AB14 e H19); nenhum regrediu. Dois dos resolvidos abriram achados novos (G6 → G9 e G11; G8 → G10). Abaixo, só os itens que este lote tocou ou que não estão fechados; os demais seguem como na análise do lote 10. "Conferido" quer dizer lido no código deste commit.

| ID | Achado anterior | Situação | O que mudou |
| --- | --- | --- | --- |
| G6 | Recorte tira a variedade do granel | Resolvido, com achados novos (conferido) | `productNameFromLabel` em `package_suggestion.dart:336` guarda toda palavra que não é número, tamanho, unidade, embalagem nem uma das ~50 marcas de `_knownBrands`; `_accents` acentua 34 palavras. A escolha recebe `label` e `newName`: "Na etiqueta: …" sob a busca e "Criar" com o recorte sempre que a etiqueta tem palavra que o produto achado não tem (`_createName`, `sameSearchWords` contra o nome a criar). A palavra a mais também esvazia a busca (G9), e o acento fica pela metade em palavras de balança (G11). |
| G7 | Busca do Início diferencia acento | Resolvido (conferido) | `_visible` em `home_page.dart:195` usa `matchesProductSearch` só com o nome. A marca ficou de fora, mas o vazio diz "Nada com esse nome na sua casa", então a tela não promete buscar por marca. |
| G8 | Desfazer do mover leva a "Produto não encontrado" | Resolvido, com achado novo (conferido) | `onAction` em `_showUndoThenOfferDelete` fecha a tela do destino (`router.pop()`) se ela é a rota de cima, antes de desfazer; com `undone`, o segundo aviso não vem. Voltar sem desfazer ainda troca o Desfazer pelo segundo aviso (G10). |
| H17 | Cartão diz que vai menos do que vai | Resolvido (conferido) | `crashAskWhy`: "Vão o erro e dados do celular, como modelo e versão…", sem "só" e com "como" marcando exemplo; `crashAskDetails` "O que vai" (`TextButton` de 48 dp, sublinhado, `ink`) abre os Ajustes, onde a lista ganhou o Flutter, os dados técnicos e `settingsCrashSent3` (os rastros de ciclo de vida), o que bate com `safeContextKeys` e `safeBreadcrumbCategories`. |
| H18 | Cartão empurra "Acabando" e chega com o fim da compra | Parcial (conferido) | O cartão saiu de cima de "Acabando" (`home_page.dart:352-357`) e espera `finishedTripBeforeSessionProvider` (`watchAnyFinished(before: appSessionStartProvider)`). Falta escondê-lo durante a busca, que o lote 10 também pedia (H18, resto). |
| H1 | Abas com dois visuais | Parcial (conferido) | A escolha de produto ganhou a dica em `BipaText.caption`, mas segue com `TextField`, `ListTile` e `CircleAvatar` (`product_picker_sheet.dart:168-236`). Item "H1 (resto)" no roadmap. |
| H3 | Alturas fixas com texto dentro | Parcial | Sem mudança: a câmera e o carrinho continuam fora do teste a 200%. |
| AB14 | Escolher o local no aviso tira o "ter sempre" | Aberto | Não tocado; pede o quadro "CapturaCasaLocal" antes. |
| H19 | Anel recomeça a cada volta de tela cheia | Aberto | Não tocado; pede a regra no design system antes. |

## Problemas por jornada

Caminhos relativos ao repositório. Tudo foi avaliado lendo o código, sem compilar. Gravidade: crítico perde dado ou bloqueia a tarefa; alto é dado errado ou caminho principal confuso; médio é atrito; baixo é acabamento. "Provável" quando o efeito depende de rodar o app ou do que o OCR lê.

### D. Câmera do bipar e modo carrinho

**G9. Uma palavra diferente na etiqueta esconde o produto que já existe (médio, provável).**

- **Onde:** `productQueryFromLabel` em `lib/features/products/domain/package_suggestion.dart:388-415`, pelos dois `_chooseGranel` (`camera_page.dart:247`, `cart_mode_page.dart:147`). O texto inicial é o recorte inteiro (`productNameFromLabel`) quando nenhum produto tem todas as palavras do próprio nome na etiqueta. A busca da escolha (`watchAll(query:)`, com `matchesProductSearch`) pede todas as palavras do recorte, e a saída do passo 3 só troca o texto quando um produto tem **mais da metade** delas (`bestCount * 2 > words.length`, linha 414): com duas palavras, uma em comum não basta.
- **O que a pessoa vive:** cadastrou "Limão tahiti" no Atacarejo. No outro mercado, a balança escreve "LIMAO TAITI KG". A escolha abre com "Limão taiti", a dica "Na etiqueta: LIMAO TAITI KG" e uma linha só: "Criar “Limão taiti”". O limão que ela já tem não aparece, e ela cria outro. O mesmo com marca de frios que não está em `_knownBrands` ("MUSSARELA TIROLEZ KG" com "Queijo mussarela" cadastrado: abre só "Criar “Mussarela tirolez”") e com a abreviação de balança ("QJO MUSS FAT KG"). No lote 10, o recorte "Limao" ou "Mussarela" achava o produto.
- **Por que importa:** o G6 trocou a fusão por duplicação de propósito ("uma palavra a mais custa menos que uma variedade a menos"), mas a troca supunha que a palavra a mais só alonga o nome. Ela também esvazia a lista, e a pessoa nem vê a opção de usar o que existe. O histórico do limão se parte por mercado, que é justamente a comparação que o Bipa promete. Dá para juntar depois ("Juntar com…"), mas só quem percebe.
- **O que fazer:** estender o mecanismo do próprio G6. Quando o recorte inteiro não acha nada e a primeira palavra dele acha, a busca abre com a primeira palavra ("Limão", "Mussarela") e o `newName` continua sendo o recorte, então a lista mostra "Limão tahiti" e, no fim, "Criar “Limão taiti”", com a dica da etiqueta em cima para comparar. Testes em `package_suggestion_test.dart` com "LIMAO TAITI KG" e `['Limão tahiti']`, e "MUSSARELA TIROLEZ KG" e `['Queijo mussarela']`, esperando a primeira palavra como texto inicial.

**G11. O nome novo sai com meio acento nas palavras de balança (baixo).**

- **Onde:** `_accents` em `lib/features/products/domain/package_suggestion.dart:250`, aplicado palavra por palavra por `productNameFromLabel`. Das 34 palavras, muitas são de empacotado (açúcar, álcool, higiênico, requeijão); faltam as que mais aparecem na etiqueta de balança e da gôndola de granel: francês, grão (só há "grãos"), linguiça, abóbora, parmesão, salmão, tilápia, rúcula, agrião, jiló, suíno e suína, padrão, contrafilé, almôndega.
- **O que a pessoa vive:** na padaria do mercado, toca no aviso de "PAO FRANCES KG" e cria o produto. Ele aparece no Início, na Lista e em Produtos como "Pão frances". Do mesmo jeito: "Grao de bico", "Linguica toscana", "Lombo suino", "Queijo minas padrao".
- **Por que importa:** meio acento chama mais atenção do que nenhum, e o pão francês é provavelmente o granel mais comprado do país. O nome vai para a busca e para a lista que a pessoa lê no mercado.
- **O que fazer:** acrescentar essas palavras a `_accents`, com a mesma regra (só palavra sem outra leitura no mercado), e um teste com "PAO FRANCES KG" → "Pão francês". Até o catálogo do ADR 0024 dar os nomes.

### G. Produto e embalagens

**G10. Voltar do produto criado troca o Desfazer pelo "ficou sem embalagem" (médio).**

- **Onde:** `_showUndoThenOfferDelete` em `lib/features/products/presentation/product_detail_page.dart:197-256`. Com `openProductId`, a oferta de apagar espera só a volta da tela do destino (`await push(...)`, linha 237); sem ele, espera o aviso fechar (`controller.closed`, linha 241). Ao voltar, se a origem ficou vazia, `showBipaToast` mostra "{nome} ficou sem embalagem, preço e estoque. · Apagar produto", e `showBipaToast` começa com `messenger.hideCurrentSnackBar()` (`bipa_toast.dart:110`): o Desfazer de 10 s some na hora.
- **O que a pessoa vive:** o produto "Leite" só tem a embalagem do Ninho. Ela move a embalagem para um produto novo, "Leite Ninho"; a tela dele abre com "Embalagem movida para Leite Ninho. · Desfazer". Percebe que escolheu errado e faz o gesto mais natural, voltar, para conferir a origem. Na volta, o aviso já é outro, com "Apagar produto" no lugar exato onde estava o Desfazer. Para desfazer, ela precisa mover a embalagem de volta pelo menu e apagar o "Leite Ninho" à mão. Quem toca no botão por reflexo cai na confirmação de apagar o "Leite".
- **Por que importa:** o H13 deu 10 s ao Desfazer das ações grandes (e espera o TalkBack); aqui o tempo acaba quando a pessoa volta, que é justamente quando ela costuma querer desfazer. O caminho sem destino aberto já espera o primeiro aviso fechar, então são duas regras para a mesma oferta.
- **O que fazer:** no caminho com destino aberto, esperar a volta **e** o aviso fechar (`await push(...)` e depois `await controller.closed`) antes do segundo aviso. Teste de widget: mover para um produto novo, voltar sem desfazer e conferir que o Desfazer continua na tela.

### H. Consistência e acessibilidade

**H18 (resto). O cartão do relatório de falhas fica no meio da busca (baixo).**

- **Onde:** `home_page.dart:352-357`: o `CrashReportingAskCard` entra sem olhar `_query` nem `_place`, entre "Acabando" e "Em casa" (e logo depois de "Nada com esse nome na sua casa." quando a busca não acha nada).
- **O que a pessoa vive:** na abertura seguinte à primeira compra, antes de responder ao cartão, busca "arroz" para ver se tem em casa. Com o teclado aberto, a tela mostra o título, a busca, os locais e o cartão, de uns 260 dp com o link novo; o "Arroz" de "Em casa" fica embaixo do cartão e do teclado. Quando a busca não acha nada, o cartão aparece logo abaixo do "Nada com esse nome".
- **O que fazer:** esconder o cartão com `_query` não vazio ou um local escolhido, como o lote 10 propôs. Ele volta quando a busca esvazia, e nada muda na regra de "uma vez".

### Conferido sem achado

- **Nomes com marca desconhecida ou abreviação.** "Feijão carioca sao jorge" ou "Leite cond" só nasceriam no granel: a leitura pela metade (`_chooseProductFor`, nos dois arquivos) abre a escolha com `allowCreate: false`, e a "Embalagem nova" usa `PackageSuggestion.from`, que sugere só a primeira palavra e põe o resto na marca. No granel, quem tem marca na etiqueta são os frios, e o nome a criar aparece inteiro no "Criar “…”" antes do toque, editável no campo. O problema real desse caso é a busca vazia (G9), não o nome.
- **Os dois caminhos da escolha.** Com "Banana" cadastrada, "BANANA NANICA KG" abre com "Banana" no campo, "Na etiqueta: BANANA NANICA KG" embaixo, a linha "Banana" e, no fim, "Criar “Banana nanica”". O texto do "Criar" diz o nome que vai nascer, e a dica dá o que comparar. Se a pessoa digita, o "Criar" passa a usar o que ela digitou (`_createName`), o que é o esperado. Sem palavra a mais ("BANANA KG"), o "Criar" some (`sameSearchWords`).
- **"Na abertura seguinte" e o processo do Android.** `appSessionStartProvider` é lido uma vez por processo. Se o Android mantém o Bipa em segundo plano, o cartão espera, mas não para sempre: o processo cai ao tirar o app dos recentes, ao atualizar, ao reiniciar e por falta de memória, e no Android 8 a 11 o "voltar" na tela inicial fecha a atividade e recria o motor. A demora está escrita no ADR 0025. Com o texto honesto, esperar uns dias custa pouco.
- **O texto do cartão e o link.** "Vão o erro e dados do celular, como modelo e versão" é verdadeiro e diz que é exemplo; a lista inteira está a um toque. O filtro (`crash_report_scrubber.dart`) confirma o "ficam aqui": a mensagem de exceção sai, menos dos tipos da linguagem, e só passam os contextos e rastros listados. O leitor de tela ouve "O que vai, botão" logo depois do parágrafo que cita os Ajustes, o que basta como contexto (WCAG 2.4.4).
- **G8 com o leitor de tela.** O Desfazer fecha a tela do destino antes de apagar o produto, então o foco volta para a origem e não passa por "Produto não encontrado".

## Divergências com o design system e o protótipo

O design system vale sobre o código. As cópias do repositório estão à frente das publicadas (`estado.md`); o que segue é o que sobra além disso.

- **"InicioRelatorioFalhas" com o texto antigo:** o HTML do quadro (`docs/design/prototipo/fonte/InicioRelatorioFalhas.dc.html:62`) e a imagem ainda dizem "Vai só o tipo do erro e o modelo do celular" e não têm o link "O que vai" nem "Acabando". O README do protótipo registra a diferença, mas, com a regra de que o design system vale, quem confere a tela pelo quadro pode "corrigir" o app de volta para o texto que a LGPD não aceita. Redesenhar a cópia (com `tool/prototipo/renderizar.js`) com o texto novo e o cartão depois de "Acabando".
- **Escolha de produto sem quadro:** a dica "Na etiqueta: …" e o "Criar" da variedade entraram sem quadro, e a folha segue fora do design system (`TextField`, `ListTile`, `CircleAvatar` em `brandSoft`). O item "H1 (resto)" do roadmap já inclui o seletor; o quadro dele deve ter a dica da etiqueta e os dois caminhos (produto achado e "Criar"), e o G9 entra no mesmo desenho.
- **`estado.md`:** "Próximos passos" ainda descreve o lote 11 como interrompido em branches `wip:`, e a lista do teste no aparelho não tem o "Criar" da variedade, a dica da etiqueta nem o cartão na abertura seguinte.
- **`ScanNavBar.md`:** o vidro sem `saturate(1.5)` continua sem registro (desde o lote 9).

## Referência primeiro, do nosso jeito depois

Seguindo [processo.md](../design/processo.md), o que outras fontes fazem nos pontos novos.

| Problema | Referência | O que levamos | O que fazemos diferente |
| --- | --- | --- | --- |
| Busca que não acha por uma palavra | O próprio passo 1 do `productQueryFromLabel` (G6): abre com o nome do produto achado e oferece criar o recorte | Separar o texto da busca (o que acha) do nome a criar (o que a etiqueta diz) | Quando o recorte inteiro não acha nada, o texto da busca encolhe para a primeira palavra, sem adivinhar qual produto é |
| Dois avisos seguidos | **Material 3**, Snackbar ([guia](https://m3.material.io/components/snackbar/guidelines)): um aviso por vez, e o seguinte espera o anterior sair | O segundo aviso espera o primeiro fechar | Esperar também a volta da tela do destino, para a oferta de apagar não chegar com a pessoa fora da origem |

## Lotes sugeridos

Em ordem. Nenhum pede quadro novo.

1. **Escolha de produto que mostra o que existe** (G9, G11). A primeira palavra como busca quando o recorte não acha nada, e os acentos de balança. Os dois em `package_suggestion.dart`, com testes no port de domínio.
2. **Desfazer que espera a pessoa** (G10, H18 resto). O segundo aviso espera o primeiro fechar, e o cartão some durante a busca.
3. **Quadros** (AB14, H19, H1 resto). "CapturaCasaLocal" com o "ter sempre", a regra do anel no design system e o quadro da escolha de produto, com a dica da etiqueta. Junto, redesenhar "InicioRelatorioFalhas" com o texto novo.

## O que funciona bem (manter)

- **O nome a criar separado do texto da busca.** O G6 resolveu a fusão sem tirar o atalho: a lista mostra o que existe e o "Criar" diz o nome que vai nascer, com a etiqueta embaixo para comparar.
- **Marca só por lista.** Uma palavra só sai do nome se for marca conhecida; na dúvida, fica. Erra para o lado que se conserta com "Juntar com…".
- **O consentimento conferido contra o filtro.** A lista dos Ajustes foi refeita a partir de `safeContextKeys` e `safeBreadcrumbCategories`, e o cartão remete a ela em vez de resumir pela metade.
- **A abertura seguinte sem esquema novo.** Um instante lido uma vez por processo e uma consulta sobre `finishedAt`: o cartão não disputa a tela com o "Compra terminada · Desfazer" nem com o anel.
- **O Desfazer que fecha a tela certa.** Só tira o destino se ele é a rota de cima; se a pessoa já voltou, só desfaz.

## Fontes

Base interna: `CLAUDE.md`, `docs/estado.md`, `docs/roadmap.md`, o ADR 0025, `docs/design/processo.md`, o README do protótipo e os quadros `InicioRelatorioFalhas` e `ModoCarrinhoGranel`, a análise do lote 10 e o código em `lib/` e `test/` no commit `b88c49c` (diff `c55b679..b88c49c`). Nada foi compilado; os cenários do G9 e do G11 foram seguidos à mão pelas funções `productNameFromLabel`, `productQueryFromLabel` e `matchesProductSearch`, e a altura do cartão em H18 foi estimada pelo layout.

Referências externas:

- [Material Design 3: Snackbar, guidelines](https://m3.material.io/components/snackbar/guidelines)
- [W3C: Understanding SC 2.4.4 Link Purpose (In Context)](https://www.w3.org/WAI/WCAG22/Understanding/link-purpose-in-context.html)
