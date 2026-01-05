import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:praticos/mobx/auth_store.dart';
import 'package:praticos/mobx/bottom_navigation_bar_store.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/mobx/theme_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/screens/login.dart';
import 'package:praticos/screens/auth_wrapper.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:praticos/global.dart';
import 'package:praticos/theme/app_theme.dart';
import 'package:praticos/routes.dart';
import 'package:praticos/providers/segment_config_provider.dart';

AuthStore _authStore = AuthStore();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PackageInfo info = await PackageInfo.fromPlatform();
  Global.version = "${info.version} (${info.buildNumber})";
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
        Provider<ThemeStore>(create: (_) => ThemeStore()),
        ChangeNotifierProvider<SegmentConfigProvider>(
          create: (_) => SegmentConfigProvider(),
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

    final themeStore = Provider.of<ThemeStore>(context);

    return Observer(
      builder: (_) {
        return MaterialApp(
          title: 'PraticOS',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeStore.themeMode,
          navigatorObservers: <NavigatorObserver>[observer],
          builder: (context, child) {
            // Wrap with CupertinoTheme to support dynamic Cupertino colors
            final brightness = Theme.of(context).brightness;
            return CupertinoTheme(
              data: CupertinoThemeData(
                brightness: brightness,
                primaryColor: CupertinoColors.activeBlue,
              ),
              child: child!,
            );
          },
          home: Observer(
            builder: (BuildContext context) {
              return _buildHome(_authStore);
            },
          ),
          routes: appRoutes,
        );
      },
    );
  }

  Widget _buildHome(_authStore) {
    if (_authStore.currentUser != null && _authStore.currentUser.data != null) {
      return AuthWrapper(authStore: _authStore);
    } else {
      return LoginPage();
    }
  }
}
