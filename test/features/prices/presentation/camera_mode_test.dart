import 'package:bipa/core/navigation/routes.dart';
import 'package:bipa/features/prices/presentation/camera_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('o modo da câmera vem da rota, e sem ele é a etiqueta', () {
    expect(CameraMode.fromQuery('usei'), CameraMode.used);
    expect(CameraMode.fromQuery('comprei'), CameraMode.bought);
    expect(CameraMode.fromQuery(null), CameraMode.price);
    expect(CameraMode.fromQuery('outro'), CameraMode.price);
  });

  test('as rotas da câmera usam os nomes dos modos', () {
    expect(Uri.parse(Routes.cameraBought).queryParameters['modo'], CameraMode.bought.query);
    expect(Uri.parse(Routes.cameraUsed).queryParameters['modo'], CameraMode.used.query);
  });
}
