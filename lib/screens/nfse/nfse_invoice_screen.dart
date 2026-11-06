import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:praticos/global.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/nfse.dart';
import 'package:praticos/repositories/tenant/nfse_invoice_repository.dart';
import 'package:praticos/screens/menu_navigation/more/more_page.dart';
import 'package:praticos/screens/nfse/direct/nfse_direct_issue_sheet.dart';
import 'package:praticos/screens/nfse/direct/nfse_direct_texts.dart';
import 'package:praticos/screens/nfse/direct/nfse_order_link.dart';
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
import 'package:praticos/services/nfse_direct_api_service.dart';
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
  if (invoice.isDirect) {
    final refusal = invoice.refusal;
    if (refusal != null) {
      return refusal.text(l10n.localeName.split('_').first) ??
          l10n.nfseDirectRefusedGeneric;
    }
    if (invoice.isAutoDirectFailure) {
      return nfseAutoErrorReason(l10n, invoice.errorCode!);
    }
    return invoice.statusDescription;
  }
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
  await shareNfsePdfUrl(
    context,
    url,
    'nota-${invoice.number ?? invoice.id}.pdf',
    client: client,
  );
}

/// Shares the PDF at [url] as a file named [name], or the link when it
/// cannot be downloaded.
Future<void> shareNfsePdfUrl(
  BuildContext context,
  String url,
  String name, {
  http.Client? client,
}) async {
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  XFile? file;
  try {
    final get = client?.get ?? http.get;
    final response = await get(Uri.parse(url));
    final isPdf = (response.headers['content-type'] ?? '').contains('pdf');
    if (response.statusCode == 200 && isPdf) {
      final directory = await getTemporaryDirectory();
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

/// Download URL of a file in Storage (the direct nota's PDF and XML).
Future<String> nfseStorageUrl(String path) =>
    FirebaseStorage.instance.ref(path).getDownloadURL();

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
    this.directService,
    this.storageUrl,
    this.now,
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

  /// Test seam; defaults to [NfseDirectApiService.instance] (direct notas).
  final NfseDirectApiService? directService;

  /// Test seam; defaults to [nfseStorageUrl].
  final Future<String> Function(String path)? storageUrl;

  /// Test seam; defaults to now.
  final DateTime? now;

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

  /// Result of "Enviar de novo" until the live nota brings it.
  NfseEmailDelivery? _resent;

  AsaasApiService get _service => widget.service ?? AsaasApiService.instance;

  NfseDirectApiService get _direct =>
      widget.directService ?? NfseDirectApiService.instance;

  /// A direct nota with no clear answer for a while: "Conferir agora".
  bool get _stale {
    final created = _invoice.createdAt;
    if (!_invoice.isDirect ||
        _invoice.status != NfseStatus.creating ||
        created == null) {
      return false;
    }
    return (widget.now ?? DateTime.now()).difference(created) >
        const Duration(minutes: 3);
  }

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
      if (invoice != null && mounted) {
        setState(() {
          _invoice = invoice;
          _resent = null;
        });
      }
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

  /// Download URL of the direct nota's PDF (made by the server if needed).
  Future<String?> _directPdfUrl() async {
    final path = await _direct.invoicePdfPath(_invoice.id);
    if (path == null) return null;
    return (widget.storageUrl ?? nfseStorageUrl)(path);
  }

  Future<void> _sharePdf() async {
    if (_busy) return;
    setState(() => _busy = true);
    final share = widget.sharePdf ?? shareNfsePdf;
    try {
      if (_invoice.isDirect && widget.sharePdf == null) {
        final url = await _directPdfUrl();
        if (url != null && mounted) {
          await shareNfsePdfUrl(
            context,
            url,
            'nota-${_invoice.number ?? _invoice.id}.pdf',
          );
        }
      } else {
        await share(context, _invoice);
      }
    } on NfseDirectApiException catch (e) {
      if (mounted) {
        showAppToast(
          context,
          nfseDirectErrorText(context.l10n, e),
          icon: CupertinoIcons.exclamationmark_circle,
        );
      }
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

  /// Opens the PDF or the XML of a direct nota.
  Future<void> _openDirect({required bool pdf}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final url = pdf
          ? await _directPdfUrl()
          : await (widget.storageUrl ?? nfseStorageUrl)(_invoice.xmlPath!);
      if (url != null) await _open(url);
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          nfseDirectErrorText(context.l10n, e),
          icon: CupertinoIcons.exclamationmark_circle,
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Emits again: the sheet asks for what is missing.
  Future<void> _reissue() async {
    final direct = _invoice.isDirect;
    final invoice = direct
        ? await NfseDirectIssueSheet.show(
            context,
            orderIds: _invoice.orderIds,
            service: widget.directService,
          )
        : await NfseIssueSheet.show(
            context,
            orderIds: _invoice.orderIds,
            customerId: _invoice.customerId,
            service: widget.service,
          );
    if (invoice != null && mounted) {
      final l10n = context.l10n;
      showAppToast(
        context,
        !direct
            ? l10n.nfseSent
            : invoice.status == NfseStatus.creating
            ? l10n.nfseDirectWaitingToast
            : l10n.nfseDirectIssuedToast,
        icon: CupertinoIcons.checkmark_circle,
      );
      Navigator.of(context).pop();
    }
  }

  /// "Tentar novamente" of an automatic nota that did not go out: issues it
  /// now, without the sheet; back to the order when it went.
  Future<void> _retryAuto() async {
    if (_busy) return;
    setState(() => _busy = true);
    final invoice = await retryAutoNfse(
      context,
      _invoice,
      service: widget.directService,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (invoice != null) await Navigator.of(context).maybePop();
  }

  /// Asks the government now about a direct nota with no clear answer.
  Future<void> _reconcile() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final updated = await _direct.reconcileInvoice(_invoice.id);
      if (mounted && updated.id.isNotEmpty) {
        setState(() => _invoice = updated);
      }
    } catch (e) {
      if (mounted) {
        showAppToast(
          context,
          nfseDirectErrorText(context.l10n, e),
          icon: CupertinoIcons.exclamationmark_circle,
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  /// A direct nota with a PDF can go to the customer's e-mail (issue #611).
  bool get _canEmail {
    final status = _invoice.status;
    return _invoice.isDirect &&
        _invoice.xmlPath != null &&
        (status == NfseStatus.authorized ||
            status == NfseStatus.cancellationDenied ||
            status == NfseStatus.canceled);
  }

  /// "Enviada para fulano@… em 05/11/2026", or why it did not go.
  String _emailText(AppLocalizations l10n, NfseEmailDelivery? delivery) {
    if (delivery == null) return l10n.nfseEmailNotSentYet;
    final to = delivery.to ?? '';
    final date = delivery.at == null
        ? ''
        : _format.formatDate(delivery.at!.toLocal());
    if (delivery.sent) {
      return delivery.canceled
          ? l10n.nfseEmailCancelSentTo(to, date)
          : l10n.nfseEmailSentTo(to, date);
    }
    if (delivery.failed) return l10n.nfseEmailFailedTo(to, date);
    return delivery.reason == 'turnedOff'
        ? l10n.nfseEmailSkippedTurnedOff
        : l10n.nfseEmailSkippedNoEmail;
  }

  /// "Enviar de novo": the nota (or the cancellation notice) goes now.
  Future<void> _resendEmail() async {
    if (_busy) return;
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final delivery = await _direct.resendInvoiceEmail(_invoice.id);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _resent = delivery;
      });
      final sent = delivery?.sent == true;
      showAppToast(
        context,
        sent
            ? l10n.nfseEmailSentToast(delivery!.to ?? '')
            : delivery?.reason == 'noEmail'
            ? l10n.nfseEmailNoAddressToast
            : l10n.nfseEmailFailedToast,
        icon: sent
            ? CupertinoIcons.checkmark_circle
            : CupertinoIcons.exclamationmark_circle,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppToast(
        context,
        nfseDirectErrorText(l10n, e),
        icon: CupertinoIcons.exclamationmark_circle,
      );
    }
  }

  Widget? _floatingButton() {
    final l10n = context.l10n;
    final invoice = _invoice;
    if (_stale) {
      return PrimaryButton(
        key: const Key('nfseReconcile'),
        label: l10n.nfseDirectCheckNow,
        floating: true,
        onPressed: _busy ? null : _reconcile,
      );
    }
    if (invoice.status == NfseStatus.authorized &&
        (invoice.pdfUrl != null ||
            (invoice.isDirect && invoice.xmlPath != null))) {
      return PrimaryButton(
        key: const Key('nfseSharePdf'),
        label: l10n.nfseSharePdf,
        floating: true,
        onPressed: _busy ? null : _sharePdf,
      );
    }
    if (invoice.canRetryAuto && !invoice.conflict) {
      return PrimaryButton(
        key: const Key('nfseRetryAuto'),
        label: l10n.tryAgain,
        floating: true,
        onPressed: _busy ? null : _retryAuto,
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
        if (canUnlinkNfseFromOrder(_invoice))
          PullDownGroup([
            PullDownItem(
              value: 'unlink',
              label: l10n.nfseUnlinkAction,
              icon: CupertinoIcons.link,
            ),
          ]),
        if (_invoice.canCancel)
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
    if (!mounted) return;
    if (choice == 'cancel') {
      if (_invoice.isDirect) {
        await _confirmDirectCancel();
      } else {
        await _confirmCancel();
      }
    }
    if (choice == 'unlink') {
      await unlinkNfseFromOrder(
        context,
        _invoice,
        service: widget.directService,
      );
    }
  }

  /// "Cancelar nota" of a direct nota: the reason is the confirmation.
  Future<void> _confirmDirectCancel() async {
    final l10n = context.l10n;
    final reason = await showCupertinoModalPopup<NfseCancelReason>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(l10n.nfseCancelQuestion(_format.formatBrl(_invoice.value))),
        message: Text(l10n.nfseDirectCancelMessage),
        actions: [
          for (final reason in NfseCancelReason.values)
            CupertinoActionSheetAction(
              key: Key('nfseCancelReason_${reason.name}'),
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(sheetContext, reason),
              child: Text(nfseCancelReasonText(l10n, reason)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(sheetContext),
          child: Text(l10n.nfseKeep),
        ),
      ),
    );
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated = await _direct.cancelInvoice(_invoice.id, reason);
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (updated.id.isNotEmpty) _invoice = updated;
      });
      showAppToast(
        context,
        l10n.nfseCanceledToast,
        icon: CupertinoIcons.checkmark_circle,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final portal = e is NfseDirectApiException && e.code == 'CANCEL_REFUSED';
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          content: Text(
            portal ? l10n.nfseDirectCancelPortal : nfseDirectErrorText(l10n, e),
            key: const Key('nfseDirectCancelError'),
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.ok),
            ),
          ],
        ),
      );
    }
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
          : invoice.canCancel || canUnlinkNfseFromOrder(invoice)
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
            if (invoice.emitter != null)
              AppListRow(
                key: const Key('nfseInvoiceEmitter'),
                title: l10n.nfseDirectEmitterLabel,
                subtitle: [
                  invoice.emitter!.legalName ?? '',
                  if (invoice.emitter!.taxId != null)
                    nfseTaxIdLine(l10n, invoice.emitter!.taxId!),
                ].where((t) => t.isNotEmpty).join('\n'),
              ),
            if (invoice.recipient != null)
              AppListRow(
                key: const Key('nfseInvoiceRecipient'),
                title: l10n.nfseDirectIssueTo,
                subtitle: [
                  invoice.recipient!.legalName ?? invoice.customerName ?? '',
                  if (invoice.recipient!.taxId != null)
                    nfseTaxIdLine(l10n, invoice.recipient!.taxId!),
                ].where((t) => t.isNotEmpty).join('\n'),
              ),
            if (invoice.cancelReason != null &&
                invoice.status == NfseStatus.canceled)
              AppListRow(
                title: l10n.nfseDirectCancelReasonRow,
                trailing: nfseCancelReasonText(l10n, invoice.cancelReason!),
              ),
            if (_canEmail)
              AppListRow(
                key: const Key('nfseInvoiceEmail'),
                title: l10n.nfseEmailRow,
                subtitle: _emailText(l10n, _resent ?? invoice.emailDelivery),
                trailing: (_resent ?? invoice.emailDelivery) == null
                    ? l10n.nfseEmailSend
                    : l10n.nfseEmailSendAgain,
                trailingStyle: AppTypography.body.copyWith(
                  color: AppColors.accentText.resolveFrom(context),
                ),
                onTap: _busy ? null : _resendEmail,
              ),
            if (invoice.accessKey != null)
              AppListRow(
                key: const Key('nfseInvoiceAccessKey'),
                title: l10n.nfseDirectAccessKeyLabel,
                subtitle: invoice.accessKey,
              ),
            if (canLinkNfseToOrder(invoice))
              AppListRow(
                key: const Key('nfseLinkOrder'),
                title: l10n.nfseLinkOrderRow,
                trailing: l10n.nfseLinkOrderAction,
                trailingStyle: AppTypography.body.copyWith(
                  color: AppColors.accentText.resolveFrom(context),
                ),
                onTap: () => linkNfseToOrder(
                  context,
                  invoice,
                  service: widget.directService,
                ),
              ),
          ],
        ),
        if (invoice.isExternal)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageMargin,
              AppSpacing.md,
              AppSpacing.pageMargin,
              0,
            ),
            child: Text(
              l10n.nfseDirectExternalTag,
              key: const Key('nfseInvoiceExternal'),
              style: AppTypography.callout.copyWith(color: secondary),
            ),
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
        if (authorized && invoice.isDirect && invoice.xmlPath != null)
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
                TextLink(
                  key: const Key('nfseOpenPdf'),
                  label: l10n.nfseOpenPdf,
                  onPressed: () => _openDirect(pdf: true),
                ),
                TextLink(
                  key: const Key('nfseOpenXml'),
                  label: l10n.nfseOpenXml,
                  onPressed: () => _openDirect(pdf: false),
                ),
              ],
            ),
          ),
        if (authorized &&
            !invoice.isDirect &&
            (invoice.pdfUrl != null || invoice.xmlUrl != null))
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

String nfseCancelReasonText(AppLocalizations l10n, NfseCancelReason reason) =>
    switch (reason) {
      NfseCancelReason.issueError => l10n.nfseDirectCancelReasonIssueError,
      NfseCancelReason.serviceNotProvided =>
        l10n.nfseDirectCancelReasonNotProvided,
    };
