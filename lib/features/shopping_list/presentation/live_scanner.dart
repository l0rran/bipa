import 'dart:async';
import 'dart:io';

import 'package:bipa/core/camera/camera_input_image.dart';
import 'package:bipa/core/camera/live_frame_analyzer.dart';
import 'package:bipa/core/camera/viewfinder_region.dart';
import 'package:bipa/features/shopping_list/domain/live_scan.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart' show InputImage;

/// Onde a moldura está, relativa à prévia, e o tamanho da prévia, para
/// recortar cada quadro.
typedef ViewfinderOnScreen = ({PixelRect viewfinder, double screenWidth, double screenHeight});

/// A câmera do modo carrinho (ADR 0012): mostra a prévia e lê cada quadro,
/// código de barras e etiqueta juntos, só dentro da moldura.
///
/// Só um quadro é analisado por vez; os que chegam enquanto isso são pulados.
/// [start], [stop] e [toggleTorch] rodam em fila, na ordem em que foram
/// chamados.
final class LiveScanner extends ChangeNotifier {
  LiveScanner({
    required this.onEvents,
    required this.viewfinder,
    required LiveFrameAnalyzer analyzer,
    this.onError,
    LiveScanInterpreter? interpreter,
  }) : _analyzer = analyzer,
       _interpreter = interpreter ?? LiveScanInterpreter();

  /// O que a leitura concluiu (bipes e etiquetas), na ordem.
  final void Function(List<LiveScanEvent> events) onEvents;

  /// A posição atual da moldura; `null` enquanto ela não foi desenhada.
  final ViewfinderOnScreen? Function() viewfinder;

  /// Falhas da câmera ou do reconhecimento, para o relatório.
  final void Function(Object error, StackTrace stack)? onError;

  final LiveFrameAnalyzer _analyzer;
  final LiveScanInterpreter _interpreter;

  /// Uma margem em volta da moldura: a etiqueta raramente cabe certinha.
  static const _cropMargin = 0.15;

  CameraController? _controller;
  CameraDescription? _camera;
  Future<void>? _inFlight;
  var _torch = false;
  var _disposed = false;
  Future<void> _queue = Future.value();

  var _analysisPaused = false;

  /// Com a análise pausada, a prévia continua, mas nenhum quadro é lido:
  /// enquanto um diálogo está por cima, por exemplo. Ao voltar, a leitura
  /// recomeça como ao abrir a câmera: o produto que ficou na frente (o que
  /// acabou de ser cadastrado, por exemplo) não soma outra unidade.
  bool get analysisPaused => _analysisPaused;

  set analysisPaused(bool paused) {
    if (_analysisPaused && !paused) _interpreter.restart(DateTime.now());
    _analysisPaused = paused;
  }

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
      _interpreter.restart(DateTime.now());
      _torch = false;
      _controller = controller;
      _notify();
      await controller.startImageStream((image) => _onImage(controller, image));
    } on Object {
      if (_controller == controller) {
        _controller = null;
        _notify();
      }
      // O erro que importa é o da abertura (permissão negada, por exemplo).
      await _quietly(controller.dispose);
      rethrow;
    }
  });

  /// Fecha a câmera: no fundo, ou enquanto outra tela usa a câmera.
  Future<void> stop() => _enqueue(() async {
    final controller = _controller;
    if (controller == null) return;
    _controller = null;
    _torch = false;
    _notify();
    try {
      if (controller.value.isStreamingImages) await controller.stopImageStream();
    } finally {
      await controller.dispose();
    }
  });

  /// O disparo: fotografa o que está na frente, em alta resolução, para ler a
  /// etiqueta que a leitura ao vivo deixou passar. A leitura para durante a
  /// foto (nem toda câmera fotografa enquanto entrega quadros) e volta em
  /// seguida. Devolve o caminho do arquivo, ou `null` com a câmera fechada.
  Future<String?> takePicture() async {
    String? path;
    await _enqueue(() async {
      final controller = _controller;
      if (controller == null || _disposed) return;
      try {
        if (controller.value.isStreamingImages) await controller.stopImageStream();
        path = (await controller.takePicture()).path;
      } finally {
        // A leitura ao vivo volta mesmo se a foto falhar. Uma falha aqui não
        // perde a foto já tirada: só é relatada.
        if (_controller == controller && !_disposed && !controller.value.isStreamingImages) {
          _interpreter.restart(DateTime.now());
          await _quietly(() => controller.startImageStream((image) => _onImage(controller, image)));
        }
      }
    });
    return path;
  }

  Future<void> toggleTorch() => _enqueue(() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.setFlashMode(_torch ? FlashMode.off : FlashMode.torch);
    _torch = !_torch;
    _notify();
  });

  @override
  void dispose() {
    _disposed = true;
    // Fecha a câmera, espera o quadro em análise e só então os
    // reconhecedores. Uma falha aqui só tem o relatório a quem avisar.
    unawaited(_shutDown());
    super.dispose();
  }

  Future<void> _shutDown() async {
    try {
      await stop();
      await _inFlight;
      await _analyzer.close();
    } on Object catch (error, stack) {
      onError?.call(error, stack);
    }
  }

  void _onImage(CameraController controller, CameraImage image) {
    if (_inFlight != null || _analysisPaused || _disposed || _controller != controller) return;
    final region = viewfinder();
    if (region == null) return;
    final frame = cameraFrameToInputImage(
      image,
      camera: controller.description,
      deviceOrientation: controller.value.deviceOrientation,
    );
    if (frame == null) return;

    final upright = uprightImageSize(image.width.toDouble(), image.height.toDouble(), frame.rotationDegrees);
    final crop = viewfinderInImage(
      viewfinder: region.viewfinder,
      screenWidth: region.screenWidth,
      screenHeight: region.screenHeight,
      imageWidth: upright.width,
      imageHeight: upright.height,
    ).inflate(_cropMargin);
    _inFlight = _analyze(controller, frame.image, crop).whenComplete(() {
      _inFlight = null;
    });
  }

  Future<void> _analyze(CameraController controller, InputImage image, PixelRect crop) async {
    try {
      final reading = await _analyzer.analyze(image, at: DateTime.now(), crop: crop);
      if (_disposed || _analysisPaused || _controller != controller) return;
      final events = _interpreter.add(reading);
      if (events.isNotEmpty) onEvents(events);
    } on Object catch (error, stack) {
      onError?.call(error, stack);
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _queue.then((_) => action());
    // A fila segue mesmo se um passo falhar; o erro volta para quem chamou.
    _queue = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  Future<void> _quietly(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error, stack) {
      onError?.call(error, stack);
    }
  }

  static Future<CameraDescription?> _backCamera() async {
    final cameras = await availableCameras();
    return cameras.where((camera) => camera.lensDirection == CameraLensDirection.back).firstOrNull ??
        cameras.firstOrNull;
  }
}
