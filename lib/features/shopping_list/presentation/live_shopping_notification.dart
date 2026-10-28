import 'dart:async';

import 'package:bipa/app/router.dart';
import 'package:bipa/core/design_system/bipa_palette.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/core/notifications/live_notification.dart';
import 'package:bipa/core/notifications/notifications_provider.dart';
import 'package:bipa/features/shopping_list/presentation/aisle_label.dart';
import 'package:bipa/features/shopping_list/presentation/finish_shopping.dart';
import 'package:bipa/features/shopping_list/presentation/shopping_list_providers.dart';
import 'package:bipa/features/shopping_list/presentation/trip_summary_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Mantém a notificação ao vivo da compra (protótipo "Notificação ao vivo",
/// ADR 0015) igual ao que está na tela, e atende os botões dela.
///
/// Fica no `builder` do MaterialApp, acima do Navigator: assim continua
/// ativa com o modo carrinho por cima das abas (o Riverpod pausa quem fica
/// fora de cena).
class LiveShoppingNotification extends ConsumerStatefulWidget {
  const LiveShoppingNotification({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<LiveShoppingNotification> createState() => _LiveShoppingNotificationState();
}

class _LiveShoppingNotificationState extends ConsumerState<LiveShoppingNotification> {
  StreamSubscription<LiveAction>? _actions;
  StreamSubscription<void>? _permission;

  /// O que está na notificação agora; `null` quando não há notificação.
  LiveNotificationContent? _shown;

  @override
  void initState() {
    super.initState();
    final notifications = ref.read(liveNotificationsProvider);
    _actions = notifications.actions.listen(_onAction);
    _permission = notifications.permissionGranted.listen((_) {
      // Com a permissão nova, a notificação que não pôde aparecer aparece.
      _shown = null;
      _sync(ref.read(liveShoppingProvider));
    });
    ref.listenManual(liveShoppingProvider, (_, next) => _sync(next));
    // Depois do primeiro quadro: o contexto já tem os textos e as rotas.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _sync(ref.read(liveShoppingProvider));
      final launch = await notifications.takeLaunchAction();
      if (launch != null && mounted) await _onAction(launch);
    });
  }

  @override
  void dispose() {
    unawaited(_actions?.cancel());
    unawaited(_permission?.cancel());
    super.dispose();
  }

  void _sync(LiveShopping? shopping) {
    final notifications = ref.read(liveNotificationsProvider);
    if (shopping == null) {
      if (_shown != null) unawaited(notifications.cancel());
      _shown = null;
      return;
    }
    final content = _content(AppLocalizations.of(context), shopping);
    if (content == _shown) return;
    _shown = content;
    unawaited(notifications.show(content));
  }

  static LiveNotificationContent _content(AppLocalizations l10n, LiveShopping shopping) {
    final summary = shopping.summary;
    final hasList = summary.hasList;
    final items = hasList ? l10n.tripItems(summary.done, summary.total) : l10n.liveShopping;
    final spent = summary.spentLabel(l10n);
    return LiveNotificationContent(
      tripId: shopping.tripId,
      title: spent == null ? items : l10n.liveTitle(items, spent),
      text: switch (shopping.next) {
        (:final aisle, :final items) => l10n.liveNext(aisle.localizedLabel(l10n), items.join(', ')),
        null when hasList => l10n.liveAllPicked,
        null => null,
      },
      subText: shopping.marketName,
      chip: hasList ? l10n.liveChip(summary.done, summary.total) : null,
      done: summary.done,
      total: summary.total,
      // A notificação é desenhada pelo sistema: a cor vai como valor, da
      // paleta clara (ADR 0009).
      accentColor: BipaPalette.light.brand.toARGB32(),
      channelName: l10n.liveChannelName,
      channelDescription: l10n.liveChannelDescription,
      actionLabels: {
        LiveAction.scan: l10n.liveScan,
        LiveAction.list: l10n.listTitle,
        LiveAction.finish: l10n.tripFinish,
      },
    );
  }

  Future<void> _onAction(LiveAction action) async {
    // Acima do Navigator não há GoRouter no contexto: vem do provider.
    final router = ref.read(routerProvider);
    switch (action) {
      case LiveAction.scan:
        // Já no carrinho, não abre outro por cima.
        if (_topPath(router) != Routes.cartMode) unawaited(router.push<void>(Routes.cartMode));
      case LiveAction.list:
        router.go(Routes.shoppingList);
      case LiveAction.finish:
        // Aberto pela notificação, o app pode ainda estar lendo a compra.
        final trip = await ref.read(activeTripProvider.future);
        if (!mounted || trip == null) return;
        router.go(Routes.shoppingList);
        // Um toque no bolso não pode encerrar a compra: a folha "Fim da
        // compra" pede a confirmação. Ela precisa de um contexto abaixo do
        // Navigator.
        final navigatorContext = router.routerDelegate.navigatorKey.currentContext;
        if (navigatorContext == null || !navigatorContext.mounted) return;
        await finishShopping(navigatorContext, ref, trip.id);
    }
  }

  /// A rota de cima. Uma rota aberta com `push` não muda o `uri` da
  /// configuração: ela aparece como a última correspondência.
  static String _topPath(GoRouter router) {
    final configuration = router.routerDelegate.currentConfiguration;
    final last = configuration.matches.lastOrNull;
    return last is ImperativeRouteMatch ? last.matches.uri.path : configuration.uri.path;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
