# Bipa

App Android para controlar o estoque da casa e acompanhar preços de mercado,
**100% offline**, com o mínimo possível de digitação: a câmera lê códigos de
barras e etiquetas de preço.

## Funcionalidades (v0.1)

- **Bipar preço**: fotografe a etiqueta da gôndola; o OCR (no aparelho, sem
  internet) preenche o preço, o preço sem desconto ("de/por"), o código de
  barras e o nome do produto. Você só confere e salva.
- **Mercado detectado pelo GPS**: ao abrir a captura, o app identifica em qual
  mercado cadastrado você está (raio de 150 m).
- **Produtos** por código de barras (EAN/UPC), com validação do dígito
  verificador e preço normalizado por kg/L/unidade.
- **Comparação de preços**: último preço em cada mercado, menor preço em
  destaque e histórico completo.
- **Estoque**: entrada e saída com um toque, quantidade mínima, local
  (despensa, geladeira, freezer) e lista do que está acabando.

## Rodando o projeto

Pré-requisitos: Flutter 3.32+ (Dart 3.8+) e Android SDK.

```bash
# 1. Gera os arquivos da plataforma Android que não estão no repositório
#    (os arquivos existentes, como o AndroidManifest.xml, são preservados).
flutter create . --platforms=android --org dev.l0rran --project-name bipa

# 2. Dependências e código gerado do banco (Drift)
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# 3. Testes e execução
flutter test
flutter run
```

Depois do passo 1, faça commit da pasta `android/` gerada.

Se o build Android reclamar da versão mínima do SDK (`minSdk`), ajuste em
`android/app/build.gradle.kts` para `minSdk = 23` ou maior.

### Testes do banco no Windows

Os testes de repositório usam SQLite em memória (`NativeDatabase.memory()`),
que precisa da biblioteca nativa do SQLite na máquina. No Windows, se os testes
falharem com erro de carregamento de `sqlite3.dll`, baixe o
"Precompiled Binaries for Windows" em sqlite.org e coloque o `sqlite3.dll`
na raiz do projeto (ele está fora do controle de versão por padrão).

## Arquitetura

Organização por funcionalidade, cada uma em camadas:

```
lib/
├── app/                 # MaterialApp, tema, rotas e shell de navegação
├── core/                # Base compartilhada
│   ├── database/        # Drift: tabelas e AppDatabase
│   ├── location/        # GeoPoint (haversine) e serviço de GPS
│   ├── money/           # Money: valores em centavos (sem double)
│   └── ...
└── features/
    ├── products/        # domain / data / presentation
    ├── markets/
    ├── prices/          # inclui o parser de etiquetas (OCR → preço)
    └── stock/
```

- **domain**: entidades imutáveis, contratos de repositório e regras de
  negócio em Dart puro (sem Flutter), testáveis com fakes.
- **data**: implementações com Drift (SQLite) e ML Kit.
- **presentation**: telas e providers do Riverpod (injeção de dependências).

### Decisões para a sincronização comunitária (próxima fase)

- **Banco local é a fonte da verdade**; o servidor será um parceiro de
  sincronização.
- **IDs UUID gerados no aparelho**, sem colisão entre usuários.
- **Preços são eventos imutáveis** (só inserção), o que elimina conflitos.
- Tabelas compartilháveis (`products`, `markets`, `price_observations`) têm
  `synced_at`: nulo significa pendente de envio (padrão outbox). O estoque é
  privado e nunca sai do aparelho.
- A origem do preço (`manual`, `etiqueta`, `cupom fiscal`) é registrada para
  pesar a confiabilidade na base comunitária.

## Próximos passos

- Importar o cupom fiscal (QR Code da NFC-e) com fila offline.
- Previsão de consumo a partir do histórico de movimentos do estoque.
- Lista de compras com sugestão do mercado mais barato.
- Sincronização com o servidor.
