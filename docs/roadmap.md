# Roadmap

## Fase 0: base sólida (em andamento)

- [x] Protótipo funcional: produtos, mercados com GPS, preços com OCR, estoque
- [x] Documentação: arquitetura, ADRs, convenções
- [x] Identidade visual e protótipo das telas principais
- [x] Atualizar Gradle, Android Gradle Plugin e Kotlin (9.3.1, 9.1.0 e 2.4.0)
- [ ] Migrar para Riverpod com geração de código e freezed
- [x] Implementar a base do design system em `lib/core/design_system/`: tokens gerados, paleta semântica (ADR 0009), tema, fontes embutidas e os componentes do Início
- [x] Textos em ARB (`flutter gen-l10n`): todas as telas; as mensagens das exceções do domínio continuam em português no código, porque o domínio não conhece o ARB
- [x] Redesenhar as telas conforme o protótipo: barra com botão de bipar, câmera direto, folha de conferir e salvar
- [x] Novo Início: busca com bipar, locais como categorias, prateleira de Acabando e lista com medidor de nível
- [x] Início: prévia da lista
- [ ] Início: carrossel de insights (depende da previsão de consumo)
- [x] Modo compra: barra fixa acima da navegação com progresso e total, em todas as abas
- [x] Trocar "mínimo" por "ter sempre" (`StockItem.targetQuantity`, acabando abaixo dele)
- [ ] Fotos dos produtos (ADR 0010): miniatura com ícone da categoria pronta e `photoPath` no banco; falta tirar a foto ao bipar e buscar no Open Food Facts
- [x] Câmera própria na captura (pacote `camera`), com leitura ao vivo em vez de foto
- [x] Preços com condição (ADR 0011): varejo, cartão da loja e atacado lidos da mesma etiqueta, com banco de testes do OCR em `tool/ocr_bench`
- [ ] Protótipo da confirmação com mais de um preço na etiqueta (hoje a captura mostra os outros preços como chips)
- [x] Etiqueta de gôndola com "/kg" e sem código: ler a unidade no `PriceTagParser` e escolher o produto pelo nome (ADR 0018)
- [ ] Testar o OCR com fotos nítidas de etiquetas reais e acrescentá-las a `tool/ocr_bench/etiquetas_reais.py`
- [ ] Revisar e fechar o modelo dos dados (tabelas, ids, o que é privado e o que sincroniza, o que pode ser apagado, e o catálogo pronto separado dos dados da pessoa) num ADR, antes do backup

## Fase 1: MVP para uso pessoal

- [ ] Importar cupom fiscal (QR Code da NFC-e) com fila offline: registra os preços e abastece o estoque, e serve de onboarding
- [ ] Catálogo pronto de produtos do mercado brasileiro: o app já vem com nome, marca, tamanho e categoria por código de barras, e bipar um produto conhecido não abre o cadastro. Pede um ADR de fonte e licença: a [Open Food Facts](https://openfoodfacts.github.io/documentation/docs/Product-Opener/api/tutorials/license-be-on-the-legal-side/) é aberta (ODbL na base, CC BY-SA nas imagens), mas exige atribuição e compartilhar a base derivada na mesma licença; o [Cadastro Nacional de Produtos da GS1 Brasil](https://gs1br.org/educacao-e-eventos/Documents/API%20de%20Cadastro%20e%20Consulta%20CNP_v3.pdf) e o Cosmos da Bluesoft precisam ter os termos de acesso e reuso conferidos. Decidir também o recorte (só produtos vendidos no Brasil), o tamanho no APK ou o download na primeira abertura, e a atualização
- [x] Modos do bipar: "Preço" no mercado, "Comprei" e "Usei" em casa, com a embalagem vazia pondo na lista ao dar baixa (ADR 0019)
- [x] Desfazer em toda ação de passagem que muda o estoque (bipes e gestos); os steppers se desfazem no próprio botão (ADR 0019); cada item bipado é salvo na hora
- [x] Lista de compras: itens de produto ou escritos à mão, os itens de sempre (os com "ter sempre"), seções do mercado, preço esperado e total estimado; "Pôr na lista" no Início
- [x] Modo compra: "Ir às compras" na prévia, barra da compra acima da navegação, item marcado ao registrar o preço e "Terminei", que leva o comprado ao estoque
- [x] Notificação ao vivo da compra (Android 16, Live Updates, ADR 0015)
- [x] Modo carrinho: câmera contínua, a bandeja com o "levar", o preço esperado do mercado e o total real; o disparo fotografa a etiqueta
- [x] Modo carrinho: ler a etiqueta ao vivo (OCR nos quadros da câmera), sem precisar fotografar
- [x] Produto e embalagens (ADR 0013): marca e tamanho por código de barras, folha de embalagem nova, estoque por embalagem com o total em kg, preço por kg e "Juntar com…"
- [x] Tela do produto: gráfico do preço nos últimos 6 meses (protótipo "Produto com embalagens")
- [x] Ordem dos corredores aprendida por mercado, a partir da ordem em que a pessoa bipa e marca (ADR 0014)
- [x] Preços da compra guardados com ela: sobrevivem ao fechamento do carrinho, esperam o mercado e vão junto quando ele muda (ADR 0020)
- [x] Uma câmera só: o disparo e o teclado usam a câmera ao vivo e a folha "Conferir e salvar", aposentando o formulário "Bipar preço" e o leitor antigo
- [x] Quantidade na compra: "1 de 3" na lista e na bandeja, e o que faltou continua na lista
- [ ] Itens de sempre pelo ritmo de consumo (hoje são os produtos com "ter sempre")
- [x] Fechar o ciclo: o que é bipado em "Comprei" sai da lista e entra no estoque (o "Terminei" do modo compra já faz isso com o que foi marcado)
- [x] Sugestão de onde comprar a lista mais barata, comparando a lista inteira e mostrando a idade de cada preço
- [ ] Lista a partir de foto de lista de papel e por voz ("acabou o café"); widget de adicionar rápido
- [ ] Previsão de consumo a partir do histórico do estoque
- [ ] Onboarding (a explicação antes de pedir localização e notificação já existe)
- [ ] Backup e restauração local do banco, depois de fechar o modelo dos dados
- [ ] Relatório de falhas e ícone do app

### Ajustes de UX (análise de 28/10/2026)

Os achados da [análise de UX](https://claude.ai/artifact/VeoUk6VjBSRWCox1prVyMr) que ainda faltam, com o código de cada um. Os já feitos estão no CHANGELOG.

Primeira abertura e em casa:

- [ ] AB5: primeira carga que configura: folha "Arrumar o que entrou" com local e "ter sempre", ou o local sugerido pela categoria

Câmera e modo carrinho:

- [ ] D3 (resto): o preço por kg do granel como estimativa na bandeja; hoje a linha entra sem preço

Preços, mercados e produto:

- [ ] G2: mover uma embalagem para outro produto e apagar uma embalagem (com ADR)

Consistência e acessibilidade:

- [ ] H1: a aba Produtos com os componentes de Mercados, e os formulários de produto e de mercado no design system
- [ ] H2 (resto): exceções do domínio traduzidas pelo ARB e falha tratada no stepper do produto (os textos de falha já seguem "Não deu para … Tente de novo.")
- [ ] H3 (resto): teste com fonte em 200% em cada tela (o stepper e o número da seção já crescem; os selos não têm altura fixa)
- [ ] A barra de navegação encolhe ao rolar, como no design system
- [ ] Desenhar no protótipo o que o app já faz sem quadro: o "Desfazer" no aviso da câmera em "Comprei" e "Usei", o mercado e a idade no preço em destaque velho do produto, o chip "Ter sempre" no editor da linha do Início e a folha "Editar embalagem"

## Fase 2: base comunitária

- [ ] ADR de sincronização (servidor, autenticação, conflitos)
- [ ] API e envio da outbox (produtos, mercados, preços)
- [ ] Confiabilidade dos preços: origem, idade, confirmações
- [ ] Pedir confirmação só do que falta: perto de um mercado, os preços mais antigos da sua lista
- [ ] Privacidade: revisão de LGPD e termos de uso
- [ ] Versão iOS
