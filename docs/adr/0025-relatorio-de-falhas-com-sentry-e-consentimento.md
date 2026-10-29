# 0025. Relatório de falhas com Sentry, só com consentimento

- Status: Aceito
- Data: 2026-10-28

## Contexto

Hoje um erro inesperado vira uma mensagem genérica na tela e uma linha no log do aparelho (`arquitetura.md`, "Erros"). Fora do emulador, ninguém vê esse log: um travamento no celular de quem usa o app só chega ao mantenedor se a pessoa contar. Antes da publicação na loja, o app precisa de um relatório de falhas.

O Bipa guarda coisas que dizem muito sobre uma casa: o que tem na despensa, quanto pagou em cada mercado, onde ficam os mercados que a pessoa frequenta. É offline-first, e o estoque e a lista nunca saem do aparelho (ADR 0007). Um relatório de falhas é a primeira coisa que manda dados para fora, e não pode levar nada disso junto.

Havia três caminhos:

- **Firebase Crashlytics:** gratuito e comum no Android, mas traz o Firebase inteiro (`google-services.json`, plugin do Gradle, Google Analytics sugerido junto), manda um identificador de instalação por padrão e não tem um filtro em Dart antes do envio: o que vai no relatório é decidido pelo SDK. Desligar a coleta é possível, mas o filtro de conteúdo teria de ser feito em cada chamada.
- **Só um registro local exportável:** nada sai do aparelho sem a pessoa mandar. Mas depende de a pessoa notar a falha, achar o registro e enviá-lo, o que quase nunca acontece. Um travamento na abertura nem deixa chegar à tela de exportar.
- **Sentry:** SDK oficial para Flutter (`sentry_flutter`) que pega erros do Dart e falhas nativas do Android, e tem dois ganchos em Dart, `beforeSend` e `beforeBreadcrumb`, que recebem cada evento e cada rastro antes do envio e podem limpá-los ou descartá-los. O plano gratuito basta para um app pequeno, o projeto pode ficar na região da União Europeia, e o servidor tem opções próprias de privacidade (não guardar IP, limpeza de dados no servidor).

## Decisão

- **Sentry**, com o pacote `sentry_flutter`. O filtro em Dart é o que decide: o que não passar por ele não sai do aparelho.
- **Desligado por padrão, só com consentimento (opt-in).** O Sentry só é iniciado quando há DSN no build **e** a pessoa aceitou. Sem resposta ou com "não", nada é iniciado, nenhum dado é coletado, nenhuma conexão é aberta.
- **O consentimento fica no aparelho**, num arquivo pequeno na pasta de suporte do app (`crash_reporting_consent`), lido antes do `runApp`. É uma preferência do aparelho, não um dado do domínio: não entra no banco nem muda o esquema. Tem três estados: nunca perguntado, aceito e recusado. A interface usa o primeiro para saber se ainda precisa perguntar.
- **Ligar e desligar valem na hora.** Aceitar grava a resposta e inicia o Sentry; recusar (ou revogar) fecha o Sentry e grava a resposta. O provider `crashReportingConsentProvider` e o caso de uso `SetCrashReportingConsent` em `lib/core/crash_reporting/` já fazem isso, prontos para a tela.
- **O DSN fica fora do repositório.** Ele entra no build por `--dart-define=SENTRY_DSN=...` e é lido com `String.fromEnvironment`. Build sem DSN (o de desenvolvimento, o dos testes, o de quem clona o repositório) nunca inicia o Sentry, mesmo com consentimento, e a interface não deve oferecer a pergunta (`crashReportingAvailableProvider` diz se há DSN).

### O que é enviado

- O tipo da exceção (`StateError`, `SqliteException`...) e a pilha de chamadas, que apontam o arquivo e a linha do código do app.
- A mensagem da exceção só para os erros do Dart cuja mensagem é escrita pela própria linguagem, sem dado de quem usa: `TypeError` ("type 'Null' is not a subtype of type 'String'"), `RangeError` e `IndexError` (índices), `ConcurrentModificationError`, `StackOverflowError`, `OutOfMemoryError` e `LateInitializationError`.
- Versão do app, do Android e do Flutter, modelo do aparelho, idioma e fuso horário: o que o SDK põe por padrão para reproduzir o erro.
- Rastros (breadcrumbs) do ciclo de vida do app (abriu, foi para o fundo, girou a tela), que não carregam texto da interface.

### O que é removido (`beforeSend` e `beforeBreadcrumb`)

- **Mensagens de exceção** de qualquer outro tipo: podem trazer o nome de um produto, um código de barras, o texto lido de uma etiqueta ou o SQL com valores. Fica o tipo, sai o texto.
- **A mensagem do evento**: fica só o modelo (`template`), quando houver, sem os parâmetros.
- **Rastros de navegação** (as rotas levam o id do produto ou do mercado), **de toque** (levam o texto do botão), **do console** (`print` e `debugPrint` podem ter qualquer coisa) e **de rede**. O filtro é por lista do que pode passar: só os rastros de ciclo de vida do app e do aparelho; qualquer categoria nova é descartada até alguém revisá-la.
- **Os detalhes do erro do Flutter** (`flutter_error_details`), que descrevem a árvore de widgets e podem incluir o texto na tela. Dos contextos ficam só os do aparelho, do sistema, do app, do runtime, da GPU, de idioma e do rastreamento; o nome do aparelho sai.
- **Pessoa e IP:** `sendDefaultPii: false`, e o filtro apaga o usuário do evento (`user`, com IP, id e localização), o nome do servidor, a requisição, os `extra` e a transação (que pode levar o nome da rota). Nomes de produto e de mercado, preços, estoque e coordenadas nunca são postos no evento pelo app; se aparecerem por acaso numa mensagem, a mensagem sai inteira.
- **Desligados no SDK:** captura de tela e da árvore de widgets, rastreamento de desempenho, rastros e rastreamento de toques, rastros de `print`, rastros nativos automáticos e sessões (que mandam um identificador de instalação).

A limpeza é uma função pura (`scrubEvent` e `scrubBreadcrumb`, em `crash_report_scrubber.dart`), com testes que montam eventos com nome de produto, coordenadas e mensagens com texto de quem usa.

### Onde a pergunta deve aparecer (proposta para o protótipo)

O visual é aprovado no protótipo antes de ser implementado, então a pergunta ainda não existe no app. A proposta, para virar quadro:

- **Não na primeira abertura.** A pessoa ainda não sabe o que o app faz, e uma pergunta de privacidade antes de bipar o primeiro item quebra o "calma por padrão".
- **Uma vez, depois da primeira compra terminada:** um cartão no Início, abaixo do resumo, com o porquê em uma frase ("Se o Bipa travar, mandar um relatório sem seus produtos, preços nem lugares?") e dois botões de mesmo peso, "Mandar" e "Não mandar". Fechar o cartão sem escolher conta como "não" e ele não volta. Nada fica pré-marcado.
- **Sempre revogável numa tela de Ajustes** (ou "Sobre o Bipa"), que ainda não existe: um interruptor "Relatório de falhas", com um link para o que é enviado. É o único lugar para mudar de ideia, nos dois sentidos.
- Em build sem DSN, nem o cartão nem o interruptor aparecem.

### LGPD

- **Base legal: consentimento** (art. 7º, I), livre, informado e para uma finalidade só: corrigir falhas do app. Como o relatório não leva dado que identifique a pessoa, o consentimento é também a forma mais simples de deixar a escolha com ela.
- **Revogar** é desligar o interruptor nos Ajustes (art. 8º, § 5º): o Sentry é fechado na hora e nada mais é enviado. Desinstalar o app também apaga a resposta.
- **O que já foi enviado** fica no projeto do Sentry pelo prazo de retenção do plano e pode ser apagado pelo mantenedor a pedido. O texto de privacidade da loja precisa dizer isso, junto com o que é enviado e o que é removido, na revisão de LGPD do roadmap.
- **Operador:** a Sentry (Functional Software, Inc.) trata os dados. Preferir a região da União Europeia ao criar o projeto e ligar, no servidor, "Prevent Storing of IP Addresses" e o "Data Scrubber" padrão, como segunda barreira.

## Consequências

- Falhas no celular de quem aceitou chegam ao mantenedor, com tipo, pilha e versão, sem o conteúdo da casa.
- Mensagens de exceção ficam pobres de propósito: muitas falhas vão chegar só com o tipo e a pilha. Quando isso não bastar, o caminho é uma exceção do app com mensagem escrita no código (sem interpolar dados), não afrouxar o filtro.
- **Falhas nativas** (Kotlin, Java e NDK, como as dos plugins de câmera e do ML Kit) são tratadas pelo SDK do Android e **não passam pelo filtro em Dart**. Elas recebem o `sendDefaultPii: false`, o escopo já limpo (sem usuário, com os rastros já filtrados) e os rastros nativos automáticos desligados. O texto da notificação ao vivo (ADR 0015) só iria junto se aparecesse na mensagem de uma exceção nativa. A limpeza do servidor cobre esse caso.
- Erros que o app já captura e transforma em mensagem na tela não são enviados: só falhas não tratadas. Mandar também os capturados é outra decisão.
- Sem a pergunta na interface, ninguém consegue ligar o relatório: até o quadro ser aprovado e a tela feita, o app continua sem enviar nada, mesmo num build com DSN.
- Para criar o projeto: no Sentry, um projeto Flutter; o DSN vai no build de publicação com `flutter build appbundle --dart-define=SENTRY_DSN=<dsn>`. Para subir os símbolos do código ofuscado, o `sentry_dart_plugin` pode entrar depois.
