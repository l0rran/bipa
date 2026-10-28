import 'package:bipa/core/notifications/live_notification.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.l0rran.bipa/live_shopping');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'takeLaunchAction' ? 'finish' : null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  const content = LiveNotificationContent(
    tripId: 'compra',
    title: r'4 de 7 itens · R$ 54,88',
    text: 'Próximo · Laticínios: Leite, Ovos',
    subText: 'Atacarejo Vila Nova',
    chip: '4/7',
    done: 4,
    total: 7,
    accentColor: 0xFFF6C445,
    channelName: 'Compra em andamento',
    channelDescription: 'Mostra o progresso da compra.',
    actionLabels: {LiveAction.scan: 'Bipar', LiveAction.list: 'Lista', LiveAction.finish: 'Terminei'},
  );

  test('manda o conteúdo pronto para o lado nativo', () async {
    await MethodChannelLiveNotifications(channel).show(content);

    expect(calls.single.method, 'show');
    final args = calls.single.arguments as Map<Object?, Object?>;
    expect(args['title'], r'4 de 7 itens · R$ 54,88');
    expect(args['chip'], '4/7');
    expect((args['done'], args['total']), (4, 7));
    expect(args['actions'], {'scan': 'Bipar', 'list': 'Lista', 'finish': 'Terminei'});
  });

  test('lê o botão que abriu o app e os tocados depois', () async {
    final notifications = MethodChannelLiveNotifications(channel);
    expect(await notifications.takeLaunchAction(), LiveAction.finish);

    final next = notifications.actions.first;
    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(const MethodCall('action', 'scan')),
      (_) {},
    );

    expect(await next, LiveAction.scan);
  });

  test('conteúdos iguais são iguais, para não atualizar à toa', () {
    const same = LiveNotificationContent(
      tripId: 'compra',
      title: r'4 de 7 itens · R$ 54,88',
      text: 'Próximo · Laticínios: Leite, Ovos',
      subText: 'Atacarejo Vila Nova',
      chip: '4/7',
      done: 4,
      total: 7,
      accentColor: 0xFFF6C445,
      channelName: 'Compra em andamento',
      channelDescription: 'Mostra o progresso da compra.',
      actionLabels: {LiveAction.list: 'Lista', LiveAction.scan: 'Bipar', LiveAction.finish: 'Terminei'},
    );

    expect(same, content);
    expect(same.hashCode, content.hashCode);
  });
}
