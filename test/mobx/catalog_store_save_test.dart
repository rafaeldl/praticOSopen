import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/customer_store.dart';
import 'package:praticos/mobx/product_store.dart';
import 'package:praticos/mobx/service_store.dart';
import 'package:praticos/mobx/user_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/product.dart';
import 'package:praticos/models/service.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/repositories/v2/customer_repository_v2.dart';
import 'package:praticos/repositories/v2/product_repository_v2.dart';
import 'package:praticos/repositories/v2/service_repository_v2.dart';
import 'package:praticos/screens/catalog/catalog_source.dart';
import 'package:praticos/services/photo_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Member of two companies; the one being edited is the second.
User _user() => User()
  ..id = 'u2'
  ..name = 'Bia'
  ..companies = [
    CompanyRoleAggr()
      ..company = (CompanyAggr()
        ..id = 'other'
        ..name = 'Outra'),
    CompanyRoleAggr()
      ..company = (CompanyAggr()
        ..id = 'c1'
        ..name = 'Oficina'),
  ];

class _Users implements UserStore {
  @override
  Future<User?> getSingleUserById() async => _user();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Customers implements CustomerRepositoryV2 {
  final saved = <Customer?>[];

  @override
  Stream<List<Customer?>> streamCustomers(String companyId) => Stream.value([]);

  @override
  Future<void> createItem(String companyId, Customer? item, {String? id}) async {
    item?.id ??= 'new-id';
    saved.add(item);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Services implements ServiceRepositoryV2 {
  final created = <Service?>[];
  final updated = <Service?>[];
  final fields = <String, Map<String, dynamic>>{};

  @override
  Future<void> writeFields(
    String companyId,
    String id,
    Map<String, dynamic> fields,
  ) async => this.fields[id] = fields;

  @override
  Stream<List<Service?>> streamServices(String companyId) => Stream.value([]);

  @override
  Future<void> createItem(String companyId, Service? item, {String? id}) async {
    item?.id ??= 'svc-id';
    created.add(item);
  }

  @override
  Future<void> updateItem(String companyId, Service? item) async =>
      updated.add(item);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Products implements ProductRepositoryV2 {
  final created = <Product?>[];
  final updated = <Product?>[];
  final fields = <String, Map<String, dynamic>>{};

  @override
  Future<void> writeFields(
    String companyId,
    String id,
    Map<String, dynamic> fields,
  ) async => this.fields[id] = fields;

  @override
  Stream<List<Product?>> streamProducts(String companyId) => Stream.value([]);

  @override
  Future<void> createItem(String companyId, Product? item, {String? id}) async {
    item?.id ??= 'prd-id';
    created.add(item);
  }

  @override
  Future<void> updateItem(String companyId, Product? item) async =>
      updated.add(item);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Photos implements PhotoService {
  @override
  Future<String?> uploadImage({
    required File file,
    required String storagePath,
  }) async => 'https://x/$storagePath';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final createdAt = DateTime(2025, 3, 1);
  final creator = UserAggr()
    ..id = 'u1'
    ..name = 'Ana';

  setUp(() {
    SharedPreferences.setMockInitialValues({'companyId': 'c1'});
    Global.companyAggr = null;
  });

  test('editing a customer keeps who created it, in the right company, and '
      'logs no new creation', () async {
    final created = <Customer>[];
    final repo = _Customers();
    final store = CustomerStore(
      repository: repo,
      userStore: _Users(),
      onCreated: created.add,
    );
    final customer = Customer()
      ..id = 'cust1'
      ..name = 'Ana'
      ..createdAt = createdAt
      ..createdBy = creator;

    await store.saveCustomer(customer);

    expect(customer.createdAt, createdAt);
    expect(customer.createdBy?.id, 'u1');
    expect(customer.updatedBy?.id, 'u2');
    expect(customer.company?.id, 'c1');
    expect(created, isEmpty);
  });

  test('a new customer is stamped and logged once', () async {
    final created = <Customer>[];
    final store = CustomerStore(
      repository: _Customers(),
      userStore: _Users(),
      onCreated: created.add,
    );
    final customer = Customer()..name = 'Ana';
    await store.saveCustomer(customer);
    expect(customer.createdBy?.id, 'u2');
    expect(customer.company?.id, 'c1');
    expect(created, hasLength(1));
  });

  test('editing a service keeps its creation fields', () async {
    final store = ServiceStore(
      repository: _Services(),
      userStore: _Users(),
      photoService: _Photos(),
    );
    final service = Service()
      ..id = 's1'
      ..name = 'Troca'
      ..createdAt = createdAt
      ..createdBy = creator;
    await store.saveService(service);
    expect(service.createdAt, createdAt);
    expect(service.createdBy?.id, 'u1');
    expect(service.company?.id, 'c1');
  });

  test('a photo on a new service writes nothing before ✓', () async {
    final repo = _Services();
    final store = ServiceStore(
      repository: repo,
      userStore: _Users(),
      photoService: _Photos(),
    )..newId = () => 'draft1';
    final service = Service();

    final url = await store.uploadServicePhoto(File('a.jpg'), service);

    expect(url, contains('services/draft1/photo.jpg'));
    expect(service.photo, url);
    expect(repo.created, isEmpty);
    expect(repo.updated, isEmpty);

    // ✓ creates it with the same id, as new.
    service.name = 'Troca';
    await store.saveService(service);
    expect(repo.created.single?.id, 'draft1');
    expect(service.createdBy?.id, 'u2');

    // A photo on the saved service writes only the photo and updatedAt.
    await store.uploadServicePhoto(File('b.jpg'), service);
    expect(repo.updated, isEmpty);
    expect(
      repo.fields['draft1']!.keys.where((k) => k != 'updatedBy'),
      unorderedEquals(['photo', 'updatedAt']),
    );
  });

  test('editing a saved service writes only what changed', () async {
    final repo = _Services();
    final store = ServiceStore(
      repository: repo,
      userStore: _Users(),
      photoService: _Photos(),
    );
    final service = Service()
      ..id = 's1'
      ..name = 'Troca'
      ..value = 100
      ..createdAt = createdAt
      ..createdBy = creator;
    final previous = service.toJson();
    // Renamed in the app; the price the web raised meanwhile is not touched.
    service.name = 'Troca de óleo';

    await store.saveService(service, previous: previous);

    expect(repo.created, isEmpty);
    final written = repo.fields['s1']!;
    expect(
      written.keys,
      unorderedEquals(['name', 'keywords', 'updatedAt', 'updatedBy']),
    );
    expect(written['name'], 'Troca de óleo');
    expect(written['updatedBy']['id'], 'u2');
  });

  test('the catalog form saves only the name it changed', () async {
    final repo = _Services();
    final source = FirestoreCatalogSource(
      services: ServiceStore(
        repository: repo,
        userStore: _Users(),
        photoService: _Photos(),
      ),
    );
    // As the list read it.
    final read = Service()
      ..id = 's1'
      ..name = 'Troca'
      ..value = 100
      ..createdAt = createdAt
      ..createdBy = creator;
    // The form works on a copy of the row, with the same origin.
    final item = CatalogItem(
      id: 's1',
      name: 'Troca de óleo',
      value: 100,
      origin: read,
    );

    await source.save(CatalogKind.service, item);

    expect(repo.created, isEmpty);
    expect(
      repo.fields['s1']!.keys.where((k) => k != 'updatedBy'),
      unorderedEquals(['name', 'keywords', 'updatedAt']),
    );
    // What was read stays as it was.
    expect(read.name, 'Troca');
  });

  test('saving a saved product without changes writes nothing', () async {
    final repo = _Products();
    final store = ProductStore(
      repository: repo,
      userStore: _Users(),
      photoService: _Photos(),
    );
    final product = Product()
      ..id = 'p1'
      ..name = 'Filtro'
      ..value = 35;

    await store.saveProduct(product, previous: product.toJson());

    expect(repo.created, isEmpty);
    expect(repo.fields, isEmpty);
  });

  test('a price change on a saved product writes the price', () async {
    final repo = _Products();
    final store = ProductStore(
      repository: repo,
      userStore: _Users(),
      photoService: _Photos(),
    );
    final product = Product()
      ..id = 'p1'
      ..name = 'Filtro'
      ..value = 35;
    final previous = product.toJson();
    product.value = 40;

    await store.saveProduct(product, previous: previous);

    expect(
      repo.fields['p1']!.keys.where((k) => k != 'updatedBy'),
      unorderedEquals(['value', 'updatedAt']),
    );
    expect(repo.fields['p1']!['value'], 40);
  });

  test('a photo on a new product writes nothing before ✓', () async {
    final repo = _Products();
    final store = ProductStore(
      repository: repo,
      userStore: _Users(),
      photoService: _Photos(),
    )..newId = () => 'draft2';
    final product = Product();
    await store.uploadProductPhoto(File('a.jpg'), product);
    expect(repo.created, isEmpty);
    expect(repo.updated, isEmpty);
    expect(product.id, 'draft2');
  });
}
