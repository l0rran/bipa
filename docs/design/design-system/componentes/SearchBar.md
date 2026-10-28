# SearchBar

A busca no topo da Casa e das listas, com o botão de bipar dentro dela.

## Referências

- **Apps de serviço e de conteúdo** (referências enviadas pelo Wesley): a busca é um campo grande logo abaixo do título, com um botão de ação dentro (filtro ou mapa).
- **iFood:** a busca fica sempre visível no topo da home.

## Do jeito do Bipa

O botão dentro da busca é o **bipar**: em vez de digitar o nome, aponte a câmera para o código de barras. Escrever continua possível, mas é o caminho secundário.

## Anatomia

- Pílula de 52px em `surface`, com a lupa em `ink-muted` à esquerda e o campo em Figtree 500 16px.
- O botão de bipar tem 40px, fundo `surface-sunken` e ícone `ink`. O amarelo fica no botão de bipar da barra de navegação, para não ter dois destaques disputando.
- No foco, ganha `shadow-focus`.

## Regras

- O texto de exemplo diz o que se busca ("Buscar na sua casa", "Buscar produto"), sem instruções longas.
- Os resultados aparecem enquanto se digita, a partir da segunda letra.

## Markup

`label.bipa-search` com o ícone, `input[type=search]` e `button.bipa-search__scan`. `Bipa.SearchBar.enhance(el)` foca o campo ao tocar na barra e emite `bipa:scan` no botão de bipar.
