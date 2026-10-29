# Roadmap

## Fase 0: base sólida (em andamento)

- [x] Protótipo funcional: produtos, mercados com GPS, preços com OCR, estoque
- [x] Documentação: arquitetura, ADRs, convenções
- [x] Identidade visual e protótipo das telas principais
- [x] Atualizar Gradle, Android Gradle Plugin e Kotlin (9.3.1, 9.1.0 e 2.4.0)
- [ ] Migrar para Riverpod com geração de código e freezed
- [x] Implementar a base do design system em `lib/core/design_system/`: tokens gerados, paleta semântica (ADR 0009), tema, fontes embutidas e os componentes do Início
- [x] Textos em ARB (`flutter gen-l10n`): todas as telas, e as exceções do domínio por código (`DomainErrorCode`)
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
- [x] Revisar e fechar o modelo dos dados num ADR, antes do backup (ADR 0023, com as lacunas B1–B4 fechadas; as S* ficam para a sincronização)
- [ ] Migrar o Android para o Kotlin embutido do Flutter (o build avisa que o plugin do Kotlin vai quebrar em versões futuras)

## Fase 1: MVP para uso pessoal

- [ ] Importar cupom fiscal (QR Code da NFC-e) com fila offline: registra os preços e abastece o estoque, e serve de onboarding
- [x] Catálogo pronto de produtos do mercado brasileiro (ADR 0024): 40.944 produtos do Open Food Facts, Open Products Facts e Open Beauty Facts em `assets/catalog/catalogo.sqlite` (2,7 MB), gerado por `tool/catalogo`; bipar um código do catálogo preenche a "Embalagem nova" e a atribuição está em "Sobre o Bipa"
- [ ] Medir a cobertura do catálogo com cupons reais do mantenedor (`py -3 tool/catalogo/cobertura.py`)
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
- [x] Backup e restauração local (ADR 0023, lacuna B5): o `.bipa` diário em `backup/ultimo.bipa`, "Salvar uma cópia…" e "Restaurar de um arquivo…" em Ajustes, com conferência, Desfazer e o cartão "Backup encontrado" no celular novo
- [x] Ícone do app: a etiqueta amarela com o "b" (proposta 1, em `docs/design/icone/`)
- [x] Relatório de falhas com Sentry só com consentimento (ADR 0025): a pergunta no Início depois da primeira compra e o interruptor em Ajustes
- [ ] Criar o projeto no Sentry (região UE, sem guardar IP) e gerar os builds de publicação com `--dart-define=SENTRY_DSN=...`

### Ajustes de UX (análise de 28/10/2026)

Os achados da [análise de UX](ux/analise-ux-2026-10-28.md) ([publicada](https://claude.ai/artifact/VeoUk6VjBSRWCox1prVyMr)) que ainda faltam, com o código de cada um. Os já feitos estão no CHANGELOG.

Primeira abertura e em casa:

- [x] AB5 (parte): o item novo nasce no local sugerido pela categoria do produto
- [x] AB5 (resto): folha "Arrumar o que entrou" com local e "ter sempre", ao fechar a câmera de casa com 3 ou mais itens novos

Câmera e modo carrinho:

- [x] D3 (resto): o preço por kg do granel como estimativa na bandeja

Preços, mercados e produto:

- [x] G2: mover uma embalagem para outro produto e apagar uma embalagem, com Desfazer (ADR 0022)

Consistência e acessibilidade:

- [x] H1: a aba Produtos com os componentes de Mercados
- [ ] H1 (resto): os formulários de produto e de mercado no design system (a busca já ignora acento, G4)
- [x] H2 (resto): exceções do domínio traduzidas pelo ARB e falha tratada no stepper do produto
- [x] H3 (resto): teste com fonte em 200% nas telas principais e alturas mínimas no lugar de fixas
- [x] H3 (formulários): o teste com fonte em 200% cobre os formulários de produto, mercado e embalagem, a folha do preço e "Editar embalagem" (a câmera e a tela do carrinho não montam em teste)
- [x] A barra de navegação encolhe ao rolar, como no design system
- [x] Barra de navegação igual ao design system: 68 px, desfoque 18 e o anel que respira (a saturação do vidro ficou de fora)
- [x] Desenhar no protótipo o que o app já faz sem quadro (quadros de 28/10, com as divergências resolvidas no README do protótipo)
- [ ] Levar ao protótipo e ao design system publicados no claude.ai as mudanças feitas nas cópias do repositório (quadros novos, ícone, variantes, guias)

### Ajustes de UX (análise do lote 8, 28/10/2026)

Os achados da [análise do lote 8](ux/analise-ux-2026-10-28-lote8.md), feita depois da AB5, D3, H2, H3 e da barra que encolhe.

- [x] D8 (alto): o valor digitado numa linha de granel ou pesagem não vira preço do produto no histórico (ADR 0018)
- [x] AB9: corrigir o local sugerido (leite de caixinha, enlatados e "Ovomaltine" não vão para a Geladeira; congelados vão para o Freezer) e dizer no aviso da câmera onde o item ficou
- [x] AB10 (parte): a folha do item mostra o local sugerido enquanto o item não existe
- [x] AB10 (resto): "Tirar de casa" lembra o local escolhido, e o item volta a nascer ali (ADR 0021, esquema v14)
- [x] AB9 (resto): o local fica dentro do aviso da câmera ("1 na Despensa ▾"), e o toque abre a escolha
- [x] H11: o stepper da linha do Início e da folha do item avisa quando falha, como o da tela do produto
- [x] D9: a linha do granel na bandeja com o traço e o preço por kg sob o nome, e o diálogo "Quanto deu…" com o peso de volta
- [x] H8, H9, H10: a barra com letra grande (A até 160%, B acima), o nome do produto inteiro e um teste que mede leitura a 360 dp

### Ajustes de UX (análise do lote 9, 28/10/2026)

Os achados da [análise do lote 9](ux/analise-ux-2026-10-28-lote9.md), feita depois da barra com letra grande, G2, H1, D9, AB5, AB9, ícone, Sentry e o toast que some sozinho.

- [x] G4 (alto): a busca de produtos ignora acento e casa palavra por palavra, também na escolha de produto (granel e "Mover embalagem"), e não oferece "Cadastrar" quando já há um parecido (junto com o "H1 (resto)")
- [x] AB11 e H14: o aviso da câmera de casa respeita o TalkBack como o toast, e a linha do tempo do toast respeita "Remover animações"
- [x] H13 e H15: o toast pausa ao toque, dura mais em ações grandes ("Tirar comprados"), segue o "Tempo para agir" do Android, e as falhas aparecem acima das folhas
- [x] F5: a idade do preço na lista de Produtos quando ele é velho
- [x] D10, G5: "Quanto deu…" sem artigo, com o peso anunciado e erro visível; depois de mover, caminho para o produto de destino e nome da embalagem sem rótulo
- [x] AB12, AB13: o aviso com local em duas linhas (o local nunca corta), e a folha "Arrumar o que entrou" só com o que ninguém conferiu, sem mínimo
- [x] H12: com letra acima de 160% durante a compra, a barra da compra assume o lugar do bipar flutuante, com o toque longo do menu
- [x] H16: o anel respira duas vezes e para; sem fim só com casa e lista vazias; parado na compra
- [x] Atualizar `processo.md`, `ScanNavBar.md` e `BipFeedback.md` com o que foi decidido, e redesenhar CapturaComprei e CapturaUsei com o chip do modo

### Ajustes de UX (análise do lote 10, 28/10/2026)

Os achados da [análise do lote 10](ux/analise-ux-2026-10-28-lote10.md), feita depois da busca sem acento, dos avisos que esperam a pessoa, de AB12, AB13, H12, H16 e de Ajustes.

- [x] G6 (alto) e G7: o recorte da etiqueta guarda a variedade do granel ("Banana prata" não vira "Banana") e oferece "Cadastrar" quando a etiqueta tem palavra a mais; o nome novo ganha os acentos comuns; a busca do Início usa a mesma regra da aba Produtos
- [x] H17 e H18: o texto do cartão do relatório de falhas diz tudo o que vai (como os Ajustes), com link para eles, e o cartão fica depois de "Acabando" e só na abertura seguinte à compra. Antes do primeiro build com DSN
- [ ] AB14: escolher o local no aviso da câmera não pode tirar a pergunta do "ter sempre" (quadro "CapturaCasaLocal" antes)
- [x] G8: o Desfazer depois de mover para um produto novo volta para a origem, não para "Produto não encontrado"
- [ ] H19: o anel do bipar não volta a respirar a cada volta de tela cheia (regra no design system antes)
- [ ] H1 (resto) inclui a escolha de produto (`product_picker_sheet.dart`, ainda com `TextField`, `ListTile` e `CircleAvatar`), com quadro da dica "Na etiqueta" e dos dois caminhos (produto achado e "Criar" a variedade)

### Ajustes de UX (análise do lote 11, 29/10/2026)

Os achados da [análise do lote 11](ux/analise-ux-2026-10-29-lote11.md), feita depois de G6, G7, H17, H18 e G8.

- [x] G9 e G11: uma palavra diferente na etiqueta ("LIMAO TAITI" com "Limão tahiti") não pode esconder o produto que existe (abrir a busca com a primeira palavra e manter o recorte como nome a criar); acentos das palavras de balança que faltam (francês, grão, linguiça, abóbora, suíno, parmesão)
- [x] G10 e H18 (resto): o aviso "ficou sem embalagem" espera o Desfazer fechar, e o cartão do relatório de falhas some durante a busca e o filtro de local
- [ ] Redesenhar a cópia do quadro InicioRelatorioFalhas com o texto novo do cartão e a posição depois de "Acabando"

### Ajustes de UX (análise do lote 12, 29/10/2026)

Os achados da [análise do lote 12](ux/analise-ux-2026-10-29-lote12.md), feita depois do backup (B5) e do catálogo pronto.

- [x] BK1 (crítico) e BK4: backup que não se perde. O `ultimo.bipa` do celular antigo precisa continuar restaurável pelos Ajustes (não só pelo cartão do Início, que some com o primeiro item), o backup diário não pode parar calado nem um "Fazer backup agora" gravar por cima de um backup de outro aparelho sem perguntar, e a casa vazia do cartão se decide por `isEmpty()`. Quadro e decisão antes. Antes de qualquer build para outras pessoas
- [x] BK2 e BK3: o Desfazer da restauração dura o mesmo que o aviso (TalkBack, "Tempo para agir", dedo em cima); a confirmação mostra os mesmos três números dos dois lados e a data com ano
- [x] G12 e G13: catálogo que não junta (o produto da pessoa começa o nome sugerido; versão e linha não bloqueiam; sabor e tipo bloqueiam; a marca fica quando sobra só o sabor). Fica o G14 e a linha "No catálogo: …" (quadro antes)
- [ ] G14 e o resto do G12: o gerador fica só com nomes em português, a grafia da marca e o tamanho por massa ("1 u, 120 g"); a folha mostra "No catálogo: …" (quadro antes)
- [ ] H20 e G15: atribuição com link, com o texto de "Sobre" no ARB citando as três bases, e a linha "Dados do Open Food Facts" como link para a ficha (quadros antes)

## Fase 2: base comunitária

- [ ] ADR de sincronização (servidor, autenticação, conflitos)
- [ ] API e envio da outbox (produtos, mercados, preços)
- [ ] Confiabilidade dos preços: origem, idade, confirmações
- [ ] Pedir confirmação só do que falta: perto de um mercado, os preços mais antigos da sua lista
- [ ] Privacidade: revisão de LGPD e termos de uso
- [ ] Versão iOS
- [ ] Licença da base comunitária (ADR 0024, Fase 2): consultar reuse@openfoodfacts.org antes de decidir
