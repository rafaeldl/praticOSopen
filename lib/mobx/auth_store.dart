import 'package:praticos/mobx/company_store.dart';
import 'package:praticos/mobx/user_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/repositories/auth_repository.dart';
import 'package:praticos/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../global.dart';
part 'auth_store.g.dart';

class AuthStore = _AuthStore with _$AuthStore;

abstract class _AuthStore with Store {
  final AuthRepository _auth = AuthRepository();
  final AuthService _authService = AuthService();

  CompanyStore companyStore = CompanyStore();
  UserStore userStore = UserStore();

  @observable
  ObservableStream<User?>? currentUser;

  @observable
  CompanyAggr? companyAggr;

  Observable<bool> changed = Observable(false);

  bool logout = false;

  _AuthStore() {
    currentUser = _auth.onAuthStateChanged().asObservable();

    when((_) => currentUser!.value != null, () async {
      if (logout) return;

      User user = currentUser!.value!;
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await userStore.createUserIfNotExist(user);

      var dbUser = await userStore.repository.findUserById(user.uid);
      Company company;

      // Check if there is a last selected company saved
      String? lastCompanyId = prefs.getString('companyId');

      if (lastCompanyId != null &&
          dbUser != null &&
          dbUser.companies != null &&
          dbUser.companies!.any((c) => c.company?.id == lastCompanyId)) {
        // Load the saved company if the user still belongs to it
        company = await companyStore.retrieveCompany(lastCompanyId);
      } else if (dbUser != null &&
          dbUser.companies != null &&
          dbUser.companies!.isNotEmpty &&
          dbUser.companies!.first.company != null &&
          dbUser.companies!.first.company!.id != null) {
        // Retrieve the first company associated with the user
        company = await companyStore
            .retrieveCompany(dbUser.companies!.first.company!.id!);
      } else {
        // Fallback for legacy or owner-only logic
        company = await companyStore.getCompanyByOwnerId(user.uid);
      }

      Global.currentUser = user;

      prefs.setString('userId', user.uid);
      prefs.setString('userDisplayName', user.displayName ?? '');
      prefs.setString('userEmail', user.email ?? '');
      if (user.photoURL != null) {
        prefs.setString('userPhoto', user.photoURL!);
      }

      if (company.id != null) {
        prefs.setString('companyId', company.id!);
      }
      if (company.name != null) {
        prefs.setString('companyName', company.name!);
      }
      companyAggr = company.toAggr();
      Global.companyAggr = companyAggr;
    });
  }

  @action
  Future<void> switchCompany(String companyId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    Company company = await companyStore.retrieveCompany(companyId);

    if (company.id != null) {
      prefs.setString('companyId', company.id!);
    }
    if (company.name != null) {
      prefs.setString('companyName', company.name!);
    }
    companyAggr = company.toAggr();
    Global.companyAggr = companyAggr;
  }

  @action
  signInWithGoogle() {
    _auth.signInWithGoogle();
  }

  @action
  Future<dynamic> signInWithApple() {
    return _auth.signInWithApple();
  }

  @action
  Future<dynamic> signInWithEmailPassword(String email, String password) {
    return _auth.signInWithEmailPassword(email, password);
  }

  @action
  signOutGoogle() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    logout = true;
    await prefs.remove("userId");
    await prefs.remove("userDisplayName");
    await prefs.remove("userEmail");
    await prefs.remove("userPhoto");
    await prefs.remove("companyId");
    await prefs.remove("companyName");
    Global.currentUser = null;
    Global.companyAggr = null;
    _auth.signOutGoogle();
  }

  @action
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email);
  }

  @action
  Future<void> deleteAccount() async {
    final user = currentUser?.value;
    if (user == null) {
      throw Exception('No authenticated user to delete');
    }

    try {
      // 1. Delete all Firestore data
      await _authService.deleteUserData(user.uid);

      // 2. Clear local preferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove("userId");
      await prefs.remove("userDisplayName");
      await prefs.remove("userEmail");
      await prefs.remove("userPhoto");
      await prefs.remove("companyId");
      await prefs.remove("companyName");

      // 3. Clear global state
      Global.currentUser = null;
      Global.companyAggr = null;

      // 4. Delete Firebase Auth account
      await _auth.deleteAccount();

      logout = true;
    } catch (e) {
      print('Error deleting account: $e');
      rethrow;
    }
  }
}
