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
