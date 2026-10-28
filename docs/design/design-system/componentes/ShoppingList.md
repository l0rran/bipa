# ShoppingList

A lista de compras: adicionar itens com um toque e percorrer o mercado na ordem dos corredores.

## Referências

- **Bring!:** monta a lista tocando em ícones grandes por categoria, sem digitar.
- **AnyList:** reorganiza a lista conforme a disposição dos corredores de cada mercado, a partir de categorias configuradas por loja. A quantidade fica nos detalhes do item, abertos pelo lápis, com um stepper ([ajuda do AnyList](https://help.anylist.com/articles/add-item-quantity/)).

## Do jeito do Bipa

- **Comprados com frequência:** a grade não é um catálogo genérico; são os itens do seu histórico, ordenados pela chance de acabarem logo. Um toque adiciona (fica `brand-soft` com um check).
- **Ordem dos corredores aprendida, sem configurar nada:** o app registra a sequência em que você bipa e marca itens em cada mercado e, quando o GPS detecta o mercado, a lista vem na ordem do seu percurso. Tudo calculado no aparelho.
- **Quantidade à mão:** "3×" antes do nome, em `ink-muted`, e tocar nele a muda, sem tela de detalhes. O campo de adicionar entende "2 leite", "leite 2" e "2x leite".
- **"1 de 3" na compra:** o item só fica marcado quando o carrinho alcança a quantidade da lista. Antes disso, a quantidade vira "1 de 3", e o que faltou continua na lista depois do "Terminei".
- **Preço esperado** ao lado de cada item: o último preço naquele mercado ("~" quando é estimado pelo preço por kg).
- **Progresso** no topo: "1 de 6" e uma barra `brand`. Durante a compra, o mesmo progresso aparece numa notificação ao vivo do Android (fase 1).

## Anatomia

- Grade de 4 colunas de blocos quadrados em `surface`, raio `radius-md`, ícone de traço 28px e rótulo em 12px.
- Lista em `surface` com raio `radius-lg`; cabeçalhos de corredor em 12px maiúsculo `ink-muted`.
- Item: caixa de seleção de 24px com raio 8 (concêntrico ao cartão), quantidade (quando é mais de uma, com área de toque de 48px), nome, preço esperado em `ink-muted`.

## Movimento

- Marcar: a caixa enche de `brand` e o check se desenha, o nome é riscado da esquerda para a direita, e 260ms depois o item desce para o fim do corredor (animação FLIP: os vizinhos sobem para ocupar o espaço).
- A barra de progresso cresce com mola; o contador rola.
- Bloco da grade encolhe para 92% ao toque; o check aparece com mola.

## Markup

`.bipa-quick` com `button.bipa-quick__tile[aria-pressed]`; `.bipa-progress` (`__label` com `.bipa-roll.bipa-progress__done`, `__fill`); `.bipa-list` com `__aisle` e grupos de `button.bipa-list__item` (`.bipa-check`, `__name`, `__price`). `Bipa.ShoppingList.enhance(root)`.
