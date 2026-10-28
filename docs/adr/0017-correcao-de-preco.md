# 0017. Correção de preço sem apagar a observação

- Status: Aceito
- Data: 2026-10-28

## Contexto

No modo carrinho, a etiqueta lida ao vivo vira uma observação de preço na hora (ADR 0012). Se o OCR lê "21,90" no lugar de "27,90", a pessoa digita o preço certo, mas a leitura errada continua no histórico. Ela vira o "menor preço do dia" no gráfico de 6 meses, em "Nos mercados" e na comparação da lista. A análise de UX apontou isso como problema médio (D5).

O ADR 0007 manda as observações serem imutáveis e só inseridas, para a sincronização não ter conflito. Apagar ou editar a leitura errada quebraria essa regra.

## Decisão

- Uma observação pode **corrigir** outra: o campo `supersedes` guarda o id da corrigida (coluna `supersedes_id`, esquema v11).
- A corrigida continua gravada. O histórico, o preço por mercado e os preços recentes do mercado a ignoram (`withoutSuperseded`). Quem a substitui é a correção.
- No modo carrinho, digitar o preço de um item cuja etiqueta foi lida nesta compra grava o preço digitado como correção da leitura. Digitar de novo corrige o digitado antes.
- A coluna não tem chave estrangeira: com a sincronização, uma correção pode chegar antes da observação que ela corrige.
- A correção vale só para o preço principal. Os outros preços da mesma etiqueta (cartão, atacado) continuam valendo.

## Consequências

- Uma leitura errada deixa de distorcer o histórico assim que é corrigida, sem apagar nada.
- Na sincronização, a correção é só mais uma inserção, e a base comunitária pode usar a mesma regra para ignorar leituras corrigidas.
- O "Desfazer" da leitura ao vivo pedido no `BipFeedback.md` ainda não existe. A correção cobre o caso mais comum, que é a pessoa ver o preço errado e digitar o certo.

## Atualização (28/10/2026)

A correção também existe fora do carrinho: tocar num preço da tela do produto ("Nos mercados") ou da tela do mercado ("Preços recentes") abre a folha do preço, com "Corrigir o preço". A correção grava uma observação nova que corrige a antiga (`supersedes`), com a data da antiga, porque o preço certo é o daquele dia.
