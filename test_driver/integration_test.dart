import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  // Detecta a plataforma baseado no device conectado
  final isAndroid = Platform.environment['FLUTTER_TEST_PLATFORM'] == 'android' ||
      !Platform.environment.containsKey('FLUTTER_TEST_PLATFORM');

  // Define o diretório de destino baseado na plataforma
  final String screenshotDir;
  if (Platform.environment.containsKey('SCREENSHOT_DIR')) {
    screenshotDir = Platform.environment['SCREENSHOT_DIR']!;
  } else if (isAndroid) {
    screenshotDir = 'android/fastlane/metadata/android/pt-BR/images/phoneScreenshots';
  } else {
    screenshotDir = 'ios/fastlane/screenshots/pt-BR';
  }

  print('📸 Screenshots will be saved to: $screenshotDir');

  // Mapeamento de nomes para o formato iOS
  final Map<String, String> iosNameMapping = {
    '1_login': '00_Login',
    '2_home': '01_Home',
    '3_order_detail': '02_OrderDetail',
    '4_dashboard': '03_Dashboard',
    '5_customers': '04_Customers',
    '6_customer_detail': '05_CustomerDetail',
    '7_settings': '06_Settings',
  };

  await integrationDriver(
    onScreenshot: (String screenshotName, List<int> screenshotBytes, [Map<String, Object?>? args]) async {
      // Extrai o número do nome (ex: "1_login" -> "1")
      final number = screenshotName.split('_').first;

      // Define o nome final do arquivo
      final String filename;
      if (screenshotDir.contains('android')) {
        // Android: usa apenas número (1.png, 2.png, etc.)
        filename = '$number.png';
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
