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
  ('textSecondary on background', AppColors.textSecondary, AppColors.background, 4.5),
  ('textSecondary on surface', AppColors.textSecondary, AppColors.surface, 4.5),
  ('onAccent on accent', AppColors.onAccent, AppColors.accent, 4.5),
  ('accentText on background', AppColors.accentText, AppColors.background, 4.5),
  ('accentText on surface', AppColors.accentText, AppColors.surface, 4.5),
  ('onAccentSoft on accentSoft', AppColors.onAccentSoft, AppColors.accentSoft, 4.5),
  ('onSecondaryFill on secondaryFill', AppColors.onSecondaryFill, AppColors.secondaryFill, 4.5),
  ('onAssistantFill on assistantFill', AppColors.onAssistantFill, AppColors.assistantFill, 4.5),
  ('onMarker on marker', AppColors.onMarker, AppColors.marker, 4.5),
  ('success on background', AppColors.success, AppColors.background, 4.5),
  ('success on surface', AppColors.success, AppColors.surface, 4.5),
  ('warning on background', AppColors.warning, AppColors.background, 4.5),
  ('warning on surface', AppColors.warning, AppColors.surface, 4.5),
  ('onWarningSoft on warningSoft', AppColors.onWarningSoft, AppColors.warningSoft, 4.5),
  ('danger on background', AppColors.danger, AppColors.background, 4.5),
  ('danger on surface', AppColors.danger, AppColors.surface, 4.5),
  ('accent fill on surface', AppColors.accent, AppColors.surface, 3.0),
  ('assistant fill on background', AppColors.assistantFill, AppColors.background, 3.0),
];

void main() {
  for (final mode in [Brightness.light, Brightness.dark]) {
    group('AppColors contrast (${mode.name})', () {
      for (final (name, fg, bg, min) in _pairs) {
        test('$name >= $min', () {
          final f = mode == Brightness.dark ? fg.darkColor : fg.color;
          final b = mode == Brightness.dark ? bg.darkColor : bg.color;
          expect(_contrast(f, b), greaterThanOrEqualTo(min));
        });
      }
    });
  }
}
