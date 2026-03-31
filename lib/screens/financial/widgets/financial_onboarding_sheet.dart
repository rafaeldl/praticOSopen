import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/financial_account_store.dart';
import 'package:praticos/models/financial_account.dart';
import 'package:praticos/services/format_service.dart';

/// A 3-step onboarding sheet for first-time financial module setup.
///
/// Step 1: Choose account type (cash, bank, digital wallet)
/// Step 2: Enter initial balance
/// Step 3: Success confirmation
class FinancialOnboardingSheet extends StatefulWidget {
  final FinancialAccountStore accountStore;
  final VoidCallback onComplete;

  const FinancialOnboardingSheet({
    super.key,
    required this.accountStore,
    required this.onComplete,
  });

  @override
  State<FinancialOnboardingSheet> createState() =>
      _FinancialOnboardingSheetState();
}

class _FinancialOnboardingSheetState extends State<FinancialOnboardingSheet> {
  int _step = 0;
  FinancialAccount? _createdAccount;
  final TextEditingController _balanceController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _selectAccountType(
    FinancialAccountType type,
    String name,
  ) async {
    setState(() => _isSaving = true);
    try {
      final account = FinancialAccount()
        ..type = type
        ..name = name
        ..initialBalance = 0
        ..currentBalance = 0
        ..active = true
        ..isDefault = true;

      await widget.accountStore.createAccount(account);
      _createdAccount = account;

      if (mounted) {
        setState(() {
          _step = 1;
          _isSaving = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  double _parseBalance(String value) {
    if (value.isEmpty) return 0;
    try {
      return FormatService().currencyFormat.parse(value).toDouble();
    } catch (_) {
      return double.tryParse(value.replaceAll(',', '.')) ?? 0;
    }
  }

  Future<void> _saveBalance() async {
    if (_createdAccount == null) return;
    setState(() => _isSaving = true);
    try {
      final balance = _parseBalance(_balanceController.text);
      _createdAccount!.initialBalance = balance;
      _createdAccount!.currentBalance = balance;
      await widget.accountStore.updateAccount(_createdAccount!);

      if (mounted) {
        setState(() {
          _step = 2;
          _isSaving = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor =
        CupertinoColors.systemGroupedBackground.resolveFrom(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey3.resolveFrom(context),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            Expanded(
              child: _buildStep(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        return _buildStep1(context);
      case 1:
        return _buildStep2(context);
      case 2:
        return _buildStep3(context);
      default:
        return const SizedBox.shrink();
    }
  }

  /// Step 1: Choose account type
  Widget _buildStep1(BuildContext context) {
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryLabelColor =
        CupertinoColors.secondaryLabel.resolveFrom(context);

    if (_isSaving) {
      return const Center(child: CupertinoActivityIndicator());
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Text(
            context.l10n.howDoYouReceivePayments,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: labelColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _buildAccountTypeCard(
            context,
            icon: CupertinoIcons.money_dollar_circle,
            label: context.l10n.cashBox,
            onTap: () => _selectAccountType(
              FinancialAccountType.cash,
              context.l10n.cashBox,
            ),
          ),
          const SizedBox(height: 12),
          _buildAccountTypeCard(
            context,
            icon: CupertinoIcons.building_2_fill,
            label: context.l10n.bankAccount,
            onTap: () => _selectAccountType(
              FinancialAccountType.bank,
              context.l10n.bankAccount,
            ),
          ),
          const SizedBox(height: 12),
          _buildAccountTypeCard(
            context,
            icon: CupertinoIcons.device_phone_portrait,
            label: context.l10n.digitalWallet,
            onTap: () => _selectAccountType(
              FinancialAccountType.digitalWallet,
              context.l10n.digitalWallet,
            ),
          ),
          const Spacer(),
          Text(
            context.l10n.setupFinancialDescription,
            style: TextStyle(
              fontSize: 13,
              color: secondaryLabelColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildAccountTypeCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final cardColor =
        CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);
    final labelColor = CupertinoColors.label.resolveFrom(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: CupertinoColors.activeBlue),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: labelColor,
              ),
            ),
            const Spacer(),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: CupertinoColors.systemGrey.resolveFrom(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Step 2: Enter initial balance
  Widget _buildStep2(BuildContext context) {
    final labelColor = CupertinoColors.label.resolveFrom(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Text(
            context.l10n.howMuchToday,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: labelColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          CupertinoTextField(
            controller: _balanceController,
            placeholder: '0,00',
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: labelColor,
            ),
            decoration: const BoxDecoration(),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              onPressed: _isSaving ? null : _saveBalance,
              child: _isSaving
                  ? const CupertinoActivityIndicator(
                      color: CupertinoColors.white)
                  : Text(context.l10n.continue_),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Step 3: Success
  Widget _buildStep3(BuildContext context) {
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryLabelColor =
        CupertinoColors.secondaryLabel.resolveFrom(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.checkmark_circle_fill,
            size: 64,
            color: CupertinoColors.systemGreen,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.allSet,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.registerFirst,
            style: TextStyle(
              fontSize: 15,
              color: secondaryLabelColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              onPressed: widget.onComplete,
              child: Text(context.l10n.finish),
            ),
          ),
        ],
      ),
    );
  }
}
