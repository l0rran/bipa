# Análise de UX do Bipa (lote 14)

> Análise feita no commit `21c004b`, sobre o que entrou depois de `f55bcab`: BK5 (o `ultimo.bipa` é adotado só quando a pessoa restaura ele mesmo, e o Desfazer devolve a pendência), BK7 (deixar de lado confere o id), BK6 (o arquivo deixado de lado só é substituído no dia seguinte, com a marca `ultimo.deixado` e o "Automático volta amanhã"), BK8 (a ação de toque na `Semantics`), BK9 ("Veio do backup do Google" no lugar de "outro celular"), G16 (a grandeza tem que combinar na escolha do catálogo, e o destaque e o "Mais barato" ficam na grandeza da maioria) e G17 (a marca no nome não dispensa tipo, sabor, categoria e grandeza, com a tabela de marcas). Os caminhos e o "o que a pessoa vive" descrevem o app desse commit. As análises anteriores estão em [lote 7](analise-ux-2026-10-28.md), [lote 8](analise-ux-2026-10-28-lote8.md), [lote 9](analise-ux-2026-10-28-lote9.md), [lote 10](analise-ux-2026-10-28-lote10.md), [lote 11](analise-ux-2026-10-29-lote11.md), [lote 12](analise-ux-2026-10-29-lote12.md) e [lote 13](analise-ux-2026-10-29-lote13.md).

Oct 29, 2026 · @Wesley

## Resumo

O lote corrige os sete achados do lote 13 nos cenários descritos lá. Restaurar outro arquivo não responde mais pelo backup pendente, o Desfazer devolve a pergunta, "Deixar de lado" espera o dia seguinte e avisa quando, um backup novo feito com o aviso na tela não vira "de outro aparelho", o TalkBack abre a linha de Ajustes, e o leite em pó com tamanho não entra mais no "Leite" em litros. O destaque e o "Mais barato" deixam de comparar kg com litro em qualquer produto. Sobram dois caminhos laterais, um no backup e um no catálogo, e dois acabamentos:

1. **O diário roda enquanto o Desfazer da restauração está na tela, e depois do Desfazer o backup do outro celular volta com a data de hoje (BK10, alto, provável).** Nada se perde na hora, porque o arquivo novo tem os mesmos dados. Mas o cartão e Ajustes passam a mostrar "Backup do Google" de hoje. A pessoa tende a deixar de lado um backup de hoje, e no dia seguinte o diário grava por cima dele.
2. **Metade do catálogo não tem tamanho, e nesses produtos a regra da grandeza não vale (G18, médio).** "Leite em pó desnatado" da Batavo, sem tamanho, ainda entra no "Leite" em litros. Depois que a pessoa digita os 400 g, o "Leite" passa a se medir também em kg, e daí em diante aceita qualquer leite em pó com tamanho.

Também entram: "Ninho Fases 1+" e "NESTLÉ NINHO Fases Zero Lactose" entram no "Ninho", e o filtro de papel sem tamanho entra no "Melitta" (G19, médio, provável). E "Veio do backup do Google" não é verdade quando o arquivo chega pela transferência direta entre aparelhos, por cabo ou Wi-Fi (BK11, baixo).

Nada aqui bloqueia o teste no aparelho. O BK10 pede correção antes de qualquer build para outras pessoas e aparece no teste se ele seguir "Para o teste no aparelho".

## Situação dos achados anteriores

Das sete análises anteriores saíram 82 achados. Este lote resolveu BK5, BK6, BK7, BK8, BK9, G16 e G17. Hoje são 73 resolvidos, 4 parciais (H1, H3, G12 e G13) e 5 abertos (AB14, H19, G14, G15 e H20). Nenhum regrediu. A tabela abaixo traz só os itens que este lote tocou ou que ainda não fecharam. Os demais seguem como na análise do lote 13. "Conferido" quer dizer lido no código deste commit.

| ID | Achado anterior | Situação | O que mudou |
| --- | --- | --- | --- |
| BK5 | O Desfazer de uma restauração, ou restaurar outro arquivo, apaga o backup do outro celular | Resolvido (conferido), com BK10 novo | `RestoreBackup.apply` (`restore_backup.dart:148-156`) só adota quando o id do manifesto restaurado é o do `ultimo.bipa` pendente. `replaceAppData` guarda a marca de antes em `restauracao/ultimo.id`, e `_returnMarker` (`local_backup_storage.dart:216`) a devolve no Desfazer. A abertura seguinte limpa tudo com a área de restauração (`AppDataSwap.atStartup`). Os dois cenários do lote 13 (o Desfazer pelo cartão e a cópia do Drive) agora mantêm a pendência. Sobra o diário que roda no meio (BK10). |
| BK6 | "Deixar de lado" apaga o backup do outro celular na volta seguinte ao app | Resolvido (conferido) | `dismiss` grava `ultimo.deixado` (id e hora). O diário só grava a partir do dia seguinte (`_setAsideBefore`, `create_backup.dart:72`). Ajustes ainda restaura pela linha e mostra "Automático volta amanhã". O aviso diz "Amanhã o backup deste celular grava por cima." Um backup novo publicado apaga a marca. |
| BK7 | Deixar de lado com o id antigo faz o backup deste celular parecer de outro | Resolvido (conferido) | `RestoreOffer.dismiss` lê o `ultimo.bipa` de novo dentro do `_serial` e não faz nada se o id mudou ou se ele já é deste aparelho. |
| BK8 | A linha pendente de Ajustes sem ação de toque para o TalkBack | Resolvido (conferido) | `onTap: onTap` na `Semantics` de `_PendingBackupRow`, com teste do toque pelo leitor de tela. |
| BK9 | "De outro celular" depois de reinstalar no mesmo aparelho | Resolvido (conferido), com BK11 novo | "Veio do backup do Google" na linha, na folha e no diálogo. Serve à reinstalação, mas não à transferência direta (BK11). |
| G16 | O "Leite" com leite em pó mistura kg e litro no destaque e no "Mais barato" | Resolvido (conferido), com G18 novo | `mainPriceUnit` (`package_prices.dart:77`) põe primeiro a grandeza da maioria dos preços, e `firstIsCheapest` (`:103`) só dá o selo quando há outro preço da mesma grandeza. Vale para qualquer produto que já misture grandezas. Na escolha, `_measureAgrees` (`package_suggestion.dart:204`) recusa a grandeza diferente, mas só quando o catálogo tem tamanho (G18). |
| G17 | Um produto com nome de marca recebe tudo o que leva a marca | Resolvido (conferido), com G19 novo | Os quatro exemplos do lote 13 (iogurte Ninho Fruti, fórmula infantil, brownie, bebida láctea Nescau) estão no banco de casos e são recusados. Tipo, sabor, categoria e grandeza valem também para o produto de marca, e `_brandProducts` dá a ele o tipo do produto pelo qual a marca é conhecida. Sobram nomes de linha sem palavra de tipo (G19). |
| G12 | O catálogo põe a embalagem num produto mais genérico | Parcial | Melhorou com G16 e G17. Ainda falta a linha "No catálogo: …" na folha (roadmap). |
| G13 | O nome novo que o catálogo sugere sai pela metade | Parcial | Entraram as grafias de "Molico" e "Toddy". O gerador não mudou. |
| G14 | "1 u, 120 g" vira 1 unidade | Aberto | Não foi tocado. Agora também pesa na escolha: esses 138 itens do catálogo, em "un", são recusados pelos produtos em g ou ml (G16). |
| G15, H20, AB14, H19 | | Aberto | Não foram tocados. |
| H1, H3 | | Parcial | Não foram tocados. |

## Problemas por jornada

Os caminhos são relativos ao repositório. Tudo foi avaliado lendo o código, sem compilar. Os exemplos do catálogo são linhas reais de `assets/catalog/catalogo.sqlite`, consultadas com `py -3` só para leitura e seguidas à mão por `_catalogProductIn`, `_catalogProductName` e `_measureAgrees`. A gravidade segue a mesma escala: crítico perde dado ou bloqueia a tarefa; alto é dado errado ou caminho principal confuso; médio é atrito; baixo é acabamento. "Provável" marca o efeito que depende de rodar o app.

### I. Backup e restauração

**BK10. O diário grava durante o Desfazer da restauração, e depois do Desfazer o backup do outro celular volta com a data de hoje (alto, provável).**

- **Onde:** `BackupController.runDailyBackup` (`lib/features/backup/presentation/backup_providers.dart:148`) só olha `_busy` e não olha `canUndoRestore`. `DailyBackup` (`lib/app/daily_backup.dart`) o chama a cada volta ao app. Depois de restaurar o arquivo pendente, ele já é "deste aparelho" e não é de hoje, então `CreateBackup.call` (`lib/features/backup/domain/create_backup.dart:69-74`) grava um `ultimo.bipa` novo, com id novo e a data de hoje. No Desfazer, `_returnMarker` (`lib/features/backup/data/local_backup_storage.dart:216-229`) devolve a marca de antes (nenhuma) sem conferir se o `ultimo.bipa` ainda é o arquivo que a restauração adotou. O relógio do aviso (`BipaToastClock`, `lib/core/design_system/components/bipa_toast.dart:144`) anda com os quadros da animação. Com o app no fundo não há quadros, então o aviso continua na tela quando a pessoa volta. Com TalkBack ele espera de qualquer jeito.
- **O que a pessoa vive:** no celular novo, com a casa já em uso, toca em "Restaurar" no cartão menor ("Restaurar o backup de 27/10/2026?") e confirma. Aparece "Backup de 27/10/2026 restaurado" com "Desfazer". Ela vai ao WhatsApp para conferir com alguém se era isso mesmo e volta. O diário grava nesse momento. Ela toca em "Desfazer", e a casa de hoje volta. O cartão também volta, mas agora diz "Restaurar o backup de 29/10/2026?", com os números do celular antigo. Ajustes mostra "Veio do backup do Google" de 29/10, e "Fazer backup agora" pergunta "Apagar o backup que veio do Google? O backup de 29/10/2026…". Um backup "de hoje" parece descartável. Se ela toca em "Deixar de lado", o diário do dia seguinte grava por cima, e o histórico do celular antigo some depois de duas respostas dadas com informação errada.
- **Por que importa:** é o mesmo fim do BK5 por outro caminho, e o caminho é natural: sair do app para conferir é o que se faz antes de decidir um Desfazer. A data é o que a pessoa usa para reconhecer o backup antigo, e aqui ela muda sem a pessoa ter feito backup nenhum. Enquanto isso, a casa de hoje fica sem backup automático ("Automático pausado").
- **O que fazer:**
  1. `runDailyBackup` não grava enquanto `state.value?.canUndoRestore` é verdadeiro. O diário espera o aviso sair, como a reserva já espera (BK2).
  2. Se a pessoa toca em "Fazer backup agora" ou "Salvar uma cópia…" com o Desfazer na tela, ela escolheu ficar com o restaurado. Uma saída é descartar a reserva antes de gravar (`discardRestoreUndo(restoreEpoch)`), e o aviso perde o "Desfazer". A outra é `_returnMarker` só devolver a marca quando o `ultimo.bipa` ainda tem o id adotado. A primeira é mais simples de explicar.
  3. Teste em `backup_controller_test.dart`: restaurar o arquivo pendente, rodar `runDailyBackup` com o relógio num dia depois do backup e desfazer. O `ultimo.bipa` continua sendo o de 27/10 e pendente.

**BK11. "Veio do backup do Google" não é verdade quando o arquivo chega pela transferência direta entre aparelhos (baixo).**

- **Onde:** `android/app/src/main/res/xml/data_extraction_rules.xml` inclui `backup/ultimo.bipa` também em `<device-transfer>`. Os textos ficam em `lib/core/l10n/app_pt.arb`: `backupLastFromGoogle` (linha 47), `backupFromGoogle` (134), `backupReplacePendingTitle` e o rótulo do cartão `backupOfferEyebrow` ("Backup do Google", 229).
- **O que a pessoa vive:** troca de celular ligando os dois por cabo, na tela "Copiar apps e dados" da configuração do Android, com o backup do Google desligado. O arquivo chega por cabo, e o app diz "Veio do backup do Google" e "Apagar o backup que veio do Google?". Quem desligou o backup do Google de propósito pode achar que ele foi ligado sem pedir.
- **O que fazer:** escolher um texto que sirva aos três casos (reinstalação, nuvem e cabo) sem afirmar a origem, por exemplo "Trazido pelo Android" ou "Veio na instalação do app", e usar o mesmo no rótulo do cartão. Cabe na revisão de texto, sem quadro novo. Se o mantenedor preferir manter "Google", vale registrar no ADR 0023 que a transferência por cabo também traz o arquivo.

### G. Produto e embalagens

**G18. A regra da grandeza não vale para metade do catálogo, e um leite em pó sem tamanho ainda abre a porta do "Leite" (médio).**

- **Onde:** `_catalogProductIn` (`lib/features/products/domain/package_suggestion.dart:204`) só confere a grandeza quando `unit != null`. Dos 40.944 itens do catálogo, 20.790 não têm `size_value`, e nenhum desses tem tamanho que `_size` leia no nome ou na quantidade. Sem tamanho, a folha abre com a unidade do produto sugerido (`new_package_sheet.dart:99`). Depois, `_measuresOf` aceita qualquer grandeza que o produto já tenha (`measures.contains`), então uma embalagem em kg dentro do "Leite" desliga a regra para todo leite em pó.
- **O que a pessoa vive:** tem "Leite" com o UHT de 1 L. Bipa o `7891097106736` "Leite em pó desnatado" (Batavo), que no catálogo não tem tamanho, e a folha diz "Embalagem nova de Leite", como antes do G16. Ela digita 400, troca a unidade para g e salva. O destaque continua certo, porque a maioria dos preços é por litro. Mas o "Leite" agora se mede em kg e em L, e o próximo leite em pó com tamanho, o `7891000101506` Molico 280 g, que o banco de casos espera recusado, também entra. São 55 itens de leite em pó sem tamanho, entre eles Piracanjuba, Aurora, Batavo e "Leite em pó - Ninho".
- **Por que importa:** o G16 trocou a calibragem do "em pó" pela regra da grandeza, mas a regra só funciona onde o catálogo tem tamanho. Do jeito que está, a primeira embalagem errada torna as seguintes certas. O banco de casos não tem nenhum item sem tamanho.
- **O que fazer:**
  1. Na folha, quando o catálogo não tem tamanho, conferir de novo ao salvar. Se a grandeza digitada não combina com a do produto sugerido (pela mesma `_measureAgrees`), a folha volta a sugerir o produto novo com o nome do catálogo, e o produto parecido fica a um toque, como já acontece quando a folha sugere um novo.
  2. Em `_measuresOf`, contar a grandeza principal do produto (a da maioria das embalagens, como em `mainPriceUnit`) em vez de todas. Assim uma embalagem fora do padrão não abre a porta.
  3. Pôr no banco de casos o `7891097106736` sem tamanho, com a casa do "Leite" em litro.

**G19. Linhas da marca sem palavra de tipo ainda entram no produto de marca (médio, provável).**

- **Onde:** `_catalogProductIn` (`package_suggestion.dart:206-213`): para um produto de marca, a primeira palavra do nome pode ser outra, desde que `ProductKind.of(head)` seja "outro", e só `_typeWords` e `_otherProducts` (`:307`) bloqueiam o resto. Sem tamanho no catálogo, a grandeza também não bloqueia (G18).
- **O que a pessoa vive:**
  - Tem "Ninho" (o leite em pó, 380 g). Bipa a lata de 1,2 kg do `7891000282748` "Ninho Fases 1+", categoria laticínios. O nome sugerido vira "Fases", "fases" não bloqueia, a categoria e a grandeza combinam, e a folha diz "Embalagem nova de Ninho". É o mesmo composto infantil que o banco de casos recusa quando o nome traz "Fórmula Infantil" (`7891000001080`, linha 180), com outro preço por kg e outro uso. O mesmo vale para o `7891000346945` "NESTLÉ NINHO Fases Zero Lactose" (800 g) e para o `7891000258590` "Ninho Nutrigold" (sem tamanho).
  - Tem "Melitta" (o café). Bipa o `7891021001946` "filtro de papel Melitta", sem tamanho, e a folha diz "Embalagem nova de Melitta". A linha com "30 un" (`7891021002097`) é recusada pela grandeza, mas a sem tamanho não.
  - No sentido contrário, que separa e não mistura: o `7891000284971` "Leite Pó Instantâneo Semidesnatado Ninho Levinho" não entra no "Ninho", porque "instantaneo" está em `_typeWords`. Já o "Leite po ninho instant lt" entra.
- **Por que importa:** G17 fechou os exemplos que tinham palavra de tipo. Linhas de produto como "Fases", "Nutrigold" e "Nutri Advance" não dizem o tipo, e com o filtro é o produto inteiro que muda sem palavra que o diga. Separar demais custa um toque na troca de produto. Misturar põe o preço de um composto infantil na tela do leite da casa.
- **O que fazer:** pôr "fases", "nutrigold" e "filtro" (ou "papel") em `_otherProducts` e esses quatro itens no banco de casos. Decidir com o mantenedor se "instantaneo" bloqueia só para o produto genérico ("Leite", "Café") e não para o de marca, cujo produto já é instantâneo. A correção do G18 cobre o filtro sem tamanho por outro caminho.

### Conferido sem achado

- **Desfazer, deixar de lado e "Fazer backup agora" no mesmo dia e no seguinte.** Foi seguido à mão:
  - Restaurar o pendente, desfazer, deixar de lado e reabrir no mesmo dia: o diário espera (`_setAsideBefore`), e Ajustes restaura e mostra "Automático volta amanhã". No dia seguinte, o diário grava por cima, como o aviso disse.
  - Deixar de lado e, com o aviso na tela, restaurar o pendente por Ajustes: `dismiss` vê o arquivo adotado e não marca nada. O Desfazer da restauração devolve a pergunta, e o cartão volta sem a marca de deixado.
  - Deixar de lado e depois "Fazer backup agora": o diálogo pergunta, e confirmado, `publishLatest` apaga `ultimo.deixado`.
  - "Salvar uma cópia…" com o arquivo deixado de lado grava só a cópia.
  - Restaurar outra cópia com o arquivo deixado de lado: a marca fica, e o diário do dia seguinte grava por cima, como prometido.
  - Duas restaurações seguidas: a segunda, sem adotar, apaga a marca guardada pela primeira, e o Desfazer volta ao estado da primeira, certo.
  - O único caminho novo de perda é o BK10.
- **O app fechado no meio.** Se o app fecha entre a troca e a adoção, o arquivo fica pendente, que é o lado seguro. A marca guardada sai com a área de restauração na abertura seguinte (`AppDataSwap.atStartup`). O intervalo entre `swap.undo` e `_returnMarker` é de milissegundos.
- **"Amanhã o backup deste celular grava por cima."** O aviso só aparece no cartão menor, com a casa em uso, então o diário de amanhã tem o que gravar. Deixado de lado às 23h59, "amanhã" chega em um minuto. A frase continua verdadeira, e o diálogo de Ajustes segue até lá. Quem não abre o app amanhã fica com o arquivo por mais tempo, que é o lado seguro.
- **"Automático volta amanhã".** Só aparece no dia em que o arquivo foi deixado de lado (`_automaticState`, `backup_settings_group.dart`). Depois de "Começar do zero" com a casa vazia, o diário volta, mas só grava quando houver algo. É o comportamento de sempre do diário e não contradiz o texto.
- **O destaque e o "Mais barato" com grandezas misturadas.** A grandeza da maioria vem primeiro, o mercado que só tem o preço por kg vai para depois, e um kg sozinho entre litros não ganha selo. É a regra do gráfico (`priceTrend`).
- **Produtos vendidos em g e em ml.** "Bebida láctea" tem 50 itens em g e 42 em ml, e "Sorvete" tem 24 em g, 105 em L e 104 em ml. Com a regra, esses produtos separam em vez de juntar: a folha sugere o produto novo, e a escolha abre com o parecido. Custa um toque e não engana o preço. Iogurte (394 g, 1 ml), requeijão, maionese, mel e molho de tomate são todos em massa, e a regra não muda nada para eles.
- **Marcas com mais de um produto.** O amaciante de uma marca de detergente é recusado pela palavra ("amaciante" em `_otherProducts`), e o sabão em pó pela grandeza (kg contra ml). Omo, Toddy e Danone têm casos reais no banco, que não foi rodado aqui.
- **Cores e textos.** Nenhum `Color(0x…)` nem texto fora do ARB nas mudanças. As descrições do ARB explicam o porquê dos textos novos.

## Divergências com o design system e o protótipo

O design system vale sobre o código. O README do protótipo já registra os textos novos ("Veio do backup do Google", "Amanhã o backup deste celular grava por cima.", "Automático volta amanhã"), mas os quadros em HTML não mudaram:

- **`fonte/InicioBackupPendente.dc.html`:** a nota do momento 2 (linha 77) ainda diz "o automático volta e grava por cima no dia seguinte", o que agora está certo. Mas o aviso desenhado (linha 86) ainda é "O próximo grava por cima."
- **`fonte/AjustesBackupPendente.dc.html`:** a linha diz "De outro celular. Toque para restaurar." (linhas 84-86), o rótulo acessível diz "de outro celular", e falta o momento "Automático volta amanhã" do dia em que o arquivo foi deixado de lado.
- Os dois quadros precisam ser refeitos com `tool/prototipo/renderizar.js` quando o texto do BK11 estiver decidido, para não refazer duas vezes.

## Para o teste no aparelho

Itens para observar por causa dos achados acima. O build de debug permite `run-as`.

1. **Simular o backup de outro celular.** Com o app fechado e antes da primeira abertura do dia, rode `adb shell run-as dev.l0rran.bipa rm files/backup/ultimo.id files/backup/ultimo.deixado` e abra o app. Agora também é preciso apagar o `ultimo.deixado`. Sem isso, um "Deixar de lado" de um teste anterior esconde o cartão.
2. **BK5 (corrigido):** toque em "Restaurar" no cartão menor, confirme e toque logo em "Desfazer". O cartão volta, e Ajustes mostra "Veio do backup do Google" com a data antiga.
3. **BK10:** repita o passo 2, mas antes do "Desfazer" vá a outro app e volte. Com o aviso ainda na tela, toque em "Desfazer". Se o cartão voltar com a data de hoje, o BK10 se confirmou.
4. **BK6 (corrigido):** toque em "Deixar de lado", espere o aviso sair, vá a outro app e volte. Em Ajustes, a linha ainda restaura, e embaixo de "Fazer backup agora" aparece "Automático volta amanhã". No dia seguinte, a linha passa a "hoje".
5. **BK8 (corrigido):** com TalkBack, toque duas vezes na linha "Último backup" pendente. A folha abre.
6. **G16 (corrigido):** com o "Leite" UHT em litro e com preço, bipe um leite em pó com tamanho no catálogo (Molico 280 g). A folha sugere um produto novo.
7. **G18:** se tiver um leite em pó Batavo ou Piracanjuba em casa, bipe e veja se a folha diz "Embalagem nova de Leite".
8. **G19:** com um "Ninho", bipe uma lata de Ninho Fases. A folha não deveria sugerir o "Ninho".

## Referência primeiro, do nosso jeito depois

Seguindo [processo.md](../design/processo.md), o que outras fontes fazem nos pontos novos.

| Problema | Referência | O que levamos | O que fazemos diferente |
| --- | --- | --- | --- |
| Ação automática durante o Desfazer | O próprio padrão do Bipa (ADR 0016, 0022, BK2): enquanto o aviso com Desfazer está na tela, nada torna a ação definitiva | O diário espera o aviso sair, como a reserva já espera | Um backup manual com o aviso na tela encerra o Desfazer, porque a pessoa escolheu ficar com o restaurado |
| Origem do arquivo trazido na instalação | **Android Developers**, Auto Backup ([guia](https://developer.android.com/identity/data/autobackup)): o mesmo conjunto de regras serve à nuvem e à transferência entre aparelhos (`device-transfer`) | Não afirmar um canal que o app não sabe qual foi | Um texto só para reinstalação, nuvem e cabo |
| Comparar só o que tem a mesma grandeza | O próprio `priceTrend` e o `mainPriceUnit` do Bipa | Usar a grandeza principal do produto, e não todas as que ele já teve, também na escolha do catálogo | Quando o catálogo não traz o tamanho, conferir com o tamanho que a pessoa digitou |

## Lotes sugeridos

Em ordem.

1. **O Desfazer que nada torna definitivo** (BK10). Não pede quadro: o diário espera o aviso, e o backup manual com o aviso na tela encerra o Desfazer. Fazer antes de qualquer build para outras pessoas.
2. **O texto da origem** (BK11), com os quadros AjustesBackupPendente e InicioBackupPendente refeitos de uma vez.
3. **A grandeza sem tamanho e as linhas da marca** (G18, G19), junto com o que sobra do G12, do G13 e do G14. Pede ao mantenedor a decisão sobre "instantâneo" no produto de marca.
4. **Quadros que já esperavam** (H20, G15, AB14, H19, o resto do H1 e InicioRelatorioFalhas), como no lote 13.

## O que funciona bem (manter)

- **A pendência que volta inteira.** A marca de antes fica junto da reserva e sai com ela. O Desfazer devolve os dados e também a pergunta, e restaurar outro arquivo não decide pelo pendente.
- **"Deixar de lado" que cumpre o que diz.** O aviso, a linha de Ajustes e o diário falam do mesmo dia, e a marca separada (`ultimo.deixado`) não confunde "deixado de lado" com "adotado".
- **A conferência do id na hora de gravar.** `dismiss` relê o arquivo dentro da fila. Essa mesma ideia resolveria o BK10 no `_returnMarker`.
- **Texto que não afirma o que o app não sabe.** O BK9 trocou uma origem que podia ser falsa por uma verdadeira na maior parte dos casos, sem guardar um identificador do aparelho no arquivo. O BK11 só pede para levar a ideia até o fim.
- **A grandeza da maioria no destaque.** A regra resolve o leite em pó e também qualquer produto que já misturou grandezas por outros caminhos (mover embalagem, etiqueta).
- **O banco de casos com marcas.** "Ninho", "Nescau", "Toddy", "Danone" e "Omo" agora têm linhas reais que separam o que é da marca do que só leva a marca. G18 e G19 cabem nele.

## Fontes

Base interna: `CLAUDE.md`, `docs/estado.md`, o ADR 0023 (seção 5), a análise do lote 13, o README do protótipo e os quadros InicioBackupPendente e AjustesBackupPendente (HTML em `docs/design/prototipo/fonte/`), as regras de backup em `android/app/src/main/res/xml/` e o código em `lib/` e `test/` no commit `21c004b` (diff `f55bcab..21c004b`). Nada foi compilado. Os exemplos do G18 e do G19 são linhas de `assets/catalog/catalogo.sqlite`, consultadas só para leitura. As contagens (itens sem tamanho, leite em pó sem tamanho, unidades por tipo de produto, itens em "un" com g ou ml na quantidade) vêm de consultas no mesmo arquivo.

Referências externas:

- [Android Developers: backup automático dos dados do app](https://developer.android.com/identity/data/autobackup)
