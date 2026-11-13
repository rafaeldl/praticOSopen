import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/pdf/pdf_image_loader.dart';
import 'package:praticos/services/pdf/pdf_styles.dart';
import 'package:praticos/services/pdf/receipt_pdf.dart'
    show orderShortDescription, pdfCompanyHeader, pdfSafeText;
import 'package:praticos/utils/order_payment_math.dart';

/// One service or part of an order on the extrato.
class StatementItem {
  const StatementItem({
    required this.name,
    required this.quantity,
    required this.value,
    this.description,
  });

  final String name;

  /// The note typed on the item ("para-choque dianteiro"), when it adds to
  /// [name].
  final String? description;
  final int quantity;

  /// "Pintura - para-choque dianteiro", like the order PDF.
  String get label => description == null ? name : '$name - $description';

  /// Line total (quantity × unit value).
  final double value;
}

/// One open order on the extrato: what it is, what it costs and what is
/// still owed on it.
class StatementOrder {
  const StatementOrder({
    required this.number,
    required this.date,
    this.completed,
    required this.total,
    required this.paid,
    required this.open,
    this.device,
    this.items = const [],
    this.discount = 0,
  });

  /// From a full [Order]. Orders read without their items (someone else's,
  /// for a consultant) come with only number, date and amounts.
  factory StatementOrder.fromOrder(Order order) {
    final items = <StatementItem>[
      for (final s in order.services ?? const <OrderService>[])
        if ((s.service?.name ?? s.description ?? '').trim().isNotEmpty ||
            (s.value ?? 0) > 0)
          StatementItem(
            name: (s.service?.name ?? s.description ?? '').trim(),
            description: _itemNote(s.service?.name, s.description),
            quantity: 1,
            value: s.value ?? 0,
          ),
      for (final p in order.products ?? const <OrderProduct>[])
        if ((p.product?.name ?? p.description ?? '').trim().isNotEmpty ||
            (p.total ?? p.value ?? 0) > 0)
          StatementItem(
            name: (p.product?.name ?? p.description ?? '').trim(),
            description: _itemNote(p.product?.name, p.description),
            quantity: p.quantity ?? 1,
            value: p.total ?? (p.value ?? 0) * (p.quantity ?? 1),
          ),
    ];
    final total = order.total ?? 0;
    final paid = order.paidAmount ?? 0;
    return StatementOrder(
      number: order.number,
      date: order.createdAt,
      completed: order.status == null ? null : order.status == 'done',
      device: statementDeviceOf(order),
      items: items,
      discount: order.discount ?? 0,
      total: total,
      paid: paid > total ? total : paid,
      open: OrderPaymentMath.remainingBalance(order),
    );
  }

  final int? number;
  final DateTime? date;

  /// Concluída, or still being done (approved or running). Null when the
  /// status was not read (someone else's order).
  final bool? completed;

  /// "Fiat Uno · ABC-1234", several joined with ", ".
  final String? device;
  final List<StatementItem> items;
  final double discount;
  final double total;
  final double paid;
  final double open;
}

/// The item's note when it has a catalog name and the note says something
/// else (without a catalog name the note already is the name).
String? _itemNote(String? name, String? description) {
  final n = name?.trim() ?? '';
  final d = description?.trim() ?? '';
  return n.isEmpty || d.isEmpty || d == n ? null : d;
}

/// Devices of [order] with name and serial ("Fiat Uno · ABC-1234"), or its
/// first service when it has no device.
String? statementDeviceOf(Order order) {
  final devices = [
    for (final d in order.effectiveDevices)
      [
        if ((d.name ?? '').trim().isNotEmpty) d.name!.trim(),
        if ((d.serial ?? '').trim().isNotEmpty) d.serial!.trim(),
      ].join(' · '),
  ].where((d) => d.isNotEmpty).toList();
  if (devices.isNotEmpty) return devices.join(', ');
  return orderShortDescription(order);
}

/// What goes to the customer: who, from whom, when, and the orders.
class CustomerStatementData {
  const CustomerStatementData({
    required this.customerName,
    required this.date,
    required this.orders,
    this.companyName,
  });

  final String customerName;
  final String? companyName;
  final DateTime date;

  /// Oldest first, as the screen lists them.
  final List<StatementOrder> orders;

  double get totalOpen =>
      orders.fold<int>(0, (sum, o) => sum + (o.open * 100).round()) / 100;
}

String _customer(CustomerStatementData data, AppLocalizations l10n) =>
    data.customerName.trim().isEmpty
    ? l10n.customerWithoutName
    : data.customerName.trim();

/// The WhatsApp message: a hello, one block per order (number, date, device
/// or first service, "em andamento" when not completed, what is owed) and
/// the total owed.
String buildStatementText(
  CustomerStatementData data,
  AppLocalizations l10n,
  FormatService format,
) {
  final name = _customer(data, l10n);
  final company = data.companyName?.trim() ?? '';
  final lines = <String>[
    company.isEmpty
        ? l10n.statementTextHelloNoCompany(name)
        : l10n.statementTextHello(name, company),
  ];
  for (final order in data.orders) {
    final head = [
      l10n.statementOrderNumber(order.number == null ? '-' : '${order.number}'),
      if (order.date != null) format.formatDayMonthOrDate(order.date),
      if ((order.device ?? '').isNotEmpty) order.device!,
      if (order.completed == false) l10n.statementInProgress,
    ].join(' · ');
    lines
      ..add('')
      ..add(head)
      ..add(l10n.statementOpenLine(format.formatCurrency(order.open)));
  }
  lines
    ..add('')
    ..add(l10n.statementTotalOpen(format.formatCurrency(data.totalOpen)));
  return lines.join('\n');
}

/// One order block of the PDF, already formatted.
class StatementPdfBlock {
  const StatementPdfBlock({
    required this.title,
    required this.rows,
    required this.totals,
    this.device,
    this.discount,
  });

  /// "OS 182 · 03/10/2026 · Concluído".
  final String title;
  final String? device;

  /// Item, quantity, value.
  final List<List<String>> rows;

  /// "Desconto  - R$ 20,00" (null without discount).
  final String? discount;

  /// "Total R$ 500,00 · Pago R$ 200,00 · Falta R$ 300,00".
  final String totals;
}

/// Every text of the extrato PDF, localized and formatted. Pure: tests read
/// this instead of the PDF.
class CustomerStatementContent {
  const CustomerStatementContent({
    required this.title,
    required this.date,
    required this.sentence,
    required this.columns,
    required this.blocks,
    required this.totalLabel,
    required this.totalValue,
    required this.fileName,
  });

  final String title;

  /// Today, under the title.
  final String date;

  /// "OS em aberto de João em 06/11/2026."
  final String sentence;

  /// Item, quantity, value.
  final List<String> columns;
  final List<StatementPdfBlock> blocks;
  final String totalLabel;
  final String totalValue;

  /// Without extension ("Extrato-2026-11-06").
  final String fileName;
}

CustomerStatementContent buildStatementPdfContent(
  CustomerStatementData data,
  AppLocalizations l10n,
  FormatService format,
) {
  final today = format.formatDate(data.date);
  final d = data.date;
  String two(int n) => n.toString().padLeft(2, '0');
  return CustomerStatementContent(
    title: l10n.statementPdfTitle,
    date: today,
    sentence: l10n.statementPdfSentence(_customer(data, l10n), today),
    columns: [l10n.statementItemColumn, l10n.quantityShort, l10n.valueColumn],
    blocks: [
      for (final order in data.orders)
        StatementPdfBlock(
          title: [
            l10n.statementOrderNumber(
              order.number == null ? '-' : '${order.number}',
            ),
            if (order.date != null) format.formatDate(order.date),
            if (order.completed != null)
              order.completed! ? l10n.statusCompleted : l10n.statusInProgress,
          ].join(' · '),
          // Without a device, [StatementOrder.device] is the first item, already in
          // the table.
          device:
              order.items.isNotEmpty && order.device == order.items.first.name
              ? null
              : order.device,
          rows: [
            for (final item in order.items)
              [
                item.label,
                '${item.quantity}',
                format.formatCurrency(item.value),
              ],
          ],
          discount: order.discount > 0
              ? '${l10n.discount}  - ${format.formatCurrency(order.discount)}'
              : null,
          totals: l10n.statementOrderTotals(
            format.formatCurrency(order.total),
            format.formatCurrency(order.paid),
            format.formatCurrency(order.open),
          ),
        ),
    ],
    totalLabel: l10n.statementPdfTotalOpen,
    totalValue: format.formatCurrency(data.totalOpen),
    fileName: l10n.statementFileName('${d.year}-${two(d.month)}-${two(d.day)}'),
  );
}

/// Draws the extrato.
class CustomerStatementPdfService {
  CustomerStatementPdfService({PdfImageLoader? imageLoader})
    : _imageLoader = imageLoader ?? PdfImageLoader();

  final PdfImageLoader _imageLoader;

  Future<Uint8List> generate(
    CustomerStatementContent content,
    Company company,
  ) async {
    final logo = await _imageLoader.loadLogo(company.logo);
    final base = pw.Font.helvetica();
    final bold = pw.Font.helveticaBold();
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(
          pageFormat: PdfStyles.pageFormat,
          margin: PdfStyles.pageMargin,
        ),
        header: (_) => pdfCompanyHeader(
          title: content.title,
          subtitle: content.date,
          company: company,
          logo: logo,
          base: base,
          bold: bold,
        ),
        build: (_) => _body(content, base, bold),
      ),
    );
    return doc.save();
  }

  List<pw.Widget> _body(
    CustomerStatementContent content,
    pw.Font base,
    pw.Font bold,
  ) {
    pw.TextStyle style({
      bool strong = false,
      double size = 9,
      PdfColor color = PdfStyles.textPrimary,
    }) =>
        pw.TextStyle(font: strong ? bold : base, fontSize: size, color: color);

    pw.Widget cell(String text, {bool right = false, bool strong = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: pw.Text(
            pdfSafeText(text),
            textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
            style: style(strong: strong),
          ),
        );

    pw.Widget block(StatementPdfBlock b) => pw.Padding(
      padding: const pw.EdgeInsets.fromLTRB(32, 0, 32, 18),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(pdfSafeText(b.title), style: style(strong: true, size: 11)),
          if ((b.device ?? '').isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text(
                pdfSafeText(b.device!),
                style: style(color: PdfStyles.textSecondary),
              ),
            ),
          pw.SizedBox(height: 6),
          if (b.rows.isNotEmpty)
            pw.Table(
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(
                  color: PdfStyles.dividerColor,
                  width: 0.5,
                ),
                bottom: pw.BorderSide(color: PdfStyles.borderColor, width: 0.5),
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(6),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfStyles.backgroundLighter,
                  ),
                  children: [
                    for (var i = 0; i < content.columns.length; i++)
                      cell(content.columns[i], right: i >= 1, strong: true),
                  ],
                ),
                for (final row in b.rows)
                  pw.TableRow(
                    children: [
                      for (var i = 0; i < row.length; i++)
                        cell(row[i], right: i >= 1),
                    ],
                  ),
              ],
            ),
          if (b.discount != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(pdfSafeText(b.discount!), style: style()),
              ),
            ),
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(pdfSafeText(b.totals), style: style(strong: true)),
            ),
          ),
        ],
      ),
    );

    return [
      pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(32, 24, 32, 16),
        child: pw.Text(pdfSafeText(content.sentence), style: style(size: 13)),
      ),
      for (final b in content.blocks) block(b),
      pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(32, 4, 32, 0),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              pdfSafeText('${content.totalLabel}  '),
              style: style(size: 11),
            ),
            pw.Text(
              pdfSafeText(content.totalValue),
              style: style(strong: true, size: 13),
            ),
          ],
        ),
      ),
    ];
  }
}
