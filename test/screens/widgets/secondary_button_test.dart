import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/screens/widgets/secondary_button.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';

void main() {
  Future<void> pump(WidgetTester tester, VoidCallback? onPressed) =>
      tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Center(
              child: SecondaryButton(
                label: 'Mandar cobrança',
                onPressed: onPressed,
              ),
            ),
          ),
        ),
      );

  testWidgets('same height as the primary button, on the surface color', (
    tester,
  ) async {
    await pump(tester, () {});
    final button = find.byType(SecondaryButton);
    expect(
      tester.getSize(button).height,
      greaterThanOrEqualTo(AppSizes.primaryButtonHeight),
    );
    final cupertino = tester.widget<CupertinoButton>(
      find.byType(CupertinoButton),
    );
    expect(
      cupertino.color,
      AppColors.surface.resolveFrom(tester.element(button)),
    );
  });

  testWidgets('calls back when enabled, does nothing when off', (tester) async {
    var taps = 0;
    await pump(tester, () => taps++);
    await tester.tap(find.text('Mandar cobrança'));
    expect(taps, 1);

    await pump(tester, null);
    await tester.tap(find.text('Mandar cobrança'));
    expect(taps, 1);
  });
}
