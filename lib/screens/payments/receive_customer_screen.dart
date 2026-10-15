import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/screens/payments/widgets/receipt_file_picker.dart';
import 'package:praticos/screens/payments/widgets/receive_amount_field.dart';
import 'package:praticos/screens/payments/widgets/receive_block.dart'
    show ReceiptChip;
import 'package:praticos/screens/payments/widgets/receive_date_row.dart';
import 'package:praticos/screens/payments/widgets/receive_orders_picker.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/app_toast.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/primary_button.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/customer_receipt_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
import 'package:praticos/utils/currency_input.dart';
import 'package:praticos/utils/payment_allocation.dart';
import 'package:praticos/widgets/permission_widgets.dart';

/// "Receber de João": one payment from a customer who owes on several
/// orders, split oldest order first ([allocatePayment]). "Escolher as OS"
/// limits the split to the chosen orders (still oldest first).
///
/// Amount (pre-filled with everything owed, never more), day the money came
/// in ("Hoje" by default, no future dates), optional receipt, the live
/// "Como fica" split and one blue "Recebi R$ X". On success it shows a toast
/// and pops with `true`. Pushed (not a sheet): it acts on existing orders.
class ReceiveCustomerScreen extends StatefulWidget {
  const ReceiveCustomerScreen({
    super.key,
    required this.orders,
    this.customer,
    this.customerName,
    this.service,
    this.canAttachReceipt,
    this.pickReceipt,
    this.pickOrders,
  });

  /// Open orders of the customer, oldest first (as `Debtor.orders`).
  final List<Order> orders;
  final CustomerAggr? customer;

  /// Falls back to [customer]'s name.
  final String? customerName;

  /// Injected in tests.
  final CustomerReceiptService? service;

  /// Overrides the `attachPhotos` permission (tests).
  final bool? canAttachReceipt;

  /// Overrides the camera/gallery/files picker (tests).
  final Future<PickedReceiptFile?> Function(BuildContext context)? pickReceipt;

  /// Overrides the "Escolher as OS" picker (tests).
  final Future<Set<String>?> Function(
    BuildContext context,
    List<Order> orders,
    Set<String> selected,
  )?
  pickOrders;

  /// Pushes the screen; completes with true when a payment was recorded.
  /// Without financial access (`viewFinancialReports`) it shows "access
  /// denied" instead. [canReceive] overrides that permission (tests).
  static Future<bool> open(
    BuildContext context, {
    required List<Order> orders,
    CustomerAggr? customer,
    String? customerName,
    bool? canAttachReceipt,
    bool? canReceive,
  }) async {
    final done = await Navigator.of(context, rootNavigator: true).push<bool>(
      CupertinoPageRoute<bool>(
        settings: const RouteSettings(name: '/receive_customer'),
        builder: (context) {
          final screen = ReceiveCustomerScreen(
            orders: orders,
            customer: customer,
            customerName: customerName,
            canAttachReceipt: canAttachReceipt,
          );
          // Only who has financial access receives (owner, admin, manager).
          if (canReceive != null) {
            return canReceive
                ? screen
                : AccessDeniedScreen(onBack: () => Navigator.of(context).pop());
          }
          return ProtectedRoute(
            permission: PermissionType.viewFinancialReports,
            child: screen,
          );
        },
      ),
    );
    return done ?? false;
  }

  @override
  State<ReceiveCustomerScreen> createState() => _ReceiveCustomerScreenState();
}

class _ReceiveCustomerScreenState extends State<ReceiveCustomerScreen> {
  late final List<OpenBalance> _balances = [
    for (final order in widget.orders) OpenBalance.ofOrder(order),
  ].where((b) => b.open > 0).toList();
  late final double _owed = totalOpen(_balances);
  late final TextEditingController _amount = TextEditingController(
    text: ReceiveAmountField.textFor(_owed),
  );

  /// Orders chosen in "Escolher as OS"; null = all of them.
  Set<String>? _chosen;

  /// Balances the payment goes to (the chosen ones, oldest first).
  List<OpenBalance> get _active => chosenBalances(_balances, _chosen);

  /// Most that can be received now: what is open on [_active].
  double get _max => totalOpen(_active);

  DateTime _paidDay = DateTime.now();
  PickedReceiptFile? _receipt;
  bool _busy = false;

  bool get _canAttach =>
      widget.canAttachReceipt ??
      AuthorizationService.instance.hasPermission(PermissionType.attachPhotos);

  String get _name =>
      widget.customerName ??
      widget.customer?.name ??
      context.l10n.customerWithoutName;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int _cents(double value) => (value * 100).round();

  Future<void> _pickDay() async {
    final day = await pickPaymentDay(context, _paidDay);
    if (day != null && mounted) setState(() => _paidDay = day);
  }

  Future<void> _attach() async {
    final picked = await (widget.pickReceipt ?? pickReceiptFile)(context);
    if (picked != null && mounted) setState(() => _receipt = picked);
  }

  Future<void> _chooseOrders() async {
    final openOrders = [
      for (final b in _balances)
        for (final o in widget.orders)
          if (o.id == b.orderId) o,
    ];
    final current = _chosen ?? {for (final b in _balances) b.orderId};
    final picked = await (widget.pickOrders ??
        (context, orders, selected) =>
            pickReceiveOrders(context, orders: orders, selected: selected))(
      context,
      openOrders,
      current,
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() {
      _chosen = picked.length == _balances.length ? null : picked;
      _amount.text = ReceiveAmountField.textFor(_max);
    });
  }

  Future<void> _confirm() async {
    final value = parseCurrencyInput(_amount.text);
    if (_busy || value <= 0 || _cents(value) > _cents(_max)) return;
    final l10n = context.l10n;
    final allocations = allocatePayment(_active, value);
    setState(() => _busy = true);
    try {
      await (widget.service ?? CustomerReceiptService()).record(
        CustomerReceiptRequest(
          customer: widget.customer,
          orders: widget.orders,
          allocations: allocations,
          paidAt: paidAtFor(_paidDay),
          file: _receipt,
        ),
      );
    } on CustomerReceiptException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppToast(
        context,
        e.reason == CustomerReceiptFailure.upload
            ? l10n.receiveCustomerUploadFailed
            : l10n.paymentUpdateFailed,
        icon: CupertinoIcons.exclamationmark_circle,
      );
      return;
    }
    if (!mounted) return;
    showAppToast(
      context,
      l10n.receiveCustomerDone(ReceiveAmountField.textFor(value), _name),
      icon: CupertinoIcons.checkmark_circle,
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppColors.text.resolveFrom(context);
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final format = FormatService();

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppNavBar.barBackground(context),
        border: null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          bottom: false,
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _amount,
            builder: (context, value, _) {
              final amount = parseCurrencyInput(value.text);
              final active = _active;
              final tooMuch = _cents(amount) > _cents(_max);
              final canSave = !_busy && amount > 0 && !tooMuch;
              final previews = previewAllocation(
                active,
                tooMuch ? const [] : allocatePayment(active, amount),
              );
              return ListView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom + 40,
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageMargin,
                      AppSpacing.sm,
                      AppSpacing.pageMargin,
                      AppSpacing.xs,
                    ),
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.receiveCustomerTitle(_name),
                        key: const Key('receiveCustomerTitle'),
                        style: AppTypography.title.copyWith(color: text),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageMargin,
                      0,
                      AppSpacing.pageMargin,
                      AppSpacing.sm,
                    ),
                    child: Text(
                      l10n.receiveCustomerOwes(
                        format.formatCurrency(_owed),
                        _balances.length,
                      ),
                      key: const Key('receiveCustomerOwes'),
                      style: AppTypography.callout.copyWith(
                        color: secondary,
                        fontFeatures: AppTypography.tabular,
                      ),
                    ),
                  ),
                  _buildAmountCard(amount, tooMuch),
                  SectionLabel(l10n.receiveCustomerHowItGoes),
                  for (final preview in previews)
                    AppListRow(
                      key: Key('receiveCustomerRow_${preview.balance.orderId}'),
                      title: _previewLine(preview, format),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageMargin,
                      AppSpacing.sm,
                      AppSpacing.pageMargin,
                      AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _chosen == null
                              ? l10n.receiveCustomerOldestFirst
                              : l10n.receiveCustomerChosenOnly,
                          key: const Key('receiveCustomerSplitNote'),
                          style: AppTypography.label.copyWith(
                            color: secondary,
                          ),
                        ),
                        if (_balances.length > 1)
                          TextLink(
                            key: const Key('receiveCustomerChoose'),
                            label: l10n.receiveCustomerChooseOrders,
                            onPressed: _busy ? null : _chooseOrders,
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.blockMargin,
                    ),
                    child: _busy
                        ? const SizedBox(
                            height: AppSizes.primaryButtonHeight,
                            child: Center(child: CupertinoActivityIndicator()),
                          )
                        : PrimaryButton(
                            key: const Key('receiveCustomerConfirm'),
                            label: l10n.receiveButton(
                              ReceiveAmountField.textFor(amount),
                            ),
                            onPressed: canSave ? _confirm : null,
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// accentSoft block: amount, hint (or why the button is off), "Quando"
  /// and the receipt.
  Widget _buildAmountCard(double amount, bool tooMuch) {
    final l10n = context.l10n;
    final onSoft = AppColors.onAccentSoft.resolveFrom(context);
    final String hint;
    Color hintColor = onSoft;
    if (tooMuch) {
      final max = FormatService().formatCurrency(_max);
      hint = _chosen == null
          ? l10n.receiveCustomerTooMuch(max)
          : l10n.receiveCustomerTooMuchChosen(max);
      hintColor = AppColors.danger.resolveFrom(context);
    } else if (amount <= 0) {
      hint = l10n.receiveCustomerZero;
    } else {
      hint = l10n.receiveAmountHint;
    }

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.blockMargin,
        vertical: AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.accentSoft.resolveFrom(context),
        borderRadius: BorderRadius.circular(AppRadii.block),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.receiveCustomerAmountLabel,
            style: AppTypography.label.copyWith(color: onSoft),
          ),
          const SizedBox(height: AppSpacing.xs),
          ReceiveAmountField(controller: _amount),
          const SizedBox(height: AppSpacing.xs),
          Text(
            hint,
            key: const Key('receiveCustomerHint'),
            style: AppTypography.label.copyWith(
              color: hintColor,
              fontWeight: tooMuch ? FontWeight.w600 : null,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ReceiveDateRow(day: _paidDay, onTap: _busy ? null : _pickDay),
          if (_receipt != null)
            ReceiptChip(
              name: _receipt!.name,
              onRemove: _busy ? null : () => setState(() => _receipt = null),
            )
          else if (_canAttach)
            CupertinoButton(
              key: const Key('receiveCustomerAttach'),
              padding: EdgeInsets.zero,
              minimumSize: const Size(
                AppSizes.minTouchTarget,
                AppSizes.minTouchTarget,
              ),
              onPressed: _busy ? null : _attach,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.paperclip,
                    size: 20,
                    color: AppColors.accentText.resolveFrom(context),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      l10n.receiveAttachReceipt,
                      style: AppTypography.callout.copyWith(
                        color: AppColors.accentText.resolveFrom(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _previewLine(AllocationPreview preview, FormatService format) {
    final l10n = context.l10n;
    final number = preview.balance.orderNumber ?? 0;
    if (preview.untouched) {
      return l10n.receiveCustomerUntouched(
        number,
        format.formatCurrency(preview.balance.open),
      );
    }
    if (preview.settles) {
      return l10n.receiveCustomerSettles(
        number,
        format.formatCurrency(preview.received),
      );
    }
    return l10n.receiveCustomerPartial(
      number,
      format.formatCurrency(preview.received),
      format.formatCurrency(preview.remaining),
    );
  }
}
