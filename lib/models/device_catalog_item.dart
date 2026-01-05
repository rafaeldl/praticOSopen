import 'package:cloud_firestore/cloud_firestore.dart';

class DeviceCatalogItem {
  String? id;
  String? brandId; // Referência à brand
  String brand; // Desnormalizado (performance)
  String model;
  List<String> variants; // Ex: ["9000 BTUs", "12000 BTUs"]
  String searchKey; // Texto para busca (lowercase)
  int usageCount; // Quantas vezes foi usado
  DateTime? createdAt;
  DateTime? updatedAt;

  DeviceCatalogItem({
    this.id,
    this.brandId,
    required this.brand,
    required this.model,
    this.variants = const [],
    required this.searchKey,
    this.usageCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory DeviceCatalogItem.fromJson(Map<String, dynamic> json) {
    return DeviceCatalogItem(
      id: json['id'],
      brandId: json['brandId'],
      brand: json['brand'] ?? '',
      model: json['model'] ?? '',
      variants: List<String>.from(json['variants'] ?? []),
      searchKey: json['searchKey'] ?? '',
      usageCount: json['usageCount'] ?? 0,
      createdAt: json['createdAt']?.toDate(),
      updatedAt: json['updatedAt']?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (brandId != null) 'brandId': brandId,
      'brand': brand,
      'model': model,
      'variants': variants,
      'searchKey': searchKey,
      'usageCount': usageCount,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Gera searchKey a partir dos dados
  static String generateSearchKey(String brand, String model) {
    return '$brand $model'.toLowerCase();
  }

  @override
  String toString() => '$brand $model';
}
