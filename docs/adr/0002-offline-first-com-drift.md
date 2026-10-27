# 0002. Offline-first com SQLite (Drift) como fonte da verdade

- Status: Aceito
- Data: 2026-10-27

## Contexto

O app é usado dentro de mercados, onde o sinal costuma ser ruim, e deve funcionar sem servidor no início. Os dados são relacionais (produtos, mercados, preços, estoque) e as telas precisam reagir a mudanças.

## Decisão

Guardar tudo em SQLite no aparelho, acessado pelo Drift. O banco local é a fonte da verdade; o servidor, quando existir, será um parceiro de sincronização.

## Consequências

- Consultas tipadas, transações, chaves estrangeiras e streams reativas (`watch`) prontas.
- O Drift exige geração de código (`build_runner`) e migrações explícitas a cada mudança de esquema.
- Recursos que dependem de internet (consultar a nota fiscal, catálogo de produtos) entram como filas que são processadas quando houver conexão, nunca como requisito para usar o app.
