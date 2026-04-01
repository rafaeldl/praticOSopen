import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/financial_payment.dart';
import 'package:praticos/models/payment_method.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/photo_service.dart';

/// Half-sheet showing payment details with receipt attachment and reversal.
class PaymentDetailSheet extends StatefulWidget {
  final FinancialPayment payment;
  final Function(FinancialPayment payment, String reason)? onReverse;
  final VoidCallback? onOrderTap;
  final String? companyId;
  final Future<void> Function(FinancialPayment payment, String url)?
      onAttachmentAdded;

  const PaymentDetailSheet({
    super.key,
    required this.payment,
    this.onReverse,
    this.onOrderTap,
    this.companyId,
    this.onAttachmentAdded,
  });

  static Future<void> show(
    BuildContext context, {
    required FinancialPayment payment,
    Function(FinancialPayment payment, String reason)? onReverse,
    VoidCallback? onOrderTap,
    String? companyId,
    Future<void> Function(FinancialPayment payment, String url)?
        onAttachmentAdded,
  }) {
    return showCupertinoModalPopup(
      context: context,
      builder: (context) => PaymentDetailSheet(
        payment: payment,
        onReverse: onReverse,
        onOrderTap: onOrderTap,
        companyId: companyId,
        onAttachmentAdded: onAttachmentAdded,
      ),
    );
  }

  @override
  State<PaymentDetailSheet> createState() => _PaymentDetailSheetState();
}

class _PaymentDetailSheetState extends State<PaymentDetailSheet> {
  bool _isUploading = false;

  bool get _isReversed =>
      widget.payment.status == FinancialPaymentStatus.reversed;

  bool get _canReverse =>
      widget.onReverse != null &&
      widget.payment.status == FinancialPaymentStatus.completed &&
      widget.payment.reversedPaymentId == null;

  Color get _typeColor {
    if (_isReversed) return CupertinoColors.systemGrey;
    switch (widget.payment.type) {
      case FinancialPaymentType.income:
        return CupertinoColors.systemGreen;
      case FinancialPaymentType.expense:
        return CupertinoColors.systemRed;
      case FinancialPaymentType.transfer:
        return CupertinoColors.activeBlue;
      case null:
        return CupertinoColors.systemGrey;
    }
  }

  String _typeLabel(BuildContext context) {
    switch (widget.payment.type) {
      case FinancialPaymentType.income:
        return context.l10n.income;
      case FinancialPaymentType.expense:
        return context.l10n.expense;
      case FinancialPaymentType.transfer:
        return context.l10n.transfer;
      case null:
        return '';
    }
  }

  String _formatAmount() {
    final formatted =
        FormatService().formatCurrency(widget.payment.amount ?? 0);
    if (_isReversed) return formatted;
    switch (widget.payment.type) {
      case FinancialPaymentType.income:
        return '+$formatted';
      case FinancialPaymentType.expense:
        return '-$formatted';
      case FinancialPaymentType.transfer:
      case null:
        return formatted;
    }
  }

  String _paymentMethodLabel(PaymentMethod? method) {
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
      case null:
        return '';
    }
  }

  Future<void> _pickAndUploadReceipt() async {
    if (widget.companyId == null || widget.payment.id == null) return;

    final photoService = PhotoService();
    final file = await photoService.pickDocument();
    if (file == null || file.path == null) return;

    setState(() => _isUploading = true);
    try {
      final ext = file.extension ?? 'jpg';
      final contentType = ext == 'pdf' ? 'application/pdf' : 'image/$ext';
      final storagePath =
          'tenants/${widget.companyId}/financial/payments/${widget.payment.id}/attachments/${file.name}';

      final url = await photoService.uploadFile(
        file: File(file.path!),
        storagePath: storagePath,
        contentType: contentType,
      );

      if (url != null && widget.onAttachmentAdded != null) {
        await widget.onAttachmentAdded!(widget.payment, url);
        if (mounted) {
          setState(() {
            widget.payment.attachments ??= [];
            widget.payment.attachments!.add(url);
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _showReversalDialog() async {
    String reason = '';
    final result = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return CupertinoAlertDialog(
              title: Text(context.l10n.confirmReversal),
              content: Column(
                children: [
                  const SizedBox(height: 8),
                  Text(context.l10n.confirmReversalMessage),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    placeholder: context.l10n.reversalReasonHint,
                    onChanged: (value) =>
                        setDialogState(() => reason = value),
                    autofocus: true,
                    maxLines: 2,
                  ),
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(context.l10n.cancel),
                ),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  onPressed: reason.trim().isEmpty
                      ? null
                      : () => Navigator.pop(ctx, reason.trim()),
                  child: Text(context.l10n.reversePayment),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      widget.onReverse!(widget.payment, result);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final secondaryLabelColor =
        CupertinoColors.secondaryLabel.resolveFrom(context);
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final payment = widget.payment;
    final textDecoration =
        _isReversed ? TextDecoration.lineThrough : TextDecoration.none;

    return Container(
      constraints: const BoxConstraints(minHeight: 200, maxHeight: 520),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 4),
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey4.resolveFrom(context),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),

              // Title
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  context.l10n.paymentDetails,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
                ),
              ),

              // Header: description + amount
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        payment.description ?? '',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color:
                              _isReversed ? CupertinoColors.systemGrey : labelColor,
                          decoration: textDecoration,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatAmount(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _typeColor,
                        decoration: textDecoration,
                      ),
                    ),
                  ],
                ),
              ),

              // Type + method subtitle
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Text(
                  '${_typeLabel(context)} \u00b7 ${_paymentMethodLabel(payment.paymentMethod)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: secondaryLabelColor,
                    decoration: textDecoration,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Detail rows
              _buildDetailRow(
                  context, context.l10n.paymentDate,
                  payment.paymentDate != null
                      ? FormatService().formatDate(payment.paymentDate!)
                      : '-'),
              _buildDetailRow(
                  context, context.l10n.accounts, payment.account?.name ?? '-'),
              if (payment.category != null && payment.category!.isNotEmpty)
                _buildDetailRow(
                    context, context.l10n.category, payment.category!),
              if (payment.supplier != null && payment.supplier!.isNotEmpty)
                _buildDetailRow(
                    context, context.l10n.supplier, payment.supplier!),
              if (payment.customer?.name != null)
                _buildDetailRow(
                    context, context.l10n.customer, payment.customer!.name!),

              // OS link
              if (payment.orderId != null && payment.orderNumber != null)
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    widget.onOrderTap?.call();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            'OS',
                            style: TextStyle(
                                fontSize: 14, color: secondaryLabelColor),
                          ),
                        ),
                        Text(
                          '#${payment.orderNumber}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: CupertinoColors.activeBlue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(CupertinoIcons.chevron_right,
                            size: 14, color: CupertinoColors.activeBlue),
                      ],
                    ),
                  ),
                ),

              // Reversed info
              if (_isReversed && payment.reversalReason != null)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6.resolveFrom(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.arrow_uturn_left,
                            size: 16, color: CupertinoColors.systemOrange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            payment.reversalReason!,
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: secondaryLabelColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Attachments section
              if (!_isReversed) ...[
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    height: 0.5,
                    color: CupertinoColors.separator.resolveFrom(context),
                  ),
                ),

                // Existing attachments
                if (payment.attachments != null &&
                    payment.attachments!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: payment.attachments!.map((url) {
                        final isPdf = url.toLowerCase().contains('.pdf');
                        return GestureDetector(
                          onTap: () {
                            // Could open preview
                          },
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: CupertinoColors.systemGrey5
                                  .resolveFrom(context),
                            ),
                            child: isPdf
                                ? const Icon(CupertinoIcons.doc_text,
                                    size: 28)
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(url,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                                CupertinoIcons.photo)),
                                  ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                // Attach button
                if (widget.companyId != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _isUploading ? null : _pickAndUploadReceipt,
                      child: Row(
                        children: [
                          if (_isUploading)
                            const CupertinoActivityIndicator()
                          else
                            const Icon(CupertinoIcons.paperclip, size: 18),
                          const SizedBox(width: 6),
                          Text(context.l10n.attachReceipt),
                        ],
                      ),
                    ),
                  ),
              ],

              // Reverse button
              if (_canReverse)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      color: CupertinoColors.systemRed.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      onPressed: _showReversalDialog,
                      child: Text(
                        context.l10n.reversePayment,
                        style: const TextStyle(
                          color: CupertinoColors.systemRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
      BuildContext context, String label, String value) {
    final secondaryLabelColor =
        CupertinoColors.secondaryLabel.resolveFrom(context);
    final labelColor = CupertinoColors.label.resolveFrom(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: secondaryLabelColor),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, color: labelColor),
            ),
          ),
        ],
      ),
    );
  }
}
