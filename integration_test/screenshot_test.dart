import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show InkWell, Navigator, NavigatorState, Icon;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:praticos/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Screenshot Tests', () {
    testWidgets('capture all 7 screenshots for Play Store', (WidgetTester tester) async {
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
        
        // Find CupertinoTabBar and tap third item (Settings)
        final tabBar = find.byType(CupertinoTabBar);
        if (tabBar.evaluate().isNotEmpty) {
          final tabBarBox = tester.getRect(tabBar);
          // 3 tabs: 0-1/3 (Home), 1/3-2/3 (Customers), 2/3-1 (Settings)
          final settingsTabX = tabBarBox.left + (tabBarBox.width / 3) * 2.5;
          final tabY = tabBarBox.center.dy;
          
          await tester.tapAt(Offset(settingsTabX, tabY));
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(seconds: 2));

          // Find "Sair" button in Settings
          final logoutTile = find.text('Sair');
          if (logoutTile.evaluate().isNotEmpty) {
            await tester.tap(logoutTile.first);
            await tester.pumpAndSettle();
            await Future.delayed(const Duration(seconds: 1));

            // Confirm logout in CupertinoAlertDialog
            final confirmButton = find.descendant(
              of: find.byType(CupertinoAlertDialog),
              matching: find.text('Sair'),
            );
            
            if (confirmButton.evaluate().isNotEmpty) {
              await tester.tap(confirmButton.last); // Usually the action button is the last one
              await tester.pumpAndSettle();
              print('✅ Logged out successfully');
              
              // Wait for login page to appear
              await Future.delayed(const Duration(seconds: 3));
              await tester.pumpAndSettle();
            }
          }
        }
      }

      // Android specific: Enable screenshot capture
      await binding.convertFlutterSurfaceToImage();

      // ========== SCREENSHOT 1: Login ==========
      print('📸 Capturing Screenshot 1: Login');
      // Wait extra time for the logo and assets to decode and render clearly
      await Future.delayed(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('1_login');

      // ========== LOGIN WITH DEMO ACCOUNT ==========
      print('🔐 Logging in with demo account...');

      // Find and tap "Entrar com email" link
      final emailLinkByText = find.textContaining('email', skipOffstage: false);
      if (emailLinkByText.evaluate().isNotEmpty) {
        await tester.tap(emailLinkByText.first);
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

        // Dismiss keyboard to reveal login button
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 1));

        // Tap login button
        final loginButton = find.text('Entrar');
        await tester.ensureVisible(loginButton.first); // Ensure it's in view
        await tester.tap(loginButton.first);
        await tester.pumpAndSettle();

        // Wait for login to complete and data to load
        print('⏳ Waiting for login and data load...');
        await Future.delayed(const Duration(seconds: 10)); // Increased from 8 to 10
        await tester.pumpAndSettle();

        // Ensure orders are loaded (wait for possible loading indicators to disappear)
        final loadingIndicator = find.byType(CupertinoActivityIndicator);
        if (loadingIndicator.evaluate().isNotEmpty) {
          print('⏳ Still loading data, waiting more...');
          await Future.delayed(const Duration(seconds: 5));
          await tester.pumpAndSettle();
        }
      }

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

        // Go back using Navigator pop
        final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
        navigator.pop();
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 1));
      }

      // ========== SCREENSHOT 4: Dashboard ==========
      print('📸 Navigating to Dashboard...');
      await tester.pumpAndSettle();

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
            final anoButton = find.text('Ano');
            if (anoButton.evaluate().isNotEmpty) {
              await tester.tap(anoButton);
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

            print('📸 Capturing Screenshot 4: Dashboard');
            await binding.takeScreenshot('4_dashboard');

            // Go back
            final backNav = tester.state<NavigatorState>(find.byType(Navigator).first);
            backNav.pop();
            await tester.pumpAndSettle();
            await Future.delayed(const Duration(seconds: 1));
            break;
          }
        }
      }

      // ========== SCREENSHOT 5: Customers ==========
      print('📸 Navigating to Customers tab...');
      await tester.pumpAndSettle();

      // Find CupertinoTabBar and tap second item (Clientes)
      final tabBar = find.byType(CupertinoTabBar);
      if (tabBar.evaluate().isNotEmpty) {
        // Get the tab bar widget to find its position
        final tabBarBox = tester.getRect(tabBar);

        // Calculate tap position for second tab (Clientes) - middle of second third
        final secondTabX = tabBarBox.left + (tabBarBox.width / 3) * 1.5;
        final tabY = tabBarBox.center.dy;

        await tester.tapAt(Offset(secondTabX, tabY));
        await tester.pumpAndSettle();

        // Wait longer for customers to load from Firebase
        print('⏳ Waiting for customers to load...');
        await Future.delayed(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        print('📸 Capturing Screenshot 5: Customers');
        await binding.takeScreenshot('5_customers');

        // ========== SCREENSHOT 6: Customer Detail (filtered orders) ==========
        print('📸 Selecting a customer for filtered view...');

        // Wait more for list to be ready
        await Future.delayed(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        final customerItems = find.byType(InkWell);
        print('Found ${customerItems.evaluate().length} customer items');
        if (customerItems.evaluate().isNotEmpty) {
          await tester.tap(customerItems.first);
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(seconds: 3));

          print('📸 Capturing Screenshot 6: Customer Detail (filtered orders)');
          await binding.takeScreenshot('6_customer_detail');
        } else {
          print('⚠️ No customer items found to tap');
        }

        // ========== SCREENSHOT 7: Settings ==========
        print('📸 Navigating to Settings tab...');

        // Tap third tab (Mais/Settings)
        final thirdTabX = tabBarBox.left + (tabBarBox.width / 3) * 2.5;
        await tester.tapAt(Offset(thirdTabX, tabY));
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 2));

        print('📸 Capturing Screenshot 7: Settings');
        await binding.takeScreenshot('7_settings');
      }

      print('✅ All screenshots captured successfully!');
    });
  });
}
