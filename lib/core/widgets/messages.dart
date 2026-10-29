import 'package:bipa/core/design_system/components/bipa_toast.dart';
import 'package:flutter/material.dart';

/// Atalho para exibir mensagens curtas ao usuário, no aviso do design system.
extension MessageContext on BuildContext {
  void showMessage(String message) {
    showBipaToast(ScaffoldMessenger.of(this), message);
  }
}
