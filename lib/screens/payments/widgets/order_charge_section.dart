import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/models/payment_settings.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/repositories/tenant/order_charge_repository.dart';
import 'package:praticos/repositories/tenant/payment_settings_repository.dart';
import 'package:praticos/screens/integrations/asaas_connection_screen.dart'
    show safePaymentSettings;
import 'package:praticos/screens/payments/widgets/order_charge_card.dart';
import 'package:praticos/services/authorization_service.dart';

/// Asaas charge state of the Receber screen: payment settings and the
/// order's charges, watched while the screen is open.
///
/// Inactive (no charge shown, no "send link") when the user lacks
/// [PermissionType.chargeOrder] or the company is not in the Asaas pilot
/// (`asaasEnabled`). Charges are watched only once the pilot is on: Firestore
/// rules deny reading `charges` to users without the permission. Creating a
/// link needs `asaasConnected`; an open charge stays visible after
/// disconnecting.
///
/// Whoever can receive on the order ([AuthorizationService.canReceiveOnOrder],
/// e.g. a consultant on an order they created) also watches the charges,
/// read-only: marking money as received while a link is open would charge
/// the customer twice. When the charges can't be read (rules), [chargesUnknown]
/// is true and the screen must not offer "Marcar como recebido" as the main
/// action.
class OrderChargeController extends ChangeNotifier {
  OrderChargeController({
    required this.store,
    bool? canCharge,
    bool? canWatch,
    Stream<PaymentSettings>? settingsStream,
    Stream<List<OrderCharge>>? chargesStream,
  }) : _chargesSource = chargesStream,
       _canCharge =
           canCharge ??
           AuthorizationService.instance.hasPermission(
             PermissionType.chargeOrder,
           ) {
    final watching =
        _canCharge ||
        (canWatch ??
            AuthorizationService.instance.canReceiveOnOrder(store.order));
    if (!watching) return;
    final companyId = store.companyId;
    final source =
        settingsStream ??
        (companyId == null
            ? null
            : PaymentSettingsRepository().watch(companyId));
    if (source == null) return;
    _watching = true;
    _settingsSubscription = safePaymentSettings(source).listen(_onSettings);
  }

  final OrderStore store;

  /// [PermissionType.chargeOrder]: may create and replace links.
  final bool _canCharge;

  bool _watching = false;
  bool _chargesArrived = false;

  /// Still finding out whether a link is open: the payment settings or (in
  /// the pilot) the first answer about the charges have not arrived. The
  /// screen offers no blue "Marcar como recebido" meanwhile, or a quick tap
  /// could receive by hand over an open link.
  bool get pending {
    if (!_watching) return false;
    final settings = _settings;
    if (settings == null) return true;
    return settings.asaasEnabled && !_chargesArrived;
  }

  /// The charges could not be read (e.g. denied by the rules for this role):
  /// a link may be open without this screen knowing.
  bool get chargesUnknown => enabled && _chargesUnknown;
  bool _chargesUnknown = false;

  /// Test seam; defaults to [OrderChargeRepository.watch].
  final Stream<List<OrderCharge>>? _chargesSource;

  StreamSubscription<PaymentSettings>? _settingsSubscription;
  StreamSubscription<List<OrderCharge>>? _chargesSubscription;
  PaymentSettings? _settings;
  List<OrderCharge> _charges = const [];

  /// Charges of the last emission by id; null until the first emission.
  Map<String, OrderCharge>? _previous;

  /// Whether the payments were already reloaded for this screen.
  bool _reloadedOnOpen = false;
  bool _disposed = false;

  /// Company in the Asaas pilot and user allowed to charge.
  bool get enabled => _settings?.asaasEnabled == true;

  /// Asaas account connected and user allowed to charge: new links can be
  /// created.
  bool get connected => enabled && _canCharge && _settings!.asaasConnected;

  /// The open (pending/overdue) charge, if any.
  OrderCharge? get openCharge {
    if (!enabled) return null;
    for (final charge in _charges) {
      if (charge.isOpen) return charge;
    }
    return null;
  }

  /// The latest charge, when the server canceled it and no link replaced it.
  OrderCharge? get autoCanceledCharge {
    if (!enabled || openCharge != null) return null;
    final latest = OrderCharge.current(_charges);
    final canceled =
        latest?.status == ChargeStatus.canceled && latest?.autoCanceled == true;
    return canceled ? latest : null;
  }

  /// A charge with paid installments can't be replaced nor canceled.
  bool get blockedByInstallments =>
      enabled && _charges.any(chargeHasPaidInstallments);

  void _onSettings(PaymentSettings settings) {
    _settings = settings;
    if (settings.asaasEnabled && _chargesSubscription == null) {
      _chargesSubscription = (_chargesSource ?? _watchCharges()).listen(
        _onCharges,
        // E.g. permission denied by the rules: behave as "no charge".
        onError: (Object _) {
          _charges = const [];
          _chargesUnknown = true;
          _chargesArrived = true;
          _notify();
        },
      );
    }
    _notify();
  }

  Stream<List<OrderCharge>> _watchCharges() {
    final order = store.order;
    final companyId = order?.company?.id ?? Global.companyAggr?.id;
    final orderId = order?.id;
    if (companyId == null || orderId == null) {
      return Stream.value(const <OrderCharge>[]);
    }
    return OrderChargeRepository().watch(companyId, orderId);
  }

  void _onCharges(List<OrderCharge> charges) {
    final previous = _previous;
    final settled =
        previous != null &&
        charges.any((c) => chargeSettled(previous[c.id], c));
    _previous = {for (final c in charges) c.id ?? '': c};
    _charges = charges;
    _chargesUnknown = false;
    _chargesArrived = true;
    _notify();
    // The webhook booked or reverted payments on the order.
    if (settled && !_disposed) store.reloadPayments();
  }

  /// Reloads the payments once, when the charge part first shows up.
  ///
  /// [OrderStore.orderStream] doesn't refresh the payment fields, so a charge
  /// paid by the webhook while the order screen was open would leave a stale
  /// balance here (and a manual payment on top of it would double count).
  void reloadOnFirstShow() {
    if (_reloadedOnOpen) return;
    _reloadedOnOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) store.reloadPayments();
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _settingsSubscription?.cancel();
    _chargesSubscription?.cancel();
    super.dispose();
  }
}
