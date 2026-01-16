# Social Features - Guia de Implementação

> Documento otimizado para implementação assistida por IA.
> Referência completa: `docs/SOCIAL_FEATURES_V3_UNIFIED.md`

---

## Visão Geral

**Objetivo:** Transformar a lista de OSs em uma timeline de conversas (estilo WhatsApp), substituindo comunicação externa e permitindo acompanhamento pelo cliente via link mágico.

**Mudança Principal:**
- Tap na OS → Abre **Timeline** (chat) em vez de detalhes
- Detalhes acessíveis via botão (i) no header

---

## Arquitetura

### Estrutura Firestore

```
/companies/{companyId}/
├── orders/{orderId}/
│   ├── ... (campos existentes)
│   ├── customerToken: string              // Token único para link mágico
│   ├── lastActivity: LastActivity         // Agregado para preview na lista
│   ├── unreadCounts: Map<userId, int>     // Contagem de não lidos por usuário
│   └── timeline/{eventId}/                // SUBCOLLECTION
│         ├── type: string
│         ├── visibility: 'internal' | 'customer'
│         ├── author: TimelineAuthor | null
│         ├── data: TimelineEventData
│         ├── readBy: string[]
│         ├── mentions: string[]
│         ├── createdAt: Timestamp
│         └── isDeleted: boolean
│
└── customerTokens/{token}/                // INDEX para lookup rápido
      ├── companyId: string
      ├── orderId: string
      └── createdAt: Timestamp
```

### Índices Firestore (Criar no Console)

```
Collection: companies/{companyId}/orders/{orderId}/timeline

Índice 1 - Query Equipe:
  - isDeleted (ASC) + createdAt (ASC)

Índice 2 - Query Cliente:
  - visibility (ASC) + createdAt (ASC)
```

---

## Modelos de Dados

### 1. TimelineEvent (Dart)

**Arquivo:** `lib/models/timeline_event.dart`

```dart
import 'package:json_annotation/json_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'timeline_event.g.dart';

/// Tipos de eventos na timeline
enum TimelineEventType {
  orderCreated,
  statusChange,
  photosAdded,
  serviceAdded,
  serviceUpdated,
  serviceRemoved,
  productAdded,
  productUpdated,
  productRemoved,
  formCompleted,
  paymentReceived,
  comment,
  assignmentChange,
  dueDateAlert,
  dueDateChange,
}

/// Evento da timeline de uma OS
@JsonSerializable(explicitToJson: true)
class TimelineEvent {
  String? id;
  String? type;

  /// Visibilidade: 'internal' (só equipe) ou 'customer' (cliente vê)
  @JsonKey(defaultValue: 'internal')
  String? visibility;

  TimelineAuthor? author;
  TimelineEventData? data;
  List<String>? readBy;
  List<String>? mentions;

  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  DateTime? createdAt;

  bool? isDeleted;

  TimelineEvent({
    this.id,
    this.type,
    this.visibility = 'internal',
    this.author,
    this.data,
    this.readBy,
    this.mentions,
    this.createdAt,
    this.isDeleted = false,
  });

  factory TimelineEvent.fromJson(Map<String, dynamic> json) =>
      _$TimelineEventFromJson(json);
  Map<String, dynamic> toJson() => _$TimelineEventToJson(this);

  // --- Helpers ---

  bool isReadBy(String userId) => readBy?.contains(userId) ?? false;
  bool get isSystemEvent => author == null || author?.type == 'system';
  bool get isComment => type == 'comment';
  bool get isPublic => visibility == 'customer';
  bool get isFromCustomer => author?.type == 'customer';

  String get icon {
    switch (type) {
      case 'comment': return '💬';
      case 'photos_added': return '📷';
      case 'status_change': return data?.newStatus == 'canceled' ? '❌' : '✅';
      case 'service_added':
      case 'service_updated':
      case 'service_removed': return '🔧';
      case 'product_added':
      case 'product_updated':
      case 'product_removed': return '📦';
      case 'form_completed': return '📋';
      case 'payment_received': return '💰';
      case 'assignment_change': return '👤';
      case 'due_date_alert': return data?.isOverdue == true ? '🔴' : '⚠️';
      case 'due_date_change': return '📅';
      case 'order_created': return '📋';
      default: return '🔵';
    }
  }

  // --- Timestamp Converters ---

  static DateTime? _timestampFromJson(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return null;
  }

  static dynamic _timestampToJson(DateTime? date) =>
      date != null ? Timestamp.fromDate(date) : null;
}

/// Autor de um evento
@JsonSerializable()
class TimelineAuthor {
  String? id;
  String? name;
  String? photoUrl;

  /// Tipo: 'collaborator', 'customer', 'system'
  @JsonKey(defaultValue: 'collaborator')
  String? type;

  TimelineAuthor({
    this.id,
    this.name,
    this.photoUrl,
    this.type = 'collaborator',
  });

  factory TimelineAuthor.fromJson(Map<String, dynamic> json) =>
      _$TimelineAuthorFromJson(json);
  Map<String, dynamic> toJson() => _$TimelineAuthorToJson(this);

  bool get isCustomer => type == 'customer';
  bool get isCollaborator => type == 'collaborator';
  bool get isSystem => type == 'system';
}

/// Dados específicos de cada tipo de evento
@JsonSerializable(explicitToJson: true)
class TimelineEventData {
  // --- Comment ---
  String? text;
  List<TimelineAttachment>? attachments;

  // --- Status Change ---
  String? oldStatus;
  String? newStatus;
  String? reason;

  // --- Photos ---
  List<String>? photoUrls;
  String? caption;

  // --- Service ---
  String? serviceName;
  double? serviceValue;
  double? oldValue;
  double? newValue;
  String? description;

  // --- Product ---
  String? productName;
  int? quantity;
  int? oldQuantity;
  int? newQuantity;
  double? unitPrice;
  double? totalPrice;
  double? oldTotal;
  double? newTotal;

  // --- Form ---
  String? formName;
  String? formId;
  int? totalItems;
  int? completedItems;

  // --- Payment ---
  double? amount;
  String? method;
  double? orderTotal;
  double? totalPaid;
  double? remaining;

  // --- Assignment ---
  TimelineAuthor? oldAssignee;
  TimelineAuthor? newAssignee;

  // --- Due Date ---
  @JsonKey(fromJson: TimelineEvent._timestampFromJson, toJson: TimelineEvent._timestampToJson)
  DateTime? dueDate;
  @JsonKey(fromJson: TimelineEvent._timestampFromJson, toJson: TimelineEvent._timestampToJson)
  DateTime? oldDate;
  @JsonKey(fromJson: TimelineEvent._timestampFromJson, toJson: TimelineEvent._timestampToJson)
  DateTime? newDate;
  int? daysRemaining;
  bool? isOverdue;

  // --- Order Created ---
  String? customerName;
  String? customerPhone;
  String? deviceName;
  String? devicePlate;

  TimelineEventData({
    this.text,
    this.attachments,
    this.oldStatus,
    this.newStatus,
    this.reason,
    this.photoUrls,
    this.caption,
    this.serviceName,
    this.serviceValue,
    this.oldValue,
    this.newValue,
    this.description,
    this.productName,
    this.quantity,
    this.oldQuantity,
    this.newQuantity,
    this.unitPrice,
    this.totalPrice,
    this.oldTotal,
    this.newTotal,
    this.formName,
    this.formId,
    this.totalItems,
    this.completedItems,
    this.amount,
    this.method,
    this.orderTotal,
    this.totalPaid,
    this.remaining,
    this.oldAssignee,
    this.newAssignee,
    this.dueDate,
    this.oldDate,
    this.newDate,
    this.daysRemaining,
    this.isOverdue,
    this.customerName,
    this.customerPhone,
    this.deviceName,
    this.devicePlate,
  });

  factory TimelineEventData.fromJson(Map<String, dynamic> json) =>
      _$TimelineEventDataFromJson(json);
  Map<String, dynamic> toJson() => _$TimelineEventDataToJson(this);
}

/// Anexo (foto/arquivo) em um comentário
@JsonSerializable()
class TimelineAttachment {
  String? id;
  String? type; // 'image' | 'file'
  String? url;
  String? thumbnailUrl;
  String? name;
  int? size;

  TimelineAttachment({
    this.id,
    this.type,
    this.url,
    this.thumbnailUrl,
    this.name,
    this.size,
  });

  factory TimelineAttachment.fromJson(Map<String, dynamic> json) =>
      _$TimelineAttachmentFromJson(json);
  Map<String, dynamic> toJson() => _$TimelineAttachmentToJson(this);
}
```

### 2. LastActivity (Adicionar ao Order)

**Arquivo:** `lib/models/order.dart` (adicionar campos)

```dart
/// Adicionar estes campos à classe Order existente:

/// Token único para link mágico do cliente
String? customerToken;

/// Preview da última atividade (para lista)
LastActivity? lastActivity;

/// Contagem de não lidos por usuário
Map<String, int>? unreadCounts;

/// Helper: obtém contagem de não lidos para um usuário
int getUnreadCount(String userId) => unreadCounts?[userId] ?? 0;

/// Helper: verifica se tem não lidos
bool hasUnread(String userId) => getUnreadCount(userId) > 0;
```

```dart
/// Classe LastActivity (pode ficar no mesmo arquivo ou separado)
@JsonSerializable()
class LastActivity {
  String? type;
  String? icon;
  String? preview;
  String? authorId;
  String? authorName;

  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  DateTime? createdAt;

  LastActivity({
    this.type,
    this.icon,
    this.preview,
    this.authorId,
    this.authorName,
    this.createdAt,
  });

  factory LastActivity.fromJson(Map<String, dynamic> json) =>
      _$LastActivityFromJson(json);
  Map<String, dynamic> toJson() => _$LastActivityToJson(this);

  static DateTime? _timestampFromJson(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return null;
  }

  static dynamic _timestampToJson(DateTime? date) =>
      date != null ? Timestamp.fromDate(date) : null;
}
```

---

## Repository

**Arquivo:** `lib/repositories/timeline_repository.dart`

```dart
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

  /// Stream de eventos para EQUIPE (todos os eventos)
  Stream<List<TimelineEvent>> getTimeline(String companyId, String orderId) {
    return _timelineRef(companyId, orderId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TimelineEvent.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Stream de eventos para CLIENTE (apenas públicos)
  Stream<List<TimelineEvent>> getCustomerTimeline(String companyId, String orderId) {
    return _timelineRef(companyId, orderId)
        .where('visibility', isEqualTo: 'customer')
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TimelineEvent.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  // --- Create Events ---

  /// Criar evento genérico
  Future<TimelineEvent> createEvent(
    String companyId,
    String orderId,
    TimelineEvent event,
  ) async {
    final docRef = await _timelineRef(companyId, orderId).add(event.toJson());
    event.id = docRef.id;

    await _updateLastActivity(companyId, orderId, event);
    await _incrementUnreadCounts(companyId, orderId, event.author?.id);

    return event;
  }

  /// Enviar comentário (colaborador)
  Future<TimelineEvent> sendComment(
    String companyId,
    String orderId,
    String text, {
    List<TimelineAttachment>? attachments,
    bool isPublic = false,
  }) async {
    final currentUser = Global.currentUser;

    final event = TimelineEvent(
      type: 'comment',
      visibility: isPublic ? 'customer' : 'internal',
      author: TimelineAuthor(
        id: currentUser?.id,
        name: currentUser?.name,
        photoUrl: currentUser?.photoUrl,
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

  /// Enviar comentário (cliente via portal)
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

  /// Log: Mudança de status (sempre público)
  Future<void> logStatusChange(
    String companyId,
    String orderId,
    String oldStatus,
    String newStatus, {
    String? reason,
  }) async {
    final currentUser = Global.currentUser;

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

  /// Log: Fotos adicionadas (público por padrão)
  Future<void> logPhotosAdded(
    String companyId,
    String orderId,
    List<String> photoUrls, {
    String? caption,
    bool isPublic = true,
  }) async {
    final currentUser = Global.currentUser;

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

  /// Log: Serviço adicionado (interno, visível após aprovação)
  Future<void> logServiceAdded(
    String companyId,
    String orderId,
    String serviceName,
    double value, {
    String? description,
    bool isPublic = false,
  }) async {
    final currentUser = Global.currentUser;

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

  /// Log: Produto adicionado (interno, visível após aprovação)
  Future<void> logProductAdded(
    String companyId,
    String orderId,
    String productName,
    int quantity,
    double unitPrice, {
    bool isPublic = false,
  }) async {
    final currentUser = Global.currentUser;

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

  /// Log: Formulário/Checklist concluído (interno)
  Future<void> logFormCompleted(
    String companyId,
    String orderId,
    String formName,
    String formId,
    int totalItems,
  ) async {
    final currentUser = Global.currentUser;

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

  /// Log: Pagamento recebido (sempre público)
  Future<void> logPaymentReceived(
    String companyId,
    String orderId,
    double amount,
    String method,
    double orderTotal,
    double totalPaid,
  ) async {
    final currentUser = Global.currentUser;

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

  // --- Read Status ---

  /// Marcar todos como lidos para um usuário
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

  /// Gerar token único para cliente
  Future<String> generateCustomerToken(String companyId, String orderId) async {
    final token = _generateToken();

    // Salvar no order
    await _orderRef(companyId, orderId).update({
      'customerToken': token,
    });

    // Criar índice para lookup
    await _firestore.collection('customerTokens').doc(token).set({
      'companyId': companyId,
      'orderId': orderId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return token;
  }

  /// Resolver token para companyId/orderId
  Future<Map<String, String>?> resolveCustomerToken(String token) async {
    final doc = await _firestore.collection('customerTokens').doc(token).get();
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
    final currentUserId = Global.currentUser?.id;
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
        preview = '$authorName: ${event.data?.oldStatus} → ${event.data?.newStatus}';
        break;
      case 'service_added':
        preview = 'Serviço: ${event.data?.serviceName}';
        break;
      case 'product_added':
        preview = 'Produto: ${event.data?.productName} (${event.data?.quantity}x)';
        break;
      case 'form_completed':
        preview = '$authorName concluiu ${event.data?.formName}';
        break;
      case 'payment_received':
        preview = 'Pagamento: R\$ ${event.data?.amount?.toStringAsFixed(0)} via ${event.data?.method}';
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
      },
    });
  }

  Future<void> _incrementUnreadCounts(
    String companyId,
    String orderId,
    String? authorId,
  ) async {
    final collaborators = await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('collaborators')
        .get();

    final updates = <String, dynamic>{};

    for (final collab in collaborators.docs) {
      if (collab.id != authorId) {
        updates['unreadCounts.${collab.id}'] = FieldValue.increment(1);
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
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    var token = '';
    for (var i = 0; i < 8; i++) {
      token += chars[(random + i * 7) % chars.length];
    }
    return token;
  }
}
```

---

## MobX Store

**Arquivo:** `lib/mobx/timeline_store.dart`

```dart
import 'package:mobx/mobx.dart';
import 'package:praticos/models/timeline_event.dart';
import 'package:praticos/repositories/timeline_repository.dart';
import 'package:praticos/global.dart';

part 'timeline_store.g.dart';

class TimelineStore = _TimelineStore with _$TimelineStore;

abstract class _TimelineStore with Store {
  final TimelineRepository _repository = TimelineRepository();

  @observable
  ObservableStream<List<TimelineEvent>>? timelineStream;

  @observable
  bool isSending = false;

  @observable
  String? error;

  String? _companyId;
  String? _orderId;

  @computed
  List<TimelineEvent> get events => timelineStream?.value ?? [];

  @computed
  int get unreadCount {
    final userId = Global.currentUser?.id;
    if (userId == null) return 0;
    return events.where((e) => !e.isReadBy(userId)).length;
  }

  /// Eventos agrupados por data (para separadores)
  @computed
  Map<String, List<TimelineEvent>> get eventsByDate {
    final grouped = <String, List<TimelineEvent>>{};

    for (final event in events) {
      final dateKey = _formatDateKey(event.createdAt);
      grouped.putIfAbsent(dateKey, () => []).add(event);
    }

    return grouped;
  }

  @action
  void init(String companyId, String orderId) {
    _companyId = companyId;
    _orderId = orderId;

    timelineStream = ObservableStream(
      _repository.getTimeline(companyId, orderId),
    );

    // Marcar como lido ao abrir
    _markAllAsRead();
  }

  @action
  Future<void> sendMessage(
    String text, {
    List<TimelineAttachment>? attachments,
    bool isPublic = false,
  }) async {
    if (_companyId == null || _orderId == null) return;
    if (text.trim().isEmpty && (attachments?.isEmpty ?? true)) return;

    isSending = true;
    error = null;

    try {
      await _repository.sendComment(
        _companyId!,
        _orderId!,
        text.trim(),
        attachments: attachments,
        isPublic: isPublic,
      );
    } catch (e) {
      error = e.toString();
    } finally {
      isSending = false;
    }
  }

  @action
  Future<void> _markAllAsRead() async {
    if (_companyId == null || _orderId == null) return;

    final userId = Global.currentUser?.id;
    if (userId == null) return;

    await _repository.markAllAsRead(_companyId!, _orderId!, userId);
  }

  @action
  void dispose() {
    timelineStream = null;
    _companyId = null;
    _orderId = null;
  }

  String _formatDateKey(DateTime? date) {
    if (date == null) return 'Desconhecido';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final eventDate = DateTime(date.year, date.month, date.day);

    if (eventDate == today) return 'Hoje';
    if (eventDate == yesterday) return 'Ontem';
    if (now.difference(date).inDays < 7) {
      const weekdays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
      return weekdays[date.weekday - 1];
    }

    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
```

---

## Integração com Código Existente

### OrderStore - Adicionar logs

**Arquivo:** `lib/mobx/order_store.dart`

```dart
// Importar
import 'package:praticos/repositories/timeline_repository.dart';

// Instanciar
final _timelineRepository = TimelineRepository();

// Modificar método setStatus:
@action
Future<void> setStatus(String newStatus) async {
  final oldStatus = order?.status;
  order?.status = newStatus;

  await repository.updateItem(companyId!, order!);

  // LOG NA TIMELINE
  if (order?.id != null && oldStatus != newStatus) {
    await _timelineRepository.logStatusChange(
      companyId!,
      order!.id!,
      oldStatus ?? '',
      newStatus,
    );
  }
}

// Modificar método de adicionar serviço:
@action
Future<void> addService(OrderService service) async {
  // ... lógica existente ...

  // LOG NA TIMELINE
  if (order?.id != null) {
    await _timelineRepository.logServiceAdded(
      companyId!,
      order!.id!,
      service.service?.name ?? '',
      service.value ?? 0,
      description: service.description,
    );
  }
}

// Similar para addProduct, removeService, etc.
```

### PhotoService - Log de fotos

```dart
// Após upload bem sucedido:
if (orderId != null && uploadedUrls.isNotEmpty) {
  await TimelineRepository().logPhotosAdded(
    companyId!,
    orderId!,
    uploadedUrls,
    isPublic: true,  // Fotos são públicas por padrão
  );
}
```

---

## Strings i18n

**Arquivo:** `lib/l10n/app_pt.arb`

```json
{
  "timeline": "Conversa",
  "timelineEmpty": "Nenhuma atividade ainda",
  "typeMessage": "Digite uma mensagem...",
  "sendMessage": "Enviar",
  "unread": "Não lidas",
  "viewDetails": "Ver detalhes",
  "addPhotos": "Adicionar fotos",
  "fillChecklist": "Preencher checklist",
  "muteNotifications": "Silenciar notificações",
  "shareWithCustomer": "Compartilhar com cliente",
  "internalOnly": "Só equipe",
  "customerCanSee": "Cliente vê",
  "sendToCustomer": "Enviar para cliente?",
  "sendToCustomerDescription": "Esta mensagem será visível para {customerName}.",
  "osCreated": "OS criada",
  "statusChanged": "Status alterado",
  "photosAdded": "{count, plural, =1{1 foto adicionada} other{{count} fotos adicionadas}}",
  "serviceAdded": "Serviço adicionado",
  "productAdded": "Produto adicionado",
  "checklistCompleted": "Checklist concluído",
  "paymentReceived": "Pagamento recebido",
  "assignedTo": "Atribuído a {name}",
  "dueTodayAlert": "Prazo vence hoje!",
  "dueInDaysAlert": "Prazo vence em {count} {count, plural, =1{dia} other{dias}}",
  "overdueAlert": "Prazo vencido há {count} {count, plural, =1{dia} other{dias}}!",
  "you": "Você",
  "system": "Sistema",
  "customer": "Cliente",
  "copyLink": "Copiar link",
  "sendViaWhatsapp": "Enviar via WhatsApp",
  "trackingLink": "Link de acompanhamento"
}
```

---

## Plano de Implementação

### Fase 1: Fundação (Models + Repository)

| Task | Arquivo | Dependência |
|------|---------|-------------|
| 1.1 | Criar `TimelineEvent` model | `lib/models/timeline_event.dart` | - |
| 1.2 | Adicionar campos ao `Order` | `lib/models/order.dart` | - |
| 1.3 | Rodar `build_runner` | - | 1.1, 1.2 |
| 1.4 | Criar `TimelineRepository` | `lib/repositories/timeline_repository.dart` | 1.3 |
| 1.5 | Criar `TimelineStore` | `lib/mobx/timeline_store.dart` | 1.4 |
| 1.6 | Rodar `build_runner` | - | 1.5 |
| 1.7 | Adicionar strings i18n | `lib/l10n/app_*.arb` | - |
| 1.8 | Rodar `gen-l10n` | - | 1.7 |

### Fase 2: Tela Timeline

| Task | Arquivo | Dependência |
|------|---------|-------------|
| 2.1 | Criar `TimelineScreen` | `lib/screens/timeline/timeline_screen.dart` | Fase 1 |
| 2.2 | Criar `TimelineEventCard` widget | `lib/screens/timeline/widgets/event_card.dart` | 2.1 |
| 2.3 | Criar `MessageInput` widget | `lib/screens/timeline/widgets/message_input.dart` | 2.1 |
| 2.4 | Criar `VisibilityToggle` widget | `lib/screens/timeline/widgets/visibility_toggle.dart` | 2.3 |
| 2.5 | Adicionar rota `/timeline` | `lib/main.dart` | 2.1 |

### Fase 3: Integração Home

| Task | Arquivo | Dependência |
|------|---------|-------------|
| 3.1 | Atualizar card da OS com preview | `lib/screens/menu_navigation/home.dart` | Fase 1 |
| 3.2 | Mudar tap para abrir timeline | `lib/screens/menu_navigation/home.dart` | 2.5 |
| 3.3 | Adicionar filtro "Não lidas" | `lib/screens/menu_navigation/home.dart` | 3.1 |
| 3.4 | Badge de não lidos na TabBar | `lib/screens/menu_navigation/navigation_controller.dart` | 3.1 |

### Fase 4: Logs Automáticos

| Task | Arquivo | Dependência |
|------|---------|-------------|
| 4.1 | Log de mudança de status | `lib/mobx/order_store.dart` | 1.4 |
| 4.2 | Log de fotos adicionadas | `lib/services/photo_service.dart` | 1.4 |
| 4.3 | Log de serviço add/edit/remove | `lib/mobx/order_store.dart` | 1.4 |
| 4.4 | Log de produto add/edit/remove | `lib/mobx/order_store.dart` | 1.4 |
| 4.5 | Log de checklist concluído | Depende da implementação atual | 1.4 |
| 4.6 | Log de pagamento | Depende da implementação atual | 1.4 |

### Fase 5: Portal Cliente (Link Mágico)

| Task | Arquivo | Dependência |
|------|---------|-------------|
| 5.1 | Gerar `customerToken` ao criar OS | `lib/repositories/order_repository.dart` | 1.4 |
| 5.2 | Criar coleção `customerTokens` | Firestore | - |
| 5.3 | UI: Botão compartilhar na timeline | `lib/screens/timeline/widgets/share_button.dart` | 2.1 |
| 5.4 | Deep link WhatsApp | `lib/services/share_service.dart` | 5.3 |
| 5.5 | Web page: `/t/{token}` | Firebase Hosting ou Flutter Web | 5.1 |

### Fase 6: Notificações

| Task | Arquivo | Dependência |
|------|---------|-------------|
| 6.1 | Cloud Function: push on new event | `functions/src/timeline_notifications.ts` | Fase 1 |
| 6.2 | Cloud Function: alertas de prazo | `functions/src/due_date_alerts.ts` | 1.4 |
| 6.3 | Configurar FCM no app | `lib/services/notification_service.dart` | 6.1 |

---

## Checklist de Validação

### Após Fase 1
- [ ] `TimelineEvent.fromJson()` funciona com dados de teste
- [ ] `TimelineRepository.getTimeline()` retorna stream
- [ ] `build_runner` executa sem erros

### Após Fase 2
- [ ] Timeline exibe eventos mockados
- [ ] Input de mensagem envia para Firestore
- [ ] Toggle de visibilidade funciona

### Após Fase 3
- [ ] Card da OS mostra `lastActivity.preview`
- [ ] Badge de não lidos aparece
- [ ] Tap na OS abre Timeline

### Após Fase 4
- [ ] Mudar status cria evento na timeline
- [ ] Adicionar foto cria evento na timeline
- [ ] `lastActivity` atualiza automaticamente

### Após Fase 5
- [ ] Token é gerado ao criar OS
- [ ] Link abre página do cliente
- [ ] Cliente vê apenas eventos públicos

---

## Comandos Úteis

```bash
# Gerar código após alterar models/stores
fvm flutter pub run build_runner build --delete-conflicting-outputs

# Gerar strings após alterar .arb
fvm flutter gen-l10n

# Análise de código
fvm flutter analyze
```
