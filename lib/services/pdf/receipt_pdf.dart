import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/payment_transaction.dart';
import 'package:praticos/models/receipt.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/pdf/pdf_image_loader.dart';
import 'package:praticos/services/pdf/pdf_styles.dart';
import 'package:praticos/utils/order_payment_math.dart';
import 'package:printing/printing.dart';

/// One order on the recibo: what was paid on it now and what is still open.
class ReceiptPdfLine {
  const ReceiptPdfLine({
    required this.orderNumber,
    required this.paid,
    required this.open,
    this.description,
  });

  final int? orderNumber;

  /// Vehicle/device of the order, or its first service (may be null).
  final String? description;
  final double paid;
  final double open;
}

/// The data of a recibo, built from a [Receipt] (several orders) or from
/// one payment of one order ([ReceiptPdfData.fromPayment]).
class ReceiptPdfData {
  const ReceiptPdfData({
    required this.number,
    required this.customerName,
    required this.amount,
    required this.paidAt,
    required this.lines,
    this.recordedBy,
  });

  /// [Receipt] with the current [orders] (by id), for "Ainda falta".
  factory ReceiptPdfData.fromReceipt(
    Receipt receipt,
    Map<String, Order> orders, {
    String? customerName,
  }) {
    final lines = <ReceiptPdfLine>[];
    for (final a in receipt.allocations ?? const <ReceiptAllocation>[]) {
      final order = orders[a.orderId];
      lines.add(
        ReceiptPdfLine(
          orderNumber: a.orderNumber ?? order?.number,
          description: order == null ? null : orderShortDescription(order),
          paid: a.amount ?? 0,
          open: order == null ? 0 : OrderPaymentMath.remainingBalance(order),
        ),
      );
    }
    return ReceiptPdfData(
      number: receiptShortNumber(receipt.id),
      customerName: receipt.customer?.name ?? customerName ?? '',
      amount: receipt.amount ?? 0,
      paidAt: receipt.paidAt ?? receipt.createdAt ?? DateTime.now(),
      lines: lines,
      recordedBy: receipt.createdBy?.name,
    );
  }

  /// One payment ([tx]) of one [order], without a [Receipt] document.
  factory ReceiptPdfData.fromPayment(Order order, PaymentTransaction tx) {
    return ReceiptPdfData(
      number: receiptShortNumber(
        tx.id ?? '${tx.createdAt.millisecondsSinceEpoch}',
      ),
      customerName: order.customer?.name ?? '',
      amount: tx.amount,
      paidAt: tx.paidOn,
      lines: [
        ReceiptPdfLine(
          orderNumber: order.number,
          description: orderShortDescription(order),
          paid: tx.amount,
          open: OrderPaymentMath.remainingBalance(order),
        ),
      ],
      recordedBy: tx.createdBy?.name,
    );
  }

  final String number;
  final String customerName;
  final double amount;
  final DateTime paidAt;
  final List<ReceiptPdfLine> lines;
  final String? recordedBy;
}

/// Short code printed on the recibo ("Nº 3F9A1C"): the first 6 letters or
/// digits of [id], upper case.
String receiptShortNumber(String? id) {
  final clean = (id ?? '').replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  if (clean.isEmpty) return '-';
  return (clean.length > 6 ? clean.substring(0, 6) : clean).toUpperCase();
}

/// Vehicles/devices of [order] (names), or its first service.
String? orderShortDescription(Order order) {
  final devices = [
    for (final d in order.effectiveDevices)
      if ((d.name ?? '').trim().isNotEmpty) d.name!.trim(),
  ];
  if (devices.isNotEmpty) return devices.join(', ');
  final services = order.services ?? const <OrderService>[];
  for (final s in services) {
    final name = s.service?.name ?? s.description;
    if ((name ?? '').trim().isNotEmpty) return name!.trim();
  }
  return null;
}

/// Every text of the recibo, already localized and formatted. Pure: tests
/// check this instead of the PDF pixels.
class ReceiptPdfContent {
  const ReceiptPdfContent({
    required this.title,
    required this.number,
    required this.sentence,
    required this.columns,
    required this.rows,
    required this.totalLabel,
    required this.totalValue,
    required this.fileName,
    this.remaining,
    this.recordedBy,
  });

  final String title;

  /// "Nº 3F9A1C".
  final String number;

  /// "Recebemos de João a quantia de R$ 700,00 em 14/10/2026."
  final String sentence;

  /// OS, description, paid now, still open.
  final List<String> columns;
  final List<List<String>> rows;
  final String totalLabel;
  final String totalValue;

  /// "Falta receber R$ 200,00 dessas OS." (null when everything is paid).
  final String? remaining;

  /// "Registrado por Ana".
  final String? recordedBy;

  /// Without extension ("Recibo-3F9A1C").
  final String fileName;
}

ReceiptPdfContent buildReceiptPdfContent(
  ReceiptPdfData data,
  AppLocalizations l10n,
  FormatService format,
) {
  final openCents = data.lines.fold<int>(
    0,
    (sum, l) => sum + (l.open * 100).round(),
  );
  final recordedBy = data.recordedBy?.trim();
  return ReceiptPdfContent(
    title: l10n.pdfReceiptTitle,
    number: l10n.pdfReceiptNumber(data.number),
    sentence: l10n.pdfReceiptSentence(
      data.customerName.trim().isEmpty
          ? l10n.customerWithoutName
          : data.customerName.trim(),
      format.formatCurrency(data.amount),
      format.formatDate(data.paidAt),
    ),
    columns: [
      l10n.pdfReceiptOrderColumn,
      l10n.pdfReceiptDescriptionColumn,
      l10n.pdfReceiptPaidColumn,
      l10n.pdfReceiptOpenColumn,
    ],
    rows: [
      for (final line in data.lines)
        [
          line.orderNumber == null ? '-' : '${line.orderNumber}',
          line.description ?? '',
          format.formatCurrency(line.paid),
          line.open > 0 ? format.formatCurrency(line.open) : '-',
        ],
    ],
    totalLabel: l10n.pdfReceiptTotal,
    totalValue: format.formatCurrency(data.amount),
    remaining: openCents > 0
        ? l10n.pdfReceiptRemaining(format.formatCurrency(openCents / 100))
        : null,
    recordedBy: recordedBy == null || recordedBy.isEmpty
        ? null
        : l10n.pdfReceiptRecordedBy(recordedBy),
    fileName: l10n.pdfReceiptFileName(data.number),
  );
}

/// Keeps what the built-in Helvetica can draw (Latin-1, which has the
/// Portuguese and Spanish accents); drops the rest (emoji, other scripts).
String pdfSafeText(String text) =>
    String.fromCharCodes(text.runes.where((r) => r <= 0xFF));

/// Draws and shares the recibo.
class ReceiptPdfService {
  ReceiptPdfService({PdfImageLoader? imageLoader})
    : _imageLoader = imageLoader ?? PdfImageLoader();

  final PdfImageLoader _imageLoader;

  Future<Uint8List> generate(ReceiptPdfContent content, Company company) async {
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
        header: (_) => _header(content, company, logo, base, bold),
        build: (_) => _body(content, base, bold),
      ),
    );
    return doc.save();
  }

  /// Generates the PDF and opens the system share sheet (WhatsApp, e-mail…).
  Future<void> share(ReceiptPdfContent content, Company company) async {
    final bytes = await generate(content, company);
    await Printing.sharePdf(bytes: bytes, filename: '${content.fileName}.pdf');
  }

  pw.Widget _header(
    ReceiptPdfContent content,
    Company company,
    pw.MemoryImage? logo,
    pw.Font base,
    pw.Font bold,
  ) {
    const soft = PdfColor.fromInt(0xBBFFFFFF);
    pw.Widget info(String? text) => (text ?? '').isEmpty
        ? pw.SizedBox()
        : pw.Text(
            pdfSafeText(text!),
            style: pw.TextStyle(font: base, fontSize: 8, color: soft),
          );
    return pw.Container(
      width: double.infinity,
      decoration: const pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [PdfStyles.headerGradientStart, PdfStyles.headerGradientEnd],
          begin: pw.Alignment.centerLeft,
          end: pw.Alignment.centerRight,
        ),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (logo != null) ...[
            pw.Container(
              width: 40,
              height: 40,
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              padding: const pw.EdgeInsets.all(4),
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(width: 12),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  pdfSafeText(company.name ?? ''),
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 10,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 2),
                info(company.address),
                info(company.phone),
                info(company.email),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                pdfSafeText(content.title.toUpperCase()),
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 22,
                  color: PdfColors.white,
                ),
              ),
              pw.Text(
                pdfSafeText(content.number),
                style: pw.TextStyle(font: base, fontSize: 9, color: soft),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _body(ReceiptPdfContent content, pw.Font base, pw.Font bold) {
    pw.TextStyle style({
      bool strong = false,
      double size = 9,
      PdfColor color = PdfStyles.textPrimary,
    }) =>
        pw.TextStyle(font: strong ? bold : base, fontSize: size, color: color);

    pw.Widget cell(String text, {bool right = false, bool strong = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: pw.Text(
            pdfSafeText(text),
            textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
            style: style(strong: strong),
          ),
        );

    return [
      pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(32, 24, 32, 16),
        child: pw.Text(pdfSafeText(content.sentence), style: style(size: 13)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 32),
        child: pw.Table(
          border: const pw.TableBorder(
            horizontalInside: pw.BorderSide(
              color: PdfStyles.dividerColor,
              width: 0.5,
            ),
            bottom: pw.BorderSide(color: PdfStyles.borderColor, width: 0.5),
          ),
          columnWidths: const {
            0: pw.FlexColumnWidth(1),
            1: pw.FlexColumnWidth(4),
            2: pw.FlexColumnWidth(2),
            3: pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                color: PdfStyles.backgroundLighter,
              ),
              children: [
                for (var i = 0; i < content.columns.length; i++)
                  cell(content.columns[i], right: i >= 2, strong: true),
              ],
            ),
            for (final row in content.rows)
              pw.TableRow(
                children: [
                  for (var i = 0; i < row.length; i++)
                    cell(row[i], right: i >= 2),
                ],
              ),
          ],
        ),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(32, 10, 32, 0),
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
      if (content.remaining != null)
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(32, 8, 32, 0),
          child: pw.Text(
            pdfSafeText(content.remaining!),
            style: style(size: 10, color: PdfStyles.textSecondary),
          ),
        ),
      pw.SizedBox(height: 32),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 32),
        child: pw.Text(
          pdfSafeText(
            [
              if (content.recordedBy != null) content.recordedBy!,
              content.number,
            ].join(' · '),
          ),
          style: style(size: 8, color: PdfStyles.textMuted),
        ),
      ),
    ];
  }
}
