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

    testWidgets('floating variant renders on glass', (tester) async {
      await tester.pumpWidget(
        wrap(PrimaryButton(label: 'Nova OS', floating: true, onPressed: () {})),
      );
      expect(find.byType(BackdropFilter), findsOneWidget);
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
      expect(find.byKey(const Key('order_row_overdue_dot')), findsNothing);
    });

    testWidgets('overdue: red dot and bold danger status', (tester) async {
      await tester.pumpWidget(
        wrap(
          const OrderListRow(
            customerName: 'Ana',
            statusText: 'Atrasada 2 dias',
            overdue: true,
          ),
        ),
      );
      expect(find.byKey(const Key('order_row_overdue_dot')), findsOneWidget);
      final style = tester.widget<Text>(find.text('Atrasada 2 dias')).style!;
      expect(style.fontWeight, FontWeight.w700);
      expect(style.color!.toARGB32(), AppColors.danger.color.toARGB32());
    });

    testWidgets('normal status text is neutral, not colored', (tester) async {
      await tester.pumpWidget(
        wrap(const OrderListRow(customerName: 'Ana', statusText: 'Aprovado')),
      );
      final style = tester.widget<Text>(find.text('Aprovado')).style!;
      expect(style.color!.toARGB32(), AppColors.textSecondary.color.toARGB32());
    });
  });
}
