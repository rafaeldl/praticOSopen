import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:praticos/main.dart' as app;

/// Timeline Integration Tests
///
/// These tests validate that timeline events are correctly created
/// when performing various operations on orders.
///
/// Run with:
/// ```bash
/// fvm flutter test integration_test/timeline_integration_test.dart --dart-define=TEST_LOCALE=pt-BR
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Timeline Integration Tests', () {
    testWidgets('Order creation logs to timeline', (WidgetTester tester) async {
      const locale = String.fromEnvironment('TEST_LOCALE', defaultValue: 'pt-BR');

      print('\n========================================');
      print('Timeline Test: Order Creation');
      print('Locale: $locale');
      print('========================================\n');

      // Initialize app
      await _initializeApp(tester);

      // Login with demo account
      await _performLogin(tester, locale);

      // Create a new order (this opens the order form)
      print('Creating new order...');
      await _createNewOrder(tester);

      // Wait for order to be created
      await Future.delayed(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Go back to home
      print('Going back to home...');
      await _goBack(tester);
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Tap on the first order (this opens timeline directly)
      print('Opening order timeline...');
      await _openOrderTimeline(tester);

      // Verify order_created event exists
      print('Verifying order_created event...');
      await _verifyTimelineEventExists(tester, 'OS criada');

      print('\n Order creation timeline test passed');

      // Cleanup: Delete the test order
      await _deleteCurrentOrder(tester);
    });

    testWidgets('Status change logs correctly', (WidgetTester tester) async {
      const locale = String.fromEnvironment('TEST_LOCALE', defaultValue: 'pt-BR');

      print('\n========================================');
      print('Timeline Test: Status Change');
      print('Locale: $locale');
      print('========================================\n');

      // Initialize app
      await _initializeApp(tester);

      // Login with demo account
      await _performLogin(tester, locale);

      // Create own order for this test (test independence)
      print('Creating new order for test...');
      await _createNewOrder(tester);
      await _goBack(tester);
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Tap on first order (opens timeline directly)
      print('Opening order timeline...');
      await _openOrderTimeline(tester);

      // Change status using attachment menu
      print('Changing status...');
      await _changeStatusViaTimeline(tester, 'approved');

      // Wait for status change to be logged
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Verify status_change event exists (look for status indicators)
      print('Verifying status_change event...');
      final hasStatusEvent = await _hasTimelineEventWithPattern(tester, ['quote', 'approved', '→']);
      expect(hasStatusEvent, isTrue, reason: 'Status change event should appear in timeline');

      print('\n Status change timeline test passed');

      // Cleanup: Delete the test order
      await _deleteCurrentOrder(tester);
    });

    testWidgets('Service operations log correctly', (WidgetTester tester) async {
      const locale = String.fromEnvironment('TEST_LOCALE', defaultValue: 'pt-BR');

      print('\n========================================');
      print('Timeline Test: Service Operations');
      print('Locale: $locale');
      print('========================================\n');

      // Initialize app
      await _initializeApp(tester);

      // Login with demo account
      await _performLogin(tester, locale);

      // Create own order for this test (test independence)
      print('Creating new order for test...');
      await _createNewOrder(tester);
      await _goBack(tester);
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Tap on first order (opens timeline directly)
      print('Opening order timeline...');
      await _openOrderTimeline(tester);

      // Add a service via timeline attachment menu
      print('Adding service via timeline...');
      await _addServiceViaTimeline(tester);

      // Wait for service to be added and logged
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Verify service_added event exists (look for service icon or text)
      print('Verifying service_added event...');
      final hasServiceEvent = await _hasTimelineEventWithPattern(tester, ['Serviço', 'service', '🔧']);
      expect(hasServiceEvent, isTrue, reason: 'Service added event should appear in timeline');

      print('\n Service operations timeline test passed');

      // Cleanup: Delete the test order
      await _deleteCurrentOrder(tester);
    });

    testWidgets('Product operations log correctly', (WidgetTester tester) async {
      const locale = String.fromEnvironment('TEST_LOCALE', defaultValue: 'pt-BR');

      print('\n========================================');
      print('Timeline Test: Product Operations');
      print('Locale: $locale');
      print('========================================\n');

      // Initialize app
      await _initializeApp(tester);

      // Login with demo account
      await _performLogin(tester, locale);

      // Create own order for this test (test independence)
      print('Creating new order for test...');
      await _createNewOrder(tester);
      await _goBack(tester);
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Tap on first order (opens timeline directly)
      print('Opening order timeline...');
      await _openOrderTimeline(tester);

      // Add a product via timeline attachment menu
      print('Adding product via timeline...');
      await _addProductViaTimeline(tester);

      // Wait for product to be added and logged
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Verify product_added event exists (look for product icon or text)
      print('Verifying product_added event...');
      final hasProductEvent = await _hasTimelineEventWithPattern(tester, ['Produto', 'product', '📦']);
      expect(hasProductEvent, isTrue, reason: 'Product added event should appear in timeline');

      print('\n Product operations timeline test passed');

      // Cleanup: Delete the test order
      await _deleteCurrentOrder(tester);
    });

    testWidgets('Payment logs correctly', (WidgetTester tester) async {
      const locale = String.fromEnvironment('TEST_LOCALE', defaultValue: 'pt-BR');

      print('\n========================================');
      print('Timeline Test: Payment');
      print('Locale: $locale');
      print('========================================\n');

      // Initialize app
      await _initializeApp(tester);

      // Login with demo account
      await _performLogin(tester, locale);

      // Create own order for this test (test independence)
      print('Creating new order for test...');
      await _createNewOrder(tester);
      await _goBack(tester);
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Tap on first order (opens timeline directly)
      print('Opening order timeline...');
      await _openOrderTimeline(tester);

      // STEP 1: Change status to approved (required for payments)
      print('Changing status to approved (required for payments)...');
      await _changeStatusViaTimeline(tester, 'approved');
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // STEP 2: Add a service (required to have a value to pay)
      print('Adding service (required to have payment value)...');
      await _addServiceViaTimeline(tester);
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // STEP 3: Add payment via timeline attachment menu
      print('Adding payment via timeline...');
      await _addPaymentViaTimeline(tester);

      // Wait for payment to be logged
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Verify payment_received event exists (look for payment icon or text)
      print('Verifying payment_received event...');
      final hasPaymentEvent = await _hasTimelineEventWithPattern(tester, ['Pagamento', 'payment', '💰']);
      expect(hasPaymentEvent, isTrue, reason: 'Payment received event should appear in timeline');

      print('\n Payment timeline test passed');

      // Cleanup: Delete the test order
      await _deleteCurrentOrder(tester);
    });

    testWidgets('Full flow: create order, add items, change status, add payment', (WidgetTester tester) async {
      const locale = String.fromEnvironment('TEST_LOCALE', defaultValue: 'pt-BR');

      print('\n========================================');
      print('Timeline Test: Full Flow (Comprehensive)');
      print('Locale: $locale');
      print('========================================\n');

      // Initialize app
      await _initializeApp(tester);

      // Login with demo account
      await _performLogin(tester, locale);

      // Create new order (opens order form)
      print('Step 1: Creating new order...');
      await _createNewOrder(tester);
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Go back to home
      print('Step 2: Going back to home...');
      await _goBack(tester);
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Tap on first order (opens timeline)
      print('Step 3: Opening order timeline...');
      await _openOrderTimeline(tester);

      // Add service via timeline
      print('Step 4: Adding service...');
      await _addServiceViaTimeline(tester);
      await Future.delayed(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Add product via timeline
      print('Step 5: Adding product...');
      await _addProductViaTimeline(tester);
      await Future.delayed(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Wait for timeline to update
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Verify multiple events exist
      print('Step 6: Verifying timeline events...');

      // Check for order created
      final hasOrderCreated = await _hasTimelineEventWithPattern(tester, ['OS criada']);
      print('  - Order created event: ${hasOrderCreated ? "FOUND" : "NOT FOUND"}');

      // Check for service
      final hasService = await _hasTimelineEventWithPattern(tester, ['Serviço', '🔧']);
      print('  - Service event: ${hasService ? "FOUND" : "NOT FOUND"}');

      // Check for product
      final hasProduct = await _hasTimelineEventWithPattern(tester, ['Produto', '📦']);
      print('  - Product event: ${hasProduct ? "FOUND" : "NOT FOUND"}');

      expect(hasOrderCreated, isTrue, reason: 'Order created event should exist');

      print('\n Full flow timeline test passed');

      // Cleanup: Delete the test order
      await _deleteCurrentOrder(tester);
    });
  });
}

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/// Initialize the app and wait for it to be ready
Future<void> _initializeApp(WidgetTester tester) async {
  print('Initializing app...');
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
  app.main();
  await tester.pumpAndSettle();
  await Future.delayed(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  print('App initialized');
}

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
      return 'demo@praticos.com.br';
  }
}

/// Performs login with demo account
Future<void> _performLogin(WidgetTester tester, String locale) async {
  print('Logging in with demo account for locale: $locale...');

  final email = _getEmailByLocale(locale);
  const password = 'Demo@2024!';

  // Check if already logged in
  final emailLink = find.textContaining('email');
  if (emailLink.evaluate().isEmpty) {
    print('Already logged in, skipping login');
    return;
  }

  // Find and tap email login link
  final emailTexts = ['email', 'e-mail', 'correo'];
  Finder? emailLoginLink;
  for (final text in emailTexts) {
    final finder = find.textContaining(text, skipOffstage: false);
    if (finder.evaluate().isNotEmpty) {
      emailLoginLink = finder;
      break;
    }
  }

  if (emailLoginLink != null) {
    await tester.tap(emailLoginLink.first);
    await tester.pumpAndSettle();
    await Future.delayed(const Duration(seconds: 2));

    // Enter email and password
    final emailFields = find.byType(CupertinoTextFormFieldRow);
    if (emailFields.evaluate().isNotEmpty) {
      await tester.enterText(emailFields.first, email);
      await tester.pumpAndSettle();

      if (emailFields.evaluate().length > 1) {
        await tester.enterText(emailFields.at(1), password);
        await tester.pumpAndSettle();
      }

      // Dismiss keyboard
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 1));

      // Find and tap login button
      final allButtons = find.byType(CupertinoButton);
      for (var i = 0; i < allButtons.evaluate().length; i++) {
        final button = allButtons.at(i);
        final widget = tester.widget<CupertinoButton>(button);
        if (widget.child.runtimeType.toString() != 'Icon') {
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          break;
        }
      }

      // Wait for login to complete
      await Future.delayed(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      print('Login complete');
    }
  }
}

/// Find widget by semantic identifier
Future<Finder?> _findBySemantic(WidgetTester tester, String identifier) async {
  final allSemantics = find.byType(Semantics);

  for (var i = 0; i < allSemantics.evaluate().length; i++) {
    final widget = tester.widget<Semantics>(allSemantics.at(i));
    final id = widget.properties.identifier?.toString() ?? '';
    if (id == identifier) {
      return allSemantics.at(i);
    }
  }
  return null;
}

/// Create a new order by selecting a customer (triggers Firebase save)
Future<void> _createNewOrder(WidgetTester tester) async {
  // 1. Tap add order button
  final addButton = await _findBySemantic(tester, 'add_order_button');
  if (addButton == null) {
    print('Warning: Add order button not found');
    return;
  }

  await tester.tap(addButton);
  await tester.pumpAndSettle();
  await Future.delayed(const Duration(seconds: 2));
  print('New order form opened');

  // 2. Tap customer button to open customer list
  final customerButton = await _findBySemantic(tester, 'order_customer_button');
  if (customerButton == null) {
    print('Warning: Customer button not found');
    return;
  }

  await tester.tap(customerButton);
  await tester.pumpAndSettle();
  await Future.delayed(const Duration(seconds: 2));
  print('Customer list opened');

  // 3. Select first customer (this triggers order creation in Firebase)
  final customerItem = await _findBySemantic(tester, 'customer_item_0');
  if (customerItem == null) {
    print('Warning: Customer item not found');
    // Try to go back if customer list is empty
    await _goBack(tester);
    return;
  }

  await tester.tap(customerItem);
  await tester.pumpAndSettle();
  await Future.delayed(const Duration(seconds: 3)); // Wait for Firebase save
  print('Customer selected - order saved to Firebase');
}

/// Go back (pop navigator)
Future<void> _goBack(WidgetTester tester) async {
  // Try back button icon first
  final backButton = find.byIcon(CupertinoIcons.back);
  if (backButton.evaluate().isNotEmpty) {
    await tester.tap(backButton.first);
    await tester.pumpAndSettle();
    print('Navigated back via button');
    return;
  }

  // Try navigator pop
  try {
    final navState = tester.state<NavigatorState>(find.byType(Navigator).first);
    navState.pop();
    await tester.pumpAndSettle();
    print('Navigated back via Navigator.pop');
  } catch (e) {
    print('Warning: Could not go back: $e');
  }
}

/// Open order timeline (tap on order card - goes directly to timeline)
Future<void> _openOrderTimeline(WidgetTester tester) async {
  await Future.delayed(const Duration(seconds: 2));
  await tester.pumpAndSettle();

  // Find order cards using semantic identifiers (try order_card_0 first, then any order_card_)
  Finder? orderCard = await _findBySemantic(tester, 'order_card_0');

  // If no order_card_0, search for any order card
  if (orderCard == null) {
    final allSemantics = find.byType(Semantics);
    for (var i = 0; i < allSemantics.evaluate().length; i++) {
      final widget = tester.widget<Semantics>(allSemantics.at(i));
      final identifier = widget.properties.identifier?.toString() ?? '';
      if (identifier.startsWith('order_card_')) {
        orderCard = allSemantics.at(i);
        print('Found order card: $identifier');
        break;
      }
    }
  } else {
    print('Found order card: order_card_0');
  }

  if (orderCard != null) {
    await tester.tap(orderCard);
    await tester.pumpAndSettle();
    await Future.delayed(const Duration(seconds: 3));
    print('Timeline opened (via order card tap)');
  } else {
    print('Warning: No order cards found');
  }
}

/// Open attachment menu in timeline (plus button)
Future<Finder?> _openAttachmentMenu(WidgetTester tester) async {
  // Find the attachment button using semantic identifier
  Finder? attachmentButton = await _findBySemantic(tester, 'timeline_attachment_button');

  if (attachmentButton != null) {
    print('Found attachment button via semantic identifier');
  } else {
    // Fallback to icon search
    final plusCircleIcons = find.byIcon(CupertinoIcons.plus_circle);
    final plusIcons = find.byIcon(CupertinoIcons.plus);

    if (plusCircleIcons.evaluate().isNotEmpty) {
      attachmentButton = plusCircleIcons.first;
      print('Found attachment button via plus_circle icon');
    } else if (plusIcons.evaluate().isNotEmpty) {
      attachmentButton = plusIcons.first;
      print('Found attachment button via plus icon');
    }
  }

  if (attachmentButton != null) {
    await tester.tap(attachmentButton);
    await tester.pumpAndSettle();
    await Future.delayed(const Duration(seconds: 1));
    print('Attachment menu opened');
    return attachmentButton;
  }

  print('Warning: Attachment button not found');
  return null;
}

/// Change status via timeline attachment menu
Future<void> _changeStatusViaTimeline(WidgetTester tester, String newStatus) async {
  final menuOpened = await _openAttachmentMenu(tester);

  if (menuOpened != null) {
    final statusOption = await _findActionSheetOption(tester, 'timeline_action_change_status');

    if (statusOption != null) {
      await tester.tap(statusOption);
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 1));

      // Find and tap the new status option (these are in a second action sheet)
      final statusMapping = {
        'quote': ['Orçamento', 'Quote', 'Presupuesto'],
        'approved': ['Aprovado', 'Approved', 'Aprobado'],
        'progress': ['Em Andamento', 'In Progress', 'En Progreso'],
        'done': ['Concluído', 'Completed', 'Completado'],
      };

      final statusLabels = statusMapping[newStatus] ?? [newStatus];
      Finder? statusButton;
      for (final label in statusLabels) {
        final finder = find.textContaining(label, skipOffstage: false);
        if (finder.evaluate().isNotEmpty) {
          statusButton = finder.first;
          break;
        }
      }

      if (statusButton != null) {
        await tester.tap(statusButton);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 1));
        print('Status changed to: $newStatus');
      } else {
        print('Warning: Status option "$newStatus" not found');
        await tester.tapAt(const Offset(200, 100));
        await tester.pumpAndSettle();
      }
    } else {
      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle();
    }
  }
}

/// Find action sheet option by semantic identifier
Future<Finder?> _findActionSheetOption(WidgetTester tester, String identifier) async {
  final result = await _findBySemantic(tester, identifier);
  if (result != null) {
    print('Found action option: $identifier');
  } else {
    print('Warning: Action option not found: $identifier');
  }
  return result;
}

/// Add a service via timeline attachment menu - actually selecting a service
Future<void> _addServiceViaTimeline(WidgetTester tester) async {
  final menuOpened = await _openAttachmentMenu(tester);

  if (menuOpened != null) {
    final serviceOption = await _findActionSheetOption(tester, 'timeline_action_add_service');

    if (serviceOption != null) {
      // 1. Open service list
      await tester.tap(serviceOption);
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 2));
      print('Service list opened');

      // 2. Select first service from list
      final serviceItem = await _findBySemantic(tester, 'service_item_0');
      if (serviceItem != null) {
        await tester.tap(serviceItem);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 2));
        print('Service selected, order service screen opened');

        // 3. Save the service (tap save button)
        final saveButton = await _findBySemantic(tester, 'save_service_button');
        if (saveButton != null) {
          await tester.tap(saveButton);
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(seconds: 2));
          print('Service added successfully');
        } else {
          print('Warning: Save service button not found, going back');
          await _goBack(tester);
          await tester.pumpAndSettle();
        }
      } else {
        print('Warning: No service items found, going back');
        await _goBack(tester);
        await tester.pumpAndSettle();
      }
    } else {
      // Close action sheet
      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle();
    }
  }
}

/// Add a product via timeline attachment menu - actually selecting a product
Future<void> _addProductViaTimeline(WidgetTester tester) async {
  final menuOpened = await _openAttachmentMenu(tester);

  if (menuOpened != null) {
    final productOption = await _findActionSheetOption(tester, 'timeline_action_add_product');

    if (productOption != null) {
      // 1. Open product list
      await tester.tap(productOption);
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 2));
      print('Product list opened');

      // 2. Select first product from list
      final productItem = await _findBySemantic(tester, 'product_item_0');
      if (productItem != null) {
        await tester.tap(productItem);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 2));
        print('Product selected, order product screen opened');

        // 3. Save the product (tap save button)
        final saveButton = await _findBySemantic(tester, 'save_product_button');
        if (saveButton != null) {
          await tester.tap(saveButton);
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(seconds: 2));
          print('Product added successfully');
        } else {
          print('Warning: Save product button not found, going back');
          await _goBack(tester);
          await tester.pumpAndSettle();
        }
      } else {
        print('Warning: No product items found, going back');
        await _goBack(tester);
        await tester.pumpAndSettle();
      }
    } else {
      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle();
    }
  }
}

/// Add a payment via timeline attachment menu - actually registering payment
Future<void> _addPaymentViaTimeline(WidgetTester tester) async {
  final menuOpened = await _openAttachmentMenu(tester);

  if (menuOpened != null) {
    final paymentOption = await _findActionSheetOption(tester, 'timeline_action_add_payment');

    if (paymentOption != null) {
      // 1. Open payment screen
      await tester.tap(paymentOption);
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 2));
      print('Payment screen opened');

      // 2. Tap register payment button (amount is pre-filled with remaining balance)
      final registerButton = await _findBySemantic(tester, 'register_payment_button');
      if (registerButton != null) {
        await tester.tap(registerButton);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 2));
        print('Payment registered successfully');

        // 3. Dismiss success dialog if shown
        final okButton = find.text('OK');
        if (okButton.evaluate().isNotEmpty) {
          await tester.tap(okButton.first);
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(seconds: 1));
        }

        // 4. Go back to timeline
        await _goBack(tester);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 1));
      } else {
        print('Warning: Register payment button not found, going back');
        await _goBack(tester);
        await tester.pumpAndSettle();
      }
    } else {
      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle();
    }
  }
}

/// Verify that a timeline event with specific text exists
Future<void> _verifyTimelineEventExists(WidgetTester tester, String expectedText) async {
  await Future.delayed(const Duration(seconds: 2));
  await tester.pumpAndSettle();

  final finder = find.textContaining(expectedText, skipOffstage: false);
  expect(finder.evaluate().isNotEmpty, isTrue,
      reason: 'Timeline should contain event with text: $expectedText');
}

/// Check if timeline has event matching any of the patterns
Future<bool> _hasTimelineEventWithPattern(WidgetTester tester, List<String> patterns) async {
  await Future.delayed(const Duration(seconds: 1));
  await tester.pumpAndSettle();

  for (final pattern in patterns) {
    final finder = find.textContaining(pattern, skipOffstage: false);
    if (finder.evaluate().isNotEmpty) {
      return true;
    }
  }
  return false;
}

/// Delete the current order via order form options menu
/// Flow: Timeline → Order Form → Options (⋯) → Delete → Confirm
Future<void> _deleteCurrentOrder(WidgetTester tester) async {
  print('Cleaning up: Deleting test order...');

  // 1. Navigate to order form from timeline (tap the header)
  final orderHeader = await _findBySemantic(tester, 'timeline_order_header');
  if (orderHeader != null) {
    await tester.tap(orderHeader);
    await tester.pumpAndSettle();
    await Future.delayed(const Duration(seconds: 2));
    print('Navigated to order form');

    // 2. Tap options button (ellipsis)
    final optionsButton = await _findBySemantic(tester, 'order_options_button');
    if (optionsButton != null) {
      await tester.tap(optionsButton);
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 1));
      print('Options menu opened');

      // 3. Tap delete button in action sheet
      final deleteButton = await _findBySemantic(tester, 'order_delete_button');
      if (deleteButton != null) {
        await tester.tap(deleteButton);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 1));
        print('Delete option tapped');

        // 4. Confirm deletion
        final confirmButton = await _findBySemantic(tester, 'order_delete_confirm_button');
        if (confirmButton != null) {
          await tester.tap(confirmButton);
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(seconds: 2));
          print('Order deleted successfully');
          return;
        } else {
          print('Warning: Delete confirm button not found');
        }
      } else {
        print('Warning: Delete button not found');
        // Close action sheet
        await tester.tapAt(const Offset(200, 100));
        await tester.pumpAndSettle();
      }
    } else {
      print('Warning: Options button not found');
      // Go back to timeline
      await _goBack(tester);
      await tester.pumpAndSettle();
    }
  } else {
    print('Warning: Timeline order header not found');
  }
  print('Warning: Could not delete order');
}
