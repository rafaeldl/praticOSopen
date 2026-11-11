import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/product.dart';
import 'package:praticos/models/service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/pdf/customer_statement_pdf.dart';

Order _done() => Order()
  ..id = 'a'
  ..number = 182
  ..status = 'done'
  ..createdAt = DateTime(2026, 10, 3)
  ..total = 480
  ..discount = 20
  ..paidAmount = 180
  ..devices = [
    DeviceAggr()
      ..name = 'Fiat Uno'
      ..serial = 'ABC-1234',
  ]
  ..services = [
    OrderService()
      ..service = (ServiceAggr()..name = 'Troca de óleo')
      ..value = 150,
  ]
  ..products = [
    OrderProduct()
      ..product = (ProductAggr()..name = 'Filtro')
      ..quantity = 2
      ..value = 50
      ..total = 100,
    OrderProduct()
      ..description = 'Pastilha'
      ..quantity = 1
      ..value = 250,
  ];

Order _running() => Order()
  ..id = 'b'
  ..number = 190
  ..status = 'progress'
  ..createdAt = DateTime(2026, 10, 12)
  ..total = 150
  ..paidAmount = 0
  ..services = [
    OrderService()
      ..description = 'Alinhamento'
      ..value = 150,
  ];

void main() {
  final pt = lookupAppLocalizations(const Locale('pt'));
  late FormatService format;

  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });
  setUp(() => format = FormatService()..setLocale('pt-BR'));

  String brl(double v) => format.formatCurrency(v);

  CustomerStatementData data({String? company = 'Oficina Boa'}) =>
      CustomerStatementData(
        customerName: 'João',
        companyName: company,
        date: DateTime(2026, 11, 6),
        orders: [
          StatementOrder.fromOrder(_done()),
          StatementOrder.fromOrder(_running()),
        ],
      );

  group('StatementOrder.fromOrder', () {
    test('services and parts with quantity and line value', () {
      final order = StatementOrder.fromOrder(_done());
      expect(
        [for (final i in order.items) (i.name, i.quantity, i.value)],
        [
          ('Troca de óleo', 1, 150.0),
          ('Filtro', 2, 100.0),
          ('Pastilha', 1, 250.0),
        ],
      );
      expect(order.device, 'Fiat Uno · ABC-1234');
      expect(order.completed, isTrue);
      expect(order.open, 300);
      expect(order.discount, 20);
    });

    test('in progress, and unknown status for an order read without it', () {
      expect(StatementOrder.fromOrder(_running()).completed, isFalse);
      final light = Order()
        ..id = 'x'
        ..number = 5
        ..total = 90
        ..paidAmount = 0;
      final order = StatementOrder.fromOrder(light);
      expect(order.completed, isNull);
      expect(order.items, isEmpty);
      expect(order.open, 90);
    });

    test('without a device, the first service describes it', () {
      expect(StatementOrder.fromOrder(_running()).device, 'Alinhamento');
    });
  });

  group('buildStatementText', () {
    test('one block per order and the total owed', () {
      final text = buildStatementText(data(), pt, format);
      expect(
        text,
        [
          'Olá, João! Estas são as OS em aberto com Oficina Boa:',
          '',
          'OS 182 · ${format.formatDayMonthOrDate(DateTime(2026, 10, 3))}'
              ' · Fiat Uno · ABC-1234',
          'Falta ${brl(300)}',
          '',
          'OS 190 · ${format.formatDayMonthOrDate(DateTime(2026, 10, 12))}'
              ' · Alinhamento · em andamento',
          'Falta ${brl(150)}',
          '',
          'Total em aberto: ${brl(450)}',
        ].join('\n'),
      );
    });

    test('without company name', () {
      final text = buildStatementText(data(company: null), pt, format);
      expect(text, startsWith('Olá, João! Estas são as OS em aberto:'));
    });
  });

  group('buildStatementPdfContent', () {
    test('blocks with items, discount and amounts', () {
      final content = buildStatementPdfContent(data(), pt, format);
      expect(content.title, 'Extrato');
      expect(content.sentence, 'OS em aberto de João em 06/11/2026.');
      expect(content.columns, ['Serviço ou peça', 'Qtd', 'Valor']);
      expect(content.blocks, hasLength(2));

      final first = content.blocks.first;
      expect(first.title, 'OS 182 · 03/10/2026 · Concluído');
      expect(first.device, 'Fiat Uno · ABC-1234');
      expect(first.rows, [
        ['Troca de óleo', '1', brl(150)],
        ['Filtro', '2', brl(100)],
        ['Pastilha', '1', brl(250)],
      ]);
      expect(first.discount, 'Desconto  - ${brl(20)}');
      expect(
        first.totals,
        'Total ${brl(480)}  ·  Pago ${brl(180)}  ·  Falta ${brl(300)}',
      );

      expect(content.blocks.last.title, 'OS 190 · 12/10/2026 · Em Andamento');
      expect(content.blocks.last.discount, isNull);
      // No device: the service is already in the table.
      expect(content.blocks.last.device, isNull);
      expect(content.totalValue, brl(450));
      expect(content.fileName, 'Extrato-2026-11-06');
    });

    test('draws a PDF', () async {
      final content = buildStatementPdfContent(data(), pt, format);
      final bytes = await CustomerStatementPdfService().generate(
        content,
        Company()..name = 'Oficina Boa',
      );
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    });
  });
}
