import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show DateUtils;
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// "Hoje", "Ontem" or the date.
String paymentDayLabel(AppLocalizations l10n, DateTime day, {DateTime? now}) {
  final today = now ?? DateTime.now();
  if (DateUtils.isSameDay(day, today)) return l10n.today;
  if (DateUtils.isSameDay(day, today.subtract(const Duration(days: 1)))) {
    return l10n.yesterday;
  }
  return FormatService().formatDate(day);
}

/// `paidAt` stored for the chosen [day]: now when it is today, otherwise
/// noon of that day (no time is asked; noon keeps the day in any timezone
/// offset of a few hours).
DateTime paidAtFor(DateTime day, {DateTime? now}) {
  final current = now ?? DateTime.now();
  if (DateUtils.isSameDay(day, current)) return current;
  return DateTime(day.year, day.month, day.day, 12);
}

/// Date picker for when the money came in. No future dates.
Future<DateTime?> pickPaymentDay(BuildContext context, DateTime current) {
  final now = DateTime.now();
  final max = DateTime(now.year, now.month, now.day, 23, 59);
  var selected = DateUtils.dateOnly(current.isAfter(max) ? now : current);
  return showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (popupContext) => Container(
      height: 320,
      color: AppColors.surface.resolveFrom(popupContext),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: CupertinoButton(
                key: const Key('receiveDateConfirm'),
                minimumSize: const Size(
                  AppSizes.minTouchTarget,
                  AppSizes.minTouchTarget,
                ),
                onPressed: () => Navigator.pop(popupContext, selected),
                child: Text(popupContext.l10n.confirm),
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                key: const Key('receiveDatePicker'),
                mode: CupertinoDatePickerMode.date,
                initialDateTime: selected,
                maximumDate: max,
                onDateTimeChanged: (date) =>
                    selected = DateUtils.dateOnly(date),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// "Quando · Hoje ›" row of the receive blocks (on `accentSoft`).
class ReceiveDateRow extends StatelessWidget {
  const ReceiveDateRow({super.key, required this.day, required this.onTap});

  final DateTime day;

  /// Null disables the row (e.g. while saving).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final onSoft = AppColors.onAccentSoft.resolveFrom(context);
    final value = paymentDayLabel(context.l10n, day);
    return Semantics(
      button: true,
      label: '${context.l10n.receiveWhen}: $value',
      excludeSemantics: true,
      child: CupertinoButton(
        key: const Key('receiveDateRow'),
        padding: EdgeInsets.zero,
        minimumSize: const Size.fromHeight(AppSizes.minTouchTarget),
        onPressed: onTap,
        child: Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.receiveWhen,
                style: AppTypography.callout.copyWith(color: onSoft),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                value,
                key: const Key('receiveDateValue'),
                textAlign: TextAlign.end,
                style: AppTypography.callout.copyWith(
                  color: AppColors.accentText.resolveFrom(context),
                  fontFeatures: AppTypography.tabular,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(CupertinoIcons.chevron_right, size: 16, color: onSoft),
          ],
        ),
      ),
    );
  }
}
