import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

part 'last_activity.g.dart';

/// Last activity preview for order list display
@JsonSerializable()
class LastActivity {
  String? type;
  String? icon;
  String? preview;
  String? authorId;
  String? authorName;

  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  DateTime? createdAt;

  /// Visibility: 'internal' or 'customer'
  String? visibility;

  LastActivity({
    this.type,
    this.icon,
    this.preview,
    this.authorId,
    this.authorName,
    this.createdAt,
    this.visibility,
  });

  factory LastActivity.fromJson(Map<String, dynamic> json) =>
      _$LastActivityFromJson(json);
  Map<String, dynamic> toJson() => _$LastActivityToJson(this);

  static DateTime? _timestampFromJson(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return null;
  }

  static dynamic _timestampToJson(DateTime? date) =>
      date != null ? Timestamp.fromDate(date) : null;
}
