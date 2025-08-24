import 'dart:async';

import 'package:praticos/models/company.dart';
import 'package:praticos/repositories/company_repository.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:mobx/mobx.dart';
part 'company_store.g.dart';

class CompanyStore = _CompanyStore with _$CompanyStore;

abstract class _CompanyStore with Store {
  final CompanyRepository repository = CompanyRepository();

  Future<Company?> createItem(Company company, {String? companyId}) async {
    return await (repository.createItem(company, id: companyId)
        as FutureOr<Company?>);
  }

  Future<Company> getCompanyByOwnerId(String id) async {
    return await repository.getSingleQuery([QueryArgs('owner.id', id)]);
  }

  @action
  retrieveCompany(String? id) {
    return repository.getSingle(id);
  }
}
