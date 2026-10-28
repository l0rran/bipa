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

Os achados da [análise de UX](ux/analise-ux-2026-10-28.md) ([publicada](https://claude.ai/artifact/VeoUk6VjBSRWCox1prVyMr)) que ainda faltam, com o código de cada um. Os já feitos estão no CHANGELOG.

Primeira abertura e em casa:

- [x] AB5 (parte): o item novo nasce no local sugerido pela categoria do produto
- [ ] AB5 (resto): folha "Arrumar o que entrou" com local e "ter sempre" (quadro no protótipo antes)

Câmera e modo carrinho:

- [x] D3 (resto): o preço por kg do granel como estimativa na bandeja

Preços, mercados e produto:

- [ ] G2: mover uma embalagem para outro produto e apagar uma embalagem (com ADR)

Consistência e acessibilidade:

- [ ] H1: a aba Produtos com os componentes de Mercados, e os formulários de produto e de mercado no design system
- [x] H2 (resto): exceções do domínio traduzidas pelo ARB e falha tratada no stepper do produto
- [x] H3 (resto): teste com fonte em 200% nas telas principais e alturas mínimas no lugar de fixas
- [ ] H3 (formulários): o teste com fonte em 200% ainda não cobre os formulários de produto, mercado e embalagem, a folha do preço, a câmera e a tela do carrinho
- [x] A barra de navegação encolhe ao rolar, como no design system
- [ ] Barra de navegação igual ao design system: 68 px de altura (o código usa 72), desfoque 18 (o código usa 14) e o anel que respira no botão de bipar
- [ ] Desenhar no protótipo o que o app já faz sem quadro: o "Desfazer" no aviso da câmera em "Comprei" e "Usei", o mercado e a idade no preço em destaque velho do produto, o chip "Ter sempre" no editor da linha do Início, a folha "Editar embalagem" e a linha do granel na bandeja com o preço por kg estimado

### Ajustes de UX (análise do lote 8, 28/10/2026)

Os achados da [análise do lote 8](ux/analise-ux-2026-10-28-lote8.md), feita depois da AB5, D3, H2, H3 e da barra que encolhe.

- [x] D8 (alto): o valor digitado numa linha de granel ou pesagem não vira preço do produto no histórico (ADR 0018)
- [x] AB9: corrigir o local sugerido (leite de caixinha, enlatados e "Ovomaltine" não vão para a Geladeira; congelados vão para o Freezer) e dizer no aviso da câmera onde o item ficou
- [x] AB10 (parte): a folha do item mostra o local sugerido enquanto o item não existe
- [ ] AB10 (resto): "Tirar de casa" lembra o local escolhido. Pede mudar o esquema (coluna em `StockItems`, migração v14) e um ADR curto; espera o mantenedor
- [ ] AB9 (resto): tocar no local do aviso da câmera abre a escolha (quadro no protótipo antes)
- [x] H11: o stepper da linha do Início e da folha do item avisa quando falha, como o da tela do produto
- [ ] D9: a linha do granel na bandeja com sinal próprio para o preço por kg (quadro no protótipo antes; substitui o quadro da linha do granel pedido acima)
- [ ] H8, H9, H10: rodada de letra grande: rótulos da navegação que cortam, nome do produto que perde para o preço e um teste que meça leitura, não só estouro (junto com o "H3 (formulários)")

## Fase 2: base comunitária

- [ ] ADR de sincronização (servidor, autenticação, conflitos)
- [ ] API e envio da outbox (produtos, mercados, preços)
- [ ] Confiabilidade dos preços: origem, idade, confirmações
- [ ] Pedir confirmação só do que falta: perto de um mercado, os preços mais antigos da sua lista
- [ ] Privacidade: revisão de LGPD e termos de uso
- [ ] Versão iOS
