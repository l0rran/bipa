# 0013. Separar o produto das embalagens

- Status: Aceito
- Data: 2026-10-28

## Contexto

Hoje cada código de barras é um produto, com marca e tamanho fixos. Estoque, lista, "ter sempre" e preços ficam presos a esse código. Na prática:

- comprar arroz de outra marca obriga a editar o produto ou a cadastrar outro;
- o arroz de 5 kg e o de 10 kg viram dois produtos, cada um com o seu estoque e o seu "ter sempre";
- a lista diz "Arroz Tio João 5 kg" quando a pessoa só precisa de arroz;
- não dá para comparar o preço de tamanhos diferentes.

Em casa, o arroz é um só: o que muda de uma compra para outra é a embalagem. Referências e o que levamos delas estão em [processo.md](../design/processo.md#produto-e-embalagens-outubro-de-2026).

## Decisão

- **Produto** é o que se usa em casa: "Arroz branco". Tem nome, foto e categoria. Estoque, "ter sempre", lista e consumo ficam nele.
- **Embalagem** é o que se compra: um código de barras (opcional), a marca e o tamanho com a unidade (5 kg, 395 g, 12 un). Cada produto tem uma ou mais embalagens.
- **Preços são da embalagem.** Cada observação guarda a embalagem e o produto. Embalagens com tamanho conhecido se comparam pelo preço por unidade de medida (R$/kg), na tela do produto e na comparação entre mercados.
- **O estoque conta embalagens e mostra o total.** O produto sabe quantas embalagens de cada tipo há em casa: 1 de 5 kg e 1 de 10 kg dão "2", com "15 kg" ao lado. "Comprei um" sem saber qual soma a embalagem mais recente; "Usei um" tira a que entrou primeiro.
- **Cada entrada é um lote.** O estoque guarda uma linha por compra (`stock_lots`: embalagem, quantidade e quando entrou), e a soma dos lotes é sempre a quantidade do produto. Assim o "Usei um" tira o lote mais antigo de verdade, mesmo com duas compras da mesma embalagem, e todo ajuste devolve o que mudou lote a lote: o "Desfazer" (do Início ou do "Terminei") tira exatamente o lote que entrou e devolve exatamente os que saíram, com a data original. Um produto sem embalagem tem lotes sem embalagem; o total em kg só aparece quando todos os lotes têm tamanho.
- **O carrinho guarda embalagens**, porque é o que foi bipado. O "Terminei" soma cada uma ao estoque do seu produto.
- **Código novo vira embalagem com um toque.** O app sugere o produto pelo nome lido na etiqueta ou pela categoria, procurando entre os produtos que já existem; sem nenhum, sugere um nome genérico da categoria ("Arroz"). Marca e tamanho vêm do nome da etiqueta, para conferir. Trocar o produto sugerido abre a lista de produtos, com a opção de criar outro.
- **Migração (esquema 7).** Cada produto atual vira um produto e uma embalagem com o mesmo id. Preços, carrinho e estoque continuam valendo sem conversão. Os produtos que eram o mesmo em embalagens diferentes podem ser juntados depois, por um "Juntar com…" na tela do produto.
- **Sincronização (ADR 0007).** Embalagens têm UUID gerado no aparelho e `syncedAt`, como os produtos. As observações de preço continuam imutáveis e ganham a referência da embalagem.
- **A exceção do "Juntar com…".** Juntar dois produtos apaga um deles, e as observações de preço dele não podem apontar para um produto que não existe. Elas são a única mudança permitida numa observação: trocam o `productId` pelo do produto que fica e voltam para a fila de sincronização (`syncedAt` nulo). Preço, mercado, data e embalagem não mudam. No servidor, o mesmo "juntar" precisa ser um evento próprio, para que outros aparelhos refaçam a troca em vez de verem um conflito.

## Consequências

- O modelo fica mais perto de como se pensa em casa e no mercado. A lista e o estoque deixam de depender da marca.
- É uma mudança grande: produto, preços, estoque, carrinho, captura e as telas de produto mudam juntos. Ela vai em fases, com o app compilando e os testes passando a cada commit.
- A tela de cadastro deixa de pedir marca e tamanho do produto; isso passa para a embalagem.
- O total em kg depende de saber o tamanho de cada embalagem. Sem tamanho, o estoque mostra só a contagem.
- Quem já tem produtos duplicados (um por marca) precisa juntá-los uma vez.
