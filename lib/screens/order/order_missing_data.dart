import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';

/// What a saved order's customer or device still lacks that is worth asking
/// (order.quick.complete, docs/QUICK_REGISTER.md): the customer's WhatsApp
/// and each device's plate/serial or model. Never e-mail or CPF.
enum MissingKind { phone, serial, model }

class MissingData {
  const MissingData(this.kind, [this.deviceId]);

  final MissingKind kind;

  /// The device it is about (serial and model only).
  final String? deviceId;

  @override
  bool operator ==(Object other) =>
      other is MissingData && other.kind == kind && other.deviceId == deviceId;

  @override
  int get hashCode => Object.hash(kind, deviceId);

  @override
  String toString() => 'MissingData($kind, $deviceId)';
}

/// Same rule as the web (`missingOnOrder` in firebase/webapp/src/lib/orders/quick-create.ts).
List<MissingData> missingOnOrder({
  required CustomerAggr? customer,
  required List<DeviceAggr> devices,
  required bool canEditCustomers,
  required bool canEditDevices,
}) {
  final list = <MissingData>[];
  if (canEditCustomers &&
      customer?.id != null &&
      (customer!.phone?.trim().isEmpty ?? true)) {
    list.add(const MissingData(MissingKind.phone));
  }
  if (canEditDevices) {
    for (final device in devices) {
      final id = device.id;
      if (id == null) continue;
      final serial = device.serial?.trim() ?? '';
      final name = device.name?.trim() ?? '';
      if (serial.isEmpty) {
        list.add(MissingData(MissingKind.serial, id));
      } else if (name.isEmpty || name == serial) {
        list.add(MissingData(MissingKind.model, id));
      }
    }
  }
  return list;
}
