import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  // Get locale from environment (default: pt-BR)
  final locale = Platform.environment['TEST_LOCALE'] ?? 'pt-BR';
  print('🌍 Test locale: $locale');

  // Detect platform based on connected device
  final isAndroid = Platform.environment['FLUTTER_TEST_PLATFORM'] == 'android' ||
      !Platform.environment.containsKey('FLUTTER_TEST_PLATFORM');

  // Define target directory based on platform and locale
  final String screenshotDir;
  if (Platform.environment.containsKey('SCREENSHOT_DIR')) {
    screenshotDir = Platform.environment['SCREENSHOT_DIR']!;
  } else if (isAndroid) {
    screenshotDir = 'android/fastlane/metadata/android/$locale/images/phoneScreenshots';
  } else {
    screenshotDir = 'ios/fastlane/screenshots/$locale';
  }

  print('📸 Screenshots will be saved to: $screenshotDir');

  // Standardized screenshot names (same for both platforms)
  // Format: {number}_{name} (e.g., 01_home, 02_order_detail)
  final Map<String, String> screenshotNames = {
    '01_home': '01_home',
    '02_order_detail': '02_order_detail',
    '03_segments': '03_segments',
    '04_dashboard': '04_dashboard',
    '05_payments': '05_payments',
    '06_forms': '06_forms',
    '07_login': '07_login',
  };

  await integrationDriver(
    onScreenshot: (String screenshotName, List<int> screenshotBytes, [Map<String, Object?>? args]) async {
      // Remove any prefix (light_, dark_) - we only capture light mode now
      String baseScreenshotName = screenshotName;
      if (screenshotName.startsWith('light_')) {
        baseScreenshotName = screenshotName.substring(6);
      } else if (screenshotName.startsWith('dark_')) {
        baseScreenshotName = screenshotName.substring(5);
      }

      // Get standardized name
      final standardName = screenshotNames[baseScreenshotName] ?? baseScreenshotName;

      // Define final filename
      final String filename;
      if (isAndroid) {
        // Android: {number}_{name}.png (e.g., 01_home.png)
        filename = '$standardName.png';
      } else {
        // iOS: {device}-{number}_{name}.png (e.g., iPhone 16e-01_home.png)
        final deviceName = Platform.environment['DEVICE_NAME'] ?? 'iPhone 16e';
        filename = '$deviceName-$standardName.png';
      }

      final filePath = '$screenshotDir/$filename';
      final File image = await File(filePath).create(recursive: true);
      image.writeAsBytesSync(screenshotBytes);
      print('✅ Saved: $filePath');
      return true;
    },
  );
}
