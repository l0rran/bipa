# FilterChips

Filtro de uma escolha só. Tem duas formas: **categorias** com arte grande e nome embaixo, para o Início, e **chips** compactos, para listas longas como Produtos.

## Referências

- **iFood:** categorias como imagem com o nome embaixo, numa fileira que rola para o lado. Não há texto solto.
- **Material 3 (filter chips):** chips de uma escolha, com o escolhido preenchido.

## Do jeito do Bipa

- **Categorias** (`.bipa-filter--tiles`): arte de 64px em `surface` com ícone `ink`. A contagem fica num selo `surface-sunken` no canto. Ao escolher, a arte fica cheia em `ink` e cresce levemente com mola. No Início não há cor de lugar: o `place` fica para a tela de mercados.
- **Chips** (`.bipa-filter`): pílula de 36px com ícone, nome e contagem. O escolhido fica em `ink`.
- O local sai das linhas da lista: quem quer ver só a geladeira toca na categoria.

## Regras

- Sempre há um "Tudo" primeiro, com o total.
- Os locais vêm do estoque da pessoa (Despensa, Geladeira, Banheiro, Limpeza...), na ordem de quantos itens têm.
- A fileira rola para o lado; o último item aparece pela metade para mostrar que há mais.

## Markup

`.bipa-filter` (+ `--tiles`) com `button[data-value][aria-pressed]`. Nas categorias, o conteúdo é `.bipa-filter__art` (ícone + `small` com a contagem) seguido do nome. Com `data-target`, esconde os `[data-place]` de outro local dentro do alvo. `Bipa.FilterChips.enhance(el)` emite `bipa:filter` com `{ value }`.
