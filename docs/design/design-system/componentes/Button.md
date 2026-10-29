# Button

> Referência: Material 3 Expressive (botões que mudam de forma ao pressionar e alternar, grupos conectados, indicador de carregamento que se transforma). Do jeito do Bipa: a pílula vira um retângulo arredondado ao pressionar, e o carregamento são as quatro barras de código pulsando.

Botões em pílula para ações; o principal é amarelo (`brand`) com texto escuro e levemente elevado. O neutro (`--neutral`, em `ink`) é o das ações comuns.

## Variantes

- **Principal:** fundo `brand`, texto `on-brand` e `shadow-raised`. Um por tela, no terço inferior.
- **Secundário:** fundo `surface`, contorno `stroke-control` em `line`, sem sombra. Ações alternativas ("Salvar e bipar outro").
- **Texto:** só o rótulo em `ink`, para ações de baixa prioridade ("Ver produto e preços").

## Regras

- Altura 56px (principal e secundário) e raio `radius-pill`. Rótulo no estilo `label`, ícone opcional à esquerda.
- Pressionado: encolhe para 96% e o raio vai de 28 para 14px (pílula → retângulo arredondado), com mola; a sombra some.
- Desabilitado: fundo `surface-sunken`, texto `ink-muted`, sem contorno nem sombra.
- O rótulo diz o que acontece: verbo + objeto ("Salvar preço"), nunca "OK".
- **Ações que apagam ou descartam** ("Apagar mercado", "Cancelar compra", "Tirar de casa") se confirmam num diálogo, no botão neutro em `ink`, nunca no principal: o amarelo chama para salvar e bipar, não para apagar. O coral fica só para o estoque abaixo do "ter sempre".

## Movimento

- Toque: encolhe para 96% com `easing-spring` em `duration-fast`.
- Salvar: o rótulo sobe e some, entra um indicador girando; ao concluir, o botão fica `positive-text`, o check se desenha e aparece "Salvo". Depois de 1,4s volta ao normal.
- O botão nunca muda de largura entre os estados.

## Markup

`<button class="bipa-btn bipa-btn--primary">` com `.bipa-btn__label`, `.bipa-btn__spinner` e `.bipa-btn__done`; `Bipa.Button.enhance(el)` liga os estados.

## Carregando

As quatro barras de código (o símbolo antigo) pulsam em sequência (`.bipa-loader`), em vez de um círculo girando. O mesmo indicador serve para qualquer espera curta no app.

## Seletor segmentado

Grupo conectado de opções exclusivas (`.bipa-segmented`), com o fundo da opção ativa deslizando com mola até a escolhida. Variante `--camera` translúcida para usar sobre a câmera (Etiqueta · Código · Cupom fiscal). `Bipa.Segmented.enhance(el)` emite `bipa:select`.
