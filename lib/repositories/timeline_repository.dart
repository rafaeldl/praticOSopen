import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/timeline_event.dart';
import 'package:praticos/global.dart';

class TimelineRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- References ---

  CollectionReference<Map<String, dynamic>> _timelineRef(
    String companyId,
    String orderId,
  ) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('orders')
        .doc(orderId)
        .collection('timeline');
  }

  DocumentReference<Map<String, dynamic>> _orderRef(
    String companyId,
    String orderId,
  ) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('orders')
        .doc(orderId);
  }

  // --- Queries ---

  /// Stream of events for TEAM (all events)
  Stream<List<TimelineEvent>> getTimeline(String companyId, String orderId) {
    return _timelineRef(companyId, orderId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                TimelineEvent.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Stream of events for CUSTOMER (public only)
  Stream<List<TimelineEvent>> getCustomerTimeline(
      String companyId, String orderId) {
    return _timelineRef(companyId, orderId)
        .where('visibility', isEqualTo: 'customer')
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                TimelineEvent.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  // --- Create Events ---

  /// Create generic event
  Future<TimelineEvent> createEvent(
    String companyId,
    String orderId,
    TimelineEvent event,
  ) async {
    final docRef =
        await _timelineRef(companyId, orderId).add(event.toJson());
    event.id = docRef.id;

    await _updateLastActivity(companyId, orderId, event);
    await _incrementUnreadCounts(companyId, orderId, event.author?.id);

    return event;
  }

  /// Send comment (collaborator)
  Future<TimelineEvent> sendComment(
    String companyId,
    String orderId,
    String text, {
    List<TimelineAttachment>? attachments,
    bool isPublic = false,
  }) async {
    final currentUser = Global.userAggr;

    final event = TimelineEvent(
      type: 'comment',
      visibility: isPublic ? 'customer' : 'internal',
      author: TimelineAuthor(
        id: currentUser?.id,
        name: currentUser?.name,
        photoUrl: currentUser?.photo,
        type: 'collaborator',
      ),
      data: TimelineEventData(
        text: text,
        attachments: attachments,
      ),
      readBy: [currentUser?.id ?? ''],
      mentions: _parseMentions(text),
      createdAt: DateTime.now(),
      isDeleted: false,
    );

    return createEvent(companyId, orderId, event);
  }

  /// Send comment (customer via portal)
  Future<TimelineEvent> sendCustomerComment(
    String companyId,
    String orderId,
    String text,
    String customerName,
  ) async {
    final event = TimelineEvent(
      type: 'comment',
      visibility: 'customer',
      author: TimelineAuthor(
        id: 'customer',
        name: customerName,
        type: 'customer',
      ),
      data: TimelineEventData(text: text),
      readBy: [],
      mentions: [],
      createdAt: DateTime.now(),
      isDeleted: false,
    );

    return createEvent(companyId, orderId, event);
  }

  /// Log: Status change (always public)
  Future<void> logStatusChange(
    String companyId,
    String orderId,
    String oldStatus,
    String newStatus, {
    String? reason,
  }) async {
    final currentUser = Global.userAggr;

    final event = TimelineEvent(
      type: 'status_change',
      visibility: 'customer',
      author: TimelineAuthor(
        id: currentUser?.id,
        name: currentUser?.name,
        type: 'collaborator',
      ),
      data: TimelineEventData(
        oldStatus: oldStatus,
        newStatus: newStatus,
        reason: reason,
      ),
      readBy: [currentUser?.id ?? ''],
      mentions: [],
      createdAt: DateTime.now(),
      isDeleted: false,
    );

    await createEvent(companyId, orderId, event);
  }

  /// Log: Photos added (public by default)
  Future<void> logPhotosAdded(
    String companyId,
    String orderId,
    List<String> photoUrls, {
    String? caption,
    bool isPublic = true,
  }) async {
    final currentUser = Global.userAggr;

    final event = TimelineEvent(
      type: 'photos_added',
      visibility: isPublic ? 'customer' : 'internal',
      author: TimelineAuthor(
        id: currentUser?.id,
        name: currentUser?.name,
        type: 'collaborator',
      ),
      data: TimelineEventData(
        photoUrls: photoUrls,
        caption: caption,
      ),
      readBy: [currentUser?.id ?? ''],
      mentions: [],
      createdAt: DateTime.now(),
      isDeleted: false,
    );

    await createEvent(companyId, orderId, event);
  }

  /// Log: Service added (internal, visible after approval)
  Future<void> logServiceAdded(
    String companyId,
    String orderId,
    String serviceName,
    double value, {
    String? description,
    bool isPublic = false,
  }) async {
    final currentUser = Global.userAggr;

    final event = TimelineEvent(
      type: 'service_added',
      visibility: isPublic ? 'customer' : 'internal',
      author: TimelineAuthor(
        id: currentUser?.id,
        name: currentUser?.name,
        type: 'collaborator',
      ),
      data: TimelineEventData(
        serviceName: serviceName,
        serviceValue: value,
        description: description,
      ),
      readBy: [currentUser?.id ?? ''],
      mentions: [],
      createdAt: DateTime.now(),
      isDeleted: false,
    );

    await createEvent(companyId, orderId, event);
  }

  /// Log: Product added (internal, visible after approval)
  Future<void> logProductAdded(
    String companyId,
    String orderId,
    String productName,
    int quantity,
    double unitPrice, {
    bool isPublic = false,
  }) async {
    final currentUser = Global.userAggr;

    final event = TimelineEvent(
      type: 'product_added',
      visibility: isPublic ? 'customer' : 'internal',
      author: TimelineAuthor(
        id: currentUser?.id,
        name: currentUser?.name,
        type: 'collaborator',
      ),
      data: TimelineEventData(
        productName: productName,
        quantity: quantity,
        unitPrice: unitPrice,
        totalPrice: quantity * unitPrice,
      ),
      readBy: [currentUser?.id ?? ''],
      mentions: [],
      createdAt: DateTime.now(),
      isDeleted: false,
    );

    await createEvent(companyId, orderId, event);
  }

  /// Log: Form/Checklist completed (internal)
  Future<void> logFormCompleted(
    String companyId,
    String orderId,
    String formName,
    String formId,
    int totalItems,
  ) async {
    final currentUser = Global.userAggr;

    final event = TimelineEvent(
      type: 'form_completed',
      visibility: 'internal',
      author: TimelineAuthor(
        id: currentUser?.id,
        name: currentUser?.name,
        type: 'collaborator',
      ),
      data: TimelineEventData(
        formName: formName,
        formId: formId,
        totalItems: totalItems,
        completedItems: totalItems,
      ),
      readBy: [currentUser?.id ?? ''],
      mentions: [],
      createdAt: DateTime.now(),
      isDeleted: false,
    );

    await createEvent(companyId, orderId, event);
  }

  /// Log: Payment received (always public)
  Future<void> logPaymentReceived(
    String companyId,
    String orderId,
    double amount,
    String method,
    double orderTotal,
    double totalPaid,
  ) async {
    final currentUser = Global.userAggr;

    final event = TimelineEvent(
      type: 'payment_received',
      visibility: 'customer',
      author: TimelineAuthor(
        id: currentUser?.id,
        name: currentUser?.name,
        type: 'collaborator',
      ),
      data: TimelineEventData(
        amount: amount,
        method: method,
        orderTotal: orderTotal,
        totalPaid: totalPaid,
        remaining: orderTotal - totalPaid,
      ),
      readBy: [currentUser?.id ?? ''],
      mentions: [],
      createdAt: DateTime.now(),
      isDeleted: false,
    );

    await createEvent(companyId, orderId, event);
  }

  /// Log: Order created (public)
  Future<void> logOrderCreated(
    String companyId,
    String orderId, {
    String? customerName,
    String? customerPhone,
    String? deviceName,
    String? deviceSerial,
  }) async {
    final currentUser = Global.userAggr;

    final event = TimelineEvent(
      type: 'order_created',
      visibility: 'customer',
      author: TimelineAuthor(
        id: currentUser?.id,
        name: currentUser?.name,
        type: 'collaborator',
      ),
      data: TimelineEventData(
        customerName: customerName,
        customerPhone: customerPhone,
        deviceName: deviceName,
        deviceSerial: deviceSerial,
      ),
      readBy: [currentUser?.id ?? ''],
      mentions: [],
      createdAt: DateTime.now(),
      isDeleted: false,
    );

    await createEvent(companyId, orderId, event);
  }

  /// Log: Assignment change (internal)
  Future<void> logAssignmentChange(
    String companyId,
    String orderId, {
    String? oldAssigneeId,
    String? oldAssigneeName,
    String? newAssigneeId,
    String? newAssigneeName,
  }) async {
    final currentUser = Global.userAggr;

    final event = TimelineEvent(
      type: 'assignment_change',
      visibility: 'internal',
      author: TimelineAuthor(
        id: currentUser?.id,
        name: currentUser?.name,
        type: 'collaborator',
      ),
      data: TimelineEventData(
        oldAssignee: oldAssigneeId != null
            ? TimelineAuthor(id: oldAssigneeId, name: oldAssigneeName)
            : null,
        newAssignee: newAssigneeId != null
            ? TimelineAuthor(id: newAssigneeId, name: newAssigneeName)
            : null,
      ),
      readBy: [currentUser?.id ?? ''],
      mentions: [],
      createdAt: DateTime.now(),
      isDeleted: false,
    );

    await createEvent(companyId, orderId, event);
  }

  /// Log: Device change (internal)
  Future<void> logDeviceChange(
    String companyId,
    String orderId, {
    String? oldDeviceName,
    String? oldDeviceSerial,
    String? newDeviceName,
    String? newDeviceSerial,
  }) async {
    final currentUser = Global.userAggr;

    final event = TimelineEvent(
      type: 'device_change',
      visibility: 'internal',
      author: TimelineAuthor(
        id: currentUser?.id,
        name: currentUser?.name,
        type: 'collaborator',
      ),
      data: TimelineEventData(
        oldDeviceName: oldDeviceName,
        oldDeviceSerial: oldDeviceSerial,
        newDeviceName: newDeviceName,
        newDeviceSerial: newDeviceSerial,
      ),
      readBy: [currentUser?.id ?? ''],
      mentions: [],
      createdAt: DateTime.now(),
      isDeleted: false,
    );

    await createEvent(companyId, orderId, event);
  }

  // --- Read Status ---

  /// Mark all as read for a user
  Future<void> markAllAsRead(
    String companyId,
    String orderId,
    String userId,
  ) async {
    final batch = _firestore.batch();

    final unreadDocs = await _timelineRef(companyId, orderId)
        .where('isDeleted', isEqualTo: false)
        .get();

    for (final doc in unreadDocs.docs) {
      final readBy = List<String>.from(doc.data()['readBy'] ?? []);
      if (!readBy.contains(userId)) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([userId]),
        });
      }
    }

    batch.update(_orderRef(companyId, orderId), {
      'unreadCounts.$userId': 0,
    });

    await batch.commit();
  }

  // --- Customer Token ---

  /// Generate unique token for customer
  Future<String> generateCustomerToken(
      String companyId, String orderId) async {
    final token = _generateToken();

    // Save in order
    await _orderRef(companyId, orderId).update({
      'customerToken': token,
    });

    // Create index for lookup
    await _firestore.collection('customerTokens').doc(token).set({
      'companyId': companyId,
      'orderId': orderId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return token;
  }

  /// Resolve token to companyId/orderId
  Future<Map<String, String>?> resolveCustomerToken(String token) async {
    final doc =
        await _firestore.collection('customerTokens').doc(token).get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    return {
      'companyId': data['companyId'] as String,
      'orderId': data['orderId'] as String,
    };
  }

  // --- Private Helpers ---

  Future<void> _updateLastActivity(
    String companyId,
    String orderId,
    TimelineEvent event,
  ) async {
    final currentUserId = Global.userAggr?.id;
    final isMyEvent = event.author?.id == currentUserId;
    final isCustomerEvent = event.author?.type == 'customer';

    String preview = '';
    String icon = event.icon;
    String? authorName = isMyEvent ? 'Você' : event.author?.name;

    if (isCustomerEvent) {
      authorName = '${event.author?.name} (cliente)';
    }

    switch (event.type) {
      case 'comment':
        preview = '$authorName: ${_truncate(event.data?.text ?? '', 40)}';
        break;
      case 'photos_added':
        final count = event.data?.photoUrls?.length ?? 0;
        preview = '$authorName adicionou $count foto${count > 1 ? 's' : ''}';
        break;
      case 'status_change':
        preview =
            '$authorName: ${event.data?.oldStatus} → ${event.data?.newStatus}';
        break;
      case 'service_added':
        preview = 'Serviço: ${event.data?.serviceName}';
        break;
      case 'product_added':
        preview =
            'Produto: ${event.data?.productName} (${event.data?.quantity}x)';
        break;
      case 'form_completed':
        preview = '$authorName concluiu ${event.data?.formName}';
        break;
      case 'payment_received':
        preview =
            'Pagamento: R\$ ${event.data?.amount?.toStringAsFixed(0)} via ${event.data?.method}';
        break;
      case 'due_date_alert':
        final days = event.data?.daysRemaining ?? 0;
        final isOverdue = event.data?.isOverdue ?? false;
        if (isOverdue) {
          preview = '🔴 Prazo vencido há ${-days} dias!';
          icon = '🔴';
        } else if (days == 0) {
          preview = '⚠️ Prazo vence hoje!';
        } else {
          preview = '⚠️ Prazo vence em $days dia${days > 1 ? 's' : ''}';
        }
        authorName = null;
        break;
      case 'assignment_change':
        preview = 'Atribuído a ${event.data?.newAssignee?.name}';
        break;
      case 'order_created':
        preview = 'OS criada';
        authorName = null;
        break;
      default:
        preview = 'Nova atividade';
    }

    await _orderRef(companyId, orderId).update({
      'lastActivity': {
        'type': event.type,
        'icon': icon,
        'preview': preview,
        'authorId': event.author?.id,
        'authorName': authorName,
        'createdAt': FieldValue.serverTimestamp(),
        'visibility': event.visibility,
      },
    });
  }

  Future<void> _incrementUnreadCounts(
    String companyId,
    String orderId,
    String? authorId,
  ) async {
    final memberships = await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('memberships')
        .get();

    final updates = <String, dynamic>{};

    for (final member in memberships.docs) {
      if (member.id != authorId) {
        updates['unreadCounts.${member.id}'] = FieldValue.increment(1);
      }
    }

    if (updates.isNotEmpty) {
      await _orderRef(companyId, orderId).update(updates);
    }
  }

  List<String> _parseMentions(String text) {
    final regex = RegExp(r'@(\w+)');
    return regex.allMatches(text).map((m) => m.group(1) ?? '').toList();
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  String _generateToken() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
    final random = Random.secure();
    var token = '';
    for (var i = 0; i < 8; i++) {
      token += chars[random.nextInt(chars.length)];
    }
    return token;
  }
}
