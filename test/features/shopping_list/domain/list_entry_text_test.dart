import 'package:bipa/features/shopping_list/domain/list_entry_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a quantidade escrita antes ou depois do nome', () {
    const written = [
      ...['2 leite', '2x leite', '2 x leite', '2× leite', '2X leite'],
      ...['leite 2', 'leite x2', 'leite x 2', 'leite 2x'],
    ];
    for (final text in written) {
      expect(ListEntryText.parse(text), const ListEntryText('leite', quantity: 2), reason: text);
    }
    expect(ListEntryText.parse('  pilhas aa 4 '), const ListEntryText('pilhas aa', quantity: 4));
  });

  test('número que é parte do nome, ou fora de 1 a 99, fica no nome', () {
    const names = ['coca 2l', 'pão 7 grãos', 'arroz 5 kg', 'leite 1 l', '0 leite', '100 leite', '2', 'x2', 'leite'];
    for (final text in names) {
      expect(ListEntryText.parse(text), ListEntryText(text), reason: text);
    }
  });
}
