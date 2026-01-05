import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/brand.dart';
import '../models/device_catalog_item.dart';

class DeviceCatalogRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ══════════════════════════════════════════════════════════════
  // BRANDS
  // ══════════════════════════════════════════════════════════════

  CollectionReference _brandsCollection(String companyId) {
    return _db.collection('companies').doc(companyId).collection('brands');
  }

  /// Busca brands por query
  Future<List<Brand>> searchBrands(String companyId, String query) async {
    if (query.isEmpty) return [];

    final q = query.toLowerCase();

    final snap = await _brandsCollection(companyId)
        .orderBy('usageCount', descending: true)
        .get();

    // Filtra no client (não precisa de índice)
    return snap.docs
        .map((d) => Brand.fromJson({...d.data() as Map, 'id': d.id}))
        .where((b) => b.searchKey.contains(q))
        .take(10)
        .toList();
  }

  /// Adiciona ou incrementa uso da brand
  Future<String> addOrIncrementBrand(String companyId, String brandName) async {
    // Busca se já existe
    final existing = await _brandsCollection(companyId)
        .where('name', isEqualTo: brandName)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      // Incrementa contador
      final docRef = existing.docs.first.reference;
      await docRef.update({'usageCount': FieldValue.increment(1)});
      return docRef.id;
    }

    // Cria nova brand
    final docRef = await _brandsCollection(companyId).add({
      'name': brandName,
      'usageCount': 1,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Lista todas as brands (ordenado por uso)
  Stream<List<Brand>> streamAllBrands(String companyId) {
    return _brandsCollection(companyId)
        .orderBy('usageCount', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Brand.fromJson({...d.data() as Map, 'id': d.id}))
            .toList());
  }

  // ══════════════════════════════════════════════════════════════
  // DEVICE CATALOG (MODELS)
  // ══════════════════════════════════════════════════════════════

  CollectionReference _modelsCollection(String companyId) {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('deviceCatalog');
  }

  /// Busca modelos por query (todos ou filtrado por brand)
  Future<List<DeviceCatalogItem>> searchModels(
    String companyId,
    String query, {
    String? brandId,
  }) async {
    if (query.isEmpty) return [];

    final q = query.toLowerCase();

    Query ref = _modelsCollection(companyId)
        .orderBy('usageCount', descending: true);

    if (brandId != null) {
      ref = ref.where('brandId', isEqualTo: brandId);
    }

    final snap = await ref.get();

    // Filtra no client por searchKey
    return snap.docs
        .map((d) =>
            DeviceCatalogItem.fromJson({...d.data() as Map, 'id': d.id}))
        .where((m) => m.searchKey.contains(q))
        .take(20)
        .toList();
  }

  /// Adiciona ou incrementa uso do modelo
  Future<String> addOrIncrementModel(
    String companyId,
    DeviceCatalogItem item,
  ) async {
    // Busca se já existe
    final existing = await _modelsCollection(companyId)
        .where('searchKey', isEqualTo: item.searchKey)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      // Incrementa contador
      final docRef = existing.docs.first.reference;
      await docRef.update({
        'usageCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    }

    // Cria novo modelo
    final docRef = await _modelsCollection(companyId).add(item.toJson());
    return docRef.id;
  }

  /// Lista todos os modelos (ordenado por uso)
  Stream<List<DeviceCatalogItem>> streamAllModels(
    String companyId, {
    String? brandId,
  }) {
    Query ref =
        _modelsCollection(companyId).orderBy('usageCount', descending: true);

    if (brandId != null) {
      ref = ref.where('brandId', isEqualTo: brandId);
    }

    return ref.snapshots().map((snap) => snap.docs
        .map((d) =>
            DeviceCatalogItem.fromJson({...d.data() as Map, 'id': d.id}))
        .toList());
  }

  /// Remove modelo
  Future<void> removeModel(String companyId, String modelId) async {
    await _modelsCollection(companyId).doc(modelId).delete();
  }

  /// Remove brand (e opcionalmente seus modelos)
  Future<void> removeBrand(String companyId, String brandId,
      {bool removeModels = false}) async {
    await _brandsCollection(companyId).doc(brandId).delete();

    if (removeModels) {
      // Remove todos os modelos dessa brand
      final models = await _modelsCollection(companyId)
          .where('brandId', isEqualTo: brandId)
          .get();

      final batch = _db.batch();
      for (final doc in models.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }
}
