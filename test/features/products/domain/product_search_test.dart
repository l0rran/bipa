import 'package:bipa/features/products/domain/product_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  bool matches(String query, String name, {List<String> brands = const [], List<String> barcodes = const []}) =>
      matchesProductSearch(query, name: name, brands: brands, barcodes: barcodes);

  group('matchesProductSearch', () {
    test('ignora acento nos dois lados: ç, ã, é, ú', () {
      expect(matches('acucar', 'Açúcar refinado'), isTrue);
      expect(matches('açúcar', 'Acucar refinado'), isTrue);
      expect(matches('feijao', 'Feijão carioca'), isTrue);
      expect(matches('cafe', 'Café Pilão'), isTrue);
      expect(matches('pao de acucar', 'Pão de Açúcar'), isTrue);
    });

    test('ignora caixa, inclusive de letras acentuadas', () {
      expect(matches('FEIJAO CARIOCA', 'Feijão carioca'), isTrue);
      expect(matches('ACUCAR', 'açúcar'), isTrue);
      expect(matches('feijão', 'FEIJÃO'), isTrue);
    });

    test('pede todas as palavras, em qualquer ordem', () {
      expect(matches('carioca feijao', 'Feijão carioca'), isTrue);
      expect(matches('feijao arroz', 'Feijão carioca'), isFalse);
      expect(matches('feijao preto', 'Feijão carioca'), isFalse);
    });

    test('cada palavra pode ser parte de uma palavra do nome', () {
      expect(matches('arr', 'Arroz branco'), isTrue);
      expect(matches('arr br', 'Arroz branco'), isTrue);
      expect(matches('zoz', 'Arroz branco'), isFalse);
    });

    test('espaços e pontuação sobrando não atrapalham', () {
      expect(matches('  feijao   carioca ', 'Feijão carioca'), isTrue);
      expect(matches('carioca, feijão', 'Feijão carioca'), isTrue);
    });

    test('procura também na marca e junta palavras do nome e da marca', () {
      expect(matches('camil', 'Arroz', brands: ['Camil', 'Tio João']), isTrue);
      expect(matches('arroz tio joao', 'Arroz', brands: ['Tio João']), isTrue);
      expect(matches('arroz kicaldo', 'Arroz', brands: ['Tio João']), isFalse);
    });

    test('o código de barras casa só por igualdade', () {
      expect(matches('7891910000197', 'Café', barcodes: ['7891910000197']), isTrue);
      expect(matches('789191', 'Café', barcodes: ['7891910000197']), isFalse);
    });

    test('uma busca vazia mostra tudo', () {
      expect(matches('', 'Café'), isTrue);
      expect(matches('   ', 'Café'), isTrue);
    });
  });

  group('sameSearchWords', () {
    test('o texto da etiqueta é o mesmo produto do cadastro', () {
      expect(sameSearchWords('FEIJAO CARIOCA', 'Feijão carioca'), isTrue);
      expect(sameSearchWords('carioca feijao', 'Feijão carioca'), isTrue);
      expect(sameSearchWords('Açúcar', 'acucar'), isTrue);
    });

    test('palavra a mais ou a menos não é o mesmo produto', () {
      expect(sameSearchWords('Feijão', 'Feijão carioca'), isFalse);
      expect(sameSearchWords('Feijão carioca 1 kg', 'Feijão carioca'), isFalse);
    });

    test('texto vazio não é igual a nada', () {
      expect(sameSearchWords('', ''), isFalse);
    });
  });
}
