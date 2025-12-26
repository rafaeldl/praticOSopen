import 'dart:async';

import 'dart:io';

import 'package:praticos/global.dart';
import 'package:praticos/models/product.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/repositories/product_repository.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/services/photo_service.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_store.dart';
part 'product_store.g.dart';

class ProductStore = _ProductStore with _$ProductStore;

abstract class _ProductStore with Store {
  final ProductRepository repository = ProductRepository();
  final UserStore userStore = UserStore();
  final PhotoService photoService = PhotoService();

  @observable
  ObservableStream<List<Product>>? productList;

  @observable
  bool isUploading = false;

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

  @action
  Future<String?> uploadProductPhoto(File file, Product product) async {
    if (product.id == null) {
      // Salva o produto primeiro para ter um ID
      await saveProduct(product);
    }

    if (Global.companyAggr?.id == null) return null;

    isUploading = true;
    try {
      final String storagePath = 'tenants/${Global.companyAggr!.id}/products/${product.id}/photo.jpg';
      final String? url = await photoService.uploadImage(file: file, storagePath: storagePath);

      if (url != null) {
        product.photo = url;
        // Atualiza apenas o campo foto se o produto já existir, ou salva tudo
        await repository.updateItem(product);
      }
      return url;
    } finally {
      isUploading = false;
    }
  }
}
