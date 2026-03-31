import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/financial_account_store.dart';
import 'package:praticos/models/financial_account.dart';
import 'package:praticos/services/format_service.dart';

class FinancialAccountFormScreen extends StatefulWidget {
  const FinancialAccountFormScreen({super.key});

  @override
  State<FinancialAccountFormScreen> createState() =>
      _FinancialAccountFormScreenState();
}

class _FinancialAccountFormScreenState
    extends State<FinancialAccountFormScreen> {
  final FinancialAccountStore _accountStore = FinancialAccountStore();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _initialBalanceController =
      TextEditingController();

  FinancialAccount? _account;
  bool _isEditing = false;
  FinancialAccountType _selectedType = FinancialAccountType.bank;
  bool _isDefault = false;
  bool _isSaving = false;
  bool _didLoadArgs = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didLoadArgs) {
      _didLoadArgs = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is FinancialAccount) {
        _account = args;
        _isEditing = true;
        _nameController.text = args.name ?? '';
        _selectedType = args.type ?? FinancialAccountType.bank;
        _isDefault = args.isDefault ?? false;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _initialBalanceController.dispose();
    super.dispose();
  }

  String _typeLabel(FinancialAccountType type) {
    switch (type) {
      case FinancialAccountType.bank:
        return context.l10n.bankAccount;
      case FinancialAccountType.cash:
        return context.l10n.cashBox;
      case FinancialAccountType.creditCard:
        return context.l10n.creditCard;
      case FinancialAccountType.digitalWallet:
        return context.l10n.digitalWallet;
    }
  }

  double _parseAmount(String value) {
    try {
      final parsed = FormatService().currencyFormat.parse(value);
      return parsed.toDouble();
    } catch (e) {
      // Try simple parse as fallback
      final cleaned = value.replaceAll(RegExp(r'[^\d.,\-]'), '');
      final normalized = cleaned.replaceAll('.', '').replaceAll(',', '.');
      return double.tryParse(normalized) ?? 0;
    }
  }

  void _showTypeSelector() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: FinancialAccountType.values.map((type) {
          return CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _selectedType = type);
              Navigator.pop(ctx);
            },
            child: Text(_typeLabel(type)),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.l10n.cancel),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      if (_isEditing && _account != null) {
        _account!.name = name;
        _account!.type = _selectedType;
        _account!.isDefault = _isDefault;
        await _accountStore.updateAccount(_account!);
      } else {
        final account = FinancialAccount()
          ..name = name
          ..type = _selectedType
          ..initialBalance = _parseAmount(_initialBalanceController.text)
          ..isDefault = _isDefault;
        await _accountStore.createAccount(account);
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _confirmDeactivate() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(context.l10n.deactivateAccount),
        content: Text(context.l10n.deactivateAccountConfirmation),
        actions: [
          CupertinoDialogAction(
            child: Text(context.l10n.cancel),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(context.l10n.deactivateAccount),
            onPressed: () async {
              Navigator.pop(ctx);
              if (_account != null) {
                _account!.active = false;
                await _accountStore.updateAccount(_account!);
                if (mounted) {
                  Navigator.pop(context);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor =
        CupertinoColors.systemGroupedBackground.resolveFrom(context);
    final title =
        _isEditing ? context.l10n.editAccount : context.l10n.newAccount;

    return CupertinoPageScaffold(
      backgroundColor: bgColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(title),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Text(context.l10n.cancel),
          onPressed: () => Navigator.pop(context),
        ),
        trailing: _isSaving
            ? const CupertinoActivityIndicator()
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _nameController.text.trim().isEmpty ? null : _save,
                child: Text(
                  context.l10n.save,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 16),

            // Form fields
            CupertinoListSection.insetGrouped(
              children: [
                // Name
                CupertinoTextFormFieldRow(
                  controller: _nameController,
                  prefix: Text(context.l10n.name),
                  placeholder: 'Ex: Conta Corrente Itau',
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                ),

                // Type selector
                CupertinoListTile(
                  title: Text(context.l10n.type),
                  additionalInfo: Text(_typeLabel(_selectedType)),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _showTypeSelector,
                ),

                // Initial balance (create mode only)
                if (!_isEditing)
                  CupertinoTextFormFieldRow(
                    controller: _initialBalanceController,
                    prefix: Text(context.l10n.initialBalance),
                    placeholder: '0,00',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),

                // Default account toggle
                CupertinoListTile(
                  title: Text(context.l10n.defaultAccount),
                  trailing: CupertinoSwitch(
                    value: _isDefault,
                    onChanged: (value) => setState(() => _isDefault = value),
                  ),
                ),
              ],
            ),

            // Deactivate button (edit mode only)
            if (_isEditing) ...[
              const SizedBox(height: 32),
              CupertinoListSection.insetGrouped(
                children: [
                  CupertinoListTile(
                    title: Text(
                      context.l10n.deactivateAccount,
                      style: const TextStyle(
                        color: CupertinoColors.destructiveRed,
                      ),
                    ),
                    onTap: _confirmDeactivate,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
