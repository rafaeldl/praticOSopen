import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/company_store.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/pdf/customer_statement_pdf.dart';
import 'package:share_plus/share_plus.dart';

/// How the extrato goes: text only or text plus the PDF.
enum StatementChoice { withPdf, textOnly }

/// Asks whether the PDF goes with the message. Null when canceled.
Future<StatementChoice?> askStatementChoice(
  BuildContext context,
  String customerName,
) {
  final l10n = context.l10n;
  return showCupertinoModalPopup<StatementChoice>(
    context: context,
    builder: (sheet) => CupertinoActionSheet(
      title: Text(l10n.statementSendTitle(customerName)),
      message: Text(l10n.statementSendMessage),
      actions: [
        CupertinoActionSheetAction(
          key: const Key('statementWithPdf'),
          isDefaultAction: true,
          onPressed: () => Navigator.pop(sheet, StatementChoice.withPdf),
          child: Text(l10n.statementWithPdf),
        ),
        CupertinoActionSheetAction(
          key: const Key('statementTextOnly'),
          onPressed: () => Navigator.pop(sheet, StatementChoice.textOnly),
          child: Text(l10n.statementTextOnly),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(sheet),
        child: Text(l10n.cancel),
      ),
    ),
  );
}

/// "Mandar extrato": asks about the PDF, builds the message (and the PDF)
/// in the app's language and opens the system share sheet. Spinner while
/// the PDF is drawn; a short alert when it fails.
Future<void> sendCustomerStatement(
  BuildContext context,
  CustomerStatementData data,
) async {
  final l10n = context.l10n;
  final choice = await askStatementChoice(context, data.customerName);
  if (choice == null || !context.mounted) return;
  final format = FormatService()..setLocale(l10n.localeName);
  final text = buildStatementText(data, l10n, format);
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null || !box.hasSize
      ? null
      : box.localToGlobal(Offset.zero) & box.size;

  if (choice == StatementChoice.textOnly) {
    await SharePlus.instance.share(
      ShareParams(text: text, sharePositionOrigin: origin),
    );
    return;
  }

  final navigator = Navigator.of(context, rootNavigator: true);
  showCupertinoDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        const CupertinoAlertDialog(content: CupertinoActivityIndicator()),
  );
  XFile file;
  try {
    final companyId = Global.companyAggr?.id;
    Company? company;
    if (companyId != null) {
      company = await CompanyStore().retrieveCompany(companyId) as Company?;
    }
    company ??= Company()..name = Global.companyAggr?.name;
    final content = buildStatementPdfContent(data, l10n, format);
    final bytes = await CustomerStatementPdfService().generate(
      content,
      company,
    );
    final directory = await getTemporaryDirectory();
    final saved = File('${directory.path}/${content.fileName}.pdf');
    await saved.writeAsBytes(bytes);
    file = XFile(saved.path, mimeType: 'application/pdf');
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
    return;
  }
  await SharePlus.instance.share(
    ShareParams(text: text, files: [file], sharePositionOrigin: origin),
  );
}
