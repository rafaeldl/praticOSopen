import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/utils/phone_format.dart';

void main() {
  test('formats a Brazilian mobile typed with country code', () {
    expect(formatPhone('+5548984087801', country: 'BR'), '(48) 98408-7801');
  });

  test('formats a Brazilian number typed without country code', () {
    expect(formatPhone('11900000001', country: 'BR'), '(11) 90000-0001');
    expect(formatPhone('(11) 90000-0001', country: 'BR'), '(11) 90000-0001');
  });

  test('landline has 4 digits after the dash', () {
    expect(formatPhone('+554832223344', country: 'BR'), '(48) 3222-3344');
  });

  test('foreign numbers keep the country code', () {
    expect(formatPhone('+351912345678', country: 'BR'), startsWith('+351 '));
  });

  test('falls back to the raw text when it cannot be parsed', () {
    expect(formatPhone('abc', country: 'BR'), 'abc');
    expect(formatPhone('123', country: 'BR'), '123');
    expect(formatPhone(null), '');
  });
}
