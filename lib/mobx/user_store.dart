import 'package:praticos/mobx/company_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/models/user_role.dart';
import 'package:praticos/repositories/user_repository.dart';
import 'package:praticos/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:mobx/mobx.dart';

import 'package:praticos/global.dart';

part 'user_store.g.dart';

class UserStore = _UserStore with _$UserStore;

abstract class _UserStore with Store {
  final CompanyStore companyStore = CompanyStore();
  final UserRepository repository = UserRepository();
  final AuthService authService = AuthService();

  @observable
  ObservableStream<User>? user;

  @action
  findCurrentUser() async {
    if (Global.currentUser != null) {
      user = repository.streamSingle(Global.currentUser!.uid).asObservable();
    }
  }

  Future<User?> getSingleUserById() async {
    print("Global.currentUser.uid ${Global.currentUser!.uid}");
    return await repository.findUserById(Global.currentUser!.uid);
  }

  createUserIfNotExist(auth.User firebaseUser) async {
    User? user = await repository.findUserById(firebaseUser.uid);
    if (user != null) return;

    User newUser = _fillUserFields(firebaseUser);
    Company newCompany = _fillCompanyFields(newUser, firebaseUser.uid);

    // Adiciona a empresa à lista do usuário (source of truth para claims)
    CompanyRoleAggr companyRole = CompanyRoleAggr()
      ..company = newCompany.toAggr()
      ..role = RolesType.admin;
    newUser.companies = [companyRole];

    await authService.signup(
      user: newUser,
      company: newCompany,
      role: RolesType.admin,
    );
  }

  User _fillUserFields(auth.User firebaseUser) {
    User newUser = User();
    newUser.id = firebaseUser.uid;
    newUser.name = firebaseUser.displayName;
    newUser.email = firebaseUser.email;
    newUser.createdAt = DateTime.now();
    newUser.createdBy = newUser.toAggr();
    newUser.updatedAt = newUser.createdAt;
    newUser.updatedBy = newUser.toAggr();
    return newUser;
  }

  Company _fillCompanyFields(User user, String companyId) {
    return Company()
      ..id = companyId
      ..createdAt = DateTime.now()
      ..createdBy = user.toAggr()
      ..updatedAt = DateTime.now()
      ..updatedBy = user.toAggr()
      ..name = user.name
      ..owner = user.toAggr();
  }
}
