import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/mobx/customer_store.dart';
import 'package:praticos/mobx/user_store.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/repositories/v2/customer_repository_v2.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRepository implements CustomerRepositoryV2 {
  final saved = <String, Customer?>{};

  @override
  Stream<List<Customer?>> streamCustomers(String companyId) => Stream.value([]);

  @override
  Future<void> createItem(String companyId, Customer? item, {String? id}) async {
    item?.id = 'new-id';
    saved[companyId] = item;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserStore implements UserStore {
  @override
  Future<User?> getSingleUserById() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('a store created right before saving still saves the customer', () async {
    SharedPreferences.setMockInitialValues({'companyId': 'c1'});
    final repository = _FakeRepository();
    final store = CustomerStore(
      repository: repository,
      userStore: _FakeUserStore(),
      onCreated: (_) {},
    );
    final customer = Customer()..name = 'Ana';

    // No await between creating the store and saving, as the form does.
    await store.saveCustomer(customer);

    expect(repository.saved['c1'], same(customer));
    expect(customer.id, 'new-id');
  });

  test('without a company it fails instead of pretending it saved', () async {
    SharedPreferences.setMockInitialValues({});
    final store = CustomerStore(
      repository: _FakeRepository(),
      userStore: _FakeUserStore(),
      onCreated: (_) {},
    );

    await expectLater(
      store.saveCustomer(Customer()..name = 'Ana'),
      throwsStateError,
    );
  });
}
