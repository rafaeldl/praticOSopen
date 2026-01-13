import 'package:json_annotation/json_annotation.dart';

part 'accumulated_value.g.dart';

/// Represents a value that accumulates over time for reuse in forms.
///
/// Used for fields like device categories, brands, service categories, etc.
/// Supports hierarchical grouping (e.g., models grouped by brand).
@JsonSerializable(explicitToJson: true)
class AccumulatedValue {
  String? id;
  String value;
  String searchKey;
  int usageCount;
  String? group; // Parent value for hierarchical filtering (e.g., brand for models)
  DateTime? createdAt;
  DateTime? updatedAt;

  AccumulatedValue({
    this.id,
    required this.value,
    String? searchKey,
    this.usageCount = 0,
    this.group,
    this.createdAt,
    this.updatedAt,
  }) : searchKey = searchKey ?? value.toLowerCase();

  factory AccumulatedValue.fromJson(Map<String, dynamic> json) =>
      _$AccumulatedValueFromJson(json);

  Map<String, dynamic> toJson() => _$AccumulatedValueToJson(this);

  /// Creates a copy with updated fields
  AccumulatedValue copyWith({
    String? id,
    String? value,
    String? searchKey,
    int? usageCount,
    String? group,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AccumulatedValue(
      id: id ?? this.id,
      value: value ?? this.value,
      searchKey: searchKey ?? this.searchKey,
      usageCount: usageCount ?? this.usageCount,
      group: group ?? this.group,
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
