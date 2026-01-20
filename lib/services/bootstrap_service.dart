import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/service.dart';
import 'package:praticos/models/product.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/models/order.dart' as models;
import 'package:praticos/repositories/v2/service_repository_v2.dart';
import 'package:praticos/repositories/v2/product_repository_v2.dart';
import 'package:praticos/repositories/v2/device_repository_v2.dart';
import 'package:praticos/repositories/v2/customer_repository_v2.dart';
import 'package:praticos/repositories/v2/order_repository_v2.dart';
import 'package:praticos/services/forms_service.dart';

/// Resultado da execução do bootstrap
class BootstrapResult {
  final List<String> createdServices;
  final List<String> createdProducts;
  final List<String> createdDevices;
  final List<String> createdCustomers;
  final List<String> createdOrders;
  final List<String> skippedServices;
  final List<String> skippedProducts;
  final List<String> skippedDevices;
  final List<String> skippedCustomers;
  final List<String> skippedOrders;

  BootstrapResult({
    this.createdServices = const [],
    this.createdProducts = const [],
    this.createdDevices = const [],
    this.createdCustomers = const [],
    this.createdOrders = const [],
    this.skippedServices = const [],
    this.skippedProducts = const [],
    this.skippedDevices = const [],
    this.skippedCustomers = const [],
    this.skippedOrders = const [],
  });

  int get totalCreated =>
      createdServices.length +
      createdProducts.length +
      createdDevices.length +
      createdCustomers.length +
      createdOrders.length;

  int get totalSkipped =>
      skippedServices.length +
      skippedProducts.length +
      skippedDevices.length +
      skippedCustomers.length +
      skippedOrders.length;

  Map<String, dynamic> toJson() => {
        'createdServices': createdServices,
        'createdProducts': createdProducts,
        'createdDevices': createdDevices,
        'createdCustomers': createdCustomers,
        'createdOrders': createdOrders,
        'skippedServices': skippedServices,
        'skippedProducts': skippedProducts,
        'skippedDevices': skippedDevices,
        'skippedCustomers': skippedCustomers,
        'skippedOrders': skippedOrders,
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
  final OrderRepositoryV2 _orderRepo = OrderRepositoryV2();
  final FormsService _formsService = FormsService();

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

  /// Maps country code or locale to locale code for i18n
  /// Accepts: BR, PT, pt-BR, pt-PT -> pt
  /// Accepts: US, en-US -> en
  /// Accepts: ES, es-ES -> es
  String _getLocaleFromCountry(String? countryOrLocale) {
    if (countryOrLocale == null) return 'pt';
    final input = countryOrLocale.toUpperCase();

    // Check if it's a locale format (pt-BR, en-US, es-ES)
    if (input.contains('-')) {
      final parts = input.split('-');
      final languageCode = parts[0].toLowerCase();
      if (languageCode == 'pt') return 'pt';
      if (languageCode == 'en') return 'en';
      if (languageCode == 'es') return 'es';
      return 'pt';
    }

    // Otherwise, treat as country code
    if (input == 'BR' || input == 'PT') return 'pt';
    if (input == 'US') return 'en';
    if (input == 'ES') return 'es';
    return 'pt'; // default fallback
  }

  /// Localizes form data based on company locale
  /// Extracts localized strings from i18n fields and removes them
  Map<String, dynamic> _localizeFormData(
    Map<String, dynamic> data,
    String localeCode,
  ) {
    final localized = Map<String, dynamic>.from(data);

    // Localize title
    if (data['titleI18n'] is Map) {
      final titleI18n = data['titleI18n'] as Map;
      localized['title'] = titleI18n[localeCode] ??
                          titleI18n['pt'] ??
                          data['title'];
      localized.remove('titleI18n');
    }

    // Localize description
    if (data['descriptionI18n'] is Map) {
      final descI18n = data['descriptionI18n'] as Map;
      localized['description'] = descI18n[localeCode] ??
                                descI18n['pt'] ??
                                data['description'];
      localized.remove('descriptionI18n');
    }

    // Localize items
    if (data['items'] is List) {
      final items = List<Map<String, dynamic>>.from(
        (data['items'] as List).map((item) => Map<String, dynamic>.from(item)),
      );

      for (var item in items) {
        // Localize item label
        if (item['labelI18n'] is Map) {
          final labelI18n = item['labelI18n'] as Map;
          item['label'] = labelI18n[localeCode] ??
                         labelI18n['pt'] ??
                         item['label'];
          item.remove('labelI18n');
        }

        // Localize item options
        if (item['optionsI18n'] is Map) {
          final optionsI18n = item['optionsI18n'] as Map;
          item['options'] = optionsI18n[localeCode] ??
                           optionsI18n['pt'] ??
                           item['options'];
          item.remove('optionsI18n');
        }
      }

      localized['items'] = items;
    }

    return localized;
  }

  Future<void> syncCompanyFormsFromSegment({
    required String companyId,
    required String segmentId,
    required List<String> subspecialties,
    required UserAggr userAggr,
    String? locale,
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

    // Get locale code from company country or locale
    final localeCode = _getLocaleFromCountry(locale);

    for (final doc in segmentSnapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      final isActive = data['isActive'] != false;
      if (!isActive) continue;

      final formSubspecialties = _extractStringList(data['subspecialties']);
      if (!_shouldIncludeForm(formSubspecialties, subspecialties)) {
        continue;
      }

      // Localize form data based on company locale and remove i18n fields
      final localizedData = _localizeFormData(data, localeCode);

      final formData = Map<String, dynamic>.from(localizedData)
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
    required CompanyAggr companyAggr,
    String locale = 'pt-BR',
  }) async {
    // Resultado
    final List<String> createdServices = [];
    final List<String> createdProducts = [];
    final List<String> createdDevices = [];
    final List<String> createdCustomers = [];
    final List<String> createdOrders = [];
    final List<String> skippedServices = [];
    final List<String> skippedProducts = [];
    final List<String> skippedDevices = [];
    final List<String> skippedCustomers = [];
    final List<String> skippedOrders = [];

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
        ..company = companyAggr
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
        ..company = companyAggr
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
        ..company = companyAggr
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
            ..company = companyAggr
            ..createdAt = DateTime.now()
            ..createdBy = userAggr
            ..updatedAt = DateTime.now()
            ..updatedBy = userAggr;

          await _customerRepo.createItem(companyId, customer);
          createdCustomers.add(customerName);
        }
      }
    }

    // 7. Criar OSs de exemplo (usando customers, devices e services criados)
    // Verificar se já existem OSs criadas para evitar duplicação
    final existingOrders = await _orderRepo.getQueryList(
      companyId,
      limit: 1,
    );

    if (existingOrders.isEmpty) {
      // Primeira vez executando o bootstrap, criar OSs demo
      final orderResults = await _createSampleOrders(
        companyId: companyId,
        locale: locale,
        userAggr: userAggr,
        companyAggr: companyAggr,
      );
      createdOrders.addAll(orderResults['created'] as List<String>);
      skippedOrders.addAll(orderResults['skipped'] as List<String>);
    } else {
      // Bootstrap já foi executado antes, não criar OSs duplicadas
      skippedOrders.add('Orders already exist, skipping demo orders creation');
      print('⏭️ Skipping demo orders creation - company already has orders');
    }

    // 8. Salvar metadata do bootstrap
    final result = BootstrapResult(
      createdServices: createdServices,
      createdProducts: createdProducts,
      createdDevices: createdDevices,
      createdCustomers: createdCustomers,
      createdOrders: createdOrders,
      skippedServices: skippedServices,
      skippedProducts: skippedProducts,
      skippedDevices: skippedDevices,
      skippedCustomers: skippedCustomers,
      skippedOrders: skippedOrders,
    );

    await _saveMetadata(companyId, segmentId, subspecialties, result);

    return result;
  }

  /// Salva metadata do bootstrap executado
  /// Tenta salvar a metadata, mas não falha o bootstrap se houver erro de permissão
  Future<void> _saveMetadata(
    String companyId,
    String segmentId,
    List<String> subspecialties,
    BootstrapResult result,
  ) async {
    try {
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
          'orders': result.createdOrders,
        },
        'skipped': {
          'services': result.skippedServices,
          'products': result.skippedProducts,
          'devices': result.skippedDevices,
          'customers': result.skippedCustomers,
          'orders': result.skippedOrders,
        },
      });
    } catch (e) {
      // Não falha o bootstrap se houver erro ao salvar metadata
      // Isso pode acontecer se as claims ainda não foram propagadas
      print('⚠️ Could not save bootstrap metadata: $e');
    }
  }

  /// Cria OSs de exemplo com dados localizados
  Future<Map<String, List<String>>> _createSampleOrders({
    required String companyId,
    required String locale,
    required UserAggr userAggr,
    required CompanyAggr companyAggr,
  }) async {
    final List<String> created = [];
    final List<String> skipped = [];

    try {
      // Buscar customers, devices e services criados (limit 10 para evitar sobrecarga)
      final customers = await _customerRepo.getQueryList(companyId, limit: 10);
      final devices = await _deviceRepo.getQueryList(companyId, limit: 10);
      final services = await _serviceRepo.getQueryList(companyId, limit: 10);

      // Filtrar nulls
      final validCustomers = customers.where((c) => c != null).cast<Customer>().toList();
      final validDevices = devices.where((d) => d != null).cast<Device>().toList();
      final validServices = services.where((s) => s != null).cast<Service>().toList();

      // Se não houver dados suficientes, pular criação
      if (validCustomers.isEmpty || validDevices.isEmpty || validServices.isEmpty) {
        skipped.add('Insufficient data to create orders');
        return {'created': created, 'skipped': skipped};
      }

      // Criar 4 OSs com diferentes status
      for (int i = 0; i < 4; i++) {
        final customer = validCustomers[i % validCustomers.length];
        final device = validDevices[i % validDevices.length];
        final service = validServices[i % validServices.length];

        // Definir status baseado no índice
        final status = _getOrderStatus(i);
        final dueDate = DateTime.now().subtract(Duration(days: 10 - (i * 2)));

        // Criar OrderService (usa o nome do serviço que já foi criado pelo bootstrap do segmento)
        final orderService = models.OrderService()
          ..service = service.toAggr()
          ..value = service.value;

        final order = models.Order()
          ..customer = customer.toAggr()
          ..device = device.toAggr()
          ..services = [orderService]
          ..status = status
          ..dueDate = dueDate
          ..total = service.value ?? 0
          ..company = companyAggr
          ..createdAt = DateTime.now().subtract(Duration(days: 11 - (i * 2)))
          ..createdBy = userAggr
          ..updatedAt = DateTime.now().subtract(Duration(days: 10 - (i * 2)))
          ..updatedBy = userAggr;

        await _orderRepo.createItem(companyId, order);
        created.add('OS #${i + 1} - ${customer.name} - $status');

        // Add a form to the first order (for screenshots)
        if (i == 0 && order.id != null) {
          try {
            final templates = await _formsService.getCompanyTemplates(companyId);
            if (templates.isNotEmpty) {
              await _formsService.addFormToOrder(
                companyId,
                order.id!,
                templates.first,
              );
              print('✅ Added form "${templates.first.title}" to order #1');
            }
          } catch (e) {
            print('⚠️ Could not add form to order: $e');
          }
        }
      }
    } catch (e) {
      print('Error creating sample orders: $e');
      skipped.add('Error: $e');
    }

    return {'created': created, 'skipped': skipped};
  }

  /// Retorna status da OS baseado no índice
  String _getOrderStatus(int index) {
    switch (index) {
      case 0:
        return 'quote'; // Orçamento - aguardando aprovação do cliente
      case 1:
        return 'approved'; // Aprovado - aprovado mas ainda não iniciado
      case 2:
        return 'progress'; // Em Andamento - técnico trabalhando
      case 3:
        return 'done'; // Concluído - finalizado
      default:
        return 'quote';
    }
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
