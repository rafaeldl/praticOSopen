import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order_document.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';
import 'package:praticos/services/photo_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/widgets/photo_limit_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

// Shared actions for the photos and documents of an order, used by the
// legacy order screen (OrderMediaWidget, OrderForm) and the new one
// (OrderScreenV2).

/// MIME type of a picked file by its extension.
String orderDocumentContentType(String extension) {
  switch (extension.toLowerCase()) {
    case 'pdf':
      return 'application/pdf';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    default:
      return 'application/octet-stream';
  }
}

/// "Tirar foto" / "Galeria" / "Arquivos": photos go to the order photos
/// (counted in the plan quota), files go to the order documents after
/// choosing their type.
Future<void> showAddOrderMediaSheet(
  BuildContext context,
  OrderStore store, {
  String? title,
}) {
  void afterPhoto(bool success) {
    if (success || !context.mounted) return;
    final limitResult = store.photoLimitResult;
    if (limitResult != null && !limitResult.isAllowed) {
      showPhotoLimitDialog(context, limitResult);
    }
  }

  Widget label(IconData icon, String text) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Flexible(child: Text(text, textAlign: TextAlign.center)),
        ],
      );

  return showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: title == null ? null : Text(title),
      actions: [
        CupertinoActionSheetAction(
          child: label(CupertinoIcons.camera, context.l10n.takePhoto),
          onPressed: () async {
            Navigator.pop(ctx);
            afterPhoto(await store.addPhotoFromCamera());
          },
        ),
        CupertinoActionSheetAction(
          child: label(CupertinoIcons.photo, context.l10n.gallery),
          onPressed: () async {
            Navigator.pop(ctx);
            afterPhoto(await store.addPhotoFromGallery());
          },
        ),
        CupertinoActionSheetAction(
          child: label(CupertinoIcons.doc, context.l10n.fromFiles),
          onPressed: () async {
            Navigator.pop(ctx);
            final platformFile = await PhotoService().pickDocument();
            if (platformFile == null ||
                platformFile.path == null ||
                !context.mounted) {
              return;
            }
            await _selectDocumentType(
              context,
              store,
              File(platformFile.path!),
              orderDocumentContentType(platformFile.extension ?? ''),
              platformFile.name,
              fileSize: platformFile.size,
            );
          },
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        child: Text(context.l10n.cancel),
        onPressed: () => Navigator.pop(ctx),
      ),
    ),
  );
}

/// "Que documento é este?": picks the type (receipt, invoice, ...) and
/// uploads the file to the order documents.
Future<void> _selectDocumentType(
  BuildContext context,
  OrderStore store,
  File file,
  String contentType,
  String fileName, {
  int? fileSize,
}) async {
  final l10n = context.l10n;
  final types = {
    OrderDocumentType.receipt: l10n.receipt,
    OrderDocumentType.invoice: l10n.invoice,
    OrderDocumentType.contract: l10n.contract,
    OrderDocumentType.warranty: l10n.warranty,
    OrderDocumentType.other: l10n.other,
  };
  final type = await pickOne<OrderDocumentType>(
    context,
    title: l10n.orderDocumentTypeTitle,
    options: [
      for (final entry in types.entries)
        PickerItem<OrderDocumentType>(value: entry.key, title: entry.value),
    ],
  );
  if (type == null || !context.mounted) return;
  final success = await store.addDocument(
    file,
    type,
    contentType,
    fileName,
    fileSize: fileSize,
  );
  if (!context.mounted) return;
  showOrderMediaFeedback(
    context,
    success ? context.l10n.documentAdded : context.l10n.errorUploadingDocument,
    isError: !success,
  );
}

/// Short alert with a check (or an x) and [message].
void showOrderMediaFeedback(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  showCupertinoDialog<void>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isError
                ? CupertinoIcons.xmark_circle_fill
                : CupertinoIcons.checkmark_circle_fill,
            color: isError
                ? AppColors.danger.resolveFrom(ctx)
                : AppColors.success.resolveFrom(ctx),
            size: 24,
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(child: Text(message)),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          child: Text(context.l10n.ok),
          onPressed: () => Navigator.pop(ctx),
        ),
      ],
    ),
  );
}

/// "Excluir documento?" Resolves true when confirmed.
Future<bool> confirmDeleteOrderDocument(BuildContext context) async {
  final confirmed = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(context.l10n.deleteDocument),
      content: Text(context.l10n.confirmDeleteDocument),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          child: Text(context.l10n.cancel),
          onPressed: () => Navigator.pop(ctx, false),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          child: Text(context.l10n.delete),
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Opens a document: images in a full-screen viewer, other files in the
/// app that handles them. The download URL is refreshed from the storage
/// path first to avoid stale tokens.
Future<void> openOrderDocument(BuildContext context, OrderDocument doc) async {
  if (doc.url == null && doc.storagePath == null) return;

  var url = doc.url;
  if (doc.storagePath != null) {
    final freshUrl = await PhotoService().getFreshDownloadUrl(doc.storagePath!);
    if (freshUrl != null) {
      url = freshUrl;
      doc.url = freshUrl;
    }
  }

  if (url == null || !context.mounted) return;

  if (doc.isImage) {
    final imageUrl = url;
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) => OrderDocumentImageViewer(
          url: imageUrl,
          title: doc.fileName ?? context.l10n.documents,
        ),
      ),
    );
  } else {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

/// Full-screen image viewer for document images (black, like the iPhone's
/// photo viewer: over a photo the colors do not follow the theme).
class OrderDocumentImageViewer extends StatelessWidget {
  final String url;
  final String title;

  const OrderDocumentImageViewer({
    super.key,
    required this.url,
    required this.title,
  });

  static const _black = Color(0xFF000000);
  static const _white = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: _black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: _black.withValues(alpha: 0.8),
        border: null,
        leading: Semantics(
          button: true,
          label: context.l10n.back,
          excludeSemantics: true,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(
              AppSizes.minTouchTarget,
              AppSizes.minTouchTarget,
            ),
            child: const Icon(CupertinoIcons.back, color: _white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        middle: Text(
          title,
          style: AppTypography.callout.copyWith(
            color: _white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: SafeArea(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 3.0,
          child: Center(
            child: Image.network(
              url,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const CupertinoActivityIndicator(color: _white);
              },
              errorBuilder: (context, error, stackTrace) {
                return Semantics(
                  label: context.l10n.errorLoadingPhoto,
                  child: const Icon(
                    CupertinoIcons.exclamationmark_triangle,
                    color: _white,
                    size: 48,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
