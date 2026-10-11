import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/theme/app_colors.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Every pair the design system puts on screen, with its WCAG AA minimum:
/// 4.5 for text, 3.0 for component boundaries.
final _pairs = <(String, CupertinoDynamicColor, CupertinoDynamicColor, double)>[
  ('text on background', AppColors.text, AppColors.background, 4.5),
  ('text on surface', AppColors.text, AppColors.surface, 4.5),
  (
    'textSecondary on background',
    AppColors.textSecondary,
    AppColors.background,
    4.5,
  ),
  ('textSecondary on surface', AppColors.textSecondary, AppColors.surface, 4.5),
  ('onAccent on accent', AppColors.onAccent, AppColors.accent, 4.5),
  ('accentText on background', AppColors.accentText, AppColors.background, 4.5),
  ('accentText on surface', AppColors.accentText, AppColors.surface, 4.5),
  (
    'onAccentSoft on accentSoft',
    AppColors.onAccentSoft,
    AppColors.accentSoft,
    4.5,
  ),
  (
    'onSecondaryFill on secondaryFill',
    AppColors.onSecondaryFill,
    AppColors.secondaryFill,
    4.5,
  ),
  (
    'onAssistantFill on assistantFill',
    AppColors.onAssistantFill,
    AppColors.assistantFill,
    4.5,
  ),
  ('onMarker on marker', AppColors.onMarker, AppColors.marker, 4.5),
  ('success on background', AppColors.success, AppColors.background, 4.5),
  ('success on surface', AppColors.success, AppColors.surface, 4.5),
  ('warning on background', AppColors.warning, AppColors.background, 4.5),
  ('warning on surface', AppColors.warning, AppColors.surface, 4.5),
  (
    'onWarningSoft on warningSoft',
    AppColors.onWarningSoft,
    AppColors.warningSoft,
    4.5,
  ),
  ('danger on background', AppColors.danger, AppColors.background, 4.5),
  ('danger on surface', AppColors.danger, AppColors.surface, 4.5),
  ('accent fill on surface', AppColors.accent, AppColors.surface, 3.0),
  (
    'assistant fill on background',
    AppColors.assistantFill,
    AppColors.background,
    3.0,
  ),
];

enum _Variant { light, dark, lightHighContrast, darkHighContrast }

Color _pick(CupertinoDynamicColor c, _Variant v) => switch (v) {
  _Variant.light => c.color,
  _Variant.dark => c.darkColor,
  _Variant.lightHighContrast => c.highContrastColor,
  _Variant.darkHighContrast => c.darkHighContrastColor,
};

void main() {
  for (final variant in _Variant.values) {
    group('AppColors contrast (${variant.name})', () {
      for (final (name, fg, bg, min) in _pairs) {
        test('$name >= $min', () {
          expect(
            _contrast(_pick(fg, variant), _pick(bg, variant)),
            greaterThanOrEqualTo(min),
          );
        });
      }
    });
  }

  group('Increase Contrast never lowers contrast', () {
    for (final (name, fg, bg, _) in _pairs) {
      test(name, () {
        final light = _contrast(fg.color, bg.color);
        final dark = _contrast(fg.darkColor, bg.darkColor);
        expect(
          _contrast(fg.highContrastColor, bg.highContrastColor),
          greaterThanOrEqualTo(light),
        );
        expect(
          _contrast(fg.darkHighContrastColor, bg.darkHighContrastColor),
          greaterThanOrEqualTo(dark),
        );
      });
    }
  });

  test('textSecondary reaches 7:1 (AAA) with Increase Contrast', () {
    for (final bg in [AppColors.background, AppColors.surface]) {
      expect(
        _contrast(
          AppColors.textSecondary.highContrastColor,
          bg.highContrastColor,
        ),
        greaterThanOrEqualTo(7.0),
      );
      expect(
        _contrast(
          AppColors.textSecondary.darkHighContrastColor,
          bg.darkHighContrastColor,
        ),
        greaterThanOrEqualTo(7.0),
      );
    }
  });

  testWidgets('resolveFrom picks the high contrast variant', (tester) async {
    late Color resolved;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(highContrast: true),
        child: Builder(
          builder: (context) {
            resolved = AppColors.textSecondary.resolveFrom(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(
      resolved.toARGB32(),
      AppColors.textSecondary.highContrastColor.toARGB32(),
    );
  });
}
