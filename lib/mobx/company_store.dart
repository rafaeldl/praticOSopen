import 'dart:async';
import 'dart:io';

import 'package:praticos/global.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/repositories/company_repository.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/repositories/user_repository.dart';
import 'package:praticos/services/photo_service.dart';
import 'package:mobx/mobx.dart';
part 'company_store.g.dart';

class CompanyStore = _CompanyStore with _$CompanyStore;

abstract class _CompanyStore with Store {
  final CompanyRepository repository = CompanyRepository();
  final UserRepository userRepository = UserRepository();
  final PhotoService photoService = PhotoService();

  @observable
  bool isUploading = false;

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

  @action
  Future<void> addCollaborator(String email, RolesType role) async {
    User? user = await userRepository.findUserByEmail(email);

    if (user == null) {
      throw Exception('Usuário não encontrado');
    }

    if (Global.companyAggr == null) {
      throw Exception('Empresa não selecionada');
    }

    Company? company = await repository.getSingle(Global.companyAggr!.id);
    if (company == null) {
      throw Exception('Empresa não encontrada');
    }

    // Check if user is already in the company
    bool userExists = company.users
            ?.any((u) => u.user?.id == user.id) ??
        false;

    if (userExists) {
      throw Exception('Usuário já é colaborador');
    }

    // Add to Company
    UserRoleAggr newUserRole = UserRoleAggr()
      ..user = user.toAggr()
      ..role = role;

    company.users ??= [];
    company.users!.add(newUserRole);

    // Add to User
    CompanyRoleAggr newCompanyRole = CompanyRoleAggr()
      ..company = company.toAggr()
      ..role = role;

    user.companies ??= [];
    user.companies!.add(newCompanyRole);

    // Save
    await repository.updateItem(company);
    await userRepository.updateItem(user);
  }

  @action
  Future<void> removeCollaborator(String userId) async {
    if (Global.companyAggr == null) return;

    Company? company = await repository.getSingle(Global.companyAggr!.id);
    User? user = await userRepository.findUserById(userId);

    if (company == null || user == null) return;

    // Remove user from company
    company.users?.removeWhere((u) => u.user?.id == userId);

    // Remove company from user
    user.companies?.removeWhere((c) => c.company?.id == company.id);

    await repository.updateItem(company);
    await userRepository.updateItem(user);
  }

  @action
  Future<void> updateCollaboratorRole(String userId, RolesType newRole) async {
    if (Global.companyAggr == null) return;

    Company? company = await repository.getSingle(Global.companyAggr!.id);
    User? user = await userRepository.findUserById(userId);

    if (company == null || user == null) return;

    // Update in company
    var userRole = company.users?.firstWhere((u) => u.user?.id == userId);
    if (userRole != null) {
      userRole.role = newRole;
    }

    // Update in user
    var companyRole =
        user.companies?.firstWhere((c) => c.company?.id == company.id);
    if (companyRole != null) {
      companyRole.role = newRole;
    }

    await repository.updateItem(company);
    await userRepository.updateItem(user);
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
