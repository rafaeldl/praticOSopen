import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';

/// Tells that a save or delete failed ("Não deu para salvar. Tente de
/// novo."). The screen stays as it was, so the person can try again.
Future<void> showFailureAlert(BuildContext context, String message) {
  final l10n = context.l10n;
  return showCupertinoDialog<void>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(message),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.ok),
        ),
      ],
    ),
  );
}
