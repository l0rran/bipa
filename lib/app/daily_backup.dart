import 'dart:async';

import 'package:bipa/features/backup/presentation/backup_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pede o backup diário (ADR 0023, seção 5) quando o app abre e quando a
/// pessoa volta para ele. O backup só acontece na primeira vez de cada dia
/// (`CreateBackup`), sem WorkManager e sem gravar com o app no fundo
/// (decisão do mantenedor em 29/10).
///
/// Fica no `builder` do MaterialApp, acima das rotas.
class DailyBackup extends ConsumerStatefulWidget {
  const DailyBackup({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<DailyBackup> createState() => _DailyBackupState();
}

class _DailyBackupState extends ConsumerState<DailyBackup> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _run);
    // Depois do primeiro quadro: a abertura não espera pelo backup.
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  void _run() {
    if (!mounted) return;
    unawaited(ref.read(backupProvider.notifier).runDailyBackup());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
