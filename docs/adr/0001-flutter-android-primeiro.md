# 0001. Usar Flutter, começando pelo Android

- Status: Aceito
- Data: 2026-10-27

## Contexto

O app depende muito de câmera e reconhecimento de imagem, precisa funcionar offline e deve chegar ao iOS no futuro. O desenvolvimento é feito por uma pessoa, então manter duas bases de código nativas sairia caro.

## Decisão

Usar Flutter (Dart 3.8+) com uma base de código única. A primeira plataforma suportada é o Android.

## Consequências

- Os plugins de câmera, ML Kit, geolocalização e SQLite são maduros no Flutter.
- O código não deve assumir Android: nada de APIs exclusivas fora de plugins. Levar ao iOS deve exigir só configuração (permissões no `Info.plist`, assinatura).
- A pasta `ios/` não é versionada até o iOS entrar no roadmap.
