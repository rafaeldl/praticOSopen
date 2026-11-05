import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/screens/order/order_missing_data.dart';

DeviceAggr _device(String id, {String? name, String? serial}) => DeviceAggr()
  ..id = id
  ..name = name
  ..serial = serial;

void main() {
  final customer = CustomerAggr()
    ..id = 'c1'
    ..name = 'Ana';

  test('WhatsApp, plate or model; nothing else (same rule as the web)', () {
    expect(
      missingOnOrder(
        customer: customer,
        devices: [
          _device('d1', name: 'Argo'),
          _device('d2', name: 'ABC1D23', serial: 'ABC1D23'),
          _device('d3', name: 'Onix', serial: 'XYZ9A99'),
        ],
        canEditCustomers: true,
        canEditDevices: true,
      ),
      const [
        MissingData(MissingKind.phone),
        MissingData(MissingKind.serial, 'd1'),
        MissingData(MissingKind.model, 'd2'),
      ],
    );
  });

  test('without permission or with a phone, nothing', () {
    expect(
      missingOnOrder(
        customer: customer,
        devices: [_device('d1', name: 'Argo')],
        canEditCustomers: false,
        canEditDevices: false,
      ),
      isEmpty,
    );
    expect(
      missingOnOrder(
        customer: CustomerAggr()
          ..id = 'c1'
          ..phone = '11 99999-0000',
        devices: const [],
        canEditCustomers: true,
        canEditDevices: true,
      ),
      isEmpty,
    );
  });
}
