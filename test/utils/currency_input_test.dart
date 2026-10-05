import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/utils/currency_input.dart';

void main() {
  final format = FormatService();

  tearDown(() => format.setLocale('pt-BR'));

  group('parseCurrencyInput', () {
    test('reads the value formatted by FormatService', () {
      for (final locale in ['pt-BR', 'en-US', 'es-ES']) {
        format.setLocale(locale);
        expect(parseCurrencyInput(format.formatCurrency(1234.56)), 1234.56,
            reason: locale);
      }
    });

    test('reads the BRL field mask in any app locale', () {
      for (final locale in ['pt-BR', 'en-US', 'es-ES']) {
        format.setLocale(locale);
        expect(parseCurrencyInput('R\$ 1.500,00'), 1500.0, reason: locale);
        expect(parseCurrencyInput('R\$ 1.500,25'), 1500.25,
            reason: locale);
      }
    });

    test('plain numbers in the app locale', () {
      expect(parseCurrencyInput('1500,5'), 1500.5);
      format.setLocale('en-US');
      expect(parseCurrencyInput('1,500.50'), 1500.5);
    });

    test('empty or garbage is zero', () {
      expect(parseCurrencyInput(''), 0);
      expect(parseCurrencyInput('   '), 0);
      expect(parseCurrencyInput('abc'), 0);
    });
  });
}
