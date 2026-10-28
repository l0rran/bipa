# 0018. Etiquetas da balança no carrinho

- Status: Aceito
- Data: 2026-10-28

## Contexto

Hortifrúti, açougue, padaria e frios saem da balança do mercado com uma etiqueta própria. O código de barras dela é um EAN-13 de circulação restrita: começa com 2 e só vale dentro daquela loja ([GS1 Brasil](https://www.gs1br.org/conteudo/materiais-tecnicos/CadernoEficiencia/Conhecendo%20o%20C%C3%B3digo%20de%20Barras.pdf)). Ele junta o código do item na balança e o valor da pesagem.

Até aqui o app tratava esse código como o de um produto. No carrinho, cada pesagem abria "Embalagem nova", e cada saco de tomate virava um produto novo, sujando o catálogo. A análise de UX apontou isso como problema alto (D3).

O formato varia de balança para balança. As configurações comuns no Brasil (Toledo, Filizola) põem o código do item com 4, 5 ou 6 dígitos logo depois do 2 e o valor com 5 ou 6 dígitos antes do verificador. O valor quase sempre é o preço total em centavos, mas algumas lojas gravam o peso ([read-label-balance](https://packagist.org/packages/liontecnologia/read-label-balance)).

## Decisão

- Um EAN-13 válido que começa com 2 é uma **etiqueta da balança** (`ScaleLabel`), não um código de produto.
- O **código do item** são os 7 primeiros dígitos, que cobrem os códigos de 4, 5 e 6 dígitos. O **valor** são os 5 dígitos antes do verificador, lidos como centavos.
- No carrinho, o primeiro bipe de um item num mercado pergunta o produto ("Que produto é este de R$ 8,43?"), na busca de sempre, que também deixa criar um produto vendido por kg. A resposta fica lembrada por mercado (tabela `scale_items`, esquema v12). Sem mercado na compra, pergunta a cada vez.
- A pesagem entra no carrinho como o preço firmado do produto, sem embalagem. Duas pesagens do mesmo produto somam o valor numa linha só, que conta como uma embalagem no estoque.
- O valor da pesagem **não** vira observação de preço: é o total de um pacote, não o preço do produto.
- Fora do carrinho, o código da balança não vira embalagem. O leitor de código explica e continua lendo. O cadastro recusa o código, e o registro de preço o ignora.

## Consequências

- Hortifrúti pesado no mercado entra no carrinho com o valor certo, sem sujar o catálogo.
- Numa loja que grava o peso no código, o valor sai errado. A pessoa corrige digitando o preço, como em qualquer item.
- A etiqueta de gôndola com "/kg" e sem código (a banana na banca, pesada só no caixa) ainda não tem caminho: o preço lido espera um produto bipado que não vem. Resolver isso pede ler a unidade "/kg" na etiqueta (no `PriceTagParser` e no port do `tool/ocr_bench`) e escolher o produto pelo nome lido.
