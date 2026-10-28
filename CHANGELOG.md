# Changelog

Todas as mudanças relevantes do projeto. O formato segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e as versões seguem o [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Não lançado]

### Adicionado
- Documentação de arquitetura, ADRs, guia de contribuição e roadmap.
- Identidade visual (Bipa Design System) e protótipo das telas principais.
- Novo Início: busca com bipar, locais como categorias, prateleira de "Acabando" com cartões e medidor de nível, e lista "Em casa" com editor ao tocar e baixa por gesto com Desfazer.
- Barra de navegação de vidro com o botão de bipar no centro e a aba Lista (por enquanto, um aviso).
- Design system no código: paleta semântica gerada de `design/tokens.json`, tema do Material 3 e fontes embutidas.
- Miniatura do produto com foto ou ícone da categoria, e o campo de foto no banco (esquema 2).
- Textos de todas as telas em ARB (`flutter gen-l10n`).
- Preços com condição (ADR 0011): a etiqueta de atacarejo vira até três preços (varejo, cartão da loja e atacado a partir de N unidades), todos salvos e mostrados no histórico. O esquema vai à versão 3.
- Lista de compras: a aba Lista com progresso, adicionar com sugestões, itens de sempre, seções do mercado, preço esperado e desfazer; a prévia da lista no Início; e "Pôr na lista" no cartão de Acabando e no gesto para a direita da linha. O esquema vai à versão 4.
- Modo compra: "Ir às compras" começa a compra e detecta o mercado; a barra da compra mostra o progresso e o total acima da navegação; registrar o preço de um item da lista o marca; "Terminei" leva o comprado ao estoque, com Desfazer. O esquema vai à versão 5.
- Modo carrinho: a câmera fica aberta e cada código lido entra no carrinho com o último preço do mercado; a bandeja mostra o "levar", o preço (que dá para digitar) e o total do que vai ser levado. O "Terminei" leva ao estoque a quantidade bipada. O esquema vai à versão 6. O preço da etiqueta fotografada entra no carrinho, e marcar ou desmarcar na lista decide se o item vai ser levado.
- Etiqueta lida ao vivo no modo carrinho (ADR 0012): a câmera lê o código e a etiqueta no mesmo quadro, só dentro da moldura. O preço que se repete em quadros seguidos vai para o último item bipado ou espera o próximo produto, e um chip mostra o que foi lido. Etiqueta com código não soma unidade. O modo carrinho passa a usar o plugin `camera`.
- Produto e embalagens (ADR 0013): o produto é o que se usa em casa ("Arroz branco") e cada código de barras é uma embalagem, com marca e tamanho. Bipar um código novo abre a folha "Embalagem nova", com o produto, a marca e o tamanho sugeridos pela etiqueta. O carrinho guarda a embalagem, o estoque guarda cada compra como um lote e mostra o total ("15 kg em casa"), o "Usei um" tira o lote mais antigo, o Desfazer tira exatamente o que entrou, e a tela do produto compara as embalagens pelo preço por kg. "Juntar com…" une produtos cadastrados uma vez por marca. O esquema vai à versão 7.
- Gráfico dos últimos 6 meses na tela do produto: o menor preço de cada dia, por kg quando as embalagens têm tamanho, sem os preços de cartão e de atacado.
- A lista aprende a ordem das seções em cada mercado (ADR 0014): no "Terminei", as seções visitadas ficam na ordem em que foram percorridas, e a lista da próxima compra naquele mercado segue esse percurso. O esquema vai à versão 8. O chip do mercado ao lado do título da Lista mostra e troca o mercado: o da compra, ou o escolhido para a próxima (por padrão, o da última compra).
- Notificação ao vivo da compra (ADR 0015): na tela de bloqueio e como chip na barra de status do Android 16, com o progresso, o total, a próxima seção e os botões Bipar, Lista e Terminei. Antes do Android 16, é uma notificação fixa com barra de progresso. Primeiro código nativo do app (Kotlin) e androidx.core 1.17.
- Nova tela de Mercados, como no protótipo: busca, mapa esquemático com os mercados em volta, quanto a lista custa em cada mercado (com ressalva quando faltam preços) e os mercados do mais perto ao mais longe, com a idade dos preços.
- Tela do mercado: tocar num mercado abre onde ele fica e a idade dos preços, a ordem das seções aprendida nas compras, o preço mais recente de cada produto ali e "Ir às compras aqui". Editar e Apagar ficam no menu.
- Tocar numa embalagem na tela do produto registra o preço dela.
- Quantidade na lista: "Pôr na lista" sugere o que falta para o "ter sempre" (com 1 em casa e "ter sempre 4", entram 3), o item mostra "3×" antes do nome, o toque longo muda a quantidade, o total da lista multiplica por ela e o marcado à mão entra no estoque com ela. O esquema vai à versão 10, com testes das migrações.
- Na Lista, o preço do mercado da compra aparece exato; o "≈" fica só no preço estimado pelos outros mercados.
- Folha "Fim da compra": o "Terminei" (no carrinho, na Lista ou na notificação) mostra antes o total, quantas embalagens vão para casa, a economia contra o mercado mais barato depois deste (só quando os dois têm preço de tudo) e o que faltou da lista, e só termina em "Terminar compra". O aviso depois conta embalagens, não produtos.
- Correção de preço (ADR 0017): no modo carrinho, digitar o preço de um item corrige a etiqueta lida errado, que sai do histórico sem ser apagada. O esquema vai à versão 11.
- Etiquetas da balança (ADR 0018): no carrinho, o código que começa com 2 pergunta o produto uma vez por mercado e entra com o valor da pesagem, sem virar embalagem. Fora do carrinho, o leitor explica que o código é da balança. O esquema vai à versão 12.
- Câmera do bipar, como no protótipo "Captura": o botão central abre a câmera ao vivo, com "Etiqueta" (o preço lido abre a folha de conferir e salvar, com "Mais barato aqui" e "Também comprei") e "Código" (abre o produto). O mercado fica no chip do topo e só é pedido no "Salvar". Segurar o botão abre o menu com "Modo carrinho" e "Dar baixa em casa", e o Início vazio abre a câmera somando cada código em casa. A câmera ao vivo virou um componente comum ao carrinho.
- Granel sem código: a etiqueta de gôndola por quilo vira um aviso tocável no carrinho e na câmera, que escolhe o produto pelo nome lido e guarda o preço por kg no histórico. O leitor de etiquetas marca o preço por kg.
- Casa e lista no mesmo gesto (ADR 0019): o "Comprei" da câmera e o "Também comprei" tiram o produto da lista (ou diminuem o que falta), e o "Usei" da câmera e o deslizar "Usei um" do Início põem na lista o que ficou abaixo do "ter sempre". O aviso diz o que mudou na lista, e o Desfazer volta estoque e lista juntos.
- Mercados: o selo "mais barato" só aparece quando a comparação é justa (o mercado tem a lista inteira e sai mais barato que cada um dos outros nos itens que os dois têm), e cada mercado mostra a idade do preço mais antigo que entrou no total.
- Preços da compra guardados com ela (ADR 0020): o que é lido ou digitado no carrinho fica numa tabela própria (esquema v13), com ou sem mercado. Sem mercado, o preço espera, sobrevive ao fechamento do carrinho e vai para o mercado escolhido com a hora da leitura; o "Terminei" do carrinho, da Lista ou da notificação pergunta o mercado. Trocar o mercado da compra pergunta se os preços já gravados vão junto, e corrigir um preço funciona depois de reabrir o carrinho.
- Cópias exportadas do design system e do protótipo em `docs/design/`.
- Banco de testes do OCR em `tool/ocr_bench`, com etiquetas sintéticas e transcrições de etiquetas reais.

### Alterado
- A aba principal passa a se chamar Início.
- Paleta: o amarelo da etiqueta é a cor da marca, com o coral como única cor de alerta.
- "Mínimo" virou "ter sempre": o item está acabando quando fica abaixo desse número.
- O preço clube deixa de ser tratado como promoção: vira o preço com cartão da loja.
- A comparação entre mercados usa o preço sem condição.
- Gradle 9.3.1, Android Gradle Plugin 9.1.0 e Kotlin 2.4.0; o app pede Flutter 3.47 ou mais novo.
- "Guardar em casa" no menu do bipar: o modo "Comprei" da câmera deixa de existir só no Início vazio.
- O stepper do estoque passa a se anunciar como correção ("Uma embalagem a menos/a mais"); "Usei um" e "Comprei um" ficam para os gestos e a câmera, que mexem na lista.
- Pôr ou tirar da lista pela linha do Início avisa o que mudou, com Desfazer.
- Telas que não carregam oferecem "Tentar de novo".
- Ações que apagam ou descartam se confirmam no botão neutro, com verbo e objeto ("Apagar mercado").
- Uma câmera só: o disparo do carrinho fotografa pela câmera ao vivo, "Registrar preço" na tela do produto abre a câmera em "Etiqueta" com o produto já escolhido, e o leitor de código do cadastro também usa a câmera ao vivo. Saem o formulário "Bipar preço", o leitor antigo e os pacotes `image_picker` e `mobile_scanner`.
- Os avisos de espera são botões: o preço que espera o produto abre a escolha pelo nome lido, e na câmera o produto que espera a etiqueta oferece "Digitar preço" e "Guardar em casa".
- A folha "Conferir e salvar" mostra o mercado do preço, e tocar nele troca.
- Quantidade na compra: o item da lista só fica marcado quando o carrinho alcança a quantidade dela. Antes, a lista e a bandeja mostram "1 de 3", e o "Terminei" deixa na lista o que faltou, citado na folha "Fim da compra" ("2× Leite").
- Tocar na quantidade do item da lista a muda, e o campo de adicionar entende "2 leite", "leite 2" e "2x leite".
- Sem localização, a compra começa no mercado que o chip da Lista mostrava, o da última compra.
- "Cancelar compra" também na folha "Fim da compra", que o "Terminei" do carrinho abre; na Lista, o menu passa para a direita.
- O editor da linha do Início ganhou "⋯" (mais do item), que leva ao local, a "Tirar de casa" e ao produto sem passar pelo chip do "ter sempre".

### Corrigido
- Leitura da etiqueta: centavos sobrescritos lidos à parte, milhar ("1.299,90"), preço seguido de KG ou UN, parcelas confundidas com o preço, dígitos espaçados pelo OCR e rótulos como "LEVE 3 PAGUE 2" tomados pelo nome do produto.
- Etiqueta com mais de um preço e nenhum rótulo lido (foto de longe ou borrada) não grava mais o preço do cartão ou do atacado como varejo: o campo fica em branco e os valores lidos ficam para tocar. Um preço lido sem a vírgula ao lado de outro ("13,89 1535") também entra entre os valores.
- O "Terminei" e a folha "Fim da compra" levam para casa só o que foi marcado durante a compra; o marcado antes, em casa ou numa compra cancelada, fica na lista como está. Cancelar a compra desmarca o que foi marcado nela.
- A foto da etiqueta tirada no carrinho, e a foto e o teclado da câmera, gravam o preço no mercado da compra ou do chip, e não no que a localização achar.
- O mercado sem preço de tudo fica sem barra na comparação, que contradizia o selo "mais barato". A idade do preço mais antigo só aparece a partir de 30 dias, e a lista de mercados diz "atualizado há N dias".
- A idade dos preços não aparece mais como "há -1 dias" com o relógio do aparelho atrasado.
- A alça da bandeja segue a direção do arrasto, e o preço estimado tem um sinal só (a etiqueta vazada).
- Compra sem lista mostra "8 no carrinho" em vez de "0 de 0 itens".
- "a menos que no Padaria Real" virou "a menos que em Padaria Real".
- A mesma etiqueta lida de novo, logo depois de dar o preço a um produto, não vai mais para o próximo produto bipado.

## [0.1.0] - 2026-10-27

### Adicionado
- Cadastro de produtos por código de barras, com validação do dígito verificador.
- Mercados com localização e detecção automática do mercado atual.
- Registro de preços com leitura da etiqueta por OCR no aparelho.
- Comparação de preços entre mercados e preço por unidade (kg, L, un).
- Estoque da casa com mínimo, local e histórico de movimentos.
- Banco local SQLite (Drift) preparado para sincronização futura.
