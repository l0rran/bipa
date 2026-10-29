# Análise de UX do Bipa (lote 13)

> Análise feita no commit `5ace292`, sobre o que entrou depois de `b0ba36a`: BK2 (a reserva do Desfazer presa ao aviso), BK4 (a casa vazia por todas as tabelas), BK1 (o backup de outro celular pendente sem prazo, o diário pausado, a linha "Último backup" que restaura em Ajustes, o diálogo antes de gravar por cima, os cartões do Início com a casa vazia e em uso, e "Deixar de lado"), BK3 (os três números dos dois lados, a data com o ano e a linha do que sai), o G12 calibrado (o produto da pessoa começa o nome sugerido, versão e linha não bloqueiam, palavras de tipo bloqueiam, a categoria do catálogo recusa) e o G13 (a marca no nome quando sobra só o sabor, a grafia das marcas). Os caminhos e o "o que a pessoa vive" descrevem o app desse commit. As análises anteriores estão em [lote 7](analise-ux-2026-10-28.md), [lote 8](analise-ux-2026-10-28-lote8.md), [lote 9](analise-ux-2026-10-28-lote9.md), [lote 10](analise-ux-2026-10-28-lote10.md), [lote 11](analise-ux-2026-10-29-lote11.md) e [lote 12](analise-ux-2026-10-29-lote12.md).

Oct 29, 2026 · @Wesley

## Resumo

O lote resolve o que o lote 12 pediu antes do teste: o backup do outro celular fica restaurável em Ajustes e no Início, o diário para e diz que parou, "Fazer backup agora" pergunta antes de apagar, o Desfazer da restauração dura o aviso, a confirmação mostra os mesmos números dos dois lados com o ano, e o catálogo deixa de pôr o leite condensado no "Leite". O que preocupa são os caminhos laterais que ainda levam ao mesmo fim que o BK1 queria evitar, e duas brechas na regra do catálogo:

1. **O Desfazer de uma restauração, ou restaurar outro arquivo, apaga o backup do outro celular sem pergunta (BK5, crítico).** `RestoreBackup.apply` adota o `ultimo.bipa` pendente qualquer que seja o arquivo restaurado, e o Desfazer devolve os dados, mas não a pendência. O cartão não volta, Ajustes deixa de oferecer o arquivo, e o diário grava por cima na volta seguinte ao app.
2. **"Deixar de lado" apaga o backup do outro celular na volta seguinte ao app, não no dia seguinte (BK6, alto).** O quadro promete "grava por cima no dia seguinte". No app, se o backup do outro celular não é de hoje, o diário grava assim que a pessoa troca de app e volta. É a mesma perda do "Apagar e fazer backup", que tem diálogo e "não volta mais", atrás de um rótulo que em português quer dizer "guardar para depois".
3. **O "Leite" com leite em pó mistura kg e litro, e o destaque e o "Mais barato" passam a comparar os dois (G16, alto).** A calibragem põe o leite em pó no "Leite" de propósito, mas a ordem dos preços põe sempre os preços por kg antes dos por litro: o leite em pó vira o "melhor preço" e o mercado dele ganha o "Mais barato".
4. **Um produto com nome de marca recebe tudo o que leva a marca (G17, médio).** O "Ninho" recebe a fórmula infantil, o iogurte de morango e o brownie; o "Nescau" recebe a bebida láctea de 200 ml.

Também entram: "Deixar de lado" que, num caso de corrida, faz o backup deste celular parecer de outro (BK7), a linha de Ajustes que o TalkBack anuncia como botão sem ação de toque (BK8) e o "De outro celular" depois de reinstalar no mesmo aparelho (BK9). BK5 pede correção antes do primeiro build para outras pessoas. BK6 pede uma decisão do mantenedor. As duas coisas aparecem no teste do aparelho se ele for feito como descrito em "Para o teste no aparelho".

## Situação dos achados anteriores

Das seis análises anteriores saíram 75 achados. Este lote resolveu BK1, BK2, BK3 e BK4, e resolveu em parte G12 e G13. Hoje são 66 resolvidos, 4 parciais (H1, H3, G12 e G13) e 5 abertos (AB14, H19, G14, G15 e H20). Nenhum regrediu. Abaixo, só os itens que este lote tocou ou que não estão fechados; os demais seguem como na análise do lote 12. "Conferido" quer dizer lido no código deste commit.

| ID | Achado anterior | Situação | O que mudou |
| --- | --- | --- | --- |
| BK1 | O backup do celular antigo só se restaura pelo cartão, que some com o primeiro uso | Resolvido (conferido), com BK5 a BK7 novos | `RestoreOffer` não depende mais da casa vazia; `CreateBackup.call` (`create_backup.dart:64-75`) pausa o diário enquanto o arquivo é de outro aparelho; `_PendingBackupRow` restaura pela linha; `confirmReplacePending` pergunta antes de gravar por cima; "Salvar uma cópia…" grava só a cópia; o `PendingBackupCard` fica no Início até a resposta. Os três pedidos do lote 12 estão no app. O que sobra são outros caminhos para a mesma perda (BK5, BK6). |
| BK2 | O Desfazer da restauração vence em 10 s mesmo quando o aviso espera | Resolvido (conferido) | O `Timer` saiu; `applyRestoreAndNotify` (`restore_sheet.dart:116-166`) descarta a reserva quando o aviso sai sem a ação, com o número da restauração (`restoreEpoch`) para um aviso velho não apagar a reserva nova. `restore_undo_notice_test.dart` cobre TalkBack, "Tempo para agir" e o dedo em cima. |
| BK3 | A confirmação compara números que não mostram o que se perde | Resolvido (conferido) | Os mesmos três números dos dois lados (`_CurrentLine`), a data com o ano (`BackupLabels.fullDate`) e a linha "Os preços e as compras depois de … saem deste celular" quando `latestActivity` é mais nova que o backup. |
| BK4 | "Restaurar" no cartão apaga sem folha o que não entra nos três números | Resolvido (conferido) | `PreparedRestore.currentIsEmpty` vem de `BackupDatabase.isEmpty()`; com lista ou mercado, o cartão passa pela folha com Desfazer (`restore_offer_card.dart:62`). |
| G12 | O catálogo põe a embalagem num produto mais genérico | Parcial | `_catalogProductIn` (`package_suggestion.dart:156-188`) só escolhe o produto que começa o nome sugerido, sem palavra de tipo a mais e com a categoria compatível; há um banco de 49 casos reais (`catalog_product_cases_test.dart`). Falta a linha "No catálogo: …" na folha (roadmap). Ficam dois buracos novos: a unidade (G16) e o produto com nome de marca (G17). |
| G13 | O nome novo que o catálogo sugere sai pela metade | Parcial | No app, a marca fica quando sobra só sabor ou linha ("Fanta uva", "Heineken"), e `_brandSpellings` acentua 65 marcas ("Nestlé", "Tio João"). O gerador (`tool/catalogo/catalogo.py`) não mudou: os 162 nomes em espanhol com código 789 continuam ("Leche condensada" vira o produto novo "Leche condensada"), e a marca em caixa alta fora da lista segue sem acento ("CAFE BRASILEIRO" vira "Cafe Brasileiro"). |
| G14 | "1 u, 120 g" vira 1 unidade | Aberto | Não tocado (gerador). |
| G15 | A linha "Dados do Open Food Facts" não leva a lugar nenhum | Aberto | Não tocado; pede quadro. |
| H20 | A atribuição de "Sobre" sem os links da ODbL | Aberto | Não tocado. |
| H1 | Abas com dois visuais | Parcial | A escolha de produto abre agora com o produto parecido quando a folha sugere um novo (`new_package_sheet.dart:118-135`), mas o visual da folha de escolha não mudou. |
| H3 | Alturas fixas com texto dentro | Parcial | Sem mudança; as telas novas entraram no teste a 200%. |
| AB14 | Escolher o local no aviso tira o "ter sempre" | Aberto | Não tocado. |
| H19 | Anel recomeça a cada volta de tela cheia | Aberto | Não tocado. |

## Problemas por jornada

Caminhos relativos ao repositório. Tudo foi avaliado lendo o código, sem compilar. Os exemplos do catálogo são linhas reais de `assets/catalog/catalogo.sqlite`, consultadas com `py -3` só para leitura e seguidas à mão por `PackageSuggestion.fromCatalog`. Gravidade: crítico perde dado ou bloqueia a tarefa; alto é dado errado ou caminho principal confuso; médio é atrito; baixo é acabamento. "Provável" quando o efeito depende de rodar o app.

### I. Backup e restauração

**BK5. O Desfazer de uma restauração, ou restaurar outro arquivo, apaga o backup do outro celular sem pergunta (crítico).**

- **Onde:** `RestoreBackup.apply` em `lib/features/backup/domain/restore_backup.dart:148-158` adota o `ultimo.bipa` (`adoptLatest`) depois de qualquer restauração, seja qual for o arquivo restaurado. `BackupController.undoRestore` em `lib/features/backup/presentation/backup_providers.dart:199-203` devolve o banco e as fotos, mas não a marca `ultimo.id`. Depois disso, `_refresh` lê o arquivo como "feito aqui", e o diário (`CreateBackup.call`, `create_backup.dart:67-70`), que roda a cada volta ao app (`lib/app/daily_backup.dart:28`), grava por cima se o backup não é de hoje.
- **O que a pessoa vive:**
  - **Pelo Desfazer:** no celular novo, com a casa já em uso, ela toca em "Restaurar" no cartão menor, confirma e vê que o estoque de hoje sumiu (o backup é de 12/10). Toca em "Desfazer", e a casa de hoje volta. O cartão não volta, e Ajustes passa a mostrar "Último backup: 12/10 · Automático, uma vez por dia" como se fosse dela. Ela responde uma mensagem no WhatsApp, volta ao Bipa, e o diário grava a casa de hoje no lugar do backup do celular antigo. O único histórico do aparelho antigo some por causa de um Desfazer.
  - **Por outro arquivo:** com o backup do outro celular pendente, ela restaura em "Restaurar de um arquivo…" uma cópia do Drive. A folha fala só da cópia e não diz nada do backup pendente. Na volta seguinte ao app, ele é substituído.
- **Por que importa:** o lote fechou "Fazer backup agora" com um diálogo que diz "não volta mais", mas o mesmo arquivo se perde por um Desfazer, que a pessoa usa justamente para não perder nada. O ADR 0023 registra "restaurar qualquer arquivo adota o `ultimo.bipa`" como decisão, mas essa decisão contradiz a regra que o próprio lote criou: o arquivo do outro celular espera uma resposta sobre ele.
- **O que fazer:**
  1. Em `apply`, adotar só quando o arquivo restaurado é o próprio `ultimo.bipa` pendente (`prepared.manifest.id == latest manifest id`). Restaurar outro arquivo deixa a pendência como está, e o cartão continua no Início.
  2. Guardar na reserva a marca de antes (o `madeHereId`, ou a falta dele) e devolvê-la em `undoReplace`. O Desfazer volta tudo, inclusive a pergunta.
  3. Testes em `backup_controller_test.dart`: com o arquivo pendente, restaurar e desfazer deixa `pending` verdadeiro e o diário sem gravar; restaurar outro arquivo também.

**BK6. "Deixar de lado" apaga o backup do outro celular na volta seguinte ao app, com menos aviso que "Fazer backup agora" (alto).**

- **Onde:** `_setAside` em `lib/features/backup/presentation/restore_offer_card.dart:223-241` adota o arquivo quando o aviso sai (`dismissRestoreOffer`, `backup_providers.dart:241-246`). Depois disso, `CreateBackup.call` (`create_backup.dart:70`) só espera se o backup é de hoje (`_sameDay(latest.createdAt, …)`). O aviso diz "Backup de 12/10/2026 deixado de lado. O próximo grava por cima." (`backupOfferSetAsideNotice` em `lib/core/l10n/app_pt.arb`). O quadro, em `docs/design/prototipo/fonte/InicioBackupPendente.dc.html:77`, diz "o automático volta e grava por cima no dia seguinte".
- **O que a pessoa vive:** troca de celular no dia 29. O Android trouxe o backup do celular antigo, de 27/10. Ela já bipou umas coisas, vê o cartão e toca em "Deixar de lado", lendo como "deixar para depois". O aviso fica 10 s. Ela vai ao app do banco e volta. O diário grava, e o backup de 27/10 deixa de existir, sem diálogo. Se ela abrir Ajustes entre o aviso e a volta, vê "Último backup: 27/10 · Automático, uma vez por dia", como se o backup fosse dela.
- **Por que importa:** "Apagar e fazer backup" e "Deixar de lado" levam à mesma perda. Um tem diálogo com a data, os números e "não volta mais"; o outro tem um rótulo brando e 10 s de aviso. A regra do CLAUDE.md pede texto nas ações que apagam, e aqui o texto não diz que apaga. A promessa do quadro ("no dia seguinte") daria à pessoa o resto do dia para voltar atrás, mas o app só cumpre quando o backup do outro celular é do mesmo dia. No teste do mantenedor ele costuma ser do mesmo dia, o que esconde o problema (veja "Para o teste no aparelho").
- **O que fazer:** cumprir o quadro, com decisão do mantenedor sobre o texto.
  1. Guardar o dia em que o arquivo foi deixado de lado (na marca, ao lado do id). O diário não grava nesse dia, e Ajustes mantém a linha restaurável com a frase "Deixado de lado. O automático grava por cima amanhã."
  2. O aviso diz quando: "Backup de 27/10/2026 deixado de lado. O automático grava por cima amanhã." Com o leitor de tela, a data vai por extenso, como no título.
  3. Teste com o backup do outro celular de dois dias antes: depois de "Deixar de lado", o diário do mesmo dia não grava e o do dia seguinte grava.

**BK7. "Deixar de lado" adota o arquivo pelo id antigo e pode fazer o backup deste celular parecer de outro (médio).**

- **Onde:** `dismissRestoreOffer(offer)` em `backup_providers.dart:241-246` grava em `ultimo.id` o id de `offer`, guardado quando o cartão saiu, sem conferir se o `ultimo.bipa` ainda é ele. O aviso fica até o toque com TalkBack (H13), e Ajustes continua oferecendo o arquivo enquanto isso.
- **O que a pessoa vive:** com TalkBack, ela toca em "Deixar de lado". O aviso fica na tela, e ela vai a Ajustes, toca em "Fazer backup agora" e confirma "Apagar e fazer backup". O backup novo entra. Quando o aviso sai, a marca recebe o id do backup antigo. O backup que ela acabou de fazer passa a ser "de outro celular": o cartão volta no Início oferecendo restaurar o próprio backup, e Ajustes diz "Automático pausado até você decidir". Sem TalkBack, o mesmo acontece se tudo couber nos 10 s do aviso.
- **O que fazer:** adotar só se o `ultimo.bipa` ainda tem o id da oferta (comparar antes de gravar a marca, dentro do `_serial`). Teste: esconder a oferta, fazer o backup com `replacePending` e depois `dismissRestoreOffer` deixa `pending` falso.

**BK8. A linha "Último backup" de outro celular é anunciada como botão, mas não tem ação de toque para o TalkBack (médio, provável).**

- **Onde:** `_PendingBackupRow` em `lib/features/backup/presentation/backup_settings_group.dart:258-264`: `Semantics(button: true, excludeSemantics: true, label: …)` sem `onTap`. O `excludeSemantics` tira da árvore a ação do `InkWell` de dentro. Os componentes do design system com o mesmo padrão passam o toque à `Semantics` (`product_card.dart:146-151`, `place_filter.dart:57-62`).
- **O que a pessoa vive:** com TalkBack, ela ouve "Último backup: de outro celular, 12 de outubro de 2026. Restaurar, botão", toca duas vezes, e o nó não tem a ação de clique. Dependendo da versão do TalkBack e do Android, nada acontece. O caminho pelo Início continua, mas a linha de Ajustes foi feita para ser o caminho que não some.
- **O que fazer:** `onTap: onTap` na `Semantics`, como nos componentes, e um teste com `tester.getSemantics(...)` e `hasTapAction` em `backup_settings_test.dart`.

**BK9. Depois de reinstalar no mesmo celular, o próprio backup aparece como "De outro celular" (baixo).**

- **Onde:** `LocalBackupStorage` (`lib/features/backup/data/local_backup_storage.dart:39-40`, `99-105`): a marca `ultimo.id` não vai para o Auto Backup, então qualquer `ultimo.bipa` restaurado na instalação é "de outro aparelho". Os textos `backupFromOtherPhone` e `backupLastFromOtherPhone` (ARB).
- **O que a pessoa vive:** desinstala o Bipa para liberar espaço e instala de novo. O Android traz o backup na instalação ([Android Developers](https://developer.android.com/identity/data/autobackup)), o cartão aparece (certo) e a folha e Ajustes dizem "De outro celular", que é o mesmo celular.
- **O que fazer:** um texto que serve aos dois casos, sem afirmar a origem, por exemplo "Trazido pelo backup do Google" no lugar de "De outro celular". Cabe na revisão de texto, sem quadro novo.

### G. Produto e embalagens

**G16. O "Leite" com leite em pó mistura kg e litro, e o destaque e o "Mais barato" passam a comparar os dois (alto).**

- **Onde:** `_catalogProductIn` em `lib/features/products/domain/package_suggestion.dart:156-188` não olha a unidade. O caso calibrado `7891000101506 "Leite em pó desnatado" → Leite` está em `test/features/products/domain/catalog_product_cases_test.dart:65`. Na tela do produto, `_byUnitPrice` (`lib/features/prices/domain/package_prices.dart:67-77`) agrupa pela ordem do enum (`MeasureUnit`: kg antes de L), e `best = perPackage.firstOrNull` (`product_detail_page.dart:419`) e o selo "Mais barato" (`product_detail_page.dart:561`) pegam o primeiro. O gráfico (`price_trend.dart`) já resolve isso usando a unidade da maioria dos preços, mas o destaque e os mercados não.
- **O que a pessoa vive:** tem "Leite" com o UHT de 1 L a R$ 5,49 no Mercado A. Bipa o Molico 400 g no Mercado B, e a folha diz "Embalagem nova de Leite". Ela salva e registra R$ 21,90. Na tela do Leite, o destaque passa a ser "R$ 54,75/kg", o leite em pó ganha o "menor por kg", e na lista de mercados o B fica em primeiro com "Mais barato", acima dos R$ 5,49/L do A. São 126 linhas de leite em pó no catálogo, 70 com o tamanho em gramas. O mesmo vale para o "Nescau" com a bebida láctea de 200 ml (G17).
- **Por que importa:** a calibragem decidiu que "em pó" não muda o produto. Para o nome, a decisão se sustenta. Para o preço, não: o app compara preço por kg ou por litro (ADR 0013), e kg contra litro não tem resposta. É o achado que mais engana no uso diário, porque o destaque é o número que a pessoa olha no mercado.
- **O que fazer:**
  1. Na escolha (`_catalogProductIn`), exigir que a unidade base da embalagem do catálogo combine com a das embalagens que o produto já tem (ou com a do produto, quando não é "un"). Se não combinar, a folha sugere "Leite em pó" como produto novo, com "Leite" a um toque na troca. O caso do banco passa a esperar `null` quando a casa tem o "Leite" em litro. Isso é decisão do mantenedor, porque muda a calibragem.
  2. Na tela do produto, ordenar primeiro a unidade da maioria dos preços, como faz o `priceTrend`, para o destaque e o "Mais barato" nunca compararem kg com L. Isso vale também para produtos que já misturam unidades por outros caminhos (mover embalagem, etiqueta).
  3. Testes em `package_prices_test.dart` (destaque com kg e L) e no banco de casos.

**G17. Um produto com nome de marca recebe tudo o que leva a marca (médio, provável).**

- **Onde:** `package_suggestion.dart:174-178`: quando alguma palavra do produto é marca (a do catálogo ou uma de `_knownBrands` no nome), os passos 2 e 3 são pulados inteiros, inclusive as palavras de tipo. `_kindsAgree` (`:202-207`) aceita qualquer categoria quando o nome do produto não diz o tipo (`ProductKind.other`), que é o caso de "Ninho" e "Danone".
- **O que a pessoa vive:** chama o leite em pó da casa de "Ninho", como muita gente faz. Bipa um iogurte para a criança, e a folha diz "Embalagem nova de Ninho": é o `7891000094396` "Iogurte Parcialmente Desnatado Morango Ninho Fruti 250g". O mesmo vale para o `7891000001080` "Fórmula Infantil Ninho Fases 1+", com outro preço e outro uso, e para o `0609963517664` "Brownie Recheado - Leite Ninho". Com "Nescau" (o achocolatado em pó), o `7891000023167` "Bebida Láctea Uht Chocolate Light Nescau Caixa 200ml" entra como embalagem, em ml (G16). Com "Danone", qualquer um dos 87 produtos Danone.
- **Por que importa:** é o G6 de novo, agora pela marca. O banco de casos só tem "Heineken" e "Coca-cola" como produtos de marca, e os dois são o caso fácil, porque a marca é o produto.
- **O que fazer:** para o produto com nome de marca, pular só o passo 2 (a primeira palavra), e não o 3: sabor e palavras de tipo continuam bloqueando ("morango", "bebida", "fórmula", "iogurte" e "brownie" quando o produto não é nenhum deles). Também vale a regra da unidade do G16. Pôr no banco de casos uma casa com "Ninho", "Nescau", "Danone" e "Toddy", com essas linhas, e calibrar com o mantenedor.

### Conferido sem achado

- **A reserva do Desfazer presa ao aviso (BK2).** Outra restauração no meio não apaga a reserva nova (`restoreEpoch`), e o app fechado com o aviso na tela limpa a reserva na abertura seguinte.
- **Casa vazia por todas as tabelas (BK4).** Uma lista escrita à mão ou um mercado criado levam o cartão grande à folha, com Desfazer.
- **"Fazer backup agora" e "Salvar uma cópia…" com o arquivo pendente.** O primeiro pergunta, e com o banco vazio não grava nem com a confirmação ("Nada para guardar ainda"). O segundo grava só a cópia, sem tocar no `ultimo.bipa` (`create_backup.dart:81-94`).
- **App fechado durante o aviso de "Deixar de lado" ou "Começar do zero".** O arquivo não foi adotado, e a oferta volta na abertura seguinte. Nada se perde.
- **Dois aparelhos trocando backup.** O backup do Google é guardado por aparelho, e o celular velho e o novo não gravam um por cima do outro. Uma cópia do celular A restaurada no B adota o `ultimo.bipa` do B, que é do próprio B, e ele fica com os dados de antes até o diário do dia seguinte, o que serve de rede. O caso que perde é o B com o arquivo do A ainda pendente (BK5).
- **Arroz integral no "Arroz" e cerveja zero na "Cerveja".** A unidade é a mesma, então o "menor por kg" e o "Mais barato" continuam mostrando a variedade mais barata. O gráfico pode ter um dia mais alto quando só a outra foi vista, o que a calibragem aceitou. O café em cápsula ("Café Au Lait Em Cápsula…") entra no "Café" pela mesma regra, em g, e o efeito é o mesmo.
- **Leite condensado, Fanta Uva, arroz carreteiro e feijão pronto.** Não caem mais no genérico (o banco de casos confere), e a escolha abre com o produto parecido quando a folha sugere um novo.
- **Letra grande.** O grupo pendente, o diálogo empilhado e o cartão menor estão no teste a 200%; os botões do cartão empilham a 150%.
- **Cores e textos.** Nenhum `Color(0x…)` nem texto fora do ARB nas telas novas. Ajustes e os cartões continuam neutros.

## Divergências com o design system e o protótipo

O design system vale sobre o código. As cópias do repositório estão à frente das publicadas (`estado.md`); o que segue é o que sobra além disso.

- **Quadro InicioBackupPendente, nota do momento 2** (`fonte/InicioBackupPendente.dc.html:77`): "grava por cima no dia seguinte". O app grava na volta seguinte ao app quando o backup não é de hoje (BK6). Ou o app cumpre, ou a nota muda. A recomendação é cumprir.
- **ADR 0023, "A resposta":** "restaurar (qualquer arquivo adota o `ultimo.bipa`)". É a regra que leva ao BK5; revisar junto com a correção.
- **README do protótipo, linha InicioBackupEncontrado:** o aviso ainda é "Backup de 12/10 restaurado", sem o ano que o app mostra para o backup de outro celular (`restore_sheet.dart:133-135`). É só acerto de texto.
- **`estado.md`, lista do teste no aparelho:** "depois de limpar os dados do app, o cartão 'Backup encontrado'". Limpar os dados apaga `files/backup/ultimo.bipa` junto com o resto, e o Auto Backup só restaura na instalação, então o cartão não aparece. Os caminhos que funcionam estão abaixo.
- **Banco de casos do catálogo:** a calibragem "em pó não muda o produto" (`catalog_product_cases_test.dart:65`) foi feita sem olhar a unidade (G16). Vale registrar a decisão de novo, com a regra da unidade.

## Para o teste no aparelho

O que observar por causa dos achados acima. O build de debug permite `run-as`.

1. **Simular o backup de outro celular sem um segundo aparelho.** Com o app fechado e **antes da primeira abertura do dia** (para o `ultimo.bipa` ser de ontem), rode `adb shell run-as dev.l0rran.bipa rm files/backup/ultimo.id` e abra o app. O cartão menor aparece se há itens em casa. Se a marca for apagada depois de o app ter aberto hoje, o backup é de hoje, o diário espera até amanhã e o BK6 não aparece. Desinstalar e instalar de novo depois de `adb shell bmgr backupnow dev.l0rran.bipa` também traz o arquivo, com o "De outro celular" do BK9.
2. **BK6:** toque em "Deixar de lado", espere o aviso sair, vá a outro app e volte. Em Ajustes, "Último backup" passa a "hoje": o arquivo foi substituído no mesmo dia.
3. **BK5:** de novo com o arquivo pendente, toque em "Restaurar" no cartão menor, confirme e toque em "Desfazer". O cartão não volta, e Ajustes mostra a data do backup como se ele fosse deste celular. Saia e volte: vira "hoje".
4. **BK8:** com TalkBack, em Ajustes, toque duas vezes na linha "Último backup" de outro celular. A folha precisa abrir.
5. **G16:** com um "Leite" de UHT em litro e com preço, bipe um leite em pó, salve e registre o preço em outro mercado. O destaque da tela do produto e o "Mais barato" vão para o leite em pó.
6. **G17:** com um produto chamado "Ninho" ou "Nescau", bipe um iogurte Ninho ou uma bebida láctea Nescau. A folha não deveria sugerir o produto da marca.

## Referência primeiro, do nosso jeito depois

Seguindo [processo.md](../design/processo.md), o que outras fontes fazem nos pontos novos.

| Problema | Referência | O que levamos | O que fazemos diferente |
| --- | --- | --- | --- |
| Desfazer que não desfaz tudo | O próprio padrão do Bipa (ADR 0016, 0022): o Desfazer volta o estado anterior inteiro, não só os dados | A marca do backup pendente faz parte do estado e volta junto | Restaurar outro arquivo não responde à pergunta sobre o arquivo pendente |
| Descartar algo que não volta | **Android Developers**, Auto Backup ([guia](https://developer.android.com/identity/data/autobackup)): só o backup mais recente fica guardado, e a restauração acontece na instalação | Tratar o arquivo do outro celular como insubstituível até o fim do dia em que foi deixado de lado | O diário espera o dia seguinte, e o aviso diz quando ("amanhã") em vez de "o próximo" |
| Botão para o leitor de tela | **W3C**, WCAG 4.1.2 Name, Role, Value ([entenda](https://www.w3.org/WAI/WCAG22/Understanding/name-role-value.html)): papel de botão exige a ação que o ativa | O padrão dos componentes do Bipa: `Semantics` com `onTap` quando exclui os filhos | Nada diferente: é corrigir a linha nova |
| Preço por unidade com grandezas diferentes | O próprio `priceTrend` do Bipa: a unidade da maioria dos preços | A mesma regra no destaque e no "Mais barato" | A escolha do catálogo também recusa a unidade que não combina |

## Lotes sugeridos

Em ordem.

1. **O backup do outro celular não se perde por caminho lateral** (BK5, BK7). Sem quadro: adotar só o próprio arquivo, devolver a marca no Desfazer e comparar o id ao deixar de lado. Antes de qualquer build para outras pessoas.
2. **"Deixar de lado" que espera o dia** (BK6). Pede decisão do mantenedor sobre o texto do aviso e da linha de Ajustes, e a nota do quadro InicioBackupPendente com "amanhã".
3. **TalkBack e texto do backup** (BK8, BK9). O `onTap` na linha e o texto que serve à reinstalação.
4. **Catálogo por unidade e por marca** (G16, G17), junto com o resto do G12 (a linha "No catálogo"), o G13 no gerador (nomes só em português, grafia das marcas) e o G14. Pede a decisão do mantenedor sobre o leite em pó e o quadro da "Embalagem nova" com o catálogo.
5. **Quadros que já esperavam** (H20, G15, AB14, H19, H1 resto e InicioRelatorioFalhas), como no lote 12.

## O que funciona bem (manter)

- **O diário que diz que parou.** "Automático pausado até você decidir" troca uma frase que ficaria falsa por uma verdadeira, sem cor e sem cartão novo.
- **A pergunta antes de apagar, com os números do que some.** O diálogo de "Fazer backup agora" diz a data, os três números e "não volta mais", e um banco vazio não apaga nada nem com o sim.
- **A reserva que dura o aviso.** Sem relógio próprio, o Desfazer da restauração segue as regras de tempo de todo aviso, e os testes cobrem TalkBack, "Tempo para agir" e o dedo em cima.
- **A confirmação que mostra o que se perde.** Os mesmos números dos dois lados, o ano e a linha "saem deste celular" fazem um backup velho parecer velho.
- **O banco de casos reais do catálogo.** A calibragem virou teste com linhas do arquivo, o que deixa ajustar a regra sem regredir. G16 e G17 cabem nele.
- **A escolha que abre com o parecido.** Quando a folha sugere um produto novo, a troca abre com o produto que a pessoa já tem, e "Criar" segue com o nome do catálogo.

## Fontes

Base interna: `CLAUDE.md`, `docs/estado.md`, `docs/roadmap.md`, os ADRs 0023 e 0024, `docs/design/processo.md`, o README do protótipo e os quadros AjustesBackup, AjustesBackupPendente, RestaurarBackup, RestaurarBackupResultado, InicioBackupEncontrado e InicioBackupPendente (HTML em `docs/design/prototipo/fonte/`), a análise do lote 12 e o código em `lib/`, `test/` e `android/` no commit `5ace292` (diff `b0ba36a..5ace292`). Nada foi compilado. Os exemplos do G16 e do G17 são linhas de `assets/catalog/catalogo.sqlite`, consultadas só para leitura e seguidas à mão por `_catalogProductIn`, `_catalogProductName` e `_kindsAgree`. As contagens vêm de consultas no mesmo arquivo.

Referências externas:

- [Android Developers: backup automático dos dados do app](https://developer.android.com/identity/data/autobackup)
- [W3C: Understanding SC 4.1.2 Name, Role, Value](https://www.w3.org/WAI/WCAG22/Understanding/name-role-value.html)
