import 'package:cloud_firestore/cloud_firestore.dart';

enum FormItemType {
  text,
  number,
  select,
  checklist,
  photo_only,
  boolean,
}

class FormItemDefinition {
  String? id;
  String? label;
  FormItemType? type;
  List<String>? options;
  bool? required;
  bool? allowPhotos;

  FormItemDefinition({
    this.id,
    this.label,
    this.type,
    this.options,
    this.required,
    this.allowPhotos,
  });

  FormItemDefinition.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    label = json['label'];
    type = json['type'] != null
        ? FormItemType.values.firstWhere(
            (e) => e.toString().split('.').last == json['type'],
            orElse: () => FormItemType.text)
        : null;
    options =
        json['options'] != null ? List<String>.from(json['options']) : null;
    required = json['required'];
    allowPhotos = json['allowPhotos'];
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'type': type?.toString().split('.').last,
      'options': options,
      'required': required,
      'allowPhotos': allowPhotos,
    };
  }
}

class FormDefinition {
  String? id;
  String? title;
  String? description;
  bool? isActive;
  List<FormItemDefinition>? items;
  DateTime? createdAt;
  DateTime? updatedAt;

  FormDefinition({
    this.id,
    this.title,
    this.description,
    this.isActive,
    this.items,
    this.createdAt,
    this.updatedAt,
  });

  FormDefinition.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    title = json['title'];
    description = json['description'];
    isActive = json['isActive'];
    if (json['items'] != null) {
      items = <FormItemDefinition>[];
      json['items'].forEach((v) {
        items!.add(FormItemDefinition.fromJson(v));
      });
    }
    createdAt = json['createdAt'] is Timestamp
        ? (json['createdAt'] as Timestamp).toDate()
        : json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null;
    updatedAt = json['updatedAt'] is Timestamp
        ? (json['updatedAt'] as Timestamp).toDate()
        : json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isActive': isActive,
      'items': items?.map((v) => v.toJson()).toList(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
