import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/models/payment_settings.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/repositories/tenant/order_charge_repository.dart';
import 'package:praticos/repositories/tenant/payment_settings_repository.dart';
import 'package:praticos/screens/integrations/asaas_connection_screen.dart'
    show safePaymentSettings;
import 'package:praticos/screens/payments/create_charge_screen.dart';
import 'package:praticos/screens/widgets/share_link_sheet.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/utils/order_payment_math.dart';

/// What "Mandar cobrança" does for one order.
enum SendChargeAction {
  /// No Asaas (or not allowed to charge): share the order link, as before.
  shareOrderLink,

  /// Asaas with an open charge: share the link, the charge is already there.
  shareExistingCharge,

  /// Asaas without an open charge: create the charge, then share the link.
  createChargeThenShare,
}

/// Pure decision behind [SendChargeFlow.send].
///
/// Asaas is used only when the user may charge ([PermissionType.chargeOrder]),
/// the company is in the pilot and connected, and the order still accepts a
/// charge (not a quote, not canceled, something left to pay).
SendChargeAction decideSendChargeAction({
  required bool canCharge,
  required PaymentSettings settings,
  required Order order,
  required OrderCharge? openCharge,
}) {
  final asaasReady = canCharge &&
      settings.asaasEnabled &&
      settings.asaasConnected &&
      order.id != null &&
      order.status != 'quote' &&
      order.status != 'canceled' &&
      OrderPaymentMath.remainingBalance(order) > OrderPaymentMath.centTolerance;
  if (!asaasReady) return SendChargeAction.shareOrderLink;
  if (openCharge != null && openCharge.isOpen) {
    return SendChargeAction.shareExistingCharge;
  }
  return SendChargeAction.createChargeThenShare;
}

/// "Mandar cobrança" from the Financeiro tab.
///
/// With Asaas connected the charge is generated first (reusing
/// [CreateChargeScreen], which already asks for the missing CPF/CNPJ and
/// calls the existing createCharge API) and then the order link is shared
/// through [ShareLinkSheet] (WhatsApp/share sheet); the customer pays by Pix,
/// boleto or card on that link. An open charge is reused, never duplicated.
/// Without Asaas, or when anything about Asaas cannot be read, it keeps the
/// old behavior: share the order link.
///
/// Every dependency is injectable so the paths can be tested without
/// Firebase.
class SendChargeFlow {
  SendChargeFlow({
    this.canCharge,
    this.settingsLoader,
    this.openChargeLoader,
    this.createCharge,
    this.share,
    this.timeout = const Duration(seconds: 8),
  });

  /// Defaults to the [PermissionType.chargeOrder] check.
  final bool? canCharge;

  /// Defaults to the company's `settings/payments` document.
  final Future<PaymentSettings> Function()? settingsLoader;

  /// Defaults to the order's charges in Firestore (current one, if open).
  final Future<OrderCharge?> Function(Order order)? openChargeLoader;

  /// Opens the create-charge flow; returns the created charge or null when
  /// the user gave up. Defaults to pushing [CreateChargeScreen].
  final Future<OrderCharge?> Function(
    BuildContext context,
    Order order,
    double remainingBalance,
  )? createCharge;

  /// Shares the order link. Defaults to [ShareLinkSheet.show].
  final Future<void> Function(BuildContext context, Order order)? share;

  /// Max wait for each Firestore read before falling back to the share link.
  final Duration timeout;

  /// Runs the flow and returns what was done. A charge the user gave up
  /// creating shares nothing.
  Future<SendChargeAction> send(BuildContext context, Order order) async {
    final allowed = canCharge ??
        AuthorizationService.instance.hasPermission(PermissionType.chargeOrder);

    var action = SendChargeAction.shareOrderLink;
    if (allowed) {
      final settings = await _loadSettings();
      final quickCheck = decideSendChargeAction(
        canCharge: allowed,
        settings: settings,
        order: order,
        openCharge: null,
      );
      if (quickCheck != SendChargeAction.shareOrderLink) {
        final openCharge = await _loadOpenCharge(order);
        if (openCharge.failed) {
          action = SendChargeAction.shareOrderLink;
        } else {
          action = decideSendChargeAction(
            canCharge: allowed,
            settings: settings,
            order: order,
            openCharge: openCharge.charge,
          );
        }
      }
    }
    if (!context.mounted) return action;

    if (action == SendChargeAction.createChargeThenShare) {
      final created = await (createCharge ?? _pushCreateCharge)(
        context,
        order,
        OrderPaymentMath.remainingBalance(order),
      );
      if (created == null || !context.mounted) return action;
    }
    await (share ?? _defaultShare)(context, order);
    return action;
  }

  Future<PaymentSettings> _loadSettings() async {
    try {
      final loader = settingsLoader ?? _defaultSettings;
      return await loader().timeout(timeout);
    } catch (_) {
      return PaymentSettings();
    }
  }

  Future<({OrderCharge? charge, bool failed})> _loadOpenCharge(
    Order order,
  ) async {
    try {
      final loader = openChargeLoader ?? _defaultOpenCharge;
      final charge = await loader(order).timeout(timeout);
      return (charge: charge, failed: false);
    } catch (_) {
      // Unknown state: creating a charge could cancel one the customer is
      // about to pay. Fall back to the plain link.
      return (charge: null, failed: true);
    }
  }

  static Future<PaymentSettings> _defaultSettings() {
    final companyId = Global.companyAggr?.id;
    if (companyId == null) return Future.value(PaymentSettings());
    return safePaymentSettings(PaymentSettingsRepository().watch(companyId))
        .first;
  }

  static Future<OrderCharge?> _defaultOpenCharge(Order order) async {
    final companyId = Global.companyAggr?.id;
    final orderId = order.id;
    if (companyId == null || orderId == null) return null;
    final charges =
        await OrderChargeRepository().watch(companyId, orderId).first;
    final current = OrderCharge.current(charges);
    return current != null && current.isOpen ? current : null;
  }

  static Future<OrderCharge?> _pushCreateCharge(
    BuildContext context,
    Order order,
    double remainingBalance,
  ) {
    return Navigator.of(context).push<OrderCharge>(
      CupertinoPageRoute(
        builder: (_) => CreateChargeScreen(
          order: order,
          remainingBalance: remainingBalance,
        ),
      ),
    );
  }

  static Future<void> _defaultShare(BuildContext context, Order order) =>
      ShareLinkSheet.show(context, order);
}
