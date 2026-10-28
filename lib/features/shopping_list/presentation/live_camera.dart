import 'dart:async';

import 'package:bipa/core/camera/viewfinder_region.dart';
import 'package:bipa/core/design_system/bipa_metrics.dart';
import 'package:bipa/core/design_system/bipa_theme.dart';
import 'package:bipa/core/design_system/bipa_typography.dart';
import 'package:bipa/core/design_system/components/scan_tray.dart';
import 'package:bipa/core/l10n/app_localizations.dart';
import 'package:bipa/features/shopping_list/domain/live_scan.dart';
import 'package:bipa/features/shopping_list/presentation/live_scanner.dart';
import 'package:bipa/features/shopping_list/presentation/shopping_list_providers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A câmera ao vivo (ADR 0012), comum ao modo carrinho e à captura: a
/// prévia em tela cheia, a moldura que trava a cada leitura, o aviso logo
/// abaixo dela e o que fazer sem permissão ou com a câmera ocupada.
///
/// Cada leitura chega em [onEvent], uma de cada vez: a próxima espera esta
/// terminar. A tela dona da câmera desenha a barra de cima ([topBar], que
/// recebe a câmera para a lanterna) e a parte de baixo ([bottom]), e usa o
/// [LiveCameraState] (por uma `GlobalKey`) para pausar a leitura enquanto
/// algo está por cima.
class LiveCamera extends ConsumerStatefulWidget {
  const LiveCamera({required this.onEvent, required this.topBar, this.bottom, this.notice, this.hint, super.key});

  final Future<void> Function(LiveScanEvent event) onEvent;
  final Widget Function(LiveCameraState camera) topBar;
  final Widget? bottom;

  /// O aviso abaixo da moldura (o preço lido, por exemplo).
  final Widget? notice;

  /// O que fazer, sem aviso: "Aponte para o código ou a etiqueta".
  final String? hint;

  @override
  LiveCameraState createState() => LiveCameraState();
}

class LiveCameraState extends ConsumerState<LiveCamera> with WidgetsBindingObserver {
  /// Quantas câmeras estão abertas: ao trocar de uma para outra (da captura
  /// para o carrinho), a nova trava o retrato antes de a velha sair, e só a
  /// última a sair o libera.
  static var _open = 0;

  late final _live = LiveScanner(
    onEvents: _onEvents,
    viewfinder: _viewfinderOnScreen,
    analyzer: ref.read(liveFrameAnalyzerFactoryProvider)(),
    onError: _report,
  );
  final _previewKey = GlobalKey();
  final _viewfinderKey = GlobalKey();
  Future<void> _eventQueue = Future.value();

  /// A moldura "trava" por um instante a cada leitura.
  var _locked = false;
  Timer? _unlock;
  var _denied = false;

  /// A câmera não abriu por outro motivo (ocupada por outro app, por
  /// exemplo): a tela diz isso e oferece tentar de novo, em vez de ficar preta.
  var _failed = false;

  /// A abertura da câmera pode pedir permissão, e o diálogo do Android deixa
  /// o app inativo por um instante: isso não é ir para o fundo.
  var _starting = false;
  var _wentToBackground = false;

  /// Outra tela está usando a câmera: o leitor não volta sozinho ao app
  /// voltar do fundo.
  var _pausedForRoute = false;

  static const _frameWidth = 260.0;
  static const _frameHeight = 150.0;

  /// O espaço abaixo da moldura para o aviso: a folga e um botão de 48.
  static const _noticeBand = BipaSpacing.s4 + 48;

  bool get torchOn => _live.torchOn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _live.addListener(_onLiveChanged);
    // A prévia e o recorte supõem o celular em pé.
    _open++;
    unawaited(SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]));
    unawaited(_start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_pausedForRoute || _starting) return;
    switch (state) {
      case AppLifecycleState.resumed:
        // Sem permissão, só tenta de novo depois de a pessoa sair do app (para
        // as configurações, por exemplo); senão, o pedido se repetiria.
        if (_denied && !_wentToBackground) return;
        _wentToBackground = false;
        unawaited(_start());
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        _wentToBackground = true;
        unawaited(_command(_live.stop));
      case AppLifecycleState.inactive:
        unawaited(_command(_live.stop));
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unlock?.cancel();
    _live
      ..removeListener(_onLiveChanged)
      ..dispose();
    _open--;
    if (_open == 0) unawaited(SystemChrome.setPreferredOrientations(const []));
    super.dispose();
  }

  void _onLiveChanged() {
    if (mounted) setState(() {});
  }

  /// Abre a câmera; sem permissão ou com falha, a tela explica no lugar da
  /// prévia.
  Future<void> _start() async {
    _starting = true;
    var denied = false;
    var failed = false;
    try {
      await _live.start();
    } on CameraException catch (error, stack) {
      denied = error.code.startsWith('CameraAccessDenied');
      failed = !denied;
      if (failed) _report(error, stack);
    } on Exception catch (error, stack) {
      failed = true;
      _report(error, stack);
    } finally {
      _starting = false;
    }
    if (mounted && (denied != _denied || failed != _failed)) {
      setState(() {
        _denied = denied;
        _failed = failed;
      });
    }
  }

  /// A moldura na tela, relativa à prévia da câmera, para o recorte.
  ViewfinderOnScreen? _viewfinderOnScreen() {
    final preview = _previewKey.currentContext?.findRenderObject();
    final frame = _viewfinderKey.currentContext?.findRenderObject();
    if (preview is! RenderBox || frame is! RenderBox || !preview.hasSize || !frame.hasSize) return null;
    if (!preview.attached || !frame.attached) return null;
    final origin = frame.localToGlobal(Offset.zero) - preview.localToGlobal(Offset.zero);
    return (
      viewfinder: PixelRect(origin.dx, origin.dy, frame.size.width, frame.size.height),
      screenWidth: preview.size.width,
      screenHeight: preview.size.height,
    );
  }

  void _onEvents(List<LiveScanEvent> events) {
    for (final event in events) {
      _eventQueue = _eventQueue
          .then((_) async {
            if (mounted) await widget.onEvent(event);
          })
          // Uma falha não pode travar a fila dos próximos eventos.
          .then<void>((_) {}, onError: _report);
    }
  }

  /// Trava a moldura por um instante: a leitura deu certo.
  void lock() {
    if (!mounted) return;
    setState(() => _locked = true);
    _unlock?.cancel();
    _unlock = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _locked = false);
    });
  }

  /// Um diálogo por cima: a prévia continua, mas nada é lido por baixo dele.
  Future<T> withAnalysisPaused<T>(Future<T> Function() action) async {
    _live.analysisPaused = true;
    try {
      return await action();
    } finally {
      _live.analysisPaused = false;
    }
  }

  /// Outra tela (a câmera da etiqueta, o cadastro) precisa da câmera, e o
  /// leitor não pode continuar lendo por baixo dela.
  Future<T?> withScannerPaused<T>(Future<T?> Function() action) async {
    _pausedForRoute = true;
    await _command(_live.stop);
    try {
      return await action();
    } finally {
      _pausedForRoute = false;
      if (mounted) await _start();
    }
  }

  /// Fecha a câmera de vez, antes de outra tela abrir a dela (o carrinho, por
  /// exemplo): não volta sozinha.
  Future<void> stop() async {
    _pausedForRoute = true;
    await _command(_live.stop);
  }

  /// Volta a abrir a câmera depois de um [stop] que não levou a lugar
  /// nenhum (a outra tela não abriu).
  Future<void> resume() async {
    _pausedForRoute = false;
    if (mounted) await _start();
  }

  /// A lanterna falha se a câmera não abriu (sem permissão, por exemplo).
  Future<void> toggleTorch() => _command(_live.toggleTorch);

  /// Comandos da câmera que podem falhar sem derrubar a tela: o erro vai para
  /// o relatório e o leitor segue como está.
  Future<void> _command(Future<void> Function() command) async {
    try {
      await command();
    } on Exception catch (error, stack) {
      _report(error, stack);
    }
  }

  void _report(Object error, StackTrace stack) =>
      FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'live camera'));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final controller = _live.controller;
    final previewSize = controller?.value.previewSize;
    final below =
        widget.notice ??
        switch ((_denied, widget.hint)) {
          (true, _) => Text(
            l10n.cartCameraDenied,
            textAlign: TextAlign.center,
            style: BipaText.label.copyWith(color: colors.onCamera),
          ),
          (false, final text?) => Text(
            text,
            textAlign: TextAlign.center,
            style: BipaText.label.copyWith(color: colors.onCamera),
          ),
          _ => const SizedBox.shrink(),
        };

    return Stack(
      fit: StackFit.expand,
      children: [
        // A prévia preenche a tela (cover); o recorte de cada quadro conta
        // com isso (viewfinderInImage).
        SizedBox.expand(
          key: _previewKey,
          child: controller == null || previewSize == null || !controller.value.isInitialized
              ? null
              : ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: previewSize.height,
                      height: previewSize.width,
                      child: CameraPreview(controller),
                    ),
                  ),
                ),
        ),
        if (_failed)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: BipaSpacing.s6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.cartCameraFailed,
                    textAlign: TextAlign.center,
                    style: BipaText.label.copyWith(color: colors.onCamera),
                  ),
                  const SizedBox(height: BipaSpacing.s4),
                  FilledButton.tonal(onPressed: _start, child: Text(l10n.cartCameraRetry)),
                ],
              ),
            ),
          )
        else
          Align(
            alignment: const Alignment(0, -0.45),
            // A faixa do aviso fica dentro da caixa, acima e abaixo da moldura
            // (simétrica, para a moldura continuar no centro dela): fora dos
            // limites, o aviso tocável do granel não receberia o toque.
            child: SizedBox(
              width: double.infinity,
              height: _frameHeight + 2 * _noticeBand,
              child: Stack(
                children: [
                  Positioned(
                    top: _noticeBand,
                    left: 0,
                    right: 0,
                    child: Center(
                      // O tamanho fixo é o da moldura aberta: o recorte não
                      // muda quando ela trava.
                      child: SizedBox(
                        key: _viewfinderKey,
                        width: _frameWidth,
                        height: _frameHeight,
                        child: Center(child: ScanViewfinder(locked: _locked)),
                      ),
                    ),
                  ),
                  Positioned(
                    top: _noticeBand + _frameHeight + BipaSpacing.s4,
                    left: BipaSpacing.s4,
                    right: BipaSpacing.s4,
                    child: Center(child: below),
                  ),
                ],
              ),
            ),
          ),
        // No topo: dentro do Stack que ocupa a tela, a barra se esticaria até
        // o meio.
        Align(
          alignment: Alignment.topCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(BipaSpacing.s4, BipaSpacing.s4, BipaSpacing.s4, 0),
              child: widget.topBar(this),
            ),
          ),
        ),
        if (widget.bottom case final bottom?) Align(alignment: Alignment.bottomCenter, child: bottom),
      ],
    );
  }
}
