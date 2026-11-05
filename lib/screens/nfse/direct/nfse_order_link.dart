import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/nfse.dart';
import 'package:praticos/models/nfse_import.dart';
import 'package:praticos/screens/nfse/direct/nfse_direct_texts.dart';
import 'package:praticos/screens/widgets/app_toast.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/nfse_direct_api_service.dart';

/// A direct nota issued and without an order: "OS · Ligar a uma OS" (§4.7).
bool canLinkNfseToOrder(NfseInvoice invoice) =>
    invoice.provider == NfseProvider.direct &&
    invoice.orderIds.isEmpty &&
    (invoice.status == NfseStatus.authorized ||
        invoice.status == NfseStatus.cancellationDenied);

/// A nota made outside the PraticOS linked to an order: "Desligar da OS".
/// A nota the PraticOS issued for an order stays with it.
bool canUnlinkNfseFromOrder(NfseInvoice invoice) =>
    invoice.provider == NfseProvider.direct &&
    invoice.isExternal &&
    invoice.orderIds.isNotEmpty;

/// "Ligar a uma OS": the screen to choose (orders of the same customer
/// first, then those of similar value and date), then the link. Orders that
/// already have a nota show "Já tem nota" and are refused by the server.
/// Returns true when linked.
Future<bool> linkNfseToOrder(
  BuildContext context,
  NfseInvoice invoice, {
  NfseDirectApiService? service,
}) async {
  final api = service ?? NfseDirectApiService.instance;
  final l10n = context.l10n;
  final List<NfseLinkCandidate> candidates;
  try {
    candidates = await api.linkCandidates(invoice.id);
  } catch (e) {
    if (context.mounted) _toastError(context, e);
    return false;
  }
  if (!context.mounted) return false;
  final format = FormatService();
  PickerItem<String> item(NfseLinkCandidate o) => PickerItem(
    key: Key('nfseLinkCandidate-${o.id}'),
    value: o.id,
    title: l10n.nfseLinkOrderTitle('${o.number ?? ''}'),
    subtitle: [
      if (o.customerName != null) o.customerName!,
      format.formatBrl(o.value),
      if (o.date != null) format.formatDate(o.date!),
      if (o.hasNota) l10n.nfseLinkHasNota,
    ].join(' · '),
  );
  final same = candidates.where((o) => o.sameCustomer).toList();
  final others = candidates.where((o) => !o.sameCustomer).toList();
  final orderId = await Navigator.of(context).push<String>(
    CupertinoPageRoute<String>(
      settings: const RouteSettings(name: '/nfse_link_order'),
      builder: (_) => PickerScaffold<String>(
        title: l10n.nfseLinkPickerTitle,
        subtitle: format.formatBrl(invoice.value),
        itemCount: candidates.length,
        strongTitles: true,
        emptyTitle: l10n.nfseLinkPickerEmpty,
        sections: (query) {
          final q = query.toLowerCase();
          bool match(NfseLinkCandidate o) =>
              q.isEmpty ||
              '${o.number ?? ''}'.contains(q) ||
              (o.customerName ?? '').toLowerCase().contains(q);
          return [
            if (same.any(match))
              PickerSection(
                label: others.isEmpty ? null : l10n.nfseLinkPickerSame,
                items: [for (final o in same.where(match)) item(o)],
              ),
            if (others.any(match))
              PickerSection(
                label: same.isEmpty ? null : l10n.nfseLinkPickerOthers,
                items: [for (final o in others.where(match)) item(o)],
              ),
          ];
        },
      ),
    ),
  );
  if (orderId == null || !context.mounted) return false;
  try {
    await api.linkInvoiceToOrder(invoice.id, orderId);
  } catch (e) {
    if (context.mounted) _toastError(context, e);
    return false;
  }
  if (context.mounted) {
    showAppToast(
      context,
      l10n.nfseLinked,
      icon: CupertinoIcons.checkmark_circle,
    );
  }
  return true;
}

/// "Desligar da OS": confirms, then frees the order. Returns true when done.
Future<bool> unlinkNfseFromOrder(
  BuildContext context,
  NfseInvoice invoice, {
  NfseDirectApiService? service,
}) async {
  final l10n = context.l10n;
  final ok = await showCupertinoDialog<bool>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(l10n.nfseUnlinkQuestion(invoice.orderNumbers)),
      content: Text(l10n.nfseUnlinkMessage),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.nfseKeep),
        ),
        CupertinoDialogAction(
          key: const Key('nfseUnlinkConfirm'),
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.nfseUnlinkAction),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  try {
    await (service ?? NfseDirectApiService.instance).unlinkInvoice(invoice.id);
  } catch (e) {
    if (context.mounted) _toastError(context, e);
    return false;
  }
  if (context.mounted) {
    showAppToast(
      context,
      l10n.nfseUnlinked,
      icon: CupertinoIcons.checkmark_circle,
    );
  }
  return true;
}

void _toastError(BuildContext context, Object error) => showAppToast(
  context,
  nfseDirectErrorText(context.l10n, error),
  icon: CupertinoIcons.exclamationmark_circle,
);
