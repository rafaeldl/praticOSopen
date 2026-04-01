import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/financial_account_store.dart';
import 'package:praticos/mobx/financial_entry_store.dart';
import 'package:praticos/mobx/financial_payment_store.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/financial_account.dart';
import 'package:praticos/models/financial_entry.dart';
import 'package:praticos/models/financial_payment.dart';
import 'package:praticos/models/payment_method.dart';
import 'package:praticos/screens/financial/widgets/category_picker_grid.dart';
import 'package:praticos/screens/financial/widgets/payment_confirmation_sheet.dart';
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
  final FinancialPaymentStore _paymentStore = FinancialPaymentStore();

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

  // "Already paid" toggle (Fix B)
  bool _markAsPaid = false;
  PaymentMethod _paymentMethod = PaymentMethod.pix;
  DateTime _paymentDate = DateTime.now();

  // Edit mode (Fix C)
  FinancialEntry? _existingEntry;
  bool get _isEditing => _existingEntry != null;
  bool get _isReadOnly =>
      _existingEntry?.status == FinancialEntryStatus.cancelled;
  bool get _isPaid => _existingEntry?.status == FinancialEntryStatus.paid;
  bool _isLoading = false;
  List<FinancialPayment> _linkedPayments = [];

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
    if (args != null) {
      if (args['direction'] != null) {
        _direction = args['direction'] as String;
        if (!_isPayable) _showDetails = true;
      }
      if (args['entryId'] != null && _existingEntry == null && !_isLoading) {
        _loadExistingEntry(args['entryId'] as String);
      }
    }
  }

  Future<void> _loadExistingEntry(String entryId) async {
    if (_companyId == null) {
      // Wait for companyId to be loaded
      final prefs = await SharedPreferences.getInstance();
      _companyId = prefs.getString('companyId');
    }
    if (_companyId == null) return;

    setState(() => _isLoading = true);
    try {
      final entry =
          await _entryStore.repository.getSingle(_companyId!, entryId);
      if (entry != null && mounted) {
        // Load linked payments for entries with any payment
        List<FinancialPayment> payments = [];
        if ((entry.paidAmount ?? 0) > 0) {
          final raw = await _paymentStore.repository
              .getByEntryId(_companyId!, entryId);
          payments = raw
              .where((p) =>
                  p != null &&
                  p.status == FinancialPaymentStatus.completed &&
                  p.reversedPaymentId == null)
              .cast<FinancialPayment>()
              .toList();
        }

        if (!mounted) return;
        setState(() {
          _existingEntry = entry;
          _linkedPayments = payments;
          _direction = entry.direction?.name ?? 'payable';
          _descriptionController.text = entry.description ?? '';
          if (entry.amount != null && entry.amount! > 0) {
            _amountController.text =
                FormatService().formatDecimal(entry.amount!);
          }
          _dueDate = entry.dueDate ?? DateTime.now();
          _selectedCategory = entry.category;
          _supplierController.text = entry.supplier ?? '';
          _notesController.text = entry.notes ?? '';
          if (entry.supplier != null || entry.customer != null || entry.notes != null) {
            _showDetails = true;
          }
          if (!_isPayable) _showDetails = true;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

    // In edit mode, try to match the entry's account
    if (_isEditing && _existingEntry?.accountId != null) {
      final match = active.where((a) => a.id == _existingEntry!.accountId);
      if (match.isNotEmpty) {
        _selectedAccount = match.first;
        return;
      }
    }

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
    if (_isReadOnly) return;
    final amount = _parseAmount(_amountController.text);
    if (amount <= 0) return;

    setState(() => _isSaving = true);

    try {
      if (_isEditing) {
        // Edit mode: update existing entry
        _existingEntry!
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
        await _entryStore.updateEntry(_existingEntry!);
      } else {
        // Create mode
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
          final freq =
              _showRecurrenceOptions ? _recurrenceFrequency : 'monthly';
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

        // Pay immediately if "already paid" is toggled
        if (_markAsPaid && _selectedAccount != null && entry.id != null) {
          await _paymentStore.payEntry(
            entry,
            amount: amount,
            accountId: _selectedAccount!.id!,
            account: _selectedAccount!.toAggr(),
            method: _paymentMethod,
            paymentDate: _paymentDate,
          );
        }
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

    final String title;
    if (_isEditing) {
      title = _isPayable ? context.l10n.editExpense : context.l10n.editIncome;
    } else {
      title = _isPayable ? context.l10n.newExpense : context.l10n.newIncome;
    }
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
          child: Text(_isReadOnly ? context.l10n.close : context.l10n.cancel),
        ),
        trailing: _isSaving
            ? const CupertinoActivityIndicator()
            : _isReadOnly
                ? null
                : CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _save,
                    child: Text(
                      context.l10n.save,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CupertinoActivityIndicator())
              : CustomScrollView(
            slivers: [
            SliverToBoxAdapter(
              child: IgnorePointer(
                ignoring: _isReadOnly,
                child: Opacity(
                  opacity: _isReadOnly ? 0.6 : 1.0,
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Payment history section
                  if (_linkedPayments.isNotEmpty)
                    CupertinoListSection.insetGrouped(
                      header: Text(context.l10n.paymentHistory),
                      children: [
                        // Progress bar
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    context.l10n.paidOf(
                                      FormatService().formatCurrency(
                                          _existingEntry?.paidAmount ?? 0),
                                      FormatService().formatCurrency(
                                          _existingEntry?.amount ?? 0),
                                    ),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: CupertinoColors.secondaryLabel
                                          .resolveFrom(context),
                                    ),
                                  ),
                                  if (_isPaid)
                                    const Icon(
                                      CupertinoIcons.checkmark_circle_fill,
                                      color: CupertinoColors.systemGreen,
                                      size: 18,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: SizedBox(
                                  height: 8,
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final total =
                                          _existingEntry?.amount ?? 1;
                                      final paid =
                                          _existingEntry?.paidAmount ?? 0;
                                      final ratio = total > 0
                                          ? (paid / total).clamp(0.0, 1.0)
                                          : 0.0;
                                      return Stack(
                                        children: [
                                          Container(
                                            width: constraints.maxWidth,
                                            color: CupertinoColors.systemGrey5
                                                .resolveFrom(context),
                                          ),
                                          Container(
                                            width: constraints.maxWidth *
                                                ratio,
                                            color:
                                                CupertinoColors.systemGreen,
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Individual payments
                        ..._linkedPayments.map(
                          (p) => CupertinoListTile(
                            leading: const Icon(
                              CupertinoIcons.checkmark_circle,
                              color: CupertinoColors.systemGreen,
                              size: 20,
                            ),
                            title: Text(
                              FormatService()
                                  .formatCurrency(p.amount ?? 0),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${FormatService().formatDate(p.paymentDate ?? p.createdAt ?? DateTime.now())} \u00b7 ${_paymentMethodLabelForPayment(p.paymentMethod)} \u00b7 ${p.account?.name ?? ''}',
                            ),
                          ),
                        ),
                        // Reverse button (only for fully paid entries)
                        if (_isPaid)
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            onPressed: _isSaving
                                ? null
                                : () => _reverseLinkedPayment(
                                    _linkedPayments.first),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  CupertinoIcons.arrow_uturn_left,
                                  color: CupertinoColors.systemRed,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  context.l10n.reverseEntryPayment,
                                  style: const TextStyle(
                                    color: CupertinoColors.systemRed,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

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
                      // Value (readonly when paid)
                      IgnorePointer(
                        ignoring: _isPaid,
                        child: Opacity(
                          opacity: _isPaid ? 0.6 : 1.0,
                          child: CupertinoTextFormFieldRow(
                            controller: _amountController,
                            prefix: Text(context.l10n.value),
                            placeholder: '0,00',
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            autofocus: !_isEditing,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: labelColor,
                            ),
                          ),
                        ),
                      ),
                      // Due date (readonly when paid)
                      IgnorePointer(
                        ignoring: _isPaid,
                        child: Opacity(
                          opacity: _isPaid ? 0.6 : 1.0,
                          child: GestureDetector(
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

                  // "Already paid" toggle (only in create mode, not installments)
                  if (!_isEditing && !_isInstallment)
                    CupertinoListSection.insetGrouped(
                      children: [
                        CupertinoListTile(
                          title: Text(context.l10n.alreadyPaid),
                          trailing: CupertinoSwitch(
                            value: _markAsPaid,
                            onChanged: (val) {
                              setState(() => _markAsPaid = val);
                            },
                          ),
                        ),
                        if (_markAsPaid) ...[
                          GestureDetector(
                            onTap: _showPaymentMethodPicker,
                            behavior: HitTestBehavior.opaque,
                            child: CupertinoListTile(
                              title: Text(context.l10n.paymentMethod),
                              additionalInfo: Text(
                                _paymentMethodLabel(_paymentMethod),
                                style:
                                    TextStyle(color: secondaryLabelColor),
                              ),
                              trailing: const CupertinoListTileChevron(),
                            ),
                          ),
                          GestureDetector(
                            onTap: _showPaymentDatePicker,
                            behavior: HitTestBehavior.opaque,
                            child: CupertinoListTile(
                              title: Text(context.l10n.paymentDate),
                              additionalInfo: Text(
                                FormatService().formatDate(_paymentDate),
                                style:
                                    TextStyle(color: secondaryLabelColor),
                              ),
                              trailing: const CupertinoListTileChevron(),
                            ),
                          ),
                        ],
                      ],
                    ),

                  // Installment toggle
                  if (!_isEditing)
                  CupertinoListSection.insetGrouped(
                    children: [
                      CupertinoListTile(
                        title: Text(context.l10n.installmentCount),
                        trailing: CupertinoSwitch(
                          value: _isInstallment,
                          onChanged: (val) {
                            setState(() {
                              _isInstallment = val;
                              if (val) {
                                _isRecurring = false;
                                _markAsPaid = false;
                              }
                            });
                          },
                        ),
                      ),
                      if (_isInstallment)
                        _buildInstallmentStepper(context, labelColor,
                            secondaryLabelColor),
                    ],
                  ),

                  // Recurring toggle (only when not in installment mode, create only)
                  if (!_isInstallment && !_isEditing)
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
                          placeholder: '...',
                          maxLines: 3,
                          textCapitalization:
                              TextCapitalization.sentences,
                        ),
                      ],
                    ),

                  // Bottom save button
                  if (!_isReadOnly)
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

                  // Pay button (edit mode, pending entries not fully paid)
                  if (_isEditing && !_isPaid && !_isReadOnly)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: CupertinoButton(
                          color: CupertinoColors.activeBlue,
                          onPressed: _showPaySheet,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                CupertinoIcons.money_dollar_circle,
                                color: CupertinoColors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                context.l10n.confirmPayment,
                                style: const TextStyle(
                                    color: CupertinoColors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Delete / Cancel buttons (edit mode, pending only)
                  if (_isEditing && !_isPaid && !_isReadOnly) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: CupertinoButton(
                          onPressed: _showCancelEntryDialog,
                          child: Text(
                            context.l10n.cancelEntry,
                            style: const TextStyle(
                                color: CupertinoColors.systemOrange),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: CupertinoButton(
                          onPressed: _showDeleteEntryDialog,
                          child: Text(
                            context.l10n.deleteEntry,
                            style: const TextStyle(
                                color: CupertinoColors.systemRed),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
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

  void _showPaySheet() {
    if (_existingEntry == null) return;
    final accounts = _accountStore.accountList?.value
            ?.where((a) => a != null && (a.active ?? false))
            .cast<FinancialAccount>()
            .toList() ??
        [];
    if (accounts.isEmpty) return;

    PaymentConfirmationSheet.show(
      context,
      entry: _existingEntry!,
      accounts: accounts,
      onConfirm: (amount, accountId, account, method, date,
          {double? discount}) async {
        await _paymentStore.payEntry(
          _existingEntry!,
          amount: amount,
          accountId: accountId,
          account: account,
          method: method,
          paymentDate: date,
          discount: discount,
        );
        // Reload entry to reflect updated payment state
        if (mounted && _existingEntry?.id != null) {
          await _loadExistingEntry(_existingEntry!.id!);
        }
      },
    );
  }

  void _showDeleteEntryDialog() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(context.l10n.deleteEntry),
        content: Text(context.l10n.confirmDeleteEntry),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await _entryStore.deleteEntry(_existingEntry!);
              if (mounted) Navigator.pop(context);
            },
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
  }

  void _showCancelEntryDialog() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(context.l10n.cancelEntry),
        content: Text(context.l10n.confirmCancelEntry),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await _entryStore.cancelEntry(_existingEntry!);
              if (mounted) Navigator.pop(context);
            },
            child: Text(context.l10n.ok),
          ),
        ],
      ),
    );
  }

  void _showPaymentMethodPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(context.l10n.paymentMethod),
        actions: PaymentMethod.values.map((method) {
          return CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _paymentMethod = method);
              Navigator.pop(ctx);
            },
            child: Text(_paymentMethodLabel(method)),
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

  String _paymentMethodLabel(PaymentMethod method) {
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

  void _showPaymentDatePicker() {
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
                initialDateTime: _paymentDate,
                onDateTimeChanged: (date) {
                  setState(() => _paymentDate = date);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reverseLinkedPayment(FinancialPayment payment) async {
    final reason = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) {
        String reason = '';
        return StatefulBuilder(
          builder: (ctx, setState) {
            return CupertinoAlertDialog(
              title: Text(context.l10n.confirmReversal),
              content: Column(
                children: [
                  const SizedBox(height: 8),
                  Text(context.l10n.confirmReversalMessage),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    placeholder: context.l10n.reversalReasonHint,
                    onChanged: (value) => setState(() => reason = value),
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

    if (reason != null && reason.isNotEmpty) {
      setState(() => _isSaving = true);
      try {
        await _paymentStore.reversePayment(payment, reason);
        // Reload entry to reflect updated status
        if (_existingEntry?.id != null && mounted) {
          await _loadExistingEntry(_existingEntry!.id!);
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  String _paymentMethodLabelForPayment(PaymentMethod? method) {
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
