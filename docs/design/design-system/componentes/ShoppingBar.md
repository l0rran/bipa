# ShoppingBar

A compra em andamento. Enquanto você está no mercado, a barra fica fixa acima da navegação em todas as abas, com o progresso da lista e o total do que já foi bipado.

## Referências

- **iFood:** a sacola fica fixa no rodapé enquanto há itens, com o total e o atalho para fechar o pedido.
- **Walmart Scan & Go:** o total acumulado sempre à vista durante a compra.
- **Android 16 (Live Updates):** a mesma informação também aparece como notificação ao vivo, fora do app.

## Anatomia

- Pílula de 60px em `brand` com texto `on-brand` e `shadow-float`.
- **Ícone** do carrinho num círculo translúcido.
- **Texto:** "3 de 7 itens" em Manrope 800 16px e, embaixo, o total e o mercado ("R$ 32,10 · Atacarejo Vila Nova"). O total vem primeiro porque é o que não pode ser cortado.
- **"Continuar":** pílula `ink` com texto `surface`, que volta para o modo carrinho.
- **Progresso:** um fio de 3px na base da barra, que enche conforme os itens da lista vão sendo bipados.

## Regras

- Aparece quando a pessoa toca em "Ir às compras" ou começa a bipar num mercado, e some ao terminar a compra.
- Fica entre o conteúdo e a navegação, e o conteúdo ganha espaço embaixo para não ficar escondido.
- O total é real (o que foi bipado), sem "≈".

## Movimento

- Entra subindo com mola. O fio de progresso e o total animam a cada item bipado.

## Markup

`a.bipa-cartbar` com `__icon`, `__text` (`strong` e `span` com o total em `[data-cents]`), `__go` e `__progress[style="--p: N"]` > `i`. `Bipa.ShoppingBar.enhance(el)` devolve `update({ done, total, cents })`.
