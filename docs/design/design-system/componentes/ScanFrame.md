# ScanFrame

O visor da câmera: mostra que a leitura está ativa, onde mirar e confirma a captura de um jeito que se percebe mesmo no barulho do mercado.

## Referências

- **Scandit:** confirmar com som, vibração e visual juntos, e esperar 150ms entre a confirmação e fechar a câmera; mais rápido que isso parece que "não leu".
- **Open Food Facts:** câmera abre na hora com moldura, linha de mira e uma instrução curta; lanterna sempre à mão; produto desconhecido não é erro.

## Do jeito do Bipa

1. **Procurando:** moldura de cantos em `on-camera` respirando, laser `brand` varrendo de cima a baixo, dica "Centralize o código ou a etiqueta".
2. **Travou:** a moldura encolhe até o código com mola e os cantos ficam `positive-soft`; o laser some; a dica mostra o código lido.
3. **Capturou:** clarão de 260ms, vibração leve e o bip sonoro; 150ms depois, o evento de captura e a folha "Bipou!" (ou o item cai na bandeja, no modo carrinho).

## Regras

- Fundo `camera` e texto `on-camera` iguais nos dois temas.
- Lanterna, digitar manualmente e galeria ficam sempre visíveis na barra inferior.
- Em pouca luz (sensor de luminosidade), a dica muda para "Está escuro. Ligue a lanterna" e o botão da lanterna pulsa uma vez.
- O som segue o volume de mídia e pode ser desligado nas configurações; a vibração respeita o sistema.

## Markup

`.bipa-viewfinder` com `.bipa-frame` (quatro `.bipa-frame__corner--tl|tr|bl|br` e `.bipa-frame__laser`), `.bipa-viewfinder__flash` e `.bipa-viewfinder__hint`. `Bipa.ScanFrame.enhance(el)` devolve `{ search(), lock(code) }` e emite `bipa:captured`.
