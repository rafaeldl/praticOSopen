import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/device.dart';

void main() {
  Device saved() => Device.fromJson({
    'id': 'd1',
    'name': 'Split',
    'nextMaintenanceDate': '2027-05-12',
    'nextMaintenanceCustomer': {'id': 'cu1', 'name': 'Padaria'},
    'nextMaintenanceLastService': 'Limpeza',
  });

  test('reads the day and who it is for', () {
    final device = saved();
    expect(device.nextMaintenance, DateTime(2027, 5, 12));
    expect(device.nextMaintenanceCustomer?.name, 'Padaria');
    expect(device.nextMaintenanceLastService, 'Limpeza');
  });

  test('has no date on a device without one', () {
    expect(Device.fromJson({'id': 'd1'}).nextMaintenance, isNull);
  });

  test('saving a device never writes the date, so it cannot erase it', () {
    final json = saved().toJson();
    expect(json.containsKey('nextMaintenanceDate'), isFalse);
    expect(json.containsKey('nextMaintenanceCustomer'), isFalse);
    expect(json.containsKey('nextMaintenanceLastService'), isFalse);
  });

  test('stays out of the aggregate embedded in orders', () {
    final json = saved().toAggr().toJson();
    expect(json.containsKey('nextMaintenanceDate'), isFalse);
  });
}
