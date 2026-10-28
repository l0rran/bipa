import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Renderiza um [AsyncValue] com indicadores padrão de carregamento e erro.
///
/// O erro aparece para a pessoa como o que aconteceu e o que fazer; os
/// detalhes técnicos vão para o log.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({required this.value, required this.data, this.onRetry, super.key});

  final AsyncValue<T> value;
  final Widget Function(T data) data;

  /// "Tentar de novo"; sem ele, só a mensagem.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) {
        debugPrint('AsyncValueView: $error\n$stackTrace');
        final l10n = AppLocalizations.of(context);
        final onRetry = this.onRetry;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.loadFailed, textAlign: TextAlign.center),
                if (onRetry != null) ...[
                  const SizedBox(height: 12),
                  TextButton(onPressed: onRetry, child: Text(l10n.retry)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
