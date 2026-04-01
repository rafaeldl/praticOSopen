import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'package:praticos/models/financial_payment.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/pdf/pdf_financial_report_builder.dart';

/// Service for exporting financial data as PDF or CSV.
class FinancialExportService {
  /// Generates DRE PDF bytes.
  Future<Uint8List> generateDrePdf(DrePdfData data) async {
    final (baseFont, boldFont) = await _loadFonts();
    final builder = PdfFinancialReportBuilder(
      baseFont: baseFont,
      boldFont: boldFont,
    );
    final doc = builder.build(data);
    return doc.save();
  }

  /// Generates a CSV string from a list of payments.
  String generateStatementCsv(List<FinancialPayment> payments) {
    final formatService = FormatService();
    final buffer = StringBuffer();

    // Header
    buffer.writeln(
        'Date,Description,Type,Category,Method,Account,Amount');

    for (final p in payments) {
      final date = p.paymentDate ?? p.createdAt ?? DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final desc = _escapeCsv(p.description ?? '');
      final type = p.type?.name ?? '';
      final category = _escapeCsv(p.category ?? '');
      final method = p.paymentMethod?.name ?? '';
      final account = _escapeCsv(p.account?.name ?? '');
      final amount = formatService.formatDecimal(p.amount ?? 0);

      buffer.writeln('$dateStr,$desc,$type,$category,$method,$account,$amount');
    }

    return buffer.toString();
  }

  /// Shares a CSV file via the system share sheet.
  Future<void> shareCsv(String csvContent, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(csvContent);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)]),
    );
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<(pw.Font, pw.Font)> _loadFonts() async {
    final baseFont = await PdfGoogleFonts.nunitoSansRegular();
    final boldFont = await PdfGoogleFonts.nunitoSansBold();
    return (baseFont, boldFont);
  }
}
