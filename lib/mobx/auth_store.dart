import 'package:praticos/mobx/company_store.dart';
import 'package:praticos/mobx/user_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../global.dart';
part 'auth_store.g.dart';

class AuthStore = _AuthStore with _$AuthStore;

abstract class _AuthStore with Store {
  AuthRepository _auth = AuthRepository();

  CompanyStore companyStore = CompanyStore();
  UserStore userStore = UserStore();

  @observable
  ObservableStream<User?>? currentUser;

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

      Company company = await companyStore.getCompanyByOwnerId(user.uid);
      Global.currentUser = user;

      prefs.setString('userId', user.uid);
      prefs.setString('userDisplayName', user.displayName!);
      prefs.setString('userEmail', user.email!);
      prefs.setString('userPhoto', user.photoURL!);

      prefs.setString('companyId', company.id!);
      prefs.setString('companyName', company.name!);
      companyAggr = company.toAggr();
      Global.companyAggr = companyAggr;
    });
  }

  @action
  signInWithGoogle() {
    _auth.signInWithGoogle();
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
}
