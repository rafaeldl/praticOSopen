import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_glass.dart';

Future<void> _pump(
  WidgetTester tester, {
  bool highContrast = false,
  bool enabled = true,
  bool reduceTransparency = false,
}) {
  return tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(highContrast: highContrast),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: AppGlass(
          enabled: enabled,
          reduceTransparency: reduceTransparency,
          child: const SizedBox(width: 100, height: 50),
        ),
      ),
    ),
  );
}

Color _fill(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(AppGlass),
      matching: find.byType(DecoratedBox),
    ),
  );
  return (box.decoration as BoxDecoration).color!;
}

void main() {
  testWidgets('renders translucent blurred glass by default', (tester) async {
    await _pump(tester);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(_fill(tester).a, closeTo(AppGlass.defaultOpacity, 0.01));
  });

  testWidgets('falls back to opaque fill with Increase Contrast', (
    tester,
  ) async {
    await _pump(tester, highContrast: true);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(
      _fill(tester).toARGB32(),
      AppColors.surface.highContrastColor.toARGB32(),
    );
  });

  testWidgets('falls back to opaque fill with Reduce Transparency', (
    tester,
  ) async {
    await _pump(tester, reduceTransparency: true);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(_fill(tester).a, 1.0);
  });

  testWidgets('falls back to opaque fill when disabled', (tester) async {
    await _pump(tester, enabled: false);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(_fill(tester).a, 1.0);
  });
}
