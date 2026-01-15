import 'package:flutter/cupertino.dart';
import 'package:printing/printing.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/services/pdf/pdf_service.dart';

/// Screen that displays a PDF preview using the printing package's PdfPreview widget.
/// This screen is useful for previewing PDFs before sharing and for screenshot capture
/// in integration tests.
class PdfPreviewScreen extends StatelessWidget {
  final OsPdfData pdfData;

  const PdfPreviewScreen({
    super.key,
    required this.pdfData,
  });

  @override
  Widget build(BuildContext context) {
    final pdfService = PdfService();
    final filename =
        '${pdfData.config.serviceOrder}-${pdfData.order.number ?? "NOVA"}.pdf';

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(context.l10n.preview),
        previousPageTitle: context.l10n.back,
      ),
      child: SafeArea(
        child: PdfPreview(
          build: (format) => pdfService.generateOsPdf(pdfData),
          pdfFileName: filename,
          canChangeOrientation: false,
          canChangePageFormat: false,
          canDebug: false,
          allowPrinting: true,
          allowSharing: true,
          loadingWidget: const Center(
            child: CupertinoActivityIndicator(),
          ),
        ),
      ),
    );
  }
}
