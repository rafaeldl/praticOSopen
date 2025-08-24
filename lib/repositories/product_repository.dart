import 'package:praticos/models/product.dart';
import 'package:praticos/repositories/repository.dart';

class ProductRepository extends Repository<Product> {
  static String collectionName = 'products';

  ProductRepository() : super(collectionName);

  @override
  Product fromJson(data) => Product.fromJson(data);

  @override
  Map<String, dynamic> toJson(Product product) => product.toJson();
}
