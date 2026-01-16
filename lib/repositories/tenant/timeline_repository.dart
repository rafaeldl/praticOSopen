import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/timeline_event.dart';

class TimelineRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _getCollection(String companyId, String orderId) {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('orders')
        .doc(orderId)
        .collection('timeline');
  }

  /// Busca a timeline de uma OS.
  Stream<List<TimelineEvent>> getTimeline(String companyId, String orderId, {bool isInternal = true}) {
    Query<Map<String, dynamic>> query = _getCollection(companyId, orderId).orderBy('createdAt', descending: true);

    // Filter out deleted events
    query = query.where('isDeleted', isEqualTo: false);

    if (!isInternal) {
      query = query.where('visibility', isEqualTo: 'customer');
    }

    return query.snapshots().map((snap) {
      return snap.docs.map((doc) => TimelineEvent.fromJson({...doc.data(), 'id': doc.id})).toList();
    });
  }

  /// Cria um novo evento na timeline e atualiza a OS.
  Future<void> createEvent(
    String companyId,
    String orderId,
    TimelineEvent event, {
    List<String>? notifyUserIds,
  }) async {
    final batch = _db.batch();

    // 1. Criar Evento
    final eventRef = _getCollection(companyId, orderId).doc();
    final eventData = event.toJson();
    eventData.remove('id');
    batch.set(eventRef, eventData);

    // 2. Atualizar OS (Last Activity)
    final orderRef = _db.collection('companies').doc(companyId).collection('orders').doc(orderId);

    final Map<String, dynamic> updates = {
      'lastActivity': OrderLastActivity(
        type: event.type.toString().split('.').last,
        icon: _getIconForEventType(event.type),
        preview: _getPreviewForEvent(event),
        authorId: event.author?.id,
        authorName: event.author?.name,
        createdAt: event.createdAt,
        visibility: event.visibility,
      ).toJson(),
    };

    // 3. Incrementar Contadores (Se houver usuários a notificar)
    if (notifyUserIds != null) {
      final Map<String, dynamic> unreadUpdates = {};
      for (final userId in notifyUserIds) {
        // Ignorar o próprio autor
        if (userId == event.author?.id) continue;
        unreadUpdates[userId] = FieldValue.increment(1);
      }
      if (unreadUpdates.isNotEmpty) {
        updates['unreadCounts'] = unreadUpdates;
      }
    }

    // Use SetOptions(merge: true) to safely create unreadCounts if it doesn't exist
    batch.set(orderRef, updates, SetOptions(merge: true));

    await batch.commit();
  }

  /// Marca a timeline como lida para um usuário.
  Future<void> markAsRead(String companyId, String orderId, String userId) async {
    final orderRef = _db.collection('companies').doc(companyId).collection('orders').doc(orderId);

    // Zera o contador na OS de forma segura
    await orderRef.set({
      'unreadCounts': {userId: 0}
    }, SetOptions(merge: true));
  }

  String _getIconForEventType(TimelineEventType type) {
    switch (type) {
      case TimelineEventType.comment: return '💬';
      case TimelineEventType.status_change: return '🔄';
      case TimelineEventType.photos_added: return '📷';
      case TimelineEventType.service_added: return '🛠️';
      case TimelineEventType.product_added: return '📦';
      case TimelineEventType.form_completed: return '📝';
      case TimelineEventType.payment_received: return '💰';
      case TimelineEventType.due_date_alert: return '⏰';
      case TimelineEventType.assignment_change: return '👤';
      default: return '🔹';
    }
  }

  String _getPreviewForEvent(TimelineEvent event) {
    final author = event.author?.name.split(' ').first ?? 'Alguém';

    switch (event.type) {
      case TimelineEventType.comment:
        return '$author: ${event.data['text'] ?? 'Comentou'}';
      case TimelineEventType.status_change:
        return '$author alterou status para ${event.data['newStatus'] ?? '...'}';
      case TimelineEventType.photos_added:
        final count = event.data['count'] ?? 1;
        return '$author adicionou $count foto(s)';
      case TimelineEventType.service_added:
        return '$author adicionou serviço';
      case TimelineEventType.product_added:
        return '$author adicionou produto';
      case TimelineEventType.form_completed:
        return '$author preencheu formulário';
      case TimelineEventType.payment_received:
        return 'Pagamento recebido';
      case TimelineEventType.due_date_alert:
        return 'Prazo de entrega próximo';
      case TimelineEventType.assignment_change:
        return 'Responsável alterado';
      default:
        return '$author atualizou a OS';
    }
  }
}
