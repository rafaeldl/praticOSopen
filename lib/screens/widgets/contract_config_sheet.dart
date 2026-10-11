import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/services/format_service.dart';

/// Bottom sheet for configuring contract parameters
class ContractConfigSheet extends StatefulWidget {
  final OrderContract contract;
  final ValueChanged<String> onFrequencyChanged;
  final ValueChanged<int> onIntervalChanged;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<DateTime?> onEndDateChanged;
  final ValueChanged<bool> onAutoGenerateChanged;
  final ValueChanged<int> onReminderDaysChanged;

  const ContractConfigSheet({
    super.key,
    required this.contract,
    required this.onFrequencyChanged,
    required this.onIntervalChanged,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onAutoGenerateChanged,
    required this.onReminderDaysChanged,
  });

  @override
  State<ContractConfigSheet> createState() => _ContractConfigSheetState();
}

class _ContractConfigSheetState extends State<ContractConfigSheet> {
  late String _frequency;
  late int _interval;
  late DateTime _startDate;
  DateTime? _endDate;
  late bool _autoGenerate;
  late int _reminderDays;

  @override
  void initState() {
    super.initState();
    _frequency = widget.contract.frequency ?? 'monthly';
    _interval = widget.contract.interval ?? 1;
    _startDate = widget.contract.startDate ?? DateTime.now();
    _endDate = widget.contract.endDate;
    _autoGenerate = widget.contract.autoGenerate ?? true;
    _reminderDays = widget.contract.reminderDaysBefore ?? 3;
  }

  String _frequencyLabel(String frequency) {
    switch (frequency) {
      case 'daily':
        return context.l10n.frequencyDaily;
      case 'weekly':
        return context.l10n.frequencyWeekly;
      case 'monthly':
        return context.l10n.frequencyMonthly;
      case 'yearly':
        return context.l10n.frequencyYearly;
      default:
        return frequency;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.configure,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: Text(context.l10n.done),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: ListView(
              children: [
                CupertinoListSection.insetGrouped(
                  children: [
                    // Frequency
                    CupertinoListTile(
                      title: Text(context.l10n.frequency),
                      additionalInfo: Text(_frequencyLabel(_frequency)),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () => _showFrequencyPicker(),
                    ),
                    // Interval
                    CupertinoListTile(
                      title: Text(context.l10n.interval),
                      additionalInfo: Text('$_interval'),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () => _showIntervalPicker(),
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  children: [
                    // Start date
                    CupertinoListTile(
                      title: Text(context.l10n.startDate),
                      additionalInfo: Text(
                        FormatService().formatDate(_startDate),
                      ),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () => _showStartDatePicker(),
                    ),
                    // End date
                    CupertinoListTile(
                      title: Text(context.l10n.endDate),
                      additionalInfo: Text(
                        _endDate != null
                            ? FormatService().formatDate(_endDate!)
                            : context.l10n.indefinite,
                      ),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () => _showEndDatePicker(),
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  children: [
                    // Auto-generate toggle
                    CupertinoListTile(
                      title: Text(context.l10n.contractAutoGenerate),
                      trailing: CupertinoSwitch(
                        value: _autoGenerate,
                        onChanged: (val) {
                          setState(() => _autoGenerate = val);
                          widget.onAutoGenerateChanged(val);
                        },
                      ),
                    ),
                    // Reminder days
                    CupertinoListTile(
                      title: Text(context.l10n.contractReminderDays),
                      additionalInfo: Text('$_reminderDays'),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () => _showReminderDaysPicker(),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Text(
                    context.l10n.contractAutoGenerateDescription,
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
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

  void _showFrequencyPicker() {
    final options = ['daily', 'weekly', 'monthly', 'yearly'];
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: options.map((f) => CupertinoActionSheetAction(
          onPressed: () {
            setState(() => _frequency = f);
            widget.onFrequencyChanged(f);
            Navigator.pop(ctx);
          },
          child: Text(_frequencyLabel(f)),
        )).toList(),
        cancelButton: CupertinoActionSheetAction(
          child: Text(context.l10n.cancel),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  void _showIntervalPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 250,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  child: Text(context.l10n.done),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 32,
                scrollController: FixedExtentScrollController(
                  initialItem: _interval - 1,
                ),
                onSelectedItemChanged: (index) {
                  setState(() => _interval = index + 1);
                  widget.onIntervalChanged(index + 1);
                },
                children: List.generate(
                  12,
                  (i) => Center(child: Text('${i + 1}')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStartDatePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 300,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  child: Text(context.l10n.done),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _startDate,
                onDateTimeChanged: (date) {
                  setState(() => _startDate = date);
                  widget.onStartDateChanged(date);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEndDatePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              setState(() => _endDate = null);
              widget.onEndDateChanged(null);
              Navigator.pop(ctx);
            },
            child: Text(context.l10n.indefinite),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _showEndDatePickerDate();
            },
            child: Text(context.l10n.selectDate),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text(context.l10n.cancel),
          onPressed: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  void _showEndDatePickerDate() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 300,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  child: Text(context.l10n.done),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _endDate ?? DateTime.now().add(const Duration(days: 365)),
                minimumDate: _startDate,
                onDateTimeChanged: (date) {
                  setState(() => _endDate = date);
                  widget.onEndDateChanged(date);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReminderDaysPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 250,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  child: Text(context.l10n.done),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 32,
                scrollController: FixedExtentScrollController(
                  initialItem: _reminderDays,
                ),
                onSelectedItemChanged: (index) {
                  setState(() => _reminderDays = index);
                  widget.onReminderDaysChanged(index);
                },
                children: List.generate(
                  31,
                  (i) => Center(child: Text('$i')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
