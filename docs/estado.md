# Estado do trabalho

Retrato de 29/10/2026, para quem continua o trabalho (pessoa ou agente). Leia antes de mexer no código. Atualize esta página quando o retrato mudar: um item verificado, uma decisão tomada, um próximo passo feito.

## Onde estamos

- **Branch:** tudo está em `main`, publicado em `l0rran/bipa`. Não há branch aberta.
- **Compilação:** o código compila e os testes passam (abaixo).
- **Banco:** esquema 15 (`product_packages.origin`, de onde veio a embalagem; ADR 0023, lacuna C1). O teste de migração está em `test/core/database/migration_test.dart`.
- **Feito até aqui:** o [CHANGELOG](../CHANGELOG.md), seção "Não lançado". O que falta está no [roadmap](roadmap.md).
- **Android:** minSdk 26 (Android 8.0), exigido pelo `sentry_flutter` 10. `flutter build apk --debug` passa.
- **Protótipo e design system:** as cópias do repositório estão **à frente** das publicadas no claude.ai. Em 28/10 entraram quadros novos (Arrumar o que entrou, granel na bandeja, local no aviso, Produtos, barra com letra grande e os que o app já fazia), o ícone novo, variantes de componente e guias corrigidos. Cada mudança está anotada na linha do quadro ou no guia; o publicado precisa recebê-las (item no roadmap).

## Compilado e testado

Em 28/10, no Windows (Flutter 3.47.8, Dart 3.13.7): `flutter analyze` sem problemas, `flutter test` com 1067 testes passando, `flutter build apk --debug` passando e o banco do OCR passando. No Windows, o banco do OCR roda com `py -3 tool/ocr_bench/testes.py`, porque não há `python3`, e `dart format .` falha depois de um build por causa de um caminho longo dentro de `build/`: use `dart format lib test tool`.

Os lotes 8 a 12 foram feitos por agentes em paralelo, cada um num worktree, e juntados em `main` com merges. Cada lote terminou com uma revisão de UX: [lote 8](ux/analise-ux-2026-10-28-lote8.md), [lote 9](ux/analise-ux-2026-10-28-lote9.md) , [lote 10](ux/analise-ux-2026-10-28-lote10.md) [lote 11](ux/analise-ux-2026-10-29-lote11.md) e [lote 12](ux/analise-ux-2026-10-29-lote12.md), cujos achados estão no roadmap.

Falta o teste no aparelho, de antes e de agora:
- compra: "3× Leite" bipando um de cada vez, cancelar pela folha "Fim da compra", trocar o produto de uma pesagem, o granel na bandeja (traço, preço por kg e "Quanto deu…");
- casa: a câmera de "Guardar em casa" com o local no aviso, o chip do modo e a folha "Arrumar o que entrou" ao fechar (pelo "×" e pelo voltar do Android);
- produto: corrigir um preço, "Editar embalagem", mover e apagar embalagem com Desfazer, a etiqueta em destaque com o furo (tema claro e escuro);
- geral: os avisos que somem sozinhos (e com TalkBack, pausa ao toque, 10 s nas ações grandes, o "Tempo para agir" do Android e por cima das folhas), a barra encolhendo ao rolar, o anel que respira duas vezes e para, a letra do Android em 130%, 170% e no máximo (com o toque longo na barra da compra), e o ícone no lançador e na notificação;
- novos: a busca sem acento, o recorte da etiqueta do granel, a tela de Ajustes e, num build com DSN, o cartão do relatório de falhas.
- catálogo: bipar produtos de casa que você ainda não cadastrou (a "Embalagem nova" preenchida; leite condensado, Fanta Uva e parecidos não podem cair no produto genérico; "Leite UHT integral" deve cair em "Leite"), a linha "Dados do Open Food Facts" no produto e a atribuição em Ajustes;
- backup: "Fazer backup agora", "Salvar uma cópia…" (seletor do Android, Drive e pasta local) e "Restaurar de um arquivo…" com a confirmação, os erros e o Desfazer; num segundo aparelho ou depois de limpar os dados do app, o cartão "Backup encontrado" (casa vazia e casa em uso, "Deixar de lado"), a linha "Último backup" em Ajustes e o diálogo antes de gravar por cima. Para forçar o Auto Backup: `adb shell bmgr backupnow dev.l0rran.bipa`.

## Pontos abertos conhecidos

Achados "prováveis" das revisões que ficaram como estão, por serem raros ou pedirem decisão:

- **Troca de pesagem (D6):** troca para o produto novo todos os códigos da balança do produto antigo naquele mercado, porque a linha do carrinho não guarda de que código veio. Toda linha sem embalagem de um produto que a balança conhece é tratada como pesagem (o toque troca o produto em vez da quantidade). E a troca não roda numa transação.
- **Total com o marcado à mão (CE4):** o preço esperado vem de `listPrices`, que para granel pode ser o preço por kg; multiplicado pela quantidade da lista, distorce o "≈".
- **Desmarcar na Lista um item "1 de 3"** desliga o "levar" da unidade que está no carrinho (regra antiga do `_setChecked`, agora mais fácil de alcançar).
- **Aviso do "ter sempre" (AB1)** só aparece quando a linha fecha por toque; trocar o filtro ou sair da tela com o editor aberto não oferece nada.
- **Linha do "Usei um" (AB3):** com TalkBack, o aviso com Desfazer fica até a pessoa agir (de propósito, WCAG 2.2.1), e a linha fica fora de "Acabando" até ele sair.
- **Juntar produtos e foto:** se o produto que fica não tem foto, a do que sai é apagada em vez de passar para ele (ADR 0013: o que fica mantém os próprios dados).
- **Desfazer de mover embalagem:** se o estoque do produto antigo foi limitado a zero na ida, a volta soma a quantidade dos lotes, que pode diferir do valor original.
- **Pedir o mercado antes da folha "Fim da compra":** se a pessoa escolhe o mercado e depois "Cancelar compra", os preços já foram para o histórico dele (o ADR 0020 aceita: são preços vistos de verdade).

## Próximos passos

Os detalhes de cada código estão nas análises de UX (em `ux/`) e no [roadmap](roadmap.md).

1. **Teste no aparelho pelo mantenedor** (lista acima): BK1, BK2, BK3, BK4, G12 e G13 foram corrigidos em 29/10, antes dele. A [revisão do lote 13](ux/analise-ux-2026-10-29-lote13.md) roda em paralelo.
2. **Depois:** BK3, G13, G14, H20 e G15; AB14, H19 e a escolha de produto no design system (H1), com quadro ou regra antes; o quadro InicioRelatorioFalhas com o texto novo.
3. **Cobertura do catálogo:** medir com os cupons reais do mantenedor (`tool/catalogo/cobertura.py`). Amostras de sites de terceiros não são usadas.
4. **Levar ao claude.ai** as mudanças de 28/10 nas cópias do protótipo e do design system.
5. **Também:** a migração para o Kotlin embutido e o teste no aparelho (acima).

## Decisões do mantenedor em 28/10

- **Relatório de falhas:** Sentry, só com consentimento (ADR 0025). Para ligar: criar o projeto no Sentry (região UE, sem guardar IP) e gerar o build com `--dart-define=SENTRY_DSN=<dsn>`. Até a tela da pergunta existir, nada é enviado.
- **Ícone:** a etiqueta amarela com o "b" (`docs/design/icone/`).
- **Backup:** Auto Backup do Android ligado, só com o `.bipa` mais recente (ADR 0023).
- **Catálogo:** Open Food Facts, Open Products Facts e Open Beauty Facts, embarcado no APK, sem consulta online na primeira versão (ADR 0024).
- **Embalagens (G2):** mover tem Desfazer; apagar com preços continua apagando, com Desfazer; produto vazio recebe a oferta de apagar; movimentos de estoque ficam no produto antigo por ora (ADR 0022).
- **Quadros:** barra A até 160% e B acima; "Arrumar o que entrou" com 3+ itens novos e só "Pronto"; local dentro do aviso; peso no diálogo do granel; Produtos com o preço da embalagem ou por kg, "Cadastrar" no fim e sem filtros; nas divergências entre app e design system, vale a versão mais atual, se for consistente com o resto do app.

## Decisões que esperam o mantenedor

- **Licença da base comunitária** (ADR 0024, só na Fase 2): consultar reuse@openfoodfacts.org antes.

## Ferramentas para agentes

| Ferramenta | Para quê |
| --- | --- |
| [`tool/ocr_bench`](../tool/ocr_bench) | Port em Python do `PriceTagParser` com banco de testes. Mudou o parser em Dart, mude o port e rode `python3 tool/ocr_bench/testes.py` |
| [`tool/prototipo/renderizar.js`](../tool/prototipo/renderizar.js) | Gera as imagens do protótipo a partir do HTML em `docs/design/prototipo/fonte/` (Playwright). Veja [como mudar uma tela](design/prototipo/README.md#como-mudar-uma-tela-sem-acesso-ao-claudeai) |
| [`tool/hunks.py`](../tool/hunks.py) | Põe no índice só alguns trechos do diff de um arquivo, para commits atômicos sem `git add -p` interativo: `python3 tool/hunks.py list ARQUIVO` e `python3 tool/hunks.py stage ARQUIVO 0,2` |
| [`tool/kit_emulador`](../tool/kit_emulador/README.md) | Imagens para a câmera virtual do emulador |
| [`tool/icone`](../tool/icone) | Gera as pranchas e os PNGs do ícone a partir dos SVGs (Playwright fora do repositório) |

## Documentos publicados no claude.ai

Os três são privados da conta do mantenedor. O repositório tem cópias para quem não tem acesso:

| Publicado | Cópia no repositório | Qual vale |
| --- | --- | --- |
| [Design system Bipa](https://claude.ai/artifact/UgbPTJ2wLHMP5FmPcC7E8G) | [`design/design-system/`](design/design-system/README.md) | O publicado, depois de receber as mudanças de 28/10 da cópia |
| [Protótipo Bipa App Telas](https://claude.ai/artifact/Pefns8PVVY8nFXTq8Z6Gd3) | [`design/prototipo/`](design/prototipo/README.md) | O publicado, depois de receber as mudanças de 28/10 da cópia |
| [Análise de UX (lote 7)](https://claude.ai/artifact/VeoUk6VjBSRWCox1prVyMr) | [`ux/analise-ux-2026-10-28.md`](ux/analise-ux-2026-10-28.md) | Nenhum para o estado: o estado está no roadmap |

Quem mudar uma cópia sem acesso ao publicado deixa isso escrito (na linha da tela, ou nesta página), para o publicado receber a mesma mudança depois.
