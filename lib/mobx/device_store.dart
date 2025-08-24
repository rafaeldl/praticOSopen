import 'dart:async';

import 'package:praticos/global.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/repositories/device_repository.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:mobx/mobx.dart';

import 'user_store.dart';
part 'device_store.g.dart';

class DeviceStore = _DeviceStore with _$DeviceStore;

abstract class _DeviceStore with Store {
  final DeviceRepository repository = DeviceRepository();
  final UserStore userStore = UserStore();

  @observable
  ObservableStream<List<Device>>? deviceList;

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
}
