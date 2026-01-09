import 'package:praticos/models/product.dart';
import 'package:praticos/repositories/tenant/tenant_product_repository.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/repositories/v2/repository_v2.dart';

/// Repository V2 para Products usando subcollections por tenant.
///
/// Path: `/companies/{companyId}/products/{productId}`
class ProductRepositoryV2 extends RepositoryV2<Product?> {
  final TenantProductRepository _tenant = TenantProductRepository();

  @override
  TenantRepository<Product?> get tenantRepo => _tenant;

  // ═══════════════════════════════════════════════════════════════════
  // Product-specific methods
  // ═══════════════════════════════════════════════════════════════════

  /// Stream de todos os products do tenant ordenados por nome.
  Stream<List<Product?>> streamProducts(String companyId) {
    return _tenant.streamProducts(companyId);
  }

  /// Busca products por faixa de preço.
  Future<List<Product?>> getByPriceRange(
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
