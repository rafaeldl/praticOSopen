import 'dart:async';
import 'dart:io';

import 'package:praticos/global.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/repositories/v2/device_repository_v2.dart';
import 'package:praticos/services/photo_service.dart';
import 'package:praticos/utils/search_utils.dart';
import 'package:mobx/mobx.dart';

import 'user_store.dart';
part 'device_store.g.dart';

class DeviceStore = _DeviceStore with _$DeviceStore;

abstract class _DeviceStore with Store {
  final DeviceRepositoryV2 repository = DeviceRepositoryV2();
  final UserStore userStore = UserStore();
  final PhotoService photoService = PhotoService();

  @observable
  ObservableStream<List<Device?>>? deviceList;

  @observable
  bool isUploading = false;

  String? get companyId => Global.companyAggr?.id;

  @action
  retrieveDevices() {
    if (companyId == null) return;
    deviceList = repository.streamDevices(companyId!).asObservable();
  }

  @action
  saveDevice(Device device) async {
    if (companyId == null) return;
    User? user = await (userStore.getSingleUserById());
    device.createdAt = DateTime.now();
    device.createdBy = user?.toAggr();
    device.company = Global.companyAggr;
    device.updatedAt = DateTime.now();
    device.updatedBy = user?.toAggr();
    device.keywords = generateKeywords(device.name);
    await repository.createItem(companyId!, device);
  }

  @action
  deleteDevice(Device device) async {
    if (companyId == null) return;
    await repository.removeItem(companyId!, device.id);
  }

  @action
  Future<String?> uploadDevicePhoto(File file, Device device) async {
    if (companyId == null) return null;

    if (device.id == null) {
      await saveDevice(device);
    }

    isUploading = true;
    try {
      final String storagePath = 'tenants/$companyId/devices/${device.id}/photo.jpg';
      final String? url = await photoService.uploadImage(file: file, storagePath: storagePath);

      if (url != null) {
        device.photo = url;
        await repository.updateItem(companyId!, device);
      }
      return url;
    } finally {
      isUploading = false;
    }
  }
}
