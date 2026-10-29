/// O filtro de privacidade do relatório de falhas (ADR 0025): cada evento e
/// cada rastro passam por aqui antes de sair do aparelho. Funciona por lista
/// do que pode passar, para que um campo ou uma categoria nova seja
/// descartada até alguém revisá-la.
library;

import 'package:sentry_flutter/sentry_flutter.dart';

/// Erros do Dart cuja mensagem é escrita pela linguagem, sem dado de quem
/// usa (tipos, índices, nomes de campo). O nome é o `runtimeType` que o
/// Sentry põe em `SentryException.type`.
const safeExceptionTypes = {
  '_TypeError',
  'TypeError',
  'RangeError',
  'IndexError',
  'ConcurrentModificationError',
  'StackOverflowError',
  'OutOfMemoryError',
  'LateError',
  'LateInitializationError',
};

/// Rastros que o SDK gera sem texto da interface: o app abriu, foi para o
/// fundo, a tela girou. Navegação (rotas com ids), toques (texto do botão),
/// console (`print`) e rede ficam de fora.
const safeBreadcrumbCategories = {
  'app.lifecycle',
  'ui.lifecycle',
  'device.orientation',
  'device.event',
  'device.screen',
};

/// Contextos que descrevem o aparelho e o app, não a pessoa. Sai, por
/// exemplo, o `flutter_error_details`, que descreve a árvore de widgets e
/// pode trazer o texto da tela.
const safeContextKeys = {'device', 'os', 'app', 'runtime', 'runtimes', 'gpu', 'culture', 'trace'};

/// O que fica no lugar do texto removido de uma mensagem.
const scrubbedText = '[removido]';

/// Limpa o evento antes do envio (`beforeSend`). Nunca descarta: a falha
/// chega, sem o que poderia identificar a pessoa ou o conteúdo da casa.
SentryEvent scrubEvent(SentryEvent event) {
  event
    ..user = null
    ..serverName = null
    ..request = null
    ..transaction = null
    ..message = _scrubMessage(event.message)
    ..breadcrumbs = event.breadcrumbs?.map(scrubBreadcrumb).nonNulls.toList();
  // O app não põe nada em `extra`; se algo puser, não sai.
  // ignore: deprecated_member_use
  event.extra = null;
  for (final exception in event.exceptions ?? const <SentryException>[]) {
    _scrubException(exception);
  }
  _scrubContexts(event.contexts);
  return event;
}

/// Filtra o rastro antes de ele entrar no escopo (`beforeBreadcrumb`):
/// devolve `null` para descartar.
Breadcrumb? scrubBreadcrumb(Breadcrumb? breadcrumb) {
  if (breadcrumb == null) return null;
  if (!safeBreadcrumbCategories.contains(breadcrumb.category)) return null;
  return breadcrumb;
}

/// Fica só o modelo, escrito no código; os parâmetros e o texto montado,
/// que podem ter dado de quem usa, saem.
SentryMessage? _scrubMessage(SentryMessage? message) {
  if (message == null) return null;
  return SentryMessage(message.template ?? scrubbedText, template: message.template);
}

void _scrubException(SentryException exception) {
  if (!safeExceptionTypes.contains(exception.type)) exception.value = null;
  final mechanism = exception.mechanism;
  if (mechanism != null) {
    mechanism
      ..description = null
      ..data = null;
  }
}

void _scrubContexts(Contexts contexts) {
  contexts.removeWhere((key, _) => !safeContextKeys.contains(key));
  contexts.device?.name = null;
}
