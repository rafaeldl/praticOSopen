import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/form_definition.dart';

/// Repository para FormDefinition (templates) de escopo global (segmento).
///
/// Path: `/segments/{segmentId}/form_templates/{templateId}`
class SegmentFormTemplateRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Retorna a referência da collection para um segmento específico.
  CollectionReference<Map<String, dynamic>> _getCollection(String segmentId) {
    return _db.collection('segments').doc(segmentId).collection('form_templates');
  }

  /// Stream de todos os templates do segmento ordenados por título.
  Stream<List<FormDefinition>> streamTemplates(String segmentId) {
    return _getCollection(segmentId)
        .orderBy('title')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => _fromJsonID(doc.id, doc.data()))
            .toList());
  }

  /// Busca templates ativos do segmento.
  Future<List<FormDefinition>> getActiveTemplates(String segmentId) async {
    final snapshot = await _getCollection(segmentId)
        .where('isActive', isEqualTo: true)
        .orderBy('title')
        .get();

    return snapshot.docs
        .map((doc) => _fromJsonID(doc.id, doc.data()))
        .toList();
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
    final dataWithId = {...data, 'id': id};
    return FormDefinition.fromJson(dataWithId);
  }
}
