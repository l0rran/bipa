# 0003. Organizar o código por funcionalidade, em camadas

- Status: Aceito
- Data: 2026-10-27

## Contexto

O app vai crescer em funcionalidades independentes (estoque, preços, mercados, lista de compras, sincronização). Organizar por tipo técnico (`models/`, `screens/`, `services/`) espalha cada funcionalidade por todo o projeto.

## Decisão

Pastas por funcionalidade em `lib/features/<feature>/`, cada uma com `domain/`, `data/` e `presentation/`. A regra de dependência e os detalhes estão em [arquitetura.md](../arquitetura.md).

## Consequências

- Uma funcionalidade nova é uma pasta nova; remover uma é apagar a pasta.
- O domínio fica em Dart puro e é testável sem Flutter.
- Há um pouco mais de arquivos (contrato + implementação) do que numa estrutura sem camadas. Aceitamos isso em troca de testabilidade e da troca futura de implementações (banco local por API, ML Kit por outro motor).
