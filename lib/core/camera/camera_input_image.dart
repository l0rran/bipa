import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Um quadro da câmera pronto para o ML Kit, com a rotação aplicada.
typedef CameraFrame = ({InputImage image, int rotationDegrees});

const _deviceRotation = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

/// Converte um quadro do `startImageStream` para a `InputImage` do ML Kit,
/// como no exemplo oficial do google_ml_kit_flutter (ADR 0012).
///
/// Devolve `null` quando o formato do quadro não é aceito pelo ML Kit; o
/// quadro é só pulado.
CameraFrame? cameraFrameToInputImage(
  CameraImage image, {
  required CameraDescription camera,
  required DeviceOrientation deviceOrientation,
}) {
  final rotationDegrees = _rotationDegrees(camera, deviceOrientation);
  if (rotationDegrees == null) return null;
  final rotation = InputImageRotationValue.fromRawValue(rotationDegrees);
  final format = InputImageFormatValue.fromRawValue(image.format.raw as int);
  if (rotation == null || format == null) return null;

  final Uint8List bytes;
  var resolvedFormat = format;
  if (Platform.isAndroid) {
    switch (format) {
      case InputImageFormat.nv21 when image.planes.length == 1:
        bytes = image.planes.first.bytes;
      case InputImageFormat.yuv_420_888 || InputImageFormat.yv12 when image.planes.length == 3:
        bytes = _yuv420ToNv21(image);
        resolvedFormat = InputImageFormat.nv21;
      default:
        return null;
    }
  } else if (format == InputImageFormat.bgra8888 && image.planes.length == 1) {
    bytes = image.planes.first.bytes;
  } else {
    return null;
  }

  return (
    image: InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: resolvedFormat,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    ),
    rotationDegrees: rotationDegrees,
  );
}

/// No Android, o ML Kit precisa da rotação que deixa a imagem em pé: a do
/// sensor compensada pela orientação do aparelho. No iOS, basta a do sensor.
int? _rotationDegrees(CameraDescription camera, DeviceOrientation deviceOrientation) {
  final sensor = camera.sensorOrientation;
  if (!Platform.isAndroid) return sensor;
  final device = _deviceRotation[deviceOrientation];
  if (device == null) return null;
  return camera.lensDirection == CameraLensDirection.front ? (sensor + device) % 360 : (sensor - device + 360) % 360;
}

/// Junta os três planos YUV num buffer NV21 (Y, depois V e U intercalados),
/// tirando o preenchimento de cada linha.
Uint8List _yuv420ToNv21(CameraImage image) {
  final width = image.width;
  final height = image.height;
  final ySize = width * height;
  final nv21 = Uint8List(ySize + ySize ~/ 2);

  final yPlane = image.planes[0];
  for (var row = 0; row < height; row++) {
    nv21.setRange(row * width, row * width + width, yPlane.bytes, row * yPlane.bytesPerRow);
  }

  final uPlane = image.planes[1];
  final vPlane = image.planes[2];
  final uStride = uPlane.bytesPerPixel ?? 1;
  final vStride = vPlane.bytesPerPixel ?? 1;
  var index = ySize;
  for (var row = 0; row < height ~/ 2; row++) {
    for (var col = 0; col < width ~/ 2; col++) {
      nv21[index++] = vPlane.bytes[row * vPlane.bytesPerRow + col * vStride];
      nv21[index++] = uPlane.bytes[row * uPlane.bytesPerRow + col * uStride];
    }
  }
  return nv21;
}
