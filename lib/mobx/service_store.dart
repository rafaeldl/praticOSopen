import 'dart:async';

import 'dart:io';

import 'package:praticos/models/service.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/repositories/v2/service_repository_v2.dart';
import 'package:praticos/services/photo_service.dart';
import 'package:praticos/utils/search_utils.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_store.dart';
part 'service_store.g.dart';

class ServiceStore = _ServiceStore with _$ServiceStore;

abstract class _ServiceStore with Store {
  final ServiceRepositoryV2 repository = ServiceRepositoryV2();
  final UserStore userStore = UserStore();
  final PhotoService photoService = PhotoService();

  @observable
  ObservableStream<List<Service?>>? serviceList;

  @observable
  bool isUploading = false;

  String? companyId;

  _ServiceStore() {
    SharedPreferences.getInstance().then((value) {
      companyId = value.getString('companyId');
      retrieveServices();
    });
  }

  @action
  retrieveServices() {
    if (companyId == null) {
      serviceList = null;
      return;
    }
    serviceList = repository.streamServices(companyId!).asObservable();
  }

  @action
  saveService(Service service) async {
    if (companyId == null) return;
    User? user = await userStore.getSingleUserById();
    service.createdAt = DateTime.now();
    service.createdBy = user?.toAggr();
    service.company = user?.companies![0].company;
    service.updatedAt = DateTime.now();
    service.updatedBy = user?.toAggr();
    service.keywords = generateKeywords(service.name);
    await repository.createItem(companyId!, service);
  }

  @action
  deleteService(Service service) async {
    if (companyId == null) return;
    await repository.removeItem(companyId!, service.id);
  }

  @action
  Future<String?> uploadServicePhoto(File file, Service service) async {
    if (companyId == null) return null;

    if (service.id == null) {
      await saveService(service);
    }

    isUploading = true;
    try {
      final String storagePath = 'tenants/$companyId/services/${service.id}/photo.jpg';
      final String? url = await photoService.uploadImage(file: file, storagePath: storagePath);

      if (url != null) {
        service.photo = url;
        await repository.updateItem(companyId!, service);
      }
      return url;
    } finally {
      isUploading = false;
    }
  }
}
