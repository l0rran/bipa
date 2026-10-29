import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  test('fechar o banco duas vezes é o mesmo que fechar uma', () async {
    // A restauração do backup fecha e espera; o provider fecha de novo ao
    // ser descartado.
    final db = createTestDatabase();
    await db.customSelect('SELECT 1').get();

    final first = db.close();
    expect(db.close(), same(first));
    await first;
  });
}
