import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/customer.dart';

void main() {
  test('taxId vai e volta no JSON e é copiado para o agregado', () {
    final customer = Customer()
      ..id = 'c1'
      ..name = 'Maria'
      ..taxId = '52998224725';

    final json = customer.toJson();
    expect(json['taxId'], '52998224725');
    expect(Customer.fromJson(json).taxId, '52998224725');

    final aggr = customer.toAggr();
    expect(aggr.taxId, '52998224725');
    expect(aggr.toJson()['taxId'], '52998224725');
    expect(CustomerAggr.fromJson(aggr.toJson()).taxId, '52998224725');
  });

  test('taxId de CNPJ alfanumérico normalizado é preservado', () {
    final customer = Customer()
      ..id = 'c3'
      ..taxId = '12ABC34501DE35';

    expect(Customer.fromJson(customer.toJson()).taxId, '12ABC34501DE35');
    expect(customer.toAggr().taxId, '12ABC34501DE35');
  });

  test('cliente sem taxId continua válido', () {
    final customer = Customer.fromJson({'id': 'c2', 'name': 'João'});

    expect(customer.taxId, isNull);
    expect(customer.toAggr().taxId, isNull);
  });
}
