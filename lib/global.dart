import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:praticos/mobx/order_store.dart';
import 'models/company.dart';
import 'models/user.dart';

class Global {
  static auth.User? currentUser;
  static CompanyAggr? companyAggr;
  static UserAggr? userAggr;

  static late String version;
  static OrderStore orderStore = OrderStore();
}
