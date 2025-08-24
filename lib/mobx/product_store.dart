import 'dart:async';

import 'package:praticos/models/product.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/repositories/product_repository.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_store.dart';
part 'product_store.g.dart';

class ProductStore = _ProductStore with _$ProductStore;

abstract class _ProductStore with Store {
  final ProductRepository repository = ProductRepository();
  final UserStore userStore = UserStore();

  @observable
  ObservableStream<List<Product>>? productList;

  String? companyId;

  _ProductStore() {
    SharedPreferences.getInstance().then((value) {
      this.companyId = value.getString('companyId');
      retrieveProducts();
    });
  }

  @action
  retrieveProducts() {
    if (this.companyId != null) {
      productList = repository.streamQueryList(
          orderBy: [OrderBy('name')],
          args: [QueryArgs('company.id', this.companyId)]).asObservable();
    } else {
      this.productList = null;
    }
  }

  @action
  saveProduct(Product product) async {
    User? user = await (userStore.getSingleUserById());
    product.createdAt = DateTime.now();
    product.createdBy = user?.toAggr();
    product.company = user?.companies![0].company;
    product.updatedAt = DateTime.now();
    product.updatedBy = user?.toAggr();
    repository.createItem(product);
  }

  @action
  deleteProduct(Product product) async {
    await repository.removeItem(product.id);
  }
}
