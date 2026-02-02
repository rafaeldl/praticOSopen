import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/app_notification.dart';
import 'package:praticos/repositories/tenant_repository.dart';

/// Convert Firestore Timestamps to DateTime in a map
Map<String, dynamic> _convertTimestamps(Map<String, dynamic> data) {
  final result = Map<String, dynamic>.from(data);
  for (final key in result.keys) {
    if (result[key] is Timestamp) {
      result[key] = (result[key] as Timestamp).toDate().toIso8601String();
    }
  }
  return result;
}

/// Repository for in-app notifications
///
/// Path: `/companies/{companyId}/notifications/{notificationId}`
class NotificationRepository extends TenantRepository<AppNotification> {
  NotificationRepository() : super('notifications');

  @override
  AppNotification fromJson(Map<String, dynamic> data) =>
      AppNotification.fromJson(_convertTimestamps(data));

  @override
  Map<String, dynamic> toJson(AppNotification? item) => item?.toJson() ?? {};

  /// Stream unread notifications for a specific user
  Stream<List<AppNotification>> streamUnreadNotifications(
    String companyId,
    String userId,
  ) {
    return FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = _convertTimestamps(doc.data());
            data['id'] = doc.id;
            return AppNotification.fromJson(data);
          }).toList();
        });
  }

  /// Stream all notifications for a specific user (with limit)
  Stream<List<AppNotification>> streamNotifications(
    String companyId,
    String userId, {
    int limit = 50,
  }) {
    return FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = _convertTimestamps(doc.data());
            data['id'] = doc.id;
            return AppNotification.fromJson(data);
          }).toList();
        });
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
