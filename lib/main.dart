import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:praticos/mobx/auth_store.dart';
import 'package:praticos/mobx/bottom_navigation_bar_store.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/screens/device_form_screen.dart';
import 'package:praticos/screens/device_list_screen.dart';
import 'package:praticos/screens/login.dart';
import 'package:praticos/screens/menu_navigation/navigation_controller.dart';
import 'package:praticos/screens/order_form.dart';
import 'package:praticos/screens/order_product_screen.dart';
import 'package:praticos/screens/order_service_screen.dart';
import 'package:praticos/screens/payment_form_screen.dart';
import 'package:praticos/screens/product_form_screen.dart';
import 'package:praticos/screens/product_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:praticos/global.dart';
import 'screens/customers/customer_form_screen.dart';
import 'screens/customers/customer_list_screen.dart';
import 'screens/info_form_screen.dart';
import 'screens/service_form_screen.dart';
import 'screens/service_list_screen.dart';
import 'package:praticos/screens/dashboard/financial_dashboard_simple.dart';

AuthStore _authStore = AuthStore();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PackageInfo info = await PackageInfo.fromPlatform();
  Global.version = info.version;
  await Firebase.initializeApp();
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
  FirebaseCrashlytics.instance.log("iniciando a aplicação");

  runApp(
    MultiProvider(
      providers: [
        Provider<OrderStore>(create: (_) => OrderStore()),
        Provider<BottomNavigationBarStore>(
          create: (_) => BottomNavigationBarStore(),
        ),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(
    analytics: analytics,
  );

  @override
  Widget build(BuildContext context) {
    SharedPreferences.getInstance().then((value) {
      Global.companyAggr = CompanyAggr();
      Global.companyAggr!.id = value.getString('companyId');
      Global.companyAggr!.name = value.getString('companyName');
      Global.userAggr = UserAggr();
      Global.userAggr!.id = value.getString('userId');
      Global.userAggr!.name = value.getString('userDisplayName');
      // Global.orderStore = OrderStore();
    });

    return MaterialApp(
      title: 'PraticOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Color(0xFF3498db),
        scaffoldBackgroundColor: Color(0xFFF7F7F7),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: Color(0xFFf1c40f),
        ),
      ),
      navigatorObservers: <NavigatorObserver>[observer],
      home: Observer(
        builder: (BuildContext context) {
          return _buildHome(_authStore);
        },
      ),
      routes: {
        '/service_list': (context) => ServiceListScreen(),
        '/service_form': (context) => ServiceFormScreen(),
        '/product_list': (context) => ProductListScreen(),
        '/product_form': (context) => ProductFormScreen(),
        '/customer_form': (context) => CustomerFormScreen(),
        '/customer_list': (context) => CustomerListScreen(),
        '/device_form': (context) => DeviceFormScreen(),
        '/device_list': (context) => DeviceListScreen(),
        '/info_form': (context) => InfoFormScreen(),
        '/order': (context) => OrderForm(),
        '/order_service': (context) => OrderServiceScreen(),
        '/order_product': (context) => OrderProductScreen(),
        '/payment_form_screen': (context) => PaymentFormScreen(),
        '/financial_dashboard_simple': (context) => FinancialDashboardSimple(),
      },
    );
  }

  Widget _buildHome(_authStore) {
    if (_authStore.currentUser != null && _authStore.currentUser.data != null) {
      return NavigationController();
    } else {
      return LoginPage();
    }
  }
}
