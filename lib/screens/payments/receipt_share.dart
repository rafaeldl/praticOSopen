import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/company_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/pdf/receipt_pdf.dart';

/// Builds the recibo of [data] in the app's language, then opens the system
/// share sheet (WhatsApp, e-mail, print…). Shows a spinner while it works
/// and a short alert when it fails.
Future<void> shareReceiptPdf(BuildContext context, ReceiptPdfData data) async {
  final l10n = context.l10n;
  final format = FormatService()..setLocale(l10n.localeName);
  final content = buildReceiptPdfContent(data, l10n, format);
  final navigator = Navigator.of(context, rootNavigator: true);

  showCupertinoDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        const CupertinoAlertDialog(content: CupertinoActivityIndicator()),
  );
  try {
    final companyId = Global.companyAggr?.id;
    Company? company;
    if (companyId != null) {
      company = await CompanyStore().retrieveCompany(companyId) as Company?;
    }
    company ??= Company()..name = Global.companyAggr?.name;
    await ReceiptPdfService().share(content, company);
    navigator.pop();
  } catch (_) {
    navigator.pop();
    if (!context.mounted) return;
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(l10n.errorOccurred),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }
}
