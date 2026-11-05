import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/custom_field.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/utils/device_reading.dart';

// The three kinds of segment: a vehicle shop (km), a machine shop (hours) and
// a phone repair (no reading).
const mileage = CustomField(
  key: 'device.mileage',
  type: 'number',
  labels: {'pt-BR': 'Quilometragem'},
  suffix: 'km',
  reading: true,
);
const hours = CustomField(
  key: 'device.operatingHours',
  type: 'number',
  labels: {'pt-BR': 'Horas de Operação'},
  suffix: 'h',
);
const year = CustomField(
  key: 'device.year',
  type: 'number',
  labels: {'pt-BR': 'Ano'},
);
const battery = CustomField(
  key: 'device.batteryHealth',
  type: 'number',
  labels: {'pt-BR': 'Saúde da bateria'},
  suffix: '%',
);

void main() {
  final pt = FormatService()..setLocale('pt');

  group('readingFieldOf', () {
    test('automotive: the field marked as reading (km)', () {
      expect(readingFieldOf(const [year, mileage])?.key, 'device.mileage');
    });

    test('machines: an old segment without the flag still has hours', () {
      expect(readingFieldOf(const [year, hours])?.key, 'device.operatingHours');
    });

    test('phones: no reading, not even a number field with a unit', () {
      expect(readingFieldOf(const [battery]), isNull);
      expect(readingFieldOf(const []), isNull);
    });

    test('a flagged field wins over a legacy key', () {
      const pages = CustomField(
        key: 'device.pageCounter',
        type: 'number',
        labels: {'pt-BR': 'Contador'},
        reading: true,
      );
      expect(readingFieldOf(const [hours, pages])?.key, 'device.pageCounter');
    });

    test('the flag survives the JSON of the segment', () {
      final field = CustomField.fromJson(mileage.toJson());
      expect(field.reading, isTrue);
      expect(CustomField.fromJson(hours.toJson()).reading, isFalse);
    });
  });

  group('format and parse', () {
    test('unit from the segment, grouped by locale', () {
      expect(formatReading(mileage, 98000, pt), '98.000 km');
      expect(formatReading(hours, '1250', pt), '1.250 h');
      expect(formatReading(year, 3400, pt), '3.400');
      expect(formatReading(mileage, null, pt), isNull);
    });

    test('old values typed as text still read', () {
      expect(parseReading('98.000'), 98000);
      expect(parseReading('98,000'), 98000);
      expect(parseReading(98000.0), 98000);
      expect(parseReading('abc'), isNull);
      expect(parseReading(-5), isNull);
      expect(parseReading(12.5), isNull);
    });

    test('device value by field name, or by the old whole key', () {
      expect(deviceReading({'mileage': 45000}, mileage), 45000);
      expect(deviceReading({'device.mileage': '45000'}, mileage), 45000);
      expect(deviceReading(null, mileage), isNull);
    });
  });

  test('the device keeps the bigger reading', () {
    expect(readingAdvances(null, 10), isTrue);
    expect(readingAdvances(98000, 98000), isTrue);
    expect(readingAdvances(98000, 99000), isTrue);
    expect(readingAdvances(98000, 50000), isFalse);
  });

  test('order keeps each device reading in deviceReadings', () {
    final order = Order()..deviceReadings = {'d1': 98000, 'd2': 1250};
    final back = Order.fromJson(order.toJson());
    expect(back.deviceReadings, {'d1': 98000, 'd2': 1250});
    expect(Order.fromJson(<String, dynamic>{}).deviceReadings, isNull);
  });
}
