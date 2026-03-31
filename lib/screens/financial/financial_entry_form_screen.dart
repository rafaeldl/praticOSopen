import 'package:flutter/cupertino.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/financial_account_store.dart';
import 'package:praticos/mobx/financial_entry_store.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/financial_account.dart';
import 'package:praticos/models/financial_entry.dart';
import 'package:praticos/screens/financial/widgets/category_picker_grid.dart';
import 'package:praticos/services/format_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Form screen for creating a financial entry (expense or income).
///
/// The direction (payable/receivable) is determined by route arguments,
/// not by a form field.
class FinancialEntryFormScreen extends StatefulWidget {
  const FinancialEntryFormScreen({super.key});

  @override
  State<FinancialEntryFormScreen> createState() =>
      _FinancialEntryFormScreenState();
}

class _FinancialEntryFormScreenState extends State<FinancialEntryFormScreen> {
  final FinancialEntryStore _entryStore = FinancialEntryStore();
  final FinancialAccountStore _accountStore = FinancialAccountStore();

  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _direction = 'payable';
  DateTime _dueDate = DateTime.now();
  String? _selectedCategory;
  FinancialAccount? _selectedAccount;
  bool _isInstallment = false;
  int _installmentCount = 2;
  bool _isRecurring = false;
  bool _showRecurrenceOptions = false;
  String _recurrenceFrequency = 'monthly';
  int _recurrenceInterval = 1;
  DateTime? _recurrenceEndDate;
  bool _showDetails = false;
  bool _isSaving = false;
  String? _companyId;
  Customer? _selectedCustomer;

  @override
  void initState() {
    super.initState();
    _loadCompanyAndAccounts();
  }

  Future<void> _loadCompanyAndAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    _companyId = prefs.getString('companyId');
    if (mounted) {
      _accountStore.load();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args['direction'] != null) {
      _direction = args['direction'] as String;
      if (!_isPayable) _showDetails = true;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _supplierController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isPayable => _direction == 'payable';

  FinancialEntryDirection get _entryDirection =>
      _isPayable ? FinancialEntryDirection.payable : FinancialEntryDirection.receivable;

  double _parseAmount(String value) {
    if (value.isEmpty) return 0;
    try {
      return FormatService().currencyFormat.parse(value).toDouble();
    } catch (e) {
      return double.tryParse(value.replaceAll(',', '.')) ?? 0;
    }
  }

  void _selectDefaultAccount(List<FinancialAccount?> accounts) {
    if (_selectedAccount != null) return;
    final active = accounts.where((a) => a != null && (a.active ?? false)).cast<FinancialAccount>().toList();
    if (active.isEmpty) return;
    final defaultAccount = active.firstWhere(
      (a) => a.isDefault == true,
      orElse: () => active.first,
    );
    _selectedAccount = defaultAccount;
  }

  void _showAccountPicker(List<FinancialAccount> accounts) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(context.l10n.accounts),
        actions: accounts
            .map(
              (account) => CupertinoActionSheetAction(
                onPressed: () {
                  setState(() => _selectedAccount = account);
                  Navigator.pop(ctx);
                },
                child: Text(account.name ?? ''),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.l10n.cancel),
        ),
      ),
    );
  }

  void _showDatePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 280,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(context.l10n.cancel),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(context.l10n.confirm),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _dueDate,
                onDateTimeChanged: (date) {
                  setState(() => _dueDate = date);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectCustomer() {
    Navigator.pushNamed(
      context,
      '/customer_list',
      arguments: {'order': null},
    ).then((result) {
      if (result != null && mounted) {
        setState(() => _selectedCustomer = result as Customer);
      }
    });
  }

  Future<void> _save() async {
    final amount = _parseAmount(_amountController.text);
    if (amount <= 0) return;

    setState(() => _isSaving = true);

    try {
      final entry = FinancialEntry()
        ..direction = _entryDirection
        ..description = _descriptionController.text.trim()
        ..amount = amount
        ..dueDate = _dueDate
        ..category = _selectedCategory
        ..accountId = _selectedAccount?.id
        ..account = _selectedAccount?.toAggr()
        ..supplier = _isPayable ? _supplierController.text.trim() : null
        ..customer = !_isPayable && _selectedCustomer != null
            ? _selectedCustomer!.toAggr()
            : null
        ..notes = _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null;

      if (_isRecurring && !_isInstallment) {
        final freq = _showRecurrenceOptions ? _recurrenceFrequency : 'monthly';
        final intv = _showRecurrenceOptions ? _recurrenceInterval : 1;
        final nextDue = _calculateNextDueDate(_dueDate, freq, intv);

        entry.recurrence = FinancialRecurrence()
          ..frequency = freq
          ..interval = intv
          ..active = true
          ..nextDueDate = nextDue
          ..endDate = _showRecurrenceOptions ? _recurrenceEndDate : null;
      }

      if (_isInstallment && _installmentCount > 1) {
        await _entryStore.createInstallments(entry, _installmentCount);
      } else {
        await _entryStore.createEntry(entry);
      }

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor =
        CupertinoColors.systemGroupedBackground.resolveFrom(context);
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryLabelColor =
        CupertinoColors.secondaryLabel.resolveFrom(context);

    final title = _isPayable ? context.l10n.newExpense : context.l10n.newIncome;
    final saveLabel = _isPayable
        ? context.l10n.registerExpense
        : context.l10n.registerIncome;

    return CupertinoPageScaffold(
      backgroundColor: bgColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(title),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        trailing: _isSaving
            ? const CupertinoActivityIndicator()
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _save,
                child: Text(
                  context.l10n.save,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Essential fields
                  CupertinoListSection.insetGrouped(
                    children: [
                      // Description
                      CupertinoTextFormFieldRow(
                        controller: _descriptionController,
                        prefix: Text(context.l10n.description),
                        placeholder: 'Ex: Material eletrico',
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      // Value
                      CupertinoTextFormFieldRow(
                        controller: _amountController,
                        prefix: Text(context.l10n.value),
                        placeholder: '0,00',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        autofocus: true,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: labelColor,
                        ),
                      ),
                      // Due date
                      GestureDetector(
                        onTap: _showDatePicker,
                        behavior: HitTestBehavior.opaque,
                        child: CupertinoListTile(
                          title: Text(context.l10n.dueDate),
                          additionalInfo: Text(
                            FormatService().formatDate(_dueDate),
                            style: TextStyle(color: secondaryLabelColor),
                          ),
                          trailing: const CupertinoListTileChevron(),
                        ),
                      ),
                    ],
                  ),

                  // Category section
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    child: Text(
                      context.l10n.category,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: secondaryLabelColor,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _companyId != null
                        ? CategoryPickerGrid(
                            fieldType: _isPayable
                                ? 'expenseCategory'
                                : 'incomeCategory',
                            selectedCategory: _selectedCategory,
                            companyId: _companyId!,
                            onCategorySelected: (category) {
                              setState(() => _selectedCategory = category);
                            },
                          )
                        : const SizedBox.shrink(),
                  ),

                  // Account section
                  Observer(
                    builder: (_) {
                      final accounts =
                          _accountStore.accountList?.value ?? [];
                      final activeAccounts = accounts
                          .where((a) =>
                              a != null && (a.active ?? false))
                          .cast<FinancialAccount>()
                          .toList();

                      _selectDefaultAccount(accounts);

                      return CupertinoListSection.insetGrouped(
                        header: Text(context.l10n.accounts),
                        children: [
                          GestureDetector(
                            onTap: activeAccounts.isNotEmpty
                                ? () => _showAccountPicker(activeAccounts)
                                : null,
                            behavior: HitTestBehavior.opaque,
                            child: CupertinoListTile(
                              title: Text(context.l10n.accounts),
                              additionalInfo: Text(
                                _selectedAccount?.name ?? '',
                                style:
                                    TextStyle(color: secondaryLabelColor),
                              ),
                              trailing: const CupertinoListTileChevron(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  // Installment toggle
                  CupertinoListSection.insetGrouped(
                    children: [
                      CupertinoListTile(
                        title: Text(context.l10n.installmentCount),
                        trailing: CupertinoSwitch(
                          value: _isInstallment,
                          onChanged: (val) {
                            setState(() {
                              _isInstallment = val;
                              if (val) _isRecurring = false;
                            });
                          },
                        ),
                      ),
                      if (_isInstallment)
                        _buildInstallmentStepper(context, labelColor,
                            secondaryLabelColor),
                    ],
                  ),

                  // Recurring toggle (only when not in installment mode)
                  if (!_isInstallment)
                    CupertinoListSection.insetGrouped(
                      children: [
                        CupertinoListTile(
                          title: Text(context.l10n.repeatMonthly),
                          trailing: CupertinoSwitch(
                            value: _isRecurring,
                            onChanged: (val) {
                              setState(() {
                                _isRecurring = val;
                                if (!val) _showRecurrenceOptions = false;
                              });
                            },
                          ),
                        ),
                        if (_isRecurring && !_showRecurrenceOptions)
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            onPressed: () =>
                                setState(() => _showRecurrenceOptions = true),
                            child: Row(
                              children: [
                                const Icon(CupertinoIcons.slider_horizontal_3,
                                    size: 16),
                                const SizedBox(width: 4),
                                Text(context.l10n.customize),
                              ],
                            ),
                          ),
                        if (_isRecurring && _showRecurrenceOptions) ...[
                          // Frequency picker
                          GestureDetector(
                            onTap: _showFrequencyPicker,
                            behavior: HitTestBehavior.opaque,
                            child: CupertinoListTile(
                              title: Text(context.l10n.frequency),
                              additionalInfo: Text(
                                _frequencyLabel(context),
                                style:
                                    TextStyle(color: secondaryLabelColor),
                              ),
                              trailing: const CupertinoListTileChevron(),
                            ),
                          ),
                          // Interval stepper
                          _buildIntervalStepper(
                              context, labelColor, secondaryLabelColor),
                          // End date picker (optional)
                          GestureDetector(
                            onTap: _showEndDatePicker,
                            behavior: HitTestBehavior.opaque,
                            child: CupertinoListTile(
                              title: Text(context.l10n.endDate),
                              additionalInfo: Text(
                                _recurrenceEndDate != null
                                    ? FormatService()
                                        .formatDate(_recurrenceEndDate!)
                                    : '-',
                                style:
                                    TextStyle(color: secondaryLabelColor),
                              ),
                              trailing: const CupertinoListTileChevron(),
                            ),
                          ),
                        ],
                      ],
                    ),

                  // Expandable details
                  if (!_showDetails)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () =>
                            setState(() => _showDetails = true),
                        child: Row(
                          children: [
                            const Icon(CupertinoIcons.add, size: 16),
                            const SizedBox(width: 4),
                            Text(context.l10n.addDetails),
                          ],
                        ),
                      ),
                    ),

                  if (_showDetails)
                    CupertinoListSection.insetGrouped(
                      children: [
                        if (_isPayable)
                          CupertinoTextFormFieldRow(
                            controller: _supplierController,
                            prefix: Text(context.l10n.supplier),
                            placeholder: context.l10n.supplier,
                            textCapitalization:
                                TextCapitalization.sentences,
                          )
                        else
                          GestureDetector(
                            onTap: _selectCustomer,
                            behavior: HitTestBehavior.opaque,
                            child: CupertinoListTile(
                              title: Text(context.l10n.customer),
                              additionalInfo: Text(
                                _selectedCustomer?.name ?? '',
                                style: TextStyle(
                                    color: secondaryLabelColor),
                              ),
                              trailing:
                                  const CupertinoListTileChevron(),
                            ),
                          ),
                        CupertinoTextFormFieldRow(
                          controller: _notesController,
                          prefix: Text(context.l10n.notes),
                          placeholder: context.l10n.notes,
                          maxLines: 3,
                          textCapitalization:
                              TextCapitalization.sentences,
                        ),
                      ],
                    ),

                  // Bottom save button
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      child: CupertinoButton.filled(
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving
                            ? const CupertinoActivityIndicator(
                                color: CupertinoColors.white)
                            : Text(saveLabel),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _frequencyLabel(BuildContext context) {
    switch (_recurrenceFrequency) {
      case 'daily':
        return context.l10n.frequencyDaily;
      case 'weekly':
        return context.l10n.frequencyWeekly;
      case 'monthly':
        return context.l10n.frequencyMonthly;
      case 'yearly':
        return context.l10n.frequencyYearly;
      default:
        return context.l10n.frequencyMonthly;
    }
  }

  void _showFrequencyPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(context.l10n.frequency),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _recurrenceFrequency = 'daily');
              Navigator.pop(ctx);
            },
            child: Text(context.l10n.frequencyDaily),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _recurrenceFrequency = 'weekly');
              Navigator.pop(ctx);
            },
            child: Text(context.l10n.frequencyWeekly),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _recurrenceFrequency = 'monthly');
              Navigator.pop(ctx);
            },
            child: Text(context.l10n.frequencyMonthly),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _recurrenceFrequency = 'yearly');
              Navigator.pop(ctx);
            },
            child: Text(context.l10n.frequencyYearly),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.l10n.cancel),
        ),
      ),
    );
  }

  void _showEndDatePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 280,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    onPressed: () {
                      setState(() => _recurrenceEndDate = null);
                      Navigator.pop(ctx);
                    },
                    child: Text(context.l10n.cancel),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(context.l10n.confirm),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime:
                    _recurrenceEndDate ?? _dueDate.add(const Duration(days: 365)),
                minimumDate: _dueDate,
                onDateTimeChanged: (date) {
                  setState(() => _recurrenceEndDate = date);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  DateTime _calculateNextDueDate(
      DateTime current, String frequency, int interval) {
    switch (frequency) {
      case 'daily':
        return current.add(Duration(days: interval));
      case 'weekly':
        return current.add(Duration(days: 7 * interval));
      case 'monthly':
        return DateTime(current.year, current.month + interval, current.day);
      case 'yearly':
        return DateTime(current.year + interval, current.month, current.day);
      default:
        return DateTime(current.year, current.month + interval, current.day);
    }
  }

  Widget _buildIntervalStepper(
    BuildContext context,
    Color labelColor,
    Color secondaryLabelColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            context.l10n.interval,
            style: TextStyle(color: labelColor),
          ),
          const Spacer(),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(32),
            onPressed: _recurrenceInterval > 1
                ? () => setState(() => _recurrenceInterval--)
                : null,
            child: const Icon(CupertinoIcons.minus_circle, size: 28),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '$_recurrenceInterval',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(32),
            onPressed: _recurrenceInterval < 12
                ? () => setState(() => _recurrenceInterval++)
                : null,
            child: const Icon(CupertinoIcons.plus_circle, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallmentStepper(
    BuildContext context,
    Color labelColor,
    Color secondaryLabelColor,
  ) {
    final amount = _parseAmount(_amountController.text);
    final perInstallment =
        amount > 0 && _installmentCount > 1 ? amount / _installmentCount : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(32),
            onPressed: _installmentCount > 2
                ? () => setState(() => _installmentCount--)
                : null,
            child: const Icon(CupertinoIcons.minus_circle, size: 28),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${_installmentCount}x',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(32),
            onPressed: _installmentCount < 12
                ? () => setState(() => _installmentCount++)
                : null,
            child: const Icon(CupertinoIcons.plus_circle, size: 28),
          ),
          const Spacer(),
          if (perInstallment > 0)
            Text(
              FormatService().formatCurrency(perInstallment),
              style: TextStyle(
                fontSize: 15,
                color: secondaryLabelColor,
              ),
            ),
        ],
      ),
    );
  }
}
