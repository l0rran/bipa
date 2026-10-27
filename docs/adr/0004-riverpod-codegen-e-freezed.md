# 0004. Usar Riverpod com geração de código e freezed

- Status: Aceito
- Data: 2026-10-27

## Contexto

O protótipo usava Riverpod declarando providers à mão e entidades com `==`, `hashCode` e `copyWith` escritos manualmente. Isso gera código repetitivo e propenso a erro (esquecer um campo na igualdade). O projeto já usa `build_runner` por causa do Drift.

## Decisão

- Estado e injeção de dependências com **Riverpod 3 + `riverpod_generator`** (`@riverpod`).
- Entidades, estados de tela e value objects compostos com **`freezed`**.
- Lints do `riverpod_lint` (via `custom_lint`) para pegar erros de uso de providers.

## Alternativas consideradas

- **Riverpod sem geração de código:** menos dependências, mas mais boilerplate e sem os lints específicos.
- **BLoC/Cubit:** padrão difundido, porém mais verboso e exigiria reescrever toda a camada de apresentação.

## Consequências

- Providers e controllers ficam curtos e com tipos inferidos; `autoDispose` é o padrão.
- Depois de mudar anotações, rode `dart run build_runner watch -d` (ou `build`).
- As versões de `riverpod_generator`, `freezed` e `drift_dev` precisam ser compatíveis entre si (todas dependem do `analyzer`). Ao atualizar uma, atualize as outras juntas com `flutter pub upgrade --major-versions`.
