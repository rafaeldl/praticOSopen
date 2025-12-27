import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:praticos/main.dart' as app;

// IMPORTANT: This test requires a running simulator/emulator.
// To run: flutter drive --driver=test_driver/integration_test.dart --target=integration_test/screenshot_test.dart

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('take screenshots', (WidgetTester tester) async {
    // 1. Initialize the app
    app.main();
    await tester.pumpAndSettle();

    // 2. Take a screenshot of the initial screen (Login or Home)
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();

    // Determine where we are
    if (find.text('Login').hits.isNotEmpty || find.byType(ElevatedButton).hits.isNotEmpty) {
      await binding.takeScreenshot('01_login_screen');
    } else {
       await binding.takeScreenshot('01_home_screen');
    }

    // 3. Navigate and take more screenshots
    // Note: Since authentication is complex to mock in this integration test setup without
    // dependency injection in main.dart, we primarily capture the initial state.
    //
    // If you are logged in (e.g. running on a device with cached auth), you can add navigation steps:
    //
    // if (find.text('Serviços').hits.isNotEmpty) {
    //   await binding.takeScreenshot('02_services_list');
    //   await tester.tap(find.text('Serviços'));
    //   await tester.pumpAndSettle();
    //   await binding.takeScreenshot('03_services_details');
    // }
  });
}
