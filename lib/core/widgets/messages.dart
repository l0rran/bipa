import 'package:flutter/material.dart';

/// Atalho para exibir mensagens curtas ao usuário.
extension MessageContext on BuildContext {
  void showMessage(String message) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
