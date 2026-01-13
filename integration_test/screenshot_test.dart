import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show InkWell, Navigator, NavigatorState, Icon;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:praticos/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Screenshot Tests', () {
    testWidgets('capture all 7 screenshots for App Store', (WidgetTester tester) async {
      // Get locale from environment (default: pt-BR)
      const locale = String.fromEnvironment('TEST_LOCALE', defaultValue: 'pt-BR');
      print('\n========================================');
      print('📱 Starting screenshot tests');
      print('🌍 Locale: $locale');
      print('========================================\n');

      // Initialize the app
      print('🚀 Initializing app...');
      app.main();
      await tester.pumpAndSettle();

      // Wait for app to fully load
      print('⏳ Waiting for app initialization...');
      await Future.delayed(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      print('✅ App initialized');

      // Check if already logged in and logout if requested
      const forceLogout = bool.fromEnvironment('FORCE_LOGOUT', defaultValue: true);

      final emailLoginLink = find.textContaining('email');
      if (forceLogout && emailLoginLink.evaluate().isEmpty) {
        print('📱 App already logged in, forcing logout to start fresh...');
        await _performLogout(tester);
      }

      // Android specific: Enable screenshot capture
      await binding.convertFlutterSurfaceToImage();

      // ========== SCREENSHOT 1: Login ==========
      print('📸 Capturing Screenshot 1: Login');
      await Future.delayed(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('1_login');

      // ========== LOGIN WITH DEMO ACCOUNT ==========
      print('🔐 Logging in with demo account...');
      await _performLogin(tester);

      // ========== SCREENSHOT 2: Home (Order List) ==========
      print('\n--- Screenshot 2: Home ---');
      print('Waiting for home screen to load...');
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      print('Home screen loaded');

      // Debug: print widget tree to see what's actually on screen
      print('\n=== WIDGET TREE DEBUG ===');
      final widgets = tester.allWidgets.toList();
      print('Total widgets: ${widgets.length}');

      // Check for common widgets
      final inkWells = widgets.where((w) => w.runtimeType.toString() == 'InkWell').length;
      final tabBars = widgets.where((w) => w.runtimeType.toString() == 'CupertinoTabBar').length;
      final buttons = widgets.where((w) => w.runtimeType.toString().contains('Button')).length;
      final icons = widgets.where((w) => w.runtimeType.toString() == 'Icon').length;

      print('InkWell widgets: $inkWells');
      print('CupertinoTabBar widgets: $tabBars');
      print('Button widgets: $buttons');
      print('Icon widgets: $icons');
      print('=========================\n');

      print('📸 Capturing Screenshot 2: Home');
      await binding.takeScreenshot('2_home');

      // ========== SCREENSHOT 3: Order Detail ==========
      print('\n--- Screenshot 3: Order Detail ---');
      print('Looking for order items...');
      final orderItems = find.byType(InkWell);
      print('Found ${orderItems.evaluate().length} InkWell items');

      if (orderItems.evaluate().isNotEmpty) {
        print('Tapping first order item...');
        await tester.tap(orderItems.first);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 3));
        print('Order detail opened');

        print('📸 Capturing Screenshot 3: Order Detail');
        await binding.takeScreenshot('3_order_detail');

        // Go back
        print('Navigating back to home...');
        final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
        navigator.pop();
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 1));
        print('✅ Back to home');
      } else {
        print('⚠️ No order items found, skipping order detail screenshot');
      }

      // ========== SCREENSHOT 4: Order Form (Create New OS) ==========
      print('\n--- Screenshot 4: Order Form ---');
      print('Looking for add button...');
      final addButton = find.byIcon(CupertinoIcons.add);
      print('Found ${addButton.evaluate().length} add buttons');

      if (addButton.evaluate().isNotEmpty) {
        print('Tapping add button to create new order...');
        await tester.tap(addButton.first);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 3));
        print('Order form opened');

        // Scroll down a bit to show more form fields
        final scrollable = find.byType(SingleChildScrollView);
        if (scrollable.evaluate().isNotEmpty) {
          print('Scrolling form to show more fields...');
          await tester.drag(scrollable.first, const Offset(0, -200));
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(seconds: 1));
        }

        print('📸 Capturing Screenshot 4: Order Form');
        await binding.takeScreenshot('4_order_form');

        // Go back
        print('Navigating back to home...');
        final backNav = tester.state<NavigatorState>(find.byType(Navigator).first);
        backNav.pop();
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 1));
        print('✅ Back to home');
      } else {
        print('⚠️ Add button not found, skipping order form screenshot');
      }

      // ========== SCREENSHOT 5: Dynamic Forms (Checklist) ==========
      print('\n--- Screenshot 5: Dynamic Forms ---');
      print('Looking for order items again...');
      final orderItems2 = find.byType(InkWell);
      print('Found ${orderItems2.evaluate().length} InkWell items');

      if (orderItems2.evaluate().isNotEmpty) {
        print('Tapping first order item...');
        await tester.tap(orderItems2.first);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 3));
        print('Order detail opened');

        // Look for forms/checklist button (icon or text)
        print('Looking for forms button (doc_text_fill icon)...');
        final formsButton = find.byIcon(CupertinoIcons.doc_text_fill);
        print('Found ${formsButton.evaluate().length} forms buttons');

        if (formsButton.evaluate().isNotEmpty) {
          print('Tapping forms button...');
          await tester.tap(formsButton.first);
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(seconds: 3));
          print('Forms screen opened');

          print('📸 Capturing Screenshot 5: Dynamic Forms');
          await binding.takeScreenshot('5_forms');

          // Go back twice (from form list to order, order to home)
          print('Navigating back to home...');
          final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
          nav.pop();
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(milliseconds: 500));
          nav.pop();
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(seconds: 1));
          print('✅ Back to home');
        } else {
          // If no forms button found, just go back to home
          print('⚠️ Forms button not found, skipping screenshot 5');
          final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
          nav.pop();
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(seconds: 1));
        }
      } else {
        print('⚠️ No order items found for forms navigation');
      }

      // ========== SCREENSHOT 6: Collaborators (Team Management) ==========
      print('\n--- Screenshot 6: Collaborators ---');
      print('Looking for tab bar...');
      final tabBar = find.byType(CupertinoTabBar);
      print('Found ${tabBar.evaluate().length} tab bars');

      if (tabBar.evaluate().isNotEmpty) {
        final tabBarBox = tester.getRect(tabBar);
        // Tap third tab (Settings/More)
        final thirdTabX = tabBarBox.left + (tabBarBox.width / 3) * 2.5;
        final tabY = tabBarBox.center.dy;

        print('Tapping Settings/More tab...');
        await tester.tapAt(Offset(thirdTabX, tabY));
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 2));
        print('Settings screen opened');

        // Find and tap Collaborators menu item
        final collaboratorsText = _findTextByLocale(locale, 'collaborators');
        print('Looking for collaborators button with text: "$collaboratorsText"');
        final collaboratorsButton = find.text(collaboratorsText);
        print('Found ${collaboratorsButton.evaluate().length} collaborators buttons');

        if (collaboratorsButton.evaluate().isNotEmpty) {
          print('Tapping collaborators button...');
          await tester.tap(collaboratorsButton.first);
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(seconds: 3));
          print('Collaborators screen opened');

          print('📸 Capturing Screenshot 6: Collaborators');
          await binding.takeScreenshot('6_collaborators');

          // Go back to settings
          print('Navigating back to settings...');
          final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
          nav.pop();
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(seconds: 1));
          print('✅ Back to settings');
        } else {
          print('⚠️ Collaborators button not found, skipping screenshot 6');
        }

        // ========== SCREENSHOT 7: Dashboard ==========
        print('\n--- Screenshot 7: Dashboard ---');
        print('Going back to home tab...');
        // Go back to home tab first
        final homeTabX = tabBarBox.left + (tabBarBox.width / 3) * 0.5;
        await tester.tapAt(Offset(homeTabX, tabY));
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 1));
        print('Home tab active');

        // Find dashboard button by icon
        print('Looking for dashboard button (chart icon)...');
        final allIcons = find.byType(Icon);
        print('Found ${allIcons.evaluate().length} total icons');

        bool dashboardFound = false;
        for (var i = 0; i < allIcons.evaluate().length; i++) {
          final iconWidget = tester.widget<Icon>(allIcons.at(i));
          if (iconWidget.icon == CupertinoIcons.chart_bar_alt_fill ||
              iconWidget.icon == CupertinoIcons.chart_bar) {
            print('Found dashboard icon at index $i');
            // Found the dashboard icon, tap its parent button
            final parentButton = find.ancestor(
              of: allIcons.at(i),
              matching: find.byType(CupertinoButton),
            );
            print('Found ${parentButton.evaluate().length} parent buttons');

            if (parentButton.evaluate().isNotEmpty) {
              print('Tapping dashboard button...');
              await tester.tap(parentButton.first);
              await tester.pumpAndSettle();
              await Future.delayed(const Duration(seconds: 3));
              print('Dashboard opened');

              // Select "Ano" (Year) filter
              print('Looking for Year filter...');
              final yearText = _findTextByLocale(locale, 'year');
              print('Year text for locale: "$yearText"');
              final yearButton = find.text(yearText);
              print('Found ${yearButton.evaluate().length} year buttons');

              if (yearButton.evaluate().isNotEmpty) {
                print('Tapping year filter...');
                await tester.tap(yearButton);
                await tester.pumpAndSettle();
                await Future.delayed(const Duration(seconds: 1));

                // Go back to previous year (2025)
                print('Looking for back chevron to navigate to 2025...');
                final backChevron = find.byIcon(CupertinoIcons.chevron_left);
                print('Found ${backChevron.evaluate().length} back chevrons');

                if (backChevron.evaluate().isNotEmpty) {
                  print('Tapping back chevron...');
                  await tester.tap(backChevron.first);
                  await tester.pumpAndSettle();
                  await Future.delayed(const Duration(seconds: 2));
                  print('Navigated to 2025');
                }
              }

              print('📸 Capturing Screenshot 7: Dashboard');
              await binding.takeScreenshot('7_dashboard');
              dashboardFound = true;
              break;
            }
          }
        }

        if (!dashboardFound) {
          print('⚠️ Dashboard button not found');
        }
      } else {
        print('⚠️ Tab bar not found, skipping collaborators and dashboard');
      }

      print('✅ All screenshots captured successfully for locale: $locale');
    });
  });
}

/// Performs logout flow
Future<void> _performLogout(WidgetTester tester) async {
  // Find CupertinoTabBar and tap third item (Settings)
  final tabBar = find.byType(CupertinoTabBar);
  if (tabBar.evaluate().isNotEmpty) {
    final tabBarBox = tester.getRect(tabBar);
    final settingsTabX = tabBarBox.left + (tabBarBox.width / 3) * 2.5;
    final tabY = tabBarBox.center.dy;

    await tester.tapAt(Offset(settingsTabX, tabY));
    await tester.pumpAndSettle();
    await Future.delayed(const Duration(seconds: 2));

    // Find logout button (try multiple possible texts)
    final logoutTexts = ['Sair', 'Logout', 'Cerrar sesión'];
    Finder? logoutTile;
    for (final text in logoutTexts) {
      final finder = find.text(text);
      if (finder.evaluate().isNotEmpty) {
        logoutTile = finder;
        break;
      }
    }

    if (logoutTile != null) {
      await tester.tap(logoutTile.first);
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 1));

      // Confirm logout in CupertinoAlertDialog
      final confirmButton = find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.textContaining('Sai', skipOffstage: false),
      );

      if (confirmButton.evaluate().isNotEmpty) {
        await tester.tap(confirmButton.last);
        await tester.pumpAndSettle();
        print('✅ Logged out successfully');

        await Future.delayed(const Duration(seconds: 3));
        await tester.pumpAndSettle();
      }
    }
  }
}

/// Performs login with demo account
Future<void> _performLogin(WidgetTester tester) async {
  print('\n=== LOGIN FLOW DEBUG ===');

  // Find and tap "Entrar com email" link (try multiple languages)
  print('Step 1: Looking for email login link...');
  final emailTexts = ['email', 'e-mail', 'correo'];
  Finder? emailLink;
  for (final text in emailTexts) {
    final finder = find.textContaining(text, skipOffstage: false);
    print('  Searching for text containing "$text": found ${finder.evaluate().length}');
    if (finder.evaluate().isNotEmpty) {
      emailLink = finder;
      print('  ✅ Found email link with text: "$text"');
      break;
    }
  }

  if (emailLink != null) {
    print('Step 2: Tapping email login link...');
    await tester.tap(emailLink.first);
    await tester.pumpAndSettle();
    await Future.delayed(const Duration(seconds: 2));
    print('  ✅ Email login screen opened');

    // Enter email
    print('Step 3: Looking for email field...');
    final emailFields = find.byType(CupertinoTextFormFieldRow);
    print('  Found ${emailFields.evaluate().length} text fields');

    if (emailFields.evaluate().isNotEmpty) {
      print('  Entering email: demo@praticos.com.br');
      await tester.enterText(emailFields.first, 'demo@praticos.com.br');
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(milliseconds: 500));
      print('  ✅ Email entered');

      // Enter password
      print('Step 4: Entering password...');
      if (emailFields.evaluate().length > 1) {
        await tester.enterText(emailFields.at(1), 'Demo@2024!');
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(milliseconds: 500));
        print('  ✅ Password entered');
      } else {
        print('  ⚠️ Password field not found!');
      }

      // Dismiss keyboard
      print('Step 5: Dismissing keyboard...');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 1));
      print('  ✅ Keyboard dismissed');

      // Tap login button (try multiple texts)
      print('Step 6: Looking for login button...');
      final loginTexts = ['Entrar', 'Login', 'Sign in', 'Iniciar sesión'];
      Finder? loginButton;
      for (final text in loginTexts) {
        final finder = find.text(text);
        print('  Searching for button with text "$text": found ${finder.evaluate().length}');
        if (finder.evaluate().isNotEmpty) {
          loginButton = finder;
          print('  ✅ Found login button with text: "$text"');
          break;
        }
      }

      if (loginButton != null) {
        print('Step 7: Tapping login button...');
        await tester.ensureVisible(loginButton.first);
        await tester.tap(loginButton.first);
        await tester.pumpAndSettle();
        print('  ✅ Login button tapped');

        // Wait for login to complete and data to load
        print('Step 8: Waiting for login to complete...');
        await Future.delayed(const Duration(seconds: 10));
        await tester.pumpAndSettle();
        print('  Initial wait complete');

        // Ensure orders are loaded
        final loadingIndicator = find.byType(CupertinoActivityIndicator);
        print('  Loading indicators: ${loadingIndicator.evaluate().length}');
        if (loadingIndicator.evaluate().isNotEmpty) {
          print('  ⏳ Still loading data, waiting more...');
          await Future.delayed(const Duration(seconds: 5));
          await tester.pumpAndSettle();
        }
        print('  ✅ Login complete');
      } else {
        print('  ❌ Login button not found!');
      }
    } else {
      print('  ❌ Email fields not found!');
    }
  } else {
    print('  ❌ Email login link not found!');
  }

  print('=========================\n');
}

/// Helper to find locale-specific text
String _findTextByLocale(String locale, String key) {
  final texts = {
    'collaborators': {
      'pt-BR': 'Colaboradores',
      'en-US': 'Collaborators',
      'es-ES': 'Colaboradores',
    },
    'year': {
      'pt-BR': 'Ano',
      'en-US': 'Year',
      'es-ES': 'Año',
    },
  };

  return texts[key]?[locale] ?? texts[key]?['pt-BR'] ?? key;
}
