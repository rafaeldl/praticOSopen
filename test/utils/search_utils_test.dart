import 'package:praticos/utils/search_utils.dart';
import 'package:test/test.dart';

void main() {
  group('removeAccents', () {
    test('removes common Portuguese accents', () {
      expect(removeAccents('João'), equals('joao'));
      expect(removeAccents('José'), equals('jose'));
      expect(removeAccents('Açúcar'), equals('acucar'));
      expect(removeAccents('Ação'), equals('acao'));
      expect(removeAccents('Café'), equals('cafe'));
    });

    test('removes Spanish accents', () {
      expect(removeAccents('Señor'), equals('senor'));
      expect(removeAccents('Niño'), equals('nino'));
      expect(removeAccents('Español'), equals('espanol'));
    });

    test('handles mixed case', () {
      expect(removeAccents('JOÃO'), equals('joao'));
      expect(removeAccents('JoÃo'), equals('joao'));
    });

    test('preserves non-accented characters', () {
      expect(removeAccents('abc'), equals('abc'));
      expect(removeAccents('123'), equals('123'));
      expect(removeAccents('test'), equals('test'));
    });
  });

  group('generateKeywords', () {
    test('removes accents and special characters', () {
      expect(
        generateKeywords('João Da Silva&*-'),
        equals(['joao', 'da', 'silva']),
      );
    });

    test('handles names with accents', () {
      expect(
        generateKeywords('Maria José'),
        equals(['maria', 'jose']),
      );
    });

    test('removes special characters', () {
      expect(
        generateKeywords('Açúcar & Café!'),
        equals(['acucar', 'cafe']),
      );
    });

    test('handles null input', () {
      expect(generateKeywords(null), equals([]));
    });

    test('handles empty string', () {
      expect(generateKeywords(''), equals([]));
    });

    test('preserves numbers', () {
      expect(
        generateKeywords('123 ABC'),
        equals(['123', 'abc']),
      );
    });

    test('handles multiple spaces', () {
      expect(
        generateKeywords('João    Maria'),
        equals(['joao', 'maria']),
      );
    });

    test('handles leading and trailing spaces', () {
      expect(
        generateKeywords('  João Silva  '),
        equals(['joao', 'silva']),
      );
    });

    test('handles only special characters', () {
      expect(
        generateKeywords('&*@#\$%'),
        equals([]),
      );
    });

    test('handles real world examples', () {
      // Brazilian names
      expect(
        generateKeywords('José da Silva Júnior'),
        equals(['jose', 'da', 'silva', 'junior']),
      );
      expect(
        generateKeywords('Maria Conceição dos Santos'),
        equals(['maria', 'conceicao', 'dos', 'santos']),
      );

      // Company names
      expect(
        generateKeywords('Oficina do João - ME'),
        equals(['oficina', 'do', 'joao', 'me']),
      );
      expect(
        generateKeywords('Auto Peças São Paulo Ltda.'),
        equals(['auto', 'pecas', 'sao', 'paulo', 'ltda']),
      );

      // Product/Service names
      expect(
        generateKeywords('Troca de Óleo 5W30'),
        equals(['troca', 'de', 'oleo', '5w30']),
      );
    });

    test('handles uppercase input', () {
      expect(
        generateKeywords('JOÃO DA SILVA'),
        equals(['joao', 'da', 'silva']),
      );
    });

    test('handles mixed case input', () {
      expect(
        generateKeywords('JoÃo Da SiLvA'),
        equals(['joao', 'da', 'silva']),
      );
    });
  });
}
