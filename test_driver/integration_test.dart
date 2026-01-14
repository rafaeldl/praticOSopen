import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  // Get locale from environment (default: pt-BR)
  final locale = Platform.environment['TEST_LOCALE'] ?? 'pt-BR';
  print('🌍 Test locale: $locale');

  // Detecta a plataforma baseado no device conectado
  final isAndroid = Platform.environment['FLUTTER_TEST_PLATFORM'] == 'android' ||
      !Platform.environment.containsKey('FLUTTER_TEST_PLATFORM');

  // Define o diretório de destino baseado na plataforma e locale
  final String screenshotDir;
  if (Platform.environment.containsKey('SCREENSHOT_DIR')) {
    screenshotDir = Platform.environment['SCREENSHOT_DIR']!;
  } else if (isAndroid) {
    screenshotDir = 'android/fastlane/metadata/android/$locale/images/phoneScreenshots';
  } else {
    screenshotDir = 'ios/fastlane/screenshots/$locale';
  }

  print('📸 Screenshots will be saved to: $screenshotDir');

  // Mapeamento de nomes para diferentes plataformas
  final Map<String, String> iosNameMapping = {
    '01_home': '00_Home',
    '02_order_detail': '01_OrderDetail',
    '03_segments': '02_Segments',
    '04_dashboard': '03_Dashboard',
    '05_payments': '04_Payments',
    '06_forms': '05_Forms',
    '07_login': '06_Login',
  };

  final Map<String, String> androidNameMapping = {
    '01_home': '01-home',
    '02_order_detail': '02-order_detail',
    '03_segments': '03-segments',
    '04_dashboard': '04-dashboard',
    '05_payments': '05-payments',
    '06_forms': '06-forms',
    '07_login': '07-login',
  };

  await integrationDriver(
    onScreenshot: (String screenshotName, List<int> screenshotBytes, [Map<String, Object?>? args]) async {
      // Define o nome final do arquivo
      final String filename;
      if (screenshotDir.contains('android')) {
        // Android: usa formato descritivo (01-login.png, 02-home.png, etc.)
        final androidName = androidNameMapping[screenshotName] ?? screenshotName;
        filename = '$androidName.png';
      } else {
        // iOS: usa formato com prefixo do dispositivo e nome mapeado
        final deviceName = Platform.environment['DEVICE_NAME'] ?? 'iPhone 16e';
        final iosName = iosNameMapping[screenshotName] ?? screenshotName;
        filename = '$deviceName-$iosName.png';
      }

      final filePath = '$screenshotDir/$filename';
      final File image = await File(filePath).create(recursive: true);
      image.writeAsBytesSync(screenshotBytes);
      print('✅ Saved: $filePath');
      return true;
    },
  );
}
