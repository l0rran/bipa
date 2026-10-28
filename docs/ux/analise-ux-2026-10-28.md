# Análise de UX do Bipa (lote 7)

> **Cópia exportada** em 28/10/2026 do documento publicado no claude.ai ([link](https://claude.ai/artifact/VeoUk6VjBSRWCox1prVyMr)), para agentes e pessoas sem acesso a ele. O texto é o da análise, feita no commit `819b679`: os caminhos, as linhas e o "o que a pessoa vive" descrevem o app daquela época. **O que já foi feito está no [CHANGELOG](../../CHANGELOG.md), e o que falta, com o código de cada achado, em [roadmap.md](../roadmap.md#ajustes-de-ux-análise-de-28102026).** Use esta página para entender o problema e a solução proposta de um código (AB5, G2, H1...), não para saber se ele está pendente.

Oct 28, 2026 · @Wesley

## Resumo

Dos 38 achados da análise anterior, 25 foram resolvidos e 13 avançaram em parte. O app agora abre a câmera direto, termina a compra com uma folha honesta e liga casa e lista. Os problemas que sobram estão nas bordas desses fluxos novos:

1. **Preços podem se perder ou cair no mercado errado durante a compra (CE1, D1, D2).** O que foi lido sem mercado vive só na tela do carrinho, trocar de mercado não leva os preços já lidos, e o disparo amarelo grava no mercado do GPS.
2. **Lista e estoque ainda se desencontram fora dos caminhos do ADR 0019 (AB1, AB2, CE2, CE3).** O "+" chamado "Comprei um" não tira da lista, o modo "Comprei" some depois da primeira carga, o "3×" sai inteiro com um bipe, e o "Terminei" leva para casa o que foi marcado dias antes.
3. **Sinais que se contradizem (F1, F2, H1).** Em Mercados, duas idades com o mesmo nome e uma barra que desmente o selo; e a aba Produtos e o leitor antigo ainda fora do design system.

O segundo se resolve quase todo com os ganhos rápidos 1 a 3. O primeiro tem um paliativo barato (item 4), mas a solução completa pede um ADR.

## Situação dos achados anteriores

Dos 38 achados da análise anterior, 25 estão resolvidos e 13 parciais; nenhum ficou como estava. O que falta em cada parcial está nos achados novos indicados entre parênteses.

| ID | Achado anterior | Situação | O que mudou |
| --- | --- | --- | --- |
| A1 | O bipar abria um formulário | Resolvido | O toque abre a câmera ao vivo, ou o carrinho durante a compra. |
| A2 | O ícone de bipar fazia três coisas | Resolvido | A busca do Início encontra o produto; ainda usa o leitor antigo (H1). |
| A3 | O estado vazio escondia busca e lista | Resolvido | Busca e prévia ficam; "Bipar produtos" abre a câmera contínua. |
| A4 | Mercado gravado com a localização de casa | Resolvido | Só preenche sozinho quando o cadastro vem de dentro da compra. |
| A5 | Permissões sem explicação | Resolvido | Um motivo antes dos pedidos da compra, uma vez por sessão. |
| A6 | Texto da Lista vazia | Resolvido | O texto muda quando não há itens de sempre. |
| B1 | "Ter sempre" enterrado | Parcial | Visível no chip e no produto; não é pedido na primeira carga (AB5). |
| B2 | "Pôr na lista" fora do editor | Resolvido | Botão no editor e ações do TalkBack nos gestos. |
| B3 | Cartão e linha com toques diferentes | Resolvido | Os dois abrem o editor; o guia ficou desatualizado (AB8). |
| B4 | Não dava para tirar nada | Resolvido | Apagar produto e mercado, e "Tirar de casa" (ADR 0016). |
| B5 | "un" ambíguo | Resolvido | Virou "emb.". |
| C1 | Carrinho longe e "Terminei" em destaque | Resolvido | "Ir às compras" abre o carrinho; "Terminei" virou secundário. |
| C2 | "Tirar comprados" mexia no estoque | Resolvido | Some durante a compra e tem Desfazer. |
| C3 | Lista sem quantidade | Resolvido | Quantidade existe; ressalvas em CE3 e CE6. |
| C4 | Não dava para cancelar a compra | Parcial | Existe só no menu da Lista e não desmarca os itens (CE2, CE7). |
| C5 | "≈" em todo preço | Resolvido | Só no preço estimado por outro mercado. |
| D1 | Preços sem mercado fora do histórico | Parcial | Gravados quando o mercado aparece, mas só com o carrinho aberto (CE1). |
| D2 | Código desconhecido em snackbar | Resolvido | Abre "Embalagem nova" na hora. |
| D3 | Granel e balança sem caminho | Parcial | Balança resolvida; granel não entra no carrinho (D3). |
| D4 | Preço esperado igual ao lido | Resolvido | Contorno no estimado; agora sobra um sinal (D7). |
| D5 | Leitura errada para sempre | Parcial | Corrige no carrinho (ADR 0017); fora dele, não (F3). |
| D6 | Quantidade fixa na bandeja | Resolvido | Tocar no nome abre o stepper. |
| D7 | Preço esperando cai no produto errado | Parcial | Anel e checagem de seção; a mesma etiqueta relida ainda escapa (D4). |
| D8 | Alvos pequenos | Resolvido | 48 dp no interruptor, na mini etiqueta, no stepper e nos chips. |
| D9 | Detalhes do carrinho | Parcial | Som e movimento reduzido na bandeja; a alça ignora a direção (D7). |
| E1 | "Terminei" sem resultado | Resolvido | Folha "Fim da compra" com total, embalagens, economia e faltas. |
| E2 | "Terminei" da notificação num toque | Resolvido | Abre a folha; só termina em "Terminar compra". |
| F1 | Comparação coroava o mercado errado | Parcial | Selo justo no domínio; a barra e as idades confundem (F1, F2). |
| F2 | Preço do produto na embalagem errada | Parcial | A linha da embalagem acerta; o menu e a foto não (G3). |
| F3 | Coral em preço antigo | Resolvido | Idade em cinza com relógio. |
| F4 | "o kg" e "/kg" juntos | Resolvido | Só "/kg" no app; o protótipo ainda diz "o kg". |
| F5 | Toque no mercado abria a edição | Resolvido | Abre a tela do mercado. |
| G1 | "Embalagem nova" sem saída | Resolvido | "Salvar" sem produto explica o que falta. |
| G2 | Mesmo código, produtos diferentes | Parcial | Câmera e carrinho usam a folha; o formulário antigo não (D2). |
| G3 | "Juntar com…" sem retorno | Resolvido | Abre o produto que fica e confirma. |
| H1 | Telas antigas e novas na mesma jornada | Parcial | Tema corrigido; Produtos, formulários e leitor antigo continuam (H1). |
| H2 | Textos grandes cortam | Parcial | Parte corrigida; alturas fixas no stepper e nos selos (H3). |
| H3 | Erro técnico exposto | Parcial | Sem erro cru, mas sem "Tentar de novo" (H2). |

Das divergências com o protótipo, a barra de navegação que encolhe ao rolar segue aberta, e o movimento reduzido só é respeitado na bandeja do carrinho.

## Problemas por jornada

Caminhos relativos ao repositório. Tudo foi avaliado lendo o código, sem compilar. Gravidade: crítico perde dado ou bloqueia a tarefa; alto é erro frequente ou caminho principal confuso; médio é atrito; baixo é acabamento.

### A e B. Primeira abertura e em casa

**AB1. "Usei um" e "Comprei um" fazem coisas diferentes conforme o controle (alto).**

- **Onde:** `home_page.dart` (`_HomeStockRow`: o deslizar chama `_used` → `RecordAtHome.used`; o stepper chama `_adjust`, que só mexe no estoque), o mesmo stepper em `stock_item_sheet.dart` e no cartão "Em casa" de `product_detail_page.dart`, e o guia `StockStepper.md`.
- **O que a pessoa vive:** volta da padaria, abre a linha do leite e toca no "+", que o TalkBack chama de "Comprei um". O estoque sobe, mas o leite continua na lista, e ela compra de novo na próxima ida. No sentido oposto, deslizar "Usei um" põe na lista com aviso, e o "−" do stepper, também "Usei um", não põe nem avisa.
- **Por que importa:** Nielsen 4 (o mesmo nome, o mesmo efeito) e a voz do Bipa, em que o botão diz o que acontece. O ADR 0019 chama o stepper de correção, mas os rótulos dizem que ele registra uma compra ou um uso.
- **O que fazer:** reservar "Usei um" e "Comprei um" para o que passa pelo `RecordAtHome`, e dar ao stepper rótulos de correção ("Uma embalagem a menos" / "a mais"). Ao fechar a linha ou a folha, se o item cruzou o "ter sempre", um único aviso oferece "Pôr na lista" ou "Tirar da lista". Levar ao protótipo antes.

**AB2. O modo "Comprei" só existe com a casa vazia (alto).**

- **Onde:** a única porta para `Routes.cameraBought` é o estado vazio (`home_page.dart:179`). O menu do bipar (`home_shell.dart`, `_openScanMenu`) tem só "Modo carrinho" e "Dar baixa em casa", e o seletor da câmera, só Etiqueta e Código.
- **O que a pessoa vive:** depois do primeiro item, não há mais como bipar uma compra feita fora do modo compra (padaria, farmácia, entrega). Sobram o "+" do stepper, que não tira da lista (AB1), ou começar uma compra só para dar "Terminei".
- **Por que importa:** o "fechar o ciclo" do roadmap só funciona na primeira carga. "Dar baixa" fica a um toque longo, e "Comprei", em lugar nenhum (Nielsen 7, eficiência).
- **O que fazer:** acrescentar "Guardar em casa" ao menu do bipar, entre "Modo carrinho" e "Dar baixa em casa". Atualizar o `MenuBipar` no protótipo primeiro.

**AB3. Deslizar "Usei um" tira a linha de vista, e o aviso só fala da lista (médio).**

- **Onde:** `home_page.dart` (`inShelf`, que leva para "Acabando" o que ficou baixo) e `home_change_snack_bar.dart` ("Leite foi para a lista").
- **O que a pessoa vive:** desliza o leite de 2 para 1, com "ter sempre 2". A linha some de "Em casa" e vai para "Acabando", muitas vezes fora da tela. O aviso diz só "Leite foi para a lista", e nenhum lugar mostra quanto ficou. Sumir ao deslizar parece apagar.
- **Por que importa:** Nielsen 1 (estado visível) e "números importantes à vista". Na câmera, o visor mostra "Leite · 1 em casa"; no Início, nada faz esse papel.
- **O que fazer:** manter a linha no lugar, já com o anel coral, enquanto o aviso estiver na tela (como já se faz com a linha aberta), e só depois levá-la para "Acabando".

**AB4. Deslizar para a direita põe ou tira da lista sem aviso nem desfazer (médio).**

- **Onde:** `home_page.dart` (`swipeRight` e `_toggleList`). "Tirar" chama `removeProduct`, que apaga a linha com a quantidade ajustada.
- **O que a pessoa vive:** o mesmo gesto põe ou tira conforme um selo pequeno na miniatura. Quem desliza para pôr um item que já estava na lista o tira, sem aviso e sem volta.
- **Por que importa:** o `StockStepper.md` promete aviso com Desfazer para os dois gestos (Nielsen 3, controle e liberdade).
- **O que fazer:** o mesmo aviso dos gestos de casa ("Leite saiu da lista", com Desfazer; o `restore` já existe).

**AB5. A primeira carga deixa "Acabando" e os locais sem uso (médio).**

- **Onde:** o item novo nasce sempre na Despensa (`drift_stock_repository.dart`, `StockLocation.pantry`), e nem a câmera "Comprei" nem a folha "Embalagem nova" perguntam local ou "ter sempre".
- **O que a pessoa vive:** bipa 25 itens e vê "Despensa 25", leite e sabão incluídos. "Acabando" só mostra o que zerar, e "De sempre" fica vazio. Para mudar isso, abre item por item.
- **Por que importa:** é a queixa do Pantry Check registrada no `processo.md` (montar o estoque inicial cansa), e o filtro de locais deixa de informar.
- **O que fazer:** ao fechar a câmera da primeira carga, uma folha "Arrumar o que entrou", que dá para pular, com local e "ter sempre" por produto. A opção mais barata é sugerir o local pela categoria que `productCategoryIcon` já deduz.

**AB6. O chip "Ter sempre" é a única porta para o resto do item (médio).**

- **Onde:** `home_page.dart`: o `DropdownChip` "Ter sempre 2" abre a folha com local, "Tirar de casa" e "Ver produto e preços".
- **O que a pessoa vive:** para mudar o leite para a Geladeira, precisa adivinhar que o chip do "ter sempre" leva até lá.
- **O que fazer:** um botão "⋯" ("Mais do item") no editor da linha, que abre a folha inteira.

**AB7. Com a casa vazia, o botão amarelo abre o modo de preço (médio, provável).**

- **Onde:** `home_shell.dart` (`Routes.camera`, que abre em Etiqueta) e `camera_page.dart`.
- **O que a pessoa vive:** o estado vazio diz "Bipe os produtos que você tem", mas o elemento mais forte da tela é o bipar amarelo. Por ele, a câmera pede mercado e etiqueta, e a casa continua vazia ao fechar.
- **O que fazer:** quando o produto bipado espera a etiqueta, o aviso do visor pode virar o botão "Guardar em casa", como já faz o aviso do granel.

**AB8. O guia do cartão "Acabando" diverge do código (baixo).** O `ProductCard.md` diz que o toque abre o produto; o código abre a folha do item, e o toque longo abre o produto. Como o design system vale sobre o código, o próximo a ler pode "corrigir" o lado errado. Atualizar o guia.

### C e E. Lista, compra e fim da compra

**CE1. Terminar fora do carrinho perde os preços lidos sem mercado (crítico).**

- **Onde:** `cart_mode_page.dart` (`_unsavedTagPrices` vive só no estado da tela; o `dispose` não grava nada; só o `_finish` do carrinho pergunta o mercado), `finish_shopping.dart` (o "Terminei" comum não pergunta) e `live_shopping_notification.dart` (`router.go` fecha o carrinho).
- **O que a pessoa vive:** primeira compra, sem mercado cadastrado ou com a localização negada. Lê 10 etiquetas, e a bandeja mostra preços e total. Então fecha o carrinho e toca "Terminei" na Lista, ou toca "Lista" ou "Terminei" na notificação. A folha "Fim da compra" mostra o total normalmente, mas nenhum desses preços chega ao histórico, sem aviso.
- **Por que importa:** perde dado em silêncio, e o preço é o centro do app. É o D1 da análise anterior voltando por outro caminho (Nielsen 1 e 5).
- **O que fazer:** guardar as leituras pendentes por compra fora da tela (provider `keepAlive` ou tabela), passar a pergunta "Em que mercado?" para o `finishShopping`, para valer nos três lugares, e, na notificação, atender "Terminei" no próprio carrinho quando ele estiver aberto.

**CE2. O que foi marcado fora da compra, ou numa compra cancelada, entra no estoque no próximo "Terminei" (alto).**

- **Onde:** `finish_shopping_trip.dart` (todo item marcado, de qualquer data, vai para casa), `trip_review.dart` e o `cancel` do repositório de compras, que apaga só a compra e o carrinho.
- **O que a pessoa vive:** bipa leite, café e arroz, que ficam marcados, e cancela a compra ("nada vai para o estoque"). Os três continuam riscados. Dias depois, toca "Terminei" numa nova compra, e os três entram em casa como comprados agora. A folha só diz "12 embalagens para casa", sem dizer quais.
- **O que fazer:** o cancelamento desmarca o que foi marcado desde o início da compra (o texto passa a dizer que os itens voltam a faltar), e o "Terminei" só considera o que foi marcado durante a compra. O resto pede decisão na folha ("Também vão para casa: Pão").

**CE3. "3× Leite" bipado uma vez sai inteiro da lista (alto).**

- **Onde:** `cart_mode_page.dart` (`checkProduct` a cada bipe), o `checkProduct` do repositório (marca o item todo, ignora a quantidade) e `trip_review.dart`.
- **O que a pessoa vive:** a lista tem "3× Leite". Ela bipa uma caixa, e a Lista já risca o item. A folha não diz que faltaram 2, e depois do "Terminei" o item some. Os 2 que faltam não ficam em lugar nenhum.
- **Por que importa:** em casa o ADR 0019 já trata isso ("faltam 2 na lista"); na loja, o comportamento é outro (Nielsen 4).
- **O que fazer:** marcar só quando o carrinho alcança a quantidade da lista, mostrar "1 de 3" antes disso, e deixar a diferença na lista ao terminar, citada em "Faltaram".

**CE4. Os totais deixam de fora o que não tem preço, sem dizer (médio).**

- **Onde:** `ShoppingTripSummary.of` (só o carrinho), `trip_review.dart` (o marcado à mão conta embalagens, mas não entra no total nem em "sem preço") e `ShoppingListSummary.of` (o sem preço é ignorado na prévia).
- **O que a pessoa vive:** marca 5 itens à mão durante a compra, e o número grande da folha não muda nem avisa. Antes da compra, a prévia diz "≈ R$ 40,00" para 12 itens, dos quais 8 nunca tiveram preço.
- **O que fazer:** somar o marcado à mão pelo preço esperado, com "≈", ou contá-lo como sem preço, e mostrar "sem preço de N" sob o total da prévia, como Mercados já faz.

**CE5. O chip mostra um mercado que o "Ir às compras" não usa (médio).**

- **Onde:** `listMarketIdProvider` (fora da compra, o escolhido ou o da última compra) e `start_shopping.dart` (usa só a escolha explícita).
- **O que a pessoa vive:** a Lista mostra "Atacarejo" com os preços de lá. Sem localização, a compra começa sem mercado, o chip vira "Escolha o mercado", e os preços ganham "≈".
- **O que fazer:** quando a localização não achar mercado, começar com o que o chip mostra, com toque para trocar.

**CE6. A quantidade só muda com o toque longo, e "2 leites" vira item escrito (médio).**

- **Onde:** `shopping_list_page.dart` (`_setQuantity` só no toque longo; `_submit` cria `addCustom` para texto que não é o nome exato).
- **O que a pessoa vive:** nada na linha sugere o toque longo, e o toque simples marca como comprado. Ao escrever "2 leites", nasce um item sem produto, sem preço e fora do estoque.
- **O que fazer:** entender "2 leite", "leite 2" e "2x leite" no campo, e abrir a quantidade ao tocar no "3×" da linha, como no [AnyList](https://help.anylist.com/articles/add-item-quantity/).

**CE7. Acabamentos (baixo).**

- Compra sem lista mostra "0 de 0 itens" na barra e na Lista, e o leitor de tela não ouve o total (`home_shell.dart`, `tripItems`). Sem lista, o título pode ser "8 no carrinho", sem o fio de progresso.
- "Cancelar compra" só existe no "⋮" da Lista, à esquerda, e o diálogo confirma com um botão amarelo da marca numa ação que descarta. Levar também ao carrinho e confirmar com um botão neutro.
- `tripReviewSavings` diz "a menos que no {market}", que erra o artigo em "no Padaria Real". Trocar por "a menos que em {market}".

### D. Câmera do bipar e modo carrinho

Três achados desta jornada já estão acima: os preços lidos sem mercado (CE1), o "3×" riscado por um bipe (CE3) e o "Comprei" só no Início vazio (AB2). Aqui entram os demais.

**D1. Trocar o mercado no meio da compra deixa os preços já lidos no mercado errado (alto).**

- **Onde:** `cart_mode_page.dart` (`_chooseMarket` só chama `setMarket`) e `start_shopping.dart`, que escolhe sozinho o mercado mais perto num raio de 150 m (`nearest_market_finder.dart`).
- **O que a pessoa vive:** duas lojas a menos de 150 m, e a compra começa na vizinha. As etiquetas lidas vão na hora para o histórico dela. Ao notar o chip, a pessoa troca o mercado, mas os preços já lidos ficam no errado e alimentam a comparação, sem aviso.
- **Por que importa:** dado errado e silencioso, justo na comparação (Nielsen 5 e 9). O caminho está confirmado no código; a frequência depende de lojas próximas.
- **O que fazer:** ao trocar com preços já gravados, perguntar uma vez "Levar os 12 preços lidos para o Assaí?" e corrigir cada observação com `supersedes` (ADR 0017). Depende de o item do carrinho guardar o id da observação, que também resolve o CE1.

**D2. O disparo e o teclado da câmera ainda abrem o formulário antigo, que grava no mercado do GPS (alto).**

- **Onde:** `camera_page.dart` (teclado e disparo → `Routes.capturePrice` e `capturePricePhoto`), `cart_mode_page.dart` (`_photographTag` → `capturePriceFromCart`) e `capture_price_page.dart`, que detecta o mercado pela localização e cria o produto pelo nome lido.
- **O que a pessoa vive:** no carrinho, a leitura ao vivo não pega a etiqueta, e ela toca o disparo amarelo, o maior botão da tela. A câmera ao vivo some, abre a tela Material "Bipar preço" com a câmera do sistema, e o mercado é o do GPS, não o da compra. Com código novo, o produto nasce como "ARROZ BRANCO TIO JOAO 5KG", sem marca nem tamanho. Fora da compra, o teclado abre o formulário vazio, sem o produto que acabou de ser bipado.
- **Por que importa:** consistência (Nielsen 4), dado no mercado errado (Nielsen 5) e o único acento da tela levando para fora do sistema visual. É o H1 e o G2 da análise anterior, agora dentro da compra.
- **O que fazer:** o disparo tira a foto do próprio `CameraController` e cai no caminho da leitura ao vivo. O teclado abre a folha "Conferir e salvar" com o produto que espera a etiqueta, ou digita o preço do item no carrinho. Enquanto isso não vem, passar o mercado da compra para o formulário na rota.

**D3. Granel pesado no caixa não entra no carrinho (médio).**

- **Onde:** `cart_mode_page.dart` (`_chooseGranel` registra o preço por kg e não toca no carrinho nem na lista).
- **O que a pessoa vive:** lê "TOMATE ITALIANO R$ 8,99 o kg", escolhe o produto, e o aviso diz "salvo: Tomate italiano". A bandeja não ganha linha, a lista não marca, e o "Fim da compra" diz que faltou tomate.
- **O que fazer:** pôr na bandeja uma linha "Tomate italiano" sem preço, com a mini etiqueta "R$ 8,99/kg" como estimativa, e marcar na lista. A etiqueta da balança, se vier, firma o valor (o `ScaleItems` já faz essa troca).

**D4. A mesma etiqueta lida de novo vai para o próximo produto (médio, provável).**

- **Onde:** `live_tag_router.dart` e `live_scan.dart`: um preço volta a valer depois de 1 s fora da moldura e espera o próximo bipe da mesma seção.
- **O que a pessoa vive:** bipa o arroz e lê R$ 27,90, abaixa o celular para guardar o pacote, e a etiqueta volta à moldura. Dez segundos depois, bipa o feijão, que entra com R$ 27,90 e vai para o histórico.
- **O que fazer:** no roteador, um preço igual ao já firmado num item desta compra, com o mesmo nome lido, é a mesma etiqueta e não cria espera. Cobrir com teste em `live_tag_router_test`.

**D5. Leitura pela metade não tem saída na câmera (médio).**

- **Onde:** `camera_page.dart`: os avisos de espera só são tocáveis no granel.
- **O que a pessoa vive:** bipa o leite, a etiqueta está amassada, e em 20 s o aviso "aponte para a etiqueta" some. O caso inverso, etiqueta lida e código inalcançável no alto da prateleira, também não tem caminho.
- **O que fazer:** os dois avisos de espera viram botão com a seta, como o do granel: o primeiro abre "Conferir e salvar" com o preço a digitar; o segundo abre a escolha de produto pelo nome lido. Vale também no carrinho.

**D6. Um produto da balança lembrado errado não tem correção (médio).**

- **Onde:** `scale_items.dart` (não há como esquecer ou trocar) e a bandeja, onde tocar no nome só muda a quantidade.
- **O que a pessoa vive:** na primeira pesagem escolhe "Banana nanica" no lugar de "Banana prata", e toda pesagem daquele item naquele mercado entra errada daqui em diante.
- **O que fazer:** na linha que veio da balança, "Trocar o produto" regrava a lembrança. A tela do mercado pode listar os itens da balança lembrados.

**D7. Acabamentos (baixo).**

- A alça da bandeja alterna com arrasto em qualquer direção (`scan_tray.dart`). Para cima expande, para baixo recolhe.
- O preço estimado tem dois sinais, contorno e "≈". Manter o contorno na mini etiqueta e o "≈" só no total.
- Em "Comprei" e "Usei", o aviso do visor e o snackbar repetem o mesmo fato, e um snackbar novo esconde o Desfazer do anterior. Quando a lista não muda, o Desfazer pode ir para o próprio aviso do visor.
- A folha "Conferir e salvar" não mostra o mercado em que o preço vai cair. Uma linha discreta sob o produto, tocável, resolve.

### F. Preços e mercados

**F1. Duas idades com o mesmo nome e sentidos opostos em Mercados (médio).**

- **Onde:** `markets_page.dart` (`marketsOldestPrice`, o preço mais antigo do total) e `market_meta.dart` (`marketsPriceAge`, o mais recente do mercado).
- **O que a pessoa vive:** a comparação diz "preços de até 40 dias", e logo abaixo o mesmo mercado aparece com "preços de ontem". A segunda faz tudo parecer fresco. Com 1 dia, a primeira vira "preços de até ontem", que soa como "valiam até ontem".
- **Por que importa:** a mesma forma com dois sentidos (Nielsen 4) e "um sinal por informação".
- **O que fazer:** na lista e na tela do mercado, falar da visita ("850 m · atualizado ontem"). Na comparação, mostrar a idade só quando algum preço passar de um limite, como "1 preço de 40 dias". Atualizar a prancha "Mercados", que aguarda revisão.

**F2. A barra curta do mercado incompleto contradiz o selo (médio).**

- **Onde:** `markets_page.dart` (`fraction` = total / maior total) e `list_cost_compare.dart`.
- **O que a pessoa vive:** A tem os 6 itens por R$ 120; B tem 5 por R$ 95, e A sai a R$ 92 nesses 5. O selo vai para A, corretamente, mas a barra de B mede 79% da de A, e o olho lê "B é mais barato".
- **O que fazer:** completar o total do incompleto com o preço de referência e desenhar a parte estimada em tracejado, com "≈". A saída mais simples é não desenhar a barra dos incompletos.

**F3. Um preço errado só se corrige dentro do carrinho (médio).**

- **Onde:** o `supersedes` só é preenchido em `cart_mode_page.dart`. Em "Nos mercados" (produto) e "Preços recentes" (mercado), o preço não tem ação.
- **O que a pessoa vive:** em casa, vê "R$ 2,19/kg · menor preço", uma leitura errada de semanas atrás, e não tem como corrigir. O ponto continua no gráfico e no "menor por kg".
- **O que fazer:** tocar numa linha de preço abre uma folha com preço, mercado, data e "Corrigir preço", que grava a correção como no carrinho (ADR 0017).

**F4. O preço em destaque do produto não diz onde nem quando (baixo).** A etiqueta amarela pode mostrar uma promoção de 5 meses atrás. Usar a mesma desconfiança de preço velho da comparação, e trocar a embalagem pelo mercado na linha da etiqueta quando o preço não for recente.

### G. Produto e embalagens

**G1. "Editar" muda a embalagem mais recente sem dizer qual (médio).**

- **Onde:** `product_form_page.dart` (`_load` pega a primeira de `watchPackages`, a mais nova) e mistura marca, tamanho e código dela com o nome do produto.
- **O que a pessoa vive:** o Arroz tem Camil 10 kg e Tio João 5 kg. Ela abre "Editar" para corrigir o nome e vê "Marca: Tio João, Tamanho: 5". Mudar o tamanho achando que é do produto recalcula o preço por kg de todo o histórico da Tio João.
- **O que fazer:** "Editar" passa a editar só nome e unidade. Cada linha de "Embalagens" ganha um menu para editar a própria embalagem.

**G2. Embalagem posta no produto errado não tem conserto (médio).** O repositório não move nem apaga embalagens. Quem põe o código do Leite Ninho no Leite integral só pode apagar o produto inteiro ou juntar produtos diferentes. O mesmo menu da linha pode oferecer "Mover para outro produto…" e "Apagar embalagem", com um ADR curto, porque mexe em observações gravadas.

**G3. "Registrar preço" escolhe a embalagem sozinho (médio).**

- **Onde:** o menu do produto abre o formulário sem embalagem, que cai na mais recente, e `_applyReading` ignora o código lido quando o produto está fixo (`capture_price_page.dart`).
- **O que a pessoa vive:** fotografa a etiqueta do Tio João, mas o preço vai para a Camil, sem aviso. Tocar na linha de uma embalagem abre o formulário antigo sem nenhuma pista de que faria isso.
- **O que fazer:** se o código lido for de outra embalagem do mesmo produto, trocar e dizer. Perguntar a embalagem quando houver mais de uma, e dar à linha a pista do toque e um `onTapHint`.

### H. Consistência e acessibilidade

**H1. Abas vizinhas com dois visuais e dois leitores de código (médio).** A aba Produtos usa `AppBar`, `SearchBar` do Material e o mesmo ícone de cesta para tudo, ao lado de Mercados, já no design system. O bipar de Produtos e da busca do Início usa o `BarcodeScannerPage` antigo, embora a câmera nova já tenha o modo "Código". Redesenhar Produtos com os componentes de Mercados (no protótipo antes) e aposentar o leitor antigo.

**H2. Erros sem saída e textos fora do ARB (baixo).** Nenhuma tela passa `onRetry` ao `AsyncValueView`, então "Tentar de novo" nunca aparece. Os textos de falha alternam "Não foi possível" e "Não deu para", e as mensagens das exceções do domínio estão no código. O stepper do produto não trata falha.

**H3. Alturas fixas com texto dentro (baixo, provável).** O `QuantityStepper` (altura 52, número e unidade empilhados), a contagem do `SectionHeader` e o número da seção na tela do mercado devem cortar com a fonte do Android em 150% ou mais (WCAG 1.4.4). Trocar `height` por altura mínima e testar com `TextScaler.linear(2)`.

**H4. O leitor de tela lê sinais ao pé da letra (baixo).** "Ter sempre —" vira "travessão", "/kg" vira "barra kg", o stepper lê "2" e "EMB." soltos, e o nome do produto não é cabeçalho. Dar `semanticsLabel` próprio ("não definido", "o quilo", "2 embalagens em casa").

**H5. Linhas que parecem levar a algum lugar e não levam (baixo).** "Nos mercados" no produto, as linhas da comparação e os alfinetes do mapa não respondem ao toque, enquanto na tela do mercado o preço abre o produto.

**H6. "Apagar" confirmado no botão amarelo da marca (baixo).** Os diálogos de apagar mercado e produto usam `FilledButton`, que no tema é o amarelo de "Salvar", e o mercado diz só "Apagar". Definir no `Button.md` uma variante destrutiva neutra e usar verbo com objeto ("Apagar mercado").

**H7. Idade negativa corrigida num lugar só (baixo).** A correção do lote 7 ficou em `markets_page.dart`. `market_meta.dart`, `market_page.dart` e `product_detail_page.dart` ainda podem mostrar "há -1 dias". Uma função única com o `max(0, …)` resolve os quatro.

## Ganhos rápidos, em ordem

Mudanças pequenas, quase todas sem tela nova, que atacam os achados mais graves primeiro. As dez foram feitas em 28/10, sem compilar; os commits estão entre parênteses.

- [x] **"Guardar em casa" no menu do bipar** (AB2). Item no menu e prancha `MenuBipar` atualizada (`321ef7f`).
- [x] **Rótulos de correção no stepper** (AB1, primeira parte). "Uma embalagem a menos" e "a mais", com os guias do design system atualizados (`ca9d052`, `f1344b4`).
- [x] **Cancelar desmarca, e "Terminei" só leva o marcado durante a compra** (CE2). `isCheckedSince`, `CancelShoppingTrip` e testes (`c4469e8`).
- [x] **Mercado da compra no formulário do disparo** (D2, paliativo). O disparo do carrinho e o disparo e o teclado da câmera levam o mercado na rota (`85473db`).
- [x] **Aviso com Desfazer no deslizar para a direita** (AB4). Também no botão da linha aberta; o "+" do cartão segue sem aviso (`859e562`).
- [x] **Idades: uma função e duas palavras** (H7, F1). `calendarDaysSince` nas quatro telas; "atualizado há N dias" na lista; na comparação, só a partir de 30 dias (`b06793b`, `7618046`).
- [x] **Sem barra para o mercado incompleto** (F2). A barra só aparece para quem tem preço de tudo (`7618046`).
- [x] **"Tentar de novo" nas telas que carregam** (H2, em parte). As sete telas com `AsyncValueView` (`a8d3ca4`). Os textos de falha e as exceções do domínio continuam como estavam.
- [x] **Acabamentos de texto e botão** (H6, CE7, AB8). `confirmDestructive` nos quatro diálogos, "Apagar mercado" e "Editar produto", "a menos que em", "8 no carrinho" e o guia do cartão (`7cd26f6`, `9afbfd0`, `9edf216`). "Cancelar compra" continua só no menu da Lista.
- [x] **Bandeja** (D7, em parte). Alça com direção e um só sinal de estimado (`3ffbf4f`). O aviso repetido de "Comprei" e "Usei" e o mercado na folha "Conferir e salvar" ficaram para depois.

## Oportunidades para o roadmap

Trabalhos maiores, que pedem protótipo ou ADR antes do código.

- **Preços da compra fora da tela** (CE1, D1). Cada item do carrinho guarda o id da observação e a marca "lido, sem mercado". O repositório grava as pendências quando a compra ganha mercado, o "Terminei" pergunta o mercado em qualquer lugar, e trocar de mercado oferece levar os preços já lidos. Feito em 28/10 com o ADR 0020, com a tabela dos preços da compra no esquema v13.
- **Quantidade na compra** (CE3, CE6). "1 de 3" na lista e na bandeja, o que faltou fica na lista, e o campo entende "2 leite".
- **Uma câmera só, de verdade** (D2, H1, G3). O disparo e o teclado usam a câmera ao vivo e a folha "Conferir e salvar", e saem o `CapturePricePage` e o `BarcodeScannerPage`. A aba Produtos ganha o visual de Mercados.
- **Corrigir fora do carrinho** (F3, G1, G2). Uma folha do preço com "Corrigir", e um menu por embalagem com editar, mover para outro produto e apagar.
- **Primeira carga que configura** (AB5). A folha "Arrumar o que entrou", com local e "ter sempre", ou o local sugerido pela categoria.
- **Correção que fecha o ciclo** (AB1, AB3). Um aviso ao fechar o editor quando o item cruzou o "ter sempre", e a linha deslizada que fica no lugar enquanto o aviso está na tela. Atualiza o ADR 0019.
- **Granel e leituras pela metade** (D3, D4, D5, D6). O granel entra na bandeja, os avisos de espera viram botão, a etiqueta relida é reconhecida, e o produto da balança pode ser trocado.
- **Rodada de acessibilidade** (H3, H4). Alturas mínimas no lugar de fixas, rótulos semânticos para "—", "/kg" e "emb.", títulos marcados e um teste com fonte em 200%.

## O que funciona bem (manter)

- **Uma câmera ao vivo robusta.** Pausa sob folhas, para sob outras telas, silêncio de 1 s ao voltar e "Tentar de novo" quando falha.
- **Código novo abre "Embalagem nova" na hora**, sugerida pela etiqueta, e "Salvar" sem produto diz o que falta.
- **Balança tratada como balança.** O código que começa com 2 não suja o catálogo e é perguntado uma vez por mercado.
- **"Fim da compra" honesto e seguro.** Economia só numa comparação justa, o que faltou dito pelo nome, proteção contra o toque duplo e um desfazer que volta estoque, lista, ordem das seções e a compra.
- **Casa e lista no mesmo gesto, com um só desfazer** (ADR 0019), numa transação, sem tirar da lista o que já estava nela.
- **Comparação justa no domínio.** Cesta em comum, preço por kg entre embalagens, quantidade da lista e nenhum selo num empate, tudo com teste.
- **Permissões no momento certo.** Um motivo em linguagem simples antes dos pedidos da compra, e "Agora não" respeitado.
- **Tema que protege o amarelo.** Nenhuma cor fora da paleta, alvos de 48 dp nas telas novas e ações do TalkBack para todo gesto.

## Fontes

Base interna: `CLAUDE.md`, `docs/roadmap.md`, `CHANGELOG.md`, os ADRs 0007 e 0011 a 0019, `docs/design/identidade-visual.md`, os guias em `docs/design/design-system/componentes/` (StockStepper, ProductCard, ScanNavBar, ScanTray, BipFeedback, Button), o protótipo em `docs/design/prototipo/telas/` e o código em `lib/` no commit `819b679`. Nada foi compilado; cada achado foi conferido no código, e os marcados "provável" dependem de rodar o app.

Referências externas:

- [The Decision Lab: Nielsen's Heuristics](https://thedecisionlab.com/reference-guide/design/nielsens-heuristics)
- [principles.design: 10 Usability Heuristics](https://principles.design/examples/10-usability-heuristics-for-user-interface-design)
- [Android Developers: pedir permissões em tempo de execução](https://developer.android.com/training/permissions/requesting)
- [AnyList: quantidade do item](https://help.anylist.com/articles/add-item-quantity/)
- [W3C: Understanding SC 1.4.4 Resize Text](https://www.w3.org/WAI/WCAG21/Understanding/resize-text.html)
- [Google: gestos do TalkBack](https://support.google.com/accessibility/android/answer/6151827)
- [Primer: Confirmation dialog](https://primer.style/product/components/confirmation-dialog/guidelines)
- [S-Group: comparação da cesta](https://s-etukortti.fi/en/support/grocery-basket-comparison)
