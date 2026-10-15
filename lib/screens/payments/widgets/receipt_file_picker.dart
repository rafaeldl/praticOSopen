import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/services/customer_receipt_service.dart';
import 'package:praticos/services/photo_service.dart';

enum _ReceiptSource { camera, gallery, files }

/// Content type of a picked document, by extension.
String receiptContentTypeOf(String extension) {
  switch (extension) {
    case 'pdf':
      return 'application/pdf';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    default:
      return 'application/octet-stream';
  }
}

/// "Anexar comprovante": camera, gallery or files. Null when canceled.
Future<PickedReceiptFile?> pickReceiptFile(
  BuildContext context, {
  PhotoService? photoService,
}) async {
  final source = await showCupertinoModalPopup<_ReceiptSource>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, _ReceiptSource.camera),
          child: Text(context.l10n.takePhoto),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, _ReceiptSource.gallery),
          child: Text(context.l10n.gallery),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, _ReceiptSource.files),
          child: Text(context.l10n.fromFiles),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(ctx),
        child: Text(context.l10n.cancel),
      ),
    ),
  );
  if (source == null) return null;
  final service = photoService ?? PhotoService();
  String photoName() => 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg';
  switch (source) {
    case _ReceiptSource.camera:
      final file = await service.takePhoto();
      return file == null
          ? null
          : PickedReceiptFile(file, 'image/jpeg', photoName());
    case _ReceiptSource.gallery:
      final file = await service.pickImageFromGallery();
      return file == null
          ? null
          : PickedReceiptFile(file, 'image/jpeg', photoName());
    case _ReceiptSource.files:
      final result = await service.pickDocument();
      if (result == null || result.path == null) return null;
      return PickedReceiptFile(
        File(result.path!),
        receiptContentTypeOf(result.extension?.toLowerCase() ?? ''),
        result.name,
      );
  }
}
