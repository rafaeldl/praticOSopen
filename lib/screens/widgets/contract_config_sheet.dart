import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/screens/menu_navigation/more/more_page.dart';
import 'package:praticos/screens/order/order_extras.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/screens/widgets/picker_screen.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// How often a contract repeats: frequency plus interval, offered as one
/// everyday choice ("Todo mês", "A cada 3 meses").
class ContractRepeat {
  const ContractRepeat(this.frequency, this.interval);

  final String frequency;
  final int interval;

  /// The choices of "Com que frequência?".
  static const options = [
    ContractRepeat('daily', 1),
    ContractRepeat('weekly', 1),
    ContractRepeat('weekly', 2),
    ContractRepeat('monthly', 1),
    ContractRepeat('monthly', 2),
    ContractRepeat('monthly', 3),
    ContractRepeat('monthly', 6),
    ContractRepeat('yearly', 1),
  ];

  String label(BuildContext context) {
    final l10n = context.l10n;
    switch (frequency) {
      case 'daily':
        return l10n.contractEveryDays(interval);
      case 'weekly':
        return l10n.contractEveryWeeks(interval);
      case 'yearly':
        return l10n.contractEveryYears(interval);
      default:
        return l10n.contractEveryMonths(interval);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ContractRepeat &&
      other.frequency == frequency &&
      other.interval == interval;

  @override
  int get hashCode => Object.hash(frequency, interval);
}

/// "Repetir": how a recurring order repeats. Opens pushed from the order;
/// every change applies right away through the callbacks.
class ContractConfigScreen extends StatefulWidget {
  const ContractConfigScreen({
    super.key,
    required this.contract,
    required this.onFrequencyChanged,
    required this.onIntervalChanged,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onAutoGenerateChanged,
    required this.onReminderDaysChanged,
    this.previousTitle,
    this.onStop,
  });

  final OrderContract contract;
  final ValueChanged<String> onFrequencyChanged;
  final ValueChanged<int> onIntervalChanged;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<DateTime?> onEndDateChanged;
  final ValueChanged<bool> onAutoGenerateChanged;
  final ValueChanged<int> onReminderDaysChanged;

  /// Back button label (the order's title).
  final String? previousTitle;

  /// "Parar de repetir": turns the contract off. Hidden when null.
  final VoidCallback? onStop;

  /// Choices of "Avisar quanto tempo antes?".
  static const reminderOptions = [0, 1, 2, 3, 5, 7, 15, 30];

  @override
  State<ContractConfigScreen> createState() => _ContractConfigScreenState();
}

class _ContractConfigScreenState extends State<ContractConfigScreen> {
  late ContractRepeat _repeat;
  late DateTime _startDate;
  DateTime? _endDate;
  late bool _autoGenerate;
  late int _reminderDays;

  @override
  void initState() {
    super.initState();
    final c = widget.contract;
    _repeat = ContractRepeat(c.frequency ?? 'monthly', c.interval ?? 1);
    _startDate = c.startDate ?? DateTime.now();
    _endDate = c.endDate;
    _autoGenerate = c.autoGenerate ?? true;
    _reminderDays = c.reminderDaysBefore ?? 3;
  }

  Future<void> _pickRepeat() async {
    final options = [
      ...ContractRepeat.options,
      if (!ContractRepeat.options.contains(_repeat)) _repeat,
    ];
    final picked = await pickOne<ContractRepeat>(
      context,
      title: context.l10n.contractRepeatsTitle,
      selected: _repeat,
      options: [
        for (final o in options) PickerItem(value: o, title: o.label(context)),
      ],
    );
    if (picked == null || !mounted || picked == _repeat) return;
    setState(() => _repeat = picked);
    widget.onFrequencyChanged(picked.frequency);
    widget.onIntervalChanged(picked.interval);
  }

  Future<void> _pickStart() async {
    final picked = await OrderDateSheet.show(
      context,
      initial: _startDate,
      dateOnly: true,
    );
    final date = picked?.date;
    if (date == null || !mounted) return;
    setState(() => _startDate = date);
    widget.onStartDateChanged(date);
    final end = _endDate;
    if (end != null && end.isBefore(date)) {
      setState(() => _endDate = date);
      widget.onEndDateChanged(date);
    }
  }

  Future<void> _pickEnd() async {
    final end = _endDate;
    final fallback = DateTime(
      _startDate.year + 1,
      _startDate.month,
      _startDate.day,
    );
    final picked = await OrderDateSheet.show(
      context,
      initial: end == null || end.isBefore(_startDate) ? fallback : end,
      dateOnly: true,
      minimum: DateTime(_startDate.year, _startDate.month, _startDate.day),
      removeLabel: end == null ? null : context.l10n.contractNoEndDate,
    );
    if (picked == null || !mounted) return;
    setState(() => _endDate = picked.remove ? null : picked.date);
    widget.onEndDateChanged(_endDate);
  }

  Future<void> _pickReminder() async {
    final options = [
      ...ContractConfigScreen.reminderOptions,
      if (!ContractConfigScreen.reminderOptions.contains(_reminderDays))
        _reminderDays,
    ];
    final picked = await pickOne<int>(
      context,
      title: context.l10n.contractRemindTitle,
      selected: _reminderDays,
      options: [
        for (final d in options)
          PickerItem(value: d, title: context.l10n.contractRemindDays(d)),
      ],
    );
    if (picked == null || !mounted || picked == _reminderDays) return;
    setState(() => _reminderDays = picked);
    widget.onReminderDaysChanged(picked);
  }

  Future<void> _confirmStop() async {
    final l10n = context.l10n;
    final stop = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(l10n.contractStopRepeatingTitle),
        content: Text(l10n.contractStopRepeatingMessage),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.contractStopRepeating),
          ),
        ],
      ),
    );
    if (stop != true || !mounted) return;
    widget.onStop?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = FormatService();
    final order = l10n.orderShort;
    return MorePage(
      title: l10n.orderRepeatRow,
      previousPageTitle: widget.previousTitle,
      children: [
        MoreRows(
          rows: [
            AppListRow(
              key: const Key('contractRepeatRow'),
              title: l10n.contractRepeats,
              trailing: _repeat.label(context),
              onTap: _pickRepeat,
            ),
            AppListRow(
              key: const Key('contractStartRow'),
              title: l10n.contractStarts,
              trailing: format.formatDate(_startDate),
              onTap: _pickStart,
            ),
            AppListRow(
              key: const Key('contractEndRow'),
              title: l10n.contractEnds,
              trailing: _endDate == null
                  ? l10n.contractNeverEnds
                  : format.formatDate(_endDate!),
              onTap: _pickEnd,
            ),
            AppListRow(
              key: const Key('contractRemindRow'),
              title: l10n.contractRemind,
              trailing: l10n.contractRemindDays(_reminderDays),
              onTap: _pickReminder,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        MoreSwitchRow(
          key: const Key('contractAutoCreateRow'),
          title: l10n.contractAutoCreate(order),
          value: _autoGenerate,
          onChanged: (value) {
            setState(() => _autoGenerate = value);
            widget.onAutoGenerateChanged(value);
          },
        ),
        MoreFootnote(l10n.contractAutoCreateHint(order)),
        if (widget.onStop != null) ...[
          const SizedBox(height: AppSpacing.xl),
          MoreRows(
            rows: [
              Semantics(
                button: true,
                child: GestureDetector(
                  key: const Key('contractStopRow'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _confirmStop,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: AppSizes.minTouchTarget,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          l10n.contractStopRepeating,
                          style: AppTypography.body.copyWith(
                            color: AppColors.danger.resolveFrom(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
