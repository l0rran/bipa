# Registros de decisão de arquitetura (ADRs)

Cada arquivo registra uma decisão importante: o contexto, o que foi decidido e as consequências. Decisões não são apagadas; quando mudam, um novo ADR substitui o antigo e o antigo passa a "Substituído por".

| Nº | Decisão | Status |
| --- | --- | --- |
| [0001](0001-flutter-android-primeiro.md) | Flutter, começando pelo Android | Aceito |
| [0002](0002-offline-first-com-drift.md) | Offline-first com SQLite (Drift) como fonte da verdade | Aceito |
| [0003](0003-arquitetura-feature-first.md) | Arquitetura feature-first em camadas | Aceito |
| [0004](0004-riverpod-codegen-e-freezed.md) | Riverpod com geração de código e freezed | Aceito |
| [0005](0005-reconhecimento-on-device.md) | Reconhecimento de etiquetas e códigos no aparelho (ML Kit) | Aceito |
| [0006](0006-dinheiro-em-centavos.md) | Valores monetários em centavos | Aceito |
| [0007](0007-dados-prontos-para-sincronizar.md) | UUIDs, preços imutáveis e outbox para sincronizar | Aceito |
| [0008](0008-design-system-proprio.md) | Design system próprio sobre o Material 3 | Aceito |
| [0009](0009-cores-semanticas-e-paleta-trocavel.md) | Cores semânticas, com a paleta trocável num lugar só | Aceito |
| [0010](0010-fotos-dos-produtos.md) | Foto do produto, com o ícone da categoria como reserva | Aceito |
| [0011](0011-precos-com-condicao.md) | Cada preço da etiqueta com a sua condição (atacado, cartão, varejo) | Aceito |

## Modelo

```markdown
# NNNN. Título no imperativo

- Status: Proposto | Aceito | Substituído por NNNN
- Data: AAAA-MM-DD

## Contexto
O problema e as forças em jogo.

## Decisão
O que foi decidido.

## Consequências
O que fica mais fácil, o que fica mais difícil e o que precisa ser feito.
```
