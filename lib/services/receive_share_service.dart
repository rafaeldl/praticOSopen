import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_document.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';
import 'package:praticos/screens/order/order_route.dart';
import 'package:praticos/screens/share/which_order_sheet.dart';
import 'package:praticos/services/notification_tap_handler.dart';
import 'package:praticos/services/order_saved_elsewhere.dart';
import 'package:praticos/services/photo_service.dart';
import 'package:praticos/services/received_share.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Receives photos and PDFs shared from other apps and asks "Em qual OS?".
///
/// Android (intent filters) and iOS (Share Extension in `ios/ShareExtension`).
/// On iOS the extension copies the files to the App Group container and opens
/// the app; those copies are deleted once handled.
class ReceiveShareService {
  ReceiveShareService._();
  static final ReceiveShareService instance = ReceiveShareService._();

  StreamSubscription<List<SharedMediaFile>>? _sub;
  bool _busy = false;

  static bool get isSupported => receiveShareSupported(
      isWeb: kIsWeb, operatingSystem: kIsWeb ? '' : Platform.operatingSystem);

  Future<void> start() async {
    if (!isSupported || _sub != null) return;
    try {
      final initial = await ReceiveSharingIntent.instance.getInitialMedia();
      if (initial.isNotEmpty) _onShared(initial);
      _sub = ReceiveSharingIntent.instance
          .getMediaStream()
          .listen(_onShared, onError: (e) => debugPrint('ReceiveShare: $e'));
    } catch (e) {
      debugPrint('ReceiveShare: start failed: $e');
    }
  }

  /// Files from the plugin payload (Android intent or iOS Share Extension).
  /// Only images and files are kept; text and URLs are ignored.
  @visibleForTesting
  static List<ReceivedFile> filesFromShared(List<SharedMediaFile> media) =>
      media
          .where((m) =>
              m.type == SharedMediaType.image || m.type == SharedMediaType.file)
          .map((m) => ReceivedFile(
              path: normalizeSharedPath(m.path), mimeType: m.mimeType))
          .toList();

  Future<void> _onShared(List<SharedMediaFile> media) async {
    final files = filesFromShared(media);
    try {
      await ReceiveSharingIntent.instance.reset();
    } catch (_) {}
    final batch = ReceivedBatch(files);
    if (batch.isEmpty || _busy) return;
    _busy = true;
    try {
      // Cold start: wait for the session (company and navigator) to be ready.
      // Without a signed-in user the share is ignored.
      for (var i = 0; i < 40; i++) {
        if (Global.companyAggr?.id != null &&
            NotificationTapHandler.navigatorKey.currentContext != null) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      final companyId = Global.companyAggr?.id;
      final context = NotificationTapHandler.navigatorKey.currentContext;
      if (companyId == null || context == null) return;
      final choice = await WhichOrderSheet.show(context, batch: batch);
      if (choice == null || !context.mounted) return;
      String? orderId = choice.order?.id;
      if (choice.isNewOrder) {
        try {
          orderId = await _createOrder(context);
        } on TimeoutException {
          if (context.mounted) await _confirm(context, null, batch);
          return;
        }
      }
      if (orderId == null || !context.mounted) return;
      await _saveAndConfirm(context, companyId, orderId, batch);
    } finally {
      // Only now: the files were used (saved, or the order was not created).
      _busy = false;
      _deleteExtensionCopies(files);
    }
  }

  /// Deletes the iOS Share Extension copies (saved, canceled or ignored), so
  /// the App Group container does not grow with every share.
  void _deleteExtensionCopies(List<ReceivedFile> files) {
    for (final f in files) {
      if (!isShareExtensionCopy(f.path)) continue;
      try {
        File(f.path).deleteSync();
      } catch (_) {}
    }
  }

  /// "+" in "Em qual OS?": opens the Nova OS and returns its id once saved,
  /// or null when it is closed without saving.
  Future<String?> _createOrder(BuildContext context) {
    final created = Completer<String>();
    final closed = openNewOrder(context, onCreated: (id) {
      if (!created.isCompleted) created.complete(id);
    });
    return newOrderIdAfter(closed, created.future);
  }

  Future<void> _saveAndConfirm(BuildContext context, String companyId,
      String orderId, ReceivedBatch batch) async {
    Order? saved;
    try {
      saved = await saveToOrder(companyId, orderId, batch);
    } catch (e) {
      debugPrint('ReceiveShare: save failed: $e');
    }
    if (!context.mounted) return;
    await _confirm(context, saved, batch);
  }

  /// "Guardado na OS 193 · 1 foto" with "Abrir a OS", or the failure.
  Future<void> _confirm(
      BuildContext context, Order? order, ReceivedBatch batch) async {
    final l10n = context.l10n;
    final ok = order != null;
    final message = ok
        ? l10n.receivedSavedInOrder(
            '${order.number ?? ''}', summarizeBatch(l10n, batch))
        : l10n.receivedSaveFailed;
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          if (ok)
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                NotificationTapHandler.navigatorKey.currentState?.pushNamed(
                    '/order',
                    arguments: {'order': Order()..id = order.id});
              },
              child: Text(l10n.receivedOpenOrder),
            ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  /// Uploads [batch] to the order and saves it. Photos go to the order photos
  /// (counting in the plan quota like any photo); PDFs become [OrderDocument]s.
  /// Returns the saved order when at least one file was saved (an open OS
  /// screen is told, see [OrderSavedElsewhere]); null otherwise.
  Future<Order?> saveToOrder(
      String companyId, String orderId, ReceivedBatch batch) async {
    final repository = TenantOrderRepository();
    final photoService = PhotoService();
    final fresh = await repository.getFromServer(companyId, orderId);
    if (fresh == null) return null;

    var saved = 0;
    for (final f in batch.photos) {
      final photo = await photoService.uploadOrderPhoto(
        file: File(f.path),
        companyId: companyId,
        orderId: orderId,
      );
      if (photo != null) {
        (fresh.photos ??= []).add(photo);
        saved++;
      }
    }
    for (final f in batch.pdfs) {
      final file = File(f.path);
      final doc = await photoService.uploadOrderDocument(
        file: file,
        companyId: companyId,
        orderId: orderId,
        contentType: 'application/pdf',
        fileName: f.fileName,
        fileSize: await file.length(),
      );
      if (doc != null) {
        doc.type = OrderDocumentType.other;
        (fresh.documents ??= []).add(doc);
        saved++;
      }
    }
    if (saved == 0) return null;
    await repository.updateItem(companyId, fresh);
    OrderSavedElsewhere.notify(fresh);
    return fresh;
  }
}

/// Id of the Nova OS opened from "Em qual OS?": null when the sheet [closed]
/// without saving ("X"); after "✓" ([closed] resolves with `true`), waits for
/// the order to be [created] (it is written after the sheet closes). Throws
/// [TimeoutException] when it is not created within [timeout].
@visibleForTesting
Future<String?> newOrderIdAfter(
  Future<Object?> closed,
  Future<String> created, {
  Duration timeout = const Duration(minutes: 2),
}) async {
  final result = await closed;
  if (result != true) return null;
  return created.timeout(timeout);
}
