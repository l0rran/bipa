# Bipa: guia para agentes

App Android em Flutter para controlar o estoque da casa e o histórico de preços de mercado. É offline-first, e a captura usa a câmera (código de barras e OCR da etiqueta) para evitar digitação. Comece por [docs/README.md](docs/README.md).

## Idioma

- Código (nomes de classes, funções, variáveis) em inglês; comentários, documentação, textos da interface e descrições de commit em português do Brasil.
- Textos visíveis ao usuário ficam em `lib/core/l10n/app_pt.arb`, nunca direto no widget.

## Arquitetura

- Feature-first com camadas `domain` / `data` / `presentation` ([docs/arquitetura.md](docs/arquitetura.md)). O domínio não importa Flutter nem Drift.
- Riverpod com geração de código e freezed (ADR 0004); Drift para o banco local (ADR 0002).
- Dinheiro sempre em centavos (`int`), nunca `double` (ADR 0006).
- Cores só pelo tema, com nomes de função (`context.colors.brand`, `alert`...). A paleta fica num arquivo só, `lib/core/design_system/bipa_palette.dart`; nada de `Color(0xFF...)` nos widgets (ADR 0009).
- Dados prontos para sincronizar: UUID gerado no aparelho, `syncedAt` na outbox, e observações de preço imutáveis (ADR 0007).
- Decisão nova de arquitetura vira um ADR em `docs/adr/`.

## Commits

- Seguem Conventional Commits, com tipo em inglês e descrição em português, no imperativo e em minúsculas. Exemplo: `feat(stock): adiciona baixa por gesto`.
- São atômicos: um commit faz uma coisa e deixa o projeto compilando. Detalhes em [docs/contribuindo.md](docs/contribuindo.md).

## Design

- O design system **Bipa** e o protótipo **Bipa App Telas** (links em [docs/design/identidade-visual.md](docs/design/identidade-visual.md)) são a referência visual. Se divergirem do código, o design system vale.
- **Referência primeiro, do nosso jeito depois:** antes de desenhar ou mudar um componente, pesquise como outros apps resolvem o mesmo problema e registre o que levamos e o que fazemos diferente ([docs/design/processo.md](docs/design/processo.md)).
- **Calma por padrão:** um destaque por tela, um sinal por informação, controles que aparecem ao tocar e números importantes à vista.
- **Um acento por tela:** uma cor de destaque e o resto neutro. A marca é o amarelo da etiqueta (`brand`), sempre com texto escuro por cima; o coral (`alert`) só marca o que está abaixo do "ter sempre".
- **Todo texto precisa se justificar:** antes de pôr um texto na tela, pergunte se é o lugar dele, se é necessário e se dá para dizer o mesmo de outra forma (ícone, número, cor, componente) sem prejudicar a compreensão. Navegação e ações que apagam algo ficam com texto, e todo elemento visual tem rótulo acessível.
- O visual é aprovado no protótipo antes de ser implementado.

## Ambiente de agentes na nuvem

- Na nuvem não há Flutter nem Dart instalados, e o pub.dev pode estar bloqueado. Por isso o código não é compilado ali, e quem compila e roda é o mantenedor, no Windows.
- Escreva código conferindo as APIs na documentação oficial e deixe claro o que não pôde ser compilado.
- Lógica pura pode ser validada com um port rápido em Python ou JavaScript. O `PriceTagParser` tem um port mantido em `tool/ocr_bench`, com banco de testes; mudou o parser em Dart, mude o port e rode `python3 tool/ocr_bench/testes.py`.
