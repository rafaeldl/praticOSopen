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
      print('📱 Running tests with locale: $locale');

      // Initialize the app
      app.main();
      await tester.pumpAndSettle();

      // Wait for app to fully load
      await Future.delayed(const Duration(seconds: 3));
      await tester.pumpAndSettle();

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
      print('📸 Capturing Screenshot 2: Home');
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 2));
      await binding.takeScreenshot('2_home');

      // ========== SCREENSHOT 3: Order Detail ==========
      print('📸 Navigating to Order Detail...');
      final orderItems = find.byType(InkWell);
      if (orderItems.evaluate().isNotEmpty) {
        await tester.tap(orderItems.first);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 2));

        print('📸 Capturing Screenshot 3: Order Detail');
        await binding.takeScreenshot('3_order_detail');

        // Go back
        final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
        navigator.pop();
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 1));
      }

      // ========== SCREENSHOT 4: Order Form (Create New OS) ==========
      print('📸 Navigating to Order Form...');
      final addButton = find.byIcon(CupertinoIcons.add);
      if (addButton.evaluate().isNotEmpty) {
        await tester.tap(addButton.first);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 3));

        // Scroll down a bit to show more form fields
        final scrollable = find.byType(SingleChildScrollView);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -200));
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(seconds: 1));
        }

        print('📸 Capturing Screenshot 4: Order Form');
        await binding.takeScreenshot('4_order_form');

        // Go back
        final backNav = tester.state<NavigatorState>(find.byType(Navigator).first);
        backNav.pop();
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 1));
      }

      // ========== SCREENSHOT 5: Dynamic Forms (Checklist) ==========
      print('📸 Navigating to Dynamic Forms...');
      // First, go to an order detail again
      if (orderItems.evaluate().isNotEmpty) {
        await tester.tap(orderItems.first);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 2));

        // Look for forms/checklist button (icon or text)
        final formsButton = find.byIcon(CupertinoIcons.doc_text_fill);
        if (formsButton.evaluate().isNotEmpty) {
          await tester.tap(formsButton.first);
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(seconds: 2));

          print('📸 Capturing Screenshot 5: Dynamic Forms');
          await binding.takeScreenshot('5_forms');

          // Go back twice (from form list to order, order to home)
          final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
          nav.pop();
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(milliseconds: 500));
          nav.pop();
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(seconds: 1));
        } else {
          // If no forms button found, just go back to home
          print('⚠️ Forms button not found, skipping screenshot 5');
          final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
          nav.pop();
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      // ========== SCREENSHOT 6: Collaborators (Team Management) ==========
      print('📸 Navigating to Collaborators...');
      // Find and tap Settings/More tab
      final tabBar = find.byType(CupertinoTabBar);
      if (tabBar.evaluate().isNotEmpty) {
        final tabBarBox = tester.getRect(tabBar);
        // Tap third tab (Settings/More)
        final thirdTabX = tabBarBox.left + (tabBarBox.width / 3) * 2.5;
        final tabY = tabBarBox.center.dy;

        await tester.tapAt(Offset(thirdTabX, tabY));
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 2));

        // Find and tap Collaborators menu item
        final collaboratorsText = _findTextByLocale(locale, 'collaborators');
        final collaboratorsButton = find.text(collaboratorsText);

        if (collaboratorsButton.evaluate().isNotEmpty) {
          await tester.tap(collaboratorsButton.first);
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(seconds: 3));

          print('📸 Capturing Screenshot 6: Collaborators');
          await binding.takeScreenshot('6_collaborators');

          // Go back to settings
          final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
          nav.pop();
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(seconds: 1));
        } else {
          print('⚠️ Collaborators button not found, skipping screenshot 6');
        }

        // ========== SCREENSHOT 7: Dashboard ==========
        print('📸 Navigating to Dashboard...');
        // Go back to home tab first
        final homeTabX = tabBarBox.left + (tabBarBox.width / 3) * 0.5;
        await tester.tapAt(Offset(homeTabX, tabY));
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 1));

        // Find dashboard button by icon
        final allIcons = find.byType(Icon);
        for (var i = 0; i < allIcons.evaluate().length; i++) {
          final iconWidget = tester.widget<Icon>(allIcons.at(i));
          if (iconWidget.icon == CupertinoIcons.chart_bar_alt_fill ||
              iconWidget.icon == CupertinoIcons.chart_bar) {
            // Found the dashboard icon, tap its parent button
            final parentButton = find.ancestor(
              of: allIcons.at(i),
              matching: find.byType(CupertinoButton),
            );
            if (parentButton.evaluate().isNotEmpty) {
              await tester.tap(parentButton.first);
              await tester.pumpAndSettle();
              await Future.delayed(const Duration(seconds: 2));

              // Select "Ano" (Year) filter
              print('📅 Selecting Year filter...');
              final yearText = _findTextByLocale(locale, 'year');
              final yearButton = find.text(yearText);
              if (yearButton.evaluate().isNotEmpty) {
                await tester.tap(yearButton);
                await tester.pumpAndSettle();
                await Future.delayed(const Duration(seconds: 1));

                // Go back to previous year (2025)
                print('📅 Navigating to 2025...');
                final backChevron = find.byIcon(CupertinoIcons.chevron_left);
                if (backChevron.evaluate().isNotEmpty) {
                  await tester.tap(backChevron.first);
                  await tester.pumpAndSettle();
                  await Future.delayed(const Duration(seconds: 2));
                }
              }

              print('📸 Capturing Screenshot 7: Dashboard');
              await binding.takeScreenshot('7_dashboard');
              break;
            }
          }
        }
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
  // Find and tap "Entrar com email" link (try multiple languages)
  final emailTexts = ['email', 'e-mail', 'correo'];
  Finder? emailLink;
  for (final text in emailTexts) {
    final finder = find.textContaining(text, skipOffstage: false);
    if (finder.evaluate().isNotEmpty) {
      emailLink = finder;
      break;
    }
  }

  if (emailLink != null) {
    await tester.tap(emailLink.first);
    await tester.pumpAndSettle();
    await Future.delayed(const Duration(seconds: 1));

    // Enter email
    final emailField = find.byType(CupertinoTextFormFieldRow).first;
    await tester.enterText(emailField, 'demo@praticos.com.br');
    await tester.pumpAndSettle();

    // Enter password
    final passwordField = find.byType(CupertinoTextFormFieldRow).at(1);
    await tester.enterText(passwordField, 'Demo@2024!');
    await tester.pumpAndSettle();

    // Dismiss keyboard
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await Future.delayed(const Duration(seconds: 1));

    // Tap login button (try multiple texts)
    final loginTexts = ['Entrar', 'Login', 'Sign in', 'Iniciar sesión'];
    Finder? loginButton;
    for (final text in loginTexts) {
      final finder = find.text(text);
      if (finder.evaluate().isNotEmpty) {
        loginButton = finder;
        break;
      }
    }

    if (loginButton != null) {
      await tester.ensureVisible(loginButton.first);
      await tester.tap(loginButton.first);
      await tester.pumpAndSettle();

      // Wait for login to complete and data to load
      print('⏳ Waiting for login and data load...');
      await Future.delayed(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      // Ensure orders are loaded
      final loadingIndicator = find.byType(CupertinoActivityIndicator);
      if (loadingIndicator.evaluate().isNotEmpty) {
        print('⏳ Still loading data, waiting more...');
        await Future.delayed(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      }
    }
  }
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
