import 'dart:async';
import 'dart:io';

import 'package:praticos/global.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/repositories/company_repository.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/services/photo_service.dart';
import 'package:mobx/mobx.dart';
part 'company_store.g.dart';

class CompanyStore = _CompanyStore with _$CompanyStore;

abstract class _CompanyStore with Store {
  final CompanyRepository repository = CompanyRepository();
  final PhotoService photoService = PhotoService();

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
        company.logo = url;
        await repository.updateItem(company);
        
        // Update global aggregate
        if (Global.companyAggr != null && company.id == Global.companyAggr!.id) {
          // You might need to add 'logo' to CompanyAggr if you want it updated globally immediately
          // But for now, just updating the full company record is enough
        }
      }
      return url;
    } finally {
      isUploading = false;
    }
  }
}
