import 'package:praticos/models/product.dart';
import 'package:praticos/repositories/tenant_repository.dart';

class TenantProductRepository extends TenantRepository<Product> {
  TenantProductRepository() : super('products');

  @override
  Product fromJson(Map<String, dynamic> data) => Product.fromJson(data);

  @override
  Map<String, dynamic> toJson(Product? item) => item!.toJson();
}
