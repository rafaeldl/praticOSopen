import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:praticos/global.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/repositories/company_repository.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/services/photo_service.dart';
import 'package:mobx/mobx.dart';
part 'company_store.g.dart';

class CompanyStore = _CompanyStore with _$CompanyStore;

/// Writes some fields of `/companies/{companyId}` (an `update`).
typedef CompanyFieldsUpdate =
    Future<void> Function(String companyId, Map<String, dynamic> fields);

Future<void> _updateCompanyFields(
  String companyId,
  Map<String, dynamic> fields,
) => FirebaseFirestore.instance
    .collection('companies')
    .doc(companyId)
    .update(fields);

abstract class _CompanyStore with Store {
  _CompanyStore({PhotoService? photoService, CompanyFieldsUpdate? writeFields})
    : photoService = photoService ?? PhotoService(),
      writeFields = writeFields ?? _updateCompanyFields;

  final CompanyRepository repository = CompanyRepository();
  final PhotoService photoService;

  /// Partial writes (the logo): never the whole company from a copy.
  final CompanyFieldsUpdate writeFields;

  @observable
  bool isUploading = false;

  Future<Company?> createItem(Company company, {String? companyId}) async {
    return await (repository.createItem(company, id: companyId)
        as FutureOr<Company?>);
  }

  Future<Company?> getCompanyByOwnerId(String id) async {
    final companies = await repository.getQueryList(args: [QueryArgs('owner.id', id)]);
    if (companies.isEmpty) return null;
    return companies.first;
  }

  @action
  retrieveCompany(String? id) {
    return repository.getSingle(id);
  }

  @action
  Future<void> updateCompany(Company company) async {
    await repository.updateItem(company);
  }

  @action
  Future<String?> uploadCompanyLogo(File file, Company company) async {
    if (company.id == null) {
      await updateCompany(company);
    }

    isUploading = true;
    try {
      final String storagePath = 'tenants/${company.id}/logo/logo.jpg';
      final String? url = await photoService.uploadImage(file: file, storagePath: storagePath);

      if (url != null) {
        company
          ..logo = url
          ..updatedAt = DateTime.now()
          ..updatedBy = Global.userAggr;
        // Only the logo: the company the screen holds may be old, and
        // writing it whole would undo what the web changed meanwhile.
        final json = company.toJson();
        await writeFields(company.id!, {
          'logo': url,
          'updatedAt': json['updatedAt'],
          if (json['updatedBy'] != null) 'updatedBy': json['updatedBy'],
        });
      }
      return url;
    } finally {
      isUploading = false;
    }
  }
}
