import 'dart:async';
import 'dart:io';

import 'package:praticos/global.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/repositories/device_repository.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/services/photo_service.dart';
import 'package:mobx/mobx.dart';

import 'user_store.dart';
part 'device_store.g.dart';

class DeviceStore = _DeviceStore with _$DeviceStore;

abstract class _DeviceStore with Store {
  final DeviceRepository repository = DeviceRepository();
  final UserStore userStore = UserStore();
  final PhotoService photoService = PhotoService();

  @observable
  ObservableStream<List<Device>>? deviceList;

  @observable
  bool isUploading = false;

  @action
  retrieveDevices() {
    deviceList = repository.streamQueryList(
        orderBy: [OrderBy('name')],
        args: [QueryArgs('company.id', Global.companyAggr!.id)]).asObservable();
  }

  @action
  saveDevice(Device device) async {
    User? user = await (userStore.getSingleUserById());
    device.createdAt = DateTime.now();
    device.createdBy = user?.toAggr();
    device.company = Global.companyAggr;
    device.updatedAt = DateTime.now();
    device.updatedBy = user?.toAggr();
    await repository.createItem(device);
  }

  @action
  deleteDevice(Device device) async {
    await repository.removeItem(device.id);
  }

  @action
  Future<String?> uploadDevicePhoto(File file, Device device) async {
    if (device.id == null) {
      await saveDevice(device);
    }

    if (Global.companyAggr?.id == null) return null;

    isUploading = true;
    try {
      final String storagePath = 'tenants/${Global.companyAggr!.id}/devices/${device.id}/photo.jpg';
      final String? url = await photoService.uploadImage(file: file, storagePath: storagePath);

      if (url != null) {
        device.photo = url;
        await repository.updateItem(device);
      }
      return url;
    } finally {
      isUploading = false;
    }
  }
}
