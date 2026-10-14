import 'dart:ui' show Tristate;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/screens/widgets/period_stepper.dart';
import 'package:praticos/theme/app_colors.dart';

void main() {
  Future<void> pump(WidgetTester tester, {VoidCallback? onNext}) {
    return tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              child: PeriodStepper(
                label: 'Outubro de 2026',
                previousLabel: 'Mês anterior',
                nextLabel: 'Próximo mês',
                onPrevious: () {},
                onNext: onNext,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('chevrons hug the label on the left, label in grey', (
    tester,
  ) async {
    await pump(tester, onNext: () {});

    final back = tester.getRect(find.byIcon(CupertinoIcons.chevron_back));
    final label = tester.getRect(find.text('Outubro de 2026'));
    final next = tester.getRect(find.byIcon(CupertinoIcons.chevron_forward));

    // Compact: the next chevron sits right after the label, not at the edge.
    expect(back.right, lessThan(label.left + 1));
    expect(next.left - label.right, lessThan(30));

    final text = tester.widget<Text>(find.text('Outubro de 2026'));
    final context = tester.element(find.text('Outubro de 2026'));
    expect(
      text.style?.color,
      AppColors.textSecondary.resolveFrom(context),
    );
  });

  testWidgets('next chevron is disabled when there is no later period', (
    tester,
  ) async {
    await pump(tester);

    final semantics = tester.getSemantics(find.bySemanticsLabel('Próximo mês'));
    expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);
  });
}
