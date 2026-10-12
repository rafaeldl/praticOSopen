import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Redesigned screens must take colors from AppColors (resolved from context),
/// not from CupertinoColors, so dark mode and "Increase Contrast" keep working.
/// This audit fails if CupertinoColors. reappears in the files already fixed.
const _redesignedFiles = <String>[
  'lib/widgets/cached_image.dart',
  'lib/screens/device_list_screen.dart',
  'lib/screens/accumulated_value_list_screen.dart',
  'lib/screens/payments/widgets/receive_block.dart',
];

void main() {
  for (final path in _redesignedFiles) {
    test('$path does not use CupertinoColors directly', () {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: 'missing file $path');
      expect(
        file.readAsStringSync().contains('CupertinoColors.'),
        isFalse,
        reason:
            '$path uses CupertinoColors. Use AppColors.<role>.resolveFrom(context)',
      );
    });
  }
}
