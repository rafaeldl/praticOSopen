import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// What will happen before a visit: "O app avisa 30 min antes.", or why it
/// will not. [minutes] is `ReminderStore.reminderMinutes`; [blocked] means
/// the phone refused notifications.
String reminderHintText(
  AppLocalizations l10n, {
  required int minutes,
  required bool blocked,
}) {
  if (blocked) return l10n.reminderPhoneBlocked;
  if (minutes <= 0) return l10n.reminderIsOff;
  final time = minutes % 60 == 0
      ? l10n.reminderHoursValue(minutes ~/ 60)
      : l10n.reminderMinutesValue(minutes);
  return l10n.reminderWillNotify(time);
}

/// Under the date picker of a visit: the hint and "Ajustar".
class ReminderHintRow extends StatelessWidget {
  const ReminderHintRow({
    super.key,
    required this.text,
    required this.onAdjust,
  });

  final String text;
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageMargin,
        AppSpacing.xs,
        AppSpacing.pageMargin,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: AppTypography.callout.copyWith(
                color: AppColors.textSecondary.resolveFrom(context),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextLink(
            key: const ValueKey('reminder_adjust'),
            label: context.l10n.reminderAdjust,
            onPressed: onAdjust,
          ),
        ],
      ),
    );
  }
}
