import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_cupertino_theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name}: navy text, theme background', (
      tester,
    ) async {
      late CupertinoThemeData theme;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(platformBrightness: brightness),
          child: CupertinoTheme(
            data: appCupertinoTheme(brightness),
            child: Builder(
              builder: (context) {
                theme = CupertinoTheme.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      final dark = brightness == Brightness.dark;
      final text = dark ? AppColors.text.darkColor : AppColors.text.color;
      final background = dark
          ? AppColors.background.darkColor
          : AppColors.background.color;
      expect(
        theme.textTheme.navLargeTitleTextStyle.color!.toARGB32(),
        text.toARGB32(),
      );
      expect(theme.textTheme.textStyle.color!.toARGB32(), text.toARGB32());
      expect(theme.scaffoldBackgroundColor.toARGB32(), background.toARGB32());
    });
  }
}
