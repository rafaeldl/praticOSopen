import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/repositories/tenant_repository.dart';

/// Repository tenant-aware para FormDefinition (templates).
///
/// Path: `/companies/{companyId}/forms/{templateId}`
class TenantFormTemplateRepository extends TenantRepository<FormDefinition?> {
  TenantFormTemplateRepository() : super('forms');

  Map<String, dynamic> _convertTimestamps(Map<String, dynamic> data) {
    final converted = Map<String, dynamic>.from(data);

    if (converted['createdAt'] is Timestamp) {
      converted['createdAt'] =
          (converted['createdAt'] as Timestamp).toDate().toIso8601String();
    }
    if (converted['updatedAt'] is Timestamp) {
      converted['updatedAt'] =
          (converted['updatedAt'] as Timestamp).toDate().toIso8601String();
    }

    return converted;
  }

  @override
  FormDefinition fromJson(Map<String, dynamic> data) {
    final normalized = _convertTimestamps(data);

    // Normaliza campos legados: name -> title
    if (normalized['title'] == null && normalized['name'] != null) {
      normalized['title'] = normalized['name'];
    }

    // Normaliza campos legados: fields -> items
    if (normalized['items'] == null && normalized['fields'] != null) {
      normalized['items'] = normalized['fields'];
    }

    // Garante que todos os items tenham IDs válidos (string)
    if (normalized['items'] is List) {
      final items = normalized['items'] as List;
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
    return FormDefinition.fromJson(normalized);
  }

  @override
  Map<String, dynamic> toJson(FormDefinition? template) => template!.toJson();

  /// Stream de todos os templates do tenant ordenados por título.
  Stream<List<FormDefinition?>> streamTemplates(String companyId) {
    return streamQueryList(
      companyId,
      orderBy: [OrderBy('title')],
    );
  }

  /// Busca templates ativos do tenant.
  Future<List<FormDefinition?>> getActiveTemplates(String companyId) {
    return getQueryList(
      companyId,
      args: [QueryArgs('isActive', true)],
      orderBy: [OrderBy('title')],
    );
  }
}
