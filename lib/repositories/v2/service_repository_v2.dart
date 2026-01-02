import 'package:praticos/config/feature_flags.dart';
import 'package:praticos/models/service.dart';
import 'package:praticos/repositories/service_repository.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/repositories/tenant/tenant_service_repository.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/repositories/v2/repository_v2.dart';

/// Repository V2 para Services com suporte a dual-write/dual-read.
class ServiceRepositoryV2 extends RepositoryV2<Service?> {
  final ServiceRepository _legacy = ServiceRepository();
  final TenantServiceRepository _tenant = TenantServiceRepository();

  @override
  Repository<Service?> get legacyRepo => _legacy;

  @override
  TenantRepository<Service?> get tenantRepo => _tenant;

  // ═══════════════════════════════════════════════════════════════════
  // Service-specific methods
  // ═══════════════════════════════════════════════════════════════════

  /// Stream de todos os services do tenant ordenados por nome.
  Stream<List<Service?>> streamServices(String companyId) {
    if (FeatureFlags.shouldReadFromNew) {
      final stream = _tenant.streamServices(companyId);

      if (FeatureFlags.shouldFallbackToLegacy) {
        return stream.handleError((error) {
          print('[ServiceRepositoryV2] Fallback streamServices: $error');
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

  /// Busca services por faixa de preço.
  Future<List<Service?>> getByPriceRange(
    String companyId, {
    double? minValue,
    double? maxValue,
  }) async {
    if (FeatureFlags.shouldReadFromNew) {
      try {
        return await _tenant.getByPriceRange(
          companyId,
          minValue: minValue,
          maxValue: maxValue,
        );
      } catch (e) {
        if (FeatureFlags.shouldFallbackToLegacy) {
          print('[ServiceRepositoryV2] Fallback getByPriceRange: $e');
          List<QueryArgs> args = [QueryArgs('company.id', companyId)];

          if (minValue != null) {
            args.add(
              QueryArgs('value', minValue, oper: 'isGreaterThanOrEqualTo'),
            );
          }

          if (maxValue != null) {
            args.add(
              QueryArgs('value', maxValue, oper: 'isLessThanOrEqualTo'),
            );
          }

          return await _legacy.getQueryList(
            args: args,
            orderBy: [OrderBy('value')],
          );
        }
        rethrow;
      }
    }

    List<QueryArgs> args = [QueryArgs('company.id', companyId)];

    if (minValue != null) {
      args.add(QueryArgs('value', minValue, oper: 'isGreaterThanOrEqualTo'));
    }

    if (maxValue != null) {
      args.add(QueryArgs('value', maxValue, oper: 'isLessThanOrEqualTo'));
    }

    return await _legacy.getQueryList(
      args: args,
      orderBy: [OrderBy('value')],
    );
  }
}
