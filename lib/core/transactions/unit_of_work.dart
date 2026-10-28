/// Roda várias operações dos repositórios como uma só: ou todas ficam, ou
/// nenhuma. Os casos de uso usam isso sem conhecer o banco (o domínio não
/// importa o Drift).
abstract interface class UnitOfWork {
  Future<T> run<T>(Future<T> Function() action);
}
