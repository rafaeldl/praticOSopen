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

  @observable
  bool hasCompanyLoadError = false;

  Observable<bool> changed = Observable(false);

  bool logout = false;

  /// Guards against concurrent/duplicate processing of auth state
  bool _isCompanyLoaded = false;

  /// Keeps the reaction disposer so we can clean up if needed
  // ignore: unused_field
  ReactionDisposer? _authReactionDisposer;

  _AuthStore() {
    currentUser = _auth.onAuthStateChanged().asObservable();

    _authReactionDisposer = reaction(
      (_) => currentUser?.value,
      (User? user) => _onAuthStateChanged(user),
      fireImmediately: true,
    );
  }

  Future<void> _onAuthStateChanged(User? user) async {
    if (user == null) return;

    // Reset logout flag on new login — a new user means a fresh session
    logout = false;

    if (_isCompanyLoaded) return;

    try {
      hasCompanyLoadError = false;

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await userStore.createUserIfNotExist(user);

      var dbUser = await userStore.findUserById(user.uid);
      Company? company;

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

      // Se não encontrou empresa, usuário vai para onboarding
      if (company == null) {
        companyAggr = null;
        Global.companyAggr = null;
        _isCompanyLoaded = true;
        return;
      }

      if (company.id != null) {
        prefs.setString('companyId', company.id!);
      }
      if (company.name != null) {
        prefs.setString('companyName', company.name!);
      }
      companyAggr = company.toAggr();
      Global.companyAggr = companyAggr;
      _isCompanyLoaded = true;
    } catch (e) {
      print('AuthStore: error loading company data: $e');
      hasCompanyLoadError = true;
    }
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

  /// Recarrega os dados do usuário e empresa do Firestore
  /// Útil após criar uma nova empresa no onboarding ou para retry após erro
  @action
  Future<void> reloadUserAndCompany() async {
    _isCompanyLoaded = false;
    hasCompanyLoadError = false;

    User? user = currentUser?.value;
    if (user == null) return;

    // Re-trigger the same logic
    await _onAuthStateChanged(user);
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
    _isCompanyLoaded = false;
    hasCompanyLoadError = false;
    companyAggr = null;
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
  Future<void> reauthenticate() async {
    await _auth.reauthenticate();
  }

  @action
  Future<void> deleteAccount() async {
    final user = currentUser?.value;
    if (user == null) {
      throw Exception('No authenticated user to delete');
    }

    try {
      // 1. Delete all Firestore data (company, user document, everything)
      await _authService.deleteUserData(user.uid);

      // 2. Delete Firebase Auth account
      try {
        await _auth.deleteAccount();
      } on FirebaseAuthException catch (e) {
        // If requires recent login, throw a specific error to handle in UI
        if (e.code == 'requires-recent-login') {
          throw Exception('REQUIRES_RECENT_LOGIN');
        }
        rethrow;
      }

      // 3. Clear local preferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove("userId");
      await prefs.remove("userDisplayName");
      await prefs.remove("userEmail");
      await prefs.remove("userPhoto");
      await prefs.remove("companyId");
      await prefs.remove("companyName");

      // 4. Clear global state
      Global.currentUser = null;
      Global.companyAggr = null;
      companyAggr = null;

      logout = true;
      _isCompanyLoaded = false;
      hasCompanyLoadError = false;
    } catch (e) {
      print('Error deleting account: $e');
      rethrow;
    }
  }
}
