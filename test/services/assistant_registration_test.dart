import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/repositories/v2/device_repository_v2.dart';
import 'package:praticos/services/assistant_registration.dart';

class _Devices implements DeviceRepositoryV2 {
  final saved = <Device?>[];

  @override
  Future<void> createItem(String companyId, Device? item, {String? id}) async =>
      saved.add(item);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => Global.companyAggr = CompanyAggr()..id = 'c1');
  tearDown(() => Global.companyAggr = null);

  test('a vehicle heard by the assistant is found by plate and brand', () async {
    final devices = _Devices();
    final registration = AssistantRegistration(
      devices: devices,
      newId: () => 'd1',
    );
    final device = registration.newDevice(
      serial: 'abc1d23',
      name: 'Gol',
      manufacturer: 'Volkswagen',
    );

    await registration.saveDevice(device);

    expect(devices.saved.single!.keywords, ['gol', 'abc1d23', 'volkswagen']);
  });
}
