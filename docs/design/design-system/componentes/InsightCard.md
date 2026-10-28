# InsightCard

Um cartão que antecipa o que você vai precisar, calculado no aparelho a partir do seu histórico. Fica no topo da Casa, um por vez.

## Referências

- **Monzo e Revolut:** um número em destaque, toda sugestão explica de onde veio, dá para esconder o cartão, e o tom é tranquilo.
- **Flo (apps de ciclo):** dia do ciclo, duração média e data da última vez são as informações que as pessoas mais procuram, e nos testes elas tinham dificuldade de achá-las num gráfico. Indicadores rápidos de ler funcionaram melhor.

## Do jeito do Bipa

Os números que decidem a ação nunca ficam escondidos numa frase. A frase vira o título, e os dados aparecem como dados:

1. **Título como tipografia, com a arte do produto ao lado:** uma linha pequena em `ink-muted` ("Café acaba na") e o dia em destaque em Manrope 800 32px ("quinta-feira"). À direita, a arte do produto (64px, `surface-sunken`), como num banner. É a referência do iFood: quando o componente é só texto, a tipografia faz o trabalho de deixá-lo gostoso de ler. A pílula opcional (`__pill`) só entra quando traz algo que a régua não mostra.
2. **Régua do ciclo** (`.bipa-days`): um segmento por dia entre a última compra e a próxima prevista. Os dias que passaram ficam em `ink`, o de hoje é maior e tem um halo, e os que faltam ficam em `surface-sunken`. Na Casa, o cartão é todo neutro, e o âmbar só aparece se um dos números estiver abaixo do "ter sempre". Para ciclos de mais de 21 dias, use `.is-long` na régua: os segmentos se juntam numa barra contínua.
3. **Fatos** (`.bipa-facts`): três números grandes com unidade e um rótulo curto embaixo, separados por fios, que se leem como frase: "**10 dias** desde a compra", "**12 dias** de intervalo" e "**1 pct** em casa". O que está baixo fica em `alert-text`.
4. **Fonte atrás do ⓘ:** o botão ao lado do rótulo mostra de onde vem a conta ("Média das suas últimas 4 compras de café. A última foi no sábado, 17/10."). O porquê continua disponível, mas não ocupa a tela.
5. **Uma ação só** ("Pôr na lista", em `ink`). O X dispensa o cartão.

## Variantes

- **Hora de repor** (`--restock`, neutro): régua do ciclo, os três fatos e "Pôr na lista" no botão `--neutral` (`ink`).
- **Economia** (`--saving`, neutro): o valor do mês em `ink` com o mini gráfico de 6 meses e os fatos (itens comprados mais barato, mercados comparados, diferença para o mês anterior, esta em `positive-text`). Na Casa, fica no carrossel junto com os de "Hora de repor".

## Regras

- Na Casa, os insights ficam num **carrossel** (`.bipa-carousel`): um cartão por vez, deslizando para o lado, com pontos embaixo. O ponto atual vira uma pílula em `ink`. No máximo cinco cartões.
- Só aparece com dados suficientes: pelo menos 3 compras do item, ou 5 preços comparáveis no mês. Melhor nenhum cartão do que um palpite.
- Ao dispensar com o X, o cartão desliza 24px para a direita e a altura recolhe. O mesmo insight não volta por 7 dias.
- Linguagem simples, sem jargão nem exclamações.

## Movimento

- Os segmentos da régua crescem em sequência (35ms entre um e outro), e o de hoje pulsa duas vezes.
- Os números dos fatos e o valor da economia contam de 0 até o valor; as barras do gráfico crescem de baixo.

## Acessibilidade

- A régua tem `role="img"` com um rótulo como "Dia 10 de 12 do ciclo de compra de café".
- Os fatos são texto real, lidos na ordem valor e depois rótulo.

## Markup

`article.bipa-insight.bipa-insight--restock|--saving` com `__eyebrow` (com `button.bipa-insight__info`), `__headline` (`small`, `strong` e `__pill`) ou `__number` (`[data-cents]`), `.bipa-days` (`__track[style="--days: N"]` com `i.is-past`/`i.is-today`, e `__ends`), `.bipa-facts` > `.bipa-fact` (`__value` com `[data-count]` e `small`, `__label`, e `.is-low` ou `.is-good` opcionais), `__source`, `__actions` e `button.bipa-insight__dismiss`. Ligue com `Bipa.InsightCard.enhance(el)`: o ⓘ alterna `.is-explained`, e o X emite `bipa:dismiss`. O carrossel é `.bipa-carousel` > `.bipa-carousel__track` (os cartões) + `.bipa-dots` (um `i` por cartão), ligado com `Bipa.Carousel.enhance(el)`.
