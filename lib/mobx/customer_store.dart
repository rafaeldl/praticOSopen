import 'dart:async';

import 'package:praticos/models/customer.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/repositories/customer_repository.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_store.dart';
part 'customer_store.g.dart';

class CustomerStore = _CustomerStore with _$CustomerStore;

abstract class _CustomerStore with Store {
  final CustomerRepository repository = CustomerRepository();
  final UserStore userStore = UserStore();

  @observable
  ObservableStream<List<Customer>>? customerList;

  String? companyId;

  _CustomerStore() {
    SharedPreferences.getInstance().then((value) {
      this.companyId = value.getString('companyId');
      retrieveCustomers();
    });
  }

  @action
  retrieveCustomers() {
    customerList = repository.streamQueryList(
        orderBy: [OrderBy('name')],
        args: [QueryArgs('company.id', this.companyId)]).asObservable();
  }

  @action
  retrieveCustomer(String? id) {
    return repository.getSingle(id);
  }

  @action
  saveCustomer(Customer customer) async {
    User? user = await (userStore.getSingleUserById());
    customer.createdAt = DateTime.now();
    customer.createdBy = user?.toAggr();
    customer.company = user?.companies![0].company;
    customer.updatedAt = DateTime.now();
    customer.updatedBy = user?.toAggr();
    await repository.createItem(customer);
  }

  @action
  deleteCustomer(Customer customer) async {
    await repository.removeItem(customer.id);
  }
}
