import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:praticos/models/form_definition.dart';
import 'package:praticos/models/order_form.dart';
import 'package:praticos/utils/form_answer_change.dart';

export 'package:praticos/utils/form_answer_change.dart';

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
      String companyId, String orderId, FormDefinition template,
      {String? deviceId}) async {
    final orderForm = OrderForm(
      id: '', // Será gerado pelo Firestore
      formDefinitionId: template.id!,
      title: template.title,
      titleI18n: template.titleI18n, // Copy i18n translations
      items: template.items, // Items already have their i18n fields
      status: FormStatus.pending,
      startedAt: DateTime.now(),
      updatedAt: DateTime.now(),
      responses: [],
      deviceId: deviceId,
    );

    final data = orderForm.toJson();
    data.remove('id');

    final docRef = await _getFormsCollection(companyId, orderId).add(data);
    orderForm.id = docRef.id;

    return orderForm;
  }

  /// How long the answer transaction may wait for the server before the
  /// answer is queued as a plain (offline) write.
  static const Duration responseTransactionTimeout = Duration(seconds: 10);

  /// Whether a failed answer transaction can be retried as a queued write:
  /// no connection or no answer in time. Refusals (rules, missing form) are
  /// real errors, and so is `aborted` (another write on the same checklist,
  /// exactly when a blind write would be most harmful).
  static bool canQueueOffline(Object error) {
    if (error is TimeoutException) return true;
    if (error is FirebaseException) {
      return const {'unavailable', 'deadline-exceeded'}.contains(error.code);
    }
    return false;
  }

  /// Saves one answer ([change]) to a checklist of the order, like the web:
  /// a transaction reads the checklist and changes only that question, and
  /// inside it only the part touched ([applyAnswerChange]). Answers and
  /// photos the web (or another phone) gave meanwhile stay. Returns the
  /// checklist's responses after the change, or null when the answer was
  /// queued offline (or the checklist is gone).
  ///
  /// Without connection transactions fail, so the answer is queued as an
  /// `arrayRemove` of every response to that question in [localKnown] (the
  /// screen's responses before the change, so no copy is left behind) and an
  /// `arrayUnion` of the new one ([queuedAnswerWrite]): only that question,
  /// never the whole list nor the status (it could reopen a checklist
  /// another device finished).
  Future<List<FormResponse>?> saveAnswer(
    String companyId,
    String orderId,
    String formId,
    FormAnswerChange change, {
    List<FormResponse> localKnown = const [],
    FormItemNote? localNote,
  }) async {
    final formRef = _getFormsCollection(companyId, orderId).doc(formId);
    try {
      return await _saveAnswerInTransaction(formRef, change);
    } catch (e) {
      if (!canQueueOffline(e)) rethrow;
      debugPrint('Checklist answer queued offline: $e');
      final write = queuedAnswerWrite(localKnown, change);
      final now = DateTime.now().toIso8601String();
      final batch = _db.batch();
      if (write.removed.isNotEmpty) {
        batch.update(formRef, {
          'responses': FieldValue.arrayRemove(write.removed),
        });
      }
      batch.update(formRef, {
        'responses': FieldValue.arrayUnion([write.added]),
        'updatedAt': now,
        ...photoNoteRemoval(change, localNote),
      });
      // Not awaited: offline the batch completes only once synced.
      unawaited(
        batch.commit().catchError((Object e) {
          debugPrint('Queued checklist answer failed: $e');
        }),
      );
      return null;
    }
  }

  Future<List<FormResponse>?> _saveAnswerInTransaction(
    DocumentReference<Map<String, dynamic>> formRef,
    FormAnswerChange change,
  ) {
    return _db.runTransaction(timeout: responseTransactionTimeout, (
      transaction,
    ) async {
      final snapshot = await transaction.get(formRef);
      if (!snapshot.exists) return null;

      final orderForm = _orderFormFromJson(snapshot.id, snapshot.data()!);
      final write = answerWrite(orderForm, change);
      transaction.update(formRef, write.update);
      return write.responses;
    });
  }

  /// What the answer transaction writes for [change] on [form] as read:
  /// the responses, the status and `updatedAt`, plus the removal of a
  /// removed photo's note ([photoNoteRemoval]). The other notes are never
  /// written here, so saving an answer keeps every note.
  static ({Map<String, dynamic> update, List<FormResponse> responses})
  answerWrite(OrderForm form, FormAnswerChange change) {
    final responses = applyAnswerChange(form.responses, change);
    var status = form.status;
    if (status == FormStatus.pending && responses.isNotEmpty) {
      status = FormStatus.inProgress;
    }
    return (
      update: {
        'responses': responses.map((e) => e.toJson()).toList(),
        'status': _statusName(status),
        'updatedAt': DateTime.now().toIso8601String(),
        ...photoNoteRemoval(change, form.noteOf(change.itemId)),
      },
      responses: responses,
    );
  }

  /// When [change] removes a photo that has a note in [note], the update of
  /// `notes.{itemId}` that takes that note out with it (empty otherwise).
  /// Only for ids that are a plain field name (letters, digits, `_`, `-`),
  /// as every app, web and seed id is.
  static Map<String, dynamic> photoNoteRemoval(
    FormAnswerChange change,
    FormItemNote? note,
  ) {
    if (change is! FormPhotoRemoved || note == null) return const {};
    if (!note.photos.any((p) => p.url == change.url)) return const {};
    if (!_plainFieldName.hasMatch(change.itemId)) return const {};
    final next = note.withoutPhoto(change.url);
    return {
      'notes.${change.itemId}': next.isEmpty
          ? FieldValue.delete()
          : next.toJson(),
    };
  }

  static final RegExp _plainFieldName = RegExp(r'^[A-Za-z0-9_-]+$');

  /// Saves the note of question [itemId] ([note] null or empty: removes it).
  /// Only `notes.{itemId}` and `updatedAt` are written: the answers stay as
  /// they are, whoever saves them. Offline the write is queued (it completes
  /// once synced), so after [responseTransactionTimeout] it is left pending.
  Future<void> saveNote(
    String companyId,
    String orderId,
    String formId,
    String itemId,
    FormItemNote? note,
  ) async {
    final formRef = _getFormsCollection(companyId, orderId).doc(formId);
    final write = formRef.update({
      FieldPath(['notes', itemId]): note == null || note.isEmpty
          ? FieldValue.delete()
          : note.toJson(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
    try {
      await write.timeout(responseTransactionTimeout);
    } on TimeoutException {
      debugPrint('Checklist note queued offline');
      unawaited(
        write.catchError((Object e) {
          debugPrint('Queued checklist note failed: $e');
        }),
      );
    }
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

  String _statusToString(FormStatus status) => _statusName(status);

  static String _statusName(FormStatus status) {
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