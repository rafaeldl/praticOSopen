import 'package:praticos/models/service.dart';
import 'package:test/test.dart';

void main() {
  group('Service', () {
    test('Create aggregation', () {
      Service service = Service();
      service.id = 'service123';
      service.name = 'Test Service';
      service.value = 150.00;

      ServiceAggr aggr = service.toAggr();

      expect(aggr.id, equals(service.id));
      expect(aggr.name, equals(service.name));
      expect(aggr.value, equals(service.value));
    });

    test('Create from json', () {
      Service service = Service();
      service.id = 'service123';
      service.name = 'Test Service';
      service.value = 250.50;
      service.photo = 'http://example.com/service.jpg';

      Service newService = Service.fromJson(service.toJson());

      expect(newService.id, equals(service.id));
      expect(newService.name, equals(service.name));
      expect(newService.value, equals(service.value));
      expect(newService.photo, equals(service.photo));
    });

    test('Aggregation contains expected fields', () {
      Service service = Service();
      service.id = 'service123';
      service.name = 'Test Service';
      service.value = 100.00;
      service.photo = 'http://example.com/service.jpg';

      ServiceAggr aggr = service.toAggr();
      Map<String, dynamic> aggrJson = aggr.toJson();

      // Aggregation should have id, name, value, photo
      expect(aggrJson.containsKey('id'), isTrue);
      expect(aggrJson.containsKey('name'), isTrue);
      expect(aggrJson.containsKey('value'), isTrue);
      expect(aggrJson.containsKey('photo'), isTrue);
    });

    test('JSON round-trip preserves data', () {
      Service service = Service();
      service.id = 'service456';
      service.name = 'Round Trip Service';
      service.value = 999.99;
      service.photo = 'http://example.com/round-trip.png';

      Map<String, dynamic> json = service.toJson();
      Service restored = Service.fromJson(json);

      expect(restored.toJson(), equals(service.toJson()));
    });

    test('Handles null values', () {
      Service service = Service();
      service.id = 'service789';

      Map<String, dynamic> json = service.toJson();
      Service restored = Service.fromJson(json);

      expect(restored.id, equals('service789'));
      expect(restored.name, isNull);
      expect(restored.value, isNull);
      expect(restored.photo, isNull);
    });
  });

  group('ServiceAggr', () {
    test('Create from json', () {
      Map<String, dynamic> json = {
        'id': 'aggr123',
        'name': 'Aggr Service',
        'value': 75.50,
        'photo': 'http://example.com/aggr.jpg',
      };

      ServiceAggr aggr = ServiceAggr.fromJson(json);

      expect(aggr.id, equals('aggr123'));
      expect(aggr.name, equals('Aggr Service'));
      expect(aggr.value, equals(75.50));
      expect(aggr.photo, equals('http://example.com/aggr.jpg'));
    });

    test('JSON round-trip preserves data', () {
      ServiceAggr aggr = ServiceAggr();
      aggr.id = 'aggr456';
      aggr.name = 'Test Aggr';
      aggr.value = 199.99;
      aggr.photo = 'http://example.com/test.jpg';

      Map<String, dynamic> json = aggr.toJson();
      ServiceAggr restored = ServiceAggr.fromJson(json);

      expect(restored.toJson(), equals(aggr.toJson()));
    });
  });
}
