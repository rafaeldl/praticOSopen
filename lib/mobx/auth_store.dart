import "package:flutter/foundation.dart";
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/mobx/company_store.dart';
import 'package:praticos/mobx/locale_store.dart';
import 'package:praticos/mobx/user_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/repositories/auth_repository.dart';
import 'package:praticos/services/analytics_service.dart';
import 'package:praticos/utils/startup_company.dart';
import 'package:praticos/services/account_deletion_api_service.dart';
import 'package:praticos/mobx/subscription_store.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../global.dart';
part 'auth_store.g.dart';

class AuthStore = _AuthStore with _$AuthStore;

abstract class _AuthStore with Store {
  final AuthRepository _auth = AuthRepository();

  CompanyStore companyStore = CompanyStore();
  UserStore userStore = UserStore();

  /// Injected from main.dart to sync locale on login
  LocaleStore? localeStore;

  /// Injected from main.dart: follows the current company's subscription.
  SubscriptionStore? subscriptionStore;

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
      final deviceLocale = localeStore?.deviceLocaleCode;
      await userStore.createUserIfNotExist(user, initialLocale: deviceLocale);

      var dbUser = await userStore.findUserById(user.uid);

      // Sync preferredLanguage between Firestore and app
      if (dbUser != null) {
        if (dbUser.preferredLanguage != null) {
          // Firestore has a language → sync to app UI
          await localeStore?.syncFromFirestore(dbUser.preferredLanguage);
        } else if (deviceLocale != null) {
          // Backfill: user has no preferredLanguage, write device locale
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'preferredLanguage': deviceLocale}).catchError((e) {
            debugPrint('AuthStore: failed to backfill preferredLanguage: $e');
          });
        }
      }
      // The saved company comes first if the user still belongs to it, then
      // the others in the user's list. Companies that were deleted or left
      // are skipped instead of failing the whole sign-in.
      String? lastCompanyId = prefs.getString('companyId');
      final memberCompanyIds = <String>[
        ...?dbUser?.companies?.map((c) => c.company?.id).whereType<String>(),
      ];
      if (lastCompanyId != null && memberCompanyIds.contains(lastCompanyId)) {
        memberCompanyIds.insert(0, lastCompanyId);
      }

      Company? company = await firstAccessibleCompany<Company>(
        memberCompanyIds,
        (id) async => await companyStore.retrieveCompany(id),
      );
      // Fallback for legacy or owner-only logic
      company ??= await loadIfAccessible(
        () => companyStore.getCompanyByOwnerId(user.uid),
      );

      Global.currentUser = user;

      prefs.setString('userId', user.uid);
      prefs.setString('userDisplayName', user.displayName ?? '');
      prefs.setString('userEmail', user.email ?? '');
      if (user.photoURL != null) {
        prefs.setString('userPhoto', user.photoURL!);
      }

      // Se não encontrou empresa, usuário vai para onboarding
      if (company == null) {
        // Forget a company that no longer exists so the next start is clean
        await prefs.remove('companyId');
        await prefs.remove('companyName');
        companyAggr = null;
        Global.companyAggr = null;
        _isCompanyLoaded = true;
        AnalyticsService.instance.logLogin(
          method: AnalyticsService.getAuthMethod(),
          hasCompany: false,
        );
        await subscriptionStore?.unbind();
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

      final authMethod = AnalyticsService.getAuthMethod();
      AnalyticsService.instance.logLogin(method: authMethod);
      final companyId = company.id;
      AnalyticsService.instance.identifyUser(
        userId: user.uid,
        companyId: companyId,
        segment: company.segment,
        userRole: dbUser?.companies
            ?.where((c) => c.company?.id == companyId)
            .firstOrNull
            ?.role
            ?.name,
      );

      // Live subscription + RevenueCat customer (appUserID = companyId).
      if (companyId != null) {
        await subscriptionStore?.bindCompany(companyId);
      }
    } catch (e) {
      debugPrint('AuthStore: error loading company data: $e');
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
    if (company.id != null) {
      await subscriptionStore?.bindCompany(company.id!);
    }
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
    AnalyticsService.instance.clearUser();
    // Stop the subscription listener and log out of RevenueCat
    await subscriptionStore?.unbind();
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
      // 1. The server deletes the companies the user owns alone, leaves the
      //    others, and deletes users/{uid} and the Firebase Auth user
      //    (docs/ACCOUNT_DELETION.md). REQUIRES_RECENT_LOGIN and the
      //    "owner with members" message are mapped by the service.
      await AccountDeletionApiService.instance.deleteAccount();

      // 2. Clear local preferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove("userId");
      await prefs.remove("userDisplayName");
      await prefs.remove("userEmail");
      await prefs.remove("userPhoto");
      await prefs.remove("companyId");
      await prefs.remove("companyName");

      // 3. Clear global state
      await subscriptionStore?.unbind();
      Global.currentUser = null;
      Global.companyAggr = null;
      companyAggr = null;
      AnalyticsService.instance.clearUser();

      logout = true;
      _isCompanyLoaded = false;
      hasCompanyLoadError = false;

      // 4. Sign out locally (Google + Firebase); the auth state change sends
      //    the user back to the login screen.
      await _auth.signOutGoogle();
    } catch (e) {
      debugPrint('Error deleting account: $e');
      rethrow;
    }
  }
}
