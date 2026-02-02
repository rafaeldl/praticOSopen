import 'package:json_annotation/json_annotation.dart';
import 'package:praticos/models/base.dart';
import 'package:praticos/models/base_audit_company.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/models/user.dart';

part 'app_notification.g.dart';

/// Notification types matching backend notification.service.ts
class NotificationType {
  static const orderApproved = 'order_approved';
  static const orderRejected = 'order_rejected';
  static const newComment = 'new_comment';
  static const statusChanged = 'status_changed';
  static const orderRated = 'order_rated';
}

/// In-app notification stored in Firestore
/// Path: /companies/{companyId}/notifications/{notificationId}
@JsonSerializable(explicitToJson: true)
class AppNotification extends BaseAuditCompany {
  /// Notification title
  String? title;

  /// Notification body/message
  String? body;

  /// Notification type (see NotificationType constants)
  String? type;

  /// Related order ID for navigation
  String? orderId;

  /// Related order number for display
  String? orderNumber;

  /// Whether the notification has been read
  bool? read;

  /// When the notification was read
  DateTime? readAt;

  /// User ID who should see this notification
  String? recipientId;

  /// Additional payload data
  Map<String, dynamic>? data;

  AppNotification();

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$AppNotificationToJson(this);

  AppNotificationAggr toAggr() => _$AppNotificationAggrFromJson(toJson());
}

/// Lightweight aggregate for embedding in other documents
@JsonSerializable()
class AppNotificationAggr extends Base {
  String? title;
  String? type;
  bool? read;

  AppNotificationAggr();

  factory AppNotificationAggr.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationAggrFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$AppNotificationAggrToJson(this);
}
