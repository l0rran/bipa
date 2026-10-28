# PriceTag

A etiqueta de gôndola do Bipa: o jeito único de mostrar um preço em destaque, fiel às etiquetas que a pessoa vê no mercado.

## Referências

- **Etiquetas de gôndola no Brasil:** leis estaduais, como a Lei do Preço Claro no Ceará, obrigam a mostrar o preço por unidade de medida (por kg ou litro) na própria etiqueta.
- **Varejo brasileiro:** preço condicionado é comum (no app ou no clube da rede, "leve 3 pague 2"), e apps de rede como o Pão de Açúcar destacam ofertas personalizadas.

## Do jeito do Bipa

O Bipa mostra o **preço que você realmente vai pagar**, e o OCR lê todas essas variações para comparar mercados com justiça.

## Variantes

- **Normal:** fundo `price`, texto `on-price`, preço em `price` (ou `price-hero` na captura), preço por unidade dentro da etiqueta em 11px, `shadow-raised`. O furo à esquerda lembra a etiqueta pendurada.
- **Promoção (de/por):** "de R$ 32,90" riscado acima; o preço pago grande.
- **Condicionado ao app/clube:** selo invertido (`on-price` com texto `price`) "No app" ou "Clube", o preço condicionado grande e "sem app R$ 18,99" embaixo. Na comparação entre mercados, conta o preço condicionado só se você marcou que participa daquele clube.
- **Leve X pague Y:** selo "Leve 3 pague 2", o preço efetivo por unidade grande ("R$ 5,33") e "cada, levando 3 · un. R$ 7,99" embaixo.
- **Menor preço:** selo `positive-soft`/`positive-text` fora da etiqueta ("Mais barato aqui · −R$ 1,20").

## Regras

- Preço sempre com algarismos tabulares e "R$" a 55% do tamanho dos números.
- O preço por unidade (kg, L, un) aparece sempre que o tamanho da embalagem for conhecido.
- A etiqueta fica sempre reta; o destaque vem do tamanho do preço.

## Movimento

- Ao aparecer, a etiqueta salta de 85% para 100% com mola e o preço conta até o valor.
- O preço antigo é riscado da esquerda para a direita; o selo de menor preço entra deslizando.

## Markup

`.bipa-tag` (+ `--hero`) com `__flag`, `__was`, `__value` (número em `[data-cents]`), `__unit` e `__alt`. `Bipa.PriceTag.play(el)` toca a entrada.

## Histórico de preço

`.bipa-history`: uma linha em `ink` com a área em `surface-sunken` e o ponto de hoje na cor da etiqueta (`price`). Mais barato fica mais baixo. Embaixo, os meses. O rótulo acessível diz o intervalo ("de R$ 9,49 a R$ 7,99"). A linha se desenha ao aparecer.

Referência: o Preço da Hora (Bahia) abre o gráfico do histórico direto do resultado da busca.
