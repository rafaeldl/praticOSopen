import 'dart:async';

import 'package:praticos/mobx/product_store.dart';
import 'package:praticos/mobx/service_store.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/models/product.dart';
import 'package:praticos/models/service.dart';
import 'package:praticos/repositories/v2/product_repository_v2.dart';
import 'package:praticos/repositories/v2/service_repository_v2.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The two things a company sells besides labor.
enum CatalogKind {
  service,
  product;

  PermissionType get viewPermission => this == CatalogKind.service
      ? PermissionType.viewServices
      : PermissionType.viewProducts;

  PermissionType get managePermission => this == CatalogKind.service
      ? PermissionType.manageServices
      : PermissionType.manageProducts;

  /// Route that edits an item in the order flow (`/order_service`, ...).
  String get orderRoute =>
      this == CatalogKind.service ? '/order_service' : '/order_product';

  /// Argument key used by the order screens (`service` / `product`).
  String get argKey => name;
}

/// Kind-agnostic view of a [Service] or [Product]: both have the same fields.
class CatalogItem {
  CatalogItem({
    this.id,
    this.name,
    this.value,
    this.photo,
    this.customData,
    this.origin,
  });

  String? id;
  String? name;

  /// Null means "no price": shown as "sem valor" and not summed.
  double? value;
  String? photo;
  Map<String, dynamic>? customData;

  /// The underlying [Service] or [Product] (kept for the order screens).
  Object? origin;
}

enum PhotoOrigin { camera, gallery }

/// Data access of the catalog, injectable so screens can be tested.
abstract class CatalogSource {
  Stream<List<CatalogItem>> watch(CatalogKind kind);
  Future<void> save(CatalogKind kind, CatalogItem item);
  Future<void> delete(CatalogKind kind, CatalogItem item);

  /// Takes/picks a photo and uploads it; returns the URL (null if cancelled).
  Future<String?> uploadPhoto(
    CatalogKind kind,
    CatalogItem item,
    PhotoOrigin from,
  );
}

/// Permission checks of the catalog, injectable for tests.
class CatalogPermissions {
  const CatalogPermissions(this.has);

  /// Checks against the current user's role.
  CatalogPermissions.current()
      : has = AuthorizationService.instance.hasPermission;

  final bool Function(PermissionType) has;

  bool canView(CatalogKind kind) => has(kind.viewPermission);
  bool canManage(CatalogKind kind) => has(kind.managePermission);
  bool get canViewPrices => has(PermissionType.viewPrices);
}

/// Firestore-backed [CatalogSource] (services and products stores).
class FirestoreCatalogSource implements CatalogSource {
  ServiceStore? _serviceStore;
  ProductStore? _productStore;
  ServiceStore get _services => _serviceStore ??= ServiceStore();
  ProductStore get _products => _productStore ??= ProductStore();

  @override
  Stream<List<CatalogItem>> watch(CatalogKind kind) async* {
    final prefs = await SharedPreferences.getInstance();
    final companyId = prefs.getString('companyId');
    if (companyId == null) {
      yield const [];
      return;
    }
    if (kind == CatalogKind.service) {
      yield* ServiceRepositoryV2().streamServices(companyId).map(
            (list) => [
              for (final s in list.whereType<Service>())
                CatalogItem(
                  id: s.id,
                  name: s.name,
                  value: s.value,
                  photo: s.photo,
                  customData: s.customData,
                  origin: s,
                ),
            ],
          );
    } else {
      yield* ProductRepositoryV2().streamProducts(companyId).map(
            (list) => [
              for (final p in list.whereType<Product>())
                CatalogItem(
                  id: p.id,
                  name: p.name,
                  value: p.value,
                  photo: p.photo,
                  customData: p.customData,
                  origin: p,
                ),
            ],
          );
    }
  }

  Object _entity(CatalogKind kind, CatalogItem item) {
    if (kind == CatalogKind.service) {
      final s = (item.origin as Service?) ?? Service();
      s
        ..name = item.name
        ..value = item.value
        ..photo = item.photo
        ..customData = item.customData;
      return item.origin = s;
    }
    final p = (item.origin as Product?) ?? Product();
    p
      ..name = item.name
      ..value = item.value
      ..photo = item.photo
      ..customData = item.customData;
    return item.origin = p;
  }

  @override
  Future<void> save(CatalogKind kind, CatalogItem item) async {
    final entity = _entity(kind, item);
    if (entity is Service) {
      await _services.saveService(entity);
      item.id = entity.id;
    } else if (entity is Product) {
      await _products.saveProduct(entity);
      item.id = entity.id;
    }
  }

  @override
  Future<void> delete(CatalogKind kind, CatalogItem item) async {
    final entity = _entity(kind, item);
    if (entity is Service) {
      await _services.deleteService(entity);
    } else if (entity is Product) {
      await _products.deleteProduct(entity);
    }
  }

  @override
  Future<String?> uploadPhoto(
    CatalogKind kind,
    CatalogItem item,
    PhotoOrigin from,
  ) async {
    final photos =
        kind == CatalogKind.service ? _services.photoService : _products.photoService;
    final file = from == PhotoOrigin.camera
        ? await photos.takePhoto()
        : await photos.pickImageFromGallery();
    if (file == null) return null;
    final entity = _entity(kind, item);
    String? url;
    if (entity is Service) {
      url = await _services.uploadServicePhoto(file, entity);
      item.id = entity.id;
    } else if (entity is Product) {
      url = await _products.uploadProductPhoto(file, entity);
      item.id = entity.id;
    }
    if (url != null) item.photo = url;
    return url;
  }
}
