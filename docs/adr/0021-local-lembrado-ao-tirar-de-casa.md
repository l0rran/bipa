# 0021. Lembrar o local do item ao tirar de casa

- Status: Aceito
- Data: 2026-10-28

## Contexto

Um item nasce em casa no local sugerido pela categoria do produto (`suggestedLocation`): leite na Geladeira, sabão na Limpeza, o resto na Despensa. A pessoa pode trocar o local, e a escolha fica na linha de `stock_items`.

"Tirar de casa" (ADR 0016) apaga essa linha, e a presença dela é o que quer dizer "está em casa". Com ela vai o local escolhido. A análise de UX de 28/10 (AB10) descreve o efeito: a pessoa põe o atum na Despensa, tira de casa quando acaba e, na compra seguinte, ele volta para a Geladeira, que é a sugestão da categoria.

Havia dois caminhos:

- **Esconder em vez de apagar:** `remove` marca a linha de `stock_items` com uma flag e a mantém. O local sobrevive sem tabela nova, mas toda consulta que hoje entende "tem linha" como "está em casa" passa a precisar do filtro: o Início, o "Acabando", a folha do item, o cartão "Em casa" do produto, a compra que termina, a lista, o juntar produtos. Uma consulta esquecida mostra em casa o que a pessoa tirou.
- **Lembrar o local à parte:** `remove` continua apagando a linha e antes guarda o local num lugar que sobrevive a ela. Só o nascimento do item lê esse lugar.

Para o segundo, o lugar natural seria uma coluna nula em `products`. Mas `products` é compartilhável e tem `synced_at` (ADR 0007), e o estoque é privado. A coluna exigiria que a sincronização a deixasse de fora ao enviar e a preservasse ao receber, e que gravá-la não zerasse o `synced_at`. Uma tabela própria é privada por construção.

## Decisão

- Uma tabela nova e privada, `remembered_locations` (esquema v14): o produto (chave primária, apagado em cascata com ele) e o local. Sem `synced_at`: como o estoque e a lista, nunca é sincronizada.
- **Tirar de casa** grava ali o local que o item tinha, na mesma transação em que apaga o item e os lotes. Grava sempre, mesmo quando o local é o sugerido: se a sugestão mudar (AB9), o item volta para onde estava, e não para a sugestão nova.
- **O item que nasce** (o primeiro "+", a compra que entra, o "ter sempre" ou o local definidos antes da primeira entrada) usa o local lembrado e, sem ele, o sugerido pela categoria.
- **A folha do item**, antes de o item existir, marca o mesmo local, lido do repositório (`watchNewItemLocation`), para o chip não pular no primeiro "+".
- **Trocar o local de um item que está em casa não grava nada na tabela.** Enquanto o item existe, o local dele vive só em `stock_items`; o "Tirar de casa" copia o local que estiver lá naquele momento, então a última troca é a que fica lembrada. Gravar a cada troca daria duas cópias do mesmo dado para manter iguais, sem ganho.
- **Juntar produtos** leva o local lembrado do produto que some, se o que fica não tiver um.

## Consequências

- Nenhuma consulta de "em casa" ou "Acabando" muda: a linha de `stock_items` continua querendo dizer "está em casa".
- A linha lembrada fica na tabela depois que o item volta. Ela não é lida enquanto o item existe, e o próximo "Tirar de casa" a sobrescreve.
- O "ter sempre" continua indo embora com o item. Quem tira de casa o que não quer mais comprar não quer o alerta de volta; lembrar o "ter sempre" seria outra decisão.
- Apagar o produto apaga o local lembrado junto.
