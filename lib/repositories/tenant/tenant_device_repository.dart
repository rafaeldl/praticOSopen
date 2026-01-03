import 'package:praticos/models/device.dart';
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
}
