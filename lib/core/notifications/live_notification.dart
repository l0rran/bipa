import 'dart:async';

import 'package:bipa/core/permissions/permission_access.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Um botão da notificação ao vivo da compra (ADR 0015).
enum LiveAction {
  /// "Bipar": abre o modo carrinho.
  scan,

  /// "Lista": abre a lista; é também o toque na notificação.
  list,

  /// "Terminei": termina a compra.
  finish,
}

/// O que a notificação ao vivo mostra. Os textos chegam prontos, do ARB: o
/// lado nativo só monta a notificação.
@immutable
final class LiveNotificationContent {
  const LiveNotificationContent({
    required this.tripId,
    required this.title,
    required this.done,
    required this.total,
    required this.accentColor,
    required this.channelName,
    required this.channelDescription,
    required this.actionLabels,
    this.text,
    this.subText,
    this.chip,
  });

  /// A compra: uma notificação dispensada pela pessoa não volta na mesma
  /// compra.
  final String tripId;

  /// "4 de 7 itens · R$ 54,88".
  final String title;

  /// "Próximo · Laticínios: leite, ovos".
  final String? text;

  /// O mercado, no cabeçalho da notificação.
  final String? subText;

  /// O texto do chip da barra de status: "4/7". Sem ele, o chip mostra só
  /// o ícone.
  final String? chip;

  /// Itens pegos e total, para os segmentos da barra de progresso.
  final int done;
  final int total;

  /// A cor dos segmentos pegos (a da marca), em ARGB.
  final int accentColor;

  final String channelName;
  final String channelDescription;
  final Map<LiveAction, String> actionLabels;

  Map<String, Object?> toMap() => {
    'tripId': tripId,
    'title': title,
    'text': text,
    'subText': subText,
    'chip': chip,
    'done': done,
    'total': total,
    'color': accentColor,
    'channelName': channelName,
    'channelDescription': channelDescription,
    'actions': {for (final MapEntry(key: action, value: label) in actionLabels.entries) action.name: label},
  };

  @override
  bool operator ==(Object other) =>
      other is LiveNotificationContent &&
      other.tripId == tripId &&
      other.title == title &&
      other.text == text &&
      other.subText == subText &&
      other.chip == chip &&
      other.done == done &&
      other.total == total &&
      other.accentColor == accentColor &&
      other.channelName == channelName &&
      other.channelDescription == channelDescription &&
      mapEquals(other.actionLabels, actionLabels);

  @override
  int get hashCode => Object.hash(
    tripId,
    title,
    text,
    subText,
    chip,
    done,
    total,
    accentColor,
    channelName,
    channelDescription,
    Object.hashAllUnordered(actionLabels.entries.map((e) => Object.hash(e.key, e.value))),
  );
}

/// A notificação ao vivo da compra: na tela de bloqueio e como chip na barra
/// de status (Live Updates do Android 16; antes dele, uma notificação fixa
/// com barra de progresso).
abstract interface class LiveNotifications {
  /// Mostra ou atualiza a notificação.
  Future<void> show(LiveNotificationContent content);

  /// Tira a notificação: a compra terminou.
  Future<void> cancel();

  /// Se o app pode mostrar notificações (Android 13+ pede permissão).
  Future<PermissionAccess> access();

  /// Pede a permissão de notificações, se ainda não foi dada, e espera a
  /// resposta: assim o pedido seguinte (o da câmera) não atropela este.
  Future<void> requestPermission();

  /// O botão que abriu o app, se foi a notificação que o abriu; lido uma vez.
  Future<LiveAction?> takeLaunchAction();

  /// Os botões tocados com o app já aberto.
  Stream<LiveAction> get actions;

  /// A pessoa acabou de permitir notificações: vale mandar o conteúdo de
  /// novo.
  Stream<void> get permissionGranted;
}

/// Fala com o código nativo do Android (MainActivity e
/// LiveShoppingNotification.kt).
final class MethodChannelLiveNotifications implements LiveNotifications {
  MethodChannelLiveNotifications([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('dev.l0rran.bipa/live_shopping') {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'action':
          if (_parse(call.arguments) case final action?) _actions.add(action);
        case 'permissionGranted':
          _permissionGranted.add(null);
      }
    });
  }

  final MethodChannel _channel;
  final _actions = StreamController<LiveAction>.broadcast();
  final _permissionGranted = StreamController<void>.broadcast();

  @override
  Stream<LiveAction> get actions => _actions.stream;

  @override
  Stream<void> get permissionGranted => _permissionGranted.stream;

  @override
  Future<void> show(LiveNotificationContent content) => _call('show', content.toMap());

  @override
  Future<void> cancel() => _call('cancel');

  @override
  Future<PermissionAccess> access() async {
    if (defaultTargetPlatform != TargetPlatform.android) return PermissionAccess.granted;
    try {
      final name = await _channel.invokeMethod<String>('notificationAccess');
      return PermissionAccess.values.where((a) => a.name == name).firstOrNull ?? PermissionAccess.granted;
    } on PlatformException {
      return PermissionAccess.granted;
    } on MissingPluginException {
      return PermissionAccess.granted;
    }
  }

  /// O limite é só uma garantia: se a resposta se perder (a Activity foi
  /// recriada no meio), a compra segue sem a notificação.
  @override
  Future<void> requestPermission() => _call('requestPermission').timeout(const Duration(minutes: 2), onTimeout: () {});

  @override
  Future<LiveAction?> takeLaunchAction() async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      return _parse(await _channel.invokeMethod<String>('takeLaunchAction'));
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// A notificação é um extra: falhar nela não pode derrubar a compra.
  Future<void> _call(String method, [Object? arguments]) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on PlatformException catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'live notification'));
    } on MissingPluginException {
      // Testes e plataformas sem o código nativo.
    }
  }

  static LiveAction? _parse(Object? name) => LiveAction.values.where((a) => a.name == name).firstOrNull;
}
