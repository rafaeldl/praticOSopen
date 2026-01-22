import 'package:praticos/models/device.dart';
import 'package:test/test.dart';

void main() {
  group('Device', () {
    test('Create aggregation', () {
      Device device = Device();
      device.id = 'device123';
      device.name = 'Test Device';
      device.serial = 'SN123';
      device.manufacturer = 'Test Manufacturer';
      device.category = 'Test Category';

      DeviceAggr aggr = device.toAggr();

      expect(aggr.id, equals(device.id));
      expect(aggr.name, equals(device.name));
      expect(aggr.serial, equals(device.serial));
    });

    test('Create from json', () {
      Device device = Device();
      device.id = 'device123';
      device.name = 'Test Device';
      device.serial = 'SN123';
      device.manufacturer = 'Test Manufacturer';
      device.category = 'Test Category';
      device.description = 'Test Description';

      Device newDevice = Device.fromJson(device.toJson());

      expect(newDevice.id, equals(device.id));
      expect(newDevice.name, equals(device.name));
      expect(newDevice.serial, equals(device.serial));
      expect(newDevice.manufacturer, equals(device.manufacturer));
      expect(newDevice.category, equals(device.category));
      expect(newDevice.description, equals(device.description));
    });

    test('Aggregation only contains essential fields', () {
      Device device = Device();
      device.id = 'device123';
      device.name = 'Test Device';
      device.serial = 'SN123';
      device.manufacturer = 'Test Manufacturer';
      device.category = 'Test Category';
      device.description = 'Test Description';
      device.photo = 'http://example.com/photo.jpg';

      DeviceAggr aggr = device.toAggr();
      Map<String, dynamic> aggrJson = aggr.toJson();

      // Aggregation should have id, name, serial, photo
      expect(aggrJson.containsKey('id'), isTrue);
      expect(aggrJson.containsKey('name'), isTrue);
      expect(aggrJson.containsKey('serial'), isTrue);
      expect(aggrJson.containsKey('photo'), isTrue);

      // Aggregation should NOT have manufacturer, category, description
      expect(aggrJson.containsKey('manufacturer'), isFalse);
      expect(aggrJson.containsKey('category'), isFalse);
      expect(aggrJson.containsKey('description'), isFalse);
    });

    test('JSON round-trip preserves data', () {
      Device device = Device();
      device.id = 'device456';
      device.name = 'Round Trip Device';
      device.serial = 'RT-001';
      device.manufacturer = 'Round Trip Manufacturer';
      device.category = 'Electronics';
      device.description = 'A device for testing round trips';
      device.photo = 'http://example.com/device.png';

      Map<String, dynamic> json = device.toJson();
      Device restored = Device.fromJson(json);

      expect(restored.toJson(), equals(device.toJson()));
    });
  });

  group('DeviceAggr', () {
    test('Create from json', () {
      Map<String, dynamic> json = {
        'id': 'aggr123',
        'name': 'Aggr Device',
        'serial': 'AGGR-001',
        'photo': 'http://example.com/aggr.jpg',
      };

      DeviceAggr aggr = DeviceAggr.fromJson(json);

      expect(aggr.id, equals('aggr123'));
      expect(aggr.name, equals('Aggr Device'));
      expect(aggr.serial, equals('AGGR-001'));
      expect(aggr.photo, equals('http://example.com/aggr.jpg'));
    });

    test('JSON round-trip preserves data', () {
      DeviceAggr aggr = DeviceAggr();
      aggr.id = 'aggr456';
      aggr.name = 'Test Aggr';
      aggr.serial = 'TA-001';
      aggr.photo = 'http://example.com/test.jpg';

      Map<String, dynamic> json = aggr.toJson();
      DeviceAggr restored = DeviceAggr.fromJson(json);

      expect(restored.toJson(), equals(aggr.toJson()));
    });
  });
}
