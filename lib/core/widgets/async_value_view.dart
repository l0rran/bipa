import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Renderiza um [AsyncValue] com indicadores padrão de carregamento e erro.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({required this.value, required this.data, super.key});

  final AsyncValue<T> value;
  final Widget Function(T data) data;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Algo deu errado ao carregar os dados.\n$error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
