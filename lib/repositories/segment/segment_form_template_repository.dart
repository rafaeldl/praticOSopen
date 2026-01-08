import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/form_definition.dart';

/// Repository para FormDefinition (templates) de escopo global (segmento).
///
/// Path: `/segments/{segmentId}/forms/{formId}`
class SegmentFormTemplateRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Retorna a referência da collection para um segmento específico.
  /// Path: `/segments/{segmentId}/forms/{formId}`
  CollectionReference<Map<String, dynamic>> _getCollection(String segmentId) {
    return _db.collection('segments').doc(segmentId).collection('forms');
  }

  /// Converte Timestamps do Firestore para ISO8601 strings para o fromJson.
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

  /// Stream de todos os templates do segmento (filtra ativos e ordena em memória).
  Stream<List<FormDefinition>> streamTemplates(String segmentId) {
    return _getCollection(segmentId).snapshots().map((snap) {
      final forms = <FormDefinition>[];
      for (final doc in snap.docs) {
        try {
          final form = _fromJsonID(doc.id, doc.data());
          if (form.isActive) {
            forms.add(form);
          }
        } catch (e) {
          print('[SegmentFormTemplateRepo] Error parsing doc ${doc.id}: $e');
        }
      }
      // Ordena por título em memória
      forms.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      return forms;
    });
  }

  /// Busca templates ativos do segmento.
  Future<List<FormDefinition>> getActiveTemplates(String segmentId) async {
    final snapshot = await _getCollection(segmentId).get();

    final forms = <FormDefinition>[];
    for (final doc in snapshot.docs) {
      try {
        final form = _fromJsonID(doc.id, doc.data());
        if (form.isActive) {
          forms.add(form);
        }
      } catch (e) {
        print('[SegmentFormTemplateRepo] Error parsing doc ${doc.id}: $e');
      }
    }

    // Ordena por título em memória
    forms.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return forms;
  }

  /// Busca um template específico por ID.
  Future<FormDefinition?> getSingle(String segmentId, String id) async {
    final doc = await _getCollection(segmentId).doc(id).get();
    if (!doc.exists) return null;
    return _fromJsonID(id, doc.data()!);
  }

  /// Stream de um template específico.
  Stream<FormDefinition?> streamSingle(String segmentId, String id) {
    return _getCollection(segmentId).doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return _fromJsonID(id, doc.data()!);
    });
  }

  /// Adiciona o ID ao map de dados e converte para FormDefinition.
  FormDefinition _fromJsonID(String? id, Map<String, dynamic> data) {
    final converted = _convertTimestamps(data);
    converted['id'] = id;

    // Normaliza campos legados: name -> title
    if (converted['title'] == null && converted['name'] != null) {
      converted['title'] = converted['name'];
    }

    // Normaliza campos legados: fields -> items
    if (converted['items'] == null && converted['fields'] != null) {
      converted['items'] = converted['fields'];
    }

    // Garante que todos os items tenham IDs válidos (string)
    if (converted['items'] is List) {
      final items = converted['items'] as List;
      for (int i = 0; i < items.length; i++) {
        if (items[i] is Map<String, dynamic>) {
          final item = items[i] as Map<String, dynamic>;
          final itemId = item['id'];
          if (itemId == null) {
            item['id'] = _db.collection('tmp').doc().id;
          } else if (itemId is! String) {
            item['id'] = itemId.toString();
          } else if (itemId.isEmpty) {
            item['id'] = _db.collection('tmp').doc().id;
          }

          // Normaliza requiresPhoto -> allowPhotos
          if (item['allowPhotos'] == null && item['requiresPhoto'] != null) {
            item['allowPhotos'] = item['requiresPhoto'];
          }
        }
      }
    }

    return FormDefinition.fromJson(converted);
  }
}
