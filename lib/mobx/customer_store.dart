import 'dart:async';

import 'package:praticos/models/customer.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/repositories/v2/customer_repository_v2.dart';
import 'package:praticos/utils/search_utils.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:praticos/services/analytics_service.dart';
import 'user_store.dart';
part 'customer_store.g.dart';

class CustomerStore = _CustomerStore with _$CustomerStore;

abstract class _CustomerStore with Store {
  final CustomerRepositoryV2 repository = CustomerRepositoryV2();
  final UserStore userStore = UserStore();

  @observable
  ObservableStream<List<Customer?>>? customerList;

  String? companyId;

  _CustomerStore() {
    SharedPreferences.getInstance().then((value) {
      companyId = value.getString('companyId');
      retrieveCustomers();
    });
  }

  @action
  retrieveCustomers() {
    if (companyId == null) return;
    customerList = repository.streamCustomers(companyId!).asObservable();
  }

  @action
  Future<Customer?> retrieveCustomer(String? id) {
    if (companyId == null || id == null) return Future.value(null);
    return repository.getSingle(companyId!, id);
  }

  @action
  saveCustomer(Customer customer) async {
    if (companyId == null) return;
    User? user = await (userStore.getSingleUserById());
    customer.createdAt = DateTime.now();
    customer.createdBy = user?.toAggr();
    customer.company = user?.companies![0].company;
    customer.updatedAt = DateTime.now();
    customer.updatedBy = user?.toAggr();
    customer.keywords = generateKeywords(customer.name);
    await repository.createItem(companyId!, customer);
    AnalyticsService.instance.logCustomerCreated(customerId: customer.id);
  }

  @action
  deleteCustomer(Customer customer) async {
    if (companyId == null) return;
    await repository.removeItem(companyId!, customer.id);
  }
}
