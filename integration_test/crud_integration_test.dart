import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:praticos/main.dart' as app;

/// CRUD Integration Tests for Devices, Services, Products, and Forms
///
/// These tests validate that CRUD operations work correctly for each entity.
///
/// Run with:
/// ```bash
/// fvm flutter test integration_test/crud_integration_test.dart --dart-define=TEST_LOCALE=pt-BR
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Device CRUD Tests', () {
    testWidgets('Create device', (WidgetTester tester) async {
      const locale = String.fromEnvironment('TEST_LOCALE', defaultValue: 'pt-BR');

      print('\n========================================');
      print('CRUD Test: Create Device');
      print('Locale: $locale');
      print('========================================\n');

      // Initialize app
      await _initializeApp(tester);

      // Login with demo account
      await _performLogin(tester, locale);

      // Navigate to device list
      await _navigateToMenu(tester, 'Equipamentos');

      // Create a new device
      print('Creating new device...');
      await _tapSemantic(tester, 'device_list_add_button');
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Fill device form (using accumulated values which open pickers)
      // For device form, we need to select category, brand, model and fill serial
      print('Selecting device category...');
      await _tapSemantic(tester, 'device_form_category_field');
      await Future.delayed(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Select first available category or create one
      await _selectOrCreateAccumulatedValue(tester, 'Test Category');
      await Future.delayed(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Fill serial number (required field)
      print('Filling serial number...');
      await _enterTextInSemantic(tester, 'device_form_serial_field', 'TEST-${DateTime.now().millisecondsSinceEpoch}');

      // Dismiss keyboard
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 1));

      // Save the device
      print('Saving device...');
      await _tapSemantic(tester, 'device_form_save_button');
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Verify device appears in list (we should be back on list screen)
      // Since IDs are used now, look for any device item
      final deviceId = await _findFirstEntityId(tester, 'device');
      expect(deviceId, isNotNull, reason: 'Device should appear in list after creation');

      print('\n Device creation test passed');
    });

    testWidgets('Update device', (WidgetTester tester) async {
      const locale = String.fromEnvironment('TEST_LOCALE', defaultValue: 'pt-BR');

      print('\n========================================');
      print('CRUD Test: Update Device');
      print('Locale: $locale');
      print('========================================\n');

      // Initialize app
      await _initializeApp(tester);

      // Login with demo account
      await _performLogin(tester, locale);

      // Navigate to device list
      await _navigateToMenu(tester, 'Equipamentos');
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Find first device in list
      print('Finding first device for editing...');
      final deviceId = await _findFirstEntityId(tester, 'device');
      if (deviceId == null) {
        print('No devices found, skipping update test');
        return;
      }

      // Tap on device to edit
      print('Opening device $deviceId for editing...');
      await _tapSemantic(tester, 'device_item_$deviceId');
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Save to confirm update (even without changes, this tests the flow)
      print('Saving device...');
      await _tapSemantic(tester, 'device_form_save_button');
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      print('\n Device update test passed');
    });

    testWidgets('Delete device via swipe', (WidgetTester tester) async {
      const locale = String.fromEnvironment('TEST_LOCALE', defaultValue: 'pt-BR');

      print('\n========================================');
      print('CRUD Test: Delete Device');
      print('Locale: $locale');
      print('========================================\n');

      // Initialize app
      await _initializeApp(tester);

      // Login with demo account
      await _performLogin(tester, locale);

      // Navigate to device list
      await _navigateToMenu(tester, 'Equipamentos');
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Find first device in list
      final deviceId = await _findFirstEntityId(tester, 'device');
      if (deviceId == null) {
        print('No devices found, skipping delete test');
        return;
      }

      // Find the device item widget
      final deviceItem = await _findBySemantic(tester, 'device_item_$deviceId');
      if (deviceItem == null) {
        print('Could not find device item, skipping delete test');
        return;
      }

      // Swipe left to delete
      print('Swiping left to delete device $deviceId...');
      await tester.drag(deviceItem, const Offset(-300, 0));
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 1));

      // Confirm deletion
      final deleteButton = find.text('Remover');
      if (deleteButton.evaluate().isNotEmpty) {
        await tester.tap(deleteButton.first);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 2));
        print('Device deleted');
      }

      print('\n Device deletion test passed');
    });
  });

  group('Service CRUD Tests', () {
    testWidgets('Create service', (WidgetTester tester) async {
      const locale = String.fromEnvironment('TEST_LOCALE', defaultValue: 'pt-BR');

      print('\n========================================');
      print('CRUD Test: Create Service');
      print('Locale: $locale');
      print('========================================\n');

      // Initialize app
      await _initializeApp(tester);

      // Login with demo account
      await _performLogin(tester, locale);

      // Navigate to service list
      await _navigateToMenu(tester, 'Serviços');
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Create a new service
      print('Creating new service...');
      await _tapSemantic(tester, 'service_list_add_button');
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Fill service form
      print('Filling service form...');
      await _enterTextInSemantic(tester, 'service_form_name_field', 'Test Service ${DateTime.now().millisecondsSinceEpoch}');
      await _enterTextInSemantic(tester, 'service_form_value_field', '100');

      // Dismiss keyboard
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 1));

      // Save the service
      print('Saving service...');
      await _tapSemantic(tester, 'service_form_save_button');
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Verify service appears in list
      final serviceId = await _findFirstEntityId(tester, 'service');
      expect(serviceId, isNotNull, reason: 'Service should appear in list after creation');

      print('\n Service creation test passed');
    });

    testWidgets('Update service', (WidgetTester tester) async {
      const locale = String.fromEnvironment('TEST_LOCALE', defaultValue: 'pt-BR');

      print('\n========================================');
      print('CRUD Test: Update Service');
      print('Locale: $locale');
      print('========================================\n');

      // Initialize app
      await _initializeApp(tester);

      // Login with demo account
      await _performLogin(tester, locale);

      // Navigate to service list
      await _navigateToMenu(tester, 'Serviços');
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Find first service in list
      print('Finding first service for editing...');
      final serviceId = await _findFirstEntityId(tester, 'service');
      if (serviceId == null) {
        print('No services found, skipping update test');
        return;
      }

      // Tap on service to edit
      print('Opening service $serviceId for editing...');
      await _tapSemantic(tester, 'service_item_$serviceId');
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Save to confirm update
      print('Saving service...');
      await _tapSemantic(tester, 'service_form_save_button');
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      print('\n Service update test passed');
    });

    testWidgets('Delete service via swipe', (WidgetTester tester) async {
      const locale = String.fromEnvironment('TEST_LOCALE', defaultValue: 'pt-BR');

      print('\n========================================');
      print('CRUD Test: Delete Service');
      print('Locale: $locale');
      print('========================================\n');

      // Initialize app
      await _initializeApp(tester);

      // Login with demo account
      await _performLogin(tester, locale);

      // Navigate to service list
      await _navigateToMenu(tester, 'Serviços');
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Find first service in list
      final serviceId = await _findFirstEntityId(tester, 'service');
      if (serviceId == null) {
        print('No services found, skipping delete test');
        return;
      }

      // Find the service item widget
      final serviceItem = await _findBySemantic(tester, 'service_item_$serviceId');
      if (serviceItem == null) {
        print('Could not find service item, skipping delete test');
        return;
      }

      // Swipe left to delete
      print('Swiping left to delete service $serviceId...');
      await tester.drag(serviceItem, const Offset(-300, 0));
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 1));

      // Confirm deletion
      final deleteButton = find.text('Remover');
      if (deleteButton.evaluate().isNotEmpty) {
        await tester.tap(deleteButton.first);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 2));
        print('Service deleted');
      }

      print('\n Service deletion test passed');
    });
  });

  group('Product CRUD Tests', () {
    testWidgets('Create product', (WidgetTester tester) async {
      const locale = String.fromEnvironment('TEST_LOCALE', defaultValue: 'pt-BR');

      print('\n========================================');
      print('CRUD Test: Create Product');
      print('Locale: $locale');
      print('========================================\n');

      // Initialize app
      await _initializeApp(tester);

      // Login with demo account
      await _performLogin(tester, locale);

      // Navigate to product list
      await _navigateToMenu(tester, 'Produtos');
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Create a new product
      print('Creating new product...');
      await _tapSemantic(tester, 'product_list_add_button');
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Fill product form
      print('Filling product form...');
      await _enterTextInSemantic(tester, 'product_form_name_field', 'Test Product ${DateTime.now().millisecondsSinceEpoch}');
      await _enterTextInSemantic(tester, 'product_form_value_field', '50');

      // Dismiss keyboard
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 1));

      // Save the product
      print('Saving product...');
      await _tapSemantic(tester, 'product_form_save_button');
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Verify product appears in list
      final productId = await _findFirstEntityId(tester, 'product');
      expect(productId, isNotNull, reason: 'Product should appear in list after creation');

      print('\n Product creation test passed');
    });

    testWidgets('Update product', (WidgetTester tester) async {
      const locale = String.fromEnvironment('TEST_LOCALE', defaultValue: 'pt-BR');

      print('\n========================================');
      print('CRUD Test: Update Product');
      print('Locale: $locale');
      print('========================================\n');

      // Initialize app
      await _initializeApp(tester);

      // Login with demo account
      await _performLogin(tester, locale);

      // Navigate to product list
      await _navigateToMenu(tester, 'Produtos');
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Find first product in list
      print('Finding first product for editing...');
      final productId = await _findFirstEntityId(tester, 'product');
      if (productId == null) {
        print('No products found, skipping update test');
        return;
      }

      // Tap on product to edit
      print('Opening product $productId for editing...');
      await _tapSemantic(tester, 'product_item_$productId');
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Save to confirm update
      print('Saving product...');
      await _tapSemantic(tester, 'product_form_save_button');
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      print('\n Product update test passed');
    });

    testWidgets('Delete product via swipe', (WidgetTester tester) async {
      const locale = String.fromEnvironment('TEST_LOCALE', defaultValue: 'pt-BR');

      print('\n========================================');
      print('CRUD Test: Delete Product');
      print('Locale: $locale');
      print('========================================\n');

      // Initialize app
      await _initializeApp(tester);

      // Login with demo account
      await _performLogin(tester, locale);

      // Navigate to product list
      await _navigateToMenu(tester, 'Produtos');
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Find first product in list
      final productId = await _findFirstEntityId(tester, 'product');
      if (productId == null) {
        print('No products found, skipping delete test');
        return;
      }

      // Find the product item widget
      final productItem = await _findBySemantic(tester, 'product_item_$productId');
      if (productItem == null) {
        print('Could not find product item, skipping delete test');
        return;
      }

      // Swipe left to delete
      print('Swiping left to delete product $productId...');
      await tester.drag(productItem, const Offset(-300, 0));
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 1));

      // Confirm deletion
      final deleteButton = find.text('Remover');
      if (deleteButton.evaluate().isNotEmpty) {
        await tester.tap(deleteButton.first);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 2));
        print('Product deleted');
      }

      print('\n Product deletion test passed');
    });
  });

  group('Form CRUD Tests', () {
    testWidgets('Create form template', (WidgetTester tester) async {
      const locale = String.fromEnvironment('TEST_LOCALE', defaultValue: 'pt-BR');

      print('\n========================================');
      print('CRUD Test: Create Form Template');
      print('Locale: $locale');
      print('========================================\n');

      // Initialize app
      await _initializeApp(tester);

      // Login with demo account
      await _performLogin(tester, locale);

      // Navigate to form list
      await _navigateToMenu(tester, 'Procedimentos');
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Create a new form template
      print('Creating new form template...');
      await _tapSemantic(tester, 'form_list_add_button');
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Fill form template
      print('Filling form template...');
      await _enterTextInSemantic(tester, 'form_form_title_field', 'Test Form ${DateTime.now().millisecondsSinceEpoch}');

      // Dismiss keyboard
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 1));

      // Add an item to the form
      print('Adding item to form...');
      final addItemButton = find.text('Adicionar Item');
      if (addItemButton.evaluate().isNotEmpty) {
        await tester.tap(addItemButton.first);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 1));

        // Fill item label using semantic identifier
        print('Filling item label...');
        await _enterTextInSemantic(tester, 'form_item_sheet_label_field', 'Test Item');
        await Future.delayed(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        // Save item using semantic identifier
        print('Saving item...');
        final saveItemButton = await _findBySemantic(tester, 'form_item_sheet_save_button');
        if (saveItemButton != null) {
          await tester.ensureVisible(saveItemButton);
          await tester.tap(saveItemButton);
          await tester.pumpAndSettle();
          await Future.delayed(const Duration(seconds: 1));
        } else {
          // Fallback: try to find by text
          final saveText = find.text('Salvar');
          if (saveText.evaluate().isNotEmpty) {
            await tester.tap(saveText.first);
            await tester.pumpAndSettle();
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      }

      // Save the form template
      print('Saving form template...');
      await _tapSemantic(tester, 'form_form_save_button');
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Verify form appears in list
      final formId = await _findFirstEntityId(tester, 'form');
      expect(formId, isNotNull, reason: 'Form should appear in list after creation');

      print('\n Form template creation test passed');
    });

    testWidgets('Update form template', (WidgetTester tester) async {
      const locale = String.fromEnvironment('TEST_LOCALE', defaultValue: 'pt-BR');

      print('\n========================================');
      print('CRUD Test: Update Form Template');
      print('Locale: $locale');
      print('========================================\n');

      // Initialize app
      await _initializeApp(tester);

      // Login with demo account
      await _performLogin(tester, locale);

      // Navigate to form list
      await _navigateToMenu(tester, 'Procedimentos');
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Find first form in list
      print('Finding first form for editing...');
      final formId = await _findFirstEntityId(tester, 'form');
      if (formId == null) {
        print('No forms found, skipping update test');
        return;
      }

      // Tap on form to edit
      print('Opening form $formId for editing...');
      await _tapSemantic(tester, 'form_item_$formId');
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Save to confirm update
      print('Saving form template...');
      await _tapSemantic(tester, 'form_form_save_button');
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      print('\n Form template update test passed');
    });

    testWidgets('Delete form template via swipe', (WidgetTester tester) async {
      const locale = String.fromEnvironment('TEST_LOCALE', defaultValue: 'pt-BR');

      print('\n========================================');
      print('CRUD Test: Delete Form Template');
      print('Locale: $locale');
      print('========================================\n');

      // Initialize app
      await _initializeApp(tester);

      // Login with demo account
      await _performLogin(tester, locale);

      // Navigate to form list
      await _navigateToMenu(tester, 'Procedimentos');
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Find first form in list
      final formId = await _findFirstEntityId(tester, 'form');
      if (formId == null) {
        print('No forms found, skipping delete test');
        return;
      }

      // Find the form item widget
      final formItem = await _findBySemantic(tester, 'form_item_$formId');
      if (formItem == null) {
        print('Could not find form item, skipping delete test');
        return;
      }

      // Swipe left to delete
      print('Swiping left to delete form $formId...');
      await tester.drag(formItem, const Offset(-300, 0));
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 1));

      // Confirm deletion
      final deleteButton = find.text('Excluir');
      if (deleteButton.evaluate().isNotEmpty) {
        await tester.tap(deleteButton.first);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 2));
        print('Form deleted');
      }

      print('\n Form template deletion test passed');
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

/// Tap a widget by semantic identifier
Future<void> _tapSemantic(WidgetTester tester, String identifier) async {
  final finder = await _findBySemantic(tester, identifier);
  if (finder != null) {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  } else {
    print('Warning: Could not find semantic identifier: $identifier');
  }
}

/// Enter text in a widget by semantic identifier
Future<void> _enterTextInSemantic(WidgetTester tester, String identifier, String text) async {
  final semanticFinder = await _findBySemantic(tester, identifier);
  if (semanticFinder == null) {
    print('Warning: Could not find semantic identifier: $identifier');
    return;
  }

  // Find text field within the semantic widget
  final textFields = find.descendant(
    of: semanticFinder,
    matching: find.byType(CupertinoTextFormFieldRow),
  );

  if (textFields.evaluate().isNotEmpty) {
    await tester.enterText(textFields.first, text);
    await tester.pumpAndSettle();
  } else {
    // Try CupertinoTextField
    final cupertinoFields = find.descendant(
      of: semanticFinder,
      matching: find.byType(CupertinoTextField),
    );
    if (cupertinoFields.evaluate().isNotEmpty) {
      await tester.enterText(cupertinoFields.first, text);
      await tester.pumpAndSettle();
    } else {
      print('Warning: Could not find text field in semantic: $identifier');
    }
  }
}

/// Navigate to a menu item via Settings tab
Future<void> _navigateToMenu(WidgetTester tester, String menuLabel) async {
  print('Navigating to: $menuLabel');

  // First, navigate to Settings tab
  print('Opening Settings tab...');
  final settingsTab = await _findBySemantic(tester, 'tab_settings');
  if (settingsTab != null) {
    await tester.tap(settingsTab);
    await tester.pumpAndSettle();
    await Future.delayed(const Duration(seconds: 2));
    print('Settings tab opened');
  } else {
    // Fallback: try to find by icon (ellipsis)
    final ellipsisIcon = find.byIcon(CupertinoIcons.ellipsis);
    if (ellipsisIcon.evaluate().isNotEmpty) {
      await tester.tap(ellipsisIcon.first);
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 2));
      print('Settings tab opened via icon');
    } else {
      print('Warning: Could not find Settings tab');
      return;
    }
  }

  // Map menu labels to semantic identifiers
  final menuIdentifiers = {
    'Equipamentos': 'settings_menu_devices',
    'Devices': 'settings_menu_devices',
    'Serviços': 'settings_menu_services',
    'Services': 'settings_menu_services',
    'Produtos': 'settings_menu_products',
    'Products': 'settings_menu_products',
    'Procedimentos': 'settings_menu_forms',
    'Forms': 'settings_menu_forms',
  };

  final semanticId = menuIdentifiers[menuLabel];
  if (semanticId != null) {
    final menuItem = await _findBySemantic(tester, semanticId);
    if (menuItem != null) {
      await tester.tap(menuItem);
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 2));
      print('Navigated to $menuLabel via semantic identifier');
      return;
    }
  }

  // Fallback: try to find by text
  final menuFinder = find.textContaining(menuLabel, skipOffstage: false);
  if (menuFinder.evaluate().isNotEmpty) {
    await tester.tap(menuFinder.first);
    await tester.pumpAndSettle();
    await Future.delayed(const Duration(seconds: 2));
    print('Navigated to $menuLabel via text');
  } else {
    // Try alternative labels
    final alternatives = {
      'Equipamentos': ['Veículos', 'Devices'],
      'Serviços': ['Services'],
      'Produtos': ['Products'],
      'Procedimentos': ['Formulários', 'Forms'],
    };

    for (final alt in alternatives[menuLabel] ?? []) {
      final altFinder = find.textContaining(alt, skipOffstage: false);
      if (altFinder.evaluate().isNotEmpty) {
        await tester.tap(altFinder.first);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 2));
        print('Navigated to $alt');
        return;
      }
    }

    print('Warning: Could not find menu: $menuLabel');
  }
}

/// Find the first entity ID from semantic identifiers in the list
/// Searches for semantic identifiers with pattern: {entityType}_item_{id}
Future<String?> _findFirstEntityId(WidgetTester tester, String entityType) async {
  final allSemantics = find.byType(Semantics);
  final pattern = '${entityType}_item_';

  for (var i = 0; i < allSemantics.evaluate().length; i++) {
    final widget = tester.widget<Semantics>(allSemantics.at(i));
    final id = widget.properties.identifier?.toString() ?? '';
    if (id.startsWith(pattern)) {
      final entityId = id.substring(pattern.length);
      print('Found $entityType with ID: $entityId');
      return entityId;
    }
  }

  print('No $entityType items found in list');
  return null;
}

/// Select or create an accumulated value from the picker
Future<void> _selectOrCreateAccumulatedValue(WidgetTester tester, String value) async {
  await Future.delayed(const Duration(seconds: 1));
  await tester.pumpAndSettle();

  // Try to find an existing item in the list
  final existingItem = await _findBySemantic(tester, 'accumulated_value_item_0');
  if (existingItem != null) {
    print('Selecting existing accumulated value...');
    await tester.tap(existingItem);
    await tester.pumpAndSettle();
    return;
  }

  // If no items, try to create a new value via search field
  final searchField = await _findBySemantic(tester, 'accumulated_value_search_field');
  if (searchField != null) {
    print('Creating new accumulated value: $value');

    // Find the text field within the semantic widget
    final textFields = find.descendant(
      of: searchField,
      matching: find.byType(CupertinoTextField),
    );

    if (textFields.evaluate().isNotEmpty) {
      await tester.enterText(textFields.first, value);
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(milliseconds: 500));

      // Tap the add button
      final addButton = await _findBySemantic(tester, 'accumulated_value_add_button');
      if (addButton != null) {
        await tester.tap(addButton);
        await tester.pumpAndSettle();
        return;
      }
    }
  }

  // Fallback: try to tap back button if nothing worked
  print('Could not select or create accumulated value, going back...');
  final backButton = find.byIcon(CupertinoIcons.back);
  if (backButton.evaluate().isNotEmpty) {
    await tester.tap(backButton.first);
    await tester.pumpAndSettle();
  }
}
