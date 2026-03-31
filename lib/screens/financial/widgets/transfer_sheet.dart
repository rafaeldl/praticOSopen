import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/financial_account.dart';
import 'package:praticos/services/format_service.dart';

/// Half-sheet for transferring money between financial accounts.
class TransferSheet extends StatefulWidget {
  final FinancialAccount fromAccount;
  final List<FinancialAccount> accounts;
  final Function(String toAccountId, double amount) onTransfer;

  const TransferSheet({
    super.key,
    required this.fromAccount,
    required this.accounts,
    required this.onTransfer,
  });

  /// Show the transfer sheet as a modal popup.
  static Future<void> show(
    BuildContext context, {
    required FinancialAccount fromAccount,
    required List<FinancialAccount> accounts,
    required Function(String toAccountId, double amount) onTransfer,
  }) {
    return showCupertinoModalPopup(
      context: context,
      builder: (context) => TransferSheet(
        fromAccount: fromAccount,
        accounts: accounts,
        onTransfer: onTransfer,
      ),
    );
  }

  @override
  State<TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<TransferSheet> {
  FinancialAccount? _selectedDestination;
  final TextEditingController _amountController = TextEditingController();
  double _amount = 0;
  bool _isLoading = false;

  List<FinancialAccount> get _destinationAccounts {
    return widget.accounts
        .where((a) =>
            a.id != widget.fromAccount.id && (a.active ?? false))
        .toList();
  }

  bool get _isValid =>
      _amount > 0 &&
      _selectedDestination != null &&
      _selectedDestination!.id != widget.fromAccount.id;

  void _showDestinationPicker() {
    final destinations = _destinationAccounts;
    if (destinations.isEmpty) return;

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(context.l10n.selectDestinationAccount),
        actions: destinations.map((account) {
          final balance = account.currentBalance ?? 0;
          final formattedBalance = FormatService().formatCurrency(balance);
          return CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _selectedDestination = account);
              Navigator.of(ctx).pop();
            },
            child: Text('${account.name ?? ''} ($formattedBalance)'),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(context.l10n.cancel),
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    if (!_isValid || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      widget.onTransfer(_selectedDestination!.id!, _amount);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor =
        CupertinoColors.systemGroupedBackground.resolveFrom(context);
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryLabelColor =
        CupertinoColors.secondaryLabel.resolveFrom(context);
    final separatorColor = CupertinoColors.separator.resolveFrom(context);

    final fromBalance = widget.fromAccount.currentBalance ?? 0;
    final fromName = widget.fromAccount.name ?? '';
    final formattedFromBalance = FormatService().formatCurrency(fromBalance);

    return Container(
      constraints: const BoxConstraints(minHeight: 280, maxHeight: 440),
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
                context.l10n.transfer,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
              const SizedBox(height: 16),

              // Source account (read-only)
              _buildField(
                context,
                label: context.l10n.transferFrom(''),
                  child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground
                        .resolveFrom(context)
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: separatorColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$fromName ($formattedFromBalance)',
                          style: TextStyle(
                            fontSize: 15,
                            color: secondaryLabelColor,
                          ),
                        ),
                      ),
                      Icon(
                        CupertinoIcons.lock,
                        size: 14,
                        color: secondaryLabelColor,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Destination account
              _buildField(
                context,
                label: context.l10n.transferTo,
                child: GestureDetector(
                  onTap: _showDestinationPicker,
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
                            _selectedDestination?.name ??
                                context.l10n.selectDestinationAccount,
                            style: TextStyle(
                              fontSize: 15,
                              color: _selectedDestination != null
                                  ? labelColor
                                  : secondaryLabelColor,
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

              // Amount
              _buildField(
                context,
                label: context.l10n.value,
                child: CupertinoTextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  placeholder: '0,00',
                  onChanged: (value) {
                    final parsed = double.tryParse(
                      value.replaceAll(',', '.'),
                    );
                    setState(() => _amount = parsed ?? 0);
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Transfer button
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  onPressed: _isValid && !_isLoading ? _confirm : null,
                  borderRadius: BorderRadius.circular(12),
                  child: _isLoading
                      ? const CupertinoActivityIndicator(
                          color: CupertinoColors.white,
                        )
                      : Text(
                          context.l10n.transfer,
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
}
