import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/nfse.dart';
import 'package:praticos/models/payment_settings.dart';
import 'package:praticos/screens/nfse/nfse_access.dart';
import 'package:praticos/screens/nfse/nfse_invoice_screen.dart';
import 'package:praticos/screens/nfse/nfse_list_screen.dart';
import 'package:praticos/services/format_service.dart';

final _today = DateTime(2026, 10, 31);

NfseInvoice _nota(
  String id, {
  String status = 'authorized',
  String date = '2026-10-20',
  double value = 100,
  String customer = 'Ana Ribeiro',
  String? number = '1048',
  Map<String, Object?> extra = const {},
}) => NfseInvoice.fromJson({
  'status': status,
  'effectiveDate': date,
  'value': value,
  'orderIds': ['o-$id'],
  'orders': [
    {'orderId': 'o-$id', 'orderNumber': 214, 'value': value},
  ],
  'customer': {'id': 'c1', 'name': customer},
  'number': number,
  'createdAt': '2026-10-20T10:00:00.000',
  ...extra,
}, id: id);

NfseController _controller(
  Stream<List<NfseInvoice>> Function(String id) invoicesOf, {
  bool enabled = true,
}) => NfseController(
  canIssue: true,
  settingsStream: Stream.value(
    PaymentSettings(
      asaasEnabled: true,
      asaasConnected: true,
      nfseEnabled: enabled,
      nfseReady: true,
    ),
  ),
  invoicesOf: invoicesOf,
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    CupertinoApp(
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

Widget _screen(
  List<NfseInvoice> invoices, {
  String? customerId,
  String? customerName,
  DateTime? month,
  bool canSetUp = false,
}) => NfseListScreen(
  month: month ?? (customerId == null ? _today : null),
  customerId: customerId,
  customerName: customerName,
  today: _today,
  canSetUp: canSetUp,
  nfse: _controller((_) => Stream.value(invoices)),
);

void main() {
  setUp(() => FormatService().setLocale('pt_BR'));

  testWidgets('one sentence with the month and the issued total', (
    tester,
  ) async {
    await _pump(
      tester,
      _screen([
        _nota('a', value: 420),
        _nota('b', value: 280, customer: 'Bruno Lima', number: '1047'),
        _nota('c', value: 900, status: 'canceled', customer: 'Carla Dias'),
      ]),
    );
    final summary = tester.widget<Text>(
      find.byKey(const Key('nfseListSummary')),
    );
    expect(summary.data, contains('2 notas'));
    expect(summary.data, contains('700,00'));
    expect(find.text('Ana Ribeiro'), findsOneWidget);
    expect(find.text('Nota 1047 · OS 214 · 20/10'), findsOneWidget);
    expect(find.text('Cancelada'), findsOneWidget);
  });

  testWidgets('an empty month says how to issue one', (tester) async {
    await _pump(tester, _screen(const []));
    expect(find.textContaining('Nenhuma nota em'), findsOneWidget);
    expect(find.textContaining('abra a OS'), findsOneWidget);
  });

  testWidgets('a refused nota goes on top with the reason', (tester) async {
    await _pump(
      tester,
      _screen([
        _nota('ok'),
        _nota(
          'bad',
          status: 'error',
          number: null,
          customer: 'Paulo Dias',
          extra: {'statusDescription': 'CEP do cliente é inválido.'},
        ),
      ]),
    );
    expect(find.text('Precisa de atenção'), findsOneWidget);
    expect(find.text('CEP do cliente é inválido.'), findsOneWidget);
    final top = tester.getTopLeft(find.text('Paulo Dias')).dy;
    expect(top, lessThan(tester.getTopLeft(find.text('Ana Ribeiro')).dy));
  });

  testWidgets('the search appears past ten notas and filters', (tester) async {
    await _pump(tester, _screen([_nota('a')]));
    expect(find.byKey(const Key('nfseListSearch')), findsNothing);

    await _pump(
      tester,
      NfseListScreen(
        key: const ValueKey('many'),
        month: _today,
        today: _today,
        canSetUp: false,
        nfse: _controller(
          (_) => Stream.value([
            for (var i = 0; i < 10; i++) _nota('n$i', customer: 'Cliente $i'),
            _nota('j', customer: 'João Prado'),
          ]),
        ),
      ),
    );
    await tester.enterText(find.byType(CupertinoSearchTextField), 'joao');
    await tester.pumpAndSettle();
    expect(find.text('João Prado'), findsOneWidget);
    expect(find.text('Cliente 1'), findsNothing);

    await tester.enterText(find.byType(CupertinoSearchTextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.textContaining('Nada encontrado'), findsOneWidget);
  });

  testWidgets('steps the month and reads the new window', (tester) async {
    final windows = <String>[];
    await _pump(
      tester,
      NfseListScreen(
        month: DateTime(2026, 5),
        today: _today,
        canSetUp: false,
        nfse: _controller((id) {
          windows.add(id);
          return Stream.value([_nota('a', date: '2026-05-10')]);
        }),
      ),
    );
    expect(find.text('Ana Ribeiro'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Mês anterior'));
    await tester.pumpAndSettle();
    expect(windows, ['2026-05-01', '2026-04-01']);
    expect(find.text('Ana Ribeiro'), findsNothing);
  });

  testWidgets('of a customer: opens on its latest month, without the name', (
    tester,
  ) async {
    await _pump(
      tester,
      _screen(
        [_nota('a', date: '2026-07-10', number: '900')],
        customerId: 'c1',
        customerName: 'Ana',
      ),
    );
    expect(find.text('Notas de Ana'), findsWidgets);
    expect(find.text('Nota 900'), findsOneWidget);
    expect(find.text('Ana Ribeiro'), findsNothing);
  });

  testWidgets('the "…" is only for who sets it up', (tester) async {
    await _pump(tester, _screen([_nota('a')]));
    expect(find.byKey(const Key('nfseListMenu')), findsNothing);
    await _pump(
      tester,
      _screen([_nota('a')], canSetUp: true, month: DateTime(2026, 10, 2)),
    );
    expect(find.byKey(const Key('nfseListMenu')), findsOneWidget);
  });

  testWidgets('a read failure offers to try again', (tester) async {
    await _pump(
      tester,
      NfseListScreen(
        month: _today,
        today: _today,
        canSetUp: false,
        nfse: _controller((_) => Stream.error('denied')),
      ),
    );
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  group('row of the Financeiro tab', () {
    Widget row(NfseController nfse) => CupertinoPageScaffold(
      child: SafeArea(
        child: NfseMonthRow(
          month: DateTime.now(),
          nfse: nfse,
          wrap: (row) => row,
        ),
      ),
    );

    testWidgets('nothing while notas are off', (tester) async {
      await _pump(
        tester,
        row(_controller((_) => Stream.value(const []), enabled: false)),
      );
      expect(find.byKey(const Key('financialNfse')), findsNothing);
    });

    testWidgets('shows the count, never money', (tester) async {
      final day = DateTime.now();
      final date =
          '${day.year}-${'${day.month}'.padLeft(2, '0')}-'
          '${'${day.day}'.padLeft(2, '0')}';
      await _pump(
        tester,
        row(
          _controller(
            (_) => Stream.value([
              _nota('a', date: date, value: 420),
              _nota('b', date: date, value: 280),
            ]),
          ),
        ),
      );
      expect(find.text('Notas fiscais'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.textContaining('R\$'), findsNothing);
    });

    testWidgets('warns when something needs attention', (tester) async {
      final day = DateTime.now();
      final date =
          '${day.year}-${'${day.month}'.padLeft(2, '0')}-'
          '${'${day.day}'.padLeft(2, '0')}';
      await _pump(
        tester,
        row(
          _controller(
            (_) => Stream.value([_nota('a', date: date, status: 'error')]),
          ),
        ),
      );
      expect(find.text('1 precisa de atenção'), findsOneWidget);
    });
  });

  group('invoice screen buttons', () {
    testWidgets('issued with PDF: blue button shares it', (tester) async {
      NfseInvoice? shared;
      final nota = _nota('a', extra: {'pdfUrl': 'https://x/a.pdf'});
      await _pump(
        tester,
        NfseInvoiceScreen(
          invoice: nota,
          invoiceStream: const Stream.empty(),
          sharePdf: (_, invoice) async => shared = invoice,
        ),
      );
      await tester.tap(find.byKey(const Key('nfseSharePdf')));
      await tester.pumpAndSettle();
      expect(shared, nota);
    });

    testWidgets('issued without PDF yet: no button', (tester) async {
      await _pump(
        tester,
        NfseInvoiceScreen(
          invoice: _nota('a'),
          invoiceStream: const Stream.empty(),
        ),
      );
      expect(find.byKey(const Key('nfseSharePdf')), findsNothing);
    });

    testWidgets('refused: offers "Corrigir e emitir"', (tester) async {
      await _pump(
        tester,
        NfseInvoiceScreen(
          invoice: _nota('a', status: 'error'),
          invoiceStream: const Stream.empty(),
        ),
      );
      expect(find.text('Corrigir e emitir'), findsOneWidget);
    });
  });
}
