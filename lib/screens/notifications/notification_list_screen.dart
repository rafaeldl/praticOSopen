import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/notification_store.dart';
import 'package:praticos/models/app_notification.dart';
import 'package:praticos/screens/notifications/notification_list_tile.dart';

/// Screen to display all notifications for the current user
class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  @override
  void initState() {
    super.initState();
    // Ensure notifications are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = Provider.of<NotificationStore>(context, listen: false);
      if (!store.isInitialized) {
        store.initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<NotificationStore>(context);

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Material(
        type: MaterialType.transparency,
        child: CustomScrollView(
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: Text(context.l10n.notifications),
              trailing: Observer(
                builder: (_) {
                  final count = store.unreadCount?.value ?? 0;
                  if (count == 0) return const SizedBox.shrink();

                  return CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => store.markAllAsRead(),
                    child: Text(
                      context.l10n.markAllAsRead,
                      style: const TextStyle(fontSize: 15),
                    ),
                  );
                },
              ),
            ),
            Observer(
              builder: (_) {
                final isLoading = store.isLoading;
                final notifications = store.notifications?.value ?? [];

                if (isLoading) {
                  return const SliverFillRemaining(
                    child: Center(child: CupertinoActivityIndicator()),
                  );
                }

                if (notifications.isEmpty) {
                  return SliverFillRemaining(
                    child: _buildEmptyState(context),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final notification = notifications[index];
                      final isFirst = index == 0;
                      final isLast = index == notifications.length - 1;

                      return NotificationListTile(
                        notification: notification,
                        isFirst: isFirst,
                        isLast: isLast,
                        onTap: () => _openNotification(context, notification, store),
                      );
                    },
                    childCount: notifications.length,
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 40),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.bell_slash,
            size: 64,
            color: CupertinoColors.systemGrey3.resolveFrom(context),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.noNotifications,
            style: TextStyle(
              fontSize: 17,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.noNotificationsDescription,
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _openNotification(
    BuildContext context,
    AppNotification notification,
    NotificationStore store,
  ) {
    // Mark as read
    if (notification.id != null && notification.read != true) {
      store.markAsRead(notification.id!);
    }

    // Navigate to order if orderId exists
    if (notification.orderId != null) {
      Navigator.pushNamed(
        context,
        '/order',
        arguments: {'orderId': notification.orderId},
      );
    }
  }
}
