import 'package:praticos/models/service.dart';
import 'package:praticos/repositories/tenant/tenant_service_repository.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/repositories/v2/repository_v2.dart';

/// Repository V2 para Services usando subcollections por tenant.
///
/// Path: `/companies/{companyId}/services/{serviceId}`
class ServiceRepositoryV2 extends RepositoryV2<Service?> {
  final TenantServiceRepository _tenant = TenantServiceRepository();

  @override
  TenantRepository<Service?> get tenantRepo => _tenant;

  // ═══════════════════════════════════════════════════════════════════
  // Service-specific methods
  // ═══════════════════════════════════════════════════════════════════

  /// Stream de todos os services do tenant ordenados por nome.
  Stream<List<Service?>> streamServices(String companyId) {
    return _tenant.streamServices(companyId);
  }

  /// Busca services por faixa de preço.
  Future<List<Service?>> getByPriceRange(
    String companyId, {
    double? minValue,
    double? maxValue,
  }) async {
    return await _tenant.getByPriceRange(
      companyId,
      minValue: minValue,
      maxValue: maxValue,
    );
  }
}
