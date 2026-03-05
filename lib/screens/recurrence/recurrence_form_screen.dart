import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:praticos/mobx/recurrence_store.dart';
import 'package:praticos/models/recurrence_rule.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/device.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/extensions/context_extensions.dart';

class RecurrenceFormScreen extends StatefulWidget {
  const RecurrenceFormScreen({super.key});

  @override
  State<RecurrenceFormScreen> createState() => _RecurrenceFormScreenState();
}

class _RecurrenceFormScreenState extends State<RecurrenceFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final RecurrenceStore _store = RecurrenceStore();
  final FormatService _formatService = FormatService();

  RecurrenceRule? _rule;
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_rule == null) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args.containsKey('rule')) {
        _rule = args['rule'] as RecurrenceRule;
        _isEditing = true;
      } else {
        _rule = RecurrenceRule()
          ..frequency = 'monthly'
          ..interval = 1
          ..active = true
          ..autoGenerate = false
          ..startDate = DateTime.now();
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);
    try {
      // Compute nextDueDate if not set
      if (_rule!.nextDueDate == null && _rule!.startDate != null) {
        _rule!.nextDueDate = _rule!.startDate;
      }

      await _store.saveRule(_rule!);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _pickFrequency() {
    final frequencies = ['daily', 'weekly', 'monthly', 'yearly'];
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(context.l10n.frequency),
        actions: frequencies.map((freq) {
          return CupertinoActionSheetAction(
            child: Text(_frequencyLabel(freq)),
            onPressed: () {
              setState(() => _rule!.frequency = freq);
              Navigator.pop(ctx);
            },
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          child: Text(context.l10n.cancel),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  String _frequencyLabel(String? frequency) {
    switch (frequency) {
      case 'daily':
        return context.l10n.recurrenceFrequencyDaily;
      case 'weekly':
        return context.l10n.recurrenceFrequencyWeekly;
      case 'monthly':
        return context.l10n.recurrenceFrequencyMonthly;
      case 'yearly':
        return context.l10n.recurrenceFrequencyYearly;
      default:
        return frequency ?? '';
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? (_rule!.startDate ?? DateTime.now()) : (_rule!.endDate ?? DateTime.now());

    await showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 300,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: Text(context.l10n.cancel),
                  onPressed: () => Navigator.pop(ctx),
                ),
                CupertinoButton(
                  child: Text(context.l10n.done, style: const TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: initial,
                onDateTimeChanged: (date) {
                  setState(() {
                    if (isStart) {
                      _rule!.startDate = date;
                    } else {
                      _rule!.endDate = date;
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectCustomer() async {
    final result = await Navigator.pushNamed(
      context,
      '/customer_list',
      arguments: {'selectionMode': true},
    );
    if (result != null && result is Customer) {
      setState(() => _rule!.customer = result.toAggr());
    }
  }

  void _selectDevice() async {
    final result = await Navigator.pushNamed(
      context,
      '/device_list',
      arguments: {'order': true},
    );
    if (result != null && result is Device) {
      setState(() {
        _rule!.devices ??= [];
        final aggr = result.toAggr();
        if (!_rule!.devices!.any((d) => d.id == aggr.id)) {
          _rule!.devices!.add(aggr);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();

    if (_rule == null) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(_isEditing
            ? context.l10n.editRecurrenceRule
            : context.l10n.newRecurrenceRule),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const CupertinoActivityIndicator()
              : Text(context.l10n.save, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 20),

              // Basic info
              CupertinoListSection.insetGrouped(
                header: Text(context.l10n.basicInfo.toUpperCase()),
                children: [
                  CupertinoTextFormFieldRow(
                    prefix: Text(context.l10n.name),
                    initialValue: _rule!.name,
                    placeholder: context.l10n.name,
                    textCapitalization: TextCapitalization.sentences,
                    textAlign: TextAlign.right,
                    onSaved: (val) => _rule!.name = val,
                  ),
                  CupertinoTextFormFieldRow(
                    prefix: Text(context.l10n.details),
                    initialValue: _rule!.templateDescription,
                    placeholder: context.l10n.details,
                    textCapitalization: TextCapitalization.sentences,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    onSaved: (val) => _rule!.templateDescription = val,
                  ),
                ],
              ),

              // Frequency
              CupertinoListSection.insetGrouped(
                header: Text(context.l10n.frequency.toUpperCase()),
                children: [
                  CupertinoListTile(
                    title: Text(context.l10n.frequency),
                    additionalInfo: Text(_frequencyLabel(_rule!.frequency)),
                    trailing: Icon(
                      CupertinoIcons.chevron_right,
                      size: 20,
                      color: CupertinoColors.systemGrey.resolveFrom(context),
                    ),
                    onTap: _pickFrequency,
                  ),
                  CupertinoTextFormFieldRow(
                    prefix: Text(context.l10n.interval),
                    initialValue: (_rule!.interval ?? 1).toString(),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    onSaved: (val) => _rule!.interval = int.tryParse(val ?? '1') ?? 1,
                  ),
                ],
              ),

              // Dates
              CupertinoListSection.insetGrouped(
                children: [
                  CupertinoListTile(
                    title: Text(context.l10n.recurrenceStartDate),
                    additionalInfo: Text(
                      _rule!.startDate != null
                          ? _formatService.formatDate(_rule!.startDate!)
                          : context.l10n.select,
                    ),
                    trailing: Icon(
                      CupertinoIcons.chevron_right,
                      size: 20,
                      color: CupertinoColors.systemGrey.resolveFrom(context),
                    ),
                    onTap: () => _pickDate(isStart: true),
                  ),
                  CupertinoListTile(
                    title: Text(context.l10n.recurrenceEndDate),
                    additionalInfo: Text(
                      _rule!.endDate != null
                          ? _formatService.formatDate(_rule!.endDate!)
                          : context.l10n.indefinite,
                    ),
                    trailing: Icon(
                      CupertinoIcons.chevron_right,
                      size: 20,
                      color: CupertinoColors.systemGrey.resolveFrom(context),
                    ),
                    onTap: () => _pickDate(isStart: false),
                  ),
                ],
              ),

              // Customer & Device
              CupertinoListSection.insetGrouped(
                header: Text('TEMPLATE'),
                children: [
                  CupertinoListTile(
                    title: Text(config.customer),
                    additionalInfo: Text(
                      _rule!.customer?.name ?? context.l10n.select,
                      style: TextStyle(
                        color: _rule!.customer != null
                            ? CupertinoColors.label.resolveFrom(context)
                            : CupertinoColors.placeholderText.resolveFrom(context),
                      ),
                    ),
                    trailing: Icon(
                      CupertinoIcons.chevron_right,
                      size: 20,
                      color: CupertinoColors.systemGrey.resolveFrom(context),
                    ),
                    onTap: _selectCustomer,
                  ),
                  CupertinoListTile(
                    title: Text(config.device),
                    additionalInfo: Text(
                      _rule!.devices?.isNotEmpty == true
                          ? _rule!.devices!.map((d) => d.name ?? d.serial ?? '').join(', ')
                          : context.l10n.select,
                      style: TextStyle(
                        color: _rule!.devices?.isNotEmpty == true
                            ? CupertinoColors.label.resolveFrom(context)
                            : CupertinoColors.placeholderText.resolveFrom(context),
                      ),
                    ),
                    trailing: Icon(
                      CupertinoIcons.chevron_right,
                      size: 20,
                      color: CupertinoColors.systemGrey.resolveFrom(context),
                    ),
                    onTap: _selectDevice,
                  ),
                ],
              ),

              // Settings
              CupertinoListSection.insetGrouped(
                header: Text(context.l10n.settings.toUpperCase()),
                children: [
                  CupertinoFormRow(
                    prefix: Text(context.l10n.recurrenceActive),
                    child: CupertinoSwitch(
                      value: _rule!.active ?? true,
                      onChanged: (val) => setState(() => _rule!.active = val),
                    ),
                  ),
                  CupertinoFormRow(
                    prefix: Text(context.l10n.recurrenceAutoGenerate),
                    helper: Text(
                      context.l10n.recurrenceAutoGenerateDescription,
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                      ),
                    ),
                    child: CupertinoSwitch(
                      value: _rule!.autoGenerate ?? false,
                      onChanged: (val) => setState(() => _rule!.autoGenerate = val),
                    ),
                  ),
                  CupertinoTextFormFieldRow(
                    prefix: Text(context.l10n.recurrenceReminderDays),
                    initialValue: (_rule!.reminderDaysBefore ?? 0).toString(),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    onSaved: (val) => _rule!.reminderDaysBefore = int.tryParse(val ?? '0') ?? 0,
                  ),
                ],
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}
