import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/screens/widgets/share_link_sheet.dart';
import 'package:praticos/services/share_link_service.dart';

// "Avisar o cliente?" after a status change, shared by the legacy order
// screen (OrderForm) and the new one (OrderScreenV2).

/// Statuses that offer to tell the customer.
const statusesThatNotifyCustomer = {'approved', 'progress', 'done'};

/// Whether changing [order] to [status] should ask "Avisar o cliente?":
/// only for approved / in progress / done, saved orders whose customer has a
/// phone, without an active share link, and not dismissed for this order in
/// this session ([dismissedOrderIds]).
bool shouldOfferStatusShare(
  Order order,
  String status, {
  Set<String> dismissedOrderIds = const {},
}) {
  if (order.id == null) return false;
  if (!statusesThatNotifyCustomer.contains(status)) return false;
  final link = order.shareLink;
  if (link != null && !link.isExpired && link.token != null) return false;
  if (dismissedOrderIds.contains(order.id)) return false;
  final phone = order.customer?.phone;
  return phone != null && phone.isNotEmpty;
}

/// Asks "Avisar o cliente?" for [status]. Resolves true for "Enviar via
/// WhatsApp", false for "Agora não" (or dismissed).
Future<bool> askNotifyCustomer(
  BuildContext context, {
  required Order order,
  required String status,
}) async {
  String title(BuildContext ctx) {
    switch (status) {
      case 'approved':
        return ctx.l10n.statusUpdateApproved;
      case 'progress':
        return ctx.l10n.statusUpdateProgress;
      case 'done':
        return ctx.l10n.statusUpdateDone;
      default:
        return ctx.l10n.notifyCustomerQuestion;
    }
  }

  final send = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title(ctx)),
      content: Text(
        ctx.l10n.notifyCustomerDescription(
          order.customer?.name ?? ctx.l10n.customer,
        ),
      ),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(ctx.l10n.notNow),
        ),
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ctx.l10n.sendViaWhatsApp),
        ),
      ],
    ),
  );
  return send ?? false;
}

/// The order's customer link: the cached one, an active token from the API,
/// or a new one. Throws when a new link cannot be generated.
Future<String?> orderShareUrl(Order order) async {
  if (order.id == null) return null;
  final service = ShareLinkService.instance;

  // 1. Cached link on the order
  final existingLink = order.shareLink;
  if (existingLink != null &&
      !existingLink.isExpired &&
      existingLink.url != null) {
    return existingLink.url;
  }

  // 2. Active tokens from the API
  try {
    final tokens = await service.getShareTokens(order.id!);
    final active = tokens.where((t) => !t.isExpired).toList();
    if (active.isNotEmpty) {
      return 'https://praticos.web.app/q/${active.first.token}';
    }
  } catch (_) {
    // Generates a new link below.
  }

  // 3. New link
  final result = await service.generateShareLink(orderId: order.id!);
  return result.url;
}

/// Opens the native share sheet with the order's customer link (reusing an
/// active one, or generating a new one) and a message for [statusContext].
/// Falls back to [ShareLinkSheet] on error.
Future<void> shareOrderLinkNatively(
  BuildContext context,
  Order order, {
  String? statusContext,
}) async {
  if (order.id == null) return;
  final service = ShareLinkService.instance;

  final overlay = OverlayEntry(
    builder: (_) => const ColoredBox(
      color: Color(0x44000000),
      child: Center(child: CupertinoActivityIndicator(radius: 16)),
    ),
  );
  Overlay.of(context).insert(overlay);

  try {
    final url = await orderShareUrl(order);

    if (url == null || !context.mounted) return;

    final message = service.buildShareMessage(
      customerName: order.customer?.name ?? '',
      orderNumber: order.number ?? 0,
      companyName: Global.companyAggr?.name,
      locale: context.l10n.localeName,
      statusContext: statusContext,
    );

    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    await service.shareViaSheet(
      url: url,
      message: message,
      subject: '${context.l10n.order} #${order.number}',
      sharePositionOrigin: sharePositionOrigin,
    );
  } catch (_) {
    if (context.mounted) {
      ShareLinkSheet.show(context, order, statusContext: statusContext);
    }
  } finally {
    overlay.remove();
  }
}
