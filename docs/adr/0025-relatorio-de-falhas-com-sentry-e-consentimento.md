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
- **Ligar e desligar valem na hora.** Aceitar grava a resposta e inicia o Sentry; recusar (ou revogar) fecha o Sentry e grava a resposta. O provider `crashReportingConsentProvider` e o caso de uso `SetCrashReportingConsent` em `lib/core/crash_reporting/` já fazem isso, e são o que o cartão do Início e o interruptor dos Ajustes chamam.
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

### Onde a pergunta aparece

O quadro foi aprovado em 28/10/2026 (`InicioRelatorioFalhas` e `Ajustes`, no [protótipo](../design/prototipo/README.md)) e está no app:

- **Não na primeira abertura.** A pessoa ainda não sabe o que o app faz, e uma pergunta de privacidade antes de bipar o primeiro item quebra o "calma por padrão".
- **Uma vez, na abertura do app seguinte à primeira compra terminada** (`CrashReportingAskCard`, no Início). O cartão fica **depois de "Acabando"** e antes de "Em casa" (o quadro foi desenhado sem "Acabando"; na análise de UX de 28/10, H18, o cartão acima dele empurrava para baixo a informação que o Início existe para dar). É neutro, sem cor de destaque, com o porquê em poucas frases ("Se o Bipa travar, mandar um relatório?"; "Vão o erro e dados do celular, como modelo e versão. Seus produtos, preços e lugares ficam aqui."), o link "O que vai", que abre os Ajustes com a lista completa, e dois botões do mesmo peso, "Mandar" e "Não mandar". Fechar com o × conta como "não", e o cartão não volta. Nada vem pré-marcado.
  - **O texto não promete menos do que vai** (H17): sem "só" e com o caminho para a lista inteira, porque o consentimento dado sobre informação incompleta pode ser nulo (LGPD, art. 9º, § 1º). A lista dos Ajustes foi conferida com o filtro (`safeContextKeys`, `safeBreadcrumbCategories`) e as opções do Sentry: faltavam a versão do Flutter, os dados técnicos do aparelho (memória, tela, GPU) e os rastros de ciclo de vida, e entraram na lista. O filtro não mudou.
  - Aparece só quando as três condições valem: o build tem DSN (`crashReportingAvailableProvider`), a resposta ainda é `unasked` e alguma compra já tinha fim registrado **antes do início desta abertura do app** (`ShoppingTripRepository.watchAnyFinished(before:)`, uma consulta sobre `finishedAt` comparada com `appSessionStartProvider`, o instante lido uma vez quando o app abre; não mudou o esquema nem o arquivo de consentimento). Assim a pergunta não chega junto com o aviso "Compra terminada · Desfazer" nem com o anel do bipar. Compra cancelada some e compra reaberta volta a estar em andamento, então nenhuma das duas conta. "Abertura" é o processo do app: se o Android o mantiver vivo em segundo plano, a pergunta espera até ele ser recriado.
  - Se gravar a resposta falhar, o cartão sai até a próxima abertura em vez de ficar preso na tela.
- **Sempre revogável nos Ajustes** (`SettingsPage`, rota `/ajustes`), aberta pela engrenagem ao lado de "Sua casa". O interruptor "Relatório de falhas" (ligado é aceito, desligado é recusado) liga e desliga o Sentry na hora e é o único lugar para mudar de ideia, nos dois sentidos. Embaixo dele ficam abertos o que vai e o que nunca vai, sem link para outra página: é a explicação que a LGPD pede, num lugar só. "Sobre o Bipa" mostra a versão, lida com o `package_info_plus` (que já vinha com o `sentry_flutter` e passou a ser dependência direta).
- **Em build sem DSN, nem o cartão nem o interruptor aparecem:** a seção "Privacidade" some e a tela fica só com a versão.

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
- Sem DSN no build, ninguém consegue ligar o relatório: nem o cartão nem o interruptor aparecem, e o app não envia nada. Com DSN, só envia depois de um "Mandar" ou do interruptor ligado.
- Para criar o projeto: no Sentry, um projeto Flutter; o DSN vai no build de publicação com `flutter build appbundle --dart-define=SENTRY_DSN=<dsn>`. Para subir os símbolos do código ofuscado, o `sentry_dart_plugin` pode entrar depois.
