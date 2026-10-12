import 'package:flutter/cupertino.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/mobx/notification_store.dart';
import 'package:praticos/models/app_notification.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/screens/notifications/notification_list_tile.dart';
import 'package:praticos/screens/widgets/list_states.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/screens/widgets/text_link.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// "Avisos": what happened in the orders since the owner last looked.
/// Unread first ("Novos"), then the read ones ("Antes"). Tapping any row
/// opens the order.
class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  @override
  void initState() {
    super.initState();
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
    return Observer(
      builder: (_) => NotificationListView(
        notifications: store.notifications?.value ?? const [],
        isLoading: store.isLoading,
        onOpen: (notification) {
          if (notification.id != null && notification.read != true) {
            store.markAsRead(notification.id!);
          }
          openNotificationOrder(context, notification);
        },
        onMarkAllRead: store.markAllAsRead,
      ),
    );
  }
}

/// Opens the order a notification is about. Comment notifications ask the
/// order to scroll to the comments.
void openNotificationOrder(BuildContext context, AppNotification notification) {
  final orderId = notification.orderId;
  if (orderId == null) return;
  final order = Order()..id = orderId;
  final isComment = notification.type == NotificationType.newComment;
  Navigator.pushNamed(
    context,
    '/order',
    arguments: {
      'order': order,
      if (isComment) 'scrollToComments': true,
      if (isComment && notification.data?['commentId'] != null)
        'commentId': notification.data!['commentId'],
    },
  );
}

/// Pure presentation of the notification list (no store, no Firebase).
class NotificationListView extends StatelessWidget {
  const NotificationListView({
    super.key,
    required this.notifications,
    required this.onOpen,
    required this.onMarkAllRead,
    this.isLoading = false,
    this.hasError = false,
    this.onRetry,
    this.now,
  });

  final List<AppNotification> notifications;
  final bool isLoading;
  final bool hasError;
  final VoidCallback? onRetry;
  final ValueChanged<AppNotification> onOpen;
  final VoidCallback onMarkAllRead;

  /// Clock, injected in tests.
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final unread = notifications.where((n) => n.read != true).toList();
    final read = notifications.where((n) => n.read == true).toList();
    final clock = (now ?? DateTime.now)();

    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      child: CustomScrollView(
        slivers: [
          AppNavBar(
            largeTitle: Text(l10n.noticesTitle),
          ),
          if (isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: LoadingState(),
            )
          else if (hasError)
            SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorState(onRetry: onRetry ?? () {}),
            )
          else if (notifications.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(title: l10n.noticesEmpty),
            )
          else ...[
            SliverToBoxAdapter(child: _header(context, unread.length)),
            SliverList(
              delegate: SliverChildListDelegate([
                if (unread.isNotEmpty) SectionLabel(l10n.noticesSectionNew),
                for (final n in unread)
                  NotificationListTile(
                    notification: n,
                    now: clock,
                    onTap: () => onOpen(n),
                  ),
                if (read.isNotEmpty) SectionLabel(l10n.noticesSectionBefore),
                for (final n in read)
                  NotificationListTile(
                    notification: n,
                    now: clock,
                    onTap: () => onOpen(n),
                  ),
              ]),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ],
        ],
      ),
    );
  }

  Widget _header(BuildContext context, int unreadCount) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (unreadCount > 0) ...[
            Text(
              l10n.noticesNewCount(unreadCount),
              style: AppTypography.callout.copyWith(
                color: AppColors.textSecondary.resolveFrom(context),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextLink(
                label: l10n.noticesMarkAllRead,
                onPressed: onMarkAllRead,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
