# Changelog

Todas as mudanças relevantes do projeto. O formato segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e as versões seguem o [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Não lançado]

### Adicionado
- Documentação de arquitetura, ADRs, guia de contribuição e roadmap.
- Identidade visual (Bipa Design System) e protótipo das telas principais.

## [0.1.0] - 2026-10-27

### Adicionado
- Cadastro de produtos por código de barras, com validação do dígito verificador.
- Mercados com localização e detecção automática do mercado atual.
- Registro de preços com leitura da etiqueta por OCR no aparelho.
- Comparação de preços entre mercados e preço por unidade (kg, L, un).
- Estoque da casa com mínimo, local e histórico de movimentos.
- Banco local SQLite (Drift) preparado para sincronização futura.
