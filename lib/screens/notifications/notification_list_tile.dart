import 'package:flutter/cupertino.dart';
import 'package:praticos/models/app_notification.dart';
import 'package:praticos/services/format_service.dart';

/// A single notification tile in the notification list
class NotificationListTile extends StatelessWidget {
  final AppNotification notification;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const NotificationListTile({
    required this.notification,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = notification.read != true;
    final typeInfo = _getTypeInfo(notification.type);

    return Container(
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        top: isFirst ? 16 : 0,
      ),
      decoration: BoxDecoration(
        color: isUnread
            ? CupertinoColors.systemBlue.withValues(alpha: 0.03)
            : CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: _getBorderRadius(),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: typeInfo.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(
                        typeInfo.icon,
                        color: typeInfo.color,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          notification.title ?? '',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                            color: CupertinoColors.label.resolveFrom(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Body
                        if (notification.body != null &&
                            notification.body!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            notification.body!,
                            style: TextStyle(
                              fontSize: 14,
                              color: CupertinoColors.secondaryLabel.resolveFrom(context),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        // Time
                        const SizedBox(height: 6),
                        Text(
                          _formatTimeAgo(notification.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Unread indicator
                  if (isUnread)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: const BoxDecoration(
                        color: CupertinoColors.activeBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  // Chevron
                  if (notification.orderId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Icon(
                        CupertinoIcons.chevron_right,
                        size: 14,
                        color: CupertinoColors.systemGrey3.resolveFrom(context),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Separator
          if (!isLast)
            Container(
              height: 1,
              margin: const EdgeInsets.only(left: 64),
              color: CupertinoColors.separator.resolveFrom(context),
            ),
        ],
      ),
    );
  }

  BorderRadius _getBorderRadius() {
    if (isFirst && isLast) {
      return BorderRadius.circular(10);
    } else if (isFirst) {
      return const BorderRadius.only(
        topLeft: Radius.circular(10),
        topRight: Radius.circular(10),
      );
    } else if (isLast) {
      return const BorderRadius.only(
        bottomLeft: Radius.circular(10),
        bottomRight: Radius.circular(10),
      );
    }
    return BorderRadius.zero;
  }

  _NotificationTypeInfo _getTypeInfo(String? type) {
    switch (type) {
      case NotificationType.orderApproved:
        return _NotificationTypeInfo(
          icon: CupertinoIcons.check_mark_circled,
          color: CupertinoColors.systemGreen,
        );
      case NotificationType.orderRejected:
        return _NotificationTypeInfo(
          icon: CupertinoIcons.xmark_circle,
          color: CupertinoColors.systemRed,
        );
      case NotificationType.newComment:
        return _NotificationTypeInfo(
          icon: CupertinoIcons.chat_bubble,
          color: CupertinoColors.activeBlue,
        );
      case NotificationType.statusChanged:
        return _NotificationTypeInfo(
          icon: CupertinoIcons.arrow_right_arrow_left,
          color: CupertinoColors.systemOrange,
        );
      case NotificationType.orderRated:
        return _NotificationTypeInfo(
          icon: CupertinoIcons.star_fill,
          color: const Color(0xFFFFD700),
        );
      default:
        return _NotificationTypeInfo(
          icon: CupertinoIcons.bell,
          color: CupertinoColors.systemGrey,
        );
    }
  }

  String _formatTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return '';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Agora';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return FormatService().formatDate(dateTime);
    }
  }
}

class _NotificationTypeInfo {
  final IconData icon;
  final Color color;

  _NotificationTypeInfo({
    required this.icon,
    required this.color,
  });
}
