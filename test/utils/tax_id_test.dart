import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/utils/tax_id.dart';

void main() {
  test('normalizeTaxId remove máscara e põe em maiúsculas', () {
    expect(normalizeTaxId('529.982.247-25'), '52998224725');
    expect(normalizeTaxId('11.222.333/0001-81'), '11222333000181');
    expect(normalizeTaxId('12.abc.345/01de-35'), '12ABC34501DE35');
    expect(normalizeTaxId(' 12 345 '), '12345');
    expect(normalizeTaxId(''), '');
  });

  group('CPF', () {
    test('válidos', () {
      expect(isValidCpf('529.982.247-25'), isTrue);
      expect(isValidCpf('12345678909'), isTrue);
    });

    test('inválidos', () {
      expect(isValidCpf('529.982.247-24'), isFalse, reason: 'dígito errado');
      expect(isValidCpf('111.111.111-11'), isFalse, reason: 'repetido');
      expect(isValidCpf('1234567890'), isFalse, reason: 'tamanho');
      expect(isValidCpf('5299822472A'), isFalse, reason: 'letra no CPF');
    });
  });

  group('CNPJ', () {
    test('válidos numéricos', () {
      expect(isValidCnpj('11.222.333/0001-81'), isTrue);
      expect(isValidCnpj('11444777000161'), isTrue);
    });

    test('válido alfanumérico (exemplo oficial da Receita)', () {
      expect(isValidCnpj('12ABC34501DE35'), isTrue);
      expect(isValidCnpj('12.ABC.345/01DE-35'), isTrue);
      expect(isValidCnpj('12.abc.345/01de-35'), isTrue);
    });

    test('inválidos', () {
      expect(isValidCnpj('11.222.333/0001-82'), isFalse, reason: 'dígito errado');
      expect(isValidCnpj('12ABC34501DE36'), isFalse, reason: 'alfa dígito errado');
      expect(isValidCnpj('12ABC34501DEAB'), isFalse, reason: 'DV não numérico');
      expect(isValidCnpj('00.000.000/0000-00'), isFalse, reason: 'repetido');
      expect(isValidCnpj('AAAAAAAAAAAAAA'), isFalse, reason: 'repetido');
      expect(isValidCnpj('1122233300018'), isFalse, reason: 'tamanho');
    });
  });

  test('isValidTaxId decide pelo tamanho', () {
    expect(isValidTaxId('529.982.247-25'), isTrue);
    expect(isValidTaxId('11.222.333/0001-81'), isTrue);
    expect(isValidTaxId('12ABC34501DE35'), isTrue);
    expect(isValidTaxId('123'), isFalse);
    expect(isValidTaxId('52998224725000'), isFalse);
  });

  test('formatTaxId aplica a máscara', () {
    expect(formatTaxId('52998224725'), '529.982.247-25');
    expect(formatTaxId('11222333000181'), '11.222.333/0001-81');
    expect(formatTaxId('12abc34501de35'), '12.ABC.345/01DE-35');
    expect(formatTaxId('12-3'), '123');
  });
}
