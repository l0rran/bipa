# Estado do trabalho

Retrato de 28/10/2026, para quem continua o trabalho (pessoa ou agente). Leia antes de mexer no código. Atualize esta página quando o retrato mudar: um item verificado, uma decisão tomada, um próximo passo feito.

## Onde estamos

- **Branch:** tudo está em `main`, publicado em `l0rran/bipa`. Não há branch aberta.
- **Banco:** esquema 13 (`trip_prices`, ADR 0020). O teste de migração está em `test/core/database/migration_test.dart`.
- **Feito até aqui:** o [CHANGELOG](../CHANGELOG.md), seção "Não lançado". O que falta está no [roadmap](roadmap.md).
- **Protótipo:** tudo o que estava "aguardando revisão" foi aprovado pelo mantenedor em 28/10. A cópia em [`design/prototipo/`](design/prototipo/README.md) está igual à publicada nessa data.

## Primeiro passo: compilar e testar

O código das últimas sessões foi escrito por agentes na nuvem, **sem Flutter**: nada foi compilado nem rodado. Revisões independentes conferiram à mão o que veio até o commit `670553d`. Os commits de `670553d..af4f739` não passaram por revisão nenhuma: G3, F4, F3, H5, H2, H4, H3, G1 e as correções da troca de pesagem. Antes de qualquer implementação nova:

```bash
flutter pub get                  # image_picker e mobile_scanner saíram do pubspec
dart run build_runner build -d   # o Drift mudou (esquema 13, CartRepository.remove, ScaleItemRepository)
flutter gen-l10n                 # muitas chaves novas, com ICU select (perUnitSpoken) e plural com num
dart format .
flutter analyze
flutter test
python3 tool/ocr_bench/testes.py
```

O que mais pode falhar, pela ordem de risco:

- **Textos (gen-l10n):** `perUnitSpoken` usa `select` com o nome do enum (`kilogram`, `liter`...), e `stockAtHomeSpoken` e `stockTargetSpoken` usam `plural` com placeholder `num`.
- **Padrões novos do Dart 3.8:** `if (... case ... when ...)` dentro de map literal (`cart_mode_page.dart`), records em `switch`, elementos com `?`.
- **Testes de widget que dependem de altura:** `components_test.dart` espera 52 de altura no `ShoppingListRow` com quantidade tocável.
- **Formatação:** o `dart format` vai quebrar algumas linhas; é esperado.

Depois disso, um teste no aparelho dos fluxos novos: comprar com "3× Leite" bipando um de cada vez, cancelar pela folha "Fim da compra", trocar o produto de uma pesagem, corrigir um preço pela tela do produto e "Editar embalagem".

## Pontos abertos conhecidos

Achados "prováveis" das revisões que ficaram como estão, por serem raros ou pedirem decisão:

- **Troca de pesagem (D6):** troca para o produto novo todos os códigos da balança do produto antigo naquele mercado, porque a linha do carrinho não guarda de que código veio. Toda linha sem embalagem de um produto que a balança conhece é tratada como pesagem (o toque troca o produto em vez da quantidade). E a troca não roda numa transação.
- **Total com o marcado à mão (CE4):** o preço esperado vem de `listPrices`, que para granel pode ser o preço por kg; multiplicado pela quantidade da lista, distorce o "≈".
- **Desmarcar na Lista um item "1 de 3"** desliga o "levar" da unidade que está no carrinho (regra antiga do `_setChecked`, agora mais fácil de alcançar).
- **Aviso do "ter sempre" (AB1)** só aparece quando a linha fecha por toque; trocar o filtro ou sair da tela com o editor aberto não oferece nada.
- **Linha do "Usei um" (AB3):** com TalkBack, o snackbar com ação não expira, e a linha fica fora de "Acabando" até o aviso sair.
- **Pedir o mercado antes da folha "Fim da compra":** se a pessoa escolhe o mercado e depois "Cancelar compra", os preços já foram para o histórico dele (o ADR 0020 aceita: são preços vistos de verdade).

## Próximos passos

Pela ordem que vínhamos seguindo. Os detalhes de cada código estão na [análise de UX](ux/analise-ux-2026-10-28.md) e no [roadmap](roadmap.md).

1. **Compilar e testar** (acima) e corrigir o que aparecer.
2. **Ajustes de UX que faltam:** AB5 (primeira carga que configura), o resto do D3 (preço por kg como estimativa na bandeja), H2 (exceções do domínio pelo ARB, falha no stepper do produto), H3 (teste com fonte em 200%), a barra de navegação que encolhe ao rolar, e os quadros que faltam no protótipo.
3. **Maiores, com ADR ou protótipo antes:** G2 (mover e apagar embalagem, com ADR) e H1 (aba Produtos com os componentes de Mercados).
4. **Fase 0:** o ADR do modelo de dados (antes do backup) e o ADR do catálogo pronto de produtos brasileiros (fonte e licença).
5. **Relatório de falhas e ícone do app:** esperam decisão do mantenedor (abaixo).

## Decisões que esperam o mantenedor

- **Relatório de falhas:** qual serviço (por exemplo Firebase Crashlytics, Sentry, ou só um registro local exportável). Pesa a privacidade (LGPD) e o app ser offline-first.
- **Ícone do app:** a direção visual. O design system está em [`design/design-system/`](design/design-system/README.md); o amarelo da etiqueta é a marca.

## Ferramentas para agentes

| Ferramenta | Para quê |
| --- | --- |
| [`tool/ocr_bench`](../tool/ocr_bench) | Port em Python do `PriceTagParser` com banco de testes. Mudou o parser em Dart, mude o port e rode `python3 tool/ocr_bench/testes.py` |
| [`tool/prototipo/renderizar.js`](../tool/prototipo/renderizar.js) | Gera as imagens do protótipo a partir do HTML em `docs/design/prototipo/fonte/` (Playwright). Veja [como mudar uma tela](design/prototipo/README.md#como-mudar-uma-tela-sem-acesso-ao-claudeai) |
| [`tool/hunks.py`](../tool/hunks.py) | Põe no índice só alguns trechos do diff de um arquivo, para commits atômicos sem `git add -p` interativo: `python3 tool/hunks.py list ARQUIVO` e `python3 tool/hunks.py stage ARQUIVO 0,2` |
| [`tool/kit_emulador`](../tool/kit_emulador/README.md) | Imagens para a câmera virtual do emulador |

## Documentos publicados no claude.ai

Os três são privados da conta do mantenedor. O repositório tem cópias para quem não tem acesso:

| Publicado | Cópia no repositório | Qual vale |
| --- | --- | --- |
| [Design system Bipa](https://claude.ai/artifact/UgbPTJ2wLHMP5FmPcC7E8G) | [`design/design-system/`](design/design-system/README.md) | O publicado |
| [Protótipo Bipa App Telas](https://claude.ai/artifact/Pefns8PVVY8nFXTq8Z6Gd3) | [`design/prototipo/`](design/prototipo/README.md) | O publicado |
| [Análise de UX (lote 7)](https://claude.ai/artifact/VeoUk6VjBSRWCox1prVyMr) | [`ux/analise-ux-2026-10-28.md`](ux/analise-ux-2026-10-28.md) | Nenhum para o estado: o estado está no roadmap |

Quem mudar uma cópia sem acesso ao publicado deixa isso escrito (na linha da tela, ou nesta página), para o publicado receber a mesma mudança depois.
