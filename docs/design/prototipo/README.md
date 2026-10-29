# Protótipo das telas

> **Cópia exportada** do protótipo **Bipa App Telas** publicado no claude.ai (o link está em [identidade-visual.md](../identidade-visual.md)), em 28/10/2026, para agentes e pessoas sem acesso à página. A versão publicada é a fonte da verdade: se as duas divergirem, vale a publicada, e esta cópia deve ser exportada de novo.

Cada tela tem uma imagem (390 px de largura, em 2x) e o HTML de origem em [`fonte/`](fonte/). O HTML abre direto no navegador e traz os valores exatos de espaçamento, tamanho e cor, usando os componentes do [design system](../design-system/README.md) (classes `bipa-*`). As cores vêm dos tokens: no Flutter, use sempre `context.colors.*` (ADR 0009), nunca o hexadecimal do HTML.

## Telas

| Tela | Imagem | No app |
| --- | --- | --- |
| **Início**: busca com bipar, a lista (miniaturas, total estimado e "Ir às compras"), locais como categorias, carrossel de insights, prateleira de "Acabando" e lista "Em casa" com o medidor de nível. Tocar na linha abre o editor: o stepper, "Na lista" e "⋯" (mais do item: local, "Tirar de casa" e produto). | [Main.png](telas/Main.png) | Feita, sem os insights. O chip "Ter sempre" do editor da linha ainda não está no quadro |
| **Menu do bipar**: o toque longo no botão de bipar abre Modo carrinho, Guardar em casa, Dar baixa em casa e Ler cupom fiscal. | [MenuBipar.png](telas/MenuBipar.png) | Feita, sem "Ler cupom fiscal" |
| **Captura**: a câmera abre direto, com o mercado no topo, a moldura de leitura, o seletor Etiqueta · Código · Cupom, o disparo, "digitar o preço" e o modo carrinho. | [Captura.png](telas/Captura.png) | Feita: a câmera lê ao vivo, como o carrinho, e ainda não tem o modo Cupom; o disparo fotografa a etiqueta no formulário antigo |
| **Confirmação**: folha para conferir e salvar, com o produto, o mercado (tocar troca), o preço em destaque, o lápis para corrigir, "Mais barato aqui" e "Também comprei", que soma ao estoque. | [Confirmacao.png](telas/Confirmacao.png) | Feita |
| **Modo carrinho**: leitura contínua, com a bandeja do que você vai levar, o total e "Terminei". Enquanto o carrinho não alcança a quantidade da lista, o item diz "1 de 2". | [ModoCarrinho.png](telas/ModoCarrinho.png) | Feita |
| **Modo carrinho, preço lido ao vivo**: a etiqueta dentro da moldura é lida sem fotografar. A moldura trava, o chip mostra o preço e o item que o recebeu, e o preço do item na bandeja muda. O chip some sozinho. | [ModoCarrinhoLido.png](telas/ModoCarrinhoLido.png) | Feita (ADR 0012) |
| **Modo carrinho, preço esperando o produto**: o preço lido antes de bipar espera o próximo produto por alguns segundos. O aviso é um botão: tocar escolhe o produto pelo nome lido na etiqueta. | [ModoCarrinhoEsperando.png](telas/ModoCarrinhoEsperando.png) | Feita (ADR 0012) |
| **Modo carrinho, granel sem código**: a etiqueta de gôndola por quilo ("TOMATE ITALIANO R$ 8,99 o kg") não tem código para bipar, então o aviso vira botão: tocar escolhe o produto, já buscado pelo nome lido, e o preço por kg vai para o histórico. Quanto custa sai da etiqueta da balança ou do preço digitado. | [ModoCarrinhoGranel.png](telas/ModoCarrinhoGranel.png) | Feita (ADR 0018) |
| **Fim da compra**: "Terminei" (no carrinho, na Lista ou na notificação) abre esta folha antes de terminar: o total em destaque, quantas embalagens vão para casa, a economia contra o mercado mais barato depois deste (quando há preço de tudo lá) e o que faltou da lista, com a quantidade quando faltou mais de uma ("2× Leite"). "Terminar compra" confirma; o Desfazer continua depois. "Cancelar compra", só texto, desiste depois de confirmar. | [FimDaCompra.png](telas/FimDaCompra.png) | Feita |
| **Início durante a compra**: a barra da compra fica fixa acima da navegação, com o progresso da lista e o total bipado. | [CasaCompra.png](telas/CasaCompra.png) | Feita |
| **Produto**: imagem, nome, código, preço, preço em cada mercado com a idade do preço, histórico de 6 meses, "Em casa" com o "ter sempre" e "Pôr na lista". | [Produto.png](telas/Produto.png) | Visual antigo |
| **Embalagem nova**: ao bipar um código desconhecido, o app sugere o produto ("Arroz branco") e preenche marca e tamanho pela etiqueta; o botão de trocar escolhe outro produto. | [EmbalagemNova.png](telas/EmbalagemNova.png) | Feita (ADR 0013) |
| **Produto com embalagens**: o produto é o que se usa em casa; as embalagens (marca e tamanho) mostram o preço e o preço por kg, e o estoque conta embalagens com o total em kg. | [ProdutoEmbalagens.png](telas/ProdutoEmbalagens.png) | Feita (ADR 0013) |
| **Juntar com…**: no menu da tela do produto, escolher o produto que fica (a busca não oferece criar um novo) e confirmar. O que vai passar para o outro produto é dito com texto, porque não dá para desfazer. | [ProdutoJuntar.png](telas/ProdutoJuntar.png), [ProdutoJuntarConfirmar.png](telas/ProdutoJuntarConfirmar.png) | Feita (ADR 0013) |
| **Mercados**: mapa, a sua lista em cada mercado (com a idade do preço mais antigo e o selo "mais barato" só numa comparação justa) e os mercados perto de você, com "Cadastrar mercado" no fim da lista. | [Mercados.png](telas/Mercados.png) | Feita; o mapa é esquemático, sem as ruas desenhadas no quadro, porque o app não usa serviço de mapas |
| **Mercado**: tocar num mercado abre a tela dele, com a distância e a idade dos preços, a ordem das seções aprendida nas compras, os preços recentes e "Ir às compras aqui". | [Mercado.png](telas/Mercado.png) | Feita; a ordem das seções só aparece depois de uma compra no mercado |
| **Folha do preço**: tocar num preço de "Nos mercados" (produto) ou de "Preços recentes" (mercado) abre o valor, a idade e "Corrigir o preço", que grava a correção na data do preço (ADR 0017); o outro botão leva ao mercado ou ao produto. | [PrecoFolha.png](telas/PrecoFolha.png) | Feita (ADR 0017) |
| **Lista**: a prévia da lista, adicionar item (com foto de lista de papel e voz), os itens de sempre e a lista na ordem dos corredores. Um item com mais de uma embalagem mostra a quantidade antes do nome ("3× Leite"), com o preço da unidade; tocar nela a muda, e na compra ela vira "1 de 3" até o carrinho alcançar a lista. A estimativa da prévia diz quantos itens ficaram de fora por falta de preço ("2 sem preço"). | [Lista.png](telas/Lista.png) | Feita, sem foto e voz; as seções seguem a ordem aprendida no mercado (ADR 0014) |
| **Notificação ao vivo**: a compra em andamento na tela de bloqueio e na barra de status (Android 16). | [Notificacao.png](telas/Notificacao.png) | Feita (ADR 0015), sem o número do corredor ao lado da seção: o app ainda não sabe o número |
| **Arrumar o que entrou** (AB5): ao fechar a câmera de "Guardar em casa" depois da primeira carga, uma folha lista o que entrou, agrupado pelo local em que cada item nasceu (o sugerido). Tocar num item abre a escolha do local, com o sugerido já marcado, e o "ter sempre". Cada toque salva na hora, então não há "Salvar": "Pronto" ou arrastar para baixo fecha a folha, e fechar é pular. | [ArrumarEntrou.png](telas/ArrumarEntrou.png) | Aguarda revisão. O protótipo publicado precisa receber o quadro |

## Ainda não desenhado

- **Confirmação com mais de um preço** (ADR 0011): varejo, cartão da loja e atacado da mesma etiqueta. Hoje a captura mostra os outros preços como chips provisórios. A variante "no app" do [PriceTag](../design-system/componentes/PriceTag.png) é um ponto de partida.

## Variantes de componente desenhadas fora do design system

Os quadros que aguardam revisão usam variantes que o design system publicado ainda não tem. Aprovadas, elas entram no guia do componente.

- **FilterChips como escolha** ([ArrumarEntrou.png](telas/ArrumarEntrou.png)): os chips compactos escolhem o local de um item (`role="radio"`), sem contagem, em `surface-sunken` para aparecerem sobre a folha clara.

## Como exportar de novo

As páginas do claude.ai são privadas. Quem tiver acesso (a mesma conta, pelo app do Claude) lê os arquivos `project/*.dc.html` e `project/canvas.json` do protótipo e `project/components/*` do design system e os copia para cá.

As imagens são capturas em 390 px de largura com escala 2, feitas com Playwright e as fontes de `assets/fonts` instaladas: `node tool/prototipo/renderizar.js` refaz todas, e `node tool/prototipo/renderizar.js Lista.dc.html` só as indicadas. O tamanho de cada tela vem de [`fonte/canvas.json`](fonte/canvas.json).

## Como mudar uma tela sem acesso ao claude.ai

Edite o HTML em `fonte/`, gere a imagem com o script acima e atualize a linha da tela nesta página. Uma tela nova entra em `fonte/canvas.json` (posição e tamanho no canvas) e na tabela. Diga na coluna "No app" que a mudança aguarda revisão até o mantenedor aprovar, e avise que o protótipo publicado precisa receber a mesma mudança, que ele continua sendo a fonte da verdade.
