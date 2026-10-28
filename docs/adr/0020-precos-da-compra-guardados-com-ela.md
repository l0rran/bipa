# 0020. Preços da compra guardados com ela

- Status: Aceito
- Data: 2026-10-28

## Contexto

Os preços lidos no carrinho só viravam observações (ADR 0007) quando a compra tinha mercado. Sem mercado, por exemplo na primeira compra ou com a localização negada, eles esperavam numa lista em memória da tela do carrinho. A análise de UX de 28/10 apontou três consequências (CE1 e D1):

- **Preços perdidos.** Fechar o carrinho, terminar pela Lista ou pela notificação, ou o Android encerrar o app, apagava os preços que esperavam o mercado, sem aviso. Só o "Terminei" do próprio carrinho perguntava o mercado.
- **Correção perdida.** A ligação entre o item e a observação gravada também ficava em memória. Depois de reabrir o carrinho, digitar o preço certo não corrigia a leitura errada (ADR 0017), que continuava no histórico.
- **Preços no mercado errado.** A compra começa no mercado mais perto num raio de 150 m. Com duas lojas vizinhas, os preços iam para a vizinha, e trocar o mercado no chip não os levava junto.

## Decisão

- Cada preço lido ou digitado no carrinho é guardado **com a compra**, na tabela `trip_prices` (esquema v13): o produto, a embalagem, o preço, a origem, os outros preços da etiqueta (ADR 0011), a hora da leitura e o id da observação, quando já existe. É uma linha por item da compra (a chave do item, como no carrinho), com o último preço dele.
- O caso de uso `RecordTripPrice` grava o preço:
  - com mercado, registra a observação na hora e guarda o id dela. Se o item já tinha uma, a nova a corrige (`supersedes`, ADR 0017);
  - sem mercado, a linha fica pendente;
  - a mesma etiqueta lida de novo, com o mesmo preço, não repete a observação;
  - só corrige no mesmo mercado: quem passou por duas lojas tem um preço certo em cada uma;
  - no mesmo mercado, uma etiqueta não corrige um preço digitado, que já é a correção dela;
  - o preço por quilo do granel tem chave própria no item, e não corrige nem é corrigido pelo total da pesagem (ADR 0018).
- O caso de uso `SetTripMarket` muda o mercado da compra e, na mesma transação:
  - registra as pendentes no mercado escolhido, com a hora em que foram lidas (`RegisterPriceInput.observedAt`);
  - se a pessoa pedir, leva para o novo mercado os preços gravados no mercado que está sendo trocado (não os deixados numa loja anterior): cada um ganha uma correção no novo mercado (`supersedes`), sem apagar nada;
  - escolher de novo o mesmo mercado só grava as pendentes. A localização do "Ir às compras" também passa por aqui.
- Trocar o mercado com preços já gravados pergunta uma vez: "Levar os 12 preços lidos para o Assaí?". Quem foi a duas lojas na mesma compra deixa os preços onde estão.
- O "Terminei", de qualquer lugar (carrinho, Lista ou notificação), pergunta o mercado quando há preços pendentes e a compra não tem mercado.
- Cancelar a compra apaga as linhas dela (chave estrangeira em cascata). As observações já gravadas ficam, porque são preços vistos de verdade.

## Consequências

- Nenhum preço lido no carrinho depende mais da tela estar aberta: ele sobrevive ao fechamento do carrinho, à troca de aba e ao fim do processo.
- Corrigir um preço funciona depois de reabrir o carrinho, e trocar o mercado leva o histórico junto, em vez de deixá-lo na loja vizinha.
- A observação continua imutável e só inserida (ADR 0007): mover é corrigir.
- **Limites:**
  - ao mover para outro mercado, os outros preços da etiqueta (cartão e atacado) entram também no novo mercado, mas os do anterior não são corrigidos, porque a correção vale só para o preço principal (ADR 0017);
  - as linhas das compras terminadas ficam no banco. São poucas, e o desfazer do "Terminei" precisa delas;
  - apagar a embalagem no meio da compra muda a chave do item, e o próximo preço dele vira outra linha.

## Atualização (28/10/2026)

O disparo do carrinho passou a fotografar pela câmera ao vivo, e o preço da foto segue o mesmo caminho da etiqueta lida (`RecordTripPrice`). Com isso, nenhum preço do carrinho é gravado fora da tabela.
