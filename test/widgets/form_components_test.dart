import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/screens/widgets/add_row.dart';
import 'package:praticos/screens/widgets/app_form_field.dart';
import 'package:praticos/screens/widgets/app_sheet.dart';
import 'package:praticos/screens/widgets/money_field.dart';
import 'package:praticos/utils/currency_input.dart';
import 'package:praticos/screens/widgets/more_fields_link.dart';

Widget app(Widget home, {String locale = 'pt', Brightness? brightness}) {
  return CupertinoApp(
    locale: Locale(locale),
    theme: CupertinoThemeData(brightness: brightness),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

void main() {
  group('AppSheet', () {
    Future<void> openSheet(WidgetTester tester, void Function(Object?) onResult,
        {VoidCallback? onAction, bool withAction = true}) async {
      await tester.pumpWidget(app(Builder(
        builder: (context) => CupertinoPageScaffold(
          child: Center(
            child: CupertinoButton(
              child: const Text('open'),
              onPressed: () async {
                final r = await AppSheet.show<String>(
                  context,
                  (_) => AppSheet(
                    title: 'Novo cliente',
                    actionLabel: withAction ? 'Salvar' : null,
                    onAction: onAction,
                    child: const Text('conteudo'),
                  ),
                );
                onResult(r);
              },
            ),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('Cancelar on the left, title in the middle, action on the right',
        (tester) async {
      await openSheet(tester, (_) {}, onAction: () {});
      final cancel = tester.getCenter(find.text('Cancelar')).dx;
      final title = tester.getCenter(find.text('Novo cliente')).dx;
      final action = tester.getCenter(find.text('Salvar')).dx;
      expect(cancel, lessThan(title));
      expect(title, lessThan(action));
      expect(find.text('conteudo'), findsOneWidget);
    });

    testWidgets('Cancelar closes the sheet with no result', (tester) async {
      Object? result = 'unset';
      await openSheet(tester, (r) => result = r, onAction: () {});
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('conteudo'), findsNothing);
      expect(result, isNull);
    });

    testWidgets('the action runs its callback', (tester) async {
      var saved = 0;
      await openSheet(tester, (_) {}, onAction: () => saved++);
      await tester.tap(find.text('Salvar'));
      expect(saved, 1);
    });

    testWidgets('no action label means no trailing button', (tester) async {
      await openSheet(tester, (_) {}, withAction: false);
      expect(find.text('Salvar'), findsNothing);
      expect(find.text('Cancelar'), findsOneWidget);
    });
  });

  group('AppFormField', () {
    testWidgets('shows label, placeholder and hint; saves the text',
        (tester) async {
      final key = GlobalKey<FormState>();
      String? saved;
      await tester.pumpWidget(app(CupertinoPageScaffold(
        child: SafeArea(
          child: Form(
            key: key,
            child: AppFormField(
              label: 'Nome',
              placeholder: 'Ex.: Ana Ribeiro',
              hint: 'Ajuda',
              onSaved: (v) => saved = v,
            ),
          ),
        ),
      )));
      expect(find.text('Nome'), findsOneWidget);
      expect(find.text('Ex.: Ana Ribeiro'), findsOneWidget);
      expect(find.text('Ajuda'), findsOneWidget);
      await tester.enterText(find.byType(CupertinoTextField), 'Ana');
      key.currentState!.save();
      expect(saved, 'Ana');
    });

    testWidgets('validator error replaces the hint, in danger color',
        (tester) async {
      final key = GlobalKey<FormState>();
      await tester.pumpWidget(app(CupertinoPageScaffold(
        child: SafeArea(
          child: Form(
            key: key,
            child: AppFormField(
              label: 'Nome',
              hint: 'Ajuda',
              validator: (v) => v.isEmpty ? 'Digite o nome' : null,
            ),
          ),
        ),
      )));
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Digite o nome'), findsOneWidget);
      expect(find.text('Ajuda'), findsNothing);
      await tester.enterText(find.byType(CupertinoTextField), 'Ana');
      expect(key.currentState!.validate(), isTrue);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(app(
        const CupertinoPageScaffold(
          child: SafeArea(child: AppFormField(label: 'Nome')),
        ),
        brightness: Brightness.dark,
      ));
      expect(find.text('Nome'), findsOneWidget);
    });
  });

  group('MoreFieldsLink', () {
    testWidgets('hides the fields until the link is tapped', (tester) async {
      await tester.pumpWidget(app(const CupertinoPageScaffold(
        child: SafeArea(
          child: MoreFieldsLink(
            label: 'Mais dados',
            children: [Text('e-mail')],
          ),
        ),
      )));
      expect(find.text('e-mail'), findsNothing);
      expect(find.text('+ Mais dados'), findsOneWidget);
      await tester.tap(find.text('+ Mais dados'));
      await tester.pump();
      expect(find.text('e-mail'), findsOneWidget);
      expect(find.text('+ Mais dados'), findsNothing);
    });

    testWidgets('initiallyExpanded shows the fields right away',
        (tester) async {
      await tester.pumpWidget(app(const CupertinoPageScaffold(
        child: SafeArea(
          child: MoreFieldsLink(
            label: 'Mais dados',
            initiallyExpanded: true,
            children: [Text('e-mail')],
          ),
        ),
      )));
      expect(find.text('e-mail'), findsOneWidget);
      expect(find.text('+ Mais dados'), findsNothing);
    });
  });

  group('MoneyField', () {
    Future<List<double>> pump(WidgetTester tester, String locale,
        {double? initial}) async {
      final changes = <double>[];
      await tester.pumpWidget(app(
        CupertinoPageScaffold(
          child: SafeArea(
            child: MoneyField(
              label: 'Valor',
              initialValue: initial,
              onChanged: changes.add,
            ),
          ),
        ),
        locale: locale,
      ));
      return changes;
    }

    String text(WidgetTester tester) =>
        tester.widget<CupertinoTextField>(find.byType(CupertinoTextField)).controller!.text;

    String plain(String value) => value.replaceAll(' ', ' ');

    testWidgets('reads typed digits as whole BRL in pt', (tester) async {
      final changes = await pump(tester, 'pt');
      await tester.enterText(find.byType(CupertinoTextField), '250');
      expect(plain(text(tester)), 'R\$ 250');
      expect(changes.last, 250);
    });

    testWidgets('reads USD with the decimal point in en', (tester) async {
      final changes = await pump(tester, 'en');
      await tester.enterText(find.byType(CupertinoTextField), '1234.5');
      expect(text(tester), '\$1,234.5');
      expect(changes.last, 1234.5);
    });

    testWidgets('the comma opens the cents in pt', (tester) async {
      final changes = await pump(tester, 'pt');
      await tester.enterText(find.byType(CupertinoTextField), '1234,56');
      expect(plain(text(tester)), 'R\$ 1.234,56');
      expect(changes.last, 1234.56);
    });

    testWidgets('a dot from the device keyboard opens the cents in pt', (
      tester,
    ) async {
      final changes = await pump(tester, 'pt');
      final field = find.byType(CupertinoTextField);
      await tester.enterText(field, '12.');
      await tester.enterText(field, '${text(tester)}5');
      expect(changes.last, 12.5);
    });

    testWidgets('deletes one character at a time', (tester) async {
      final changes = await pump(tester, 'pt', initial: 250);
      final field = find.byType(CupertinoTextField);
      for (final expected in [250.0, 250.0, 250.0, 25.0, 2.0]) {
        final current = text(tester);
        await tester.enterText(field, current.substring(0, current.length - 1));
        expect(changes.last, expected);
      }
    });

    testWidgets('the amount reads while the cents are being typed', (
      tester,
    ) async {
      await pump(tester, 'pt');
      await tester.enterText(find.byType(CupertinoTextField), '250,');
      expect(parseCurrencyInput(text(tester)), 250);
      await tester.enterText(find.byType(CupertinoTextField), '250,5');
      expect(parseCurrencyInput(text(tester)), 250.5);
    });

    testWidgets('keeps at most two decimals', (tester) async {
      final changes = await pump(tester, 'pt');
      await tester.enterText(find.byType(CupertinoTextField), '10,999');
      expect(changes.last, 10.99);
    });

    testWidgets('shows the initial amount formatted', (tester) async {
      await pump(tester, 'pt', initial: 50);
      expect(text(tester).replaceAll(' ', ' '), 'R\$ 50,00');
    });

    testWidgets('saves the amount through the form', (tester) async {
      final key = GlobalKey<FormState>();
      double? saved;
      await tester.pumpWidget(app(CupertinoPageScaffold(
        child: SafeArea(
          child: Form(
            key: key,
            child: MoneyField(label: 'Valor', onSaved: (v) => saved = v),
          ),
        ),
      )));
      await tester.enterText(find.byType(CupertinoTextField), '1990');
      key.currentState!.save();
      expect(saved, 1990);
    });
  });

  testWidgets('AddRow shows the label and taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(app(CupertinoPageScaffold(
      child: SafeArea(
        child: AddRow(label: 'Cadastrar cliente novo', onTap: () => taps++),
      ),
    )));
    await tester.tap(find.text('Cadastrar cliente novo'));
    expect(taps, 1);
  });
}
