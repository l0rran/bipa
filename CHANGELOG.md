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
- Preços com condição (ADR 0011): a etiqueta de atacarejo vira até três preços (varejo, cartão da loja e atacado a partir de N unidades), todos salvos e mostrados no histórico. O esquema vai à versão 3.
- Banco de testes do OCR em `tool/ocr_bench`, com etiquetas sintéticas e transcrições de etiquetas reais.

### Alterado
- Paleta: o amarelo da etiqueta é a cor da marca, com o coral como única cor de alerta.
- "Mínimo" virou "ter sempre": o item está acabando quando fica abaixo desse número.
- O preço clube deixa de ser tratado como promoção: vira o preço com cartão da loja.
- A comparação entre mercados usa o preço sem condição.
- Gradle 9.3.1, Android Gradle Plugin 9.1.0 e Kotlin 2.4.0; o app pede Flutter 3.47 ou mais novo.

### Corrigido
- Leitura da etiqueta: centavos sobrescritos lidos à parte, milhar ("1.299,90"), preço seguido de KG ou UN, parcelas confundidas com o preço, dígitos espaçados pelo OCR e rótulos como "LEVE 3 PAGUE 2" tomados pelo nome do produto.
- Etiqueta com mais de um preço e nenhum rótulo lido (foto de longe ou borrada) não grava mais o preço do cartão ou do atacado como varejo: o campo fica em branco e os valores lidos ficam para tocar. Um preço lido sem a vírgula ao lado de outro ("13,89 1535") também entra entre os valores.

## [0.1.0] - 2026-10-27

### Adicionado
- Cadastro de produtos por código de barras, com validação do dígito verificador.
- Mercados com localização e detecção automática do mercado atual.
- Registro de preços com leitura da etiqueta por OCR no aparelho.
- Comparação de preços entre mercados e preço por unidade (kg, L, un).
- Estoque da casa com mínimo, local e histórico de movimentos.
- Banco local SQLite (Drift) preparado para sincronização futura.
