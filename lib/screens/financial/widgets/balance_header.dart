import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/services/format_service.dart';

/// Header widget showing balance + today summary + month navigation.
///
/// Displays total balance with eye toggle to hide/show values,
/// today's income/expense summary, and month navigation controls.
class BalanceHeader extends StatefulWidget {
  final double totalBalance;
  final double totalIncome;
  final double totalExpense;
  final double todayIncome;
  final double todayExpense;
  final DateTime currentMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  const BalanceHeader({
    super.key,
    required this.totalBalance,
    required this.totalIncome,
    required this.totalExpense,
    required this.todayIncome,
    required this.todayExpense,
    required this.currentMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  @override
  State<BalanceHeader> createState() => _BalanceHeaderState();
}

class _BalanceHeaderState extends State<BalanceHeader> {
  static const _hideValuesKey = 'financial_hide_values';
  bool _hideValues = false;

  @override
  void initState() {
    super.initState();
    _loadHidePreference();
  }

  Future<void> _loadHidePreference() async {
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

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryLabelColor =
        CupertinoColors.secondaryLabel.resolveFrom(context);
    final todayNet = widget.todayIncome - widget.todayExpense;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance row with eye toggle
          Row(
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
                      _formatValue(widget.totalBalance),
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

          const SizedBox(height: 6),

          // Today summary
          _buildTodaySummary(context, secondaryLabelColor, todayNet),

          const SizedBox(height: 16),

          // Month navigation
          _buildMonthNavigation(context, labelColor, secondaryLabelColor),

          const SizedBox(height: 8),

          // Inline income/expense summary
          _buildInlineSummary(context, secondaryLabelColor),
        ],
      ),
    );
  }

  Widget _buildTodaySummary(
    BuildContext context,
    Color secondaryColor,
    double todayNet,
  ) {
    if (widget.todayIncome == 0 && widget.todayExpense == 0) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        Text(
          '${context.l10n.todaySummary}: ',
          style: TextStyle(fontSize: 13, color: secondaryColor),
        ),
        if (widget.todayIncome > 0)
          Text(
            '+${_formatValue(widget.todayIncome)}',
            style: const TextStyle(
              fontSize: 13,
              color: CupertinoColors.systemGreen,
            ),
          ),
        if (widget.todayIncome > 0 && widget.todayExpense > 0)
          Text(
            ' ',
            style: TextStyle(fontSize: 13, color: secondaryColor),
          ),
        if (widget.todayExpense > 0)
          Text(
            '-${_formatValue(widget.todayExpense)}',
            style: const TextStyle(
              fontSize: 13,
              color: CupertinoColors.systemRed,
            ),
          ),
        if (widget.todayIncome > 0 || widget.todayExpense > 0)
          Text(
            ' = ',
            style: TextStyle(fontSize: 13, color: secondaryColor),
          ),
        Text(
          '${todayNet >= 0 ? '+' : ''}${_formatValue(todayNet)}',
          style: TextStyle(
            fontSize: 13,
            color: todayNet >= 0
                ? CupertinoColors.systemGreen
                : CupertinoColors.systemRed,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthNavigation(
    BuildContext context,
    Color labelColor,
    Color secondaryColor,
  ) {
    final monthLabel = DateFormat.yMMMM(
      Localizations.localeOf(context).toString(),
    ).format(widget.currentMonth);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: widget.onPreviousMonth,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Icon(
                CupertinoIcons.chevron_left,
                color: CupertinoColors.activeBlue,
                size: 20,
              ),
            ),
          ),
        ),
        Expanded(
          child: Text(
            monthLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
          ),
        ),
        GestureDetector(
          onTap: widget.onNextMonth,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Icon(
                CupertinoIcons.chevron_right,
                color: CupertinoColors.activeBlue,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInlineSummary(BuildContext context, Color secondaryColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${context.l10n.entries} ',
          style: TextStyle(fontSize: 13, color: secondaryColor),
        ),
        Text(
          '+${_formatValue(widget.totalIncome)}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: CupertinoColors.systemGreen,
          ),
        ),
        const SizedBox(width: 16),
        Text(
          '${context.l10n.exits} ',
          style: TextStyle(fontSize: 13, color: secondaryColor),
        ),
        Text(
          '-${_formatValue(widget.totalExpense)}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: CupertinoColors.systemRed,
          ),
        ),
      ],
    );
  }
}
