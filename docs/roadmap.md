# Roadmap

## Fase 0: base sólida (em andamento)

- [x] Protótipo funcional: produtos, mercados com GPS, preços com OCR, estoque
- [x] Documentação: arquitetura, ADRs, convenções
- [x] Identidade visual e protótipo das telas principais
- [ ] Atualizar Gradle, Android Gradle Plugin e Kotlin
- [ ] Migrar para Riverpod com geração de código e freezed
- [ ] Implementar o design system em `lib/core/design_system/`, com fontes embutidas
- [ ] Textos em ARB (`flutter gen-l10n`)
- [ ] Redesenhar as telas conforme o protótipo: barra com botão de bipar, câmera direto, folha "Bipou!"
- [ ] Câmera própria na captura (pacote `camera`), com leitura ao vivo em vez de foto

## Fase 1: MVP para uso pessoal

- [ ] Importar cupom fiscal (QR Code da NFC-e) com fila offline
- [ ] Lista de compras, alimentada pelo que está acabando
- [ ] Sugestão de onde comprar a lista mais barata
- [ ] Previsão de consumo a partir do histórico do estoque
- [ ] Onboarding e explicação antes de pedir câmera e localização
- [ ] Backup e restauração local do banco
- [ ] Relatório de falhas e ícone do app

## Fase 2: base comunitária

- [ ] ADR de sincronização (servidor, autenticação, conflitos)
- [ ] API e envio da outbox (produtos, mercados, preços)
- [ ] Confiabilidade dos preços: origem, idade, confirmações
- [ ] Privacidade: revisão de LGPD e termos de uso
- [ ] Versão iOS
