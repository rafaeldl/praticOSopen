import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/global.dart';
import 'package:praticos/services/contract_directory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  test('without a company the list is empty, not loading forever', () async {
    Global.companyAggr = null;
    final orders = await FirestoreContractDirectory()
        .watchContractOrders()
        .first
        .timeout(const Duration(seconds: 1));
    expect(orders, isEmpty);
  });
}
