# 0023. Fechar o modelo de dados antes do backup

- Status: Aceito
- Data: 2026-10-28

Em 28/10, o mantenedor decidiu manter o Auto Backup do Android ligado, mas só com o arquivo `.bipa` mais recente (lacuna B1).

## Contexto

O roadmap pede um backup e restauração local do banco na fase 1 e, antes dele, uma revisão do modelo de dados: tabelas, ids, o que é privado e o que sincroniza, o que pode ser apagado, e o catálogo pronto separado dos dados da pessoa. Um backup congela o formato. Depois que houver arquivos de backup no celular das pessoas, cada mudança de esquema precisa continuar abrindo todos eles.

O ADR 0007 deu as regras para a sincronização da fase 2: UUID gerado no aparelho, `synced_at` nas tabelas compartilháveis, observações de preço imutáveis, estoque e lista privados. Desde então, outros ADRs abriram exceções ou acrescentaram tabelas:

- 0013: o "Juntar com…" troca o `product_id` das observações do produto que some;
- 0016: apagar produto ou mercado apaga, em cascata, as observações deles;
- 0017: uma observação corrige outra por `supersedes_id`, sem chave estrangeira;
- 0020 e 0021: `trip_prices` e `remembered_locations`, privadas.

O esquema está na versão 14, com 14 tabelas (`lib/core/database/tables.dart`). Esta revisão foi feita no código de 28/10/2026, conferindo as tabelas, as migrações e os repositórios contra o ADR 0007 e a fase 2 do roadmap.

O que a revisão achou, em resumo: as regras do ADR 0007 se mantêm, mas há dados privados em tabela compartilhável, mudanças em observações que não voltam para a fila, exclusões sem rastro, fotos órfãs, e o Auto Backup do Android ligado sem que ninguém tenha decidido isso.

## Decisão

### 1. O que é compartilhável e o que é privado

Uma tabela é **compartilhável** quando a fase 2 pode enviá-la à base comunitária. Ela tem UUID, `created_at` e `synced_at` e, se puder ser editada, `updated_at`. Uma tabela **privada** nunca sai do aparelho (só no backup da própria pessoa) e não tem `synced_at`. Uma coluna privada não fica numa tabela compartilhável, como já decidido para o local lembrado (ADR 0021).

| Tabela | Classe | Observações |
| --- | --- | --- |
| `products` | Compartilhável, menos `photo_path` | O nome é o da pessoa ("Arroz branco", ADR 0013). A foto é privada (ADR 0010), mas o caminho dela está nesta tabela (lacuna S3). |
| `product_packages` | Compartilhável | Código, marca e tamanho. É a parte do modelo mais próxima de um catálogo. |
| `markets` | Compartilhável | Nome, endereço e coordenadas de um lugar público. |
| `price_observations` | Compartilhável, com cuidado | O mercado com o horário exato forma uma trilha de onde a pessoa esteve. O envio arredonda o horário (lacuna S6). |
| `stock_items`, `stock_lots`, `stock_movements` | Privadas | O que há em casa e o ritmo de consumo. |
| `shopping_list_items`, `shopping_trips`, `cart_items`, `trip_prices` | Privadas | A lista, as compras e o carrinho. |
| `remembered_locations` | Privada | ADR 0021. |
| `market_aisles`, `scale_items` | Privadas por enquanto | São dados do mercado, não da pessoa, e podem vir a ser comunitários (ADR 0014). Ficam privadas até um ADR de sincronização dizer como enviá-las sem expor as compras de ninguém. |

### 2. Chaves

- Toda entidade tem UUID v4 em texto, gerado no aparelho (`UuidGenerator`). As tabelas de estado privadas usam chave natural: `stock_items` e `remembered_locations` por produto, `market_aisles` por mercado e seção, `scale_items` por mercado e código da balança, `trip_prices` por compra e item. A revisão confirmou isso nas 14 tabelas.
- **Um id não é único entre tabelas.** A migração v7 deu à embalagem o mesmo id do produto de onde ela saiu. Todo registro que aponte para "uma entidade qualquer", como uma marca de exclusão, guarda a tabela junto com o id.
- **O código de barras é a chave natural da embalagem fora do aparelho.** `product_packages.barcode` é único no banco local, mas dois aparelhos podem criar o mesmo código com UUIDs diferentes. A sincronização vai resolver isso pelo código (como um "Juntar"), não pelo UUID. Etiquetas da balança nunca viram embalagem (ADR 0018).
- `supersedes_id` e `trip_prices.observation_id` não têm chave estrangeira (ADR 0017 e 0020) e podem apontar para uma observação que não existe mais. Quem lê essas colunas tolera isso.

### 3. Carimbos de tempo

- Sem `build.yaml`, o Drift grava `DateTime` como inteiro Unix em **segundos**. O valor é absoluto e não depende de fuso. Fica assim: trocar para texto ISO-8601 exigiria migrar todas as colunas de data, e nenhuma regra depende de menos de um segundo.
- Onde a ordem importa e dois registros caem no mesmo segundo, o desempate é por uma coluna gravada, nunca pela ordem física. O `rowid` não serve, porque o `VACUUM INTO` do backup pode renumerá-lo. Hoje os lotes desempatam pelo id (`stock_lots.since`, depois `id`): a ordem é estável, embora arbitrária dentro do segundo, e passa intacta por um backup.
- O que cada carimbo quer dizer:
  - `created_at`: quando o registro nasceu neste aparelho;
  - `updated_at`: a última edição feita pela pessoa. A sincronização não mexe nele;
  - `observed_at`: quando o preço foi visto. Pode ser anterior ao `created_at` (ADR 0017 e 0020);
  - `synced_at`: quando o servidor confirmou o envio. Nulo quer dizer pendente. "Pendente" nunca sai de comparar `updated_at` com `synced_at`.
- O relógio do aparelho pode estar errado. Localmente, ele vale. O servidor vai guardar a própria hora de recebimento ao lado.

### 4. Observações de preço: as exceções admitidas

- **Admitidas:** a troca de `product_id` no "Juntar com…", que zera o `synced_at` (ADR 0013), e a exclusão em cascata com o produto ou o mercado (ADR 0016), que na fase 2 precisa de marca de exclusão.
- **Não admitida, e existente hoje:** `price_observations.package_id` tem `ON DELETE SET NULL`. Quando uma embalagem for apagada (G2), as observações dela mudam sem voltar para a fila. É a lacuna S4, e o ADR do G2 precisa resolvê-la.

### 5. Backup e restauração local

- **Formato:** um arquivo `.bipa`, que é um zip com:
  - `manifest.json`: versão do formato (1), um id, `schemaVersion`, versão do app, data, contagem de linhas por tabela, um resumo (produtos, preços e itens em casa, para a tela mostrar sem abrir o banco) e o SHA-256 e o tamanho do banco e de cada foto;
  - `bipa.sqlite`: uma cópia consistente do banco, feita com `VACUUM INTO`;
  - `fotos/`: só as fotos que algum `photo_path` cita.
- **O banco vai inteiro, como SQLite, e não como JSON.** As migrações do Drift já levam qualquer versão antiga até a atual, então restaurar num esquema mais novo é abrir o arquivo e deixar a migração rodar. Um JSON seria um segundo formato para migrar.
- **Esquema mais novo que o do app:** a restauração recusa e pede para atualizar o app. Ela confere o `schemaVersion` do manifesto e o `user_version` do arquivo antes de abrir.
- **Restaurar substitui, não junta.** O estado depois da restauração é o do backup, e restaurar o mesmo arquivo duas vezes dá o mesmo resultado. Juntar dados de dois aparelhos é trabalho da sincronização, não do backup.
- **Nada é trocado antes de tudo ser conferido.** A restauração:
  1. confere o manifesto e o hash;
  2. copia o banco para uma pasta temporária e roda nele `PRAGMA integrity_check`, a migração e `PRAGMA foreign_key_check`;
  3. confere que a soma dos lotes é a quantidade de cada item em casa (ADR 0013). Onde não é, os lotes valem: a quantidade passa a ser a soma deles (um produto com lotes e sem item ganha o item, na despensa), na cópia em conferência, e a folha de confirmação diz quantos itens mudaram ("2 itens tiveram a quantidade acertada"). Decisão do mantenedor em 29/10: antes, este passo recusava o backup, mas a diferença tem conserto e o resto dos dados está bom;
  4. guarda o banco atual como reserva, para desfazer;
  5. fecha o banco do app, troca os arquivos com `rename` e reabre.
- **`synced_at` fica como estava no backup.** Com servidor, o envio é idempotente por UUID, e uma observação reenviada não se repete. Restaurar um backup antigo não apaga nada no servidor, porque não cria marcas de exclusão.
- **O backup é privado e completo:** estoque, lista, compras e os mercados com coordenadas. Ele vai para onde a pessoa escolher, pelo seletor de arquivos do Android, e nunca para um servidor nosso.
- **O Auto Backup do Android:** na revisão, o manifesto não declarava `android:allowBackup`, então ele estava ligado por padrão. Com o backup do Google ligado no aparelho, o Android podia copiar os arquivos do app, o banco e as fotos inclusive, para o Google Drive da pessoa (até 25 MB) e para o aparelho novo numa troca, sem passar pela validação acima. A lacuna B1 declarou no manifesto que ele leva só o backup mais recente.
- **Onde fica o backup mais recente:** além do arquivo que a pessoa salva pelo seletor, o app guarda uma cópia do último backup em `backup/ultimo.bipa`, na pasta de suporte do app (`getApplicationSupportDirectory`, `files/` no Android), com nome fixo: cada backup novo substitui o anterior. O caminho está em `latestBackupPath` (`lib/core/backup/latest_backup.dart`). Ele fica fora da pasta de documentos (`app_flutter/`), onde estão o banco e as fotos. O backup do Google aceita até 25 MB por app: um `.bipa` maior que isso, por causa das fotos, não sobe, e a pessoa continua com o arquivo que salvou pelo seletor.
- **O backup de outro aparelho espera resposta, sem prazo** (decisões do mantenedor em 29/10, BK1): o `ultimo.bipa` que o Auto Backup trouxe de outro celular fica restaurável até a pessoa responder, mesmo com a casa já em uso, pelo Início e pela linha "Último backup" de Ajustes. Enquanto isso, o backup diário fica pausado (e Ajustes diz isso), "Fazer backup agora" só grava por cima depois de "Apagar o backup do outro celular?", e "Salvar uma cópia…" grava só a cópia. Restaurar, gravar por cima com a confirmação ou deixar de lado é a resposta; depois dela, o diário volta. Detalhes na lacuna B5.
- **A confirmação mostra o que se perde** (BK3): os mesmos três números do arquivo e do celular, a data com o ano e, quando o arquivo é mais velho que o último preço ou compra do celular, a linha "Os preços e as compras depois de 12/10/2025 saem deste celular."

### 6. O catálogo pronto fica fora dos dados da pessoa

- O catálogo de produtos brasileiros (ADR 0024) é um arquivo só de leitura, que vem com o app, separado do `bipa.sqlite`. Ele não entra no backup, porque vem com o app, e não é sincronizado.
- Bipar um código do catálogo cria a embalagem (e, se preciso, o produto) na base da pessoa, como cópia: editar não muda o catálogo, e atualizar o catálogo não muda o que a pessoa já tem.
- A embalagem guarda de onde veio (lacuna C1), para a tela citar a fonte e para a sincronização saber o que tem licença de terceiros.

### 7. Lacunas a corrigir

**Antes do backup (fase 1):**

- **B1.** `android/app/src/main/AndroidManifest.xml`: declarar `android:allowBackup="true"` com `android:dataExtractionRules` (Android 12+) e `android:fullBackupContent` que incluam só o arquivo `.bipa` mais recente, e deixem de fora o banco e `fotos/`. Assim, a troca de celular restaura pelo nosso formato, já validado. Decisão do mantenedor em 28/10.
  - **Feita** (commit `bf9b767`): o manifesto declara as três coisas, e as regras (`res/xml/data_extraction_rules.xml` para a nuvem e a troca de aparelho, `res/xml/backup_rules.xml` até o Android 11) incluem só `files/backup/ultimo.bipa` (seção 5). Com um `<include>`, o Android deixa todo o resto de fora, então não há `<exclude>` para o banco e as fotos: o lint do Android acusa um `<exclude>` fora do caminho incluído. O teste `test/core/backup/latest_backup_test.dart` confere que as regras citam o mesmo caminho que o app usa. Falta conferir num aparelho (`adb shell bmgr backupnow`) quando o backup próprio gravar o arquivo.
- **B2.** `products.photo_path`: apagar o produto (`DriftProductRepository.delete`) e o "Juntar com…" não apagam o arquivo da foto. Apagar o arquivo junto ou limpar as órfãs ao fazer o backup.
  - **Feita** (commit `9c8d837`): apagar e juntar apagam o arquivo junto, depois que a transação do banco termina (se ela falha, a foto fica). No "Juntar com…", sai a foto do produto que deixa de existir, e o que fica mantém a sua. Uma foto que outro produto ainda cita não é apagada. O repositório usa o contrato `ProductPhotoFiles`, do domínio, e o app passa `DirectoryProductPhotoFiles`, que só apaga dentro de `fotos/`. Se o arquivo não puder ser apagado, ele fica órfão: o backup já leva só as fotos que algum `photo_path` cita (seção 5), então não é preciso limpar as órfãs ali. Trocar a foto de um produto ainda não existe no app (ADR 0010); quando existir, a foto antiga precisa sair do mesmo jeito.
- **B3.** O esquema de cada versão guardado no repositório: hoje o teste de migração simula as versões antigas tirando colunas (`migration_test.dart`, da v8 em diante). Começar a guardar o esquema de cada versão com `drift_dev schema dump`, a partir da versão em que o backup entrar, para cada backup possível ter teste de migração com o esquema real.
  - **Feita** (commit `745b056`): o esquema 14, o atual, está em `drift_schemas/drift_schema_v14.json`, e as classes de teste geradas dele em `test/core/database/schemas/`. O backup ainda não existe, então ele vai entrar no 14 ou depois, e nenhum backup possível fica sem esquema guardado. Em `migration_test.dart`, três testes novos: o banco que o app cria é igual ao esquema guardado da versão atual (falha se as tabelas mudarem sem dump novo), cada versão guardada migra até a atual e chega ao esquema dela, e dados gravados no esquema 14 real são lidos pelo app atual. Os testes da v8 à v14, que simulam as versões antigas tirando colunas, ficam. O passo a passo para a próxima versão está em `docs/contribuindo.md`.
- **B4.** Nomes de enum e o JSON de `trip_prices.other_offers` fazem parte do formato do arquivo: `products.unit`, `product_packages.unit`, `price_observations.condition_kind` e `source`, `stock_items.location`, `stock_movements.reason`, `market_aisles.aisle` e `remembered_locations.location` gravam o nome do valor. Renomear um valor ou uma chave do JSON exige migração. Escrever essa regra no cabeçalho de `tables.dart`, onde hoje só o `Aisle` a menciona.
  - **Feita** (commit `36c8da4`): a regra está nas convenções do começo de `tables.dart`, com as nove colunas (a revisão tinha deixado de fora `trip_prices.source`), e no `PriceOffersConverter`. O teste `test/core/database/stored_names_test.dart` fixa os nomes de cada enum gravado e as chaves do JSON, nos dois sentidos: o que o app grava hoje e a leitura de um JSON já gravado. Acrescentar um valor não exige migração, mas um app mais antigo não o lê: a restauração (B5) precisa contar com isso ao abrir um backup de um app mais novo com o mesmo esquema.
- **B5.** O serviço de backup e restauração descrito na seção 5, com teste: backup e restauração ida e volta; restauração de um arquivo de versão antiga; recusa de versão mais nova; arquivo corrompido não muda nada.
  - **Feita: o serviço** (commits `6ee09bc`, `adf320d`, `8af815c` e `b006765`) **e a tela** (29/10), nos quadros AjustesBackup, RestaurarBackup, RestaurarBackupResultado e InicioBackupEncontrado do protótipo: o grupo "Backup" no topo de Ajustes (`BackupSettingsCard`), a folha de restauração (`RestoreSheet`) e o cartão do celular novo no Início (`RestoreOfferCard`), em `lib/features/backup/presentation/`. O "Salvar como" e o "Abrir" do Android (Storage Access Framework, `ACTION_CREATE_DOCUMENT` e `ACTION_OPEN_DOCUMENT`) passam por um canal com o `MainActivity` (`BackupFiles.kt`), sem plugin: os bytes vão por arquivos do app, copiados numa thread nativa. Depois de restaurar ou desfazer, o cache de imagens é limpo, porque as fotos novas têm o mesmo caminho.
  - **Onde está:** `lib/features/backup/` (domínio, `data/` e o `backupProvider` em `presentation/backup_providers.dart`) e, em `lib/core/backup/app_data_swap.dart`, a troca dos arquivos. O zip usa o pacote `archive` (Dart puro, o mais usado do pub.dev), e os hashes, o `crypto`, que já vinha com outros pacotes. O zip, os hashes e as conferências rodam em isolates. O banco vai comprimido; as fotos, que já são JPEG, não.
  - **Quando o `ultimo.bipa` é gravado sozinho** (decisão do mantenedor em 29/10): uma vez por dia, na primeira abertura do app no dia ou ao voltar para ele (`lib/app/daily_backup.dart`), sem WorkManager e sem gravar com o app no fundo. O backup diário não grava com o banco vazio, para um app recém-instalado não pôr um backup vazio no lugar do que o Auto Backup trouxe, nem no Google Drive.
  - **O `ultimo.bipa` de outro aparelho** (decisões do mantenedor em 29/10, BK1): ao lado dele, `backup/ultimo.id` guarda o id do último backup feito (ou adotado) neste aparelho. O Auto Backup leva só o `ultimo.bipa`, então num celular novo o id não bate, e o arquivo fica **pendente**: restaurável até a pessoa responder, **sem prazo e mesmo com a casa já em uso** (`RestoreOffer` não depende mais do banco vazio). Enquanto ele está pendente:
    - o **backup diário fica pausado** (não grava), e Ajustes diz isso embaixo de "Fazer backup agora": "Automático pausado até você decidir";
    - a linha "Último backup" de Ajustes vira botão ("De outro celular. Toque para restaurar.", com o dia e o ano) e abre a folha de restaurar com esse arquivo, sem o seletor do Android, que não vê a pasta do app;
    - **"Fazer backup agora" pergunta antes** ("Apagar o backup do outro celular?", com a data, os números e "não volta mais"); confirmado, grava por cima (`CreateBackup` com `replacePending`). Um banco vazio não toma o lugar dele nem com a confirmação;
    - **"Salvar uma cópia…" grava só a cópia** que a pessoa leva, sem tocar no `ultimo.bipa`;
    - o Início mostra o cartão: com a casa vazia, o "Backup encontrado" (InicioBackupEncontrado); com a casa em uso, um menor (InicioBackupPendente), com "Restaurar", sempre pela folha de confirmação, e "Deixar de lado".
  - **A resposta** é restaurar (qualquer arquivo adota o `ultimo.bipa`), gravar por cima com a confirmação, ou "Começar do zero"/"Deixar de lado", que adota o arquivo quando o aviso com Desfazer sai: a oferta some, Ajustes volta ao de sempre e o próximo backup diário grava por cima. As datas têm o ano sempre que o backup é de outro celular, e na folha de confirmação.
  - **Restaurar é em dois tempos**, como na folha do protótipo: `prepare` faz os passos 1 a 3 numa cópia em `restauracao/novo/` e devolve o resumo do backup e o do aparelho; só depois da confirmação, `apply` faz os passos 4 e 5. A troca grava uma marca em `restauracao/troca` antes de mover qualquer arquivo; se o app fechar no meio, a abertura seguinte do banco devolve os arquivos antigos. Além do passo 3, a conferência compara as contagens do manifesto com o banco, e lê cada linha de cada tabela pelo app: um nome de enum ou chave de JSON que ele não conhece (B4) recusa o backup como "de uma versão mais nova", com o mesmo aviso de um esquema mais novo.
  - **Desfazer** (decisão do mantenedor em 29/10; prazo preso ao aviso em 29/10, BK2): a reserva do passo 4 fica em `restauracao/reserva/` enquanto o aviso com "Desfazer" está na tela. Não há relógio próprio: o aviso segue a regra do tempo do `bipa-toast` (10 s no "longo"; com TalkBack espera a pessoa; estica com o "Tempo para agir" do Android; para com o dedo em cima), e a reserva só é descartada quando ele sai sem o "Desfazer" (o tempo acabou, a pessoa o dispensou ou outro aviso tomou o lugar), ou na primeira abertura do banco na execução seguinte do app. A reabertura logo depois de restaurar não a apaga. Sem "Desfazer" a oferecer (o cartão do celular novo com a casa vazia), a reserva sai na hora.
  - **"Salvar uma cópia…"** grava um backup novo no destino que o seletor do Android devolver (`StreamConsumer`), e o mesmo arquivo vira o `ultimo.bipa`. A restauração também aceita o arquivo como fluxo de bytes, além do caminho.
  - **"Começar do zero" e "Deixar de lado"** (decisão do mantenedor em 29/10): o cartão sai na hora, com o Desfazer do aviso (`BipaToastDuration.long`), e o `ultimo.bipa` só é adotado quando o aviso sai sem o Desfazer; até lá ele segue pendente, e Ajustes ainda o restaura. O aviso de "Deixar de lado" diz o que vem depois: "Backup de 12/10/2026 deixado de lado. O próximo grava por cima." Se o app fechar antes, a oferta volta na abertura seguinte, e nada se perde.
  - **A confirmação da restauração** (BK3, decisão do mantenedor em 29/10) mostra os mesmos três números dos dois lados (produtos, preços e itens em casa) e a data com o ano. Quando o arquivo é mais velho que os dados deste celular, uma linha própria diz o que sai ("Os preços e as compras depois de 12/10/2025 saem deste celular."). "Mais velho" é a data do backup contra o registro mais recente de preço ou compra do banco atual (`BackupDatabase.latestActivity`: a observação de preço, a ida ao mercado ou a entrada em casa com motivo compra).
  - **Testes:** `test/features/backup/backup_test.dart` (ida e volta com fotos, idempotência, desfazer, esquema 14 guardado, um esquema mais antigo migrado, recusa de esquema, `user_version` e formato mais novos, valor de enum desconhecido, arquivo que não é zip, cortado, sem manifesto, manifesto inválido, foto com caminho para fora, hash, foto faltando, banco que não é SQLite, contagens e chave estrangeira, sempre sem mudar nada, a quantidade acertada pela soma dos lotes, e o `ultimo.bipa` intacto quando um backup falha no meio), `test/core/backup/app_data_swap_test.dart` (a troca interrompida em cada ponto) e `test/features/backup/backup_controller_test.dart` (os providers recarregam depois de restaurar; o backup de outro celular pendente, o diário pausado, "Deixar de lado" com Desfazer e gravar por cima só com a confirmação). A tela, em `test/features/backup/presentation/` (o grupo de Ajustes, a cópia com o seletor falso, a restauração com a conferência e a troca falsas, os dois erros, o Desfazer, a linha do backup de outro celular que restaura, o diálogo de gravar por cima, a linha do que sai, e os dois cartões do Início) e em `test/accessibility/large_text_test.dart` (o grupo, o grupo com o backup pendente e o diálogo, as folhas e os dois cartões com letra a 200%).
  - **A conferir num aparelho:** o `VACUUM INTO` e o isolate da conferência com o SQLite do `sqlite3_flutter_libs`, o tempo com muitas fotos, o `adb shell bmgr backupnow` da B1, a restauração numa troca de celular de verdade, e o seletor do Android salvando e abrindo no Drive e numa pasta local.

**Com o catálogo (fase 1):**

- **C1.** `product_packages`: uma coluna `origin` (`person`, `catalog`), ou o id da fonte, para a atribuição e a licença (ADR 0024).
  - **Feita** (commit `53b741d`, esquema 15): `product_packages.origin` guarda a base de onde vieram os dados, não só "catálogo": `person`, `openFoodFacts`, `openProductsFacts` ou `openBeautyFacts` (`PackageOrigin`). Assim a tela do produto cita a base certa, e a sincronização sabe qual licença vale. As embalagens anteriores ao esquema 15 são `person`. Uma embalagem do catálogo que a pessoa corrigiu, ou moveu para outro produto, continua com a origem do catálogo: na dúvida, o dado tem licença de terceiros. O nome do valor é gravado (B4) e está no `stored_names_test.dart`.
  - **O catálogo no app** (commits `cba4a23`, `c484a6a` e `3ba6c96`): o `ProductCatalog` (`lib/features/products/domain/product_catalog.dart`) lê o `catalogo.sqlite`, copiado do asset para `catalogo/` na pasta de suporte na primeira consulta de cada versão do app e aberto só para leitura, numa conexão à parte. Sem o asset, o catálogo é vazio. A folha "Embalagem nova" procura nele antes de sugerir pela etiqueta e vem preenchida; a tela do produto cita a fonte abaixo das embalagens. O `catalogAttributionProvider` traz o aviso de `catalog_meta` para a tela "Sobre".
- **C2.** `products`: o tipo do produto hoje é deduzido do nome (`ProductKind.of`). O catálogo traz a categoria, e uma coluna nula `kind` guardaria a escolha quando ela não vier do nome. É opcional: o nome sugerido pelo catálogo pode bastar para a dedução.
  - **Não feita, por ora:** a categoria do catálogo só desempata a escolha do produto da pessoa (`PackageSuggestion.fromCatalog`). O nome sugerido ("Arroz branco") continua dando o tipo pela dedução.

**Antes da sincronização (fase 2), registradas agora para não se perderem:**

- **S1.** Marcas de exclusão: uma tabela `deletions` (tabela, id, `deleted_at`, `synced_at`), gravada na mesma transação em que se apaga um produto, uma embalagem, um mercado ou as observações em cascata (ADR 0016).
- **S2.** O "Juntar com…" como evento: uma tabela `product_merges` (id, `from_id`, `into_id`, `merged_at`, `synced_at`), para outros aparelhos e o servidor refazerem a troca (ADR 0013).
- **S3.** `products.photo_path` sai para uma tabela privada (`product_photos`), ou fica fora do envio. Hoje trocar a foto zera o `synced_at` do produto (`ProductCompanionMapper`) e reenviaria o produto por uma mudança privada.
- **S4.** `price_observations.package_id ON DELETE SET NULL`: ao apagar uma embalagem (G2), as observações dela vão junto, com marca de exclusão, ou passam para outra embalagem como uma correção. Nunca mudam sem voltar para a fila.
- **S5.** Produtos sem código (granel e pesagens) não têm chave natural fora do aparelho. O ADR de sincronização decide como um "tomate" de duas pessoas vira o mesmo produto, ou se não vira.
- **S6.** O envio de `price_observations` arredonda o `observed_at` (por exemplo, para o dia) e não leva nenhum id do aparelho ou da compra, para não formar trilha (ADR 0007). Localmente, a precisão continua a de segundos.
- **S7.** `stock_items.minimum_quantity` é o "ter sempre" (`targetQuantity`) e tem o mesmo nome da coluna de atacado de `price_observations`. Renomear para `target_quantity` na próxima migração que mexer nessa tabela. É opcional.

## Consequências

- O backup pode ser feito sem esperar a fase 2: só B1 a B5 são pré-requisito.
- O formato do backup é o próprio banco, então cada migração nova já é, por construção, a migração dos backups antigos. O custo é manter os testes de migração com o esquema real de cada versão (B3).
- Restaurar é trocar tudo. Quem quiser juntar dois aparelhos espera a sincronização.
- As lacunas S1 a S7 não bloqueiam o backup, mas mudam o esquema. Cada uma entra numa migração com teste, e o backup feito antes dela continua abrindo.
- O que é compartilhável fica explícito antes de existir servidor, e o ADR de sincronização parte desta tabela em vez de redescobri-la.
