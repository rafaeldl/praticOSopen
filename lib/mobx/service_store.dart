import 'dart:async';

import 'dart:io';

import 'package:praticos/models/service.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/repositories/v2/service_repository_v2.dart';
import 'package:praticos/services/photo_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:praticos/utils/audit_stamp.dart';
import 'package:praticos/utils/field_diff.dart';
import 'package:praticos/utils/search_utils.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_store.dart';
part 'service_store.g.dart';

class ServiceStore = _ServiceStore with _$ServiceStore;

abstract class _ServiceStore with Store {
  final ServiceRepositoryV2 repository;
  final UserStore userStore;
  final PhotoService photoService;

  @observable
  ObservableStream<List<Service?>>? serviceList;

  @observable
  bool isUploading = false;

  String? companyId;

  /// Completes once [companyId] was read: a store created right before a
  /// write must wait for it, or there is no company to write in.
  late final Future<void> _companyLoaded;

  _ServiceStore({
    ServiceRepositoryV2? repository,
    UserStore? userStore,
    PhotoService? photoService,
  }) : repository = repository ?? ServiceRepositoryV2(),
       userStore = userStore ?? UserStore(),
       photoService = photoService ?? PhotoService() {
    _companyLoaded = SharedPreferences.getInstance().then((value) {
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

  /// Saves [service]. An edit of a saved one with [previous] (the service
  /// as it was read) writes only the fields that changed: a price the web
  /// changed meanwhile is not put back. Nothing changed, nothing written.
  @action
  saveService(Service service, {Map<String, dynamic>? previous}) async {
    await _companyLoaded;
    if (companyId == null) return;
    User? user = await userStore.getSingleUserById();
    final isNew = service.id == null || _draftIds.contains(service.id);
    stampAudit(service, isNew: isNew, user: user, companyId: companyId!);
    service.keywords = generateKeywords(service.name);
    if (!isNew && previous != null) {
      final fields = catalogChangedFields(previous, service.toJson());
      if (fields.isEmpty) return;
      final json = service.toJson();
      await repository.writeFields(companyId!, service.id!, {
        ...fields,
        'updatedAt': json['updatedAt'],
        if (json['updatedBy'] != null) 'updatedBy': json['updatedBy'],
      });
      return;
    }
    await repository.createItem(companyId!, service);
    _draftIds.remove(service.id);
  }

  /// Writes only the price of the service [id] (with updatedAt, so the web
  /// sees the change): "Usar sempre" after a new price in an order.
  Future<void> updatePrice(String id, double? value) async {
    await _companyLoaded;
    if (companyId == null) return;
    final user = await userStore.getSingleUserById();
    final stamp = Service()
      ..updatedAt = DateTime.now()
      ..updatedBy = user?.toAggr();
    final json = stamp.toJson();
    await repository.writeFields(companyId!, id, {
      'value': value,
      'updatedAt': json['updatedAt'],
      if (json['updatedBy'] != null) 'updatedBy': json['updatedBy'],
    });
  }

  /// Ids given to services not saved yet (a photo taken before the ✓).
  final Set<String> _draftIds = {};

  /// New document id, without writing anything. Replaceable in tests.
  @visibleForTesting
  String Function() newId = () =>
      FirebaseFirestore.instance.collection('tmp').doc().id;

  @action
  deleteService(Service service) async {
    await _companyLoaded;
    if (companyId == null) return;
    await repository.removeItem(companyId!, service.id);
  }

  @action
  Future<String?> uploadServicePhoto(File file, Service service) async {
    await _companyLoaded;
    if (companyId == null) return null;

    // A new service gets its id now but is written only on ✓: cancelling
    // leaves no nameless service behind.
    if (service.id == null) {
      service.id = newId();
      _draftIds.add(service.id!);
    }

    isUploading = true;
    try {
      final String storagePath = 'tenants/$companyId/services/${service.id}/photo.jpg';
      final String? url = await photoService.uploadImage(file: file, storagePath: storagePath);

      if (url != null) {
        service.photo = url;
        if (!_draftIds.contains(service.id)) {
          // Only the photo, with updatedAt so the web sees the change.
          final now = DateTime.now();
          final user = await userStore.getSingleUserById();
          service
            ..updatedAt = now
            ..updatedBy = user?.toAggr() ?? service.updatedBy;
          final json = service.toJson();
          await repository.writeFields(companyId!, service.id!, {
            'photo': url,
            'updatedAt': json['updatedAt'],
            if (json['updatedBy'] != null) 'updatedBy': json['updatedBy'],
          });
        }
      }
      return url;
    } finally {
      isUploading = false;
    }
  }
}
