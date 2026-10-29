# 0022. Mover e apagar uma embalagem

- Status: Aceito
- Data: 2026-10-28

## Contexto

Uma embalagem (ADR 0013) posta no produto errado não tem conserto. Quem bipa o Leite Ninho e o põe no "Leite integral" só pode apagar o produto inteiro ou juntá-lo a outro, e nenhum dos dois serve: o "Leite integral" está certo, só a embalagem está no lugar errado. A análise de UX de 28/10 aponta isso como problema médio (G2).

O esquema (v14) já diz quem pertence a quem:

- `product_packages.product_id`: a embalagem é de um produto.
- `price_observations` guarda o produto **e** a embalagem (`product_id`, `package_id`). A chave da embalagem é `ON DELETE SET NULL`: apagar a embalagem transformaria os preços dela em preços "do produto, sem embalagem", sem tamanho, misturados aos do granel.
- `stock_lots`, `cart_items` e `trip_prices` também guardam os dois, com `SET NULL` na embalagem. A chave do item da compra (`CartItem.keyOf`, `trip_prices.item_key`) é `produto:embalagem`.
- `stock_items`, `shopping_list_items`, `remembered_locations` (ADR 0021) e `scale_items` são do produto e não sabem de embalagem.

As observações de preço são imutáveis (ADR 0007, 0017). A única mudança aceita até aqui é a do "Juntar com…" (ADR 0013): o produto delas deixa de existir, e elas trocam o `product_id` e voltam para a fila de sincronização.

Para mover sem tocar nas observações, elas teriam de apontar só para a embalagem, e o produto viria dela. Isso tira `product_id` de `price_observations` (esquema 15), muda todas as consultas de preço por produto, que hoje usam o índice `price_observations_product_date`, e muda o que a base comunitária recebe. É uma mudança grande para um conserto pontual.

## Decisão

**Mover para outro produto** é o "Juntar com…" de uma embalagem só, com a mesma exceção:

- A embalagem troca de produto e volta para a fila de sincronização (`updated_at`, `synced_at` nulo).
- **As observações de preço dela vão junto.** Trocam só o `product_id` pelo do produto novo e voltam para a fila (`synced_at` nulo). Preço, mercado, data, embalagem e correção (`supersedes`) não mudam. O preço continua sendo daquela embalagem naquele dia; o que estava errado era a classificação. Na sincronização, mover precisa ser um evento próprio, como o juntar.
- **Os lotes de estoque dela vão junto.** O que está em casa daquela embalagem é do produto novo: a quantidade do antigo cai (sem ficar negativa) e a do novo sobe, com um movimento de ajuste (`adjustment`) em cada um. Se o novo não está em casa, o item nasce no local lembrado dele ou, sem ele, no sugerido (ADR 0021). O item do antigo fica, mesmo zerado, com o "ter sempre" e o local: o produto antigo existe e pode continuar faltando.
- **O carrinho e os preços da compra** que citam a embalagem trocam de produto, em todas as compras, inclusive na que está em andamento. A chave do preço da compra (`trip_prices.item_key`) é refeita com o produto novo. Como a chave inclui a embalagem, nada colide com o que o produto novo já tem no carrinho.
- **Lista, local lembrado e itens da balança** são do produto e ficam com o antigo.
- O destino pode ser um produto que existe ou um produto novo, criado na hora com a grandeza base da embalagem, como no cadastro de um código novo. Mover para o mesmo produto não faz nada.
- A última embalagem pode sair. O produto antigo continua, sem embalagem, com o que tiver de preço sem embalagem e de estoque. Se ele estava ali só por engano, "Apagar produto" resolve.
- Pede confirmação dizendo quantos preços e quanto em casa vão junto, como o "Juntar com…". Não há "Desfazer": mover de volta pelo mesmo menu desfaz.

**Apagar embalagem** descarta a embalagem e os preços dela, como "Apagar produto" faz com o produto inteiro (ADR 0016):

- **Os preços dela saem**, apagados explicitamente. Deixar a chave virar nula transformaria R$ 27,90 do pacote de 5 kg num preço do produto sem tamanho, e o histórico mentiria. Esconder (uma marca de "apagada" na embalagem) exigiria o esquema 15 e um filtro em toda consulta de preço, e o ADR 0021 já recusou esse caminho para o estoque pelo mesmo motivo.
- **O que está em casa fica**, sem embalagem (a chave vira nula). Os itens existem; só o código estava errado. O total em kg some se algum lote ficar sem tamanho (ADR 0013).
- **Compras terminadas** ficam com as linhas do carrinho sem embalagem.
- **Na compra em andamento, não apaga.** A embalagem no carrinho é o que está na mão da pessoa, e o preço da compra aponta para uma observação dela. O app avisa e pede para tirar do carrinho ou terminar a compra antes.
- Pede confirmação no botão neutro ("Apagar embalagem"), dizendo quantos preços vão junto, e oferece **"Desfazer"**: o repositório devolve o que apagou (a embalagem, as observações como eram e quais lotes e linhas de carrinho perderam a embalagem) e o "Desfazer" grava tudo de volta, com os mesmos ids. As observações voltam com `synced_at` nulo. Como nada saiu do aparelho, regravar a mesma observação não é editar o passado.

O esquema não muda: continua o 14.

## Consequências

- Uma embalagem no produto errado se conserta em dois toques, com os preços e o estoque indo para onde deviam.
- O ADR 0013 passa a ter duas mudanças permitidas numa observação, o juntar e o mover, as duas só no `product_id`. A base comunitária vai precisar dos dois eventos.
- Apagar uma embalagem com preços apaga histórico, como apagar um produto. As marcas de exclusão do ADR 0016 vão precisar cobrir embalagens e as observações delas.
- O movimento de ajuste não separa o que foi comprado e usado de cada embalagem no passado: o histórico de movimentos do produto antigo continua com as compras dela. A previsão de consumo que usar esse histórico precisa contar com isso.
- O "Desfazer" do apagar só vale enquanto o aviso está na tela. Se a pessoa cadastrar o mesmo código nesse meio-tempo, o "Desfazer" falha e avisa.
