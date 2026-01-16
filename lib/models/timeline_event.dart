import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

part 'timeline_event.g.dart';

/// Types of timeline events
enum TimelineEventType {
  orderCreated,
  statusChange,
  photosAdded,
  serviceAdded,
  serviceUpdated,
  serviceRemoved,
  productAdded,
  productUpdated,
  productRemoved,
  formCompleted,
  paymentReceived,
  comment,
  assignmentChange,
  dueDateAlert,
  dueDateChange,
}

/// Timeline event for an order
@JsonSerializable(explicitToJson: true, includeIfNull: false)
class TimelineEvent {
  String? id;
  String? type;

  /// Visibility: 'internal' (team only) or 'customer' (customer can see)
  @JsonKey(defaultValue: 'internal')
  String? visibility;

  TimelineAuthor? author;
  TimelineEventData? data;
  List<String>? readBy;
  List<String>? mentions;

  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  DateTime? createdAt;

  bool? isDeleted;

  TimelineEvent({
    this.id,
    this.type,
    this.visibility = 'internal',
    this.author,
    this.data,
    this.readBy,
    this.mentions,
    this.createdAt,
    this.isDeleted = false,
  });

  factory TimelineEvent.fromJson(Map<String, dynamic> json) =>
      _$TimelineEventFromJson(json);
  Map<String, dynamic> toJson() => _$TimelineEventToJson(this);

  // --- Helpers ---

  bool isReadBy(String userId) => readBy?.contains(userId) ?? false;
  bool get isSystemEvent => author == null || author?.type == 'system';
  bool get isComment => type == 'comment';
  bool get isPublic => visibility == 'customer';
  bool get isFromCustomer => author?.type == 'customer';

  String get icon {
    switch (type) {
      case 'comment':
        return '💬';
      case 'photos_added':
        return '📷';
      case 'status_change':
        return data?.newStatus == 'canceled' ? '❌' : '✅';
      case 'service_added':
      case 'service_updated':
      case 'service_removed':
        return '🔧';
      case 'product_added':
      case 'product_updated':
      case 'product_removed':
        return '📦';
      case 'form_added':
      case 'form_updated':
      case 'form_completed':
        return '📋';
      case 'payment_received':
        return '💰';
      case 'assignment_change':
        return '👤';
      case 'due_date_alert':
        return data?.isOverdue == true ? '🔴' : '⚠️';
      case 'due_date_change':
        return '📅';
      case 'order_created':
        return '📋';
      case 'device_change':
        return '🔄';
      case 'customer_change':
        return '👤';
      default:
        return '🔵';
    }
  }

  // --- Timestamp Converters ---

  static DateTime? _timestampFromJson(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return null;
  }

  static dynamic _timestampToJson(DateTime? date) =>
      date != null ? Timestamp.fromDate(date) : null;
}

/// Author of a timeline event
@JsonSerializable(includeIfNull: false)
class TimelineAuthor {
  String? id;
  String? name;
  String? photoUrl;

  /// Type: 'collaborator', 'customer', 'system'
  @JsonKey(defaultValue: 'collaborator')
  String? type;

  TimelineAuthor({
    this.id,
    this.name,
    this.photoUrl,
    this.type = 'collaborator',
  });

  factory TimelineAuthor.fromJson(Map<String, dynamic> json) =>
      _$TimelineAuthorFromJson(json);
  Map<String, dynamic> toJson() => _$TimelineAuthorToJson(this);

  bool get isCustomer => type == 'customer';
  bool get isCollaborator => type == 'collaborator';
  bool get isSystem => type == 'system';
}

/// Data specific to each event type
@JsonSerializable(explicitToJson: true, includeIfNull: false)
class TimelineEventData {
  // --- Comment ---
  String? text;
  List<TimelineAttachment>? attachments;

  // --- Status Change ---
  String? oldStatus;
  String? newStatus;
  String? reason;

  // --- Photos ---
  List<String>? photoUrls;
  String? caption;

  // --- Service ---
  String? serviceName;
  double? serviceValue;
  double? oldValue;
  double? newValue;
  String? description;

  // --- Product ---
  String? productName;
  int? quantity;
  int? oldQuantity;
  int? newQuantity;
  double? unitPrice;
  double? totalPrice;
  double? oldTotal;
  double? newTotal;

  // --- Form ---
  String? formName;
  String? formId;
  int? totalItems;
  int? completedItems;

  // --- Payment ---
  double? amount;
  String? method;
  double? orderTotal;
  double? totalPaid;
  double? remaining;

  // --- Assignment ---
  TimelineAuthor? oldAssignee;
  TimelineAuthor? newAssignee;

  // --- Due Date ---
  @JsonKey(
      fromJson: TimelineEvent._timestampFromJson,
      toJson: TimelineEvent._timestampToJson)
  DateTime? dueDate;
  @JsonKey(
      fromJson: TimelineEvent._timestampFromJson,
      toJson: TimelineEvent._timestampToJson)
  DateTime? oldDate;
  @JsonKey(
      fromJson: TimelineEvent._timestampFromJson,
      toJson: TimelineEvent._timestampToJson)
  DateTime? newDate;
  int? daysRemaining;
  bool? isOverdue;

  // --- Order Created ---
  String? customerName;
  String? customerPhone;
  String? deviceName;
  String? deviceSerial;

  // --- Device Change ---
  String? oldDeviceName;
  String? oldDeviceSerial;
  String? newDeviceName;
  String? newDeviceSerial;

  // --- Customer Change ---
  String? oldCustomerName;
  String? newCustomerName;

  TimelineEventData({
    this.text,
    this.attachments,
    this.oldStatus,
    this.newStatus,
    this.reason,
    this.photoUrls,
    this.caption,
    this.serviceName,
    this.serviceValue,
    this.oldValue,
    this.newValue,
    this.description,
    this.productName,
    this.quantity,
    this.oldQuantity,
    this.newQuantity,
    this.unitPrice,
    this.totalPrice,
    this.oldTotal,
    this.newTotal,
    this.formName,
    this.formId,
    this.totalItems,
    this.completedItems,
    this.amount,
    this.method,
    this.orderTotal,
    this.totalPaid,
    this.remaining,
    this.oldAssignee,
    this.newAssignee,
    this.dueDate,
    this.oldDate,
    this.newDate,
    this.daysRemaining,
    this.isOverdue,
    this.customerName,
    this.customerPhone,
    this.deviceName,
    this.deviceSerial,
    this.oldDeviceName,
    this.oldDeviceSerial,
    this.newDeviceName,
    this.newDeviceSerial,
    this.oldCustomerName,
    this.newCustomerName,
  });

  factory TimelineEventData.fromJson(Map<String, dynamic> json) =>
      _$TimelineEventDataFromJson(json);
  Map<String, dynamic> toJson() => _$TimelineEventDataToJson(this);
}

/// Attachment (photo/file) in a comment
@JsonSerializable(includeIfNull: false)
class TimelineAttachment {
  String? id;
  String? type; // 'image' | 'file'
  String? url;
  String? thumbnailUrl;
  String? name;
  int? size;

  TimelineAttachment({
    this.id,
    this.type,
    this.url,
    this.thumbnailUrl,
    this.name,
    this.size,
  });

  factory TimelineAttachment.fromJson(Map<String, dynamic> json) =>
      _$TimelineAttachmentFromJson(json);
  Map<String, dynamic> toJson() => _$TimelineAttachmentToJson(this);
}
