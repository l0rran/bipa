# Como contribuir

## Ambiente

- Flutter estável **3.47 ou mais novo** (rode `flutter upgrade`), JDK 17 ou mais novo e Android SDK. Confira com `flutter doctor`.
- O build Android usa Gradle 9.3.1, Android Gradle Plugin 9.1.0 e Kotlin 2.4.0. As flags `android.builtInKotlin` e `android.newDsl` ficam em `false` em `android/gradle.properties` até todos os plugins (câmera, ML Kit, localização) migrarem para o Kotlin embutido do AGP 9. Se o Flutter avisar que um plugin ainda aplica o Kotlin Gradle Plugin, isso é esperado por enquanto.
- No Windows, use o terminal do próprio Windows (PowerShell ou VS Code), não o WSL, para o emulador aparecer.

```bash
flutter pub get                  # também gera os textos (lib/core/l10n/app_localizations*.dart)
dart run build_runner build -d   # gera o código do Drift, Riverpod e freezed
flutter run
```

Na primeira execução depois da atualização, o banco migra sozinho para o esquema 2 (fotos dos produtos).

Durante o desenvolvimento, deixe `dart run build_runner watch -d` rodando num terminal à parte.

O emulador não tem câmera de verdade. Para testar a leitura de código e de etiqueta nele, use a câmera virtual com as imagens de [`tool/kit_emulador`](../tool/kit_emulador/README.md).

## Antes de cada commit

```bash
dart format .
flutter analyze
flutter test
```

Os três precisam passar. Código gerado (`*.g.dart`, `*.freezed.dart` e os arquivos do `gen-l10n`) não é versionado.

## Mudança no esquema do banco

Um backup `.bipa` é o próprio banco, então todo esquema que já existiu precisa continuar abrindo (ADR 0023). Do esquema 14 em diante, o esquema de cada versão fica guardado em `drift_schemas/`, e o teste de migração parte dele. Ao mudar as tabelas:

1. suba o `schemaVersion` em `lib/core/database/app_database.dart` e escreva o passo em `onUpgrade`;
2. rode `dart run build_runner build -d`;
3. guarde o esquema novo e gere as classes de teste (as duas saídas são versionadas):

```bash
dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/drift_schema_v15.json
dart run drift_dev schema generate drift_schemas/ test/core/database/schemas/
```

4. em `test/core/database/migration_test.dart`, escreva um teste que grave dados no esquema anterior e confira o que eles viram no novo, como o `v14 → atual`.

Sem o passo 3, o teste "o esquema que o app cria é o guardado para a versão atual" falha. Um esquema guardado nunca é editado nem apagado.

## Design system no código

- **Cores, espaçamentos, raios e movimento** vêm de `design/tokens.json`, a mesma fonte do design system no Claude. Depois de mudar o arquivo, rode `dart run tool/generate_tokens.dart`, que reescreve `lib/core/design_system/bipa_palette.dart` e `bipa_metrics.dart`. Não edite esses dois à mão. O teste `test/core/design_system/bipa_palette_test.dart` falha se algum par de texto ficar abaixo de 4,5:1.
- **Nos widgets**, cores só pelo tema (`context.colors.brand`, `context.colors.alert`...), textos de `BipaText` e medidas de `BipaSpacing` e `BipaRadius`. Nada de `Color(0xFF...)` fora da paleta (ADR 0009).
- **Componentes** ficam em `lib/core/design_system/components/` e não importam nada de `features/`: a tela converte o domínio para o que o componente desenha (veja `stock_display.dart`).
- **Fontes:** Manrope, Figtree e JetBrains Mono estão em `assets/fonts/`, em arquivos estáticos por peso, com as licenças OFL ao lado.

## Textos

Todo texto visível ao usuário fica em `lib/core/l10n/app_pt.arb` e é lido com `AppLocalizations.of(context)`. As telas antigas ainda têm textos no código e migram aos poucos.

## Commits

Seguimos [Conventional Commits](https://www.conventionalcommits.org/pt-br/), com tipo em inglês e descrição em português, no imperativo e em minúsculas:

```
feat(prices): adiciona leitura de etiqueta pela câmera
fix(stock): impede quantidade negativa ao dar baixa
docs: explica a regra de dependência entre camadas
refactor(products): migra entidades para freezed
test(prices): cobre promoção de/por no parser
chore(android): atualiza Gradle para 9.1
```

- Tipos: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`, `style`, `build`, `ci`.
- Escopo: a feature (`products`, `markets`, `prices`, `stock`) ou a área (`core`, `data`, `ui`, `android`, `design-system`).
- **Commits atômicos:** um commit faz uma coisa e deixa o projeto compilando. Refatoração e mudança de comportamento vão em commits separados.
- O corpo explica o porquê quando ele não é óbvio.

## Branches e pull requests

- `main` está sempre funcionando.
- Trabalhe em branches curtas: `feat/lista-de-compras`, `fix/parser-preco-kg`, `docs/adr-sincronizacao`.
- Pull request pequeno, com descrição do que muda e como testar. Mudanças visuais levam print ou vídeo.

## Onde colocar cada coisa

| Você vai criar... | Coloque em |
| --- | --- |
| Uma regra de negócio | `features/<feature>/domain/`, com teste de unidade |
| Acesso a banco, câmera ou API | `features/<feature>/data/`, atrás de um contrato do domínio |
| Uma tela | `features/<feature>/presentation/<tela>/` com controller próprio |
| Um componente visual reutilizável | `core/design_system/components/` |
| Uma cor, raio ou espaçamento | um token em `core/design_system/` e no design system do Claude |
| Um texto visível ao usuário | `core/l10n/app_pt.arb` |
| Uma decisão de arquitetura | um ADR novo em `docs/adr/` |

Detalhes das camadas e regras em [arquitetura.md](arquitetura.md).
