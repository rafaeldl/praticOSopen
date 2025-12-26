import 'dart:async';

import 'dart:io';

import 'package:praticos/global.dart';
import 'package:praticos/models/service.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/repositories/service_repository.dart';
import 'package:praticos/services/photo_service.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_store.dart';
part 'service_store.g.dart';

class ServiceStore = _ServiceStore with _$ServiceStore;

abstract class _ServiceStore with Store {
  final ServiceRepository repository = ServiceRepository();
  final UserStore userStore = UserStore();
  final PhotoService photoService = PhotoService();

  @observable
  ObservableStream<List<Service>>? serviceList;

  @observable
  bool isUploading = false;

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

  @action
  Future<String?> uploadServicePhoto(File file, Service service) async {
    if (service.id == null) {
      await saveService(service);
    }

    if (Global.companyAggr?.id == null) return null;

    isUploading = true;
    try {
      final String storagePath = 'tenants/${Global.companyAggr!.id}/services/${service.id}/photo.jpg';
      final String? url = await photoService.uploadImage(file: file, storagePath: storagePath);

      if (url != null) {
        service.photo = url;
        await repository.updateItem(service);
      }
      return url;
    } finally {
      isUploading = false;
    }
  }
}
