import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/receipt.dart';
import 'package:praticos/screens/payments/receipt_detail_screen.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/services/customer_receipt_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/pdf/receipt_pdf.dart';

class _FakeService extends CustomerReceiptService {
  _FakeService(this.details, {this.failUndo = false});

  final ReceiptDetails? details;
  final bool failUndo;
  final undone = <Receipt>[];

  @override
  Future<ReceiptDetails?> load(String receiptId) async => details;

  @override
  Future<void> undo(Receipt receipt) async {
    if (failUndo) {
      throw const CustomerReceiptException(CustomerReceiptFailure.failed);
    }
    undone.add(receipt);
    receipt.status = ReceiptStatus.canceled;
  }
}

Order _order(String id, int number, double total, double paid) => Order()
  ..id = id
  ..number = number
  ..total = total
  ..paidAmount = paid;

Receipt _receipt({String status = ReceiptStatus.active, String? file}) =>
    Receipt()
      ..id = 'r1'
      ..amount = 500
      ..status = status
      ..paidAt = DateTime(2026, 10, 14)
      ..customer = (CustomerAggr()
        ..id = 'c1'
        ..name = 'João Silva')
      ..receiptFile = file == null
          ? null
          : ReceiptFile(
              url: 'https://x/$file',
              storagePath: 'tenants/co/receipts/r1/$file',
              fileName: file,
              contentType: 'image/jpeg',
            )
      ..allocations = [
        ReceiptAllocation(
          orderId: 'a',
          orderNumber: 185,
          amount: 400,
          transactionId: 'r1_0',
        ),
        ReceiptAllocation(
          orderId: 'b',
          orderNumber: 184,
          amount: 100,
          transactionId: 'r1_1',
        ),
      ];

ReceiptDetails _details({Receipt? receipt}) => ReceiptDetails(
  receipt: receipt ?? _receipt(),
  orders: {'a': _order('a', 185, 400, 400), 'b': _order('b', 184, 300, 100)},
);

void main() {
  setUp(() => FormatService().setLocale('pt-BR'));
  String brl(double v) => FormatService().formatCurrency(v);

  Future<void> pump(
    WidgetTester tester, {
    required _FakeService service,
    List<ReceiptPdfData>? sent,
    List<ReceiptFile>? viewed,
    List<bool>? popped,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                child: const Text('abrir'),
                onPressed: () async {
                  final undone = await Navigator.of(context).push<bool>(
                    CupertinoPageRoute(
                      builder: (_) => ReceiptDetailScreen(
                        receiptId: 'r1',
                        service: service,
                        onSend: (_, data) async => sent?.add(data),
                        onViewFile: (_, file) async => viewed?.add(file),
                        onOpenOrder: (_, __) {},
                      ),
                    ),
                  );
                  popped?.add(undone ?? false);
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('amount as title, customer and date, one row per OS', (
    tester,
  ) async {
    await pump(tester, service: _FakeService(_details()));

    expect(find.text(brl(500)), findsWidgets);
    expect(find.text('João Silva · 14/10/2026'), findsOneWidget);
    expect(find.text('OS 185 · ${brl(400)} · quitada'), findsOneWidget);
    expect(
      find.text('OS 184 · ${brl(100)} · falta ${brl(200)}'),
      findsOneWidget,
    );
    // No receipt file: no "Ver comprovante".
    expect(find.byKey(const Key('receiptFile')), findsNothing);
    // One blue button, named after the customer.
    expect(find.byType(PrimaryButton), findsOneWidget);
    expect(find.text('Mandar recibo para João'), findsOneWidget);
    expect(find.byKey(const Key('receiptMenu')), findsOneWidget);
  });

  testWidgets('"Mandar recibo" builds the recibo of this receipt', (
    tester,
  ) async {
    final sent = <ReceiptPdfData>[];
    await pump(tester, service: _FakeService(_details()), sent: sent);
    await tester.tap(find.byKey(const Key('receiptSend')));
    await tester.pumpAndSettle();

    final data = sent.single;
    expect(data.customerName, 'João Silva');
    expect(data.amount, 500);
    expect(data.lines.map((l) => l.orderNumber), [185, 184]);
    expect(data.lines.map((l) => l.open), [0, 200]);
  });

  testWidgets('the receipt file row opens the file', (tester) async {
    final viewed = <ReceiptFile>[];
    await pump(
      tester,
      service: _FakeService(_details(receipt: _receipt(file: 'pix.jpg'))),
      viewed: viewed,
    );
    expect(find.text('pix.jpg'), findsOneWidget);
    await tester.tap(find.byKey(const Key('receiptFile')));
    await tester.pumpAndSettle();
    expect(viewed.single.fileName, 'pix.jpg');
  });

  testWidgets('"…" > Desfazer recebimento asks, undoes and pops with true', (
    tester,
  ) async {
    final service = _FakeService(_details());
    final popped = <bool>[];
    await pump(tester, service: service, popped: popped);

    await tester.tap(find.byKey(const Key('receiptMenu')));
    await tester.pumpAndSettle();
    expect(find.text('Desfazer recebimento'), findsOneWidget);
    await tester.tap(find.text('Desfazer recebimento'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.text('Desfazer o recebimento de ${brl(500)}?'), findsOneWidget);
    expect(service.undone, isEmpty);
    await tester.tap(find.byKey(const Key('receiptUndoConfirm')));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(service.undone.single.id, 'r1');
    expect(popped, [true]);
  });

  testWidgets('canceling the dialog keeps the receipt', (tester) async {
    final service = _FakeService(_details());
    await pump(tester, service: service);
    await tester.tap(find.byKey(const Key('receiptMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desfazer recebimento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(service.undone, isEmpty);
    expect(find.byType(PrimaryButton), findsOneWidget);
  });

  testWidgets('a failed undo keeps the screen open', (tester) async {
    final popped = <bool>[];
    await pump(
      tester,
      service: _FakeService(_details(), failUndo: true),
      popped: popped,
    );
    await tester.tap(find.byKey(const Key('receiptMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desfazer recebimento'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('receiptUndoConfirm')));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(popped, isEmpty);
    expect(find.byType(PrimaryButton), findsOneWidget);
  });

  testWidgets('a canceled receipt says so, without button or menu', (
    tester,
  ) async {
    await pump(
      tester,
      service: _FakeService(
        _details(receipt: _receipt(status: ReceiptStatus.canceled)),
      ),
    );
    expect(find.text('Este recebimento foi desfeito.'), findsOneWidget);
    expect(find.byType(PrimaryButton), findsNothing);
    expect(find.byKey(const Key('receiptMenu')), findsNothing);
  });

  testWidgets('missing receipt shows the empty state', (tester) async {
    await pump(tester, service: _FakeService(null));
    expect(find.text('Não achamos este recebimento.'), findsOneWidget);
    expect(find.byType(PrimaryButton), findsNothing);
  });

  testWidgets('text scale 2: no overflow and rows wrap', (tester) async {
    await pump(tester, service: _FakeService(_details()), textScale: 2);
    expect(tester.takeException(), isNull);
    expect(find.text('Mandar recibo para João'), findsOneWidget);
  });
}
