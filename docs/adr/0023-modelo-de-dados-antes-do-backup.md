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
  - `manifest.json`: versão do formato (1), `schemaVersion`, versão do app, data, contagem de linhas por tabela e o SHA-256 do banco;
  - `bipa.sqlite`: uma cópia consistente do banco, feita com `VACUUM INTO`;
  - `fotos/`: só as fotos que algum `photo_path` cita.
- **O banco vai inteiro, como SQLite, e não como JSON.** As migrações do Drift já levam qualquer versão antiga até a atual, então restaurar num esquema mais novo é abrir o arquivo e deixar a migração rodar. Um JSON seria um segundo formato para migrar.
- **Esquema mais novo que o do app:** a restauração recusa e pede para atualizar o app. Ela confere o `schemaVersion` do manifesto e o `user_version` do arquivo antes de abrir.
- **Restaurar substitui, não junta.** O estado depois da restauração é o do backup, e restaurar o mesmo arquivo duas vezes dá o mesmo resultado. Juntar dados de dois aparelhos é trabalho da sincronização, não do backup.
- **Nada é trocado antes de tudo ser conferido.** A restauração:
  1. confere o manifesto e o hash;
  2. copia o banco para uma pasta temporária e roda nele `PRAGMA integrity_check`, a migração e `PRAGMA foreign_key_check`;
  3. confere que a soma dos lotes é a quantidade de cada item em casa (ADR 0013);
  4. guarda o banco atual como reserva, para desfazer;
  5. fecha o banco do app, troca os arquivos com `rename` e reabre.
- **`synced_at` fica como estava no backup.** Com servidor, o envio é idempotente por UUID, e uma observação reenviada não se repete. Restaurar um backup antigo não apaga nada no servidor, porque não cria marcas de exclusão.
- **O backup é privado e completo:** estoque, lista, compras e os mercados com coordenadas. Ele vai para onde a pessoa escolher, pelo seletor de arquivos do Android, e nunca para um servidor nosso.
- **O Auto Backup do Android:** na revisão, o manifesto não declarava `android:allowBackup`, então ele estava ligado por padrão. Com o backup do Google ligado no aparelho, o Android podia copiar os arquivos do app, o banco e as fotos inclusive, para o Google Drive da pessoa (até 25 MB) e para o aparelho novo numa troca, sem passar pela validação acima. A lacuna B1 declarou no manifesto que ele leva só o backup mais recente.
- **Onde fica o backup mais recente:** além do arquivo que a pessoa salva pelo seletor, o app guarda uma cópia do último backup em `backup/ultimo.bipa`, na pasta de suporte do app (`getApplicationSupportDirectory`, `files/` no Android), com nome fixo: cada backup novo substitui o anterior. O caminho está em `latestBackupPath` (`lib/core/backup/latest_backup.dart`). Ele fica fora da pasta de documentos (`app_flutter/`), onde estão o banco e as fotos. O backup do Google aceita até 25 MB por app: um `.bipa` maior que isso, por causa das fotos, não sobe, e a pessoa continua com o arquivo que salvou pelo seletor.

### 6. O catálogo pronto fica fora dos dados da pessoa

- O catálogo de produtos brasileiros (ADR 0024) é um arquivo só de leitura, que vem com o app, separado do `bipa.sqlite`. Ele não entra no backup, porque vem com o app, e não é sincronizado.
- Bipar um código do catálogo cria a embalagem (e, se preciso, o produto) na base da pessoa, como cópia: editar não muda o catálogo, e atualizar o catálogo não muda o que a pessoa já tem.
- A embalagem guarda de onde veio (lacuna C1), para a tela citar a fonte e para a sincronização saber o que tem licença de terceiros.

### 7. Lacunas a corrigir

**Antes do backup (fase 1):**

- **B1.** `android/app/src/main/AndroidManifest.xml`: declarar `android:allowBackup="true"` com `android:dataExtractionRules` (Android 12+) e `android:fullBackupContent` que incluam só o arquivo `.bipa` mais recente, e deixem de fora o banco e `fotos/`. Assim, a troca de celular restaura pelo nosso formato, já validado. Decisão do mantenedor em 28/10.
  - **Feita** (commit `<B1>`): o manifesto declara as três coisas, e as regras (`res/xml/data_extraction_rules.xml` para a nuvem e a troca de aparelho, `res/xml/backup_rules.xml` até o Android 11) incluem só `files/backup/ultimo.bipa` (seção 5). Com um `<include>`, o Android deixa todo o resto de fora, então não há `<exclude>` para o banco e as fotos: o lint do Android recusa excluir o que não está incluído. O teste `test/core/backup/latest_backup_test.dart` confere que as regras citam o mesmo caminho que o app usa. Falta conferir num aparelho (`adb shell bmgr backupnow`) quando o backup próprio gravar o arquivo.
- **B2.** `products.photo_path`: apagar o produto (`DriftProductRepository.delete`) e o "Juntar com…" não apagam o arquivo da foto. Apagar o arquivo junto ou limpar as órfãs ao fazer o backup.
  - **Feita** (commit `<B2>`): apagar e juntar apagam o arquivo junto, depois que a transação do banco termina (se ela falha, a foto fica). No "Juntar com…", sai a foto do produto que deixa de existir, e o que fica mantém a sua. Uma foto que outro produto ainda cita não é apagada. O repositório usa o contrato `ProductPhotoFiles`, do domínio, e o app passa `DirectoryProductPhotoFiles`, que só apaga dentro de `fotos/`. Se o arquivo não puder ser apagado, ele fica órfão: o backup já leva só as fotos que algum `photo_path` cita (seção 5), então não é preciso limpar as órfãs ali. Trocar a foto de um produto ainda não existe no app (ADR 0010); quando existir, a foto antiga precisa sair do mesmo jeito.
- **B3.** O esquema de cada versão guardado no repositório: hoje o teste de migração simula as versões antigas tirando colunas (`migration_test.dart`, da v8 em diante). Começar a guardar o esquema de cada versão com `drift_dev schema dump`, a partir da versão em que o backup entrar, para cada backup possível ter teste de migração com o esquema real.
  - **Feita** (commit `<B3>`): o esquema 14, o atual, está em `drift_schemas/drift_schema_v14.json`, e as classes de teste geradas dele em `test/core/database/schemas/`. O backup ainda não existe, então ele vai entrar no 14 ou depois, e nenhum backup possível fica sem esquema guardado. Em `migration_test.dart`, três testes novos: o banco que o app cria é igual ao esquema guardado da versão atual (falha se as tabelas mudarem sem dump novo), cada versão guardada migra até a atual e chega ao esquema dela, e dados gravados no esquema 14 real são lidos pelo app atual. Os testes da v8 à v14, que simulam as versões antigas tirando colunas, ficam. O passo a passo para a próxima versão está em `docs/contribuindo.md`.
- **B4.** Nomes de enum e o JSON de `trip_prices.other_offers` fazem parte do formato do arquivo: `products.unit`, `product_packages.unit`, `price_observations.condition_kind` e `source`, `stock_items.location`, `stock_movements.reason`, `market_aisles.aisle` e `remembered_locations.location` gravam o nome do valor. Renomear um valor ou uma chave do JSON exige migração. Escrever essa regra no cabeçalho de `tables.dart`, onde hoje só o `Aisle` a menciona.
- **B5.** O serviço de backup e restauração descrito na seção 5, com teste: backup e restauração ida e volta; restauração de um arquivo de versão antiga; recusa de versão mais nova; arquivo corrompido não muda nada.

**Com o catálogo (fase 1):**

- **C1.** `product_packages`: uma coluna `origin` (`person`, `catalog`), ou o id da fonte, para a atribuição e a licença (ADR 0024).
- **C2.** `products`: o tipo do produto hoje é deduzido do nome (`ProductKind.of`). O catálogo traz a categoria, e uma coluna nula `kind` guardaria a escolha quando ela não vier do nome. É opcional: o nome sugerido pelo catálogo pode bastar para a dedução.

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
