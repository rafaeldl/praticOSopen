import 'package:praticos/utils/amount_parser.dart';
import 'package:test/test.dart';

void main() {
  group('AmountParser.parse', () {
    test('empty string returns 0', () {
      expect(AmountParser.parse(''), equals(0));
    });

    test('plain integer', () {
      expect(AmountParser.parse('450'), equals(450));
    });

    test('plain decimal with dot', () {
      expect(AmountParser.parse('450.50'), equals(450.50));
    });

    test('Brazilian format: comma as decimal', () {
      expect(AmountParser.parse('450,50'), equals(450.50));
    });

    test('Brazilian format: dot as thousand separator', () {
      expect(AmountParser.parse('1.234,56'), equals(1234.56));
    });

    test('US format: comma as thousand separator', () {
      expect(AmountParser.parse('1,234.56'), equals(1234.56));
    });

    test('currency symbol R\$', () {
      expect(AmountParser.parse('R\$ 450,00'), equals(450.0));
    });

    test('currency symbol with thousands', () {
      expect(AmountParser.parse('R\$ 1.234,56'), equals(1234.56));
    });

    test('whitespace only returns 0', () {
      expect(AmountParser.parse('   '), equals(0));
    });

    test('invalid characters return 0', () {
      expect(AmountParser.parse('abc'), equals(0));
    });

    test('negative value', () {
      expect(AmountParser.parse('-100'), equals(-100));
    });

    test('negative Brazilian format', () {
      expect(AmountParser.parse('-1.234,56'), equals(-1234.56));
    });

    test('zero', () {
      expect(AmountParser.parse('0'), equals(0));
      expect(AmountParser.parse('0,00'), equals(0));
    });

    test('large value', () {
      expect(AmountParser.parse('999.999,99'), equals(999999.99));
    });
  });
}
