import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/payment_transaction.dart';
import 'package:praticos/models/receipt.dart';
import 'package:praticos/models/user.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/pdf/receipt_pdf.dart';

Order _order(String id, int number, double total, double paid) => Order()
  ..id = id
  ..number = number
  ..total = total
  ..paidAmount = paid
  ..customer = (CustomerAggr()
    ..id = 'c1'
    ..name = 'João Silva');

void main() {
  final pt = lookupAppLocalizations(const Locale('pt'));
  final en = lookupAppLocalizations(const Locale('en'));
  late FormatService format;

  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    await initializeDateFormatting('en_US');
  });
  setUp(() => format = FormatService()..setLocale('pt-BR'));

  String brl(double v) => format.formatCurrency(v);

  final receipt = Receipt()
    ..id = 'ab3f9z_xyz'
    ..amount = 700
    ..paidAt = DateTime(2026, 10, 14)
    ..customer = (CustomerAggr()
      ..id = 'c1'
      ..name = 'João Silva')
    ..createdBy = (UserAggr()
      ..id = 'u1'
      ..name = 'Ana')
    ..allocations = [
      ReceiptAllocation(
        orderId: 'a',
        orderNumber: 184,
        amount: 400,
        transactionId: 'r_0',
      ),
      ReceiptAllocation(
        orderId: 'b',
        orderNumber: 185,
        amount: 300,
        transactionId: 'r_1',
      ),
    ];

  final orders = {
    'a': _order('a', 184, 400, 400)
      ..device = (DeviceAggr()
        ..id = 'd1'
        ..name = 'Fiat Uno'),
    'b': _order('b', 185, 500, 300)
      ..services = [OrderService()..description = 'Troca de óleo'],
  };

  test('receipt: sentence, table, total, what is still open, who, number', () {
    final data = ReceiptPdfData.fromReceipt(receipt, orders);
    final c = buildReceiptPdfContent(data, pt, format);

    expect(c.title, 'Recibo');
    expect(c.number, 'Nº AB3F9Z');
    expect(
      c.sentence,
      'Recebemos de João Silva a quantia de ${brl(700)} em 14/10/2026.',
    );
    expect(c.columns, ['OS', 'Descrição', 'Pago agora', 'Ainda falta']);
    expect(c.rows, [
      ['184', 'Fiat Uno', brl(400), '-'],
      ['185', 'Troca de óleo', brl(300), brl(200)],
    ]);
    expect(c.totalLabel, 'Total recebido');
    expect(c.totalValue, brl(700));
    expect(c.remaining, 'Falta receber ${brl(200)} dessas OS.');
    expect(c.recordedBy, 'Registrado por Ana');
    expect(c.fileName, 'Recibo-AB3F9Z');
  });

  test('everything settled: no "Falta receber" line', () {
    final settled = {...orders, 'b': _order('b', 185, 300, 300)};
    final c = buildReceiptPdfContent(
      ReceiptPdfData.fromReceipt(receipt, settled),
      pt,
      format,
    );
    expect(c.remaining, isNull);
    expect(c.rows[1][3], '-');
  });

  test('an order that could not be read still lists its share', () {
    final c = buildReceiptPdfContent(
      ReceiptPdfData.fromReceipt(receipt, {'a': orders['a']!}),
      pt,
      format,
    );
    expect(c.rows[1], ['185', '', brl(300), '-']);
  });

  test('single payment of one order (no Receipt document)', () {
    final order = _order('b', 185, 500, 300);
    final tx = PaymentTransaction(
      id: 'tx_998877',
      type: PaymentTransactionType.payment,
      amount: 300,
      createdAt: DateTime(2026, 10, 15, 9),
      paidAt: DateTime(2026, 10, 13),
      createdBy: UserAggr()
        ..id = 'u2'
        ..name = 'Rafael',
    );
    final c = buildReceiptPdfContent(
      ReceiptPdfData.fromPayment(order, tx),
      pt,
      format,
    );
    expect(
      c.sentence,
      'Recebemos de João Silva a quantia de ${brl(300)} em 13/10/2026.',
    );
    expect(c.rows, [
      ['185', '', brl(300), brl(200)],
    ]);
    expect(c.number, 'Nº TX9988');
    expect(c.recordedBy, 'Registrado por Rafael');
  });

  test('follows the app language', () {
    final usd = FormatService()..setLocale('en-US');
    final c = buildReceiptPdfContent(
      ReceiptPdfData.fromReceipt(receipt, orders),
      en,
      usd,
    );
    expect(c.title, 'Receipt');
    expect(c.sentence, startsWith('We received from João Silva'));
    expect(c.columns.first, 'Order');
  });

  test('customer without a name', () {
    final noName = Receipt.fromJson(receipt.toJson())..customer = null;
    final c = buildReceiptPdfContent(
      ReceiptPdfData.fromReceipt(noName, orders),
      pt,
      format,
    );
    expect(c.sentence, startsWith('Recebemos de Cliente sem nome'));
  });

  test('short number and safe text helpers', () {
    expect(receiptShortNumber(null), '-');
    expect(receiptShortNumber('a-b'), 'AB');
    expect(pdfSafeText('Ação 🚗'), 'Ação ');
  });

  test('generates a PDF without network (no logo)', () async {
    final bytes = await ReceiptPdfService().generate(
      buildReceiptPdfContent(
        ReceiptPdfData.fromReceipt(receipt, orders),
        pt,
        format,
      ),
      Company()..name = 'Oficina do Zé',
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
