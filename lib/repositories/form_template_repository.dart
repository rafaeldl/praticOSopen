import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/repositories/repository.dart';

class FormTemplateRepository extends Repository<FormDefinition> {
  static String collectionName = 'form_templates';

  FormTemplateRepository() : super(collectionName);

  @override
  FormDefinition fromJson(data) {
    final map = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data);

    // Normaliza campos legados: name -> title
    if (map['title'] == null && map['name'] != null) {
      map['title'] = map['name'];
    }

    // Normaliza campos legados: fields -> items
    if (map['items'] == null && map['fields'] != null) {
      map['items'] = map['fields'];
    }

    // Garante que todos os items tenham IDs válidos (string)
    if (map['items'] is List) {
      final items = map['items'] as List;
      for (int i = 0; i < items.length; i++) {
        if (items[i] is Map<String, dynamic>) {
          final item = items[i] as Map<String, dynamic>;
          final itemId = item['id'];
          if (itemId == null) {
            item['id'] = FirebaseFirestore.instance.collection('tmp').doc().id;
          } else if (itemId is! String) {
            item['id'] = itemId.toString();
          } else if (itemId.isEmpty) {
            item['id'] = FirebaseFirestore.instance.collection('tmp').doc().id;
          }

          // Normaliza requiresPhoto -> allowPhotos
          if (item['allowPhotos'] == null && item['requiresPhoto'] != null) {
            item['allowPhotos'] = item['requiresPhoto'];
          }
        }
      }
    }

    return FormDefinition.fromJson(map);
  }

  @override
  Map<String, dynamic> toJson(FormDefinition template) => template.toJson();
}
