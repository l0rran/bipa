# Protótipo das telas

> **Cópia exportada** do protótipo **Bipa App Telas** publicado no claude.ai (o link está em [identidade-visual.md](../identidade-visual.md)), em 28/10/2026, para agentes e pessoas sem acesso à página. A versão publicada é a fonte da verdade: se as duas divergirem, vale a publicada, e esta cópia deve ser exportada de novo.

Cada tela tem uma imagem (390 px de largura, em 2x) e o HTML de origem em [`fonte/`](fonte/). O HTML abre direto no navegador e traz os valores exatos de espaçamento, tamanho e cor, usando os componentes do [design system](../design-system/README.md) (classes `bipa-*`). As cores vêm dos tokens: no Flutter, use sempre `context.colors.*` (ADR 0009), nunca o hexadecimal do HTML.

## Telas

| Tela | Imagem | No app |
| --- | --- | --- |
| **Início**: busca com bipar, a lista (miniaturas, total estimado e "Ir às compras"), locais como categorias, carrossel de insights, prateleira de "Acabando" e lista "Em casa" com o medidor de nível. | [Main.png](telas/Main.png) | Feita, sem os insights |
| **Menu do bipar**: o toque longo no botão de bipar abre Modo carrinho, Dar baixa em casa e Ler cupom fiscal. | [MenuBipar.png](telas/MenuBipar.png) | Falta |
| **Captura**: a câmera abre direto, com o mercado no topo, a moldura de leitura, o seletor Etiqueta · Código · Cupom, o disparo, "digitar o preço" e o modo carrinho. | [Captura.png](telas/Captura.png) | Visual antigo |
| **Confirmação**: folha para conferir e salvar, com o produto, o preço em destaque, o lápis para corrigir, "Mais barato aqui" e "Também comprei", que soma ao estoque. | [Confirmacao.png](telas/Confirmacao.png) | Visual antigo |
| **Modo carrinho**: leitura contínua, com a bandeja do que você vai levar, o total e "Terminei". | [ModoCarrinho.png](telas/ModoCarrinho.png) | Feita |
| **Modo carrinho, preço lido ao vivo**: a etiqueta dentro da moldura é lida sem fotografar. A moldura trava, o chip mostra o preço e o item que o recebeu, e o preço do item na bandeja muda. O chip some sozinho. | [ModoCarrinhoLido.png](telas/ModoCarrinhoLido.png) | Feita (ADR 0012) |
| **Modo carrinho, preço esperando o produto**: o preço lido antes de bipar espera o próximo produto por alguns segundos. | [ModoCarrinhoEsperando.png](telas/ModoCarrinhoEsperando.png) | Feita (ADR 0012) |
| **Início durante a compra**: a barra da compra fica fixa acima da navegação, com o progresso da lista e o total bipado. | [CasaCompra.png](telas/CasaCompra.png) | Feita |
| **Produto**: imagem, nome, código, preço, preço em cada mercado com a idade do preço, histórico de 6 meses, "Em casa" com o "ter sempre" e "Pôr na lista". | [Produto.png](telas/Produto.png) | Visual antigo |
| **Embalagem nova**: ao bipar um código desconhecido, o app sugere o produto ("Arroz branco") e preenche marca e tamanho pela etiqueta; o botão de trocar escolhe outro produto. | [EmbalagemNova.png](telas/EmbalagemNova.png) | Feita (ADR 0013) |
| **Produto com embalagens**: o produto é o que se usa em casa; as embalagens (marca e tamanho) mostram o preço e o preço por kg, e o estoque conta embalagens com o total em kg. | [ProdutoEmbalagens.png](telas/ProdutoEmbalagens.png) | Feita (ADR 0013) |
| **Juntar com…**: no menu da tela do produto, escolher o produto que fica (a busca não oferece criar um novo) e confirmar. O que vai passar para o outro produto é dito com texto, porque não dá para desfazer. | [ProdutoJuntar.png](telas/ProdutoJuntar.png), [ProdutoJuntarConfirmar.png](telas/ProdutoJuntarConfirmar.png) | Feita (ADR 0013) |
| **Mercados**: mapa, a sua lista em cada mercado e os mercados perto de você. | [Mercados.png](telas/Mercados.png) | Visual antigo |
| **Lista**: a prévia da lista, adicionar item (com foto de lista de papel e voz), os itens de sempre e a lista na ordem dos corredores. | [Lista.png](telas/Lista.png) | Feita, sem foto e voz; as seções seguem a ordem aprendida no mercado (ADR 0014) |
| **Notificação ao vivo**: a compra em andamento na tela de bloqueio e na barra de status (Android 16). | [Notificacao.png](telas/Notificacao.png) | Feita (ADR 0015), sem o número do corredor ao lado da seção: o app ainda não sabe o número |

## Ainda não desenhado

- **Confirmação com mais de um preço** (ADR 0011): varejo, cartão da loja e atacado da mesma etiqueta. Hoje a captura mostra os outros preços como chips provisórios. A variante "no app" do [PriceTag](../design-system/componentes/PriceTag.png) é um ponto de partida.

## Como exportar de novo

As páginas do claude.ai são privadas. Quem tiver acesso (a mesma conta, pelo app do Claude) lê os arquivos `project/*.dc.html` do protótipo e `project/components/*` do design system e os copia para cá. As imagens são capturas em 390 px de largura com escala 2, feitas com Playwright e as fontes de `assets/fonts` instaladas.
