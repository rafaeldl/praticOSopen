import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/app_notification.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/repositories/tenant_repository.dart';

/// Repository for in-app notifications
///
/// Path: `/companies/{companyId}/notifications/{notificationId}`
class NotificationRepository extends TenantRepository<AppNotification> {
  NotificationRepository() : super('notifications');

  @override
  AppNotification fromJson(Map<String, dynamic> data) =>
      AppNotification.fromJson(data);

  @override
  Map<String, dynamic> toJson(AppNotification? item) => item?.toJson() ?? {};

  /// Stream unread notifications for a specific user
  Stream<List<AppNotification>> streamUnreadNotifications(
    String companyId,
    String userId,
  ) {
    return streamQueryList(
      companyId,
      args: [
        QueryArgs('recipientId', userId),
        QueryArgs('read', false),
      ],
      orderBy: [
        OrderBy('createdAt', descending: true),
      ],
      limit: 50,
    );
  }

  /// Stream all notifications for a specific user (with limit)
  Stream<List<AppNotification>> streamNotifications(
    String companyId,
    String userId, {
    int limit = 50,
  }) {
    return streamQueryList(
      companyId,
      args: [
        QueryArgs('recipientId', userId),
      ],
      orderBy: [
        OrderBy('createdAt', descending: true),
      ],
      limit: limit,
    );
  }

  /// Get unread notification count for a specific user
  Stream<int> streamUnreadCount(String companyId, String userId) {
    return streamUnreadNotifications(companyId, userId)
        .map((notifications) => notifications.length);
  }

  /// Mark a single notification as read
  Future<void> markAsRead(String companyId, String notificationId) async {
    final db = FirebaseFirestore.instance;
    await db
        .collection('companies')
        .doc(companyId)
        .collection('notifications')
        .doc(notificationId)
        .update({
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  /// Mark all notifications as read for a specific user
  Future<void> markAllAsRead(String companyId, String userId) async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    final unreadDocs = await db
        .collection('companies')
        .doc(companyId)
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();

    for (final doc in unreadDocs.docs) {
      batch.update(doc.reference, {
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
}
