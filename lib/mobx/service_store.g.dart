// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ServiceStore on _ServiceStore, Store {
  late final _$serviceListAtom = Atom(
    name: '_ServiceStore.serviceList',
    context: context,
  );

  @override
  ObservableStream<List<Service>>? get serviceList {
    _$serviceListAtom.reportRead();
    return super.serviceList;
  }

  @override
  set serviceList(ObservableStream<List<Service>>? value) {
    _$serviceListAtom.reportWrite(value, super.serviceList, () {
      super.serviceList = value;
    });
  }

  late final _$isUploadingAtom = Atom(
    name: '_ServiceStore.isUploading',
    context: context,
  );

  @override
  bool get isUploading {
    _$isUploadingAtom.reportRead();
    return super.isUploading;
  }

  @override
  set isUploading(bool value) {
    _$isUploadingAtom.reportWrite(value, super.isUploading, () {
      super.isUploading = value;
    });
  }

  late final _$saveServiceAsyncAction = AsyncAction(
    '_ServiceStore.saveService',
    context: context,
  );

  @override
  Future saveService(Service service) {
    return _$saveServiceAsyncAction.run(() => super.saveService(service));
  }

  late final _$deleteServiceAsyncAction = AsyncAction(
    '_ServiceStore.deleteService',
    context: context,
  );

  @override
  Future deleteService(Service service) {
    return _$deleteServiceAsyncAction.run(() => super.deleteService(service));
  }

  late final _$uploadServicePhotoAsyncAction = AsyncAction(
    '_ServiceStore.uploadServicePhoto',
    context: context,
  );

  @override
  Future<String?> uploadServicePhoto(File file, Service service) {
    return _$uploadServicePhotoAsyncAction.run(
        () => super.uploadServicePhoto(file, service));
  }

  late final _$_ServiceStoreActionController = ActionController(
    name: '_ServiceStore',
    context: context,
  );

  @override
  dynamic retrieveServices() {
    final _$actionInfo = _$_ServiceStoreActionController.startAction(
      name: '_ServiceStore.retrieveServices',
    );
    try {
      return super.retrieveServices();
    } finally {
      _$_ServiceStoreActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
serviceList: ${serviceList},
isUploading: ${isUploading}
    ''';
  }
}
