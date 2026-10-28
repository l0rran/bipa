import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/components/scan_tray.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/products/domain/scale_label.dart';
import 'package:bipa/features/shopping_list/domain/live_scan.dart';
import 'package:bipa/features/shopping_list/presentation/live_camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Lê um código de barras de produto e o devolve via `pop`: o bipar das
/// buscas e do formulário do produto. Usa a mesma câmera ao vivo do botão de
/// bipar (ADR 0012), com a moldura, a lanterna e o que fazer sem permissão.
///
/// O código da balança não identifica produto (ADR 0018): a leitura continua
/// e a dica explica por quê.
class ScanCodePage extends StatefulWidget {
  const ScanCodePage({super.key});

  @override
  State<ScanCodePage> createState() => _ScanCodePageState();
}

class _ScanCodePageState extends State<ScanCodePage> {
  var _handled = false;
  var _sawScaleCode = false;

  Future<void> _onEvent(LiveScanEvent event) async {
    // O código vale também quando a etiqueta veio junto no mesmo quadro.
    final barcode = switch (event) {
      ProductScanned(:final barcode) => barcode,
      TagPriceRead(:final barcode) => barcode,
    };
    if (_handled || barcode == null) return;
    if (ScaleLabel.isScaleCode(barcode)) {
      if (!_sawScaleCode) setState(() => _sawScaleCode = true);
      return;
    }
    _handled = true;
    await HapticFeedback.mediumImpact();
    if (mounted) context.pop(barcode);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: context.colors.camera,
      body: LiveCamera(
        onEvent: _onEvent,
        hint: _sawScaleCode ? l10n.scannerScaleCode : l10n.scannerHint,
        topBar: (camera) => Row(
          children: [
            CameraGlassButton(icon: Icons.close_rounded, label: l10n.cartClose, onPressed: () => context.pop()),
            const Spacer(),
            CameraGlassButton(
              icon: camera.torchOn ? Icons.flashlight_off_outlined : Icons.flashlight_on_outlined,
              label: l10n.cartTorch,
              onPressed: camera.toggleTorch,
            ),
          ],
        ),
      ),
    );
  }
}
