import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/nfse.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/payment_settings.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/repositories/tenant/nfse_invoice_repository.dart';
import 'package:praticos/repositories/tenant/payment_settings_repository.dart';
import 'package:praticos/screens/integrations/asaas_connection_screen.dart'
    show safePaymentSettings;
import 'package:praticos/screens/nfse/nfse_setup_screen.dart';
import 'package:praticos/screens/widgets/status_dot.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Services total of an order as the nota counts it: services minus their
/// share of the discount (same rule as the server, `invoiceValueOfOrder`).
/// Items without a price count as zero.
double nfseValueOfOrder(Order order) {
  final services = (order.services ?? const []).fold<double>(
    0,
    (sum, s) => sum + (s.value ?? 0),
  );
  final products = (order.products ?? const []).fold<double>(0, (sum, p) {
    if (p.value == null) return sum;
    return sum + (p.total ?? (p.value! * (p.quantity ?? 1)));
  });
  final gross = services + products;
  final discount = (order.discount ?? 0).clamp(0, gross < 0 ? 0 : gross);
  final share = gross > 0 ? services / gross : 0;
  final value = services - discount * share;
  return value <= 0 ? 0 : (value * 100).round() / 100;
}

/// An order can have a nota: saved, not a quote nor canceled, with service
/// value.
bool orderCanHaveNfse(Order order) =>
    order.id != null &&
    order.status != 'quote' &&
    order.status != 'canceled' &&
    nfseValueOfOrder(order) > 0;

enum _NfseScope { order, customer, since }

/// Watches whether notas are on for the company and the user
/// (`settings/payments` `nfseEnabled` + Asaas connected, and the
/// `chargeOrder` permission) and, once [watchOrder], [watchCustomer] or
/// [watchMonth] is called, the notas of that order, customer or month.
///
/// With the flag off nothing is read beyond the settings, and [enabled]
/// stays false: nothing about notas shows. Firestore rules deny reading
/// the invoices to users without financial access; errors read as "none".
class NfseController extends ChangeNotifier {
  NfseController({
    bool? canIssue,
    Stream<PaymentSettings>? settingsStream,
    Stream<List<NfseInvoice>> Function(String id)? invoicesOf,
  }) : _invoicesOf = invoicesOf {
    // Company first: without one there is nothing to show, and the
    // permission lookup would build the auth stores for nothing.
    final companyId = Global.companyAggr?.id;
    if (settingsStream == null && companyId == null) return;
    final allowed =
        canIssue ??
        AuthorizationService.instance.hasPermission(PermissionType.chargeOrder);
    if (!allowed) return;
    final source =
        settingsStream ?? PaymentSettingsRepository().watch(companyId!);
    _settingsSubscription = safePaymentSettings(source).listen(_onSettings);
  }

  final Stream<List<NfseInvoice>> Function(String id)? _invoicesOf;
  StreamSubscription<PaymentSettings>? _settingsSubscription;
  StreamSubscription<List<NfseInvoice>>? _invoicesSubscription;
  PaymentSettings? _settings;
  List<NfseInvoice> _invoices = const [];
  String? _watching;
  _NfseScope _scope = _NfseScope.order;
  bool _loaded = false;
  bool _failed = false;
  bool _disposed = false;

  /// Notas are on for this company and user.
  bool get enabled => _settings?.nfseAvailable == true;

  /// The Asaas connection is sandbox.
  bool get sandbox => _settings?.isSandbox == true;

  /// The setup is complete: notas can be issued.
  bool get ready => enabled && _settings!.nfseReady;

  /// Notas of the watched order or customer (empty while disabled).
  List<NfseInvoice> get invoices => enabled ? _invoices : const [];

  /// The watched notas arrived (or failed to).
  bool get loaded => _loaded;

  /// The watched notas could not be read.
  bool get failed => _failed;

  /// The nota that represents the watched order (see [currentInvoiceOf]).
  NfseInvoice? get current => currentInvoiceOf(invoices);

  /// Order ids that already have an active nota.
  Set<String> get invoicedOrderIds => {
    for (final invoice in invoices)
      if (invoice.isActive()) ...invoice.orderIds,
  };

  /// Watches the notas of [orderId] (idempotent).
  void watchOrder(String? orderId) => _watch(orderId, _NfseScope.order);

  /// Watches the notas of [customerId] (idempotent).
  void watchCustomer(String? customerId) =>
      _watch(customerId, _NfseScope.customer);

  /// Watches the notas [month] needs (see [nfseQuerySince], idempotent).
  void watchMonth(DateTime month) =>
      _watch(nfseDayKey(nfseQuerySince(month)), _NfseScope.since);

  /// Reads again after [failed].
  void retry() {
    if (enabled) _subscribe();
  }

  void _watch(String? id, _NfseScope scope) {
    if (id == null || (_watching == id && _scope == scope)) return;
    _watching = id;
    _scope = scope;
    if (enabled) _subscribe();
  }

  void _onSettings(PaymentSettings settings) {
    _settings = settings;
    if (settings.nfseAvailable && _invoicesSubscription == null) {
      _subscribe();
    }
    _notify();
  }

  void _subscribe() {
    final id = _watching;
    if (id == null) return;
    _loaded = false;
    _failed = false;
    _invoicesSubscription?.cancel();
    _invoicesSubscription = _source(id).listen(
      (list) {
        _invoices = list;
        _loaded = true;
        _notify();
      },
      onError: (Object _) {
        _invoices = const [];
        _loaded = true;
        _failed = true;
        _notify();
      },
    );
  }

  Stream<List<NfseInvoice>> _source(String id) {
    final custom = _invoicesOf;
    if (custom != null) return custom(id);
    final companyId = Global.companyAggr?.id;
    if (companyId == null) return Stream.value(const []);
    final repository = NfseInvoiceRepository();
    switch (_scope) {
      case _NfseScope.order:
        return repository.watchOfOrder(companyId, id);
      case _NfseScope.customer:
        return repository.watchOfCustomer(companyId, id);
      case _NfseScope.since:
        return repository.watchSince(companyId, DateTime.parse(id));
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _settingsSubscription?.cancel();
    _invoicesSubscription?.cancel();
    super.dispose();
  }
}

/// Status text of a nota ("Aguardando prefeitura", "Emitida", ...).
String nfseStatusText(
  AppLocalizations l10n,
  NfseInvoice invoice, {
  DateTime? today,
}) {
  switch (invoice.status) {
    case NfseStatus.scheduled:
      final day = invoice.effectiveDay;
      final now = today ?? DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      if (day != null && day.isAfter(start)) {
        return l10n.nfseStatusScheduledFor(FormatService().formatDate(day));
      }
      return l10n.nfseStatusWaiting;
    case NfseStatus.creating:
    case NfseStatus.synchronized:
      return l10n.nfseStatusWaiting;
    case NfseStatus.authorized:
      return invoice.number == null
          ? l10n.nfseStatusIssued
          : l10n.nfseStatusIssuedNumber(invoice.number!);
    case NfseStatus.processingCancellation:
      return l10n.nfseStatusCanceling;
    case NfseStatus.cancellationDenied:
      return l10n.nfseStatusCancelDenied;
    case NfseStatus.canceled:
      return l10n.nfseStatusCanceled;
    case NfseStatus.error:
      return l10n.nfseStatusError;
  }
}

/// Dot color of a nota: waiting amber, issued green, error red, rest gray.
CupertinoDynamicColor nfseStatusColor(NfseStatus status) {
  switch (status) {
    case NfseStatus.creating:
    case NfseStatus.scheduled:
    case NfseStatus.synchronized:
      return AppColors.warning;
    case NfseStatus.authorized:
      return AppColors.success;
    case NfseStatus.error:
    case NfseStatus.cancellationDenied:
      return AppColors.danger;
    case NfseStatus.processingCancellation:
    case NfseStatus.canceled:
      return AppColors.textSecondary;
  }
}

/// Status dot + text in `textSecondary` (red and bold when it is a problem),
/// wrapping when the text is large.
class NfseStatusLine extends StatelessWidget {
  const NfseStatusLine({super.key, required this.invoice});

  final NfseInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final problem =
        invoice.status == NfseStatus.error ||
        invoice.status == NfseStatus.cancellationDenied;
    final color = nfseStatusColor(invoice.status).resolveFrom(context);
    return Row(
      children: [
        StatusDot(color: color),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            nfseStatusText(context.l10n, invoice),
            style: AppTypography.callout.copyWith(
              color: problem
                  ? AppColors.danger.resolveFrom(context)
                  : AppColors.textSecondary.resolveFrom(context),
              fontWeight: problem ? FontWeight.w600 : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// "Falta configurar a nota fiscal": owner/admin can open the setup,
/// the others are told to ask the owner.
Future<void> showNfseNotReady(
  BuildContext context, {
  required bool sandbox,
  bool? canSetUp,
}) async {
  final l10n = context.l10n;
  final admin = canSetUp ?? AuthorizationService.instance.canManageCompany;
  final setUp = await showCupertinoDialog<bool>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(l10n.nfseNotReadyTitle),
      content: Text(admin ? l10n.nfseNotReadyAdmin : l10n.nfseNotReadyOther),
      actions: [
        if (admin)
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(dialogContext, admin),
          child: Text(admin ? l10n.nfseSetupAction : l10n.ok),
        ),
      ],
    ),
  );
  if (setUp != true || !context.mounted) return;
  await Navigator.of(context, rootNavigator: true).push<void>(
    CupertinoPageRoute<void>(builder: (_) => NfseSetupScreen(sandbox: sandbox)),
  );
}
