import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:praticos/services/pdf/pdf_styles.dart';

/// Data class for DRE PDF generation.
class DrePdfData {
  final String monthLabel;
  final String companyName;
  final Map<String, double> incomeByCategory;
  final Map<String, double> expenseByCategory;
  final double totalIncome;
  final double totalExpense;

  DrePdfData({
    required this.monthLabel,
    required this.companyName,
    required this.incomeByCategory,
    required this.expenseByCategory,
    required this.totalIncome,
    required this.totalExpense,
  });

  double get result => totalIncome - totalExpense;
  double get margin => totalIncome > 0 ? (result / totalIncome) * 100 : 0;
}

/// Builds a DRE (simplified income statement) PDF.
class PdfFinancialReportBuilder {
  final pw.Font baseFont;
  final pw.Font boldFont;

  PdfFinancialReportBuilder({
    required this.baseFont,
    required this.boldFont,
  });

  pw.Document build(DrePdfData data) {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfStyles.pageFormat,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildHeader(data),
            pw.SizedBox(height: PdfStyles.spacingLarge),
            _buildSection(data.incomeByCategory, 'Receitas / Revenue',
                PdfStyles.successColor, data.totalIncome),
            pw.SizedBox(height: PdfStyles.spacingMedium),
            _buildSection(data.expenseByCategory, 'Despesas / Expenses',
                PdfStyles.dangerColor, data.totalExpense),
            pw.SizedBox(height: PdfStyles.spacingLarge),
            _buildTotals(data),
          ],
        ),
      ),
    );

    return doc;
  }

  pw.Widget _buildHeader(DrePdfData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfStyles.primaryDark,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'DRE - ${data.monthLabel}',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: PdfStyles.fontSizeTitle,
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                data.companyName,
                style: pw.TextStyle(
                  font: baseFont,
                  fontSize: PdfStyles.fontSizeNormal,
                  color: PdfColors.grey300,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSection(
    Map<String, double> categories,
    String title,
    PdfColor color,
    double total,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: pw.BoxDecoration(
            color: color.shade(0.9),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            title,
            style: pw.TextStyle(
              font: boldFont,
              fontSize: PdfStyles.fontSizeSmall,
              color: color,
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        ...categories.entries.map(
          (e) => pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom:
                    pw.BorderSide(color: PdfStyles.dividerColor, width: 0.5),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    e.key.isEmpty ? '(sem categoria)' : e.key,
                    style: pw.TextStyle(
                      font: baseFont,
                      fontSize: PdfStyles.fontSizeNormal,
                      color: PdfStyles.textPrimary,
                    ),
                  ),
                ),
                pw.Text(
                  _formatCurrency(e.value),
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: PdfStyles.fontSizeNormal,
                    color: PdfStyles.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          color: PdfStyles.backgroundLighter,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Total',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: PdfStyles.fontSizeNormal,
                  color: color,
                ),
              ),
              pw.Text(
                _formatCurrency(total),
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: PdfStyles.fontSizeNormal,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTotals(DrePdfData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: PdfStyles.cardDecoration(),
      child: pw.Column(
        children: [
          _buildTotalRow('Receitas / Revenue', data.totalIncome,
              PdfStyles.successColor),
          pw.SizedBox(height: 4),
          _buildTotalRow('Despesas / Expenses', -data.totalExpense,
              PdfStyles.dangerColor),
          pw.Divider(color: PdfStyles.borderColor),
          _buildTotalRow(
            'Resultado / Result',
            data.result,
            data.result >= 0
                ? PdfStyles.successColor
                : PdfStyles.dangerColor,
          ),
          pw.SizedBox(height: 4),
          _buildTotalRow(
            'Margem / Margin',
            data.margin,
            PdfStyles.textSecondary,
            suffix: '%',
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTotalRow(String label, double value, PdfColor color,
      {String suffix = ''}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: baseFont,
            fontSize: PdfStyles.fontSizeNormal,
            color: PdfStyles.textSecondary,
          ),
        ),
        pw.Text(
          suffix.isNotEmpty
              ? '${value.toStringAsFixed(1)}$suffix'
              : _formatCurrency(value),
          style: pw.TextStyle(
            font: boldFont,
            fontSize: PdfStyles.fontSizeLarge,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatCurrency(double value) {
    final abs = value.abs();
    final sign = value < 0 ? '-' : '';
    final parts = abs.toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return '${sign}R\$ $intPart,${parts[1]}';
  }
}
