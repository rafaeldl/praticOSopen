import 'package:cloud_firestore/cloud_firestore.dart';

enum TimelineEventType {
  comment,
  status_change,
  photos_added,
  service_added,
  product_added,
  form_completed,
  payment_received,
  due_date_alert,
  assignment_change,
}

class TimelineEventAuthor {
  final String id;
  final String name;
  final String type; // 'collaborator' | 'customer' | 'system'
  final String? photoUrl;

  TimelineEventAuthor({
    required this.id,
    required this.name,
    required this.type,
    this.photoUrl,
  });

  factory TimelineEventAuthor.fromJson(Map<String, dynamic> json) {
    return TimelineEventAuthor(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      photoUrl: json['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'photoUrl': photoUrl,
    };
  }
}

class TimelineEvent {
  String? id;
  final TimelineEventType type;
  final String visibility; // 'internal' | 'customer'
  final TimelineEventAuthor? author;
  final Map<String, dynamic> data;
  final List<String> readBy;
  final DateTime createdAt;
  final bool isDeleted;

  TimelineEvent({
    this.id,
    required this.type,
    required this.visibility,
    this.author,
    required this.data,
    required this.readBy,
    required this.createdAt,
    this.isDeleted = false,
  });

  factory TimelineEvent.fromJson(Map<String, dynamic> json) {
    // Handle createdAt: can be Timestamp or String (ISO8601) or null
    DateTime createdDate;
    if (json['createdAt'] is Timestamp) {
      createdDate = (json['createdAt'] as Timestamp).toDate();
    } else if (json['createdAt'] is String) {
      createdDate = DateTime.parse(json['createdAt'] as String);
    } else {
      createdDate = DateTime.now(); // Fallback
    }

    return TimelineEvent(
      id: json['id'] as String?,
      type: TimelineEventType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => TimelineEventType.comment,
      ),
      visibility: json['visibility'] as String? ?? 'internal',
      author: json['author'] != null
          ? TimelineEventAuthor.fromJson(json['author'] as Map<String, dynamic>)
          : null,
      data: json['data'] as Map<String, dynamic>? ?? {},
      readBy: (json['readBy'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      createdAt: createdDate,
      isDeleted: json['isDeleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'type': type.toString().split('.').last,
      'visibility': visibility,
      'author': author?.toJson(),
      'data': data,
      'readBy': readBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'isDeleted': isDeleted,
    };
  }
}
