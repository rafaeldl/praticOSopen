import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/fiscal_address.dart';
import 'package:praticos/models/nfse.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/screens/customers/customer_detail_screen.dart';
import 'package:praticos/screens/customers/customer_form_screen.dart';
import 'package:praticos/screens/customers/customer_invoice_fields.dart';
import 'package:praticos/screens/nfse/nfse_access.dart';
import 'package:praticos/services/fiscal_lookup_service.dart';
import 'package:provider/provider.dart';

import 'customer_screens_test.dart' show FakeDirectory;

const _cnpj = '11222333000181';
const _on = CustomerInvoiceConfig(enabled: true);

class _FakeLookup extends FiscalLookupService {
  _FakeLookup({this.cnpj, this.cep});

  final CnpjInfo? cnpj;
  final FiscalAddress? cep;
  final List<String> asked = [];

  @override
  Future<CnpjInfo?> lookupCnpj(String value) async {
    asked.add(value);
    return cnpj;
  }

  @override
  Future<FiscalAddress?> lookupPostalCode(String value) async {
    asked.add(value);
    return cep;
  }
}

Customer _customer(String id, String name, {String? taxId}) => Customer()
  ..id = id
  ..name = name
  ..taxId = taxId;

/// Pushes [screen] from a launcher; [result] has what it popped.
class _Harness {
  Object? result;

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1170, 4000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<SegmentConfigProvider>(
        create: (_) => SegmentConfigProvider(),
        child: CupertinoApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => CupertinoPageScaffold(
              child: Center(
                child: CupertinoButton(
                  child: const Text('open'),
                  onPressed: () async {
                    result = await Navigator.of(
                      context,
                    ).push(CupertinoPageRoute(builder: (_) => screen));
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }
}

Finder _field(String key) => find.descendant(
  of: find.byKey(Key(key)),
  matching: find.byType(CupertinoTextField),
);

String _text(WidgetTester tester, String key) =>
    tester.widget<CupertinoTextField>(_field(key)).controller!.text;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('findCustomerWithTaxId', () {
    final list = [
      _customer('a', 'Loja Centro', taxId: _cnpj),
      _customer('b', 'Ana', taxId: '52998224725'),
    ];

    test('finds the other customer with the same number', () {
      expect(
        findCustomerWithTaxId(list, '11.222.333/0001-81', exceptId: 'x')?.id,
        'a',
      );
      expect(findCustomerWithTaxId(list, '529.982.247-25')?.id, 'b');
    });

    test('ignores the customer being saved and an empty number', () {
      expect(findCustomerWithTaxId(list, _cnpj, exceptId: 'a'), isNull);
      expect(findCustomerWithTaxId(list, ''), isNull);
      expect(findCustomerWithTaxId(list, null), isNull);
    });
  });

  group('CustomerInvoiceConfig', () {
    test('the switch shows only when the nota can go out by itself', () {
      expect(_on.showAutoIssue, isFalse);
      const chosen = CustomerInvoiceConfig(
        enabled: true,
        autoIssue: NfseDirectAutoIssue.selectedCustomers,
      );
      const all = CustomerInvoiceConfig(
        enabled: true,
        autoIssue: NfseDirectAutoIssue.allOrders,
      );
      expect(chosen.showAutoIssue, isTrue);
      expect(chosen.autoIssueOf(Customer()), isFalse);
      expect(all.autoIssueOf(Customer()), isTrue);
      expect(all.autoIssueOf(Customer()..autoIssueInvoice = false), isFalse);
    });
  });

  group('"Dados para nota" in the customer form', () {
    testWidgets('off: no group, CPF/CNPJ stays in "Mais dados"', (
      tester,
    ) async {
      await _Harness().pump(
        tester,
        CustomerFormScreen(
          customer: _customer('c1', 'Loja Centro'),
          invoiceConfig: CustomerInvoiceConfig.off,
        ),
      );
      expect(find.text('Dados para nota'), findsNothing);
    });

    testWidgets('new customer: closed card that opens the fields', (
      tester,
    ) async {
      await _Harness().pump(
        tester,
        CustomerFormScreen(asSheet: true, invoiceConfig: _on),
      );
      expect(find.text('Dados para nota'), findsOneWidget);
      await tester.tap(find.text('Dados para nota'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('customerInvoiceData')),
          matching: find.byKey(const Key('taxIdFormField')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a typed CNPJ fills legal name and address from the Receita', (
      tester,
    ) async {
      final lookup = _FakeLookup(
        cnpj: CnpjInfo(
          legalName: 'REVENDA EXEMPLO LTDA',
          email: 'fiscal@revenda.com.br',
          address: FiscalAddress(
            postalCode: '80010000',
            street: 'Rua Das Flores',
            number: '100',
            district: 'Centro',
            cityName: 'Curitiba',
            cityCode: '4106902',
            state: 'PR',
          ),
        ),
      );
      Customer? saved;
      await _Harness().pump(
        tester,
        CustomerFormScreen(
          customer: _customer('c1', 'Loja Centro'),
          invoiceConfig: _on,
          lookup: lookup,
          loadCustomers: () async => const [],
          onSave: (c) async => saved = c,
        ),
      );
      await tester.tap(find.text('+ Dados para nota'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('taxIdFormField')), _cnpj);
      await tester.pumpAndSettle();

      expect(lookup.asked, [_cnpj]);
      expect(
        find.text(
          'Preenchido com os dados da Receita. Confira antes de salvar.',
        ),
        findsOneWidget,
      );
      expect(_text(tester, 'invoiceLegalName'), 'REVENDA EXEMPLO LTDA');
      expect(_text(tester, 'invoicePostalCode'), '80010-000');
      expect(_text(tester, 'invoiceCity'), 'Curitiba');

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(saved!.taxId, _cnpj);
      expect(saved!.legalName, 'REVENDA EXEMPLO LTDA');
      expect(saved!.invoiceEmail, 'fiscal@revenda.com.br');
      expect(saved!.fiscalAddress!.cityCode, '4106902');
      expect(saved!.fiscalAddress!.isComplete, isTrue);
    });

    testWidgets('a CNPJ not found asks to fill by hand', (tester) async {
      await _Harness().pump(
        tester,
        CustomerFormScreen(
          customer: _customer('c1', 'Loja Centro', taxId: '52998224725'),
          invoiceConfig: _on,
          lookup: _FakeLookup(),
        ),
      );
      await tester.enterText(find.byKey(const Key('taxIdFormField')), _cnpj);
      await tester.pumpAndSettle();
      expect(
        find.text('Não achamos este CNPJ na Receita. Preencha à mão.'),
        findsOneWidget,
      );
    });

    testWidgets('the CEP fills street, district and city', (tester) async {
      final lookup = _FakeLookup(
        cep: FiscalAddress(
          postalCode: '01310100',
          street: 'Avenida Paulista',
          district: 'Bela Vista',
          cityName: 'São Paulo',
          cityCode: '3550308',
          state: 'SP',
        ),
      );
      Customer? saved;
      await _Harness().pump(
        tester,
        CustomerFormScreen(
          customer: _customer('c1', 'Ana', taxId: '52998224725'),
          invoiceConfig: _on,
          lookup: lookup,
          onSave: (c) async => saved = c,
        ),
      );
      await tester.enterText(_field('invoicePostalCode'), '01310100');
      await tester.pumpAndSettle();
      expect(_text(tester, 'invoiceStreet'), 'Avenida Paulista');
      expect(_text(tester, 'invoiceDistrict'), 'Bela Vista');
      expect(_text(tester, 'invoiceState'), 'SP');

      await tester.enterText(_field('invoiceNumber'), '1000');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      final a = saved!.fiscalAddress!;
      expect(a.postalCode, '01310100');
      expect(a.number, '1000');
      expect(a.cityCode, '3550308');
    });

    testWidgets('typing another city drops the code from the CEP', (
      tester,
    ) async {
      Customer? saved;
      final c = _customer('c1', 'Ana', taxId: '52998224725')
        ..fiscalAddress = FiscalAddress(
          postalCode: '01310100',
          cityName: 'São Paulo',
          cityCode: '3550308',
        );
      await _Harness().pump(
        tester,
        CustomerFormScreen(
          customer: c,
          invoiceConfig: _on,
          lookup: _FakeLookup(),
          onSave: (c) async => saved = c,
        ),
      );
      await tester.enterText(_field('invoiceCity'), 'Osasco');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(saved!.fiscalAddress!.cityName, 'Osasco');
      expect(saved!.fiscalAddress!.cityCode, isNull);
    });

    testWidgets('a CNPJ another customer has blocks and offers "Mandar as '
        'notas desta loja para ela"', (tester) async {
      final owner = _customer('r1', 'Revenda', taxId: _cnpj)
        ..legalName = 'REVENDA EXEMPLO LTDA';
      final saves = <Customer>[];
      final h = _Harness();
      await h.pump(
        tester,
        CustomerFormScreen(
          customer: _customer('c1', 'Loja Centro'),
          invoiceConfig: _on,
          lookup: _FakeLookup(),
          loadCustomers: () async => [owner],
          onSave: (c) async => saves.add(c),
        ),
      );
      await tester.tap(find.text('+ Dados para nota'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('taxIdFormField')), _cnpj);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(
        find.text('REVENDA EXEMPLO LTDA já tem este CNPJ'),
        findsOneWidget,
      );
      expect(saves, isEmpty);
      await tester.tap(find.byKey(const Key('invoiceTaxIdTakenUse')));
      await tester.pumpAndSettle();

      expect(saves, hasLength(1));
      expect(saves.single.taxId, isNull);
      expect(saves.single.invoiceRecipient?.id, 'r1');
      expect(h.result, same(saves.single));
    });

    testWidgets('"Voltar" on the repeated CNPJ saves nothing', (tester) async {
      final owner = _customer('r1', 'Revenda', taxId: _cnpj);
      final saves = <Customer>[];
      await _Harness().pump(
        tester,
        CustomerFormScreen(
          customer: _customer('c1', 'Loja Centro', taxId: '52998224725'),
          invoiceConfig: _on,
          lookup: _FakeLookup(),
          loadCustomers: () async => [owner],
          onSave: (c) async => saves.add(c),
        ),
      );
      await tester.enterText(find.byKey(const Key('taxIdFormField')), _cnpj);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();
      expect(saves, isEmpty);
      expect(find.text('Editar cliente'), findsOneWidget);
    });

    testWidgets('saving the same CPF/CNPJ again does not ask', (tester) async {
      final saves = <Customer>[];
      await _Harness().pump(
        tester,
        CustomerFormScreen(
          customer: _customer('c1', 'Loja Centro', taxId: _cnpj),
          invoiceConfig: _on,
          lookup: _FakeLookup(),
          loadCustomers: () async => [_customer('r1', 'Outra', taxId: _cnpj)],
          onSave: (c) async => saves.add(c),
        ),
      );
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(saves, hasLength(1));
    });

    testWidgets('"Emitir nota sozinha" shows only when the nota goes out by '
        'itself, and saves the choice', (tester) async {
      Customer? saved;
      await _Harness().pump(
        tester,
        CustomerFormScreen(
          customer: _customer('c1', 'Loja Centro', taxId: _cnpj),
          invoiceConfig: const CustomerInvoiceConfig(
            enabled: true,
            autoIssue: NfseDirectAutoIssue.selectedCustomers,
          ),
          lookup: _FakeLookup(),
          loadCustomers: () async => const [],
          onSave: (c) async => saved = c,
        ),
      );
      final toggle = find.byKey(const Key('invoiceAutoIssueSwitch'));
      expect(tester.widget<CupertinoSwitch>(toggle).value, isFalse);
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(saved!.autoIssueInvoice, isTrue);
    });

    testWidgets('no switch when the nota never goes out by itself', (
      tester,
    ) async {
      await _Harness().pump(
        tester,
        CustomerFormScreen(
          customer: _customer('c1', 'Loja Centro', taxId: _cnpj),
          invoiceConfig: _on,
          lookup: _FakeLookup(),
        ),
      );
      expect(find.byKey(const Key('invoiceAutoIssueSwitch')), findsNothing);
    });
  });

  group('"Nota fiscal para" on the customer screen', () {
    final store = _customer('c1', 'Loja Centro');
    final revenda = _customer('r1', 'Revenda', taxId: _cnpj)
      ..legalName = 'REVENDA EXEMPLO LTDA';

    Widget screen({
      required Customer customer,
      required List<Customer> saves,
      CustomerInvoiceConfig config = _on,
    }) => CustomerDetailScreen(
      can: (_) => true,
      customer: customer,
      directory: FakeDirectory(customers: [customer, revenda]),
      nfse: NfseController(canIssue: false),
      showPrices: false,
      canSeeReceipts: false,
      canReceiveOn: (_) => false,
      invoiceConfig: config,
      saveCustomer: (c) async => saves.add(c),
    );

    testWidgets('"…" → "Mandar a nota para outro cliente" picks and saves', (
      tester,
    ) async {
      final saves = <Customer>[];
      final c = Customer.fromJson(store.toJson())..id = 'c1';
      await _Harness().pump(tester, screen(customer: c, saves: saves));
      expect(
        find.byKey(const Key('customerInvoiceRecipientRow')),
        findsNothing,
      );
      await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('customerInvoiceRecipient')));
      await tester.pumpAndSettle();

      expect(find.text('Para quem vai a nota?'), findsWidgets);
      expect(find.text('Nenhum: a nota vai para o próprio cliente'),
          findsOneWidget);
      await tester.tap(find.text('REVENDA EXEMPLO LTDA'));
      await tester.pumpAndSettle();

      expect(saves.single.invoiceRecipient?.id, 'r1');
      expect(
        find.byKey(const Key('customerInvoiceRecipientRow')),
        findsOneWidget,
      );
      expect(find.text('Revenda'), findsWidgets);
    });

    testWidgets('"Nenhum" takes the recipient off', (tester) async {
      final saves = <Customer>[];
      final c = Customer.fromJson(store.toJson())
        ..id = 'c1'
        ..invoiceRecipient = revenda.toAggr();
      await _Harness().pump(tester, screen(customer: c, saves: saves));
      await tester.tap(find.byKey(const Key('customerInvoiceRecipientRow')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('invoiceRecipientNone')));
      await tester.pumpAndSettle();
      expect(saves.single.invoiceRecipient, isNull);
      expect(
        find.byKey(const Key('customerInvoiceRecipientRow')),
        findsNothing,
      );
    });

    testWidgets('off: no menu action and no row', (tester) async {
      final c = Customer.fromJson(store.toJson())
        ..id = 'c1'
        ..invoiceRecipient = revenda.toAggr();
      await _Harness().pump(
        tester,
        screen(
          customer: c,
          saves: [],
          config: CustomerInvoiceConfig.off,
        ),
      );
      expect(
        find.byKey(const Key('customerInvoiceRecipientRow')),
        findsNothing,
      );
      await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('customerInvoiceRecipient')), findsNothing);
    });
  });
}
