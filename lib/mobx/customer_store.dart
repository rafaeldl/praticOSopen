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
  final CustomerRepositoryV2 repository;
  final UserStore userStore;
  final void Function(Customer customer) _onCreated;

  @observable
  ObservableStream<List<Customer?>>? customerList;

  String? companyId;

  /// Completes once [companyId] was read: a store created right before a
  /// save must wait for it, or there is no company to save in.
  late final Future<void> _companyLoaded;

  _CustomerStore({
    CustomerRepositoryV2? repository,
    UserStore? userStore,
    void Function(Customer customer)? onCreated,
  }) : repository = repository ?? CustomerRepositoryV2(),
       userStore = userStore ?? UserStore(),
       _onCreated =
           onCreated ??
           ((customer) => AnalyticsService.instance.logCustomerCreated(
             customerId: customer.id,
           )) {
    _companyLoaded = SharedPreferences.getInstance().then((value) {
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
  Future<void> saveCustomer(Customer customer) async {
    await _companyLoaded;
    if (companyId == null) throw StateError('No company to save the customer');
    User? user = await (userStore.getSingleUserById());
    customer.createdAt = DateTime.now();
    customer.createdBy = user?.toAggr();
    customer.company = user?.companies![0].company;
    customer.updatedAt = DateTime.now();
    customer.updatedBy = user?.toAggr();
    customer.keywords = generateKeywords(customer.name);
    await repository.createItem(companyId!, customer);
    _onCreated(customer);
  }

  @action
  deleteCustomer(Customer customer) async {
    if (companyId == null) return;
    await repository.removeItem(companyId!, customer.id);
  }
}
