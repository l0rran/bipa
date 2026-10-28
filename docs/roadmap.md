# Roadmap

## Fase 0: base sólida (em andamento)

- [x] Protótipo funcional: produtos, mercados com GPS, preços com OCR, estoque
- [x] Documentação: arquitetura, ADRs, convenções
- [x] Identidade visual e protótipo das telas principais
- [x] Atualizar Gradle, Android Gradle Plugin e Kotlin (9.3.1, 9.1.0 e 2.4.0)
- [ ] Migrar para Riverpod com geração de código e freezed
- [x] Implementar a base do design system em `lib/core/design_system/`: tokens gerados, paleta semântica (ADR 0009), tema, fontes embutidas e os componentes da Casa
- [ ] Textos em ARB (`flutter gen-l10n`): ligado, com a Casa; falta migrar as telas antigas
- [ ] Redesenhar as telas conforme o protótipo: barra com botão de bipar, câmera direto, folha "Bipou!"
- [x] Casa nova: busca com bipar, locais como categorias, prateleira de Acabando e lista com medidor de nível
- [ ] Casa: prévia da lista e carrossel de insights (dependem da lista de compras e da previsão de consumo)
- [ ] Modo compra: barra fixa acima da navegação com progresso e total, em todas as abas
- [x] Trocar "mínimo" por "ter sempre" (`StockItem.targetQuantity`, acabando abaixo dele)
- [ ] Fotos dos produtos (ADR 0010): miniatura com ícone da categoria pronta e `photoPath` no banco; falta tirar a foto ao bipar e buscar no Open Food Facts
- [ ] Câmera própria na captura (pacote `camera`), com leitura ao vivo em vez de foto
- [x] Preços com condição (ADR 0011): varejo, cartão da loja e atacado lidos da mesma etiqueta, com banco de testes do OCR em `tool/ocr_bench`
- [ ] Protótipo da confirmação com mais de um preço na etiqueta (hoje a captura mostra os outros preços como chips)
- [ ] Testar o OCR com fotos nítidas de etiquetas reais e acrescentá-las a `tool/ocr_bench/etiquetas_reais.py`

## Fase 1: MVP para uso pessoal

- [ ] Importar cupom fiscal (QR Code da NFC-e) com fila offline: registra os preços e abastece o estoque, e serve de onboarding
- [ ] Modos do bipar: "Preço" no mercado, "Comprei" e "Usei" em casa (bipar a embalagem vazia dá baixa e põe na lista)
- [ ] Desfazer em toda ação que muda o estoque; cada item bipado é salvo na hora
- [ ] Lista de compras, alimentada pelo que está acabando, com os itens de sempre sugeridos pelo ritmo de consumo
- [ ] Fechar o ciclo: o que é bipado em "Comprei" sai da lista e entra no estoque
- [ ] Sugestão de onde comprar a lista mais barata, comparando a lista inteira e mostrando a idade de cada preço
- [ ] Lista a partir de foto de lista de papel e por voz ("acabou o café"); widget de adicionar rápido
- [ ] Previsão de consumo a partir do histórico do estoque
- [ ] Onboarding e explicação antes de pedir câmera e localização
- [ ] Backup e restauração local do banco
- [ ] Relatório de falhas e ícone do app

## Fase 2: base comunitária

- [ ] ADR de sincronização (servidor, autenticação, conflitos)
- [ ] API e envio da outbox (produtos, mercados, preços)
- [ ] Confiabilidade dos preços: origem, idade, confirmações
- [ ] Pedir confirmação só do que falta: perto de um mercado, os preços mais antigos da sua lista
- [ ] Privacidade: revisão de LGPD e termos de uso
- [ ] Versão iOS
