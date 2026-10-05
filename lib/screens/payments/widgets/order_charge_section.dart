import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/models/payment_settings.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/repositories/tenant/payment_settings_repository.dart';
import 'package:praticos/screens/integrations/asaas_connection_screen.dart'
    show safePaymentSettings;
import 'package:praticos/screens/payments/widgets/order_charge_card.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/utils/order_payment_math.dart';

/// "Cobrança" section of the order payments screen.
///
/// Shown only when the user has [PermissionType.chargeOrder], the company is
/// in the Asaas pilot (`asaasEnabled`) and the order accepts payments (not a
/// quote nor canceled, same rule as manual payments). "Cobrar" needs
/// `asaasConnected`; an existing charge stays visible after disconnecting.
class OrderChargeSection extends StatefulWidget {
  const OrderChargeSection({
    super.key,
    required this.store,
    required this.onCreateCharge,
    this.canCharge,
    this.settingsStream,
    this.chargesStream,
  });

  final OrderStore store;

  /// Opens the create-charge flow for the given remaining balance. The
  /// returned future keeps the card's double-tap guard on while it runs.
  final FutureOr<void> Function(double remainingBalance) onCreateCharge;

  /// Test seam; defaults to the [PermissionType.chargeOrder] check.
  final bool? canCharge;

  /// Test seam; defaults to [PaymentSettingsRepository.watch].
  final Stream<PaymentSettings>? settingsStream;

  /// Test seam passed to [OrderChargeCard].
  final Stream<List<OrderCharge>>? chargesStream;

  @override
  State<OrderChargeSection> createState() => _OrderChargeSectionState();
}

class _OrderChargeSectionState extends State<OrderChargeSection> {
  /// Null when the user cannot charge or there is no company.
  Stream<PaymentSettings>? _settings;

  @override
  void initState() {
    super.initState();
    final canCharge = widget.canCharge ??
        AuthorizationService.instance.hasPermission(PermissionType.chargeOrder);
    final companyId = widget.store.companyId;
    if (!canCharge) return;
    final source = widget.settingsStream ??
        (companyId == null
            ? null
            : PaymentSettingsRepository().watch(companyId));
    if (source != null) _settings = safePaymentSettings(source);
  }

  @override
  Widget build(BuildContext context) {
    final settingsStream = _settings;
    if (settingsStream == null) return const SizedBox.shrink();

    return StreamBuilder<PaymentSettings>(
      stream: settingsStream,
      builder: (context, snapshot) {
        final settings = snapshot.data;
        if (settings == null || !settings.asaasEnabled) {
          return const SizedBox.shrink();
        }
        return Observer(
          builder: (_) {
            final store = widget.store;
            final status = store.status;
            // Read the observables so the card follows payment changes.
            store.remainingBalance;
            final order = store.order;
            if (order?.id == null ||
                status == 'quote' ||
                status == 'canceled') {
              return const SizedBox.shrink();
            }
            final remaining = OrderPaymentMath.remainingBalance(order!);
            return OrderChargeCard(
              order: order,
              remainingBalance: remaining,
              canCreateCharge: settings.asaasConnected,
              onCreateCharge: () => widget.onCreateCharge(remaining),
              onChargeSettled: () => store.reloadPayments(),
              chargesStream: widget.chargesStream,
            );
          },
        );
      },
    );
  }
}
