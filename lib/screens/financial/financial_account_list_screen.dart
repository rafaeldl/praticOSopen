import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/financial_account_store.dart';
import 'package:praticos/mobx/financial_payment_store.dart';
import 'package:praticos/models/financial_account.dart';
import 'package:praticos/screens/financial/widgets/transfer_sheet.dart';
import 'package:praticos/services/format_service.dart';

class FinancialAccountListScreen extends StatefulWidget {
  const FinancialAccountListScreen({super.key});

  @override
  State<FinancialAccountListScreen> createState() =>
      _FinancialAccountListScreenState();
}

class _FinancialAccountListScreenState
    extends State<FinancialAccountListScreen> {
  final FinancialAccountStore _accountStore = FinancialAccountStore();
  final FinancialPaymentStore _paymentStore = FinancialPaymentStore();
  static const _hideValuesKey = 'financial_hide_values';
  bool _hideValues = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _accountStore.load();
      }
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _hideValues = prefs.getBool(_hideValuesKey) ?? false;
      });
    }
  }

  Future<void> _toggleHideValues() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hideValues = !_hideValues;
    });
    await prefs.setBool(_hideValuesKey, _hideValues);
  }

  String _formatValue(double value) {
    if (_hideValues) return '\u2022\u2022\u2022\u2022';
    return FormatService().formatCurrency(value);
  }

  IconData _iconForType(FinancialAccountType? type) {
    switch (type) {
      case FinancialAccountType.bank:
        return CupertinoIcons.building_2_fill;
      case FinancialAccountType.cash:
        return CupertinoIcons.money_dollar;
      case FinancialAccountType.creditCard:
        return CupertinoIcons.creditcard;
      case FinancialAccountType.digitalWallet:
        return CupertinoIcons.device_phone_portrait;
      default:
        return CupertinoIcons.money_dollar;
    }
  }

  Color _colorForType(FinancialAccountType? type) {
    switch (type) {
      case FinancialAccountType.bank:
        return CupertinoColors.activeBlue;
      case FinancialAccountType.cash:
        return CupertinoColors.systemGreen;
      case FinancialAccountType.creditCard:
        return CupertinoColors.systemOrange;
      case FinancialAccountType.digitalWallet:
        return CupertinoColors.systemPurple;
      default:
        return CupertinoColors.systemGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor =
        CupertinoColors.systemGroupedBackground.resolveFrom(context);
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryLabelColor =
        CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      backgroundColor: bgColor,
      child: Material(
        type: MaterialType.transparency,
        child: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: Text(context.l10n.accounts),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Icon(CupertinoIcons.add),
                onPressed: () {
                  Navigator.pushNamed(context, '/financial_account_form')
                      .then((_) {
                    // Reload on return
                    _accountStore.load();
                  });
                },
              ),
            ),

            // Total balance header
            SliverToBoxAdapter(
              child: Observer(
                builder: (_) {
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.totalBalance,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: secondaryLabelColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatValue(_accountStore.totalBalance),
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: labelColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _toggleHideValues,
                          behavior: HitTestBehavior.opaque,
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: Icon(
                                _hideValues
                                    ? CupertinoIcons.eye_slash
                                    : CupertinoIcons.eye,
                                color: secondaryLabelColor,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Account list
            Observer(
              builder: (_) => _buildAccountList(context),
            ),

            // Bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountList(BuildContext context) {
    final secondaryLabelColor =
        CupertinoColors.secondaryLabel.resolveFrom(context);

    if (_accountStore.accountList == null) {
      return const SliverFillRemaining(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    if (_accountStore.accountList!.hasError) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.exclamationmark_circle,
                  size: 48, color: CupertinoColors.systemRed),
              const SizedBox(height: 16),
              Text(context.l10n.errorLoading),
            ],
          ),
        ),
      );
    }

    final rawData = _accountStore.accountList!.value;
    if (rawData == null) {
      return const SliverFillRemaining(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    final accounts = rawData
        .whereType<FinancialAccount>()
        .where((a) => a.active ?? false)
        .toList();

    if (accounts.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.creditcard,
                    size: 64, color: secondaryLabelColor),
                const SizedBox(height: 16),
                Text(
                  context.l10n.noAccountsRegistered,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.addFirstAccount,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: secondaryLabelColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: CupertinoListSection.insetGrouped(
        children: accounts.map((account) {
          final balance = account.currentBalance ?? 0;
          final balanceColor = balance >= 0
              ? CupertinoColors.systemGreen
              : CupertinoColors.systemRed;
          final accountColor = _colorForType(account.type);

          return GestureDetector(
            onLongPress: () => _showAccountActions(context, account, accounts),
            child: Dismissible(
              key: ValueKey(account.id),
              direction: DismissDirection.startToEnd,
              confirmDismiss: (_) async {
                _showTransferSheet(context, account, accounts);
                return false;
              },
              background: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 20),
                color: CupertinoColors.activeBlue,
                child: const Icon(
                  CupertinoIcons.arrow_right_arrow_left,
                  color: CupertinoColors.white,
                ),
              ),
              child: CupertinoListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accountColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      _iconForType(account.type),
                      size: 18,
                      color: accountColor,
                    ),
                  ),
                ),
                title: Text(account.name ?? ''),
                subtitle: Text(
                  _formatValue(balance),
                  style: TextStyle(color: balanceColor),
                ),
                trailing: const CupertinoListTileChevron(),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/financial_account_form',
                    arguments: account,
                  ).then((_) {
                    _accountStore.load();
                  });
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showTransferSheet(
    BuildContext context,
    FinancialAccount fromAccount,
    List<FinancialAccount> allAccounts,
  ) {
    TransferSheet.show(
      context,
      fromAccount: fromAccount,
      accounts: allAccounts,
      onTransfer: (toAccountId, amount) async {
        final toAccount = allAccounts.firstWhere((a) => a.id == toAccountId);
        await _paymentStore.transfer(
          fromAccountId: fromAccount.id!,
          fromAccount: fromAccount.toAggr(),
          toAccountId: toAccountId,
          toAccount: toAccount.toAggr(),
          amount: amount,
        );
        if (mounted) {
          _accountStore.load();
          _showSnackBar(context, context.l10n.transferSuccess);
        }
      },
    );
  }

  void _showAccountActions(
    BuildContext context,
    FinancialAccount account,
    List<FinancialAccount> allAccounts,
  ) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showTransferSheet(context, account, allAccounts);
            },
            child: Text(context.l10n.transfer),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _verifyBalance(context, account);
            },
            child: Text(context.l10n.verifyBalance),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(context.l10n.cancel),
        ),
      ),
    );
  }

  Future<void> _verifyBalance(
    BuildContext context,
    FinancialAccount account,
  ) async {
    final realBalance =
        await _accountStore.calculateRealBalance(account.id!);
    final currentBalance = account.currentBalance ?? 0;
    final formatService = FormatService();

    if (!mounted) return;

    if ((realBalance - currentBalance).abs() < 0.01) {
      // Balances match
      _showSnackBar(context, context.l10n.balanceMatches);
      return;
    }

    // Balances diverge - show correction dialog
    final formattedRegistered = formatService.formatCurrency(currentBalance);
    final formattedReal = formatService.formatCurrency(realBalance);

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(context.l10n.balanceMismatch),
        content: Column(
          children: [
            const SizedBox(height: 8),
            Text(context.l10n.registeredBalance(formattedRegistered)),
            const SizedBox(height: 4),
            Text(context.l10n.realBalance(formattedReal)),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _accountStore.reconcileBalance(
                account.id!,
                realBalance,
              );
              if (mounted) {
                _accountStore.load();
                _showSnackBar(context, context.l10n.balanceCorrected);
              }
            },
            child: Text(context.l10n.correctBalance),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    // Use an overlay-based toast since we are in Cupertino context
    final overlay = Navigator.of(context).overlay;
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: MediaQuery.of(context).padding.bottom + 60,
        left: 16,
        right: 16,
        child: Center(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: CupertinoColors.label.resolveFrom(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              message,
              style: TextStyle(
                color: CupertinoColors.systemBackground
                    .resolveFrom(context),
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () {
      entry.remove();
    });
  }
}
