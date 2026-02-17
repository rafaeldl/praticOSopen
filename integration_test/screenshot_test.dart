import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:praticos/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Screenshot Tests', () {
    testWidgets('capture all 8 screenshots for App Store', (WidgetTester tester) async {
      // Get locale from environment (default: pt-BR)
      const locale = String.fromEnvironment('TEST_LOCALE', defaultValue: 'pt-BR');

      print('\n========================================');
      print('📱 Starting screenshot tests');
      print('🌍 Locale: $locale');
      print('========================================\n');

      // Always use light mode for screenshots
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;

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

      // ========== SCREENSHOT 7: Login Screen (captured before login) ==========
      print('\n--- Screenshot 7: Login Screen ---');
      print('Waiting for login screen to be ready...');
      await Future.delayed(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      print('📸 Capturing Screenshot 7: Login');
      await binding.takeScreenshot('07_login');

      // ========== LOGIN WITH DEMO ACCOUNT ==========
      print('🔐 Logging in with demo account for locale: $locale...');
      await _performLogin(tester, locale);

      // ========== SCREENSHOT 1: Home (Order List) ==========
      print('\n--- Screenshot 1: Home ---');
      print('Waiting for home screen to load...');
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      print('Home screen loaded');

      // Dismiss WhatsApp setup banner if present
      print('Checking for WhatsApp setup banner...');
      final xmarkIcon = find.byIcon(CupertinoIcons.xmark);
      if (xmarkIcon.evaluate().isNotEmpty) {
        print('Dismissing WhatsApp banner...');
        await tester.tap(xmarkIcon.first);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 1));
        print('✅ WhatsApp banner dismissed');
      }

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

        print('📸 Capturing Screenshot 1: Home');
        await binding.takeScreenshot('01_home');

      // ========== SCREENSHOT 2, 5, 6: Enter OS once and capture Detail, Payments, Forms ==========
      print('\n--- Entering OS to capture Order Detail, Payments, and Forms ---');
      print('Looking for order cards with semantic identifiers...');

      // Find all Semantics widgets and filter for order_card_ identifiers
      final allSemanticsOrder = find.byType(Semantics);
      Finder? orderCard;

      for (var i = 0; i < allSemanticsOrder.evaluate().length; i++) {
        final widget = tester.widget<Semantics>(allSemanticsOrder.at(i));
        final identifier = widget.properties.identifier?.toString() ?? '';
        if (identifier.startsWith('order_card_')) {
          orderCard = allSemanticsOrder.at(i);
          print('Found order card: $identifier');
          break;
        }
      }

      print('Order cards found: ${orderCard != null ? 1 : 0}');

      if (orderCard != null) {
        print('Tapping order card...');
        await tester.tap(orderCard);
        // Order form has continuous Firestore streams/MobX observers
        // that prevent pumpAndSettle from completing.
        // Pump frames to complete the iOS page transition animation (~500ms),
        // then wait for data to load.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        await Future.delayed(const Duration(seconds: 3));
        await tester.pump();
        print('Order detail opened');

          // SCREENSHOT 2: Order Detail (top of screen)
          print('📸 Capturing Screenshot 2: Order Detail');
          await binding.takeScreenshot('02_order_detail');

        // SCREENSHOT 5: Payments (scroll down to payments section)
        print('\n--- Screenshot 5: Payments ---');
        print('Scrolling to payments section...');
        final orderScroll = find.byType(CustomScrollView);
        if (orderScroll.evaluate().isNotEmpty) {
          await tester.drag(orderScroll.first, const Offset(0, -350));
          await Future.delayed(const Duration(seconds: 1));
          await tester.pump();
        }

        // Look for payment button using semantic identifier
        print('Looking for payment button by semantic identifier...');
        final paymentSemantics = find.byType(Semantics);
        Finder? paymentButton;

        for (var i = 0; i < paymentSemantics.evaluate().length; i++) {
          final widget = tester.widget<Semantics>(paymentSemantics.at(i));
          final identifier = widget.properties.identifier?.toString() ?? '';
          if (identifier == 'payment_button') {
            paymentButton = paymentSemantics.at(i);
            print('Found payment button with semantic identifier');
            break;
          }
        }

        if (paymentButton != null) {
          print('Tapping payment button...');
          await tester.tap(paymentButton);
          // Pump frames to complete page transition animation
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 500));
          await Future.delayed(const Duration(seconds: 2));
          await tester.pump();
          print('Payments screen opened');

          print('📸 Capturing Screenshot 5: Payments');
          await binding.takeScreenshot('05_payments');

          // Go back to order detail
          print('Navigating back to order detail...');
          final navPayments = tester.state<NavigatorState>(find.byType(Navigator).first);
          navPayments.pop();
          await Future.delayed(const Duration(seconds: 1));
          await tester.pump();
          print('✅ Back to order detail');
        } else {
          print('⚠️ Could not find payment button, skipping screenshot 5');
        }

        // SCREENSHOT 6: Forms (scroll down further to forms section)
        print('\n--- Screenshot 6: Forms ---');
        print('Scrolling to forms section...');
        final orderScrollForms = find.byType(CustomScrollView);
        if (orderScrollForms.evaluate().isNotEmpty) {
          await tester.drag(orderScrollForms.first, const Offset(0, -400));
          await Future.delayed(const Duration(seconds: 1));
          await tester.pump();
        }

        // Form items have a clock or checkmark icon inside a colored circle.
        // Find form rows by looking for the clock icon (pending forms)
        // or checkmark icon (completed forms), NOT the "Adicione itens" button.
        print('Looking for form items by status icon...');
        Finder? formToTap;

        // Try pending forms first (clock icon)
        final clockIcons = find.byIcon(CupertinoIcons.clock);
        if (clockIcons.evaluate().isNotEmpty) {
          // Find the parent GestureDetector of the first clock icon
          final formRow = find.ancestor(
            of: clockIcons.first,
            matching: find.byType(GestureDetector),
          );
          if (formRow.evaluate().isNotEmpty) {
            formToTap = formRow.first;
            print('  ✅ Found pending form item (clock icon)');
          }
        }

        // Fallback: try completed forms (checkmark icon)
        if (formToTap == null) {
          final checkIcons = find.byIcon(CupertinoIcons.checkmark);
          if (checkIcons.evaluate().isNotEmpty) {
            final formRow = find.ancestor(
              of: checkIcons.first,
              matching: find.byType(GestureDetector),
            );
            if (formRow.evaluate().isNotEmpty) {
              formToTap = formRow.first;
              print('  ✅ Found completed form item (checkmark icon)');
            }
          }
        }

        if (formToTap != null && formToTap.evaluate().isNotEmpty) {
          print('Tapping form item to open it...');
          await tester.tap(formToTap);
          // Pump frames to complete page transition animation
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 500));
          await Future.delayed(const Duration(seconds: 2));
          await tester.pump();
          print('Form opened');

          // Wait for form to fully render (forms can have many fields and images)
          print('Waiting for form to fully render...');
          await Future.delayed(const Duration(seconds: 4));
          await tester.pump();

          print('Form fully rendered, ready to capture');
          print('📸 Capturing Screenshot 6: Forms');
          await binding.takeScreenshot('06_forms');

          // Go back to order detail
          print('Navigating back to order detail...');
          final navForms = tester.state<NavigatorState>(find.byType(Navigator).first);
          navForms.pop();
          await Future.delayed(const Duration(seconds: 1));
          await tester.pump();
          print('✅ Back to order detail');
        } else {
          print('⚠️ Form items not found, skipping screenshot 6');
        }

        // Go back to home
        print('Navigating back to home...');
        final navHome = tester.state<NavigatorState>(find.byType(Navigator).first);
        navHome.pop();
        await Future.delayed(const Duration(seconds: 1));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        print('✅ Back to home');
      } else {
        print('⚠️ No order items found, skipping order detail, payments, and forms screenshots');
      }

      // ========== SCREENSHOT 4: Dashboard (via Financeiro tab) ==========
      print('\n--- Screenshot 4: Dashboard ---');
      print('Looking for financial tab...');

      final allSemanticsTabsForDashboard = find.byType(Semantics);
      Finder? financialTab;

      for (var i = 0; i < allSemanticsTabsForDashboard.evaluate().length; i++) {
        final widget = tester.widget<Semantics>(allSemanticsTabsForDashboard.at(i));
        final identifier = widget.properties.identifier?.toString() ?? '';
        if (identifier == 'tab_financial') {
          financialTab = allSemanticsTabsForDashboard.at(i);
          print('Found financial tab with semantic identifier');
          break;
        }
      }

      if (financialTab != null) {
        print('Tapping financial tab...');
        await tester.tap(financialTab);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 3));
        print('Dashboard opened');

        print('Waiting for dashboard to load data...');
        await Future.delayed(const Duration(seconds: 2));

        print('📸 Capturing Screenshot 4: Dashboard');
        await binding.takeScreenshot('04_dashboard');

        // Navigate back to home tab
        print('Navigating back to home tab...');
        final allSemanticsTabsBackHomeDash = find.byType(Semantics);
        for (var i = 0; i < allSemanticsTabsBackHomeDash.evaluate().length; i++) {
          final widget = tester.widget<Semantics>(allSemanticsTabsBackHomeDash.at(i));
          final identifier = widget.properties.identifier?.toString() ?? '';
          if (identifier == 'tab_home') {
            await tester.tap(allSemanticsTabsBackHomeDash.at(i));
            await tester.pumpAndSettle();
            await Future.delayed(const Duration(seconds: 1));
            print('✅ Back to home tab');
            break;
          }
        }
      } else {
        print('⚠️ Financial tab not found, skipping screenshot 4');
      }

      // ========== SCREENSHOT 3: Agenda ==========
      print('\n--- Screenshot 3: Agenda ---');
      print('Looking for agenda tab...');

      final allSemanticsTabsForAgenda = find.byType(Semantics);
      Finder? agendaTab;

      for (var i = 0; i < allSemanticsTabsForAgenda.evaluate().length; i++) {
        final widget = tester.widget<Semantics>(allSemanticsTabsForAgenda.at(i));
        final identifier = widget.properties.identifier?.toString() ?? '';
        if (identifier == 'tab_agenda') {
          agendaTab = allSemanticsTabsForAgenda.at(i);
          print('Found agenda tab with semantic identifier');
          break;
        }
      }

      if (agendaTab != null) {
        await tester.tap(agendaTab);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 3));
        print('Agenda tab opened');

        print('📸 Capturing Screenshot 3: Agenda');
        await binding.takeScreenshot('03_agenda');

        // Navigate back to home tab
        print('Navigating back to home tab...');
        final allSemanticsTabsBackHome = find.byType(Semantics);
        for (var i = 0; i < allSemanticsTabsBackHome.evaluate().length; i++) {
          final widget = tester.widget<Semantics>(allSemanticsTabsBackHome.at(i));
          final identifier = widget.properties.identifier?.toString() ?? '';
          if (identifier == 'tab_home') {
            await tester.tap(allSemanticsTabsBackHome.at(i));
            await tester.pumpAndSettle();
            await Future.delayed(const Duration(seconds: 1));
            print('✅ Back to home tab');
            break;
          }
        }
      } else {
        print('⚠️ Agenda tab not found, skipping screenshot 3');
      }

      // ========== SCREENSHOT 9: Segments Screen (Onboarding) ==========
      print('\n--- Screenshot 9: Segments Screen ---');
      print('Navigating to settings to trigger re-onboarding...');

      // Go to settings tab using semantic identifier
      print('Looking for settings tab...');
      final allSemanticsTabsForSegments = find.byType(Semantics);
      Finder? settingsTabForSegments;

      for (var i = 0; i < allSemanticsTabsForSegments.evaluate().length; i++) {
        final widget = tester.widget<Semantics>(allSemanticsTabsForSegments.at(i));
        final identifier = widget.properties.identifier?.toString() ?? '';
        if (identifier == 'tab_settings') {
          settingsTabForSegments = allSemanticsTabsForSegments.at(i);
          print('Found settings tab with semantic identifier');
          break;
        }
      }

      if (settingsTabForSegments != null) {
        await tester.tap(settingsTabForSegments);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 1));
        print('Settings tab opened');

        // Find "Reopen Onboarding" button using semantic identifier
        print('Looking for Reopen Onboarding button by semantic identifier...');
        final allSemanticsForReopen = find.byType(Semantics);
        Finder? reopenButton;

        for (var i = 0; i < allSemanticsForReopen.evaluate().length; i++) {
          final widget = tester.widget<Semantics>(allSemanticsForReopen.at(i));
          final identifier = widget.properties.identifier?.toString() ?? '';
          if (identifier == 'reopen_onboarding_button') {
            reopenButton = allSemanticsForReopen.at(i);
            print('  ✅ Found reopen onboarding button with semantic identifier');
            break;
          }
        }

        if (reopenButton != null) {
          print('Tapping Reopen Onboarding button...');
          await tester.tap(reopenButton);
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(seconds: 2));
          print('Company Info screen opened');

          // Navigate through onboarding: Company Info -> Company Contact -> Segments

          // Step 1: Company Info Screen - tap "Next" button using semantic identifier
          print('Step 1: Looking for Next button in Company Info by semantic identifier...');
          final allSemanticsInfo = find.byType(Semantics);
          Finder? nextButton1;

          for (var i = 0; i < allSemanticsInfo.evaluate().length; i++) {
            final widget = tester.widget<Semantics>(allSemanticsInfo.at(i));
            final identifier = widget.properties.identifier?.toString() ?? '';
            if (identifier == 'next_button_company_info') {
              nextButton1 = allSemanticsInfo.at(i);
              print('  ✅ Found Next button (Company Info) with semantic identifier');
              break;
            }
          }

          if (nextButton1 != null) {
            print('Tapping Next button (Company Info)...');
            await tester.tap(nextButton1);
            await tester.pumpAndSettle();
            await Future.delayed(const Duration(seconds: 2));
            print('Company Contact screen opened');

            // Step 2: Company Contact Screen - tap "Next" button using semantic identifier
            print('Step 2: Looking for Next button in Company Contact by semantic identifier...');
            final allSemanticsContact = find.byType(Semantics);
            Finder? nextButton2;

            for (var i = 0; i < allSemanticsContact.evaluate().length; i++) {
              final widget = tester.widget<Semantics>(allSemanticsContact.at(i));
              final identifier = widget.properties.identifier?.toString() ?? '';
              if (identifier == 'next_button_company_contact') {
                nextButton2 = allSemanticsContact.at(i);
                print('  ✅ Found Next button (Company Contact) with semantic identifier');
                break;
              }
            }

            if (nextButton2 != null) {
              print('Tapping Next button (Company Contact)...');
              await tester.tap(nextButton2);
              await tester.pumpAndSettle();
              await Future.delayed(const Duration(seconds: 2));
              print('Segments screen opened!');

              // Now we're on the Segments screen - capture it!
              print('Waiting for segments screen to fully load...');
              await Future.delayed(const Duration(seconds: 2));

              print('📸 Capturing Screenshot 9: Segments Screen');
              await binding.takeScreenshot('09_segments');

              print('✅ Segments screenshot captured');
            } else {
              print('⚠️ Next button not found in Company Contact screen');
            }
          } else {
            print('⚠️ Next button not found in Company Info screen');
          }
        } else {
          print('⚠️ Reopen Onboarding button not found, skipping segments screenshot');
        }
      } else {
        print('⚠️ Settings tab not found, skipping segments screenshot');
      }

      print('\n✅ All screenshots captured successfully (locale: $locale)');
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
