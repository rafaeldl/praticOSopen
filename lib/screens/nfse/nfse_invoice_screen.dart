import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/nfse.dart';
import 'package:praticos/repositories/tenant/nfse_invoice_repository.dart';
import 'package:praticos/screens/menu_navigation/more/more_page.dart';
import 'package:praticos/screens/nfse/nfse_access.dart';
import 'package:praticos/screens/payments/asaas_error_text.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/app_toast.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/pull_down_menu.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/services/asaas_api_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:url_launcher/url_launcher.dart';

/// One sentence on top of the nota screen ("A nota foi emitida.").
String nfseHeadline(AppLocalizations l10n, NfseInvoice invoice) {
  switch (invoice.status) {
    case NfseStatus.scheduled:
      final day = invoice.effectiveDay;
      final now = DateTime.now();
      if (day != null && day.isAfter(DateTime(now.year, now.month, now.day))) {
        return l10n.nfseHeadScheduled(FormatService().formatDate(day));
      }
      return l10n.nfseHeadWaiting;
    case NfseStatus.creating:
    case NfseStatus.synchronized:
      return l10n.nfseHeadWaiting;
    case NfseStatus.authorized:
      return l10n.nfseHeadIssued;
    case NfseStatus.processingCancellation:
      return l10n.nfseHeadCanceling;
    case NfseStatus.cancellationDenied:
      return l10n.nfseHeadCancelDenied;
    case NfseStatus.canceled:
      return l10n.nfseHeadCanceled;
    case NfseStatus.error:
      return l10n.nfseHeadError;
  }
}

/// A nota: status, value, orders, text, the PDF/XML once the city issued
/// it, the city's reason when it refused, and "Cancelar nota" in the "…".
///
/// Watches the nota live (the webhook moves it). Pushed over the tab bar.
class NfseInvoiceScreen extends StatefulWidget {
  const NfseInvoiceScreen({
    super.key,
    required this.invoice,
    this.invoiceStream,
    this.service,
    this.openUrl,
    this.previousPageTitle,
  });

  final NfseInvoice invoice;

  /// Test seam; defaults to [NfseInvoiceRepository.watch].
  final Stream<NfseInvoice?>? invoiceStream;

  /// Test seam; defaults to [AsaasApiService.instance].
  final AsaasApiService? service;

  /// Test seam; defaults to [launchUrl] (outside the app).
  final Future<void> Function(String url)? openUrl;

  final String? previousPageTitle;

  static Future<void> open(
    BuildContext context,
    NfseInvoice invoice, {
    String? previousPageTitle,
  }) => Navigator.of(context, rootNavigator: true).push<void>(
    CupertinoPageRoute<void>(
      settings: const RouteSettings(name: '/nfse_invoice'),
      builder: (_) => NfseInvoiceScreen(
        invoice: invoice,
        previousPageTitle: previousPageTitle,
      ),
    ),
  );

  @override
  State<NfseInvoiceScreen> createState() => _NfseInvoiceScreenState();
}

class _NfseInvoiceScreenState extends State<NfseInvoiceScreen> {
  final _format = FormatService();
  late NfseInvoice _invoice = widget.invoice;
  StreamSubscription<NfseInvoice?>? _subscription;
  bool _busy = false;

  AsaasApiService get _service => widget.service ?? AsaasApiService.instance;

  @override
  void initState() {
    super.initState();
    final companyId = Global.companyAggr?.id;
    final stream =
        widget.invoiceStream ??
        (companyId == null
            ? null
            : NfseInvoiceRepository().watch(companyId, widget.invoice.id));
    _subscription = stream?.listen((invoice) {
      if (invoice != null && mounted) setState(() => _invoice = invoice);
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _open(String url) async {
    final custom = widget.openUrl;
    if (custom != null) return custom(url);
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _showMenu() async {
    final l10n = context.l10n;
    final choice = await showPullDownMenu(
      context,
      groups: [
        PullDownGroup([
          PullDownItem(
            value: 'cancel',
            label: l10n.nfseCancelAction,
            icon: CupertinoIcons.xmark_circle,
            destructive: true,
          ),
        ]),
      ],
    );
    if (choice == 'cancel' && mounted) await _confirmCancel();
  }

  Future<void> _confirmCancel() async {
    final l10n = context.l10n;
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(l10n.nfseCancelQuestion(_format.formatBrl(_invoice.value))),
        content: Text(l10n.nfseCancelMessage),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.nfseKeep),
          ),
          CupertinoDialogAction(
            key: const Key('nfseCancelConfirm'),
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.nfseCancelAction),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await _cancel();
  }

  Future<void> _cancel({bool onlyOnAsaas = false}) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final updated = await _service.cancelInvoice(
        _invoice.id,
        onlyOnAsaas: onlyOnAsaas,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (updated.id.isNotEmpty) _invoice = updated;
      });
      showAppToast(
        context,
        updated.status == NfseStatus.canceled
            ? l10n.nfseCanceledToast
            : l10n.nfseCancelRequested,
        icon: CupertinoIcons.checkmark_circle,
      );
    } on AsaasApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (e.code == 'CANCEL_NOT_SUPPORTED' && !onlyOnAsaas) {
        await _askCanceledAtCity();
        return;
      }
      showAppToast(
        context,
        asaasErrorText(l10n, e, nota: true),
        icon: CupertinoIcons.exclamationmark_circle,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppToast(
        context,
        l10n.asaasErrorGeneric,
        icon: CupertinoIcons.exclamationmark_circle,
      );
    }
  }

  /// The city does not cancel through the integration: the user cancels on
  /// the city's website and then marks it here (cancels only in Asaas).
  Future<void> _askCanceledAtCity() async {
    final l10n = context.l10n;
    final done = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(l10n.nfseCancelAtCityTitle),
        content: Text(l10n.nfseCancelAtCityMessage),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.nfseKeep),
          ),
          CupertinoDialogAction(
            key: const Key('nfseCanceledAtCity'),
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.nfseCanceledAtCity),
          ),
        ],
      ),
    );
    if (done == true && mounted) await _cancel(onlyOnAsaas: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final invoice = _invoice;
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final text = AppColors.text.resolveFrom(context);
    final authorized = invoice.status == NfseStatus.authorized;
    final refused =
        invoice.status == NfseStatus.error ||
        invoice.status == NfseStatus.cancellationDenied;

    return MorePage(
      title: l10n.nfseRowTitle,
      previousPageTitle: widget.previousPageTitle,
      subtitle: nfseHeadline(l10n, invoice),
      trailing: _busy
          ? const CupertinoActivityIndicator()
          : invoice.canCancel
          ? GlassBarButton(
              key: const Key('nfseMenuButton'),
              label: l10n.nfseMenu,
              icon: CupertinoIcons.ellipsis,
              onPressed: _showMenu,
            )
          : null,
      children: [
        MoreRows(
          rows: [
            AppListRow(
              key: const Key('nfseInvoiceStatus'),
              title: l10n.nfseRowTitle,
              subtitleWidget: NfseStatusLine(invoice: invoice),
            ),
            AppListRow(
              title: l10n.nfseValueLabel,
              trailing: _format.formatBrl(invoice.value),
            ),
            if (invoice.number != null)
              AppListRow(title: l10n.nfseNumberLabel, trailing: invoice.number),
            if (invoice.effectiveDay != null)
              AppListRow(
                title: l10n.nfseDateLabel,
                trailing: _format.formatDate(invoice.effectiveDay!),
              ),
            if (invoice.orderNumbers.isNotEmpty)
              AppListRow(
                title: l10n.nfseOrdersLabel,
                trailing: invoice.orderNumbers,
              ),
          ],
        ),
        if (invoice.conflict)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageMargin,
              AppSpacing.md,
              AppSpacing.pageMargin,
              0,
            ),
            child: Text(
              l10n.nfseConflictNotice,
              key: const Key('nfseInvoiceConflict'),
              style: AppTypography.body.copyWith(color: text),
            ),
          ),
        if (refused && invoice.statusDescription != null) ...[
          SectionLabel(l10n.nfseReasonLabel),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageMargin,
            ),
            child: Text(
              invoice.statusDescription!,
              key: const Key('nfseInvoiceReason'),
              style: AppTypography.body.copyWith(color: text),
            ),
          ),
        ],
        if (authorized && (invoice.pdfUrl != null || invoice.xmlUrl != null))
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageMargin,
              AppSpacing.md,
              AppSpacing.pageMargin,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (invoice.pdfUrl != null)
                  TextLink(
                    key: const Key('nfseOpenPdf'),
                    label: l10n.nfseOpenPdf,
                    onPressed: () => _open(invoice.pdfUrl!),
                  ),
                if (invoice.xmlUrl != null)
                  TextLink(
                    key: const Key('nfseOpenXml'),
                    label: l10n.nfseOpenXml,
                    onPressed: () => _open(invoice.xmlUrl!),
                  ),
              ],
            ),
          ),
        if ((invoice.serviceDescription ?? '').isNotEmpty) ...[
          SectionLabel(l10n.nfseDescriptionLabel),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageMargin,
            ),
            child: Text(
              invoice.serviceDescription!,
              style: AppTypography.callout.copyWith(color: secondary),
            ),
          ),
        ],
      ],
    );
  }
}
