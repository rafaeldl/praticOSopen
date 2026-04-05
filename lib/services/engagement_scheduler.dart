import 'package:flutter/foundation.dart';
import 'package:praticos/global.dart';
import 'package:praticos/mobx/engagement_reminder_store.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/repositories/tenant/tenant_order_repository.dart';
import 'package:praticos/services/notification_service.dart';

/// Pre-resolved i18n strings for engagement notifications.
/// Passed from the UI layer so this service doesn't need BuildContext.
class EngagementStrings {
  final String dailyTitle;
  final String dailyBody;
  final String inactivity3dTitle;
  final String inactivity3dBody;
  final String inactivity5dTitle;
  final String inactivity5dBody;
  final String inactivity7dTitle;
  final String inactivity7dBody;
  final String pendingOsTitle;
  final String Function(int count) pendingOsBody;

  EngagementStrings({
    required this.dailyTitle,
    required this.dailyBody,
    required this.inactivity3dTitle,
    required this.inactivity3dBody,
    required this.inactivity5dTitle,
    required this.inactivity5dBody,
    required this.inactivity7dTitle,
    required this.inactivity7dBody,
    required this.pendingOsTitle,
    required this.pendingOsBody,
  });
}

/// Stateless service that orchestrates engagement notification scheduling.
/// Call [onAppResumed] every time the app comes to foreground.
class EngagementScheduler {
  final EngagementReminderStore _store;
  final EngagementStrings _strings;
  final NotificationService _notificationService = NotificationService.instance;
  final TenantOrderRepository _orderRepository = TenantOrderRepository();

  EngagementScheduler({
    required EngagementReminderStore store,
    required EngagementStrings strings,
  })  : _store = store,
        _strings = strings;

  /// Cancel all previous engagement notifications, then re-schedule
  /// based on current preferences and data.
  Future<void> onAppResumed() async {
    try {
      // Cancel everything first
      await _notificationService.cancelAllEngagementNotifications();

      // Re-schedule based on user preferences
      if (_store.dailyEnabled) {
        await _notificationService.scheduleDailyReminder(
          title: _strings.dailyTitle,
          body: _strings.dailyBody,
        );
      }

      if (_store.inactivityEnabled) {
        await _notificationService.scheduleInactivityReminders(
          title3d: _strings.inactivity3dTitle,
          body3d: _strings.inactivity3dBody,
          title5d: _strings.inactivity5dTitle,
          body5d: _strings.inactivity5dBody,
          title7d: _strings.inactivity7dTitle,
          body7d: _strings.inactivity7dBody,
        );
      }

      if (_store.pendingOsEnabled) {
        await _schedulePendingOsReminders();
      }
    } catch (e) {
      debugPrint('[EngagementScheduler] Error scheduling: $e');
    }
  }

  /// Query orders in quote/approved status older than 7 days,
  /// then schedule a single summary notification for tomorrow at 10 AM.
  Future<void> _schedulePendingOsReminders() async {
    final companyId = Global.companyAggr?.id;
    if (companyId == null) return;

    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

      // Get orders in quote or approved status
      final quoteOrders = await _orderRepository.getQueryList(
        companyId,
        args: [
          QueryArgs('status', ['quote', 'approved'], oper: 'whereIn'),
          QueryArgs(
            'createdAt',
            sevenDaysAgo.toIso8601String(),
            oper: 'isLessThan',
          ),
        ],
        orderBy: [OrderBy('createdAt', descending: true)],
      );

      final pendingCount =
          quoteOrders.where((o) => o != null).length;

      if (pendingCount == 0) return;

      // Schedule a single summary notification for tomorrow at 10 AM
      final now = DateTime.now();
      final tomorrow10am =
          DateTime(now.year, now.month, now.day + 1, 10, 0);

      await _notificationService.schedulePendingOsReminders([
        PendingOsNotification(
          title: _strings.pendingOsTitle,
          body: _strings.pendingOsBody(pendingCount),
          scheduledTime: tomorrow10am,
        ),
      ]);
    } catch (e) {
      debugPrint('[EngagementScheduler] Error fetching pending orders: $e');
    }
  }
}
