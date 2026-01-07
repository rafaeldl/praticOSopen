import 'package:praticos/models/device.dart';
import 'package:praticos/repositories/tenant/tenant_device_repository.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/repositories/v2/repository_v2.dart';

/// Repository V2 para Devices usando subcollections por tenant.
///
/// Path: `/companies/{companyId}/devices/{deviceId}`
class DeviceRepositoryV2 extends RepositoryV2<Device?> {
  final TenantDeviceRepository _tenant = TenantDeviceRepository();

  @override
  TenantRepository<Device?> get tenantRepo => _tenant;

  // ═══════════════════════════════════════════════════════════════════
  // Device-specific methods
  // ═══════════════════════════════════════════════════════════════════

  /// Stream de todos os devices do tenant ordenados por nome.
  Stream<List<Device?>> streamDevices(String companyId) {
    return _tenant.streamDevices(companyId);
  }

  /// Busca device por número de série.
  Future<Device?> getBySerial(String companyId, String serial) async {
    return await _tenant.getBySerial(companyId, serial);
  }

  /// Busca devices por categoria.
  Future<List<Device?>> getByCategory(String companyId, String category) async {
    return await _tenant.getByCategory(companyId, category);
  }

  /// Busca devices por fabricante.
  Future<List<Device?>> getByManufacturer(
    String companyId,
    String manufacturer,
  ) async {
    return await _tenant.getByManufacturer(companyId, manufacturer);
  }
}
