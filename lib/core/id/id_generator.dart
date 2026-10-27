import 'package:uuid/uuid.dart';

/// Gera identificadores únicos globais.
///
/// Os IDs são criados no próprio aparelho para que registros feitos offline
/// possam ser sincronizados depois com o servidor sem colisões.
abstract interface class IdGenerator {
  String newId();
}

/// Implementação padrão baseada em UUID v4.
final class UuidGenerator implements IdGenerator {
  const UuidGenerator();

  static const _uuid = Uuid();

  @override
  String newId() => _uuid.v4();
}
