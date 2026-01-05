import 'package:cloud_firestore/cloud_firestore.dart';

class Brand {
  String? id;
  String name;
  int usageCount;
  DateTime? createdAt;

  Brand({
    this.id,
    required this.name,
    this.usageCount = 0,
    this.createdAt,
  });

  factory Brand.fromJson(Map<String, dynamic> json) {
    return Brand(
      id: json['id'],
      name: json['name'] ?? '',
      usageCount: json['usageCount'] ?? 0,
      createdAt: json['createdAt']?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'usageCount': usageCount,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  String get searchKey => name.toLowerCase();

  @override
  String toString() => name;
}
