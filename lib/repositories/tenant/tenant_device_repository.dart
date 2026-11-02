import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/repositories/repository.dart';

/// Repository para Devices usando subcollections por tenant.
///
/// Path: `/companies/{companyId}/devices/{deviceId}`
class TenantDeviceRepository extends TenantRepository<Device?> {
  static const String collectionName = 'devices';

  TenantDeviceRepository() : super(collectionName);

  @override
  Device fromJson(Map<String, dynamic> data) => Device.fromJson(data);

  @override
  Map<String, dynamic> toJson(Device? device) => device!.toJson();

  // ═══════════════════════════════════════════════════════════════════
  // Device-specific methods
  // ═══════════════════════════════════════════════════════════════════

  /// Stream de todos os devices do tenant ordenados por nome.
  Stream<List<Device?>> streamDevices(String companyId) {
    return streamQueryList(
      companyId,
      orderBy: [OrderBy('name')],
    );
  }

  /// Busca device por número de série.
  Future<Device?> getBySerial(String companyId, String serial) async {
    final devices = await getQueryList(
      companyId,
      args: [QueryArgs('serial', serial)],
      limit: 1,
    );
    return devices.isNotEmpty ? devices.first : null;
  }

  /// Busca devices por categoria.
  Future<List<Device?>> getByCategory(String companyId, String category) {
    return getQueryList(
      companyId,
      args: [QueryArgs('category', category)],
      orderBy: [OrderBy('name')],
    );
  }

  /// Busca devices por fabricante.
  Future<List<Device?>> getByManufacturer(
    String companyId,
    String manufacturer,
  ) {
    return getQueryList(
      companyId,
      args: [QueryArgs('manufacturer', manufacturer)],
      orderBy: [OrderBy('name')],
    );
  }

  /// Devices with a maintenance up to [untilDay] (`YYYY-MM-DD`), soonest
  /// first. Late ones stay until someone changes or removes the date.
  Stream<List<Device?>> streamMaintenanceUntil(
    String companyId,
    String untilDay,
  ) {
    return streamQueryList(
      companyId,
      orderBy: [OrderBy('nextMaintenanceDate')],
      args: [
        QueryArgs(
          'nextMaintenanceDate',
          untilDay,
          oper: 'isLessThanOrEqualTo',
        ),
      ],
    );
  }

  /// Sets ([day], `YYYY-MM-DD`) or removes (null) the next maintenance of
  /// [deviceIds], all or none. Touches only these fields, so it never undoes
  /// an edit made elsewhere, and clears the daily job's "already told" mark.
  /// [customer] stays as it was when null. Offline it resolves only when the
  /// connection is back: do not wait for it on screen.
  Future<void> setNextMaintenance(
    String companyId,
    Iterable<String> deviceIds, {
    required String? day,
    CustomerAggr? customer,
    UserAggr? actor,
  }) {
    final batch = firestore.batch();
    final fields = <String, dynamic>{
      'nextMaintenanceDate': day ?? FieldValue.delete(),
      'nextMaintenanceNoticeFor': FieldValue.delete(),
      if (day == null)
        'nextMaintenanceCustomer': FieldValue.delete()
      else if (customer != null)
        'nextMaintenanceCustomer': {'id': customer.id, 'name': customer.name},
      'updatedAt': DateTime.now().toIso8601String(),
      if (actor != null) 'updatedBy': actor.toJson(),
    };
    for (final id in deviceIds) {
      batch.update(collectionFor(companyId).doc(id), fields);
    }
    return batch.commit();
  }
}
