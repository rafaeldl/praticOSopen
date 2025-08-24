import 'dart:async';

import 'package:praticos/models/service.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/repositories/service_repository.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_store.dart';
part 'service_store.g.dart';

class ServiceStore = _ServiceStore with _$ServiceStore;

abstract class _ServiceStore with Store {
  final ServiceRepository repository = ServiceRepository();
  final UserStore userStore = UserStore();

  @observable
  ObservableStream<List<Service>>? serviceList;

  String? companyId;

  _ServiceStore() {
    SharedPreferences.getInstance().then((value) {
      this.companyId = value.getString('companyId');
      retrieveServices();
    });
  }

  @action
  retrieveServices() {
    if (this.companyId != null) {
      serviceList = repository.streamQueryList(
          orderBy: [OrderBy('name')],
          args: [QueryArgs('company.id', this.companyId)]).asObservable();
    } else {
      this.serviceList = null;
    }
  }

  @action
  saveService(Service service) async {
    User? user = await userStore.getSingleUserById();
    service.createdAt = DateTime.now();
    service.createdBy = user?.toAggr();
    service.company = user?.companies![0].company;
    service.updatedAt = DateTime.now();
    service.updatedBy = user?.toAggr();
    repository.createItem(service);
  }

  @action
  deleteService(Service service) async {
    await repository.removeItem(service.id);
  }
}
