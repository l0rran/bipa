import 'package:bipa/core/database/app_database.dart';
import 'package:bipa/core/transactions/unit_of_work.dart';

/// Uma transação do Drift. As consultas dos repositórios feitas dentro dela
/// entram na mesma transação (o Drift acompanha pela zona), e as transações
/// deles viram pontos de salvamento.
final class DriftUnitOfWork implements UnitOfWork {
  const DriftUnitOfWork(this._db);

  final AppDatabase _db;

  @override
  Future<T> run<T>(Future<T> Function() action) => _db.transaction(action);
}
