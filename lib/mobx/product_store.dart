import 'dart:async';

import 'dart:io';

import 'package:praticos/models/product.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/repositories/v2/product_repository_v2.dart';
import 'package:praticos/services/photo_service.dart';
import 'package:praticos/utils/search_utils.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_store.dart';
part 'product_store.g.dart';

class ProductStore = _ProductStore with _$ProductStore;

abstract class _ProductStore with Store {
  final ProductRepositoryV2 repository = ProductRepositoryV2();
  final UserStore userStore = UserStore();
  final PhotoService photoService = PhotoService();

  @observable
  ObservableStream<List<Product?>>? productList;

  @observable
  bool isUploading = false;

  String? companyId;

  _ProductStore() {
    SharedPreferences.getInstance().then((value) {
      companyId = value.getString('companyId');
      retrieveProducts();
    });
  }

  @action
  retrieveProducts() {
    if (companyId == null) {
      productList = null;
      return;
    }
    productList = repository.streamProducts(companyId!).asObservable();
  }

  @action
  saveProduct(Product product) async {
    if (companyId == null) return;
    User? user = await (userStore.getSingleUserById());
    product.createdAt = DateTime.now();
    product.createdBy = user?.toAggr();
    product.company = user?.companies![0].company;
    product.updatedAt = DateTime.now();
    product.updatedBy = user?.toAggr();
    product.keywords = generateKeywords(product.name);
    await repository.createItem(companyId!, product);
  }

  @action
  deleteProduct(Product product) async {
    if (companyId == null) return;
    await repository.removeItem(companyId!, product.id);
  }

  @action
  Future<String?> uploadProductPhoto(File file, Product product) async {
    if (companyId == null) return null;

    if (product.id == null) {
      await saveProduct(product);
    }

    isUploading = true;
    try {
      final String storagePath = 'tenants/$companyId/products/${product.id}/photo.jpg';
      final String? url = await photoService.uploadImage(file: file, storagePath: storagePath);

      if (url != null) {
        product.photo = url;
        await repository.updateItem(companyId!, product);
      }
      return url;
    } finally {
      isUploading = false;
    }
  }
}
