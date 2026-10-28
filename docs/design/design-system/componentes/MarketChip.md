# MarketChip

Chip de mercado com distância; ganha destaque quando o usuário está dentro dele.

## Estados

- **Perto:** fundo `surface-sunken`, ícone de loja, nome e distância em `caption`.
- **Você está aqui** (dentro do raio de presença): fundo `place`, texto `on-place`, ícone de pino. Aparece no topo da captura de preço.
- **Sem localização:** só o nome, sem distância.

## Regras

- Distância em metros abaixo de 1 km ("120 m"), em km com uma casa acima ("1,5 km").
- Toque abre a seleção de mercado; o chip nunca é só decorativo.

## Movimento

- Listas de chips entram em cascata (60ms entre cada, `fade-up` de 8px).
- No chip "você está aqui", um ponto pulsa como radar a cada 1,6s, no lugar do ícone de pino.

## Vidro (sobre a câmera)

`.bipa-chip--glass`: fundo escuro translúcido com desfoque e texto `on-camera`, para o mercado atual no topo da câmera e do modo carrinho. A cor de lugar (`place`) fica só na tela de mercados.

## Preço por mercado

`.bipa-mprices` > `.bipa-mprice`: miniatura do mercado, nome, a **idade do preço** ("há 5 dias", com relógio) e o valor à direita. O menor preço ganha "menor preço" em `positive-text`. Preço com mais de 30 dias fica com a idade em `alert-text`, porque pode estar desatualizado.

Referências: os apps de nota fiscal das secretarias da Fazenda (Menor Preço, Preço da Hora) mostram sempre a data da última venda, porque preço muda rápido.

## Sua lista em cada mercado

`.bipa-compare` > `.bipa-compare__row`: o total estimado da lista em cada mercado, com uma barra proporcional ao mais caro. O mais barato fica com a barra em `ink` e "mais barato" em `positive-text`.

Referência: o Basket (EUA) compara a lista inteira entre mercados, porque a mesma compra pode variar de 30 a 40% entre lojas.
