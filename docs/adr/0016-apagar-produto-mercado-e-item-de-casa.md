# 0016. Apagar produto, mercado e item de casa

- Status: Aceito
- Data: 2026-10-28

## Contexto

Até aqui o app não tinha como tirar nada. Um produto com erro de digitação só saía pelo "Juntar com…", e um mercado criado por engano ficava para sempre. Um produto que zerou e nunca mais vai ser comprado ficava em "Acabando" para sempre. A análise de UX apontou isso como problema médio.

Apagar esbarra no ADR 0007: as observações de preço são imutáveis e, um dia, vão para a base comunitária.

## Decisão

- **Tirar de casa** (o item do estoque) apaga o item e os lotes. O produto, os preços e o histórico de movimentos continuam: é só "não tenho mais isso em casa". Fica no editor do item, com confirmação.
- **Apagar produto** apaga o produto e, em cascata, as embalagens, os preços, o estoque, a lista e o carrinho dele. Fica no menu da tela do produto, com uma confirmação que diz o que vai junto e que não dá para desfazer.
- **Apagar mercado** apaga o mercado e, em cascata, os preços e a ordem das seções dele. As compras feitas nele ficam sem mercado. Fica no menu da tela do mercado, ao lado de "Editar", também com confirmação. (Até a tela do mercado existir, ficava na barra do formulário.)
- Apagar é diferente de juntar. Juntar preserva o histórico e o passa para o outro produto. Apagar descarta.

## Consequências

- A pessoa consegue limpar o que cadastrou errado.
- Os preços apagados com o produto ou o mercado saem da base local. Enquanto não há sincronização, isso não afeta ninguém.
- O ADR de sincronização vai precisar de marcas de exclusão para que um produto ou mercado apagado aqui também saia do servidor e dos outros aparelhos. Isso inclui decidir se preços já enviados à base comunitária podem ser retirados por quem os enviou.
