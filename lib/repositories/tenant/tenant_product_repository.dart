import 'package:praticos/models/product.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/repositories/repository.dart';

/// Repository para Products usando subcollections por tenant.
///
/// Path: `/companies/{companyId}/products/{productId}`
class TenantProductRepository extends TenantRepository<Product?> {
  static const String collectionName = 'products';

  TenantProductRepository() : super(collectionName);

  @override
  Product fromJson(Map<String, dynamic> data) => Product.fromJson(data);

  @override
  Map<String, dynamic> toJson(Product? product) => product!.toJson();

  // ═══════════════════════════════════════════════════════════════════
  // Product-specific methods
  // ═══════════════════════════════════════════════════════════════════

  /// Stream de todos os products do tenant ordenados por nome.
  Stream<List<Product?>> streamProducts(String companyId) {
    return streamQueryList(
      companyId,
      orderBy: [OrderBy('name')],
    );
  }

  /// Busca products por faixa de preço.
  Future<List<Product?>> getByPriceRange(
    String companyId, {
    double? minValue,
    double? maxValue,
  }) async {
    List<QueryArgs> args = [];

    if (minValue != null) {
      args.add(QueryArgs('value', minValue, oper: 'isGreaterThanOrEqualTo'));
    }

    if (maxValue != null) {
      args.add(QueryArgs('value', maxValue, oper: 'isLessThanOrEqualTo'));
    }

    return getQueryList(
      companyId,
      args: args,
      orderBy: [OrderBy('value')],
    );
  }
}
