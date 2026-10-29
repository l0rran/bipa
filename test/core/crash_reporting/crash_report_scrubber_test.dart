import 'dart:convert';

import 'package:bipa/core/crash_reporting/crash_report_scrubber.dart';
import 'package:bipa/core/crash_reporting/sentry_crash_reporter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Coisas da casa e da pessoa que nunca podem sair do aparelho.
const _personalData = [
  'Leite Integral',
  'Atacarejo Vila Nova',
  '7891000100103',
  '-23.5505',
  '-46.6333',
  'Celular do Wesley',
  'wesley@',
  '192.168.0.7',
  'São Paulo',
  '/produto/',
  r'R$ 5,49',
];

Breadcrumb _crumb(String category, {String? message, Map<String, dynamic>? data}) =>
    Breadcrumb(category: category, message: message, data: data);

SentryEvent _eventFullOfPersonalData() => SentryEvent(
  user: SentryUser(
    id: 'instalacao-1',
    email: 'wesley@exemplo.com',
    ipAddress: '192.168.0.7',
    geo: SentryGeo(city: 'São Paulo'),
  ),
  serverName: 'Celular do Wesley',
  request: SentryRequest(url: 'https://exemplo.com/?lat=-23.5505&lng=-46.6333'),
  transaction: '/produto/0b9f3c1e-5a43-4d4c-9a52-7d1f0c2b8e11',
  message: SentryMessage(r'Leite Integral custou R$ 5,49 no Atacarejo Vila Nova'),
  exceptions: [
    SentryException(type: 'StateError', value: 'Produto "Leite Integral" (7891000100103) não encontrado'),
    SentryException(type: 'FormatException', value: 'Coordenada inválida: -23.5505, -46.6333'),
    SentryException(
      type: 'FlutterError',
      value: 'A RenderFlex overflowed: Text("Atacarejo Vila Nova")',
      mechanism: Mechanism(
        type: 'FlutterError',
        handled: false,
        description: 'Text("Leite Integral")',
        data: {'widget': 'Text("Leite Integral")'},
      ),
    ),
  ],
  breadcrumbs: [
    _crumb('navigation', data: {'from': '/casa', 'to': '/produto/0b9f3c1e', 'to_arguments': 'Leite Integral'}),
    _crumb('ui.click', data: {'label': 'Leite Integral'}),
    _crumb('console', message: 'AsyncValueView: Atacarejo Vila Nova'),
    _crumb('http', data: {'url': 'https://exemplo.com/?lat=-23.5505'}),
    _crumb('app.lifecycle', data: {'state': 'resumed'}),
  ],
  contexts:
      Contexts(
          device: SentryDevice(name: 'Celular do Wesley', model: 'Pixel 9'),
        )
        ..['flutter_error_details'] = {'information': 'Text("Leite Integral")'}
        ..['mercado'] = {'nome': 'Atacarejo Vila Nova', 'lat': -23.5505, 'lng': -46.6333},
);

void main() {
  group('scrubEvent', () {
    test('nada da casa nem da pessoa sobra no que é enviado', () {
      final json = jsonEncode(scrubEvent(_eventFullOfPersonalData()).toJson());
      for (final value in _personalData) {
        expect(json, isNot(contains(value)), reason: 'vazou "$value"');
      }
    });

    test('tira a pessoa, o IP, o servidor, a requisição e a rota', () {
      final event = scrubEvent(_eventFullOfPersonalData());
      expect(event.user, isNull);
      expect(event.serverName, isNull);
      expect(event.request, isNull);
      expect(event.transaction, isNull);
    });

    test('mantém o tipo da exceção e tira a mensagem com texto de quem usa', () {
      final exceptions = scrubEvent(_eventFullOfPersonalData()).exceptions!;
      expect(exceptions.map((e) => e.type), ['StateError', 'FormatException', 'FlutterError']);
      expect(exceptions.map((e) => e.value), everyElement(isNull));
      expect(exceptions.last.mechanism!.type, 'FlutterError');
      expect(exceptions.last.mechanism!.handled, isFalse);
      expect(exceptions.last.mechanism!.description, isNull);
      expect(exceptions.last.mechanism!.data, isEmpty);
    });

    test('mantém a mensagem dos erros que a própria linguagem escreve', () {
      const typeError = "type 'Null' is not a subtype of type 'String'";
      const rangeError = 'RangeError (index): Invalid value: Not in inclusive range 0..2: 3';
      final event = scrubEvent(
        SentryEvent(
          exceptions: [
            SentryException(type: '_TypeError', value: typeError),
            SentryException(type: 'RangeError', value: rangeError),
          ],
        ),
      );
      expect(event.exceptions!.map((e) => e.value), [typeError, rangeError]);
    });

    test('da mensagem do evento fica só o modelo, sem os parâmetros', () {
      final withTemplate = scrubEvent(
        SentryEvent(
          message: SentryMessage(
            'Falha ao salvar Leite Integral',
            template: 'Falha ao salvar %s',
            params: ['Leite Integral'],
          ),
        ),
      );
      expect(withTemplate.message!.formatted, 'Falha ao salvar %s');
      expect(withTemplate.message!.params, isNull);

      final withoutTemplate = scrubEvent(SentryEvent(message: SentryMessage('Leite Integral')));
      expect(withoutTemplate.message!.formatted, scrubbedText);
    });

    test('dos rastros do evento fica só o ciclo de vida do app', () {
      final breadcrumbs = scrubEvent(_eventFullOfPersonalData()).breadcrumbs!;
      expect(breadcrumbs.map((b) => b.category), ['app.lifecycle']);
    });

    test('dos contextos ficam só os do aparelho, sem o nome dele', () {
      final contexts = scrubEvent(_eventFullOfPersonalData()).contexts;
      expect(contexts.containsKey('flutter_error_details'), isFalse);
      expect(contexts.containsKey('mercado'), isFalse);
      expect(contexts.device!.name, isNull);
      expect(contexts.device!.model, 'Pixel 9');
    });
  });

  group('scrubBreadcrumb', () {
    test('descarta navegação, toques, console, rede e categorias desconhecidas', () {
      for (final category in ['navigation', 'ui.click', 'console', 'http', 'query', 'nova.categoria']) {
        expect(scrubBreadcrumb(_crumb(category, message: 'Leite Integral')), isNull, reason: category);
      }
      expect(scrubBreadcrumb(Breadcrumb(message: 'sem categoria')), isNull);
      expect(scrubBreadcrumb(null), isNull);
    });

    test('mantém os rastros do ciclo de vida do app e do aparelho', () {
      for (final category in safeBreadcrumbCategories) {
        final crumb = _crumb(category, data: {'state': 'paused'});
        expect(scrubBreadcrumb(crumb), same(crumb), reason: category);
      }
    });
  });

  test('o Sentry usa o filtro antes de enviar e de guardar rastros', () async {
    final options = SentryFlutterOptions();
    SentryCrashReporter.configure(options, 'https://chave@o0.ingest.sentry.io/0');

    final sent = await options.beforeSend!(_eventFullOfPersonalData(), Hint());
    expect(sent!.user, isNull);
    expect(options.beforeBreadcrumb!(_crumb('navigation'), Hint()), isNull);
  });
}
