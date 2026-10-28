import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/products/domain/gtin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Lê um código de barras de produto pela câmera e o devolve via `pop`.
///
/// A leitura acontece no aparelho (ML Kit), sem internet. Leituras com
/// dígito verificador inválido são descartadas até surgir uma válida.
class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  final _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  var _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code != null && Gtin.isValid(code)) {
        _handled = true;
        HapticFeedback.mediumImpact();
        context.pop(code);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.camera,
      appBar: AppBar(
        title: Text(l10n.scannerTitle),
        actions: [
          IconButton(
            tooltip: l10n.cartTorch,
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          const _ScanFrame(),
          Positioned(
            left: BipaSpacing.s6,
            right: BipaSpacing.s6,
            bottom: BipaSpacing.s8 + BipaSpacing.s4,
            child: Text(
              l10n.scannerHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onCamera, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

/// Moldura que indica onde posicionar o código de barras.
class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 280,
        height: 160,
        decoration: BoxDecoration(
          border: Border.all(color: context.colors.onCamera, width: 3),
          borderRadius: BorderRadius.circular(BipaRadius.lg),
        ),
      ),
    );
  }
}
