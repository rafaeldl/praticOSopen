import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/service.dart';
import 'package:praticos/models/product.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/repositories/v2/service_repository_v2.dart';
import 'package:praticos/repositories/v2/product_repository_v2.dart';
import 'package:praticos/repositories/v2/device_repository_v2.dart';
import 'package:praticos/repositories/v2/customer_repository_v2.dart';

/// Resultado da execução do bootstrap
class BootstrapResult {
  final List<String> createdServices;
  final List<String> createdProducts;
  final List<String> createdDevices;
  final List<String> createdCustomers;
  final List<String> skippedServices;
  final List<String> skippedProducts;
  final List<String> skippedDevices;
  final List<String> skippedCustomers;

  BootstrapResult({
    this.createdServices = const [],
    this.createdProducts = const [],
    this.createdDevices = const [],
    this.createdCustomers = const [],
    this.skippedServices = const [],
    this.skippedProducts = const [],
    this.skippedDevices = const [],
    this.skippedCustomers = const [],
  });

  int get totalCreated =>
      createdServices.length +
      createdProducts.length +
      createdDevices.length +
      createdCustomers.length;

  int get totalSkipped =>
      skippedServices.length +
      skippedProducts.length +
      skippedDevices.length +
      skippedCustomers.length;

  Map<String, dynamic> toJson() => {
        'createdServices': createdServices,
        'createdProducts': createdProducts,
        'createdDevices': createdDevices,
        'createdCustomers': createdCustomers,
        'skippedServices': skippedServices,
        'skippedProducts': skippedProducts,
        'skippedDevices': skippedDevices,
        'skippedCustomers': skippedCustomers,
      };
}

/// Serviço responsável por executar o bootstrap de dados iniciais
/// para uma empresa recém-criada.
class BootstrapService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ServiceRepositoryV2 _serviceRepo = ServiceRepositoryV2();
  final ProductRepositoryV2 _productRepo = ProductRepositoryV2();
  final DeviceRepositoryV2 _deviceRepo = DeviceRepositoryV2();
  final CustomerRepositoryV2 _customerRepo = CustomerRepositoryV2();

  /// Extrai string localizada de um valor que pode ser:
  /// - String simples: retorna diretamente
  /// - Map com traduções: { 'pt-BR': '...', 'en-US': '...' } → extrai locale
  String? _localizedString(dynamic value, String locale) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map) {
      // Tenta locale exato, depois fallback para pt-BR, depois primeiro disponível
      return value[locale] as String? ??
          value['pt-BR'] as String? ??
          (value.values.isNotEmpty ? value.values.first as String? : null);
    }
    return value.toString();
  }

  /// Busca dados de bootstrap do Firestore
  Future<Map<String, dynamic>?> getBootstrapData(
    String segmentId,
    String subspecialtyId,
  ) async {
    try {
      final doc = await _db
          .collection('segments')
          .doc(segmentId)
          .collection('bootstrap')
          .doc(subspecialtyId)
          .get();

      return doc.data();
    } catch (e) {
      return null;
    }
  }

  bool _shouldIncludeForm(List<String> formSubspecialties,
      List<String> selectedSubspecialties) {
    if (formSubspecialties.isEmpty) {
      return true;
    }
    if (selectedSubspecialties.isEmpty) {
      return false;
    }
    return formSubspecialties
        .any((subspecialty) => selectedSubspecialties.contains(subspecialty));
  }

  List<String> _extractStringList(dynamic value) {
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return [];
  }

  Future<void> syncCompanyFormsFromSegment({
    required String companyId,
    required String segmentId,
    required List<String> subspecialties,
    required UserAggr userAggr,
  }) async {
    final segmentSnapshot = await _db
        .collection('segments')
        .doc(segmentId)
        .collection('forms')
        .get();

    if (segmentSnapshot.docs.isEmpty) return;

    final companyFormsRef =
        _db.collection('companies').doc(companyId).collection('forms');
    final existingSnapshot = await companyFormsRef.get();
    final existingIds = existingSnapshot.docs.map((doc) => doc.id).toSet();

    for (final doc in segmentSnapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      final isActive = data['isActive'] != false;
      if (!isActive) continue;

      final formSubspecialties = _extractStringList(data['subspecialties']);
      if (!_shouldIncludeForm(formSubspecialties, subspecialties)) {
        continue;
      }

      final formData = Map<String, dynamic>.from(data)
        ..['updatedAt'] = FieldValue.serverTimestamp()
        ..['updatedBy'] = userAggr.toJson();

      if (!existingIds.contains(doc.id)) {
        formData['createdAt'] = FieldValue.serverTimestamp();
        formData['createdBy'] = userAggr.toJson();
      }

      await companyFormsRef.doc(doc.id).set(formData, SetOptions(merge: true));
    }
  }

  /// Faz merge dos dados de bootstrap de múltiplas subspecialties
  Future<Map<String, dynamic>> _mergeBootstrapData(
    String segmentId,
    List<String> subspecialties,
  ) async {
    final List<Map<String, dynamic>> servicesSet = [];
    final List<Map<String, dynamic>> productsSet = [];
    final List<Map<String, dynamic>> devicesSet = [];
    Map<String, dynamic>? customer;

    final Set<String> seenServiceNames = {};
    final Set<String> seenProductNames = {};

    // Se não tem subspecialties, usa _default
    final keys = subspecialties.isEmpty ? ['_default'] : subspecialties;

    for (final subspecialtyId in keys) {
      final data = await getBootstrapData(segmentId, subspecialtyId);
      if (data == null) continue;

      // Merge services (evita duplicatas por nome)
      final services = (data['services'] as List?) ?? [];
      for (final service in services) {
        final name = _localizedString(service['name'], 'pt-BR');
        if (name != null && !seenServiceNames.contains(name)) {
          seenServiceNames.add(name);
          servicesSet.add(Map<String, dynamic>.from(service));
        }
      }

      // Merge products (evita duplicatas por nome)
      final products = (data['products'] as List?) ?? [];
      for (final product in products) {
        final name = _localizedString(product['name'], 'pt-BR');
        if (name != null && !seenProductNames.contains(name)) {
          seenProductNames.add(name);
          productsSet.add(Map<String, dynamic>.from(product));
        }
      }

      // Merge devices (inclui todos)
      final devices = (data['devices'] as List?) ?? [];
      for (final device in devices) {
        devicesSet.add(Map<String, dynamic>.from(device));
      }

      // Cliente: usa o primeiro encontrado
      if (customer == null && data['customer'] != null) {
        customer = Map<String, dynamic>.from(data['customer']);
      }
    }

    return {
      'services': servicesSet,
      'products': productsSet,
      'devices': devicesSet,
      'customer': customer,
    };
  }

  /// Busca nomes existentes de uma collection
  Future<Set<String>> _getExistingNames(
    String companyId,
    String collection,
  ) async {
    final snapshot = await _db
        .collection('companies')
        .doc(companyId)
        .collection(collection)
        .get();

    return snapshot.docs
        .map((doc) => doc.data()['name'] as String?)
        .whereType<String>()
        .toSet();
  }

  /// Executa o bootstrap para uma empresa
  Future<BootstrapResult> executeBootstrap({
    required String companyId,
    required String segmentId,
    required List<String> subspecialties,
    required UserAggr userAggr,
    String locale = 'pt-BR',
  }) async {
    // Resultado
    final List<String> createdServices = [];
    final List<String> createdProducts = [];
    final List<String> createdDevices = [];
    final List<String> createdCustomers = [];
    final List<String> skippedServices = [];
    final List<String> skippedProducts = [];
    final List<String> skippedDevices = [];
    final List<String> skippedCustomers = [];

    // 1. Fazer merge dos dados de bootstrap
    final mergedData = await _mergeBootstrapData(segmentId, subspecialties);

    // 2. Buscar itens existentes
    final existingServices = await _getExistingNames(companyId, 'services');
    final existingProducts = await _getExistingNames(companyId, 'products');
    final existingDevices = await _getExistingNames(companyId, 'devices');
    final existingCustomers = await _getExistingNames(companyId, 'customers');

    // 3. Criar serviços
    final services = (mergedData['services'] as List?) ?? [];
    for (final serviceData in services) {
      final name = _localizedString(serviceData['name'], locale);
      if (name == null) continue;

      if (existingServices.contains(name)) {
        skippedServices.add(name);
        continue;
      }

      final service = Service()
        ..name = name
        ..value = (serviceData['value'] as num?)?.toDouble()
        ..company = Global.companyAggr
        ..createdAt = DateTime.now()
        ..createdBy = userAggr
        ..updatedAt = DateTime.now()
        ..updatedBy = userAggr;

      await _serviceRepo.createItem(companyId, service);
      createdServices.add(name);
    }

    // 4. Criar produtos
    final products = (mergedData['products'] as List?) ?? [];
    for (final productData in products) {
      final name = _localizedString(productData['name'], locale);
      if (name == null) continue;

      if (existingProducts.contains(name)) {
        skippedProducts.add(name);
        continue;
      }

      final product = Product()
        ..name = name
        ..value = (productData['value'] as num?)?.toDouble()
        ..company = Global.companyAggr
        ..createdAt = DateTime.now()
        ..createdBy = userAggr
        ..updatedAt = DateTime.now()
        ..updatedBy = userAggr;

      await _productRepo.createItem(companyId, product);
      createdProducts.add(name);
    }

    // 5. Criar equipamentos
    final devices = (mergedData['devices'] as List?) ?? [];
    for (final deviceData in devices) {
      final name = _localizedString(deviceData['name'], locale);
      if (name == null) continue;

      if (existingDevices.contains(name)) {
        skippedDevices.add(name);
        continue;
      }

      final device = Device()
        ..name = name
        ..manufacturer = _localizedString(deviceData['manufacturer'], locale)
        ..category = _localizedString(deviceData['category'], locale)
        ..company = Global.companyAggr
        ..createdAt = DateTime.now()
        ..createdBy = userAggr
        ..updatedAt = DateTime.now()
        ..updatedBy = userAggr;

      await _deviceRepo.createItem(companyId, device);
      createdDevices.add(name);
    }

    // 6. Criar cliente de exemplo
    final customerData = mergedData['customer'] as Map<String, dynamic>?;
    if (customerData != null) {
      final customerName = _localizedString(customerData['name'], locale);
      if (customerName != null) {
        // Verifica se já existe cliente de exemplo
        // Checa por "(Exemplo)", "(Example)", "(Ejemplo)"
        final hasExampleCustomer = existingCustomers.any((name) =>
            name.contains('(Exemplo)') ||
            name.contains('(Example)') ||
            name.contains('(Ejemplo)'));

        if (hasExampleCustomer) {
          skippedCustomers.add(customerName);
        } else {
          final customer = Customer()
            ..name = customerName
            ..phone = customerData['phone'] as String?
            ..email = customerData['email'] as String?
            ..address = _localizedString(customerData['address'], locale)
            ..company = Global.companyAggr
            ..createdAt = DateTime.now()
            ..createdBy = userAggr
            ..updatedAt = DateTime.now()
            ..updatedBy = userAggr;

          await _customerRepo.createItem(companyId, customer);
          createdCustomers.add(customerName);
        }
      }
    }

    // 7. Salvar metadata do bootstrap
    final result = BootstrapResult(
      createdServices: createdServices,
      createdProducts: createdProducts,
      createdDevices: createdDevices,
      createdCustomers: createdCustomers,
      skippedServices: skippedServices,
      skippedProducts: skippedProducts,
      skippedDevices: skippedDevices,
      skippedCustomers: skippedCustomers,
    );

    await _saveMetadata(companyId, segmentId, subspecialties, result);

    return result;
  }

  /// Salva metadata do bootstrap executado
  Future<void> _saveMetadata(
    String companyId,
    String segmentId,
    List<String> subspecialties,
    BootstrapResult result,
  ) async {
    await _db
        .collection('companies')
        .doc(companyId)
        .collection('metadata')
        .doc('bootstrap')
        .set({
      'executedAt': FieldValue.serverTimestamp(),
      'userOptedIn': true,
      'segment': segmentId,
      'subspecialties': subspecialties,
      'created': {
        'services': result.createdServices,
        'products': result.createdProducts,
        'devices': result.createdDevices,
        'customers': result.createdCustomers,
      },
      'skipped': {
        'services': result.skippedServices,
        'products': result.skippedProducts,
        'devices': result.skippedDevices,
        'customers': result.skippedCustomers,
      },
    });
  }

  /// Verifica se o bootstrap já foi executado para uma empresa
  Future<bool> wasBootstrapExecuted(String companyId) async {
    final doc = await _db
        .collection('companies')
        .doc(companyId)
        .collection('metadata')
        .doc('bootstrap')
        .get();

    return doc.exists;
  }
}
