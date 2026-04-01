import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/financial_account.dart';
import 'package:praticos/models/financial_entry.dart';
import 'package:praticos/models/payment_method.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/photo_service.dart';

/// Half-sheet for confirming payment of an entry.
///
/// Offers a quick "one-tap" confirmation mode with a summary and a big
/// confirm button, plus an expandable "edit details" section to adjust
/// amount, account, payment method, date, and discount.
class PaymentConfirmationSheet extends StatefulWidget {
  final FinancialEntry entry;
  final List<FinancialAccount> accounts;
  final String? companyId;
  final Function(
    double amount,
    String accountId,
    FinancialAccountAggr account,
    PaymentMethod method,
    DateTime date, {
    double? discount,
    List<String>? attachments,
  }) onConfirm;

  const PaymentConfirmationSheet({
    super.key,
    required this.entry,
    required this.accounts,
    required this.onConfirm,
    this.companyId,
  });

  /// Show the payment confirmation sheet as a modal popup.
  static Future<void> show(
    BuildContext context, {
    required FinancialEntry entry,
    required List<FinancialAccount> accounts,
    String? companyId,
    required Function(
      double amount,
      String accountId,
      FinancialAccountAggr account,
      PaymentMethod method,
      DateTime date, {
      double? discount,
      List<String>? attachments,
    }) onConfirm,
  }) {
    return showCupertinoModalPopup(
      context: context,
      builder: (context) => PaymentConfirmationSheet(
        entry: entry,
        accounts: accounts,
        companyId: companyId,
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
  final List<String> _pendingAttachments = [];
  bool _isUploading = false;

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

  Future<void> _pickAttachment() async {
    if (widget.companyId == null) return;

    final photoService = PhotoService();
    final file = await photoService.pickDocument();
    if (file == null || file.path == null) return;

    setState(() => _isUploading = true);
    try {
      final ext = file.extension ?? 'jpg';
      final contentType = ext == 'pdf' ? 'application/pdf' : 'image/$ext';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath =
          'tenants/${widget.companyId}/financial/payments/pending_$timestamp/attachments/${file.name}';

      final url = await photoService.uploadFile(
        file: File(file.path!),
        storagePath: storagePath,
        contentType: contentType,
      );

      if (url != null && mounted) {
        setState(() => _pendingAttachments.add(url));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
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
      attachments: _pendingAttachments.isNotEmpty ? _pendingAttachments : null,
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
    final formattedAmount = FormatService().formatCurrency(_amount);
    final methodLabel = _paymentMethodLabel(context, _selectedMethod);
    final accountName = _selectedAccount.name ?? '';

    return Material(
      type: MaterialType.transparency,
      child: Container(
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

              // === Quick mode: summary card ===
              if (!_showDetails) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6.resolveFrom(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        formattedAmount,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: labelColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${methodLabel.isNotEmpty ? 'via $methodLabel' : ''}'
                        '${accountName.isNotEmpty ? ' · $accountName' : ''}',
                        style: TextStyle(
                          fontSize: 14,
                          color: secondaryLabelColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _showDetails = true),
                      child: Text(
                        context.l10n.editDetails,
                        style: const TextStyle(
                          fontSize: 15,
                          color: CupertinoColors.activeBlue,
                        ),
                      ),
                    ),
                    if (widget.companyId != null) ...[
                      Text('  ·  ', style: TextStyle(fontSize: 15, color: secondaryLabelColor)),
                      GestureDetector(
                        onTap: _isUploading ? null : _pickAttachment,
                        child: Row(
                          children: [
                            if (_isUploading)
                              const CupertinoActivityIndicator()
                            else
                              Icon(CupertinoIcons.paperclip, size: 15, color: CupertinoColors.activeBlue),
                            const SizedBox(width: 4),
                            Text(
                              _pendingAttachments.isEmpty
                                  ? context.l10n.attachReceipt
                                  : '${_pendingAttachments.length}',
                              style: const TextStyle(fontSize: 15, color: CupertinoColors.activeBlue),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],

              // === Expanded mode: insetGrouped fields ===
              if (_showDetails) ...[
                CupertinoListSection.insetGrouped(
                  margin: EdgeInsets.zero,
                  children: [
                    // Amount row
                    CupertinoListTile(
                      title: Text(context.l10n.value),
                      additionalInfo: SizedBox(
                        width: 120,
                        child: CupertinoTextField(
                          controller: TextEditingController(
                            text: FormatService().formatDecimal(_amount),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.right,
                          decoration: null,
                          style: TextStyle(fontSize: 17, color: labelColor),
                          onChanged: (value) {
                            final parsed = double.tryParse(value.replaceAll(',', '.'));
                            if (parsed != null) setState(() => _amount = parsed);
                          },
                        ),
                      ),
                    ),
                    // Account row
                    GestureDetector(
                      onTap: () => _showAccountPicker(context),
                      behavior: HitTestBehavior.opaque,
                      child: CupertinoListTile(
                        title: Text(context.l10n.account),
                        additionalInfo: Text(accountName, style: TextStyle(color: secondaryLabelColor)),
                        trailing: const CupertinoListTileChevron(),
                      ),
                    ),
                    // Method row
                    GestureDetector(
                      onTap: () => _showMethodPicker(context),
                      behavior: HitTestBehavior.opaque,
                      child: CupertinoListTile(
                        title: Text(context.l10n.paymentMethod),
                        additionalInfo: Text(methodLabel, style: TextStyle(color: secondaryLabelColor)),
                        trailing: const CupertinoListTileChevron(),
                      ),
                    ),
                    // Date row
                    GestureDetector(
                      onTap: () => _showDatePicker(context),
                      behavior: HitTestBehavior.opaque,
                      child: CupertinoListTile(
                        title: Text(context.l10n.paymentDate),
                        additionalInfo: Text(FormatService().formatDate(_selectedDate), style: TextStyle(color: secondaryLabelColor)),
                        trailing: const CupertinoListTileChevron(),
                      ),
                    ),
                    // Discount row
                    GestureDetector(
                      onTap: () => setState(() => _showDiscount = !_showDiscount),
                      behavior: HitTestBehavior.opaque,
                      child: CupertinoListTile(
                        leading: Icon(
                          _showDiscount ? CupertinoIcons.chevron_down : CupertinoIcons.chevron_right,
                          size: 14, color: CupertinoColors.activeBlue,
                        ),
                        title: Text(context.l10n.discount, style: const TextStyle(color: CupertinoColors.activeBlue)),
                      ),
                    ),
                    if (_showDiscount)
                      CupertinoListTile(
                        title: Text(context.l10n.discountAmount),
                        additionalInfo: SizedBox(
                          width: 120,
                          child: CupertinoTextField(
                            controller: TextEditingController(
                              text: _discount > 0 ? FormatService().formatDecimal(_discount) : '',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.right,
                            decoration: null,
                            placeholder: '0,00',
                            style: TextStyle(fontSize: 17, color: labelColor),
                            onChanged: (value) {
                              final parsed = double.tryParse(value.replaceAll(',', '.'));
                              if (parsed != null) setState(() => _discount = parsed);
                            },
                          ),
                        ),
                      ),
                    // Attachment row (only when companyId is available)
                    if (widget.companyId != null)
                      GestureDetector(
                        onTap: _isUploading ? null : _pickAttachment,
                        behavior: HitTestBehavior.opaque,
                        child: CupertinoListTile(
                          leading: _isUploading
                              ? const CupertinoActivityIndicator()
                              : const Icon(CupertinoIcons.paperclip, color: CupertinoColors.activeBlue, size: 20),
                          title: Text(
                            context.l10n.attachReceipt,
                            style: const TextStyle(color: CupertinoColors.activeBlue),
                          ),
                          additionalInfo: _pendingAttachments.isNotEmpty
                              ? Text(
                                  '${_pendingAttachments.length}',
                                  style: TextStyle(color: secondaryLabelColor),
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

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
    ),
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
