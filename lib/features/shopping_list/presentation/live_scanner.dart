import 'dart:async';
import 'dart:io';

import 'package:bipa/core/camera/camera_input_image.dart';
import 'package:bipa/core/camera/viewfinder_region.dart';
import 'package:bipa/features/shopping_list/data/mlkit_live_frame_analyzer.dart';
import 'package:bipa/features/shopping_list/domain/live_scan.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Onde a moldura está na tela e o tamanho da tela, para recortar cada quadro.
typedef ViewfinderOnScreen = ({PixelRect viewfinder, double screenWidth, double screenHeight});

/// A câmera do modo carrinho (ADR 0012): mostra a prévia e lê cada quadro,
/// código de barras e etiqueta juntos, só dentro da moldura.
///
/// Só um quadro é analisado por vez; os que chegam enquanto isso são pulados.
/// [start] e [stop] podem ser chamados em qualquer ordem: rodam em fila.
final class LiveScanner extends ChangeNotifier {
  LiveScanner({
    required this.onEvents,
    required this.viewfinder,
    this.onError,
    MlKitLiveFrameAnalyzer? analyzer,
    LiveScanInterpreter? interpreter,
  }) : _analyzer = analyzer ?? MlKitLiveFrameAnalyzer(),
       _interpreter = interpreter ?? LiveScanInterpreter();

  /// O que a leitura concluiu (bipes e etiquetas), na ordem.
  final void Function(List<LiveScanEvent> events) onEvents;

  /// A posição atual da moldura; `null` enquanto ela não foi desenhada.
  final ViewfinderOnScreen? Function() viewfinder;

  /// Falhas da câmera ou do reconhecimento, para o relatório.
  final void Function(Object error, StackTrace stack)? onError;

  final MlKitLiveFrameAnalyzer _analyzer;
  final LiveScanInterpreter _interpreter;

  /// Uma margem em volta da moldura: a etiqueta raramente cabe certinha.
  static const _cropMargin = 0.15;

  CameraController? _controller;
  CameraDescription? _camera;
  var _analyzing = false;
  var _torch = false;
  var _disposed = false;
  Future<void> _queue = Future.value();

  /// A câmera aberta, para a prévia; `null` enquanto está parada.
  CameraController? get controller => _controller;

  bool get torchOn => _torch;

  /// Abre a câmera traseira e começa a ler.
  Future<void> start() => _enqueue(() async {
    if (_controller != null || _disposed) return;
    final camera = _camera ??= await _backCamera();
    if (camera == null) return;
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    try {
      await controller.initialize();
      if (_disposed) {
        await controller.dispose();
        return;
      }
      _interpreter.reset();
      _torch = false;
      _controller = controller;
      notifyListeners();
      await controller.startImageStream((image) => unawaited(_onImage(controller, image)));
    } on Object {
      if (_controller == controller) _controller = null;
      await controller.dispose();
      if (!_disposed) notifyListeners();
      rethrow;
    }
  });

  /// Fecha a câmera: no fundo, ou enquanto outra tela usa a câmera.
  Future<void> stop() => _enqueue(() async {
    final controller = _controller;
    if (controller == null) return;
    _controller = null;
    _torch = false;
    if (!_disposed) notifyListeners();
    if (controller.value.isStreamingImages) await controller.stopImageStream();
    await controller.dispose();
  });

  Future<void> toggleTorch() => _enqueue(() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.setFlashMode(_torch ? FlashMode.off : FlashMode.torch);
    _torch = !_torch;
    if (!_disposed) notifyListeners();
  });

  @override
  void dispose() {
    _disposed = true;
    // A fila termina sozinha: fecha a câmera e depois os reconhecedores. Uma
    // falha aqui não tem mais a quem avisar além do relatório.
    unawaited(
      stop()
          .then<void>((_) {}, onError: (Object error, StackTrace stack) => onError?.call(error, stack))
          .whenComplete(_analyzer.close),
    );
    super.dispose();
  }

  Future<void> _onImage(CameraController controller, CameraImage image) async {
    if (_analyzing || _disposed || _controller != controller) return;
    final region = viewfinder();
    if (region == null) return;
    final frame = cameraFrameToInputImage(
      image,
      camera: controller.description,
      deviceOrientation: controller.value.deviceOrientation,
    );
    if (frame == null) return;

    _analyzing = true;
    try {
      final upright = uprightImageSize(image.width.toDouble(), image.height.toDouble(), frame.rotationDegrees);
      final crop = viewfinderInImage(
        viewfinder: region.viewfinder,
        screenWidth: region.screenWidth,
        screenHeight: region.screenHeight,
        imageWidth: upright.width,
        imageHeight: upright.height,
      ).inflate(_cropMargin);
      final reading = await _analyzer.analyze(frame.image, at: DateTime.now(), crop: crop);
      if (_disposed || _controller != controller) return;
      final events = _interpreter.add(reading);
      if (events.isNotEmpty) onEvents(events);
    } on Object catch (error, stack) {
      onError?.call(error, stack);
    } finally {
      _analyzing = false;
    }
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _queue.then((_) => action());
    // A fila segue mesmo se um passo falhar; o erro volta para quem chamou.
    _queue = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  static Future<CameraDescription?> _backCamera() async {
    final cameras = await availableCameras();
    return cameras.where((camera) => camera.lensDirection == CameraLensDirection.back).firstOrNull ??
        cameras.firstOrNull;
  }
}
