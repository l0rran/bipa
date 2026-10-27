# Changelog

Todas as mudanças relevantes do projeto. O formato segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e as versões seguem o [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Não lançado]

### Adicionado
- Documentação de arquitetura, ADRs, guia de contribuição e roadmap.
- Identidade visual (Bipa Design System) e protótipo das telas principais.
- Casa nova: busca com bipar, locais como categorias, prateleira de "Acabando" com cartões e medidor de nível, e lista "Em casa" com editor ao tocar e baixa por gesto com Desfazer.
- Barra de navegação de vidro com o botão de bipar no centro e a aba Lista (por enquanto, um aviso).
- Design system no código: paleta semântica gerada de `design/tokens.json`, tema do Material 3 e fontes embutidas.
- Miniatura do produto com foto ou ícone da categoria, e o campo de foto no banco (esquema 2).
- Textos da Casa em ARB (`flutter gen-l10n`).

### Alterado
- Paleta: o amarelo da etiqueta é a cor da marca, com o coral como única cor de alerta.
- "Mínimo" virou "ter sempre": o item está acabando quando fica abaixo desse número.
- Gradle 9.3.1, Android Gradle Plugin 9.1.0 e Kotlin 2.4.0; o app pede Flutter 3.47 ou mais novo.

## [0.1.0] - 2026-10-27

### Adicionado
- Cadastro de produtos por código de barras, com validação do dígito verificador.
- Mercados com localização e detecção automática do mercado atual.
- Registro de preços com leitura da etiqueta por OCR no aparelho.
- Comparação de preços entre mercados e preço por unidade (kg, L, un).
- Estoque da casa com mínimo, local e histórico de movimentos.
- Banco local SQLite (Drift) preparado para sincronização futura.
