# 0024. Embarcar um catálogo de produtos brasileiros a partir do Open Food Facts

- Status: Aceito, menos a licença da base comunitária, que fica para o ADR de sincronização
- Data: 2026-10-28

Em 28/10, o mantenedor decidiu: o catálogo inclui limpeza e higiene (Open Products Facts e Open Beauty Facts), ele vai embarcado no APK e é refeito a cada versão, e a consulta online fica desligada na primeira versão.

## Contexto

O roadmap (fase 1) pede um catálogo pronto: o app já vem com nome, marca, tamanho e categoria por código de barras, e bipar um produto conhecido não abre o cadastro. Hoje todo código novo abre "Embalagem nova" e depende do nome lido na etiqueta (ADR 0013).

O catálogo precisa caber no jeito do app:

- **Offline (ADR 0002).** Bipar no mercado, sem sinal, precisa achar o produto. Uma consulta online por bipe não serve como caminho principal.
- **Embarcar um subconjunto.** Só o que se vende no Brasil, com os campos que o app usa, num arquivo pequeno o bastante para ir no APK.
- **Atualizar.** Produtos novos aparecem toda semana. O catálogo precisa de um jeito de ser refeito.
- **Fase 2.** A base comunitária vai receber embalagens (código, marca e tamanho) e preços. Se essas embalagens vierem do catálogo, a licença dele vale para elas.
- **Privacidade.** Uma consulta online manda a terceiros o código de cada produto que a pessoa bipa, em casa ou no mercado.

Este ADR não é parecer jurídico. As leituras de licença abaixo são as do projeto, com as fontes citadas, e os pontos duvidosos estão marcados como risco.

## Opções pesquisadas

A pesquisa foi feita em 28/10/2026. Onde a página da fonte não abriu para leitura automática, isso está dito.

### Open Food Facts

- **O que é:** base colaborativa e aberta de produtos, mantida por uma associação francesa. A família inclui o Open Products Facts (produtos que não são alimento, como limpeza) e o Open Beauty Facts (higiene e cosméticos), com a mesma licença.
- **Cobertura no Brasil:** a página brasileira mostrava **37.456 produtos** em 28/10/2026 ([br.openfoodfacts.org](https://br.openfoodfacts.org/)). A qualidade varia: os dados são colaborativos, e muitos registros não têm quantidade ou têm o nome incompleto. Quanto disso cobre o que uma casa compra de verdade ainda não foi medido.
- **Licença** ([termos de uso](https://world.openfoodfacts.org/terms-of-use), [guia de licença](https://openfoodfacts.github.io/documentation/docs/Product-Opener/api/tutorials/license-be-on-the-legal-side/)):
  - a base está sob a [ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/);
  - cada registro, sob a Database Contents License (DbCL);
  - as imagens, sob CC BY-SA 3.0, e podem conter elementos de terceiros (marcas, embalagens) que a licença não cobre.
- **Atribuição:** citar o Open Food Facts como autor, com link para openfoodfacts.org, e dizer a licença. Obras derivadas também precisam de atribuição. A versão francesa dos termos é a que vale, sob a lei francesa.
- **Share-alike (ODbL 4.4 e 4.6):** uma base derivada usada publicamente precisa sair sob a ODbL, e quem a recebe tem direito a uma cópia legível por máquina, ou ao método usado para fazê-la. Não se pode juntar a ela conteúdo de licença incompatível. Extrair e reaproveitar uma parte substancial já cria uma base derivada, e, pela definição de "Substantial" da ODbL, a extração repetida e sistemática de partes pequenas pode equivaler a uma parte substancial.
- **O que não contamina:** uma *Collective Database* (a base sem modificação, ao lado de outras independentes) e uma *Produced Work* (uma tela, uma imagem, um resultado) não obrigam o resto a sair sob a ODbL. A obra produzida só precisa do aviso "Contém informações de…" (ODbL 4.3 e 4.5).
- **Acesso:**
  - dumps completos todas as noites, em JSONL, CSV (o de alimentos tem cerca de 0,9 GB comprimido), Parquet e MongoDB, com deltas diários dos últimos 14 dias. Os deltas não marcam produtos apagados ([dados](https://world.openfoodfacts.org/data));
  - API com limite de 15 leituras de produto por minuto por IP. Num app, o limite vale por pessoa. Pede User-Agent próprio (`Bipa/versão (contato)`), e para mais que algumas centenas de produtos pede o dump em vez da API ([API](https://openfoodfacts.github.io/documentation/docs/Product-Opener/api/)).
- **Custo:** nenhum.
- **A posição do projeto:** o wiki do Open Food Facts descreve um "pote comum", em que quem mistura os dados com outros devolve a mistura aberta. Quem não pode devolver não deve reaproveitar. A página do wiki bloqueou a leitura automática, e isso veio de um resumo de busca. Dúvidas vão para reuse@openfoodfacts.org.

### Cosmos (Bluesoft)

- **O que é:** base comercial brasileira por GTIN, com descrição, marca, NCM, CEST e faixa de preço. É usada por varejo e sistemas fiscais.
- **Cobertura:** grande no varejo brasileiro, mas a empresa não publica números que pudemos conferir.
- **Termos** ([termos de serviço](https://cosmos.bluesoft.com.br/termos_de_servico), [planos](https://cosmos.bluesoft.com.br/api-pricings)). As duas páginas recusaram a leitura automática (HTTP 403), e o que segue veio dos trechos mostrados pela busca:
  - o serviço é "de caráter restrito, para uso exclusivo do usuário";
  - a API é cobrada por consulta, numa franquia diária;
  - o plano gratuito (25 consultas por dia) não é mais oferecido a novos usuários e seria desligado para todos a partir de 01/10/2026;
  - os planos pagos têm limites de 100 a 500 consultas por dia e duram 12 meses.
- **Compatibilidade:** nada nos termos autoriza guardar a base, embarcá-la num app ou redistribuí-la. Consultar por bipe exige internet e uma chave da API dentro do app, que qualquer um extrai. Cada bipe vira uma consulta paga, e o código do produto vai para a Bluesoft. Também não pode ser misturado a um catálogo ODbL (ODbL 4.4).

### GS1 Brasil: Cadastro Nacional de Produtos e Verified by GS1

- **O que é:** o cadastro oficial dos donos de marca que têm código GS1 no Brasil. É a fonte com mais autoridade sobre o que um GTIN é.
- **Acesso** ([portal de APIs](https://portalapi.gs1br.org/), [API do CNP](https://portalapi.gs1br.org/pageApiCnp), [manual do Verified by GS1](https://gs1br.org/educacao-e-eventos/Documents/Manual%20do%20Usu%C3%A1rio%20-%20API%20Verified%20by%20GS1_v.03.pdf)). As páginas do portal não abriram para leitura automática, e o que segue veio dos trechos da busca:
  - a consulta é para associados ou para varejistas e distribuidores indicados por associações parceiras, com termo de cooperação técnica, para logística interna ou validação de dados;
  - a API do Verified by GS1 exige associação, e os dados regulatórios exigem um plano pago;
  - um produto só aparece se o dono da marca cadastrou os dados e permitiu compartilhá-los.
- **Custo e limite:** num fórum de 2018, a GS1 Brasil respondeu que não havia custo e que o limite era de 300 consultas por dia ([Projeto ACBr](https://www.projetoacbr.com.br/forum/topic/44547-gs1-consulta-de-produtos-via-api/)). Esse número não foi confirmado em fonte atual.
- **Compatibilidade:** o acesso foi pensado para empresas da cadeia de suprimento, não para um app de consumidor. Não achamos licença que permita redistribuir os dados ou embarcá-los. Seria preciso um acordo escrito com a GS1 Brasil.

### Outras fontes

- **Consulta GTIN da SEFAZ (Cadastro Centralizado de GTIN):** exige certificado ICP-Brasil de um emitente de NF-e ou NFC-e, e devolve descrição, NCM e CEST só se o dono da marca autorizou ([Tecnospeed, NT 2022.001](https://blog.tecnospeed.com.br/nota-tecnica-2022-001-da-nf-e-nfc-e)). Não serve a um app de consumidor.
- **O cupom fiscal da própria pessoa (fase 1):** a NFC-e traz, por item, a descrição da loja, o código (quando a loja o preenche) e o preço. São dados da compra da pessoa, sem licença de terceiros. Não é um catálogo pronto, mas aprende o que ela compra de fato.
- **Bases comerciais internacionais** (UPCitemdb, EAN-Search, Barcode Lookup): não foram pesquisadas a fundo. São pagas por consulta, fracas em produtos brasileiros e, em geral, não permitem guardar os dados.

### Comparação

| | Open Food Facts | Cosmos | GS1 Brasil | Cupom fiscal |
| --- | --- | --- | --- | --- |
| Cobertura no Brasil | 37 mil produtos, qualidade variável | Grande (não publicada) | Só o que o dono da marca liberou | Só o que a pessoa compra |
| Custo | Nenhum | Pago por consulta | Associação ou convênio | Nenhum |
| Licença | ODbL, aberta com share-alike | Uso exclusivo do contratante | Sem licença de redistribuição | Dados da pessoa |
| Offline e embarcado | Sim, pelo dump | Não | Não | Sim, depois da importação |
| Atualizar | Dump noturno, refeito a cada versão do app | Por consulta | Por consulta | A cada cupom |
| Base comunitária | Derivada sob ODbL | Proibido pelos termos | Precisa de acordo | Decisão própria da fase 2 |

## Decisão

- **A fonte do catálogo é o Open Food Facts.** Entram os produtos alimentícios e também os do Open Products Facts e do Open Beauty Facts (limpeza e higiene), pela decisão do mantenedor. Se o tamanho pesar no APK, o recorte dessas duas fontes encolhe antes de sair alguma delas. Cosmos e GS1 Brasil ficam de fora: os termos que achamos não permitem embarcar nem redistribuir, e eles exigem internet a cada bipe.
- **O recorte:**
  - produtos com o Brasil em `countries_tags`, mais os de prefixo GS1 brasileiro (789 e 790) que a etiqueta de país não pegou;
  - só os que têm nome e código válido (dígito verificador, ADR 0005);
  - só os campos que o app usa: código, nome em português, marca, quantidade (lida para tamanho e unidade, como na embalagem) e a categoria convertida para o `ProductKind`;
  - nenhuma imagem no arquivo. A foto continua seguindo o ADR 0010: baixada sob demanda, com a licença CC BY-SA e a fonte citadas na tela do produto.
- **O formato:**
  - um arquivo SQLite só de leitura (`catalogo.sqlite`), que vai nos assets do app, separado do banco da pessoa (ADR 0023);
  - bipar um código procura primeiro nas embalagens da pessoa e depois no catálogo. Achado no catálogo, a embalagem nasce na base da pessoa como cópia, marcada como vinda do catálogo (ADR 0023, lacuna C1);
  - o produto (o "Arroz branco" do ADR 0013) continua sendo sugerido pelo nome e pela categoria, e a pessoa confere, como hoje.
- **A geração:** o script `tool/catalogo/gerar.py` baixa os dumps, filtra, converte e gera o arquivo. Ele roda antes de cada versão do app, e o arquivo vai junto. Baixar o catálogo depois da instalação fica para quando o tamanho pesar.
  - **Fonte escolhida (29/10/2026):** os dumps noturnos, sem a API. Do Open Food Facts, o CSV (`en.openfoodfacts.org.products.csv.gz`, 1,5 GB); do Open Beauty Facts e do Open Products Facts, o JSONL (100 MB e 40 MB), que traz o nome em português. O script lê cada dump enquanto baixa e guarda só o recorte brasileiro. O Parquet do Hugging Face foi testado e descartado: ler só as colunas pela rede pede dezenas de milhares de requisições e não terminou em 20 minutos. Detalhes e comando em [tool/catalogo/README.md](../../tool/catalogo/README.md).
  - **Medido em 29/10/2026:** 40.944 produtos (39.845 do Open Food Facts, 515 do Open Beauty Facts, 584 do Open Products Facts), 71% com marca, 49% com tamanho e 22% com tipo. O arquivo tem **2,70 MB** e vai no repositório, para o build funcionar sem rodar o script.
- **Licença e atribuição:**
  - o arquivo gerado é uma base derivada do Open Food Facts (filtrada e convertida) e sai sob a ODbL, com o aviso e o link da licença dentro dele e no repositório;
  - o script e o arquivo de cada versão ficam públicos (o script no repositório, o arquivo numa release), para cumprir a ODbL 4.6;
  - a tela "Sobre" diz "Contém informações do Open Food Facts, disponíveis sob a ODbL", com o link;
  - a tela do produto cita a fonte quando a embalagem veio do catálogo;
  - nada de outra fonte de licença incompatível entra nesse arquivo.
- **O código do app não muda de licença.** A ODbL vale para a base, não para o programa que a lê.
- **Consulta online do Open Food Facts, para o código que o catálogo não tem:** fica desligada na primeira versão. Ligá-la depois seria uma escolha da pessoa, com User-Agent próprio, uma consulta por bipe real (nunca em lote) e fila quando não houver sinal (ADR 0002).
- **Devolver ao Open Food Facts** o produto que a pessoa cadastrou fica para depois, como opção explícita. Exige conta no Open Food Facts e o consentimento da pessoa.

### Fase 2: o que a ODbL faz com a base comunitária

Uma embalagem que veio do catálogo e vai para a base comunitária leva consigo dados do Open Food Facts. Uma a uma, são partes pequenas. Somadas de muitos aparelhos, a extração pode ser vista como "repetida e sistemática". Nesse caso, a base comunitária de produtos é uma base derivada e precisa sair sob a ODbL. O projeto deve partir dessa leitura, que é a mais segura.

As saídas possíveis, para o ADR de sincronização escolher:

1. **A base comunitária de produtos sai sob a ODbL,** e os preços ficam numa base separada, que cita as embalagens só pelo código de barras. É o caminho mais simples e combina com o "pote comum".
   - Risco: a ODbL e o guia de bases coletivas do OpenStreetMap ([Collective Database Guideline](https://osmfoundation.org/wiki/Licence/Community_Guidelines/Collective_Database_Guideline_Guideline), que é do OSM, não do Open Food Facts) tratam como não independentes duas bases que se referenciam por chave. O código de barras é um identificador público da GS1, não uma chave do Open Food Facts, mas é também a chave dele. Há risco de alguém considerar os preços parte da base derivada.
2. **A base comunitária inteira, produtos e preços, sai sob a ODbL.** Não há dúvida sobre o que é derivado, e os dados de preço ficam abertos para todos. Fecha a porta para vender ou fechar a base de preços.
3. **A base comunitária não recebe nada que veio do catálogo,** só o código e o que a pessoa digitou. Exige saber a origem de cada campo, perde a maior parte dos nomes e marcas, e uma sugestão do catálogo aceita sem mudança continua sendo do catálogo. Não recomendado.

Antes da fase 2, a escolha passa por uma consulta a reuse@openfoodfacts.org e, se o projeto tiver fins comerciais, por um advogado.

## Consequências

- Bipar um produto conhecido não abre o cadastro, sem internet e sem mandar o código a ninguém.
- A cobertura será parcial e desigual. Muitos produtos de marca regional ou própria do mercado não estarão lá, e o cadastro de sempre continua sendo o caminho para eles. Antes de implementar, vale medir: cruzar os códigos dos cupons fiscais do mantenedor com o recorte e ver quantos acham produto.
- Os dados do catálogo podem vir errados ou em caixa alta. A folha de conferir continua mostrando tudo antes de salvar (ADR 0005), e a pessoa corrige na própria embalagem.
- O app passa a ter um compromisso de licença: aviso na tela "Sobre", fonte na tela do produto, o arquivo e o script públicos, e nenhuma fonte incompatível misturada ao catálogo. Ignorar isso coloca o app na lista de reúsos fora de conformidade do Open Food Facts.
- A escolha empurra a base comunitária da fase 2 para a ODbL, pelo menos na parte de produtos. Essa é a decisão de maior alcance deste ADR, e é por isso que ele fica "Proposto" até o mantenedor escolher.
- Cosmos ou GS1 só voltam a ser opção com acordo escrito que permita guardar e redistribuir. Mesmo assim, não entrariam no mesmo arquivo do Open Food Facts.
- Falta fazer:
  - a coluna de origem na embalagem (ADR 0023, C1);
  - a busca no catálogo no fluxo do bipe;
  - os textos de atribuição no ARB;
  - a medição de cobertura com cupons reais.
