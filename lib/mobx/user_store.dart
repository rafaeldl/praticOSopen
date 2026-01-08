import 'package:cloud_firestore/cloud_firestore.dart';
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
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @observable
  ObservableStream<User>? user;

  @action
  findCurrentUser() async {
    if (Global.currentUser != null) {
      user = repository.streamSingle(Global.currentUser!.uid).asObservable();
    }
  }

  /// Busca um usuário por ID do Firestore (retorna Future)
  @action
  Future<User?> findUserById(String userId) async {
    return await repository.findUserById(userId);
  }

  Future<User?> getSingleUserById() async {
    print("Global.currentUser.uid ${Global.currentUser!.uid}");
    return await repository.findUserById(Global.currentUser!.uid);
  }

  /// Cria o documento do usuário se não existir.
  ///
  /// IMPORTANTE: Não cria mais empresa automaticamente.
  /// O usuário vai para o onboarding onde pode:
  /// - Aceitar convites pendentes de outras empresas
  /// - Criar sua própria empresa
  createUserIfNotExist(auth.User firebaseUser) async {
    User? existingUser = await repository.findUserById(firebaseUser.uid);
    if (existingUser != null) return;

    // Cria apenas o documento do usuário (sem empresa)
    User newUser = _fillUserFields(firebaseUser);
    newUser.companies = []; // Começa sem empresas

    await _db.collection('users').doc(newUser.id).set(newUser.toJson());
  }

  /// Cria uma empresa para o usuário atual (usado no onboarding).
  Future<void> createCompanyForUser(Company company) async {
    final userId = Global.currentUser?.uid;
    if (userId == null) {
      throw Exception('Usuário não autenticado');
    }

    User? user = await repository.findUserById(userId);
    if (user == null) {
      throw Exception('Usuário não encontrado no Firestore');
    }

    // Adiciona a empresa à lista do usuário
    CompanyRoleAggr companyRole = CompanyRoleAggr()
      ..company = company.toAggr()
      ..role = RolesType.admin;

    user.companies ??= [];
    user.companies!.add(companyRole);

    await authService.signup(
      user: user,
      company: company,
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
}
