# Processo de design

Toda decisão de interface começa por ver como outros apps resolvem o mesmo problema. Depois adaptamos ao contexto do Bipa: offline, usado com uma mão, dentro do mercado e calmo por padrão. É a lição do Wonderous: estudar o que já funciona e fazer do nosso jeito, em vez de copiar ou inventar do zero.

## Passo a passo

1. **Nomear o problema**, não a tela. Por exemplo: "dar baixa no estoque sem abrir nada", não "redesenhar a linha".
2. **Pesquisar referências.** Apps parecidos na Play Store (brasileiros e de fora), apps de outras áreas que resolvem o mesmo tipo de problema (banco, saúde, scanners), guias de plataforma (Material 3, Android, iOS) e estudos de usabilidade (Baymard). Também vale ler as avaliações negativas, porque elas mostram o que evitar.
3. **Fazer do nosso jeito.** Escrever o que levamos de cada referência e o que fazemos diferente, à luz das regras de [identidade visual](identidade-visual.md), em especial a calma por padrão.
4. **Prototipar** no design system (componente com prévia interativa) e no protótipo de telas. O README de cada componente registra as referências.
5. **Aprovar antes de implementar.** O visual é aprovado no protótipo antes de virar widget em `lib/core/design_system/`.

## Inspirações

| Referência | Área | O que levamos |
| --- | --- | --- |
| iFood / iFood Mercado | Delivery e mercado | Lista que serve para qualquer mercado, lista a partir de foto e voz, barra persistente da compra em andamento, erros que dizem o que fazer |
| Scandit | Leitura de código | Confirmação com som, vibração e visual; pausa de 150ms; leitura contínua; código e preço da etiqueta lidos juntos |
| Open Food Facts | Base aberta de produtos | Produto desconhecido sem erro, com cadastro colaborativo |
| Walmart Scan & Go | Mercado | Total acumulado enquanto se compra |
| Bring! e AnyList | Lista de compras | Adicionar com um toque; lista na ordem dos corredores |
| Listonic | Lista de compras | Sugerir os itens de sempre, voz e widget na tela inicial |
| Monzo e Revolut | Banco | Insights com um número em destaque, o porquê explicado e cartões dispensáveis |
| Flo | Saúde | Ciclo, intervalo e última data como indicadores rápidos de ler |
| Linear e Shortcut | Produtividade | Interface calma: atenção só para o que é a tarefa e cor só com função |
| Material 3 Expressive e Android 16 | Plataforma | Mola, formas que mudam, menu do botão flutuante, notificação ao vivo |
| iOS 26 (Liquid Glass) | Plataforma | Barra de vidro que encolhe ao rolar; raios concêntricos |
| Wonderous | Flutter | Linguagem visual própria, gestos familiares, acessibilidade desde o início |
| Baymard | Usabilidade | O −/+ só quando o item está em uso; permitir digitar a quantidade |
| Pão de Açúcar e etiquetas de gôndola | Varejo BR | Preço por unidade, preço no app/clube, leve X pague Y |

## Benchmark: apps parecidos (outubro de 2026)

### Preço de mercado

| App | Como resolve | O que levamos | O que evitamos |
| --- | --- | --- | --- |
| **Menor Preço Brasil** (Sefaz-RS, 14 estados) e **Menor Preço Paraná** | Preços tirados das notas fiscais eletrônicas (NFC-e). Busca por código de barras ou nome, raio de até 30 km e data da última venda (até 7 dias) | A **idade do preço** sempre à vista ("visto há 3 dias"); busca pelo código de barras | Exigir login gov.br antes de usar; cobertura que depende do estado |
| **Preço da Hora** (Bahia e Paraíba) | Também usa a NFC-e: raio ajustável, telefone e rota até a loja, gráfico do histórico do preço, lista e favoritos | O **histórico do preço** na tela do produto e a rota até o mercado | Uma lista de lojas sem dizer qual sai mais barato para a compra inteira |
| **Basket** (EUA) | Crowdsourcing: cerca de 100 mil pessoas confirmam preços na gôndola, e o app pede a confirmação dos itens que mais mudam de preço. Compara a lista inteira entre mercados e sugere uma marca parecida quando falta o produto | **Comparar a lista inteira**, não item por item; **pedir só o que falta**: perto de um mercado, sugerir confirmar os preços antigos dos itens da sua lista | Depender de moderadores pagos |

A lição principal para o Bipa: **o cupom fiscal é a melhor fonte de preço**. O QR Code da NFC-e traz todos os itens, preços, data e CNPJ do mercado. Bipar o cupom registra a compra inteira de uma vez e também abastece o estoque.

### Estoque da casa

| App | Como resolve | O que levamos | O que evitamos (das avaliações) |
| --- | --- | --- | --- |
| **Pantry Check** | Código de barras, validade estimada, toque longo para "terminou" ou "estragou", lista a partir do consumo, família em tempo real | Consumido ou estragado; lista que nasce do consumo | Sem desfazer; ações destrutivas perto do ajuste; categoria automática sem revisão; montar o estoque inicial dá muito trabalho |
| **NoWaste** | Código de barras, cupom e foto; locais (geladeira, freezer, despensa); comido ou desperdiçado; lembretes de validade | Locais; estatística de desperdício | Itens perdidos quando "adicionar todos" travou; item que entra no estoque sem sair da lista; falta de voz |
| **Grocy + Barcode Buddy** (código aberto) | **Modos de leitura**: usei, comprei, abri, só consultar, pôr na lista. Um código especial troca o modo, e ele volta sozinho ao padrão. Quantidade por embalagem (uma caixa = 6 ovos) | Modos de leitura no bipar: **"Usei"** em casa (bipar a embalagem vazia dá baixa e põe na lista) e **"Comprei"** no mercado; quantidade por embalagem | Configuração técnica e servidor próprio |
| **Listonic** | 66% das listas se repetem toda semana, então o app sugere os itens de sempre ao criar uma lista; voz; widget | **Itens de sempre** pelo ritmo de consumo, que o Bipa já conhece; widget de adicionar rápido | Anúncios no meio da lista |

### Ideias que entram no roadmap

- **Bipar o cupom fiscal** (QR da NFC-e) para registrar preços e abastecer o estoque de uma vez. É também o melhor onboarding, porque resolve a reclamação de que montar o estoque inicial dá trabalho. Sem internet, a nota fica na fila.
- **Modos do bipar:** "Preço" (no mercado), "Comprei" e "Usei" (em casa).
- **Fechar o ciclo da lista:** o que é bipado em "Comprei" sai da lista e entra no estoque.
- **Desfazer em toda ação** que muda o estoque, e cada item bipado salvo na hora (nunca em lote no fim).
- **Pedir confirmação só do que falta:** perto de um mercado, os 2 ou 3 preços mais antigos da sua lista.
- **Idade do preço sempre visível** e comparação da lista inteira entre mercados.
- **Itens de sempre** ao abrir a lista; widget de adicionar rápido; voz ("acabou o café").

### Ler a etiqueta ao vivo (outubro de 2026)

O problema: **o preço da gôndola entrar no carrinho sem fotografar nem digitar**, com a câmera que já está aberta no modo carrinho.

| Referência | Como resolve | O que levamos | O que fazemos diferente |
| --- | --- | --- | --- |
| **Scandit Smart Label Capture** | Lê o código de barras e o preço da mesma etiqueta de gôndola num processo só, e confere o par com uma base | **Código e preço no mesmo quadro são uma etiqueta**: o preço vai para aquele produto, e o código não conta como mais uma unidade | Sem base de referência: o histórico de preços do próprio app é a referência |
| **Stripe CardScan** e leitores de cartão | Só termina a leitura depois de vários quadros seguidos com o cartão centrado e em foco | **Consenso entre quadros**: o preço só vale quando se repete em quadros seguidos | O leitor não fecha: a câmera continua aberta para o próximo item |
| **ShopCalc** e **Calcula AI** | Apontar para a etiqueta põe o item e o preço na lista, e o total sobe na hora | Total que sobe na hora, sem tela de confirmação | O produto vem do código de barras, não do nome da etiqueta, que costuma vir abreviado ("ARROZ TIO JOAO 5KG") |
| **Shelf to Cart** | Depois da leitura, mostra nome e preço para confirmar ou editar | A **correção sempre à mão**: tocar no preço do item para digitar | Nada de confirmação a cada item: a leitura entra direto e o aviso some sozinho |
| **Google Lens** e tradução ao vivo | Destaca na imagem o texto que está lendo | Mostrar **o que foi lido** perto de onde a pessoa está olhando | Só o que está dentro da moldura é lido, porque na gôndola a etiqueta do lado é o erro mais provável |

**Do nosso jeito:**

- **Bipa primeiro, preço depois**, ou o contrário. Um preço lido logo depois de bipar vai para o último item. Um preço lido antes de bipar fica esperando o próximo produto por alguns segundos.
- **Um sinal por leitura:** a moldura trava, uma vibração curta e um chip com o preço e o nome do item. O chip some sozinho, e o preço do item na bandeja muda.
- **Na dúvida, não escolhe:** etiqueta com vários preços do mesmo tamanho, ou só com preço de clube ou de atacado, não entra ao vivo. Para essas, o disparo continua fotografando a etiqueta.
- **A mesma etiqueta não vale duas vezes:** para ler de novo, é preciso tirá-la da moldura, como no código de barras.

### Produto e embalagens (outubro de 2026)

O problema: **o arroz de outra marca, ou de outro tamanho, é o mesmo arroz em casa**, mas hoje cada código de barras é um produto, com marca e tamanho fixos.

| Referência | Como resolve | O que levamos | O que fazemos diferente |
| --- | --- | --- | --- |
| **Grocy** (produtos pai) | Um produto pode ter variações (um nível só); o estoque do pai soma o das variações, marcado com Σ | **Produto e variações em dois níveis**, com o estoque somado no produto | Sem conversão de unidades por produto: o tamanho da embalagem já diz quanto ela tem |
| **Grocy na prática** (relato da Galaxus) | Unidades e conversões inventadas para cada produto; "o esforço supera o benefício" | Lição: **não pedir unidades nem conversões** | Contar embalagens, que é como se conta em casa, e somar o peso só para mostrar |
| **Open Food Facts** e etiquetas de gôndola | O código identifica marca e tamanho; a etiqueta escreve "ARROZ BRANCO TIO JOAO 5KG" | Marca e tamanho **pertencem ao código**, não ao produto | O nome da etiqueta sugere o produto e preenche marca e tamanho, para conferir |
| **Comparadores de preço** (preço por kg na gôndola) | O preço por unidade de medida compara tamanhos diferentes | **Preço por kg** para comparar as embalagens do mesmo produto | — |

### Ordem das seções por mercado (outubro de 2026)

| Referência | Como resolve | O que levamos | O que fazemos diferente |
| --- | --- | --- | --- |
| **AnyList** (conjuntos de categorias) | Cada loja pode ter um conjunto de categorias, na ordem que a pessoa monta | **Uma ordem por mercado** | Nada para montar: a ordem é aprendida |
| **Grocery – Smart Shopping List** | Guarda a ordem em que os itens são marcados para ordenar a próxima lista | **Aprender com a ordem em que se marca** | Por seção e pela mediana do horário, para uma volta ao corredor não bagunçar a lista |

### Juntar produtos (outubro de 2026)

Quem cadastrou o mesmo produto uma vez por marca precisa de um jeito de juntar os cadastros.

| Referência | Como resolve | O que levamos | O que fazemos diferente |
| --- | --- | --- | --- |
| **Google Contatos** ("Juntar e corrigir") | Sugere duplicados e junta com um toque; um contato juntado pode ser separado depois | Juntar é uma ação de **um toque depois de escolher** | Não sugerimos duplicados (ainda); e, como não dá para separar, há uma confirmação |
| **Grocy** (juntar tarefas) | Item no menu "mais" da lista; a API diz qual fica e qual sai (`merge/{manter}/{remover}`) | **"Juntar com…" no menu** da tela do produto, com o produto atual saindo | — |
| **Readysell** (juntar produtos no ERP) | Digita-se o código do produto que fica; o histórico dos dois é mantido; não há desfazer | **O histórico vai junto**: preços, estoque, lista e carrinho passam para o que fica | A confirmação diz em uma frase o que passa e que o outro deixa de existir |

### Granel sem código (outubro de 2026)

A etiqueta de gôndola do granel ("TOMATE ITALIANO R$ 8,99 o kg") não tem código, e o preço dela é por quilo: o que a pessoa paga depende do peso.

| Referência | Como resolve | O que levamos | O que fazemos diferente |
| --- | --- | --- | --- |
| **FairPrice Scan&Go** ([produtos sem código](https://help.fairprice.com.sg/hc/en-us/articles/360029616171-How-do-I-scan-fresh-produce-that-do-not-have-barcodes)) | A pessoa pesa na balança da loja, escolhe o item, imprime uma etiqueta com código e a bipa no app | **A pesagem vem da balança**: o valor entra pela etiqueta dela (ADR 0018) | A etiqueta da gôndola também serve: o preço por kg vai para o histórico |
| **Shipt** ([itens pesados](https://shoppers.shipt.com/app-functionality/shopping-for-weighted-items)) | O item pesado é adicionado pelo peso, e o código da embalagem é opcional | **Escolher o produto sem código**, pela busca | Não pedimos o peso: o total vem da etiqueta da balança ou do preço digitado |

### Motivo das permissões (outubro de 2026)

O "Ir às compras" pedia a localização e as notificações seguidas, sem dizer por quê, e a tela de Mercados pedia a localização só por abrir.

| Referência | Como resolve | O que levamos | O que fazemos diferente |
| --- | --- | --- | --- |
| **Android Developers** ([pedir permissões em tempo de execução](https://developer.android.com/training/permissions/requesting)) | Pedir no momento em que o recurso é usado, explicar o motivo antes do pedido do sistema e seguir funcionando quando a pessoa nega | **Uma linha de motivo antes do pedido**, só quando o sistema ainda vai perguntar; "Agora não" segue sem a permissão | Um diálogo só para as duas permissões da compra, e todos os pedidos antes de abrir a câmera, para nenhum atropelar o outro. Em Mercados, o motivo é uma linha na própria tela, com "Usar localização" |

A câmera não ganhou diálogo: ela só abre quando a pessoa toca para bipar, e a dica "Aponte para o código ou a etiqueta" já aparece atrás do pedido do sistema.

### Fechar o ciclo entre casa e lista (outubro de 2026)

Bipar em casa mudava só o estoque: o leite comprado continuava na lista, e a embalagem vazia não punha nada nela.

| Referência | Como resolve | O que levamos | O que fazemos diferente |
| --- | --- | --- | --- |
| **Grocy** ([3.3.0](https://newreleases.io/project/github/linuxserver/docker-grocy/release/v3.3.0-ls151)) | Uma opção, desligada por padrão, põe na lista o que fica abaixo do estoque mínimo | **Abaixo do "ter sempre", vai para a lista**, com o que falta | Sem opção: só o bipe de "Usei" põe na lista, e o snackbar diz isso com o Desfazer ao lado |
| **Barcode Buddy** (modos de leitura, nas fontes) | Um modo para comprar e outro para consumir, escolhidos antes de bipar | Os modos "Comprei" e "Usei" da câmera, já existentes | "Comprei" também tira da lista, ou diminui o que falta quando eram vários |

### Lista mais barata (outubro de 2026)

O selo "mais barato" ia para o mercado com a lista inteira, mesmo quando outro, com menos preços, saía mais barato nos itens que tinha. E nada dizia de quando eram os preços.

| Referência | Como resolve | O que levamos | O que fazemos diferente |
| --- | --- | --- | --- |
| **S-Group** ([comparação da cesta](https://s-etukortti.fi/en/support/grocery-basket-comparison)) | Compara só os produtos que as duas lojas têm, com preço normal (sem cartão), de menos de dois dias e do mesmo dia nas duas | **A cesta em comum decide o selo**: o primeiro precisa da lista inteira e de ganhar de cada um nos itens que os dois têm. O preço normal na frente já vinha da ADR 0011 | Os preços são da própria pessoa, de dias diferentes: em vez de descartar os antigos, cada mercado mostra a idade do mais antigo ("preços de até 12 dias") |
| **Basket** (nas fontes) | Soma a lista em cada loja próxima, com preços da comunidade | O total por mercado, com a barra | Sem selo quando a comparação não é justa: a ordem e "sem preço de N itens" já dizem o resto |

### Ícone do app (outubro de 2026)

O problema: **reconhecer o Bipa em 48 px numa tela inicial cheia de amarelo**, nas máscaras de cada fabricante e no ícone temático. As referências, as quatro propostas e a recomendação estão em [icone/](icone/README.md).

| Referência | Como resolve | O que levamos | O que fazemos diferente |
| --- | --- | --- | --- |
| **Android** ([ícones adaptativos](https://developer.android.com/develop/ui/views/launch/icon_design_adaptive)) | Fundo e primeiro plano de 108 dp, zona segura de 66 dp e camada monocromática para o tema | O desenho dentro dos 66 dp e um monocromático nosso | — |
| **Vizinhos amarelos** (Mercado Livre, Banco do Brasil, Google Keep) | Branco ou azul sobre o amarelo | Uma silhueta sólida sobre fundo chapado | Ink sobre o amarelo, como na etiqueta de gôndola |
| **Leitores de código genéricos** | Código de barras com linha vermelha | — | O furo da etiqueta como assinatura, no lugar do laser |

### Arrumar o que entrou (outubro de 2026)

O problema: **conferir onde cada coisa ficou depois da primeira carga, sem abrir item por item** (AB5). O local sugerido pela categoria acerta quase sempre, e o "ter sempre" fica vazio.

| Referência | Como resolve | O que levamos | O que fazemos diferente |
| --- | --- | --- | --- |
| **Pantry Check** ([App Store](https://apps.apple.com/us/app/pantry-check-grocery-list/id966702368)) | Bipa vários itens em sequência e depois pede quantidade, validade e local | Bipar tudo primeiro e arrumar depois, numa tela só | Nada a preencher: o local sugerido já vem marcado e o "ter sempre" é opcional |
| **Adobe Scan** ([revisar antes de salvar](https://www.adobe.com/devnet-docs/adobescan/ios/en/modify.html)) | Depois de várias capturas, uma tela de revisão para cortar e reordenar | Uma revisão do lote ao fechar a câmera | A revisão não segura nada: cada item já está salvo, e fechar a folha é pular |
| **Grocy** ([local padrão do produto](https://newreleases.io/project/github/grocy/grocy/release/v3.3.1)) | Cada produto tem um local padrão, usado na compra | O local escolhido aqui vale para as próximas vezes (ADR 0021) | Sem configurar antes: a sugestão vem da categoria |

**Do nosso jeito:**

- Os itens vêm agrupados pelo local em que nasceram, com o cabeçalho de corredor da lista. O leite na "Despensa" se vê sem um selo por linha.
- A linha é a do estoque (miniatura, nome e medidor). Tocar abre o local e o "ter sempre", como o editor da linha do Início, um item por vez.
- Cada escolha salva na hora, por isso não há "Salvar": "Pronto" fecha, e arrastar para baixo também.

### Quando aparece "Arrumar o que entrou" (outubro de 2026)

O problema: **a folha só aparece com três ou mais itens novos** (AB13). Com bipes rápidos, o aviso de cada item novo dura até o bipe seguinte, uns 2 s; com um ou dois novos, nada confere o local ao fechar. E, no caso oposto, a folha mostra também os itens cujo local a pessoa já trocou no aviso.

| Referência | Como resolve | O que levamos | O que fazemos diferente |
| --- | --- | --- | --- |
| **Adobe Scan** (no benchmark de "Arrumar o que entrou") | A revisão do lote aparece ao terminar as capturas, com o que foi capturado | A revisão ao fechar a câmera | Ela só mostra o que ninguém conferiu, e não aparece quando não há nada (proposta A) |
| **Material Design** ([folhas inferiores](https://m3.material.io/components/bottom-sheets/guidelines) e [snackbars](https://m3.material.io/components/snackbar/guidelines)) | A folha modal interrompe e pede atenção; o snackbar informa sem interromper, com uma ação | Para pouca coisa, um aviso com uma ação; para muita, a folha (proposta B) | O aviso diz os nomes e o local, para a pessoa decidir sem abrir nada |
| **Pantry Check** (no benchmark de "Arrumar o que entrou") | Pede local e validade depois de bipar vários itens, sempre | — | Não perguntar o que já foi respondido: o item com o local escolhido no aviso sai da conta |

**Do nosso jeito:** duas propostas, no quadro [ArrumarEntrouRegra](prototipo/telas/ArrumarEntrouRegra.png). Nas duas, o item cujo local foi escolhido no aviso sai da conta, e um bipe desfeito também, como hoje.

- **A, a folha só com o que ninguém conferiu:** entra o item novo cujo aviso foi trocado por outro bipe antes dos 4 s e cujo local ninguém tocou, sem mínimo. Sem nada assim, a câmera fecha direto. Uma superfície só, e a regra diz quando a pessoa provavelmente não viu o local.
- **B, um aviso para poucos e a folha para muitos:** com um ou dois itens novos sem o local escolhido, a câmera fecha e o Início mostra o `bipa-toast` "Atum e Lasanha ficaram na Despensa", com "Conferir", que abre a escolha. Com três ou mais, a folha de hoje. Interrompe menos, mas o aviso também some em 4 s.

Recomendação: A, porque não depende de a pessoa ver mais um aviso que some.

**Decidido em 28/10/2026: A**, e mais simples que o quadro: a folha lista os itens novos cujo local ninguém escolheu no aviso da câmera, sem mínimo, e sem nenhum a câmera fecha direto. O app não mede se o aviso foi trocado por outro bipe antes dos 4 s: quem não tocou no local não o conferiu, tenha visto o aviso ou não. Escolher no aviso o mesmo local sugerido também conta como conferido (`HomeArrivals.placeChosen`).

### Granel na bandeja (outubro de 2026)

O problema: **o preço por kg do granel não pode parecer o valor da linha** (D9). Na bandeja, "R$ 8,99/kg" ocupava a etiqueta com o contorno do preço estimado, que entra no total, e ficava fora dele.

| Referência | Como resolve | O que levamos | O que fazemos diferente |
| --- | --- | --- | --- |
| **Instacart** ([preços e itens por peso](https://instacart.com/help/section/pricing)) | Mostra o preço por unidade de peso e cobra o valor final pela etiqueta da pesagem, que pode mudar o total | Separar o preço por kg (certo) do valor da linha (desconhecido até a pesagem) | Não pedimos o peso para estimar: a linha fica com o traço e o total diz "sem preço de 1 item" |
| **Etiquetas de balança** (FairPrice, ADR 0018, nas fontes) | O valor pago sai da etiqueta impressa pela balança | O valor da linha é o da pesagem: a etiqueta da balança ou o digitado | Ao digitar, mostramos o peso que o valor dá pelo preço por kg, para pegar um erro de digitação ("124,0") |

**Do nosso jeito:**

- **Um sinal por sentido.** Etiqueta cheia é preço de hoje, vazada é preço do histórico (no total com "≈"), traço é sem preço. O preço por kg sai da etiqueta e vira uma linha discreta sob o nome, com o ícone da balança.
- O título do diálogo pergunta o que se pagou ("Quanto deu o Tomate italiano?"), para não confundir com o preço da gôndola.

### Trocar o local no aviso da câmera (outubro de 2026)

O problema: **corrigir o local de um item novo na hora do bipe**, quando a sugestão erra e a pessoa ainda está com a embalagem na mão (AB9).

| Referência | Como resolve | O que levamos | O que fazemos diferente |
| --- | --- | --- | --- |
| **Spotify** (botão "+", nas [discussões da comunidade](https://community.spotify.com/t5/Live-Ideas/Ability-to-Change-the-Default-Playlist-for-button/idi-p/5678036/page/3)) | O "+" salva direto nas Curtidas, e o aviso traz "Alterar" para escolher outra playlist | Salvar no destino provável e oferecer a troca no próprio aviso | A troca é o próprio texto do aviso, com o local à vista e a seta para baixo, e não um botão "Alterar" ao lado do "Desfazer" |
| **Material Design** ([snackbars](https://m3.material.io/components/snackbar/guidelines)) | Uma ação por aviso, reversível; um aviso novo substitui o anterior | O aviso fica com uma ação escrita só (Desfazer) | O local não vira uma segunda ação com rótulo: o texto que já diz o local é o botão que o troca |

**Do nosso jeito:**

- **Um sinal por informação:** o local fica dentro do aviso, no texto que já diz o estoque ("Leite integral 1 L · 1 na Despensa ▾"), e não se repete em outro lugar.
- O texto, com a seta para baixo, é um botão, e o Desfazer é outro no mesmo aviso, cada um com 48 de área de toque. O local só aparece quando o item nasce no bipe, a hora em que a sugestão pode errar.
- Tocar no local para o tempo do aviso e abre a escolha, com os chips de local de "Arrumar o que entrou". Tocar escolhe e fecha, sem botão de salvar, e o aviso volta com o local novo.

**Decidido em 28/10/2026:** a primeira proposta punha o local num chip de vidro à parte, abaixo do aviso. O quadro aprovado ([CapturaCasaLocal](prototipo/telas/CapturaCasaLocal.png)) pôs o local dentro do aviso, e o app seguiu (`onDetailTap` do `LiveReadChip`). Um chip separado dizia o mesmo item duas vezes, em dois lugares.

### Local que não corta no aviso (outubro de 2026)

O problema: **com um nome comprido, o local é a parte do aviso que corta** (AB12). Num celular de 360 dp, "Leite condensado Moça 395 g · 1 na D…": a seta continua lá, mas o que ela troca não aparece, e o local é a razão de o texto ser um botão.

| Referência | Como resolve | O que levamos | O que fazemos diferente |
| --- | --- | --- | --- |
| **Material Design** ([snackbars](https://m3.material.io/components/snackbar/guidelines)) | O texto do aviso tem uma ou duas linhas; quando não cabe numa, quebra em vez de cortar, e a ação fica ao lado | Duas linhas quando a informação precisa delas (proposta B) | Duas linhas só no bipe em que o item nasce, quando há local; nos outros bipes, uma |
| **Material Design** ([listas de duas linhas](https://m3.material.io/components/lists/guidelines)) e a `ScanTray` do Bipa (granel com `meta`) | Texto principal em cima e o de apoio embaixo, cada um na sua linha | O nome em cima, mais discreto, e o local embaixo, com a seta, que é o que se toca | O local é o texto mais forte das duas linhas, porque é ele que o botão troca |
| **Spotify** ("Adicionado a Curtidas · Alterar", no benchmark de "Trocar o local") | O destino vem no fim do aviso | — | O destino no fim é o que corta primeiro: na proposta A ele passa para a frente |

**Do nosso jeito:** duas propostas, no quadro [CapturaCasaLocalNomeLongo](prototipo/telas/CapturaCasaLocalNomeLongo.png). **A** põe o local antes do nome numa linha só ("+1 · 1 na Despensa ▾ · Leite con…"): o aviso não muda de altura, mas num celular de 360 dp o nome fica com uns 60 dp e quase some, e o nome é o que diz qual item foi. **B** usa duas linhas quando há local: o nome em cima (inteiro na maioria dos casos, cortando só no fim) e "1 na Despensa ▾" embaixo. O aviso cresce 16 dp só nesse bipe. Nas duas, o leitor de tela ouve o número, o nome, o local e "trocar o local", e o Desfazer continua um botão à parte. Recomendação: B, que não perde nenhuma das duas informações.

**Decidido em 28/10/2026: B.** No app, o `LiveReadChip` ganhou o `title`: com ele, o nome fica em cima e o local, com a seta, embaixo, mais forte, sem nunca cortar (com letra grande, ele quebra a linha). O texto do local virou só "1 na Despensa" (`cameraAtHomePlaced`), porque o nome já está na linha de cima.

### Quadros do que o app já fazia (outubro de 2026)

O "Desfazer" no aviso da câmera, o preço em destaque velho do produto, o editor da linha do Início e a folha "Editar embalagem" nasceram no código, a partir das análises de UX, sem quadro. Os quadros foram desenhados a partir do app: o conteúdo, a ordem e as ações são os do código, no visual do design system, e as diferenças do widget ficam na linha de cada quadro no [protótipo](prototipo/README.md). As referências são as que já estavam nas análises:

| Referência | O que o app já leva |
| --- | --- |
| **Material Design** ([snackbars](https://m3.material.io/components/snackbar/guidelines)) | Uma ação por aviso, e um aviso novo substitui o anterior: por isso o Desfazer vai para o aviso do visor quando a lista não muda |
| **Menor Preço Brasil** e **Preço da Hora** (no benchmark acima) | A idade do preço sempre à vista: o preço em destaque com mais de 30 dias diz onde e quando |
| **Baymard** e **Pantry Check** (nas inspirações) | Controles só no item tocado, e o resto do item (local, "Tirar de casa") a um toque, sem passar pelo chip do "ter sempre" |

### A aba Produtos (outubro de 2026)

O problema: **achar um produto e o preço dele numa aba vizinha de Mercados, sem mudar de linguagem visual** (H1). A aba ainda usa a barra, a busca e as linhas do Material, com a mesma cesta em todo produto.

| Referência | Como resolve | O que levamos | O que fazemos diferente |
| --- | --- | --- | --- |
| **Mercados** (o próprio Bipa) e **Nielsen** ([consistência e padrões](https://www.nngroup.com/articles/consistency-and-standards/)) | Abas vizinhas com a mesma busca, as mesmas linhas e o mesmo cartão | Título, busca com o bipar dentro e linhas `bipa-mprice` num cartão, com "Cadastrar…" no fim | A miniatura é a da categoria do produto, em neutro: o `place` fica para os mercados |
| **Menor Preço Brasil** (no benchmark acima) | Busca por nome ou pelo código de barras, e o preço no resultado | O bipar dentro da busca e o preço na linha | O preço é o da pessoa; por unidade (kg, litro) só quando há embalagens de tamanhos diferentes, que é quando ele compara |

**Do nosso jeito:** uma linha por produto, e não por embalagem: a embalagem aparece na linha de baixo ("Pilão · 500 g"), ou quantas são ("2 embalagens"). Sem preço, a linha não mostra nada à direita, em vez de um "—".

### Navegação com letra grande (outubro de 2026)

O problema: **os rótulos da barra cortam a partir de uns 120% num celular de 360 dp** ("Produt", "Merca"), e a barra compacta os tira de vez (H8). O `CLAUDE.md` pede texto na navegação, e quem aumenta a letra é quem mais precisa dele.

| Referência | Como resolve | O que levamos | O que fazemos diferente |
| --- | --- | --- | --- |
| **Flutter** (`NavigationBar`, [código-fonte](https://codebrowser.dev/flutter/flutter/packages/flutter/lib/src/material/navigation_bar.dart.html)) | Limita a escala do rótulo a 1,3 e mostra o rótulo maior no tooltip do toque longo | O teto de 130% e o rótulo grande no toque longo (proposta A) | Além do teto, o rótulo encolhe até caber, e os quatro ficam no mesmo tamanho |
| **iOS** (Large Content Viewer, [WWDC 2019](https://developer.apple.com/videos/play/wwdc2019/261/)) | Barras de abas não crescem com a letra; nos tamanhos de acessibilidade, segurar um item mostra o ícone e o rótulo num balão grande | O balão com ícone e rótulo, só com letra grande | No Android não há o recurso pronto: o balão é do Bipa e não pode brigar com o toque longo do bipar, que fica no botão do meio |
| **WCAG 1.4.4** ([redimensionar texto](https://www.w3.org/WAI/WCAG21/Understanding/resize-text.html)) e **Material 3** (rótulos de uma linha, sem cortar) | Texto até 200% sem perder conteúdo; o M3 pede rótulo de uma linha, inteiro | Nada de reticências na barra | A proposta B ganha largura tirando o bipar do meio, em vez de esconder rótulos |
| **iOS 26** (barra que minimiza, na análise do lote 8) | Minimiza ao rolar só quando há o que rolar | — | Com letra grande ou TalkBack, a barra não encolhe: o rótulo é a informação |

**Do nosso jeito:** duas propostas foram ao mantenedor. A mantém a anatomia do `ScanNavBar` (bipar no meio) e aceita rótulos quase do tamanho normal, com o balão para quem precisa ler maior. B dá aos rótulos uns 35% a mais de largura, mas tira o bipar do centro da barra, que é a marca do componente.

**Decidido em 28/10/2026: A até 160%, B acima.** Até 160% de letra, a barra é a de sempre, com os rótulos limitados a 130% e encolhidos por igual até caber. Acima de 160%, o bipar sai do meio e flutua acima da barra, à direita, e o menu do bipar sai dele. O balão do rótulo grande, no toque longo do destino, vale nas duas, porque em B os rótulos ainda encolhem num celular estreito. A partir de 130% ou com o TalkBack, a barra não encolhe ao rolar. B durante a compra, com a barra amarela da compra entre o bipar e a navegação, foi decidido depois (H12, em "Letra grande durante a compra", mais abaixo).

### Letra grande durante a compra (outubro de 2026)

O problema: **acima de 160% de letra, durante a compra, dois botões amarelos empilhados levam ao mesmo lugar** (H12). O bipar flutuante fica logo acima da barra da compra, os dois abrem o modo carrinho, e a parte de baixo da tela passa de 40% da altura. O quadro da barra com letra grande desenhou B sem a compra.

| Referência | Como resolve | O que levamos | O que fazemos diferente |
| --- | --- | --- | --- |
| **Material 3** ([botão flutuante](https://m3.material.io/components/floating-action-button/guidelines)) | Um botão flutuante por tela, para a ação principal | Um botão de marca só embaixo | Durante a compra, a ação principal já é a barra da compra: ela faz o papel do botão |
| **iOS 26** (o acessório de baixo entra na barra minimizada, na análise do lote 8) | O acessório de reprodução ocupa o lugar do que some | A barra da compra no lugar do bipar | Ela herda o toque longo do bipar, para o menu não sumir com a letra grande |
| **ScanNavBar** ("os itens do menu são atalhos", no guia) | Tudo o que o menu do bipar faz também existe nas telas | Esconder o atalho do toque longo não tira nenhum caminho | — |

**Do nosso jeito:** duas propostas, no quadro [NavLetraGrandeCompra](prototipo/telas/NavLetraGrandeCompra.png), ao lado do caso de hoje. Nas duas, o bipar flutuante sai durante a compra (só acima de 160%: até lá, o bipar fica no meio da barra, longe da barra da compra), ganha 76 dp e fica um amarelo só.

- **A, a barra da compra assume:** ela fica como é, com "Continuar", e ganha o toque longo do bipar, com o rótulo acessível "segure para mais opções". Nada muda no componente além do gesto.
- **B, o bipar entra na barra:** o fim da barra da compra troca "Continuar" pelo glifo do bipar num círculo `ink`. O texto ganha largura ("3 de 7 itens" numa linha) e o glifo mostra onde se bipa, mas é uma variante nova da `ShoppingBar` e tira o texto de uma ação de navegação.

Recomendação: A, que segue a regra de texto na navegação e não cria variante.

**Decidido em 28/10/2026: A.** Feito no app: acima de 160%, durante a compra, o bipar flutuante sai e a barra da compra, com "Continuar", ganha o toque longo que abre o menu do bipar, ancorado nela. A regra está nos guias [`ScanNavBar.md`](design-system/componentes/ScanNavBar.md) e [`ShoppingBar.md`](design-system/componentes/ShoppingBar.md).

### Pergunta do relatório de falhas (outubro de 2026)

O problema: **pedir o consentimento do relatório de falhas sem quebrar a calma, com a recusa tão fácil quanto o aceite e um lugar para mudar de ideia** ([ADR 0025](../adr/0025-relatorio-de-falhas-com-sentry-e-consentimento.md)). O app ainda não tem tela de Ajustes.

| Referência | Como resolve | O que levamos | O que fazemos diferente |
| --- | --- | --- | --- |
| **ANPD** ([guia de cookies, 2022](https://www.gov.br/anpd/pt-br/documentos-e-publicacoes)) e **LGPD** (art. 8º, § 5º) | Recusar tão fácil quanto aceitar, nada pré-marcado, e revogação gratuita e facilitada | "Mandar" e "Não mandar" com o mesmo peso e a mesma largura; o interruptor sempre à mão | Fechar o cartão no × conta como "não", e ele não volta |
| **iOS** (Análises e Melhorias) | Pergunta uma vez e deixa o interruptor nos Ajustes, com o que é enviado explicado ali | Uma pergunta só e o resto nos Ajustes | Não na primeira abertura: depois da primeira compra terminada, quando a pessoa já sabe o que o app faz |
| **Firefox para Android** (Ajustes, coleta de dados) | Interruptores por tipo de dado, cada um com uma linha do que faz | Um interruptor com uma linha embaixo | O que vai e o que nunca vai ficam abertos sob o interruptor, sem link para outra página: é a explicação que a LGPD pede, num lugar só |
| **InsightCard** do Bipa | Cartão dispensável no Início, com o × no canto | O mesmo cartão, neutro | Sem `brand` nem `alert`: o destaque do Início continua sendo "Ir às compras" |

**Do nosso jeito:** dois quadros, [InicioRelatorioFalhas](prototipo/telas/InicioRelatorioFalhas.png) e [Ajustes](prototipo/telas/Ajustes.png).

- **O cartão** fica no lugar do carrossel de insights, abaixo da lista e dos locais, uma vez, depois da primeira compra terminada. O selo diz o assunto ("Relatório de falhas"), o título faz a pergunta e uma frase diz o que vai e o que fica. Os dois botões são secundários, lado a lado, do mesmo tamanho.
- **Ajustes** abre por um botão redondo com a engrenagem, à direita do título "Sua casa", como o botão redondo das outras telas. A tela tem o mínimo: "Privacidade", com o interruptor "Relatório de falhas" e, embaixo, o que vai e o que nunca vai; e "Sobre o Bipa", com a versão. Desligar fecha o Sentry na hora.
- Em build sem DSN, nem o cartão nem a seção "Privacidade" aparecem; a tela fica só com a versão.

### O anel que respira (outubro de 2026)

O problema: **o anel do bipar respira sem fim, em todas as abas** (H16). É a assinatura do botão, mas um movimento contínuo no canto do olho briga com a calma por padrão, e durante a compra pulsa ao lado da barra amarela, que já é o destaque.

| Referência | Como resolve | O que levamos | O que fazemos diferente |
| --- | --- | --- | --- |
| **WCAG 2.2.2** ([pausar, parar, esconder](https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html)) | Movimento automático por mais de 5 s precisa de um jeito de pausar | Movimento com começo e fim, abaixo de 5 s: dois ciclos de 2,4 s | Sem controle de pausa: o anel para sozinho |
| **Linear e Shortcut** (calma por padrão, em [identidade-visual.md](identidade-visual.md)) | Não disputar uma atenção que não foi conquistada | O anel chama só quando a barra aparece | Continua sem fim quando a casa e a lista estão vazias, porque aí bipar é a única coisa a fazer |

**Do nosso jeito:** dois ciclos quando a barra aparece, sem fim só com a casa e a lista vazias, parado durante a compra e com movimento reduzido. **Decidido em 28/10/2026**, e a regra está no guia [`ScanNavBar.md`](design-system/componentes/ScanNavBar.md) e no app. O design system publicado no claude.ai ainda tem o anel `infinite` e precisa da mesma mudança.

## Fontes

- [Menor Preço Brasil (Olhar Digital)](https://olhardigital.com.br/2025/08/03/dicas-e-tutoriais/quer-economizar-na-farmacia-e-supermercado-conheca-o-app-menor-preco-brasil/)
- [Preço da Hora Bahia (Bahia Notícias)](https://www.bahianoticias.com.br/noticia/246778-app-do-governo-da-bahia-permite-conferir-precos-em-tempo-real)
- [Discussão sobre apps de menor preço (TabNews)](https://www.tabnews.com.br/devPadawan/app-para-descobrir-o-melhor-preco-de-produtos-alimenticios)
- [App colaborativo com NFC-e (dissertação, UFG)](https://repositorio.ufcat.edu.br/handle/tede/10644)
- [Basket: "Waze for groceries" (FoodNavigator)](https://www.foodnavigator.com/Article/2019/01/04/Waze-for-groceries-Basket-app-deploys-crowdsourcing-for-real-time-pricing-info/)
- [Pantry Check (App Store)](https://apps.apple.com/us/app/pantry-check-grocery-list/id966702368)
- [NoWaste (App Store)](https://apps.apple.com/us/app/-/id926211004)
- [Barcode Buddy: modos de leitura](https://barcodebuddy-documentation.readthedocs.io/en/latest/usage.html)
- [Listonic: recursos de lista](https://listonic.com/best-grocery-app-features)
- [Melhores apps de lista (Android Authority)](https://www.androidauthority.com/best-grocery-list-apps-101625/)
- [Linear: bastidores do redesenho](https://linear.app/now/behind-the-latest-design-refresh)
- [Shortcut: um app mais calmo](https://www.shortcut.com/blog/designing-a-calmer-clearer-faster-shortcut)
- [Flo: widgets do ciclo na tela principal](https://medium.com/flo-health/how-we-evolved-and-enriched-the-main-screen-of-the-flo-app-part-2-cycle-widgets-b73d5ccb948d)
- [Scandit Smart Label Capture](https://docs.scandit.com/next/sdks/web/label-capture/intro/)
- [Stripe CardScan: quadros exigidos antes de terminar](https://stripe.dev/stripe-android/stripecardscan/com.stripe.android.stripecardscan.cardimageverification/-card-image-verification-sheet/-configuration/strict-mode-frames.html)
- [ShopCalc (App Store)](https://apps.apple.com/app/id6756393232)
- [Calcula AI (Product Hunt)](https://www.producthunt.com/p/calcula-ai)
- [Shelf to Cart](https://shelf-to-cart-marketing.pages.dev/)
- [Grocy 2.5.0: produtos pai e estoque somado](https://newreleases.io/project/github/grocy/grocy/release/v2.5.0)
- [Digitalizar a geladeira com o Grocy (Galaxus)](https://www.galaxus.de/en/page/wie-ich-meinen-kuehlschrankinhalt-digitalisieren-will-und-daran-scheitere-39565)
- [AnyList: conjuntos de categorias por loja](https://help.anylist.com/articles/category-sets/)
- [Grocery – Smart Shopping List (App Store)](https://apps.apple.com/ca/app/id1195676848?l=en-ca)
- [Juntar contatos duplicados (Ajuda do Google Contatos)](https://support.google.com/contacts/answer/7078226)
- [Grocy 3.1.3: juntar tarefas (linuxserver/docker-grocy)](https://newreleases.io/project/github/linuxserver/docker-grocy/release/v3.1.3-ls128)
- [Juntar produtos no Readysell](https://readysell.atlassian.net/wiki/spaces/RSELL7/pages/107945786/Merging+products+through+the+products+module)
- [Ícones adaptativos (Android Developers)](https://developer.android.com/develop/ui/views/launch/icon_design_adaptive)
- [Adobe Scan: modificar as capturas antes de salvar](https://www.adobe.com/devnet-docs/adobescan/ios/en/modify.html)
- [Grocy 3.3.1: local padrão e local de consumo](https://newreleases.io/project/github/grocy/grocy/release/v3.3.1)
- [Instacart: preços e itens vendidos por peso](https://instacart.com/help/section/pricing)
- [Spotify: pedidos sobre o "+" e a playlist padrão (comunidade)](https://community.spotify.com/t5/Live-Ideas/Ability-to-Change-the-Default-Playlist-for-button/idi-p/5678036/page/3)
- [Material Design: snackbars](https://m3.material.io/components/snackbar/guidelines)
- [Nielsen Norman Group: consistência e padrões](https://www.nngroup.com/articles/consistency-and-standards/)
- [Flutter: código do NavigationBar (escala máxima do rótulo)](https://codebrowser.dev/flutter/flutter/packages/flutter/lib/src/material/navigation_bar.dart.html)
- [Apple, WWDC 2019: Large Content Viewer](https://developer.apple.com/videos/play/wwdc2019/261/)
- [W3C: Understanding SC 1.4.4 Resize Text](https://www.w3.org/WAI/WCAG21/Understanding/resize-text.html)
