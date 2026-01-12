import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a value that accumulates over time for reuse in forms.
///
/// Used for fields like device categories, brands, service categories, etc.
/// Supports hierarchical grouping (e.g., models grouped by brand).
class AccumulatedValue {
  String? id;
  String value;
  String searchKey;
  int usageCount;
  String? groupId; // Parent value ID for hierarchical filtering
  String? groupValue; // Parent value (denormalized for display)
  DateTime? createdAt;
  DateTime? updatedAt;

  AccumulatedValue({
    this.id,
    required this.value,
    String? searchKey,
    this.usageCount = 0,
    this.groupId,
    this.groupValue,
    this.createdAt,
    this.updatedAt,
  }) : searchKey = searchKey ?? value.toLowerCase();

  factory AccumulatedValue.fromJson(Map<String, dynamic> json) {
    return AccumulatedValue(
      id: json['id'],
      value: json['value'] ?? '',
      searchKey: json['searchKey'] ?? '',
      usageCount: json['usageCount'] ?? 0,
      groupId: json['groupId'],
      groupValue: json['groupValue'],
      createdAt: json['createdAt']?.toDate(),
      updatedAt: json['updatedAt']?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'value': value,
      'searchKey': searchKey,
      'usageCount': usageCount,
      if (groupId != null) 'groupId': groupId,
      if (groupValue != null) 'groupValue': groupValue,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Creates a copy with updated fields
  AccumulatedValue copyWith({
    String? id,
    String? value,
    String? searchKey,
    int? usageCount,
    String? groupId,
    String? groupValue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AccumulatedValue(
      id: id ?? this.id,
      value: value ?? this.value,
      searchKey: searchKey ?? this.searchKey,
      usageCount: usageCount ?? this.usageCount,
      groupId: groupId ?? this.groupId,
      groupValue: groupValue ?? this.groupValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccumulatedValue &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
