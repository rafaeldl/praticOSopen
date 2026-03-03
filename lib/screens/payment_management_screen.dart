import 'dart:io';

import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType, Divider;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/mobx/order_store.dart';
import 'package:praticos/models/order_document.dart';
import 'package:praticos/models/payment_transaction.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/services/authorization_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/services/photo_service.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:url_launcher/url_launcher.dart';

/// Unified payment management screen that combines:
/// - Financial summary
/// - Payment/discount registration form
/// - Transaction history
class PaymentManagementScreen extends StatefulWidget {
  const PaymentManagementScreen({super.key});

  @override
  State<PaymentManagementScreen> createState() =>
      _PaymentManagementScreenState();
}

class _PaymentManagementScreenState extends State<PaymentManagementScreen> {
  bool _initialized = false;
  OrderStore? _store;

  // Form state
  int _selectedType = 0; // 0 = payment, 1 = discount
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Receipt attachment state
  File? _receiptFile;
  String? _receiptContentType;
  String? _receiptFileName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args.containsKey('orderStore')) {
        _store = args['orderStore'];
        _prefillValue();
      }
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _prefillValue() {
    if (_store != null && _selectedType == 0) {
      final remaining = _store!.remainingBalance;
      if (remaining > 0) {
        _valueController.text = FormatService().formatCurrency(remaining);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor:
          CupertinoColors.systemGroupedBackground.resolveFrom(context),
      child: Material(
        type: MaterialType.transparency,
        child: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: Text(context.l10n.payments),
            ),
            SliverSafeArea(
              top: false,
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildSummarySection(),
                  const SizedBox(height: 20),
                  _buildFormOrPaidSection(),
                  const SizedBox(height: 20),
                  _buildHistorySection(),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SUMMARY SECTION
  // ============================================================

  Widget _buildSummarySection() {
    return Observer(
      builder: (_) {
        final total = _store?.total ?? 0.0;
        final paid = _store?.paidAmount ?? 0.0;
        final discount = _store?.discount ?? 0.0;
        final remaining = _store?.remainingBalance ?? 0.0;
        final isFullyPaid = _store?.isFullyPaid ?? false;

        return _buildGroupedSection(
          header: context.l10n.overview.toUpperCase(),
          children: [
            _buildSummaryRow(
              icon: CupertinoIcons.money_dollar_circle_fill,
              iconColor: CupertinoColors.systemBlue,
              label: context.l10n.total,
              value: FormatService().formatCurrency(total),
              valueColor: CupertinoColors.label.resolveFrom(context),
            ),
            if (discount > 0)
              _buildSummaryRow(
                icon: CupertinoIcons.tag_fill,
                iconColor: CupertinoColors.systemOrange,
                label: context.l10n.discount,
                value: '- ${FormatService().formatCurrency(discount)}',
                valueColor: CupertinoColors.systemOrange,
              ),
            _buildSummaryRow(
              icon: CupertinoIcons.checkmark_circle_fill,
              iconColor: CupertinoColors.systemGreen,
              label: context.l10n.totalPaid,
              value: FormatService().formatCurrency(paid),
              valueColor: CupertinoColors.systemGreen,
            ),
            _buildSummaryRow(
              icon: isFullyPaid
                  ? CupertinoIcons.checkmark_seal_fill
                  : CupertinoIcons.clock_fill,
              iconColor: isFullyPaid
                  ? CupertinoColors.systemGreen
                  : CupertinoColors.systemOrange,
              label: context.l10n.remaining,
              value: FormatService().formatCurrency(remaining),
              valueColor: isFullyPaid
                  ? CupertinoColors.systemGreen
                  : CupertinoColors.systemOrange,
              isBold: true,
              isLast: true,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
    bool isBold = false,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 17,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 50,
            color: CupertinoColors.systemGrey5.resolveFrom(context),
          ),
      ],
    );
  }

  // ============================================================
  // FORM OR PAID BADGE SECTION
  // ============================================================

  Widget _buildFormOrPaidSection() {
    return Observer(
      builder: (_) {
        final status = _store?.status;
        final isFullyPaid = _store?.isFullyPaid ?? false;

        // Pagamentos só são permitidos a partir de 'approved'
        // Não permitir em 'quote' ou 'canceled'
        if (status == 'quote' || status == 'canceled') {
          return _buildPaymentNotAllowedSection(status);
        }

        if (isFullyPaid) {
          return _buildPaidBadgeSection();
        }

        return _buildFormSection();
      },
    );
  }

  Widget _buildPaymentNotAllowedSection(String? status) {
    final isQuote = status == 'quote';
    return _buildGroupedSection(
      header: '',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              Icon(
                isQuote ? CupertinoIcons.doc_text : CupertinoIcons.xmark_circle,
                color: CupertinoColors.systemGrey,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                isQuote
                    ? context.l10n.payments
                    : context.l10n.statusCancelled,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isQuote
                    ? context.l10n.statusQuote
                    : context.l10n.statusCancelled,
                style: TextStyle(
                  fontSize: 15,
                  color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaidBadgeSection() {
    return _buildGroupedSection(
      header: '',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.checkmark_seal_fill,
                    color: CupertinoColors.systemGreen,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.paid,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.systemGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _confirmResetPayment,
                child: Text(
                  context.l10n.toReceive,
                  style: TextStyle(
                    fontSize: 15,
                    color: CupertinoColors.systemRed,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormSection() {
    final remaining = _store?.remainingBalance ?? 0.0;
    final isPayment = _selectedType == 0;

    return _buildGroupedSection(
      header: context.l10n.register.toUpperCase(),
      children: [
        // Segmented Control
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: _selectedType,
              onValueChanged: (value) {
                setState(() {
                  _selectedType = value ?? 0;
                  if (_selectedType == 0) {
                    _prefillValue();
                  } else {
                    _valueController.clear();
                  }
                });
              },
              children: {
                0: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.money_dollar_circle,
                        size: 18,
                        color: _selectedType == 0
                            ? CupertinoColors.label.resolveFrom(context)
                            : CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.l10n.payment,
                        style: TextStyle(
                          color: _selectedType == 0
                              ? CupertinoColors.label.resolveFrom(context)
                              : CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                        ),
                      ),
                    ],
                  ),
                ),
                1: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.tag,
                        size: 18,
                        color: _selectedType == 1
                            ? CupertinoColors.label.resolveFrom(context)
                            : CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.l10n.discount,
                        style: TextStyle(
                          color: _selectedType == 1
                              ? CupertinoColors.label.resolveFrom(context)
                              : CupertinoColors.secondaryLabel
                                  .resolveFrom(context),
                        ),
                      ),
                    ],
                  ),
                ),
              },
            ),
          ),
        ),

        // Value field
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isPayment ? context.l10n.paymentAmount : context.l10n.discountAmount,
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _valueController,
                placeholder: FormatService().formatCurrency(0),
                prefix: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Icon(
                    isPayment
                        ? CupertinoIcons.money_dollar
                        : CupertinoIcons.tag,
                    color: CupertinoColors.systemGrey.resolveFrom(context),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                inputFormatters: [
                  CurrencyTextInputFormatter.currency(
                    locale: 'pt_BR',
                    symbol: 'R\$',
                    decimalDigits: 2,
                  ),
                ],
                keyboardType: TextInputType.number,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6.resolveFrom(context),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),

        // Description field
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${context.l10n.observation} (${context.l10n.optional})',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _descriptionController,
                placeholder: isPayment
                    ? context.l10n.exampleCashPayment
                    : context.l10n.exampleLoyaltyDiscount,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                maxLines: 2,
                style: TextStyle(
                  fontSize: 17,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6.resolveFrom(context),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),

        // Attach receipt button (only for payments, requires attachPhotos permission)
        if (isPayment && AuthorizationService.instance.hasPermission(PermissionType.attachPhotos))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _receiptFile != null
                ? _buildReceiptPreview()
                : CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _showAttachReceiptOptions,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.paperclip,
                          color: CupertinoTheme.of(context).primaryColor,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          context.l10n.attachReceipt,
                          style: TextStyle(
                            fontSize: 15,
                            color: CupertinoTheme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

        // Register button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              onPressed: _registerTransaction,
              child: Text(isPayment ? context.l10n.registerPayment : context.l10n.applyDiscount),
            ),
          ),
        ),

        // Quick action - pay full remaining
        if (isPayment && remaining > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _fillRemainingBalance,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.checkmark_circle,
                    color: CupertinoTheme.of(context).primaryColor,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${context.l10n.payTotalAmount}: ${FormatService().formatCurrency(remaining)}',
                    style: TextStyle(
                      fontSize: 15,
                      color: CupertinoTheme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // HISTORY SECTION
  // ============================================================

  Widget _buildHistorySection() {
    return Observer(
      builder: (_) {
        final transactions = _store?.transactions ?? [];

        if (transactions.isEmpty) {
          return _buildGroupedSection(
            header: context.l10n.history.toUpperCase(),
            children: [
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        CupertinoIcons.doc_text,
                        size: 48,
                        color: CupertinoColors.systemGrey.resolveFrom(context),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.l10n.noTransactionsRecorded,
                        style: TextStyle(
                          fontSize: 15,
                          color: CupertinoColors.secondaryLabel
                              .resolveFrom(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        // Sort by date descending
        final sortedTransactions = List<PaymentTransaction>.from(transactions);
        sortedTransactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return _buildGroupedSection(
          header: context.l10n.history.toUpperCase(),
          children: sortedTransactions.asMap().entries.map((entry) {
            final index = transactions.indexOf(entry.value);
            final transaction = entry.value;
            final isLast = entry.key == sortedTransactions.length - 1;
            return _buildTransactionRow(transaction, index, isLast);
          }).toList(),
        );
      },
    );
  }

  Widget _buildTransactionRow(
      PaymentTransaction transaction, int index, bool isLast) {
    final isPayment = transaction.type == PaymentTransactionType.payment;

    return Dismissible(
      key: ValueKey(
          'transaction_${transaction.createdAt.millisecondsSinceEpoch}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        _confirmDeleteTransaction(index, transaction);
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: CupertinoColors.systemRed,
        child: const Icon(
          CupertinoIcons.trash,
          color: CupertinoColors.white,
        ),
      ),
      child: Container(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Icon container
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isPayment
                          ? CupertinoColors.systemGreen.withValues(alpha: 0.15)
                          : CupertinoColors.systemOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isPayment
                          ? CupertinoIcons.arrow_down_circle
                          : CupertinoIcons.tag,
                      color: isPayment
                          ? CupertinoColors.systemGreen
                          : CupertinoColors.systemOrange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.typeLabel(context.l10n),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: CupertinoColors.label.resolveFrom(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          transaction.description ??
                              FormatService().formatDateTime(transaction.createdAt),
                          style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel
                                .resolveFrom(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (transaction.description != null)
                          Text(
                            FormatService().formatDateTime(transaction.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.tertiaryLabel
                                  .resolveFrom(context),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Receipt indicator (requires viewPhotos permission)
                  if (transaction.hasReceipt &&
                      AuthorizationService.instance.hasPermission(PermissionType.viewPhotos))
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => _openReceipt(transaction),
                        child: Icon(
                          CupertinoIcons.paperclip,
                          color: CupertinoColors.activeBlue,
                          size: 16,
                        ),
                      ),
                    ),
                  // Amount
                  Text(
                    isPayment
                        ? '+ ${FormatService().formatCurrency(transaction.amount)}'
                        : '- ${FormatService().formatCurrency(transaction.amount)}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: isPayment
                          ? CupertinoColors.systemGreen
                          : CupertinoColors.systemOrange,
                    ),
                  ),
                ],
              ),
            ),
            if (!isLast)
              Divider(
                height: 1,
                indent: 68,
                color: CupertinoColors.systemGrey5.resolveFrom(context),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HELPER WIDGETS
  // ============================================================

  Widget _buildGroupedSection({
    required String header,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 20, 8),
            child: Text(
              header,
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground.resolveFrom(context),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  double _parseValue(String value) {
    if (value.isEmpty) return 0;

    try {
      // Tenta fazer parse usando o formato de moeda do locale atual
      final formatService = FormatService();
      final currencyFormat = formatService.currencyFormat;

      // Remove espaços extras
      final cleanValue = value.trim();

      // Tenta parsear usando o NumberFormat do locale
      final parsed = currencyFormat.parse(cleanValue);
      return parsed.toDouble();
    } catch (e) {
      // Fallback: tenta remover símbolos comuns e parsear
      final cleanValue = value
          .replaceAll(RegExp(r'[R\$€£¥\s]'), '') // Remove símbolos de moeda e espaços
          .replaceAll(RegExp(r'\.(?=.*,)'), '') // Remove pontos antes de vírgula (pt-BR)
          .replaceAll(RegExp(r',(?=.*\.)'), '') // Remove vírgulas antes de ponto (en-US)
          .replaceAll(',', '.') // Normaliza decimal para ponto
          .trim();
      return double.tryParse(cleanValue) ?? 0;
    }
  }

  String? _validateValue(String? value) {
    if (value == null || value.isEmpty) {
      return context.l10n.fillValue;
    }

    final valueDouble = _parseValue(value);
    if (valueDouble <= 0) {
      return context.l10n.valueMustBeGreaterThanZero;
    }

    if (_store != null && valueDouble > _store!.remainingBalance) {
      return _selectedType == 0
          ? context.l10n.paymentCannotExceedBalance
          : context.l10n.discountCannotExceedBalance;
    }

    return null;
  }

  void _registerTransaction() async {
    final error = _validateValue(_valueController.text);
    if (error != null) {
      _showError(error);
      return;
    }

    final value = _parseValue(_valueController.text);
    final description = _descriptionController.text.isNotEmpty
        ? _descriptionController.text
        : null;

    if (_selectedType == 0) {
      _store?.addPayment(value, description: description);

      // Upload receipt if one was attached
      if (_receiptFile != null && _store != null) {
        final txnIndex = _store!.transactions.length - 1;
        if (txnIndex >= 0) {
          await _store!.attachReceiptToTransaction(
            txnIndex,
            _receiptFile!,
            _receiptContentType ?? 'application/octet-stream',
            _receiptFileName ?? 'receipt',
          );
        }
      }
    } else {
      _store?.addDiscountTransaction(value, description: description);
    }

    // Clear form and refill with new remaining balance
    _descriptionController.clear();
    setState(() {
      _receiptFile = null;
      _receiptContentType = null;
      _receiptFileName = null;
    });
    _prefillValue();

    // Show feedback
    _showSuccess(_selectedType == 0
        ? context.l10n.paymentRegistered
        : context.l10n.discountApplied);
  }

  void _fillRemainingBalance() {
    final remaining = _store?.remainingBalance ?? 0.0;
    if (remaining > 0) {
      _valueController.text = FormatService().formatCurrency(remaining);
    }
  }

  void _confirmResetPayment() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(context.l10n.markAsToReceive),
        content: Text(context.l10n.thisWillRemoveAllPayments),
        actions: [
          CupertinoDialogAction(
            child: Text(context.l10n.cancel),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _resetPayment();
            },
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
  }

  void _resetPayment() async {
    if (_store != null) {
      await _store!.resetAllPayments();
    }
    _prefillValue();
  }

  void _confirmDeleteTransaction(int index, PaymentTransaction transaction) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('${context.l10n.remove} ${transaction.typeLabel(context.l10n)}'),
        content: Text(
          context.l10n.confirmRemoveTransaction(
            transaction.typeLabel(context.l10n).toLowerCase(),
            FormatService().formatCurrency(transaction.amount),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(context.l10n.cancel),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _store?.removeTransaction(index);
              _prefillValue();
            },
            child: Text(context.l10n.remove),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RECEIPT ACTIONS
  // ============================================================

  Widget _buildReceiptPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _receiptContentType?.startsWith('image/') == true
                ? CupertinoIcons.photo
                : CupertinoIcons.doc_text,
            color: CupertinoColors.activeBlue,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _receiptFileName ?? context.l10n.receipt,
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.label.resolveFrom(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: () {
              setState(() {
                _receiptFile = null;
                _receiptContentType = null;
                _receiptFileName = null;
              });
            },
            child: Icon(
              CupertinoIcons.xmark_circle_fill,
              color: CupertinoColors.systemGrey,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachReceiptOptions() {
    final photoService = PhotoService();
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.camera, size: 20),
                const SizedBox(width: 8),
                Text(context.l10n.takePhoto),
              ],
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final file = await photoService.takePhoto();
              if (file != null) {
                setState(() {
                  _receiptFile = file;
                  _receiptContentType = 'image/jpeg';
                  _receiptFileName =
                      'foto_${DateTime.now().millisecondsSinceEpoch}.jpg';
                });
              }
            },
          ),
          CupertinoActionSheetAction(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.photo, size: 20),
                const SizedBox(width: 8),
                Text(context.l10n.gallery),
              ],
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final file = await photoService.pickImageFromGallery();
              if (file != null) {
                setState(() {
                  _receiptFile = file;
                  _receiptContentType = 'image/jpeg';
                  _receiptFileName =
                      'foto_${DateTime.now().millisecondsSinceEpoch}.jpg';
                });
              }
            },
          ),
          CupertinoActionSheetAction(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.doc, size: 20),
                const SizedBox(width: 8),
                Text(context.l10n.fromFiles),
              ],
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await photoService.pickDocument();
              if (result != null && result.path != null) {
                setState(() {
                  _receiptFile = File(result.path!);
                  _receiptFileName = result.name;
                  final ext = result.extension?.toLowerCase() ?? '';
                  _receiptContentType = _getContentType(ext);
                });
              }
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text(context.l10n.cancel),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  void _openReceipt(PaymentTransaction transaction) async {
    if (transaction.receiptDocumentId == null || _store == null) return;

    final doc = _store!.documents.cast<OrderDocument?>().firstWhere(
      (d) => d?.id == transaction.receiptDocumentId,
      orElse: () => null,
    );
    if (doc == null) return;

    // Refresh URL from storagePath to avoid stale tokens
    String? url = doc.url;
    if (doc.storagePath != null) {
      final freshUrl = await PhotoService().getFreshDownloadUrl(doc.storagePath!);
      if (freshUrl != null) {
        url = freshUrl;
        doc.url = freshUrl;
      }
    }

    if (url == null || !mounted) return;

    if (doc.isImage) {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => _ReceiptImageViewer(
            url: url!,
            title: doc.fileName ?? context.l10n.receipt,
          ),
        ),
      );
    } else {
      launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication);
    }
  }

  String _getContentType(String extension) {
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(context.l10n.attention),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text(context.l10n.ok),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.checkmark_circle_fill,
              color: CupertinoColors.systemGreen,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(context.l10n.ok),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

/// Full-screen receipt image viewer
class _ReceiptImageViewer extends StatelessWidget {
  final String url;
  final String title;

  const _ReceiptImageViewer({
    required this.url,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black.withValues(alpha: 0.8),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child:
              const Icon(CupertinoIcons.back, color: CupertinoColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        middle: Text(
          title,
          style: const TextStyle(color: CupertinoColors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      child: SafeArea(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 3.0,
          child: Center(
            child: Image.network(
              url,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const CupertinoActivityIndicator();
              },
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  CupertinoIcons.exclamationmark_triangle,
                  color: CupertinoColors.systemGrey,
                  size: 48,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
