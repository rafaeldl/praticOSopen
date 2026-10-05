import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/utils/tax_id.dart';
import 'package:praticos/widgets/tax_id_form_field.dart';

const alphaCnpj = '12ABC34501DE35';

void main() {
  final l10n = AppLocalizationsPt();

  Future<GlobalKey<FormState>> pumpField(
    WidgetTester tester, {
    String? initialValue,
    required ValueChanged<String?> onSaved,
  }) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CupertinoPageScaffold(
          child: Form(
            key: formKey,
            child: ListView(
              children: [
                CupertinoListSection.insetGrouped(
                  children: [
                    TaxIdFormField(
                        initialValue: initialValue, onSaved: onSaved),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return formKey;
  }

  group('validateTaxIdInput', () {
    test('exemplo alfanumérico é válido segundo o util', () {
      expect(isValidTaxId(alphaCnpj), isTrue);
    });

    test('vazio é válido quando opcional', () {
      expect(validateTaxIdInput(l10n, ''), isNull);
      expect(validateTaxIdInput(l10n, null), isNull);
    });

    test('vazio é erro quando obrigatório', () {
      expect(validateTaxIdInput(l10n, '', required: true),
          l10n.asaasErrorTaxIdRequired);
    });

    test('CPF, CNPJ numérico e alfanumérico válidos, com ou sem máscara', () {
      expect(validateTaxIdInput(l10n, '529.982.247-25'), isNull);
      expect(validateTaxIdInput(l10n, '11222333000181'), isNull);
      expect(validateTaxIdInput(l10n, alphaCnpj), isNull);
      expect(validateTaxIdInput(l10n, '12.abc.345/01de-35'), isNull);
    });

    test('inválidos', () {
      expect(validateTaxIdInput(l10n, '12345678900'), l10n.invalidTaxId);
      expect(validateTaxIdInput(l10n, '123'), l10n.invalidTaxId);
      expect(validateTaxIdInput(l10n, '12ABC34501DE36'), l10n.invalidTaxId);
    });
  });

  group('TaxIdFormField', () {
    testWidgets('CPF válido salva normalizado', (tester) async {
      String? saved = 'untouched';
      final formKey = await pumpField(tester, onSaved: (v) => saved = v);

      await tester.enterText(find.byType(CupertinoTextField), '529.982.247-25');
      await tester.pump();

      expect(formKey.currentState!.validate(), isTrue);
      formKey.currentState!.save();
      expect(saved, '52998224725');
    });

    testWidgets('CNPJ alfanumérico minúsculo salva em maiúsculas',
        (tester) async {
      String? saved;
      final formKey = await pumpField(tester, onSaved: (v) => saved = v);

      await tester.enterText(find.byType(CupertinoTextField), '12abc34501de35');
      expect(formKey.currentState!.validate(), isTrue);
      formKey.currentState!.save();
      expect(saved, alphaCnpj);
    });

    testWidgets('CPF inválido mostra erro', (tester) async {
      final formKey = await pumpField(tester, onSaved: (_) {});

      await tester.enterText(find.byType(CupertinoTextField), '12345678900');
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();

      expect(find.text(l10n.invalidTaxId), findsOneWidget);
    });

    testWidgets('vazio salva null', (tester) async {
      String? saved = 'untouched';
      final formKey = await pumpField(tester, onSaved: (v) => saved = v);

      expect(formKey.currentState!.validate(), isTrue);
      formKey.currentState!.save();
      expect(saved, isNull);
    });

    testWidgets('valor inicial aparece formatado', (tester) async {
      await pumpField(tester, initialValue: alphaCnpj, onSaved: (_) {});
      expect(find.text('12.ABC.345/01DE-35'), findsOneWidget);
    });

    testWidgets('formata ao perder o foco', (tester) async {
      await pumpField(tester, onSaved: (_) {});

      await tester.showKeyboard(find.byType(CupertinoTextField));
      await tester.enterText(find.byType(CupertinoTextField), '52998224725');
      await tester.pump();
      expect(find.text('52998224725'), findsOneWidget);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(find.text('529.982.247-25'), findsOneWidget);
    });
  });
}
