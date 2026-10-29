import 'package:bipa/core/accessibility/recommended_timeouts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Um Android de mentira, que responde o que o teste mandar.
final class _FakeSource implements RecommendedTimeoutsSource {
  _FakeSource(this.answer);

  RecommendedTimeouts answer;
  var reads = 0;

  @override
  Future<RecommendedTimeouts> read() async {
    reads++;
    return answer;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.l0rran.bipa/accessibility');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('o canal com o Android', () {
    test('lê o "Tempo para agir" em milissegundos', () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return {'controls': 60000, 'text': 10000};
      });

      final timeouts = await MethodChannelRecommendedTimeouts().read();

      expect(calls, ['recommendedTimeouts']);
      expect(timeouts, const RecommendedTimeouts(controls: Duration(minutes: 1), text: Duration(seconds: 10)));
    });

    test('sem pedido da pessoa (zero), valem os tempos do design system', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => {'controls': 0, 'text': 0});

      expect(await MethodChannelRecommendedTimeouts().read(), RecommendedTimeouts.none);
    });

    test('sem o código nativo, valem os tempos do design system', () async {
      expect(await MethodChannelRecommendedTimeouts().read(), RecommendedTimeouts.none);
    });

    test('uma falha do lado nativo não derruba nada', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => throw PlatformException(code: 'erro'));
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);

      expect(await MethodChannelRecommendedTimeouts().read(), RecommendedTimeouts.none);
      expect(reported, hasLength(1));
    });

    test('fora do Android, nem pergunta', () async {
      var asked = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        asked = true;
        return {'controls': 60000, 'text': 60000};
      });
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(await MethodChannelRecommendedTimeouts().read(), RecommendedTimeouts.none);
      expect(asked, isFalse);
    });
  });

  group('o carregador', () {
    Future<RecommendedTimeouts Function()> pumpLoader(WidgetTester tester, _FakeSource source) async {
      late BuildContext captured;
      await tester.pumpWidget(
        RecommendedTimeoutsLoader(
          source: source,
          child: Builder(
            builder: (context) {
              captured = context;
              RecommendedTimeoutsScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();
      return () => RecommendedTimeoutsScope.of(captured);
    }

    testWidgets('lê ao abrir e dá o tempo a quem está abaixo', (tester) async {
      final source = _FakeSource(const RecommendedTimeouts(controls: Duration(minutes: 1)));
      final current = await pumpLoader(tester, source);

      expect(current(), const RecommendedTimeouts(controls: Duration(minutes: 1)));
    });

    testWidgets('lê de novo quando o app volta para a frente', (tester) async {
      final source = _FakeSource(RecommendedTimeouts.none);
      final current = await pumpLoader(tester, source);
      expect(source.reads, 1);

      // A pessoa saiu, mudou o ajuste e voltou.
      source.answer = const RecommendedTimeouts(controls: Duration(minutes: 2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(source.reads, 2);
      expect(current(), const RecommendedTimeouts(controls: Duration(minutes: 2)));
    });

    testWidgets('fora de um escopo, nenhum pedido', (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      );

      expect(RecommendedTimeoutsScope.of(captured), RecommendedTimeouts.none);
    });
  });
}
