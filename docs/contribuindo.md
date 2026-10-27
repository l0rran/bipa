# Como contribuir

## Ambiente

- Flutter estável (3.32 ou mais novo) e Android SDK. Confira com `flutter doctor`.
- No Windows, use o terminal do próprio Windows (PowerShell ou VS Code), não o WSL, para o emulador aparecer.

```bash
flutter pub get
dart run build_runner build -d   # gera o código do Drift, Riverpod e freezed
flutter run
```

Durante o desenvolvimento, deixe `dart run build_runner watch -d` rodando num terminal à parte.

## Antes de cada commit

```bash
dart format .
flutter analyze
flutter test
```

Os três precisam passar. Código gerado (`*.g.dart`, `*.freezed.dart`) não é versionado.

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
