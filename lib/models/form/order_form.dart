import 'package:cloud_firestore/cloud_firestore.dart';

class FormResponseItem {
  String? itemId;
  dynamic value;
  List<String>? photoUrls;

  FormResponseItem({
    this.itemId,
    this.value,
    this.photoUrls,
  });

  FormResponseItem.fromJson(Map<String, dynamic> json) {
    itemId = json['itemId'];
    value = json['value'];
    photoUrls =
        json['photoUrls'] != null ? List<String>.from(json['photoUrls']) : [];
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'value': value,
      'photoUrls': photoUrls,
    };
  }
}

class OrderForm {
  String? id;
  String? formDefinitionId;
  String? title;
  String? status; // 'pending' | 'in_progress' | 'completed'
  List<FormResponseItem>? responses;
  DateTime? updatedAt;

  OrderForm({
    this.id,
    this.formDefinitionId,
    this.title,
    this.status,
    this.responses,
    this.updatedAt,
  });

  OrderForm.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    formDefinitionId = json['formDefinitionId'];
    title = json['title'];
    status = json['status'];
    if (json['responses'] != null) {
      responses = <FormResponseItem>[];
      json['responses'].forEach((v) {
        responses!.add(FormResponseItem.fromJson(v));
      });
    }
    updatedAt = json['updatedAt'] is Timestamp
        ? (json['updatedAt'] as Timestamp).toDate()
        : json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'formDefinitionId': formDefinitionId,
      'title': title,
      'status': status,
      'responses': responses?.map((v) => v.toJson()).toList(),
      'updatedAt': updatedAt,
    };
  }
}
