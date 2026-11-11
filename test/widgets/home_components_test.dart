import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/screens/widgets/next_step_block.dart';
import 'package:praticos/screens/widgets/order_list_row.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';

Widget wrap(Widget child, {Brightness brightness = Brightness.light}) {
  return CupertinoApp(
    locale: const Locale('pt'),
    theme: CupertinoThemeData(brightness: brightness),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
    ],
    home: CupertinoPageScaffold(
      child: SafeArea(child: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  group('PrimaryButton', () {
    testWidgets('has the design-system height and fires onPressed', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(PrimaryButton(label: 'Nova OS', onPressed: () => taps++)),
      );
      expect(find.text('Nova OS'), findsOneWidget);
      expect(
        tester.getSize(find.byType(PrimaryButton)).height,
        greaterThanOrEqualTo(AppSizes.primaryButtonHeight),
      );
      await tester.tap(find.text('Nova OS'));
      expect(taps, 1);
    });

    testWidgets('does not fire when disabled', (tester) async {
      await tester.pumpWidget(
        wrap(const PrimaryButton(label: 'Nova OS', onPressed: null)),
      );
      await tester.tap(find.text('Nova OS'));
      // no exception, nothing to assert beyond the widget staying present
      expect(find.text('Nova OS'), findsOneWidget);
    });

    testWidgets('floating variant stays opaque: glass is for navigation', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(PrimaryButton(label: 'Nova OS', floating: true, onPressed: () {})),
      );
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('is the yellow action with navy text and a hairline', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(PrimaryButton(label: 'Nova OS', onPressed: () {})),
      );
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(PrimaryButton),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color!.toARGB32(), AppColors.action.color.toARGB32());
      expect(decoration.border, isNotNull);
      final label = tester.widget<Text>(find.text('Nova OS'));
      expect(
        label.style!.color!.toARGB32(),
        AppColors.onAction.color.toARGB32(),
      );
    });
  });

  group('TextLink', () {
    testWidgets('shows label in accentText, tap target at least 44', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(TextLink(label: 'Ver todas', onPressed: () => taps++)),
      );
      final text = tester.widget<Text>(find.text('Ver todas'));
      expect(
        text.style!.color!.toARGB32(),
        AppColors.accentText.color.toARGB32(),
      );
      expect(
        tester.getSize(find.byType(CupertinoButton)).height,
        greaterThanOrEqualTo(AppSizes.minTouchTarget),
      );
      await tester.tap(find.text('Ver todas'));
      expect(taps, 1);
    });
  });

  group('NextStepBlock', () {
    testWidgets('shows label, sentence and link; link fires', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrap(
          NextStepBlock(
            warning: true,
            label: 'Hoje',
            text: '2 OS passaram do prazo.',
            linkLabel: 'Ver as atrasadas',
            onLink: () => taps++,
          ),
        ),
      );
      expect(find.text('Hoje'), findsOneWidget);
      expect(find.text('2 OS passaram do prazo.'), findsOneWidget);
      await tester.tap(find.text('Ver as atrasadas'));
      expect(taps, 1);
    });

    testWidgets(
      'uses warningSoft in the warning variant and accentSoft otherwise',
      (tester) async {
        Color? blockColor() {
          final box = tester.widget<Container>(find.byType(Container).first);
          return (box.decoration as BoxDecoration).color;
        }

        await tester.pumpWidget(wrap(const NextStepBlock(text: 'a')));
        expect(blockColor()!.toARGB32(), AppColors.accentSoft.color.toARGB32());
        await tester.pumpWidget(
          wrap(const NextStepBlock(text: 'a', warning: true)),
        );
        expect(
          blockColor()!.toARGB32(),
          AppColors.warningSoft.color.toARGB32(),
        );
      },
    );

    testWidgets('dark mode resolves dark colors', (tester) async {
      await tester.pumpWidget(
        wrap(const NextStepBlock(text: 'a'), brightness: Brightness.dark),
      );
      final box = tester.widget<Container>(find.byType(Container).first);
      expect(
        (box.decoration as BoxDecoration).color!.toARGB32(),
        AppColors.accentSoft.darkColor.toARGB32(),
      );
    });

    testWidgets('can hold a button', (tester) async {
      await tester.pumpWidget(
        wrap(
          NextStepBlock(
            text: 'Crie sua primeira OS',
            button: PrimaryButton(label: 'Nova OS', onPressed: () {}),
          ),
        ),
      );
      expect(find.byType(PrimaryButton), findsOneWidget);
    });
  });

  group('OrderListRow', () {
    testWidgets('shows customer, value, detail and status', (tester) async {
      await tester.pumpWidget(
        wrap(
          OrderListRow(
            customerName: 'Ana Ribeiro',
            valueText: 'R\$ 1.250,00',
            detailText: 'Fiat Uno · troca de embreagem',
            statusText: 'Em andamento · entrega hoje',
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Ana Ribeiro'), findsOneWidget);
      expect(find.text('R\$ 1.250,00'), findsOneWidget);
      expect(find.text('Fiat Uno · troca de embreagem'), findsOneWidget);
      expect(find.textContaining('Em andamento'), findsOneWidget);
      expect(find.byKey(const Key('order_row_problem')), findsNothing);
    });

    testWidgets('status dot before the status, in the status color', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const OrderListRow(
            customerName: 'Ana',
            statusText: 'Pintura',
            statusColor: Color(0xFFD98B09),
          ),
        ),
      );
      final dot = tester.widget<Container>(
        find.byKey(const Key('order_row_status_dot')),
      );
      expect((dot.decoration! as BoxDecoration).color, const Color(0xFFD98B09));
    });

    testWidgets('payment after the status, in its color', (tester) async {
      await tester.pumpWidget(
        wrap(
          const OrderListRow(
            customerName: 'Ana',
            statusText: 'Pronto',
            statusExtra: 'Pago',
            statusExtraColor: Color(0xFF1D7D3E),
          ),
        ),
      );
      expect(
        find.textContaining('Pronto · Pago', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('a problem goes on the right, bold, in its color', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const OrderListRow(
            customerName: 'Ana',
            statusText: 'Pintura',
            problemText: 'Atrasada 2 dias',
            problemColor: Color(0xFFC93029),
          ),
        ),
      );
      final style = tester.widget<Text>(find.text('Atrasada 2 dias')).style!;
      expect(style.fontWeight, FontWeight.w700);
      expect(style.color, const Color(0xFFC93029));
      expect(
        tester.getTopRight(find.text('Atrasada 2 dias')).dx,
        greaterThan(tester.getTopRight(find.text('Ana')).dx - 1),
      );
    });

    testWidgets('normal status text is neutral, not colored', (tester) async {
      await tester.pumpWidget(
        wrap(const OrderListRow(customerName: 'Ana', statusText: 'Aprovado')),
      );
      final style = tester
          .widget<RichText>(find.textContaining('Aprovado', findRichText: true))
          .text
          .style!;
      expect(style.color!.toARGB32(), AppColors.textSecondary.color.toARGB32());
    });
  });
}
