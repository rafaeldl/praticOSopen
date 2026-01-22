import 'package:praticos/models/product.dart';
import 'package:test/test.dart';

void main() {
  group('Product', () {
    test('Create aggregation', () {
      Product product = Product();
      product.id = 'product123';
      product.name = 'Test Product';
      product.value = 49.99;

      ProductAggr aggr = product.toAggr();

      expect(aggr.id, equals(product.id));
      expect(aggr.name, equals(product.name));
      expect(aggr.value, equals(product.value));
    });

    test('Create from json', () {
      Product product = Product();
      product.id = 'product123';
      product.name = 'Test Product';
      product.value = 29.99;
      product.photo = 'http://example.com/product.jpg';

      Product newProduct = Product.fromJson(product.toJson());

      expect(newProduct.id, equals(product.id));
      expect(newProduct.name, equals(product.name));
      expect(newProduct.value, equals(product.value));
      expect(newProduct.photo, equals(product.photo));
    });

    test('Aggregation contains expected fields', () {
      Product product = Product();
      product.id = 'product123';
      product.name = 'Test Product';
      product.value = 100.00;
      product.photo = 'http://example.com/product.jpg';

      ProductAggr aggr = product.toAggr();
      Map<String, dynamic> aggrJson = aggr.toJson();

      // Aggregation should have id, name, value, photo
      expect(aggrJson.containsKey('id'), isTrue);
      expect(aggrJson.containsKey('name'), isTrue);
      expect(aggrJson.containsKey('value'), isTrue);
      expect(aggrJson.containsKey('photo'), isTrue);
    });

    test('JSON round-trip preserves data', () {
      Product product = Product();
      product.id = 'product456';
      product.name = 'Round Trip Product';
      product.value = 599.99;
      product.photo = 'http://example.com/round-trip.png';

      Map<String, dynamic> json = product.toJson();
      Product restored = Product.fromJson(json);

      expect(restored.toJson(), equals(product.toJson()));
    });

    test('Handles null values', () {
      Product product = Product();
      product.id = 'product789';

      Map<String, dynamic> json = product.toJson();
      Product restored = Product.fromJson(json);

      expect(restored.id, equals('product789'));
      expect(restored.name, isNull);
      expect(restored.value, isNull);
      expect(restored.photo, isNull);
    });
  });

  group('ProductAggr', () {
    test('Create from json', () {
      Map<String, dynamic> json = {
        'id': 'aggr123',
        'name': 'Aggr Product',
        'value': 125.00,
        'photo': 'http://example.com/aggr.jpg',
      };

      ProductAggr aggr = ProductAggr.fromJson(json);

      expect(aggr.id, equals('aggr123'));
      expect(aggr.name, equals('Aggr Product'));
      expect(aggr.value, equals(125.00));
      expect(aggr.photo, equals('http://example.com/aggr.jpg'));
    });

    test('JSON round-trip preserves data', () {
      ProductAggr aggr = ProductAggr();
      aggr.id = 'aggr456';
      aggr.name = 'Test Aggr';
      aggr.value = 349.99;
      aggr.photo = 'http://example.com/test.jpg';

      Map<String, dynamic> json = aggr.toJson();
      ProductAggr restored = ProductAggr.fromJson(json);

      expect(restored.toJson(), equals(aggr.toJson()));
    });
  });
}
