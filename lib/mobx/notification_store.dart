import 'package:mobx/mobx.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/app_notification.dart';
import 'package:praticos/repositories/tenant/notification_repository.dart';
import 'package:praticos/services/notification_service.dart';

part 'notification_store.g.dart';

class NotificationStore = _NotificationStore with _$NotificationStore;

abstract class _NotificationStore with Store {
  final NotificationRepository repository = NotificationRepository();
  final NotificationService notificationService = NotificationService.instance;

  @observable
  ObservableStream<List<AppNotification>>? notifications;

  @observable
  ObservableStream<int>? unreadCount;

  @observable
  bool isLoading = false;

  @observable
  bool hasPermission = false;

  @observable
  bool isInitialized = false;

  String? get companyId => Global.companyAggr?.id;
  String? get userId => Global.userAggr?.id;

  /// Initialize the notification system
  @action
  Future<void> initialize() async {
    if (isInitialized) return;

    isLoading = true;

    try {
      // Initialize notification service
      await notificationService.initialize();

      // Request permission
      hasPermission = await notificationService.requestPermission();

      // Register token if permission granted and user is logged in
      if (hasPermission && userId != null) {
        await notificationService.registerToken(userId!);
      }

      // Load notifications
      loadNotifications();

      isInitialized = true;
    } catch (e) {
      print('[NotificationStore] Error initializing: $e');
    } finally {
      isLoading = false;
    }
  }

  /// Load notifications stream for current user
  @action
  void loadNotifications() {
    if (companyId == null || userId == null) return;

    notifications = repository
        .streamNotifications(companyId!, userId!)
        .asObservable();

    unreadCount = repository
        .streamUnreadCount(companyId!, userId!)
        .asObservable();
  }

  /// Reload notifications (e.g., after company switch)
  @action
  void reload() {
    loadNotifications();
  }

  /// Mark a single notification as read
  @action
  Future<void> markAsRead(String notificationId) async {
    if (companyId == null) return;

    try {
      await repository.markAsRead(companyId!, notificationId);
    } catch (e) {
      print('[NotificationStore] Error marking as read: $e');
    }
  }

  /// Mark all notifications as read for current user
  @action
  Future<void> markAllAsRead() async {
    if (companyId == null || userId == null) return;

    try {
      await repository.markAllAsRead(companyId!, userId!);
    } catch (e) {
      print('[NotificationStore] Error marking all as read: $e');
    }
  }

  /// Cleanup on logout - unregister token
  @action
  Future<void> dispose() async {
    if (userId != null) {
      try {
        await notificationService.unregisterToken(userId!);
      } catch (e) {
        print('[NotificationStore] Error unregistering token: $e');
      }
    }

    notifications = null;
    unreadCount = null;
    isInitialized = false;
    hasPermission = false;
  }

  /// Request permission again (e.g., from settings)
  @action
  Future<bool> requestPermissionAgain() async {
    hasPermission = await notificationService.requestPermission();

    if (hasPermission && userId != null) {
      await notificationService.registerToken(userId!);
      loadNotifications();
    }

    return hasPermission;
  }
}
