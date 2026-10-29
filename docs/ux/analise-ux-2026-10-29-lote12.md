# Análise de UX do Bipa (lote 12)

> Análise feita no commit `e95810c`, sobre o que entrou depois de `795693e`: o resto do lote 11 (G9, G10, G11 e H18); o backup e a restauração (B5), com o serviço `.bipa`, o backup diário na abertura, a restauração em dois tempos com reserva e Desfazer, o grupo "Backup" em Ajustes, a folha de restauração e o cartão "Backup encontrado" no Início do celular novo; e o catálogo pronto (ADR 0024), com o gerador em `tool/catalogo`, o `catalogo.sqlite` de 40.944 produtos, a "Embalagem nova" preenchida pelo catálogo, a origem da embalagem (esquema 15), a linha "Dados do Open Food Facts" na tela do produto e a atribuição em "Sobre o Bipa". Os caminhos e o "o que a pessoa vive" descrevem o app desse commit. As análises anteriores estão em [lote 7](analise-ux-2026-10-28.md), [lote 8](analise-ux-2026-10-28-lote8.md), [lote 9](analise-ux-2026-10-28-lote9.md), [lote 10](analise-ux-2026-10-28-lote10.md) e [lote 11](analise-ux-2026-10-29-lote11.md).

Oct 29, 2026 · @Wesley

## Resumo

O lote fecha G9, G10, G11 e H18, e a parte mecânica do backup é cuidadosa: nada muda antes de conferir, a troca não deixa metade trocada, um arquivo ruim para na folha com a saída certa, e a confirmação mostra os números do arquivo e os do celular. O que preocupa está nas pontas, onde o backup encontra a pessoa, e no catálogo, que repete em escala o risco que o G6 resolveu no granel:

1. **O backup do celular antigo some sem a pessoa decidir (BK1, crítico).** O `ultimo.bipa` trazido pelo Android só se restaura pelo cartão do Início, e o cartão some para sempre com o primeiro item em casa. Nenhuma tela de Ajustes restaura esse arquivo. Daí em diante o backup diário para em silêncio (Ajustes continua dizendo "Automático, uma vez por dia"), e o primeiro "Fazer backup agora" grava por cima do backup do celular antigo, que o Android leva ao Google Drive na noite seguinte. "Começar do zero" leva ao mesmo fim, e o README promete que o arquivo "continua restaurável pelos Ajustes".
2. **O Desfazer da restauração vence em 10 s mesmo quando o aviso espera (BK2, alto).** A reserva sai por um relógio próprio de 10 s, mas o aviso, pela regra do H13, fica até o toque com TalkBack, estica com o "Tempo para agir" do Android e para com o dedo em cima. Quem mais precisa de tempo toca em "Desfazer" e ouve "O prazo para desfazer já passou".
3. **O catálogo põe a embalagem num produto mais genérico, e a folha não mostra o nome do catálogo (G12, alto, provável).** Com "Leite" cadastrado, o leite condensado Italac vira "Embalagem nova de Leite"; com "Arroz", o arroz carreteiro de 175 g; com "Uva", a Fanta Uva. A folha nunca mostra "Leite Condensado Semidesnatado", então a pessoa confere sem ver o que está aceitando.
4. **O nome novo que o catálogo sugere sai pela metade (G13, médio).** Tirar a marca deixa só o sabor ("Fanta Uva" vira "Uva", "Heineken Original" vira "Original"), há nomes em espanhol com código brasileiro ("Leche condensada") e a marca em caixa alta perde o acento ("NESTLE" vira "Nestle").

Também entram: a confirmação que compara números que não mostram o que se perde (BK3), o "Restaurar" do cartão que apaga a lista escrita sem folha nem Desfazer (BK4), o tamanho "1 u, 120 g" lido como 1 unidade (G14), a linha da fonte que não leva a lugar nenhum (G15) e a atribuição de "Sobre" sem os links que a ODbL pede (H20). BK1 e BK2 pedem decisão antes do primeiro build que chegue a alguém além do mantenedor.

## Situação dos achados anteriores

Das cinco análises anteriores saíram 66 achados. Este lote resolveu G9, G10, G11 e H18. Hoje são 62 resolvidos, 2 parciais (H1 e H3) e 2 abertos (AB14 e H19); nenhum regrediu. Abaixo, só os itens que este lote tocou ou que não estão fechados; os demais seguem como na análise do lote 11. "Conferido" quer dizer lido no código deste commit.

| ID | Achado anterior | Situação | O que mudou |
| --- | --- | --- | --- |
| G9 | Uma palavra diferente na etiqueta esconde o produto | Resolvido (conferido) | `_shorterQuery` em `package_suggestion.dart`: quando o recorte inteiro não acha nada, a busca abre com a palavra do recorte que acha menos produtos ("Limão", "Mussarela"), e o "Criar" segue com o recorte inteiro. Melhor que a primeira palavra que a análise propôs: em "PAO FRANCES KG", abre com "Pão" e mostra os pães que existem. |
| G10 | Voltar do produto criado tira o Desfazer | Resolvido (conferido) | `_showUndoThenOfferDelete` em `product_detail_page.dart` espera a volta do destino e depois `controller.closed`, como o caminho sem destino. |
| G11 | Meio acento nas palavras de balança | Resolvido (conferido) | `_accents` ganhou 25 palavras (francês, grão, linguiça, abóbora, parmesão, suíno, padrão, contrafilé…). |
| H18 | Cartão do relatório no meio da busca | Resolvido (conferido) | `home_page.dart`: o `CrashReportingAskCard` só entra com `_query` vazio e sem local escolhido. |
| H1 | Abas com dois visuais | Parcial | Sem mudança na escolha de produto (`product_picker_sheet.dart`); a "Embalagem nova" com o catálogo pede o mesmo quadro (G12). |
| H3 | Alturas fixas com texto dentro | Parcial | Sem mudança. As telas novas entraram no teste a 200% (`large_text_test.dart`). |
| AB14 | Escolher o local no aviso tira o "ter sempre" | Aberto | Não tocado; pede o quadro "CapturaCasaLocal". |
| H19 | Anel recomeça a cada volta de tela cheia | Aberto | Não tocado; pede a regra no design system. |

## Problemas por jornada

Caminhos relativos ao repositório. Tudo foi avaliado lendo o código, sem compilar; os exemplos do catálogo são linhas reais de `assets/catalog/catalogo.sqlite`, consultadas com Python, seguidas à mão por `PackageSuggestion.fromCatalog`. Gravidade: crítico perde dado ou bloqueia a tarefa; alto é dado errado ou caminho principal confuso; médio é atrito; baixo é acabamento. "Provável" quando o efeito depende de rodar o app ou do que a pessoa bipa.

### I. Backup e restauração (nova)

Os códigos desta jornada começam com BK, para não confundir com as lacunas B1 a B5 do ADR 0023.

**BK1. O backup do celular antigo só se restaura pelo cartão, que some com o primeiro uso; depois disso o diário para e o manual grava por cima (crítico).**

- **Onde:** `RestoreOffer.call` em `lib/features/backup/domain/restore_offer.dart:25-26` (a oferta exige o banco vazio), o cartão em `lib/features/stock/presentation/home_page.dart:290` (só com `entries.isEmpty`), `CreateBackup.call` em `lib/features/backup/domain/create_backup.dart:62-66` (o diário não grava enquanto `!latest.madeHere`) e a linha 98 (o manual grava se o banco não está vazio), e o grupo de Ajustes em `lib/features/backup/presentation/backup_settings_group.dart:96-119`, que só informa o último backup: "Restaurar de um arquivo…" abre o seletor do Android, que não vê `files/backup/ultimo.bipa`, a pasta privada do app.
- **O que a pessoa vive:** troca de celular, instala o Bipa e o Android traz o `ultimo.bipa` com 214 produtos e um ano de preços. Ela não lê o cartão, ou o lê no mercado e deixa para depois: vai às compras, bipa no carrinho e termina. A casa ganha itens, o cartão some e, na abertura seguinte, a oferta deixa de existir (o banco não está vazio). Em Ajustes, "Último backup: 12/10 · Automático, uma vez por dia" continua lá, mas nada é gravado: o diário espera uma resposta que não tem mais onde ser dada. Semanas depois, ela toca em "Fazer backup agora" para garantir, e o backup do celular antigo é substituído sem aviso; o backup do Google guarda só o mais recente e o troca na noite seguinte ([Android Developers](https://developer.android.com/identity/data/autobackup)). O mesmo fim vem por "Começar do zero": passado o Desfazer de 10 s, o arquivo é adotado, e o primeiro diário com dados grava por cima.
- **Por que importa:** é o único caminho para o histórico do celular antigo, e ele se fecha sem a pessoa ver uma pergunta. O README do protótipo diz que, depois de "Começar do zero", "o arquivo continua restaurável pelos Ajustes até o próximo backup diário", e que, se a pessoa "bipar antes de responder, 'Restaurar' passa pela folha": nenhuma das duas coisas existe no app. E a frase "Automático, uma vez por dia" fica falsa sem que nada mude na tela.
- **O que fazer:** três partes, com quadro antes.
  1. **A linha "Último backup" restaura.** Tocar na linha abre a mesma folha de "Restaurar de um arquivo…", com o `ultimo.bipa` já conferido. Quando o arquivo é de outro aparelho, a linha diz isso ("Do outro celular · 12/10") no lugar de "Automático, uma vez por dia". Isso cumpre a promessa do README e, de quebra, dá até o dia seguinte para voltar atrás de uma restauração ou de um engano, porque o `ultimo.bipa` de hoje tem os dados de antes.
  2. **O cartão fica até a resposta**, como o protótipo pede, mesmo com itens em casa: em cima de "Acabando", menor, e com "Restaurar" passando pela folha quando já há o que perder. A oferta passa a depender de `!madeHere`, não do banco vazio.
  3. **Gravar por cima de um backup de outro aparelho pede confirmação.** "Fazer backup agora" e "Salvar uma cópia…" com `!latest.madeHere` perguntam antes ("Substituir o backup do outro celular, de 12/10?"), e o aviso de "Começar do zero" diz o que vai acontecer ("O próximo backup grava por cima").
  Testes: em `backup_controller_test.dart`, o diário com o banco cheio e `madeHere` falso; em `backup_settings_test.dart`, a linha restaurável e a confirmação do manual.

**BK2. O Desfazer da restauração vence em 10 s mesmo quando o aviso espera (alto).**

- **Onde:** `BackupController.applyRestore` em `lib/features/backup/presentation/backup_providers.dart:175-181` abre um `Timer` fixo de `RestoreBackup.undoWindow` (10 s), que apaga a reserva (`_closeUndo`). O aviso de `applyRestoreAndNotify` (`lib/features/backup/presentation/restore_sheet.dart:127-145`) segue `bipaToastTimeout` (`lib/core/design_system/components/bipa_toast.dart:39-46`): com leitor de tela e ação, não sai sozinho; fora disso, fica 10 s ou o "Tempo para agir" do Android, o que for maior, e para enquanto o dedo está sobre ele. O relógio da reserva começa antes do aviso entrar, quando a folha ainda está aberta.
- **O que a pessoa vive:** com TalkBack, restaura um arquivo e percebe pelos números que escolheu o backup errado. Até achar o aviso, passar pelo texto e chegar ao "Desfazer", passam uns 15 s. O aviso ainda está lá, como o H13 decidiu, mas o toque responde "O prazo para desfazer já passou." O mesmo com o "Tempo para agir" em 1 minuto, ou com o dedo parado no aviso enquanto lê. Sem leitor de tela, um toque no fim da linha do tempo também pode falhar (provável), porque a reserva começou a contar antes de o aviso entrar.
- **Por que importa:** é o Desfazer da ação mais destrutiva do app, e o quadro RestaurarBackupResultado promete o contrário ("Com leitor de tela, o aviso fica até o toque, como todo aviso com Desfazer"). Quem perde o prazo não tem outra saída no app (BK1).
- **O que fazer:** a reserva vive enquanto o aviso vive. `applyRestoreAndNotify` chama o descarte quando `controller.closed` termina com outro motivo que não a ação, e o `Timer` sai (ou vira um teto longo, de alguns minutos, por segurança). A limpeza na abertura seguinte (`AppDataSwap.atStartup`) continua. Teste de widget com `accessibleNavigation: true`: restaurar, esperar 15 s e desfazer.

**BK3. A confirmação compara números que não mostram o que se perde (médio).**

- **Onde:** `_CurrentLine` em `lib/features/backup/presentation/restore_sheet.dart:371` ("Neste celular agora: {produtos} e {preços}") e o título em `restore_sheet.dart:315`, com `BackupLabels.date` (`dd/MM`, sem ano).
- **O que a pessoa vive:** abre um `bipa-2025-10-12.bipa` achado no Drive. A folha diz "Restaurar o backup de 12/10?", que parece de duas semanas atrás. Os números são parecidos ("214 produtos · 1.380 preços · 56 itens em casa" contra "230 produtos e 1.452 preços"), porque o catálogo de casa muda pouco. O que muda muito, o estoque e as compras recentes, não aparece no lado deste celular: os itens em casa estão só no lado do arquivo, e as compras não estão em nenhum.
- **Por que importa:** o protótipo põe os números "para ninguém trocar uma casa mais nova por um backup velho sem ver". Dois números contra três, e uma data sem ano, deixam o caso comum (um backup mais velho que a casa) parecer inofensivo.
- **O que fazer:** os mesmos três números dos dois lados ("Neste celular agora: 230 produtos, 1.452 preços e 61 itens em casa"), o ano quando não é o atual ("12/10/2025") e, quando o arquivo é mais velho que o último registro do celular, uma linha que diz o que sai ("Os preços e as compras depois de 12/10 saem deste celular"). Pede o quadro RestaurarBackup atualizado.

**BK4. "Restaurar" no cartão apaga sem folha nem Desfazer o que não entra nos três números (médio).**

- **Onde:** `_restore` em `lib/features/backup/presentation/restore_offer_card.dart:61`: restaura direto, com `offerUndo: false`, quando `prepared.current == BackupSummary.empty`. O resumo conta só produtos, preços e itens em casa (`_summary` em `lib/features/backup/data/drift_backup_database.dart:51-63`). A lista aceita item escrito sem produto (`shopping_list_items.product_id` é opcional, `lib/core/database/tables.dart:177`), e os mercados também ficam de fora. O cartão continua na tela porque a oferta é calculada uma vez, no `build` do `backupProvider`.
- **O que a pessoa vive:** no celular novo, antes de decidir, abre a Lista e escreve "pão, leite, café" para a compra de hoje, ou cadastra o mercado do bairro. Volta ao Início, o cartão ainda está lá, e ela toca em "Restaurar". O backup entra sem confirmação, e a lista e o mercado somem sem Desfazer.
- **O que fazer:** decidir "casa vazia" por `BackupDatabase.isEmpty()` (todas as tabelas), a mesma regra da oferta, e não pelo resumo; com qualquer coisa, passar pela folha. Teste com um item escrito na lista.

### G. Produto e embalagens

**G12. O catálogo põe a embalagem num produto mais genérico, e a folha não mostra o nome do catálogo (alto, provável).**

- **Onde:** `PackageSuggestion.fromCatalog` em `lib/features/products/domain/package_suggestion.dart:78-97` escolhe com `_productIn` o produto da pessoa cujas palavras estão todas no nome do catálogo, o mesmo critério da etiqueta. A folha (`lib/features/products/presentation/new_package_sheet.dart:200-230`) mostra "EMBALAGEM NOVA DE" e o nome do produto escolhido, a marca e o tamanho, mas nunca o nome do catálogo.
- **O que a pessoa vive:** tem "Leite", "Arroz", "Feijão" e "Uva" cadastrados, como o ADR 0013 sugere. Bipa o leite condensado `7890000110266` ("Leite Condensado Semidesnatado ITALAC", 395 g): a folha diz "Embalagem nova de Leite · Italac · 395 g". Bipa `7893500012672` ("Arroz Carreteiro Tio João Cozinha Sabor 175g"): "Embalagem nova de Arroz · Tio Joao · 175 g". O feijão preto pronto da Camil ("Temperado e Cozido") vai para "Feijão", e a Fanta Uva (`78909052`) para a fruta "Uva". A folha veio "preenchida para conferir", com tudo plausível, e ela toca em Salvar.
- **Por que importa:** o preço do leite condensado entra no histórico do leite, o arroz temperado de 175 g, perto de dez vezes mais caro por kg, no do arroz comum, e o "menor por kg" e a comparação entre mercados passam a mentir. É o G6 de novo, agora no empacotado e com a autoridade de dados "do catálogo". Na etiqueta o risco já existia, mas o nome da etiqueta é curto e abreviado; o do catálogo é longo, e quanto mais palavras, mais produtos genéricos cabem nele.
- **O que fazer:** levar a regra do G6 e do G9 para cá.
  1. Uma linha sob o produto com o nome do catálogo, como a dica "Na etiqueta" da escolha de produto: "No catálogo: Leite Condensado Semidesnatado ITALAC", em `caption` e `ink-muted`. A pessoa vê o que está conferindo.
  2. Escolher o produto só quando ele cobre a maior parte do nome recortado (`_catalogProductName`), como o passo 3 do `productQueryFromLabel` (`bestCount * 2 > words.length`): "Arroz branco" em "Arroz branco tipo 1" fica; "Leite" em "Leite condensado semidesnatado" não, e a folha sugere o produto novo, com "Leite" a um toque na troca.
  3. Testes em `package_suggestion_test.dart` com essas quatro linhas reais, e um banco pequeno de casos do catálogo, como o `tool/ocr_bench`, antes de afinar a regra.

**G13. O nome novo que o catálogo sugere sai pela metade (médio).**

- **Onde:** `_catalogProductName` e `_catalogBrand` em `lib/features/products/domain/package_suggestion.dart:141-161`, e `nome()` em `tool/catalogo/catalogo.py`, que usa `product_name` quando falta `product_name_pt`.
- **O que a pessoa vive:** sem produto parecido cadastrado, bipa e vê o nome a criar:
  - a marca sai e sobra o sabor ou a linha: "Fanta Uva" vira o produto "Uva", "Heineken Original 600ml" vira "Original", "Nescafe Classic" vira "Classic", "Kit Kat Dark" vira "Dark";
  - nomes em espanhol com código brasileiro: `7891000107263` "Leche Condensada", `7891000005422` "Crema de leche", `7891000342176` "Leche en polvo";
  - a marca em caixa alta perde o acento: das linhas com código 789, 5.919 têm a marca em caixa alta, e "NESTLE" vira "Nestle", "TIO JOAO" vira "Tio Joao".
- **Por que importa:** o produto "Uva" no meio das frutas, com o preço de um refrigerante, é pior do que nenhum nome: a busca e a Lista o mostram como a fruta. O ADR 0024 contava com caixa alta e nomes errados ("a folha de conferir continua mostrando tudo"), mas a folha mostra o nome já recortado, não o original (G12).
- **O que fazer:** se tirar a marca deixa uma palavra só, manter a marca no nome ("Fanta uva", "Heineken original"). No gerador, guardar só nome em português (o `lang` do Open Food Facts, ou `product_name_pt`) e deixar o nome vazio quando não houver, para a etiqueta nomear; e escolher, para cada marca, a grafia mais comum fora da caixa alta no próprio dump ("Nestlé", "Tio João"). Testes no `tool/catalogo/testes.py` e em `package_suggestion_test.dart`.

**G14. "1 u, 120 g" vira 1 unidade (baixo).**

- **Onde:** `tamanho()` em `tool/catalogo/catalogo.py:130-150`: `_PADRAO_TAMANHO.search` fica com a primeira medida do texto.
- **O que a pessoa vive:** bipa o doce de leite caseiro ("1 u, 40 g") e a folha vem com "1 un" no tamanho. O preço fica sem preço por kg, e a comparação com o doce de leite de 400 g some. São 64 linhas com unidade "un" e gramas ou mililitros no texto.
- **O que fazer:** quando o texto tem uma medida de massa ou volume, ela vale sobre "u"/"unidades", menos no multipack ("6 x 200 ml"). Caso novo em `testes.py`.

**G15. A linha "Dados do Open Food Facts" não leva a lugar nenhum e diz menos do que o leitor de tela ouve (baixo).**

- **Onde:** `product_detail_page.dart:526-538`. O texto visível é "Dados do Open Food Facts"; o rótulo acessível, "Marca e tamanho das embalagens com dados do Open Food Facts, sob a licença ODbL". A origem fica `openFoodFacts` mesmo depois de a pessoa corrigir a marca e o tamanho (`package_edit_sheet.dart`, de propósito, ADR 0024). Entrou sem quadro.
- **O que a pessoa vive:** corrige a embalagem que veio errada do catálogo, e a tela continua dizendo "Dados do Open Food Facts" embaixo das embalagens, sem dizer quais dados nem como ver de onde vieram. Tocar não faz nada.
- **Por que importa:** pela regra "todo texto se justifica", a linha se justifica pela licença, mas hoje é só obrigação: não ajuda a pessoa a conferir nem a corrigir na fonte. E quem enxerga lê uma coisa, quem ouve, outra.
- **O que fazer:** fazer da linha um link discreto para a página do produto no Open Food Facts (`openfoodfacts.org/product/{código}`), com o mesmo texto visível e no rótulo ("Dados do Open Food Facts", "abre no navegador"), o que dá à linha um uso: ver a ficha e corrigir lá. Desenhar no quadro do produto antes.

### H. Consistência e acessibilidade

**H20. A atribuição de "Sobre o Bipa" não tem os links que a ODbL pede, nem vem do ARB (médio).**

- **Onde:** `lib/features/settings/presentation/settings_page.dart:96-99` mostra `catalog_meta.attribution`, lido do arquivo: "Contém informações do Open Food Facts, disponíveis sob a ODbL", em texto puro.
- **O que a pessoa vive:** nada, e esse é o problema: a frase não abre o Open Food Facts nem a licença, e não cita o Open Products Facts e o Open Beauty Facts, que estão no arquivo (1.099 produtos).
- **Por que importa:** o ADR 0024 decidiu a frase "com o link", e a ODbL 4.3 pede que o nome da base aponte para ela e "Open Database License" para o texto da licença ([ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/)). Sem isso, o app pode cair na lista de reúsos fora de conformidade que o próprio ADR cita. E o `CLAUDE.md` pede todo texto visível no ARB; o do arquivo não passa pela tradução nem pela revisão de texto.
- **O que fazer:** o texto no ARB, com as três bases e dois links (a base e a licença), e o `catalog_meta.attribution` só como conferência no teste. Cabe na linha de informação de Ajustes, sem quadro novo.

### Conferido sem achado

- **App fechado no meio da troca.** `AppDataSwap.recover` roda antes de abrir o banco e devolve os arquivos antigos; `app_data_swap_test.dart` cobre cada ponto. A pessoa volta aos dados de antes sem aviso, o que é honesto: o "restaurado" nunca apareceu.
- **Arquivo que não serve e backup de app mais novo.** Param na folha, no lugar da confirmação, com "Escolher outro arquivo" ou "Atualizar o Bipa", e a frase "Nada mudou neste celular" é verdadeira: a conferência roda numa cópia.
- **"Restaurar" do cartão com a casa de fato vazia.** Sem folha e sem Desfazer é a escolha certa: não há o que perder (o caso que perde está em BK4).
- **Backup diário com o banco vazio.** Não grava: um app recém-instalado não troca o backup do Google por um vazio.
- **"Salvar uma cópia…" cancelado no seletor.** O backup é montado antes do seletor e já vira o `ultimo.bipa`; cancelar deixa um backup novo do estado atual, o que não faz mal.
- **Arrastar a folha durante "Restaurando".** O `PopScope` não segura o arraste, mas a troca continua (`_applied`), e o aviso chega do mesmo jeito.
- **Letra grande e movimento reduzido.** Os números passam a um por linha a 150%, os botões do cartão empilham, e o `BipaLoader` fica parado com "Remover animações". As telas novas estão no teste a 200%.
- **Cores e textos.** Nenhum `Color(0x…)` nas telas novas; Ajustes e o cartão ficam neutros, com `alert-text` só no ícone de erro. Fora a atribuição (H20), os textos estão no ARB.
- **A escolha com a palavra mais específica (G9).** Com "Pão de forma" e "Pão de queijo", "PAO FRANCES KG" abre com "Pão", mostra os dois e oferece "Criar “Pão francês”", já com o acento do G11.

## Divergências com o design system e o protótipo

O design system vale sobre o código. As cópias do repositório estão à frente das publicadas (`estado.md`); o que segue é o que sobra além disso.

- **README do protótipo, linha InicioBackupEncontrado:** diz que o arquivo "continua restaurável pelos Ajustes" e que, se a pessoa bipar antes de responder, "Restaurar" passa pela folha. No app, nenhuma das duas acontece (BK1). Ou o app ganha a linha restaurável, ou o README deixa de prometer.
- **Quadro RestaurarBackupResultado:** "Com leitor de tela, o aviso fica até o toque, como todo aviso com Desfazer". O aviso fica, mas o Desfazer não funciona depois de 10 s (BK2).
- **"Embalagem nova" com o catálogo, sem quadro:** a folha preenchida pelo catálogo usa o quadro "Bipar: embalagem nova", desenhado para a etiqueta. O quadro novo precisa da linha "No catálogo: …" (G12) e entra junto com o da escolha de produto (H1 resto).
- **"Dados do Open Food Facts" e a atribuição em "Sobre", sem quadro:** nenhuma das duas está em Produto nem em AjustesBackup (que mostra "Sobre o Bipa" só com a versão). Desenhar as duas, já com os links (G15, H20).
- **ADR 0024:** a primeira consequência diz "bipar um produto conhecido não abre o cadastro", mas o app abre a folha preenchida para conferir, como a decisão do mesmo ADR pede ("a pessoa confere, como hoje"). Ajustar a frase. A lista "Falta fazer" ainda tem a coluna de origem, a busca no fluxo do bipe e os textos de atribuição, que entraram; falta a medição de cobertura com cupons reais.
- **`roadmap.md` e `estado.md`:** o roadmap ainda tem o backup (B5), o catálogo e os itens do lote 11 (G9 a G11, H18) abertos, e o `estado.md` diz esquema 14 e põe B5 e o catálogo como próximos passos. A lista do teste no aparelho não tem o backup nem o catálogo.

## Referência primeiro, do nosso jeito depois

Seguindo [processo.md](../design/processo.md), o que outras fontes fazem nos pontos novos.

| Problema | Referência | O que levamos | O que fazemos diferente |
| --- | --- | --- | --- |
| Backup do aparelho antigo que se perde | **Android Developers**, Auto Backup ([guia](https://developer.android.com/identity/data/autobackup)): só o backup mais recente fica guardado, e um novo apaga o anterior, em geral na mesma noite | Tratar o `ultimo.bipa` de outro aparelho como insubstituível até a pessoa decidir | Pedir confirmação antes de gravar por cima, e deixar o arquivo restaurável em Ajustes, não só no cartão |
| Desfazer com tempo que acompanha a pessoa | O próprio H13 e o **WCAG 2.2.1** (Timing Adjustable), que o `bipaToastTimeout` já segue | O prazo da reserva é o prazo do aviso | Um teto longo de segurança, e a limpeza na abertura seguinte |
| Sugestão de produto pelo catálogo | O G6 e o G9 do próprio Bipa: a dica "Na etiqueta" e o "Criar" da variedade | Mostrar a fonte ao lado da sugestão, para comparar | Só escolher o produto quando ele cobre a maior parte do nome |
| Atribuição de base aberta | **ODbL 1.0**, seção 4.3 ([texto](https://opendatacommons.org/licenses/odbl/1-0/)): "Contains information from…", com o nome da base e da licença como links | A frase com os dois links, em "Sobre" | Na tela do produto, o link vai para a ficha do produto, que serve à pessoa |

## Lotes sugeridos

Em ordem.

1. **Backup que não se perde** (BK1, BK4). Antes do primeiro build para outras pessoas. A linha "Último backup" restaurável e com a origem, o cartão até a resposta, a confirmação antes de gravar por cima de um backup de outro aparelho e a casa vazia por `isEmpty()`. Pede quadro (a linha e o cartão menor) e decisão do mantenedor sobre o cartão com a casa cheia.
2. **Desfazer que espera a pessoa** (BK2, BK3). A reserva presa ao aviso, sem quadro; os três números dos dois lados e o ano, com o quadro RestaurarBackup atualizado.
3. **Catálogo que não junta** (G12, G13, G14). A linha "No catálogo", a regra da maior parte do nome, a marca que fica quando sobra uma palavra, nomes só em português e a grafia da marca, no app e no gerador, com um banco de casos reais. Pede o quadro da "Embalagem nova" com o catálogo, junto com o da escolha de produto (H1 resto).
4. **Atribuição com link** (H20, G15). O texto de "Sobre" no ARB com os links, e a linha do produto como link para a ficha. Pede os dois quadros.
5. **Quadros que já esperavam** (AB14, H19, H1 resto e InicioRelatorioFalhas), como no lote 11.

## O que funciona bem (manter)

- **Conferir antes de perguntar.** O arquivo inteiro é aberto, migrado e lido linha a linha numa cópia; a folha só pergunta sobre o que já sabe que funciona, e o erro vem com a saída certa.
- **A troca sem meio-termo.** A marca antes de mover qualquer arquivo e o `recover` antes de abrir o banco: um app fechado no meio volta inteiro ao que era.
- **Os lotes acertados em vez de recusar.** A diferença tem conserto, e a folha diz quantos itens mudaram, em vez de jogar fora um backup bom.
- **O diário que não grava vazio.** Um app recém-instalado não apaga o backup do Google, e a abertura não espera o backup.
- **O catálogo que não atrapalha.** Sem asset, com arquivo estranho ou com erro, o bipe segue como antes, e o catálogo só abre na primeira consulta.
- **A escolha com a palavra mais específica (G9).** Abre com o que acha menos produtos e mantém o recorte inteiro como nome a criar.

## Fontes

Base interna: `CLAUDE.md`, `docs/estado.md`, `docs/roadmap.md`, os ADRs 0023 e 0024, `docs/design/processo.md`, o README do protótipo e os quadros AjustesBackup, RestaurarBackup, RestaurarBackupResultado e InicioBackupEncontrado (HTML em `docs/design/prototipo/fonte/`), a análise do lote 11 e o código em `lib/`, `test/`, `android/` e `tool/catalogo/` no commit `e95810c` (diff `795693e..e95810c`). Nada foi compilado. Os exemplos do G12 ao G14 são linhas de `assets/catalog/catalogo.sqlite` (gerado em 29/10/2026), seguidas à mão por `fromCatalog`, `_productIn`, `_catalogProductName` e `productNameFromLabel`; as contagens vêm de consultas SQL no mesmo arquivo.

Referências externas:

- [Android Developers: backup automático dos dados do app](https://developer.android.com/identity/data/autobackup)
- [Open Data Commons: Open Database License 1.0](https://opendatacommons.org/licenses/odbl/1-0/)
- [W3C: Understanding SC 2.2.1 Timing Adjustable](https://www.w3.org/WAI/WCAG22/Understanding/timing-adjustable.html)
