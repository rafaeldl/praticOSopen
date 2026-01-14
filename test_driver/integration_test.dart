import 'dart:io';
import 'dart:typed_data';
import 'package:integration_test/integration_test_driver_extended.dart';
import 'package:image/image.dart' as img;

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

      // Decode the image from bytes
      // Convert List<int> to Uint8List as required by image package
      final bytes = screenshotBytes is Uint8List ? screenshotBytes : Uint8List.fromList(screenshotBytes);
      final originalImage = img.decodeImage(bytes);

      if (originalImage != null) {
        // Remove alpha channel by converting to RGB (no transparency)
        // This is required by App Store Connect - screenshots cannot have alpha channel
        // Create a new image without alpha by copying RGB channels only
        final rgbImage = img.Image(
          width: originalImage.width,
          height: originalImage.height,
          numChannels: 3, // RGB only, no alpha
        );

        // Copy RGB data from original (alpha is automatically dropped)
        for (var y = 0; y < originalImage.height; y++) {
          for (var x = 0; x < originalImage.width; x++) {
            final pixel = originalImage.getPixel(x, y);
            rgbImage.setPixelRgb(x, y, pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt());
          }
        }

        // Encode back to PNG without alpha
        final processedBytes = img.encodePng(rgbImage, level: 6);

        final filePath = '$screenshotDir/$filename';
        final File image = await File(filePath).create(recursive: true);
        image.writeAsBytesSync(processedBytes);
        print('✅ Saved (RGB): $filePath');
      } else {
        // Fallback: save original bytes if decoding fails
        final filePath = '$screenshotDir/$filename';
        final File image = await File(filePath).create(recursive: true);
        image.writeAsBytesSync(screenshotBytes);
        print('⚠️  Saved (original): $filePath');
      }

      return true;
    },
  );
}
