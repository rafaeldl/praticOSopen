import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_document.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';
import 'package:praticos/screens/share/which_order_sheet.dart';
import 'package:praticos/services/notification_tap_handler.dart';
import 'package:praticos/services/photo_service.dart';
import 'package:praticos/services/received_share.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Receives photos and PDFs shared from other apps and asks "Em qual OS?".
///
/// Android only: on any other platform [start] does nothing, so iOS behavior
/// is unchanged (the iOS Share Extension is a separate step).
class ReceiveShareService {
  ReceiveShareService._();
  static final ReceiveShareService instance = ReceiveShareService._();

  StreamSubscription<List<SharedMediaFile>>? _sub;
  bool _busy = false;

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

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

  Future<void> _onShared(List<SharedMediaFile> media) async {
    final files = media
        .where((m) => m.type == SharedMediaType.image ||
            m.type == SharedMediaType.file)
        .map((m) => ReceivedFile(path: m.path, mimeType: m.mimeType))
        .toList();
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
      final order = await WhichOrderSheet.show(context, batch: batch);
      if (order?.id == null) return;
      if (!context.mounted) return;
      await _saveAndConfirm(context, companyId, order!, batch);
    } finally {
      _busy = false;
    }
  }

  Future<void> _saveAndConfirm(BuildContext context, String companyId,
      Order order, ReceivedBatch batch) async {
    final l10n = context.l10n;
    bool ok;
    try {
      ok = await saveToOrder(companyId, order.id!, batch);
    } catch (e) {
      debugPrint('ReceiveShare: save failed: $e');
      ok = false;
    }
    if (!context.mounted) return;
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
  /// Returns true when at least one file was saved.
  Future<bool> saveToOrder(
      String companyId, String orderId, ReceivedBatch batch) async {
    final repository = TenantOrderRepository();
    final photoService = PhotoService();
    final fresh = await repository.getFromServer(companyId, orderId);
    if (fresh == null) return false;

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
    if (saved == 0) return false;
    await repository.updateItem(companyId, fresh);
    return true;
  }
}
