import 'dart:io';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() {
  return integrationDriver(
    onScreenshot: (String screenshotName, List<int> screenshotBytes,
        [Map<String, Object?>? args]) async {
      // Ensure extension is .png
      final String fileName = screenshotName.endsWith('.png')
          ? screenshotName
          : '$screenshotName.png';

      final File image = File(fileName);
      await image.writeAsBytes(screenshotBytes);
      return true;
    },
  );
}
