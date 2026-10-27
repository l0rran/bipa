# 0007. Preparar os dados para a sincronização desde o início

- Status: Aceito
- Data: 2026-10-27

## Contexto

Na fase 2, parte dos dados (produtos, mercados e preços) vai para uma base comunitária. Adaptar o esquema depois, com dados de usuários já gravados, é caro e arriscado.

## Decisão

- **IDs UUID v4** gerados no aparelho para todas as entidades.
- **Observações de preço imutáveis:** só inserção, nunca atualização. Um preço novo é um registro novo.
- **Outbox:** tabelas compartilháveis têm `synced_at` (nulo = pendente). Editar um produto ou mercado zera essa coluna.
- **Origem do preço** registrada (`manual`, `priceTag`, `receipt`), para pesar a confiabilidade na base comunitária.
- **Estoque e lista de compras são privados** e nunca são sincronizados.

## Consequências

- A sincronização vira "enviar o que tem `synced_at` nulo e marcar como enviado", sem resolução de conflitos para preços.
- Produtos e mercados ainda podem ter conflitos de edição; a estratégia (última escrita vence, com moderação no servidor) será decidida em um ADR da fase 2.
- Os dados enviados não podem conter informação pessoal: nada de CPF do cupom fiscal nem trilhas de localização com horário.
