# Kit para testar o modo carrinho no emulador

O emulador do Android não tem câmera de verdade. A câmera traseira **VirtualScene** mostra uma sala 3D com duas imagens trocáveis, uma na parede e outra na mesa. Com as imagens desta pasta, dá para conferir a leitura ao vivo (ADR 0012) sem um celular.

| Imagem | O que tem |
| --- | --- |
| [`imagens/parede.png`](imagens/parede.png) | Três etiquetas de gôndola: **Arroz** R$ 27,90 sem código; **Café** R$ 18,99 com o código do café; **Biscoito** com dois preços do mesmo tamanho, sem rótulo |
| [`imagens/mesa.png`](imagens/mesa.png) | As "embalagens": o código do arroz (`7896006711155`) e o do café (`7891089200015`) |

Para gerar de novo: `python3 tool/kit_emulador/gerar.py` (usa o desenho de etiquetas de `tool/ocr_bench`).

## Configurar o emulador

1. No Android Studio, abra **Tools > Device Manager** e edite o dispositivo (lápis) ou crie um novo. A imagem do sistema precisa ser x86 ou x86_64, API 27 ou mais nova.
2. Clique em **Show Advanced Settings** e ponha **Camera Back** em **VirtualScene**. Salve e inicie o emulador.
3. No emulador, abra **Extended controls** (os três pontos da barra lateral) > **Camera** > **Virtual scene images**. Ponha `parede.png` na parede e `mesa.png` na mesa.
4. Para andar na sala, clique na tela do emulador, segure **Alt** (no Windows e no Linux; **Option** no macOS) e use **W/A/S/D** (frente, lados, trás), **Q/E** (descer, subir) e o mouse para girar. Em versões mais novas do emulador, a tecla é **Shift**. As imagens ficam na sala de jantar, atrás da porta que está às costas da posição inicial.
   - As teclas costumam funcionar só com o emulador em **janela própria**. Se ele abre dentro do Android Studio (painel *Running Devices*), desmarque **Settings > Tools > Emulator > Launch in the Running Devices tool window** e reinicie o emulador.
   - Sem teclado, dá para mover a câmera por **Extended controls > Virtual sensors**, na aba da posição do aparelho (*Device Pose*).

## Preparar o app

1. Cadastre os produtos **Arroz Tio João 5 kg** (`7896006711155`) e **Café Pilão 500 g** (`7891089200015`). Ou deixe para o modo carrinho oferecer "Cadastrar" quando bipar.
2. Na Lista, toque em **Ir às compras**, escolha um mercado e abra o **Carrinho**.

## O que conferir

| Faça | Esperado |
| --- | --- |
| Bipe o arroz na mesa e, em até 20 s, aponte para a etiqueta do arroz | O chip mostra "R$ 27,90 · Arroz…", e o preço do arroz na bandeja ganha um anel |
| Aponte para a etiqueta do arroz antes de bipar | O chip mostra "R$ 27,90 · bipe o produto"; ao bipar o arroz, ele entra com R$ 27,90 |
| Aponte para a etiqueta do café (com código) | O preço vai para o café, se ele está no carrinho; o código da etiqueta **não** soma uma unidade |
| Aponte para a etiqueta do biscoito | Nada acontece: com dois preços sem rótulo, a leitura ao vivo não escolhe |
| Leia o arroz e logo depois aponte para a etiqueta do biscoito ou do café | O preço do arroz não muda |
| Saia do app e volte | A câmera fecha no fundo e volta ao reabrir |

## Limites

- A sala virtual tem resolução baixa: chegue perto da etiqueta, que ela ocupe a moldura.
- Bateria, calor, foco e reflexo só se conferem num celular de verdade. Com o celular ligado no USB e a depuração ativada, `flutter run` instala o app nele.
- Outra saída é pôr **Camera Back** em **Webcam0** e apontar a câmera do computador para as imagens, na tela de outro aparelho ou impressas.
