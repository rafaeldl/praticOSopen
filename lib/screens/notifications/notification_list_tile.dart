import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/app_notification.dart';
import 'package:praticos/screens/widgets/app_list_row.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_typography.dart';

/// Removes emoji (and the spaces around them) from both ends of a backend
/// title: the app shows status with text and dots, not pictograms.
String stripEmoji(String text) {
  final emoji = r'[\p{Extended_Pictographic}\p{Emoji_Presentation}‍️⃣]';
  return text
      .replaceAll(RegExp('^(?:$emoji|\\s)+', unicode: true), '')
      .replaceAll(RegExp('(?:$emoji|\\s)+\$', unicode: true), '');
}

/// "há 5 minutos", "há 2 dias"; older than a month falls back to the date.
String relativeTime(BuildContext context, DateTime? time, DateTime now) {
  if (time == null) return '';
  final l10n = context.l10n;
  final diff = now.difference(time);
  if (diff.inMinutes < 1) return l10n.timeAgoNow;
  if (diff.inMinutes < 60) return l10n.timeAgoMinutes(diff.inMinutes);
  if (diff.inHours < 24) return l10n.timeAgoHours(diff.inHours);
  if (diff.inDays < 30) return l10n.timeAgoDays(diff.inDays);
  return FormatService().formatDate(time);
}

/// One row of the notification list: blue dot when unread, title (bold when
/// unread), "OS 183 · há 5 minutos" underneath and a chevron. The whole row
/// is a button.
class NotificationListTile extends StatelessWidget {
  const NotificationListTile({
    super.key,
    required this.notification,
    required this.onTap,
    required this.now,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final unread = notification.read != true;
    final rawTitle = notification.title?.trim().isNotEmpty == true
        ? notification.title!
        : (notification.body ?? '');
    final time = relativeTime(context, notification.createdAt, now);
    final number = notification.orderNumber;
    final subtitle = [
      if (number != null && number.toString().isNotEmpty)
        '${l10n.orderShort} $number',
      if (time.isNotEmpty) time,
    ].join(' · ');

    return AppListRow(
      leading: SizedBox(
        width: 10,
        height: 10,
        child: unread
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.accent.resolveFrom(context),
                  shape: BoxShape.circle,
                ),
              )
            : null,
      ),
      title: stripEmoji(rawTitle),
      titleStyle: unread
          ? AppTypography.bodyStrong
          : AppTypography.body,
      subtitle: subtitle.isEmpty ? null : subtitle,
      onTap: onTap,
    );
  }
}
