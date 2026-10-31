import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:praticos/global.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/nfse.dart';
import 'package:praticos/repositories/tenant/nfse_invoice_repository.dart';
import 'package:praticos/screens/menu_navigation/more/more_page.dart';
import 'package:praticos/screens/nfse/nfse_access.dart';
import 'package:praticos/screens/nfse/nfse_issue_sheet.dart';
import 'package:praticos/screens/payments/asaas_error_text.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/app_toast.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/pull_down_menu.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/services/asaas_api_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:share_plus/share_plus.dart';
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
      if (invoice.errorCode == null) return l10n.nfseHeadError;
      return invoice.auto ? l10n.nfseHeadAutoError : l10n.nfseHeadNotIssued;
  }
}

/// Why a nota did not go out: our reason for an automatic one that failed,
/// or the city's text. Null when there is nothing to say.
String? nfseReasonText(AppLocalizations l10n, NfseInvoice invoice) {
  switch (invoice.errorCode) {
    case null:
      return invoice.statusDescription;
    case 'ASAAS_REJECTED':
      return invoice.statusDescription ?? l10n.nfseErrorAsaasValidation;
    case 'NFSE_SETUP_REJECTED':
      return invoice.statusDescription ?? l10n.nfseErrorSetupRejected;
    case 'TAX_ID_REQUIRED':
    case 'INVALID_TAX_ID':
      return l10n.nfseAutoErrorTaxId;
    default:
      return asaasErrorText(
        l10n,
        AsaasApiException(invoice.errorCode, ''),
        nota: true,
      );
  }
}

/// Shares the nota's PDF as a file. If it cannot be downloaded, shares the
/// link, so the customer still gets the nota.
Future<void> shareNfsePdf(
  BuildContext context,
  NfseInvoice invoice, {
  http.Client? client,
}) async {
  final url = invoice.pdfUrl;
  if (url == null) return;
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  XFile? file;
  try {
    final get = client?.get ?? http.get;
    final response = await get(Uri.parse(url));
    final isPdf = (response.headers['content-type'] ?? '').contains('pdf');
    if (response.statusCode == 200 && isPdf) {
      final directory = await getTemporaryDirectory();
      final name = 'nota-${invoice.number ?? invoice.id}.pdf';
      final saved = File('${directory.path}/$name');
      await saved.writeAsBytes(response.bodyBytes);
      file = XFile(saved.path, mimeType: 'application/pdf');
    }
  } catch (_) {
    file = null;
  }
  await SharePlus.instance.share(
    file == null
        ? ShareParams(text: url, sharePositionOrigin: origin)
        : ShareParams(files: [file], sharePositionOrigin: origin),
  );
}

/// A nota: status, value, orders, text, the PDF/XML once the city issued
/// it, the city's reason when it refused, and "Cancelar nota" in the "…".
/// The blue button shares the PDF, or corrects a nota that did not go out.
///
/// Watches the nota live (the webhook moves it). Pushed over the tab bar.
class NfseInvoiceScreen extends StatefulWidget {
  const NfseInvoiceScreen({
    super.key,
    required this.invoice,
    this.invoiceStream,
    this.service,
    this.openUrl,
    this.sharePdf,
    this.previousPageTitle,
  });

  final NfseInvoice invoice;

  /// Test seam; defaults to [NfseInvoiceRepository.watch].
  final Stream<NfseInvoice?>? invoiceStream;

  /// Test seam; defaults to [AsaasApiService.instance].
  final AsaasApiService? service;

  /// Test seam; defaults to [launchUrl] (outside the app).
  final Future<void> Function(String url)? openUrl;

  /// Test seam; defaults to [shareNfsePdf].
  final Future<void> Function(BuildContext context, NfseInvoice invoice)?
  sharePdf;

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

  Future<void> _sharePdf() async {
    if (_busy) return;
    setState(() => _busy = true);
    final share = widget.sharePdf ?? shareNfsePdf;
    try {
      await share(context, _invoice);
    } catch (_) {
      if (mounted) {
        showAppToast(
          context,
          context.l10n.asaasErrorGeneric,
          icon: CupertinoIcons.exclamationmark_circle,
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Emits again: the sheet asks for what is missing.
  Future<void> _reissue() async {
    final invoice = await NfseIssueSheet.show(
      context,
      orderIds: _invoice.orderIds,
      customerId: _invoice.customerId,
      service: widget.service,
    );
    if (invoice != null && mounted) {
      showAppToast(
        context,
        context.l10n.nfseSent,
        icon: CupertinoIcons.checkmark_circle,
      );
      Navigator.of(context).pop();
    }
  }

  Widget? _floatingButton() {
    final l10n = context.l10n;
    final invoice = _invoice;
    if (invoice.status == NfseStatus.authorized && invoice.pdfUrl != null) {
      return PrimaryButton(
        key: const Key('nfseSharePdf'),
        label: l10n.nfseSharePdf,
        floating: true,
        onPressed: _busy ? null : _sharePdf,
      );
    }
    if (invoice.status == NfseStatus.error &&
        !invoice.conflict &&
        invoice.orderIds.isNotEmpty) {
      return PrimaryButton(
        key: const Key('nfseReissue'),
        label: l10n.nfseFixAndIssue,
        floating: true,
        onPressed: _reissue,
      );
    }
    return null;
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
    final reason = refused ? nfseReasonText(l10n, invoice) : null;

    return MorePage(
      title: l10n.nfseRowTitle,
      previousPageTitle: widget.previousPageTitle,
      subtitle: nfseHeadline(l10n, invoice),
      floatingButton: _floatingButton(),
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
              // "Situação": the page title already says "Nota fiscal".
              title: l10n.orderStatusLabel,
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
        if (reason != null) ...[
          SectionLabel(
            invoice.errorCode != null
                ? l10n.nfseAutoReasonLabel
                : l10n.nfseReasonLabel,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageMargin,
            ),
            child: Text(
              reason,
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
