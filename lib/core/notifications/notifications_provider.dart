import 'package:bipa/core/notifications/live_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A notificação ao vivo da compra. Sobrescreva em testes.
final liveNotificationsProvider = Provider<LiveNotifications>((ref) => MethodChannelLiveNotifications());
