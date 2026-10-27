# Bipa

App Android para cuidar do estoque da casa e pagar menos no mercado, **100% offline** e com o mínimo de digitação: a câmera lê códigos de barras e etiquetas de preço.

> Status: protótipo funcional (v0.1). A fase atual constrói a base sólida do projeto; veja o [roadmap](docs/roadmap.md).

## O que já faz

- **Bipar preço:** a foto da etiqueta da gôndola preenche preço, promoção "de/por", código de barras e nome do produto. O reconhecimento roda no aparelho.
- **Mercado detectado pelo GPS:** ao registrar um preço, o app identifica em qual mercado cadastrado você está.
- **Comparação de preços:** último preço em cada mercado, menor preço em destaque e preço por kg, L ou unidade.
- **Estoque da casa:** entrada e saída com um toque, quantidade mínima, local e lista do que está acabando.

## Rodando

Pré-requisitos: Flutter 3.32+ (Dart 3.8+) e Android SDK.

```bash
flutter pub get
dart run build_runner build -d
flutter run
```

Testes: `flutter test`. Mais detalhes, convenções de commit e solução de problemas em [docs/contribuindo.md](docs/contribuindo.md).

### Testes do banco no Windows

Os testes de repositório usam SQLite em memória, que precisa da biblioteca nativa na máquina. No Windows, se os testes falharem ao carregar `sqlite3.dll`, baixe "Precompiled Binaries for Windows" (x64) em sqlite.org e coloque o `sqlite3.dll` na raiz do projeto.

## Documentação

- [Arquitetura](docs/arquitetura.md): camadas, estado, dados offline-first e testes
- [Decisões de arquitetura (ADRs)](docs/adr/README.md)
- [Identidade visual](docs/design/identidade-visual.md)
- [Roadmap](docs/roadmap.md) e [Changelog](CHANGELOG.md)
