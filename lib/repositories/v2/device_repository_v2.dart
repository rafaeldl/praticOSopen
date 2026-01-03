import 'package:praticos/config/feature_flags.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/repositories/device_repository.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/repositories/tenant/tenant_device_repository.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/repositories/v2/repository_v2.dart';

/// Repository V2 para Devices com suporte a dual-write/dual-read.
class DeviceRepositoryV2 extends RepositoryV2<Device?> {
  final DeviceRepository _legacy = DeviceRepository();
  final TenantDeviceRepository _tenant = TenantDeviceRepository();

  @override
  Repository<Device?> get legacyRepo => _legacy;

  @override
  TenantRepository<Device?> get tenantRepo => _tenant;

  // ═══════════════════════════════════════════════════════════════════
  // Device-specific methods
  // ═══════════════════════════════════════════════════════════════════

  /// Stream de todos os devices do tenant ordenados por nome.
  Stream<List<Device?>> streamDevices(String companyId) {
    if (FeatureFlags.shouldReadFromNew) {
      final stream = _tenant.streamDevices(companyId);

      if (FeatureFlags.shouldFallbackToLegacy) {
        return stream.handleError((error) {
          print('[DeviceRepositoryV2] Fallback streamDevices: $error');
          return _legacy.streamQueryList(
            orderBy: [OrderBy('name')],
            args: [QueryArgs('company.id', companyId)],
          );
        });
      }

      return stream;
    }

    return _legacy.streamQueryList(
      orderBy: [OrderBy('name')],
      args: [QueryArgs('company.id', companyId)],
    );
  }

  /// Busca device por número de série.
  Future<Device?> getBySerial(String companyId, String serial) async {
    if (FeatureFlags.shouldReadFromNew) {
      try {
        return await _tenant.getBySerial(companyId, serial);
      } catch (e) {
        if (FeatureFlags.shouldFallbackToLegacy) {
          print('[DeviceRepositoryV2] Fallback getBySerial: $e');
          final devices = await _legacy.getQueryList(
            args: [
              QueryArgs('company.id', companyId),
              QueryArgs('serial', serial),
            ],
            limit: 1,
          );
          return devices.isNotEmpty ? devices.first : null;
        }
        rethrow;
      }
    }

    final devices = await _legacy.getQueryList(
      args: [
        QueryArgs('company.id', companyId),
        QueryArgs('serial', serial),
      ],
      limit: 1,
    );
    return devices.isNotEmpty ? devices.first : null;
  }

  /// Busca devices por categoria.
  Future<List<Device?>> getByCategory(String companyId, String category) async {
    if (FeatureFlags.shouldReadFromNew) {
      try {
        return await _tenant.getByCategory(companyId, category);
      } catch (e) {
        if (FeatureFlags.shouldFallbackToLegacy) {
          print('[DeviceRepositoryV2] Fallback getByCategory: $e');
          return await _legacy.getQueryList(
            args: [
              QueryArgs('company.id', companyId),
              QueryArgs('category', category),
            ],
            orderBy: [OrderBy('name')],
          );
        }
        rethrow;
      }
    }

    return await _legacy.getQueryList(
      args: [
        QueryArgs('company.id', companyId),
        QueryArgs('category', category),
      ],
      orderBy: [OrderBy('name')],
    );
  }

  /// Busca devices por fabricante.
  Future<List<Device?>> getByManufacturer(
    String companyId,
    String manufacturer,
  ) async {
    if (FeatureFlags.shouldReadFromNew) {
      try {
        return await _tenant.getByManufacturer(companyId, manufacturer);
      } catch (e) {
        if (FeatureFlags.shouldFallbackToLegacy) {
          print('[DeviceRepositoryV2] Fallback getByManufacturer: $e');
          return await _legacy.getQueryList(
            args: [
              QueryArgs('company.id', companyId),
              QueryArgs('manufacturer', manufacturer),
            ],
            orderBy: [OrderBy('name')],
          );
        }
        rethrow;
      }
    }

    return await _legacy.getQueryList(
      args: [
        QueryArgs('company.id', companyId),
        QueryArgs('manufacturer', manufacturer),
      ],
      orderBy: [OrderBy('name')],
    );
  }
}
