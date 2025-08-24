// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$DeviceStore on _DeviceStore, Store {
  late final _$deviceListAtom =
      Atom(name: '_DeviceStore.deviceList', context: context);

  @override
  ObservableStream<List<Device>>? get deviceList {
    _$deviceListAtom.reportRead();
    return super.deviceList;
  }

  @override
  set deviceList(ObservableStream<List<Device>>? value) {
    _$deviceListAtom.reportWrite(value, super.deviceList, () {
      super.deviceList = value;
    });
  }

  late final _$saveDeviceAsyncAction =
      AsyncAction('_DeviceStore.saveDevice', context: context);

  @override
  Future saveDevice(Device device) {
    return _$saveDeviceAsyncAction.run(() => super.saveDevice(device));
  }

  late final _$deleteDeviceAsyncAction =
      AsyncAction('_DeviceStore.deleteDevice', context: context);

  @override
  Future deleteDevice(Device device) {
    return _$deleteDeviceAsyncAction.run(() => super.deleteDevice(device));
  }

  late final _$_DeviceStoreActionController =
      ActionController(name: '_DeviceStore', context: context);

  @override
  dynamic retrieveDevices() {
    final _$actionInfo = _$_DeviceStoreActionController.startAction(
        name: '_DeviceStore.retrieveDevices');
    try {
      return super.retrieveDevices();
    } finally {
      _$_DeviceStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
deviceList: ${deviceList}
    ''';
  }
}
