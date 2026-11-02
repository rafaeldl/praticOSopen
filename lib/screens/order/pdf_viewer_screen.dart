import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:printing/printing.dart';

/// Shows a generated PDF: "Ver PDF" is for looking at it, so sharing is a
/// second step, the share button on the top bar.
class PdfViewerScreen extends StatelessWidget {
  const PdfViewerScreen({
    super.key,
    required this.title,
    required this.bytes,
    required this.filename,
    this.onShare,
  });

  final String title;
  final Uint8List bytes;
  final String filename;

  /// Replaces the system share sheet (tests).
  final Future<void> Function()? onShare;

  Future<void> _share() async {
    await (onShare?.call() ??
        Printing.sharePdf(bytes: bytes, filename: filename));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(title),
        leading: CupertinoButton(
          key: const ValueKey('pdf_viewer_close'),
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
        trailing: CupertinoButton(
          key: const ValueKey('pdf_viewer_share'),
          padding: EdgeInsets.zero,
          onPressed: _share,
          child: Semantics(
            label: l10n.share,
            child: const Icon(CupertinoIcons.share),
          ),
        ),
      ),
      child: SafeArea(
        child: Material(
          type: MaterialType.transparency,
          child: PdfPreview(
            build: (_) async => bytes,
            useActions: false,
            canDebug: false,
            allowPrinting: false,
            allowSharing: false,
            canChangeOrientation: false,
            canChangePageFormat: false,
            pdfFileName: filename,
          ),
        ),
      ),
    );
  }
}
