import 'package:praticos/config/feature_flags.dart';
import 'package:praticos/models/product.dart';
import 'package:praticos/repositories/product_repository.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/repositories/tenant/tenant_product_repository.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/repositories/v2/repository_v2.dart';

/// Repository V2 para Products com suporte a dual-write/dual-read.
class ProductRepositoryV2 extends RepositoryV2<Product?> {
  final ProductRepository _legacy = ProductRepository();
  final TenantProductRepository _tenant = TenantProductRepository();

  @override
  Repository<Product?> get legacyRepo => _legacy;

  @override
  TenantRepository<Product?> get tenantRepo => _tenant;

  // ═══════════════════════════════════════════════════════════════════
  // Product-specific methods
  // ═══════════════════════════════════════════════════════════════════

  /// Stream de todos os products do tenant ordenados por nome.
  Stream<List<Product?>> streamProducts(String companyId) {
    if (FeatureFlags.shouldReadFromNew) {
      final stream = _tenant.streamProducts(companyId);

      if (FeatureFlags.shouldFallbackToLegacy) {
        return stream.handleError((error) {
          print('[ProductRepositoryV2] Fallback streamProducts: $error');
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

  /// Busca products por faixa de preço.
  Future<List<Product?>> getByPriceRange(
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
          print('[ProductRepositoryV2] Fallback getByPriceRange: $e');
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
