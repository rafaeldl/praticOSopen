import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/utils/device_suggestions.dart';

Device d(String name, {String? brand, String? category}) => Device()
  ..name = name
  ..manufacturer = brand
  ..category = category;

void main() {
  test('empty query returns nothing', () {
    expect(deviceSuggestions([d('Uno')], '  '), isEmpty);
  });

  test('groups equal models, ranks by repetition and matches name or brand',
      () {
    final result = deviceSuggestions([
      d('Fiat Uno 2015', brand: 'Fiat', category: 'Carro'),
      d('Fiat Uno 2015', brand: 'Fiat', category: 'Carro'),
      d('Fiat Palio', brand: 'Fiat', category: 'Carro'),
      d('Gol 1.0', brand: 'VW', category: 'Carro'),
    ], 'fiat');

    expect(result.map((s) => s.name), ['Fiat Uno 2015', 'Fiat Palio']);
    expect(result.first.count, 2);
    expect(result.first.manufacturer, 'Fiat');
    expect(result.first.category, 'Carro');
    expect(result.first.detail, 'Fiat · Carro');
  });

  test('ignores devices without a name and respects the limit', () {
    final devices = [
      d(''),
      for (var i = 0; i < 8; i++) d('Model $i'),
    ];
    expect(deviceSuggestions(devices, 'model', limit: 3), hasLength(3));
  });
}
