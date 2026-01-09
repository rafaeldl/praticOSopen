import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/models/order_form.dart';

class FormsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Helper para obter a referência da coleção de formulários da OS
  /// Path: `/companies/{companyId}/orders/{orderId}/forms`
  CollectionReference<Map<String, dynamic>> _getFormsCollection(
      String companyId, String orderId) {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('orders')
        .doc(orderId)
        .collection('forms');
  }

  /// Busca templates de formulários disponíveis SOMENTE da empresa
  /// (Formulários globais devem ser importados antes de usar)
  Future<List<FormDefinition>> getCompanyTemplates(String companyId) async {
    if (companyId.isEmpty) return [];

    try {
      final snapshot = await _db
          .collection('companies')
          .doc(companyId)
          .collection('forms')
          .get();

      // Filtra ativos e ordena por título em memória (evita índice composto)
      final templates = <FormDefinition>[];
      for (final doc in snapshot.docs) {
        try {
          final template = _definitionFromJson(doc.id, doc.data());
          if (template.isActive) {
            templates.add(template);
          }
        } catch (e) {
          // Log silencioso - formulário legado não compatível
        }
      }
      templates.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

      return templates;
    } catch (e) {
      return [];
    }
  }

  /// Busca templates de formulários disponíveis (Globais do Segmento + Da Empresa)
  /// @deprecated Use getCompanyTemplates() para seleção na OS
  Future<List<FormDefinition>> getAvailableTemplates(
      String segmentId, String? companyId) async {
    List<FormDefinition> templates = [];

    // 1. Templates Globais do Segmento
    try {
      final segmentSnapshot = await _db
          .collection('segments')
          .doc(segmentId)
          .collection('forms')
          .get();

      templates.addAll(segmentSnapshot.docs
          .map((doc) => _definitionFromJson(doc.id, doc.data()))
          .where((t) => t.isActive));
    } catch (e) {
      print('Erro ao buscar templates globais: $e');
    }

    // 2. Templates da Empresa
    if (companyId != null && companyId.isNotEmpty) {
      try {
        final companySnapshot = await _db
            .collection('companies')
            .doc(companyId)
            .collection('forms')
            .get();

        templates.addAll(companySnapshot.docs
            .map((doc) => _definitionFromJson(doc.id, doc.data()))
            .where((t) => t.isActive));
      } catch (e) {
        print('Erro ao buscar templates da empresa: $e');
      }
    }

    // Ordena por título em memória
    templates.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    return templates;
  }

  /// Busca formulários vinculados a uma OS (tempo real)
  Stream<List<OrderForm>> getOrderForms(String companyId, String orderId) {
    return _getFormsCollection(companyId, orderId)
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _orderFormFromJson(doc.id, doc.data()))
            .toList());
  }

  /// Adiciona um novo formulário à OS baseado em um template e retorna a instância criada
  Future<OrderForm> addFormToOrder(
      String companyId, String orderId, FormDefinition template) async {
    final orderForm = OrderForm(
      id: '', // Será gerado pelo Firestore
      formDefinitionId: template.id!,
      title: template.title,
      items: template.items,
      status: FormStatus.pending,
      startedAt: DateTime.now(),
      updatedAt: DateTime.now(),
      responses: [],
    );

    final data = orderForm.toJson();
    data.remove('id');

    final docRef = await _getFormsCollection(companyId, orderId).add(data);
    orderForm.id = docRef.id;
    
    return orderForm;
  }

  /// Salva a resposta de um item do formulário
  Future<void> saveResponse(
      String companyId, String orderId, String formId, FormResponse response) async {
    final formRef = _getFormsCollection(companyId, orderId).doc(formId);

    return _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(formRef);
      if (!snapshot.exists) return;

      final orderForm = _orderFormFromJson(snapshot.id, snapshot.data()!);

      final index =
          orderForm.responses.indexWhere((r) => r.itemId == response.itemId);
      if (index >= 0) {
        orderForm.responses[index] = response;
      } else {
        orderForm.responses.add(response);
      }

      if (orderForm.status == FormStatus.pending &&
          orderForm.responses.isNotEmpty) {
        orderForm.status = FormStatus.inProgress;
      }

      transaction.update(formRef, {
        'responses': orderForm.responses.map((e) => e.toJson()).toList(),
        'status': _statusToString(orderForm.status),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    });
  }

  /// Atualiza o status do formulário (ex: Finalizar)
  Future<void> updateStatus(
      String companyId, String orderId, String formId, FormStatus status) async {
    final Map<String, dynamic> updateData = {
      'status': _statusToString(status),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    if (status == FormStatus.completed) {
      updateData['completedAt'] = DateTime.now().toIso8601String();
    }

    await _getFormsCollection(companyId, orderId).doc(formId).update(updateData);
  }

  /// Remove um formulário da OS
  Future<void> deleteOrderForm(String companyId, String orderId, String formId) async {
    await _getFormsCollection(companyId, orderId).doc(formId).delete();
  }

  // --- Helpers ---

  String _statusToString(FormStatus status) {
    switch (status) {
      case FormStatus.pending:
        return 'pending';
      case FormStatus.inProgress:
        return 'in_progress';
      case FormStatus.completed:
        return 'completed';
    }
  }

  FormDefinition _definitionFromJson(String id, Map<String, dynamic> data) {
    final map = Map<String, dynamic>.from(data);
    _convertTimestamp(map, 'createdAt');
    _convertTimestamp(map, 'updatedAt');

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

          // Converte ID numérico para string ou gera novo
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

    return FormDefinition.fromJson({...map, 'id': id});
  }

  OrderForm _orderFormFromJson(String id, Map<String, dynamic> data) {
    final map = Map<String, dynamic>.from(data);
    _convertTimestamp(map, 'startedAt');
    _convertTimestamp(map, 'completedAt');
    _convertTimestamp(map, 'updatedAt');
    return OrderForm.fromJson({...map, 'id': id});
  }

  void _convertTimestamp(Map<String, dynamic> map, String key) {
    if (map[key] is Timestamp) {
      map[key] = (map[key] as Timestamp).toDate().toIso8601String();
    }
  }
}