import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/models/order_form.dart';

class FormsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Busca templates de formulários disponíveis (Globais do Segmento + Da Empresa)
  Future<List<FormDefinition>> getAvailableTemplates(
      String segmentId, String? companyId) async {
    List<FormDefinition> templates = [];

    // 1. Templates Globais do Segmento
    try {
      final segmentSnapshot = await _db
          .collection('segments')
          .doc(segmentId)
          .collection('forms')
          .where('isActive', isEqualTo: true)
          .get();

      templates.addAll(segmentSnapshot.docs
          .map((doc) => _definitionFromJson(doc.id, doc.data()))
          .toList());
    } catch (e) {
      print('Erro ao buscar templates globais: $e');
    }

    // 2. Templates da Empresa (se houver companyId)
    if (companyId != null && companyId.isNotEmpty) {
      try {
        final companySnapshot = await _db
            .collection('companies')
            .doc(companyId)
            .collection('forms')
            .where('isActive', isEqualTo: true)
            .get();

        templates.addAll(companySnapshot.docs
            .map((doc) => _definitionFromJson(doc.id, doc.data()))
            .toList());
      } catch (e) {
        print('Erro ao buscar templates da empresa: $e');
      }
    }

    return templates;
  }

  /// Busca formulários vinculados a uma OS (tempo real)
  Stream<List<OrderForm>> getOrderForms(String orderId) {
    return _db
        .collection('orders')
        .doc(orderId)
        .collection('forms')
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _orderFormFromJson(doc.id, doc.data()))
            .toList());
  }

  /// Adiciona um novo formulário à OS baseado em um template
  Future<void> addFormToOrder(String orderId, FormDefinition template) async {
    final orderForm = OrderForm(
      id: '', // Será gerado pelo Firestore
      formDefinitionId: template.id,
      title: template.title,
      items: template.items, // Copia os itens para congelar a versão
      status: FormStatus.pending,
      startedAt: DateTime.now(),
      updatedAt: DateTime.now(),
      responses: [],
    );

    final data = orderForm.toJson();
    data.remove('id'); // Remove ID para o Firestore gerar um novo

    await _db.collection('orders').doc(orderId).collection('forms').add(data);
  }

  /// Salva a resposta de um item do formulário
  Future<void> saveResponse(
      String orderId, String formId, FormResponse response) async {
    final formRef = _db
        .collection('orders')
        .doc(orderId)
        .collection('forms')
        .doc(formId);

    return _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(formRef);
      if (!snapshot.exists) return;

      final orderForm = _orderFormFromJson(snapshot.id, snapshot.data()!);

      // Atualiza ou adiciona a resposta na lista
      final index =
          orderForm.responses.indexWhere((r) => r.itemId == response.itemId);
      if (index >= 0) {
        orderForm.responses[index] = response;
      } else {
        orderForm.responses.add(response);
      }

      // Verifica progresso simples: se começou a responder, muda para in_progress
      if (orderForm.status == FormStatus.pending &&
          orderForm.responses.isNotEmpty) {
        // Não mudamos automaticamente para completed, deixamos o usuário finalizar
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
      String orderId, String formId, FormStatus status) async {
    final Map<String, dynamic> updateData = {
      'status': _statusToString(status),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    if (status == FormStatus.completed) {
      updateData['completedAt'] = DateTime.now().toIso8601String();
    }

    await _db
        .collection('orders')
        .doc(orderId)
        .collection('forms')
        .doc(formId)
        .update(updateData);
  }

  // --- Helpers ---

  String _statusToString(FormStatus status) {
    // Mapeamento manual para garantir compatibilidade com o @JsonValue do model
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
