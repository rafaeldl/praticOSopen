import 'dart:async';

import 'dart:io';

import 'package:praticos/models/product.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/repositories/v2/product_repository_v2.dart';
import 'package:praticos/services/photo_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:praticos/utils/audit_stamp.dart';
import 'package:praticos/utils/search_utils.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_store.dart';
part 'product_store.g.dart';

class ProductStore = _ProductStore with _$ProductStore;

abstract class _ProductStore with Store {
  final ProductRepositoryV2 repository;
  final UserStore userStore;
  final PhotoService photoService;

  @observable
  ObservableStream<List<Product?>>? productList;

  @observable
  bool isUploading = false;

  String? companyId;

  /// Completes once [companyId] was read: a store created right before a
  /// write must wait for it, or there is no company to write in.
  late final Future<void> _companyLoaded;

  _ProductStore({
    ProductRepositoryV2? repository,
    UserStore? userStore,
    PhotoService? photoService,
  }) : repository = repository ?? ProductRepositoryV2(),
       userStore = userStore ?? UserStore(),
       photoService = photoService ?? PhotoService() {
    _companyLoaded = SharedPreferences.getInstance().then((value) {
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
    await _companyLoaded;
    if (companyId == null) return;
    User? user = await (userStore.getSingleUserById());
    final isNew = product.id == null || _draftIds.contains(product.id);
    stampAudit(product, isNew: isNew, user: user, companyId: companyId!);
    product.keywords = generateKeywords(product.name);
    await repository.createItem(companyId!, product);
    _draftIds.remove(product.id);
  }

  /// Ids given to products not saved yet (a photo taken before the ✓).
  final Set<String> _draftIds = {};

  /// New document id, without writing anything. Replaceable in tests.
  @visibleForTesting
  String Function() newId = () =>
      FirebaseFirestore.instance.collection('tmp').doc().id;

  @action
  deleteProduct(Product product) async {
    await _companyLoaded;
    if (companyId == null) return;
    await repository.removeItem(companyId!, product.id);
  }

  @action
  Future<String?> uploadProductPhoto(File file, Product product) async {
    await _companyLoaded;
    if (companyId == null) return null;

    // A new product gets its id now but is written only on ✓: cancelling
    // leaves no nameless product behind.
    if (product.id == null) {
      product.id = newId();
      _draftIds.add(product.id!);
    }

    isUploading = true;
    try {
      final String storagePath = 'tenants/$companyId/products/${product.id}/photo.jpg';
      final String? url = await photoService.uploadImage(file: file, storagePath: storagePath);

      if (url != null) {
        product.photo = url;
        if (!_draftIds.contains(product.id)) {
          await repository.updateItem(companyId!, product);
        }
      }
      return url;
    } finally {
      isUploading = false;
    }
  }
}
