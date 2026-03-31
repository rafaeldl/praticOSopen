import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/financial_account.dart';
import 'package:praticos/models/financial_entry.dart';
import 'package:praticos/models/payment_method.dart';
import 'package:praticos/services/format_service.dart';

/// Half-sheet for confirming payment of an entry.
///
/// Offers a quick "one-tap" confirmation mode with a summary and a big
/// confirm button, plus an expandable "edit details" section to adjust
/// amount, account, payment method, date, and discount.
class PaymentConfirmationSheet extends StatefulWidget {
  final FinancialEntry entry;
  final List<FinancialAccount> accounts;
  final Function(
    double amount,
    String accountId,
    FinancialAccountAggr account,
    PaymentMethod method,
    DateTime date, {
    double? discount,
  }) onConfirm;

  const PaymentConfirmationSheet({
    super.key,
    required this.entry,
    required this.accounts,
    required this.onConfirm,
  });

  /// Show the payment confirmation sheet as a modal popup.
  static Future<void> show(
    BuildContext context, {
    required FinancialEntry entry,
    required List<FinancialAccount> accounts,
    required Function(
      double amount,
      String accountId,
      FinancialAccountAggr account,
      PaymentMethod method,
      DateTime date, {
      double? discount,
    }) onConfirm,
  }) {
    return showCupertinoModalPopup(
      context: context,
      builder: (context) => PaymentConfirmationSheet(
        entry: entry,
        accounts: accounts,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<PaymentConfirmationSheet> createState() =>
      _PaymentConfirmationSheetState();
}

class _PaymentConfirmationSheetState extends State<PaymentConfirmationSheet> {
  bool _showDetails = false;
  bool _showDiscount = false;

  late double _amount;
  late FinancialAccount _selectedAccount;
  late PaymentMethod _selectedMethod;
  late DateTime _selectedDate;
  double _discount = 0;

  @override
  void initState() {
    super.initState();
    _amount = widget.entry.remainingBalance;
    _selectedAccount = _defaultAccount;
    _selectedMethod = PaymentMethod.pix;
    _selectedDate = DateTime.now();
  }

  FinancialAccount get _defaultAccount {
    final defaultAcc = widget.accounts
        .where((a) => a.isDefault == true)
        .toList();
    if (defaultAcc.isNotEmpty) return defaultAcc.first;
    return widget.accounts.first;
  }

  String _paymentMethodLabel(BuildContext context, PaymentMethod method) {
    switch (method) {
      case PaymentMethod.pix:
        return context.l10n.pix;
      case PaymentMethod.cash:
        return context.l10n.cash;
      case PaymentMethod.creditCard:
        return context.l10n.creditCard;
      case PaymentMethod.debitCard:
        return context.l10n.debitCard;
      case PaymentMethod.transfer:
        return context.l10n.transfer;
      case PaymentMethod.check:
        return context.l10n.check;
      case PaymentMethod.other:
        return context.l10n.other;
    }
  }

  void _confirm() {
    final accountAggr = _selectedAccount.toAggr();
    widget.onConfirm(
      _amount,
      _selectedAccount.id ?? '',
      accountAggr,
      _selectedMethod,
      _selectedDate,
      discount: _showDiscount && _discount > 0 ? _discount : null,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor =
        CupertinoColors.systemGroupedBackground.resolveFrom(context);
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryLabelColor =
        CupertinoColors.secondaryLabel.resolveFrom(context);
    final separatorColor = CupertinoColors.separator.resolveFrom(context);
    final formattedAmount = FormatService().formatCurrency(_amount);
    final methodLabel = _paymentMethodLabel(context, _selectedMethod);
    final accountName = _selectedAccount.name ?? '';

    return Container(
      constraints: const BoxConstraints(minHeight: 300, maxHeight: 500),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey3.resolveFrom(context),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                context.l10n.confirmPayment,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
              const SizedBox(height: 4),

              // Entry description
              if (widget.entry.description != null)
                Text(
                  widget.entry.description!,
                  style: TextStyle(
                    fontSize: 14,
                    color: secondaryLabelColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 16),

              // Summary text (one-tap mode)
              if (!_showDetails) ...[
                Text(
                  '${context.l10n.confirm} $formattedAmount '
                  '${methodLabel.isNotEmpty ? 'via $methodLabel ' : ''}'
                  '${accountName.isNotEmpty ? '${context.l10n.account.toLowerCase()}: $accountName' : ''}',
                  style: TextStyle(
                    fontSize: 15,
                    color: labelColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Edit details link
                GestureDetector(
                  onTap: () => setState(() => _showDetails = true),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      context.l10n.editDetails,
                      style: const TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.activeBlue,
                      ),
                    ),
                  ),
                ),
              ],

              // Expanded details
              if (_showDetails) ...[
                Divider(height: 1, color: separatorColor),
                const SizedBox(height: 12),

                // Amount
                _buildField(
                  context,
                  label: context.l10n.value,
                  child: CupertinoTextField(
                    controller: TextEditingController(
                      text: _amount.toStringAsFixed(2),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      final parsed = double.tryParse(
                        value.replaceAll(',', '.'),
                      );
                      if (parsed != null) {
                        setState(() => _amount = parsed);
                      }
                    },
                    placeholder: context.l10n.value,
                  ),
                ),
                const SizedBox(height: 12),

                // Account picker
                _buildField(
                  context,
                  label: context.l10n.account,
                  child: GestureDetector(
                    onTap: () => _showAccountPicker(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemBackground
                            .resolveFrom(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: separatorColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              accountName,
                              style: TextStyle(
                                fontSize: 15,
                                color: labelColor,
                              ),
                            ),
                          ),
                          Icon(
                            CupertinoIcons.chevron_down,
                            size: 14,
                            color: secondaryLabelColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Payment method picker
                _buildField(
                  context,
                  label: context.l10n.paymentMethod,
                  child: GestureDetector(
                    onTap: () => _showMethodPicker(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemBackground
                            .resolveFrom(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: separatorColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              methodLabel,
                              style: TextStyle(
                                fontSize: 15,
                                color: labelColor,
                              ),
                            ),
                          ),
                          Icon(
                            CupertinoIcons.chevron_down,
                            size: 14,
                            color: secondaryLabelColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Date picker
                _buildField(
                  context,
                  label: context.l10n.paymentDate,
                  child: GestureDetector(
                    onTap: () => _showDatePicker(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemBackground
                            .resolveFrom(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: separatorColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              FormatService().formatDate(_selectedDate),
                              style: TextStyle(
                                fontSize: 15,
                                color: labelColor,
                              ),
                            ),
                          ),
                          Icon(
                            CupertinoIcons.calendar,
                            size: 16,
                            color: secondaryLabelColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Discount toggle
                GestureDetector(
                  onTap: () =>
                      setState(() => _showDiscount = !_showDiscount),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          _showDiscount
                              ? CupertinoIcons.chevron_down
                              : CupertinoIcons.chevron_right,
                          size: 14,
                          color: CupertinoColors.activeBlue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.l10n.discount,
                          style: const TextStyle(
                            fontSize: 14,
                            color: CupertinoColors.activeBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_showDiscount) ...[
                  const SizedBox(height: 8),
                  _buildField(
                    context,
                    label: context.l10n.discountAmount,
                    child: CupertinoTextField(
                      controller: TextEditingController(
                        text: _discount > 0
                            ? _discount.toStringAsFixed(2)
                            : '',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (value) {
                        final parsed = double.tryParse(
                          value.replaceAll(',', '.'),
                        );
                        if (parsed != null) {
                          setState(() => _discount = parsed);
                        }
                      },
                      placeholder: context.l10n.discountAmount,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 8),

              // Confirm button
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: _confirm,
                  borderRadius: BorderRadius.circular(12),
                  child: Text(
                    '${context.l10n.confirm} $formattedAmount',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    BuildContext context, {
    required String label,
    required Widget child,
  }) {
    final secondaryLabelColor =
        CupertinoColors.secondaryLabel.resolveFrom(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: secondaryLabelColor,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  void _showAccountPicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(context.l10n.account),
        actions: widget.accounts.map((account) {
          return CupertinoActionSheetDefaultButton(
            onPressed: () {
              setState(() => _selectedAccount = account);
              Navigator.of(ctx).pop();
            },
            child: Text(account.name ?? ''),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetDefaultButton(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(context.l10n.cancel),
        ),
      ),
    );
  }

  void _showMethodPicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(context.l10n.paymentMethod),
        actions: PaymentMethod.values.map((method) {
          return CupertinoActionSheetDefaultButton(
            onPressed: () {
              setState(() => _selectedMethod = method);
              Navigator.of(ctx).pop();
            },
            child: Text(_paymentMethodLabel(context, method)),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetDefaultButton(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(context.l10n.cancel),
        ),
      ),
    );
  }

  void _showDatePicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 260,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  child: Text(context.l10n.confirm),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _selectedDate,
                onDateTimeChanged: (date) {
                  setState(() => _selectedDate = date);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Extension to expose a Divider-like widget for Cupertino context.
class Divider extends StatelessWidget {
  final double height;
  final Color? color;

  const Divider({super.key, this.height = 1, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: color ?? CupertinoColors.separator.resolveFrom(context),
    );
  }
}

/// Button type that works within CupertinoActionSheet.
class CupertinoActionSheetDefaultButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool isDestructiveAction;

  const CupertinoActionSheetDefaultButton({
    super.key,
    this.onPressed,
    required this.child,
    this.isDestructiveAction = false,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoActionSheetAction(
      onPressed: onPressed ?? () {},
      isDestructiveAction: isDestructiveAction,
      child: child,
    );
  }
}
