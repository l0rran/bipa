# 0012. Analisar os quadros da câmera no modo carrinho com o plugin camera e o ML Kit

- Status: Aceito
- Data: 2026-10-28

## Contexto

O modo carrinho deixa a câmera aberta durante a compra. Hoje ela usa o `mobile_scanner`, que só entrega códigos de barras. Para ler o preço da etiqueta ao vivo, sem fotografar, o OCR precisa rodar nos quadros da câmera.

As forças em jogo:

- **Etiqueta com código.** Muitas etiquetas de gôndola trazem o código de barras do produto. Se o código e o texto forem lidos em quadros diferentes, a etiqueta conta como mais uma unidade bipada antes que o preço apareça.
- **Etiquetas vizinhas.** Na gôndola, a câmera vê várias etiquetas ao mesmo tempo. Ler o quadro inteiro mistura os preços.
- **Um quadro não basta.** O OCR de um quadro tremido erra dígitos ("27,90" vira "21,90").
- **Bateria e calor.** O OCR é mais caro que a leitura de código, e a compra pode durar meia hora.

As opções consideradas foram estas:

1. **`mobile_scanner` com `returnImage`.** Ele só devolve a imagem quando acha um código de barras, e em JPEG. A etiqueta sem código nunca seria lida.
2. **Um plugin nativo com o `ImageAnalysis` do CameraX.** Seria o mais eficiente, mas traria código Kotlin para manter, e a nuvem dos agentes não compila nem Dart.
3. **O plugin oficial `camera` com `startImageStream` e o ML Kit nos bytes do quadro.** É o caminho do exemplo oficial do `google_ml_kit_flutter`. Os dois reconhecedores já são dependências do app (ADR 0005).

## Decisão

- **No modo carrinho, a câmera passa a ser o plugin `camera`**, com o fluxo de quadros em NV21 no Android, resolução `high` e sem áudio. As outras telas que só leem código continuam com o `mobile_scanner`.
- **O código de barras e o texto são lidos no mesmo quadro**, pelo ML Kit Barcode Scanning e pelo Text Recognition, sobre a mesma `InputImage`. Assim, código e preço juntos indicam uma etiqueta: o preço vai para aquele produto, e o código não soma uma unidade.
- **Só um quadro é analisado por vez.** Os que chegam durante a análise são descartados, e o ritmo segue a velocidade do aparelho.
- **Só o texto dentro da moldura conta.** O retângulo da moldura na tela é convertido para as coordenadas da imagem (preview em `cover` e rotação do sensor), e as linhas fora dele são descartadas antes do `PriceTagParser`. O parser não muda.
- **Um preço só vale depois de se repetir:** o mesmo preço de varejo em 3 quadros dentro de 1,5 s. Depois de aceito, aquele preço só volta a valer quando sumir da moldura por 1 s.
- **O destino do preço é uma regra de domínio**, testada sem câmera:
  - etiqueta com código conhecido: o preço vai para esse produto, se ele já está no carrinho; senão, espera ele ser bipado, sem entrar sozinho;
  - etiqueta com código que nenhum produto tem: espera o produto ser cadastrado e bipado com esse código;
  - sem código: vai para o último item bipado, se ele entrou há até 20 s e o preço dele ainda não foi firmado (lido ao vivo, digitado ou fotografado);
  - senão, o preço espera o próximo produto bipado, por até 20 s.
- **O bipe espera um instante.** O código precisa aparecer sem preço em 2 quadros, o primeiro com pelo menos 0,6 s. É o tempo de o OCR achar o preço de uma etiqueta cujo código foi lido antes. Um produto segurado na frente de uma etiqueta conta como etiqueta, até o preço sair da moldura.
- **Ao abrir a câmera, o que já está na moldura não conta** durante o primeiro segundo: vale como já lido e só volta a valer depois de sair da moldura. Assim, voltar do cadastro com o produto na frente não soma outra unidade.
- **Com mais de um código na moldura**, vale o mais perto do centro dela.
- **Duas etiquetas vizinhas com o mesmo preço** valem as duas quando têm códigos diferentes. Sem código, valem uma vez só, se lidas sem pausa entre elas.
- **Na dúvida, nada é escolhido.** A leitura ao vivo é ignorada quando a etiqueta tem vários preços do mesmo tamanho ou só traz preço com condição (clube, cartão, atacado). Para essas etiquetas, continua valendo o disparo, que fotografa a etiqueta e abre a confirmação.
- A análise para quando o app vai para o fundo e quando outra tela usa a câmera.

## Consequências

- Uma dependência nova (`camera`), e duas pilhas de câmera no app: `mobile_scanner` nas telas de código e `camera` no modo carrinho.
- Algumas regras que o `mobile_scanner` já trazia passam a ser nossas: a conversão do quadro para `InputImage`, a rotação, a lanterna (`FlashMode.torch`) e o ciclo de vida.
- No Android, o CameraX pode escolher proporções diferentes para a prévia e para os quadros analisados. Por isso o recorte é calculado a partir do tamanho do quadro analisado, e a margem em volta da moldura absorve a diferença. Se ela for grande demais em algum aparelho, o recorte passa a considerar as duas proporções.
- O recorte da moldura, o consenso entre quadros e o destino do preço são Dart puro e têm testes. O que depende do aparelho (rotação, formato do quadro, desempenho) só se confere no celular.
- O consumo de bateria precisa ser medido numa compra real. Se pesar, o OCR pode rodar em quadros alternados, sem mudar o resto.
- A leitura ao vivo é uma sugestão, como toda leitura (ADR 0005). O preço do item continua corrigível com um toque.

## Atualização (28/10/2026)

Todas as telas que leem código passaram a usar a mesma câmera ao vivo (o leitor das buscas e do formulário do produto também), e o `mobile_scanner` saiu do app. O disparo fotografa pela própria câmera ao vivo, e a etiqueta da foto segue o caminho da leitura ao vivo: o formulário "Bipar preço" e o `image_picker` também saíram.
