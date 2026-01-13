import 'package:flutter/cupertino.dart';
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
      print('🔐 Logging in with demo account for locale: $locale...');
      await _performLogin(tester, locale);

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

      // ========== SCREENSHOT 3: Dashboard ==========
      print('\n--- Screenshot 3: Dashboard ---');
      print('Looking for dashboard button...');

      // Try to find the chart icon first
      final chartIcons = find.byIcon(CupertinoIcons.chart_bar_alt_fill);
      print('Chart icons found: ${chartIcons.evaluate().length}');

      Finder? dashboardButton;

      // Strategy 1: Find by icon
      if (chartIcons.evaluate().isNotEmpty) {
        // Find parent button
        dashboardButton = find.ancestor(
          of: chartIcons.first,
          matching: find.byType(CupertinoButton),
        );
        print('Dashboard button via icon: ${dashboardButton.evaluate().length}');
      }

      // Strategy 2: Find buttons in navigation bar area (top of screen)
      if (dashboardButton == null || dashboardButton.evaluate().isEmpty) {
        print('Trying position-based search...');
        final allButtons = find.byType(CupertinoButton);
        print('Total CupertinoButtons: ${allButtons.evaluate().length}');

        for (var i = 0; i < allButtons.evaluate().length; i++) {
          try {
            final buttonPos = tester.getTopLeft(allButtons.at(i));
            print('  Button $i at position: $buttonPos');
            // Dashboard button should be in the top 120 pixels (navigation bar)
            if (buttonPos.dy < 120) {
              dashboardButton = allButtons.at(i);
              print('  ✅ Using button at index $i as dashboard button');
              break;
            }
          } catch (e) {
            print('  Button $i: error - $e');
          }
        }
      }

      if (dashboardButton != null && dashboardButton.evaluate().isNotEmpty) {
        print('Tapping dashboard button...');
        await tester.tap(dashboardButton);
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

        print('📸 Capturing Screenshot 3: Dashboard');
        await binding.takeScreenshot('02_dashboard');

        // Navigate back to home
        print('Navigating back to home...');
        await tester.pageBack();
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 2));
        print('✅ Back to home');
      } else {
        print('⚠️ Dashboard button not found, skipping screenshot 3');
      }

      // ========== SCREENSHOT 4: Order Detail ==========
      print('\n--- Screenshot 4: Order Detail ---');
      print('Looking for order cards with semantic identifiers...');

      // Find all Semantics widgets and filter for order_card_ identifiers
      final allSemantics = find.byType(Semantics);
      Finder? firstOrderCard;

      for (var i = 0; i < allSemantics.evaluate().length; i++) {
        final widget = tester.widget<Semantics>(allSemantics.at(i));
        final identifier = widget.properties.identifier?.toString() ?? '';
        if (identifier.startsWith('order_card_')) {
          firstOrderCard = allSemantics.at(i);
          print('Found order card: $identifier');
          break;
        }
      }

      print('Order cards found: ${firstOrderCard != null ? 1 : 0}');

      if (firstOrderCard != null) {
        print('Tapping first order card...');
        await tester.tap(firstOrderCard);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 3));
        print('Order detail opened');

        print('📸 Capturing Screenshot 4: Order Detail');
        await binding.takeScreenshot('03_order_detail');

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

      // ========== SCREENSHOT 5: Order Form (Create New OS) ==========
      print('\n--- Screenshot 5: Order Form ---');
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

        print('📸 Capturing Screenshot 5: Order Form');
        await binding.takeScreenshot('04_order_form');

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

      // ========== SCREENSHOT 6: Dynamic Forms (Checklist) ==========
      print('\n--- Screenshot 6: Dynamic Forms ---');
      print('Looking for order cards again...');

      // Find order cards again
      final allSemantics2 = find.byType(Semantics);
      Finder? firstOrderCard2;

      for (var i = 0; i < allSemantics2.evaluate().length; i++) {
        final widget = tester.widget<Semantics>(allSemantics2.at(i));
        final identifier = widget.properties.identifier?.toString() ?? '';
        if (identifier.startsWith('order_card_')) {
          firstOrderCard2 = allSemantics2.at(i);
          print('Found order card: $identifier');
          break;
        }
      }

      print('Order cards found: ${firstOrderCard2 != null ? 1 : 0}');

      if (firstOrderCard2 != null) {
        print('Tapping first order card...');
        await tester.tap(firstOrderCard2);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 3));
        print('Order detail opened');

        // Look for forms/checklist button (icon or text)
        print('Looking for forms button (doc_text_fill icon)...');
        final formsButton = find.byIcon(CupertinoIcons.doc_text_fill);
        print('Found ${formsButton.evaluate().length} forms buttons');

        if (formsButton.evaluate().isNotEmpty) {
          print('Tapping forms button to see forms list...');
          await tester.tap(formsButton.first);
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(seconds: 2));
          print('Forms list opened');

          // Find first form card to tap (should be a filled form)
          print('Looking for first form card...');
          final formCards = find.byType(CupertinoButton);
          print('Found ${formCards.evaluate().length} buttons (potential form cards)');

          // Find a button in the scrollable area (not in navigation bar)
          Finder? firstFormCard;
          for (var i = 0; i < formCards.evaluate().length; i++) {
            try {
              final buttonPos = tester.getTopLeft(formCards.at(i));
              // Form cards should be below navigation bar (>150px from top)
              if (buttonPos.dy > 150) {
                firstFormCard = formCards.at(i);
                print('  ✅ Found form card at position: $buttonPos');
                break;
              }
            } catch (e) {
              // Skip buttons that can't be measured
            }
          }

          if (firstFormCard != null && firstFormCard.evaluate().isNotEmpty) {
            print('Tapping first form card to open filled form...');
            await tester.tap(firstFormCard);
            await tester.pumpAndSettle();
            await Future.delayed(const Duration(seconds: 2));
            print('Form opened');

            // Scroll down a bit to show more form content
            final scrollable = find.byType(SingleChildScrollView);
            if (scrollable.evaluate().isNotEmpty) {
              print('Scrolling form to show more items...');
              await tester.drag(scrollable.first, const Offset(0, -200));
              await tester.pumpAndSettle();
              await Future.delayed(const Duration(seconds: 1));
            }

            print('📸 Capturing Screenshot 6: Dynamic Forms');
            await binding.takeScreenshot('05_forms');

            // Go back three times (from form to forms list, to order detail, to home)
            print('Navigating back to home...');
            final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
            nav.pop(); // form to forms list
            await tester.pumpAndSettle();
            await Future.delayed(const Duration(milliseconds: 500));
            nav.pop(); // forms list to order
            await tester.pumpAndSettle();
            await Future.delayed(const Duration(milliseconds: 500));
            nav.pop(); // order to home
            await tester.pumpAndSettle();
            await Future.delayed(const Duration(seconds: 1));
            print('✅ Back to home');
          } else {
            print('⚠️ No form cards found in list, skipping screenshot 6');
            // Go back twice (from forms list to order, order to home)
            final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
            nav.pop();
            await tester.pumpAndSettle();
            await Future.delayed(const Duration(milliseconds: 500));
            nav.pop();
            await tester.pumpAndSettle();
            await Future.delayed(const Duration(seconds: 1));
          }
        } else {
          // If no forms button found, just go back to home
          print('⚠️ Forms button not found, skipping screenshot 6');
          final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
          nav.pop();
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(seconds: 1));
        }
      } else {
        print('⚠️ No order items found for forms navigation');
      }

      // ========== SCREENSHOT 7: Collaborators (Team Management) ==========
      print('\n--- Screenshot 7: Collaborators ---');
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

          print('📸 Capturing Screenshot 7: Collaborators');
          await binding.takeScreenshot('06_collaborators');

          // Go back to settings
          print('Navigating back to settings...');
          final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
          nav.pop();
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(seconds: 1));
          print('✅ Back to settings');
        } else {
          print('⚠️ Collaborators button not found, skipping screenshot 7');
        }
      } else {
        print('⚠️ Tab bar not found, skipping collaborators');
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
/// Get demo account email based on locale
String _getEmailByLocale(String locale) {
  switch (locale) {
    case 'pt-BR':
      return 'demo-pt@praticos.com.br';
    case 'en-US':
      return 'demo-en@praticos.com.br';
    case 'es-ES':
      return 'demo-es@praticos.com.br';
    default:
      return 'demo@praticos.com.br'; // Fallback
  }
}

/// Get demo account password (same for all locales)
String _getPasswordByLocale(String locale) {
  return 'Demo@2024!';
}

/// Performs login flow with locale-specific demo account
Future<void> _performLogin(WidgetTester tester, String locale) async {
  print('\n=== LOGIN FLOW DEBUG ===');

  final email = _getEmailByLocale(locale);
  final password = _getPasswordByLocale(locale);
  print('Using account: $email');

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
      print('  Entering email: $email');
      await tester.enterText(emailFields.first, email);
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(milliseconds: 500));
      print('  ✅ Email entered');

      // Enter password
      print('Step 4: Entering password...');
      if (emailFields.evaluate().length > 1) {
        await tester.enterText(emailFields.at(1), password);
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

      // Tap login button - scroll down first to ensure it's visible
      print('Step 6: Scrolling down to reveal login button...');
      await tester.drag(find.byType(CupertinoPageScaffold), const Offset(0, -150));
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(milliseconds: 500));
      print('  ✅ Scrolled down');

      print('Step 7: Looking for login button...');

      // Find all CupertinoButtons
      final allButtons = find.byType(CupertinoButton);
      print('  Found ${allButtons.evaluate().length} CupertinoButtons total');

      // The login button should be the last visible filled button in a Padding widget
      // It's wrapped in Padding with horizontal: 20
      Finder? loginButton;

      for (var i = 0; i < allButtons.evaluate().length; i++) {
        final button = allButtons.at(i);
        final widget = tester.widget<CupertinoButton>(button);

        // Check if button child is not an Icon (login button has Text, eye button has Icon)
        final childIsNotIcon = widget.child.runtimeType.toString() != 'Icon';

        print('  Button $i: child type=${widget.child.runtimeType}, color=${widget.color}');

        if (childIsNotIcon) {
          loginButton = button;
          print('  ✅ Found login button at index $i (non-icon child)');
          break;
        }
      }

      if (loginButton != null) {
        print('Step 8: Tapping login button...');
        await tester.ensureVisible(loginButton);
        await tester.tap(loginButton);
        await tester.pumpAndSettle();
        print('  ✅ Login button tapped');

        // Wait for login to complete and data to load
        print('Step 9: Waiting for login to complete...');
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
