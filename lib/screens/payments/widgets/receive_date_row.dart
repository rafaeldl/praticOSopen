import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show DateUtils;
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';

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
