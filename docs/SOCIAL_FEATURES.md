# Social Features - PraticOS

## Visao Geral

Este documento descreve a implementacao de funcionalidades sociais no PraticOS, visando:

1. **Substituir WhatsApp** como canal de comunicacao da equipe
2. **Aumentar engajamento** atraves de efeito de rede
3. **Melhorar transparencia** no acompanhamento de OSs
4. **Preparar terreno** para futuro portal do cliente

### Funcionalidades Principais

| Feature | Descricao | Prioridade |
|---------|-----------|------------|
| Comentarios na OS | Timeline de discussao dentro da OS | P0 |
| Mencoes (@usuario) | Notificar usuarios especificos | P0 |
| Feed de Atividades | Central de notificacoes e updates | P0 |
| Notificacoes Push | Alertas em tempo real | P1 |
| Seguir OS | Acompanhar OSs de interesse | P2 |
| Reacoes | Confirmar leitura (thumbs up) | P2 |

---

## Arquitetura

### Estrutura Firestore

```
/companies/{companyId}/
├── orders/{orderId}/
│   └── comments/{commentId}          # Comentarios da OS
│
├── activities/{activityId}           # Feed de atividades da empresa
│
└── collaborators/{odivllabaratorId}/
    └── notifications/{notificationId} # Notificacoes pessoais
```

### Collections Detalhadas

#### 1. Comments (Subcollection de Order)

**Path:** `/companies/{companyId}/orders/{orderId}/comments/{commentId}`

```typescript
interface Comment {
  id: string;

  // Autor
  author: {
    id: string;
    name: string;
    photoUrl?: string;
  };

  // Conteudo
  text: string;
  mentions: MentionRef[];       // Usuarios mencionados
  attachments: Attachment[];    // Fotos/arquivos anexados

  // Visibilidade (para futuro portal do cliente)
  visibility: 'internal' | 'client';

  // Threading (respostas)
  parentId?: string;            // Se for resposta a outro comentario
  replyCount: number;           // Quantidade de respostas

  // Reacoes
  reactions: {
    [emoji: string]: string[];  // emoji -> lista de userIds
  };

  // Auditoria
  createdAt: Timestamp;
  createdBy: UserAggr;
  updatedAt?: Timestamp;
  isEdited: boolean;
  isDeleted: boolean;           // Soft delete
}

interface MentionRef {
  userId: string;
  name: string;
  startIndex: number;           // Posicao no texto
  endIndex: number;
}

interface Attachment {
  id: string;
  type: 'image' | 'file';
  url: string;
  thumbnailUrl?: string;
  name: string;
  size: number;
}
```

#### 2. Activities (Feed da Empresa)

**Path:** `/companies/{companyId}/activities/{activityId}`

```typescript
interface Activity {
  id: string;

  // Tipo de atividade
  type: ActivityType;

  // Contexto
  order?: {
    id: string;
    number: number;
    customerName?: string;
  };

  // Quem fez a acao
  actor: {
    id: string;
    name: string;
    photoUrl?: string;
  };

  // Dados especificos por tipo
  data: ActivityData;

  // Quem deve ver (para queries eficientes)
  targetUsers: string[];        // userIds que devem ver no "Para Voce"

  // Timestamps
  createdAt: Timestamp;

  // Para agrupamento
  groupKey?: string;            // Ex: "photos_order123_20250115" para agrupar
}

type ActivityType =
  | 'comment'           // Novo comentario
  | 'mention'           // Mencionado em comentario
  | 'status_change'     // Mudanca de status
  | 'order_assigned'    // OS atribuida
  | 'order_created'     // Nova OS criada
  | 'photos_added'      // Fotos adicionadas
  | 'quote_approved'    // Orcamento aprovado
  | 'quote_rejected'    // Orcamento rejeitado
  | 'payment_received'  // Pagamento recebido
  | 'due_date_alert'    // Alerta de prazo
  | 'form_completed';   // Formulario concluido

interface ActivityData {
  // Para comment/mention
  commentId?: string;
  commentText?: string;

  // Para status_change
  oldStatus?: string;
  newStatus?: string;

  // Para photos_added
  photoUrls?: string[];
  photoCount?: number;

  // Para payment
  amount?: number;

  // Para due_date_alert
  dueDate?: Timestamp;
  daysRemaining?: number;
}
```

#### 3. Notifications (Pessoal do Usuario)

**Path:** `/companies/{companyId}/collaborators/{odivllabaratorId}/notifications/{notificationId}`

```typescript
interface Notification {
  id: string;

  // Referencia a atividade original
  activityId: string;
  activityType: ActivityType;

  // Preview para exibicao rapida
  title: string;
  body: string;

  // Contexto
  orderId?: string;
  orderNumber?: number;

  // Estado
  read: boolean;
  readAt?: Timestamp;

  // Para push notification
  pushSent: boolean;
  pushSentAt?: Timestamp;

  // Timestamps
  createdAt: Timestamp;
}
```

---

## Models Flutter

### Comment Model

```dart
// lib/models/comment.dart

import 'package:json_annotation/json_annotation.dart';
import 'package:praticos/models/base_audit.dart';

part 'comment.g.dart';

@JsonSerializable(explicitToJson: true)
class Comment extends BaseAudit {
  CommentAuthor? author;
  String? text;
  List<MentionRef>? mentions;
  List<CommentAttachment>? attachments;
  String? visibility; // 'internal' | 'client'
  String? parentId;
  int? replyCount;
  Map<String, List<String>>? reactions;
  bool? isEdited;
  bool? isDeleted;

  Comment();

  factory Comment.fromJson(Map<String, dynamic> json) => _$CommentFromJson(json);
  Map<String, dynamic> toJson() => _$CommentToJson(this);
}

@JsonSerializable()
class CommentAuthor {
  String? id;
  String? name;
  String? photoUrl;

  CommentAuthor();

  factory CommentAuthor.fromJson(Map<String, dynamic> json) =>
      _$CommentAuthorFromJson(json);
  Map<String, dynamic> toJson() => _$CommentAuthorToJson(this);
}

@JsonSerializable()
class MentionRef {
  String? userId;
  String? name;
  int? startIndex;
  int? endIndex;

  MentionRef();

  factory MentionRef.fromJson(Map<String, dynamic> json) =>
      _$MentionRefFromJson(json);
  Map<String, dynamic> toJson() => _$MentionRefToJson(this);
}

@JsonSerializable()
class CommentAttachment {
  String? id;
  String? type; // 'image' | 'file'
  String? url;
  String? thumbnailUrl;
  String? name;
  int? size;

  CommentAttachment();

  factory CommentAttachment.fromJson(Map<String, dynamic> json) =>
      _$CommentAttachmentFromJson(json);
  Map<String, dynamic> toJson() => _$CommentAttachmentToJson(this);
}
```

### Activity Model

```dart
// lib/models/activity.dart

import 'package:json_annotation/json_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'activity.g.dart';

@JsonSerializable(explicitToJson: true)
class Activity {
  String? id;
  String? type;
  ActivityOrder? order;
  ActivityActor? actor;
  ActivityData? data;
  List<String>? targetUsers;

  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  DateTime? createdAt;

  String? groupKey;

  Activity();

  factory Activity.fromJson(Map<String, dynamic> json) => _$ActivityFromJson(json);
  Map<String, dynamic> toJson() => _$ActivityToJson(this);

  static DateTime? _timestampFromJson(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return null;
  }

  static dynamic _timestampToJson(DateTime? date) =>
      date != null ? Timestamp.fromDate(date) : null;
}

@JsonSerializable()
class ActivityOrder {
  String? id;
  int? number;
  String? customerName;

  ActivityOrder();

  factory ActivityOrder.fromJson(Map<String, dynamic> json) =>
      _$ActivityOrderFromJson(json);
  Map<String, dynamic> toJson() => _$ActivityOrderToJson(this);
}

@JsonSerializable()
class ActivityActor {
  String? id;
  String? name;
  String? photoUrl;

  ActivityActor();

  factory ActivityActor.fromJson(Map<String, dynamic> json) =>
      _$ActivityActorFromJson(json);
  Map<String, dynamic> toJson() => _$ActivityActorToJson(this);
}

@JsonSerializable()
class ActivityData {
  String? commentId;
  String? commentText;
  String? oldStatus;
  String? newStatus;
  List<String>? photoUrls;
  int? photoCount;
  double? amount;

  @JsonKey(fromJson: Activity._timestampFromJson, toJson: Activity._timestampToJson)
  DateTime? dueDate;
  int? daysRemaining;

  ActivityData();

  factory ActivityData.fromJson(Map<String, dynamic> json) =>
      _$ActivityDataFromJson(json);
  Map<String, dynamic> toJson() => _$ActivityDataToJson(this);
}
```

---

## Repositories

### CommentRepository

```dart
// lib/repositories/comment_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/comment.dart';

class CommentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _commentsRef(
    String companyId,
    String orderId,
  ) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('orders')
        .doc(orderId)
        .collection('comments');
  }

  /// Stream de comentarios (ordenados por data)
  Stream<List<Comment>> getComments(String companyId, String orderId) {
    return _commentsRef(companyId, orderId)
        .where('isDeleted', isEqualTo: false)
        .where('parentId', isNull: true) // Apenas comentarios raiz
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Comment.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Stream de respostas de um comentario
  Stream<List<Comment>> getReplies(
    String companyId,
    String orderId,
    String parentId,
  ) {
    return _commentsRef(companyId, orderId)
        .where('isDeleted', isEqualTo: false)
        .where('parentId', isEqualTo: parentId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Comment.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Criar novo comentario
  Future<Comment> createComment(
    String companyId,
    String orderId,
    Comment comment,
  ) async {
    final docRef = await _commentsRef(companyId, orderId).add(comment.toJson());
    comment.id = docRef.id;

    // Se for resposta, incrementar contador do pai
    if (comment.parentId != null) {
      await _commentsRef(companyId, orderId)
          .doc(comment.parentId)
          .update({'replyCount': FieldValue.increment(1)});
    }

    return comment;
  }

  /// Editar comentario
  Future<void> updateComment(
    String companyId,
    String orderId,
    String commentId,
    String newText,
  ) async {
    await _commentsRef(companyId, orderId).doc(commentId).update({
      'text': newText,
      'isEdited': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Soft delete
  Future<void> deleteComment(
    String companyId,
    String orderId,
    String commentId,
  ) async {
    await _commentsRef(companyId, orderId).doc(commentId).update({
      'isDeleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Adicionar reacao
  Future<void> addReaction(
    String companyId,
    String orderId,
    String commentId,
    String emoji,
    String userId,
  ) async {
    await _commentsRef(companyId, orderId).doc(commentId).update({
      'reactions.$emoji': FieldValue.arrayUnion([userId]),
    });
  }

  /// Remover reacao
  Future<void> removeReaction(
    String companyId,
    String orderId,
    String commentId,
    String emoji,
    String userId,
  ) async {
    await _commentsRef(companyId, orderId).doc(commentId).update({
      'reactions.$emoji': FieldValue.arrayRemove([userId]),
    });
  }
}
```

### ActivityRepository

```dart
// lib/repositories/activity_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/activity.dart';

class ActivityRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _activitiesRef(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('activities');
  }

  /// Feed "Para Voce" - atividades onde o usuario e target
  Stream<List<Activity>> getActivitiesForUser(
    String companyId,
    String userId, {
    int limit = 50,
  }) {
    return _activitiesRef(companyId)
        .where('targetUsers', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Activity.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Feed "Equipe" - todas as atividades da empresa
  Stream<List<Activity>> getActivitiesForTeam(
    String companyId, {
    int limit = 50,
  }) {
    return _activitiesRef(companyId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Activity.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Feed "Seguindo" - atividades de OSs que o usuario segue
  Stream<List<Activity>> getActivitiesForFollowing(
    String companyId,
    List<String> followingOrderIds, {
    int limit = 50,
  }) {
    if (followingOrderIds.isEmpty) {
      return Stream.value([]);
    }

    // Firestore limita whereIn a 10 items, precisamos paginar
    final chunks = _chunkList(followingOrderIds, 10);

    return Stream.fromFuture(Future.wait(
      chunks.map((chunk) => _activitiesRef(companyId)
          .where('order.id', whereIn: chunk)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get()),
    )).map((snapshots) {
      final allDocs = snapshots.expand((s) => s.docs).toList();
      allDocs.sort((a, b) {
        final aTime = (a.data()['createdAt'] as Timestamp).toDate();
        final bTime = (b.data()['createdAt'] as Timestamp).toDate();
        return bTime.compareTo(aTime);
      });
      return allDocs
          .take(limit)
          .map((doc) => Activity.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    });
  }

  /// Criar atividade
  Future<void> createActivity(String companyId, Activity activity) async {
    await _activitiesRef(companyId).add(activity.toJson());
  }

  /// Paginacao - carregar mais antigos
  Future<List<Activity>> loadMoreActivities(
    String companyId,
    DateTime lastCreatedAt, {
    String? userId,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> query = _activitiesRef(companyId)
        .orderBy('createdAt', descending: true)
        .startAfter([Timestamp.fromDate(lastCreatedAt)])
        .limit(limit);

    if (userId != null) {
      query = query.where('targetUsers', arrayContains: userId);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => Activity.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }

  List<List<T>> _chunkList<T>(List<T> list, int chunkSize) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += chunkSize) {
      chunks.add(list.sublist(i, i + chunkSize > list.length ? list.length : i + chunkSize));
    }
    return chunks;
  }
}
```

---

## MobX Stores

### CommentStore

```dart
// lib/mobx/comment_store.dart

import 'package:mobx/mobx.dart';
import 'package:praticos/models/comment.dart';
import 'package:praticos/repositories/comment_repository.dart';
import 'package:praticos/global.dart';

part 'comment_store.g.dart';

class CommentStore = _CommentStore with _$CommentStore;

abstract class _CommentStore with Store {
  final CommentRepository _repository = CommentRepository();

  @observable
  ObservableStream<List<Comment>>? commentsStream;

  @observable
  bool isLoading = false;

  @observable
  String? error;

  String? _companyId;
  String? _orderId;

  @action
  void init(String companyId, String orderId) {
    _companyId = companyId;
    _orderId = orderId;
    commentsStream = ObservableStream(
      _repository.getComments(companyId, orderId),
    );
  }

  @action
  Future<Comment?> addComment(String text, {
    List<MentionRef>? mentions,
    List<CommentAttachment>? attachments,
    String? parentId,
  }) async {
    if (_companyId == null || _orderId == null) return null;

    isLoading = true;
    error = null;

    try {
      final comment = Comment()
        ..author = CommentAuthor()
          ..id = Global.currentUser?.id
          ..name = Global.currentUser?.name
          ..photoUrl = Global.currentUser?.photoUrl
        ..text = text
        ..mentions = mentions ?? []
        ..attachments = attachments ?? []
        ..visibility = 'internal'
        ..parentId = parentId
        ..replyCount = 0
        ..reactions = {}
        ..isEdited = false
        ..isDeleted = false
        ..createdAt = DateTime.now()
        ..createdBy = Global.currentUser?.toAggr();

      final created = await _repository.createComment(
        _companyId!,
        _orderId!,
        comment,
      );

      return created;
    } catch (e) {
      error = e.toString();
      return null;
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> toggleReaction(String commentId, String emoji) async {
    if (_companyId == null || _orderId == null) return;

    final userId = Global.currentUser?.id;
    if (userId == null) return;

    final comments = commentsStream?.value ?? [];
    final comment = comments.firstWhere(
      (c) => c.id == commentId,
      orElse: () => Comment(),
    );

    final hasReacted = comment.reactions?[emoji]?.contains(userId) ?? false;

    if (hasReacted) {
      await _repository.removeReaction(
        _companyId!, _orderId!, commentId, emoji, userId,
      );
    } else {
      await _repository.addReaction(
        _companyId!, _orderId!, commentId, emoji, userId,
      );
    }
  }

  @action
  Future<void> deleteComment(String commentId) async {
    if (_companyId == null || _orderId == null) return;
    await _repository.deleteComment(_companyId!, _orderId!, commentId);
  }

  @action
  void dispose() {
    commentsStream = null;
  }
}
```

### ActivityFeedStore

```dart
// lib/mobx/activity_feed_store.dart

import 'package:mobx/mobx.dart';
import 'package:praticos/models/activity.dart';
import 'package:praticos/repositories/activity_repository.dart';
import 'package:praticos/global.dart';

part 'activity_feed_store.g.dart';

enum FeedFilter { forYou, team, following }

class ActivityFeedStore = _ActivityFeedStore with _$ActivityFeedStore;

abstract class _ActivityFeedStore with Store {
  final ActivityRepository _repository = ActivityRepository();

  @observable
  FeedFilter currentFilter = FeedFilter.forYou;

  @observable
  ObservableList<Activity> activities = ObservableList<Activity>();

  @observable
  bool isLoading = false;

  @observable
  bool hasMore = true;

  @observable
  int unreadCount = 0;

  @observable
  String? error;

  String? _companyId;
  List<String> _followingOrderIds = [];

  @action
  void init(String companyId) {
    _companyId = companyId;
    loadActivities();
  }

  @action
  void setFilter(FeedFilter filter) {
    if (currentFilter != filter) {
      currentFilter = filter;
      activities.clear();
      hasMore = true;
      loadActivities();
    }
  }

  @action
  void setFollowingOrders(List<String> orderIds) {
    _followingOrderIds = orderIds;
    if (currentFilter == FeedFilter.following) {
      activities.clear();
      loadActivities();
    }
  }

  @action
  Future<void> loadActivities() async {
    if (_companyId == null || isLoading) return;

    isLoading = true;
    error = null;

    try {
      final userId = Global.currentUser?.id;

      Stream<List<Activity>> stream;

      switch (currentFilter) {
        case FeedFilter.forYou:
          if (userId == null) {
            stream = Stream.value([]);
          } else {
            stream = _repository.getActivitiesForUser(_companyId!, userId);
          }
          break;
        case FeedFilter.team:
          stream = _repository.getActivitiesForTeam(_companyId!);
          break;
        case FeedFilter.following:
          stream = _repository.getActivitiesForFollowing(
            _companyId!,
            _followingOrderIds,
          );
          break;
      }

      await for (final list in stream.take(1)) {
        activities.clear();
        activities.addAll(list);
        hasMore = list.length >= 50;
        break;
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> loadMore() async {
    if (_companyId == null || isLoading || !hasMore || activities.isEmpty) return;

    isLoading = true;

    try {
      final lastActivity = activities.last;
      final userId = currentFilter == FeedFilter.forYou
          ? Global.currentUser?.id
          : null;

      final moreActivities = await _repository.loadMoreActivities(
        _companyId!,
        lastActivity.createdAt!,
        userId: userId,
      );

      activities.addAll(moreActivities);
      hasMore = moreActivities.length >= 20;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
    }
  }

  @action
  Future<void> refresh() async {
    activities.clear();
    hasMore = true;
    await loadActivities();
  }
}
```

---

## Services

### ActivityService (Criar Atividades)

```dart
// lib/services/activity_service.dart

import 'package:praticos/models/activity.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/comment.dart';
import 'package:praticos/repositories/activity_repository.dart';
import 'package:praticos/global.dart';

class ActivityService {
  final ActivityRepository _repository = ActivityRepository();

  /// Criar atividade de novo comentario
  Future<void> onCommentCreated(
    String companyId,
    Order order,
    Comment comment,
  ) async {
    // Atividade para o feed geral
    final activity = Activity()
      ..type = 'comment'
      ..order = ActivityOrder()
        ..id = order.id
        ..number = order.number
        ..customerName = order.customer?.name
      ..actor = ActivityActor()
        ..id = comment.author?.id
        ..name = comment.author?.name
        ..photoUrl = comment.author?.photoUrl
      ..data = ActivityData()
        ..commentId = comment.id
        ..commentText = _truncateText(comment.text, 100)
      ..targetUsers = _getCommentTargetUsers(order, comment)
      ..createdAt = DateTime.now();

    await _repository.createActivity(companyId, activity);

    // Se tem mencoes, criar atividades especificas
    for (final mention in comment.mentions ?? []) {
      final mentionActivity = Activity()
        ..type = 'mention'
        ..order = activity.order
        ..actor = activity.actor
        ..data = activity.data
        ..targetUsers = [mention.userId!]
        ..createdAt = DateTime.now();

      await _repository.createActivity(companyId, mentionActivity);
    }
  }

  /// Criar atividade de mudanca de status
  Future<void> onStatusChanged(
    String companyId,
    Order order,
    String oldStatus,
    String newStatus,
  ) async {
    final activity = Activity()
      ..type = 'status_change'
      ..order = ActivityOrder()
        ..id = order.id
        ..number = order.number
        ..customerName = order.customer?.name
      ..actor = ActivityActor()
        ..id = Global.currentUser?.id
        ..name = Global.currentUser?.name
        ..photoUrl = Global.currentUser?.photoUrl
      ..data = ActivityData()
        ..oldStatus = oldStatus
        ..newStatus = newStatus
      ..targetUsers = _getOrderTargetUsers(order)
      ..createdAt = DateTime.now();

    await _repository.createActivity(companyId, activity);
  }

  /// Criar atividade de OS atribuida
  Future<void> onOrderAssigned(
    String companyId,
    Order order,
    String assignedUserId,
  ) async {
    final activity = Activity()
      ..type = 'order_assigned'
      ..order = ActivityOrder()
        ..id = order.id
        ..number = order.number
        ..customerName = order.customer?.name
      ..actor = ActivityActor()
        ..id = Global.currentUser?.id
        ..name = Global.currentUser?.name
        ..photoUrl = Global.currentUser?.photoUrl
      ..data = ActivityData()
      ..targetUsers = [assignedUserId]
      ..createdAt = DateTime.now();

    await _repository.createActivity(companyId, activity);
  }

  /// Criar atividade de fotos adicionadas
  Future<void> onPhotosAdded(
    String companyId,
    Order order,
    List<String> photoUrls,
  ) async {
    final activity = Activity()
      ..type = 'photos_added'
      ..order = ActivityOrder()
        ..id = order.id
        ..number = order.number
        ..customerName = order.customer?.name
      ..actor = ActivityActor()
        ..id = Global.currentUser?.id
        ..name = Global.currentUser?.name
        ..photoUrl = Global.currentUser?.photoUrl
      ..data = ActivityData()
        ..photoUrls = photoUrls.take(3).toList()
        ..photoCount = photoUrls.length
      ..targetUsers = _getOrderTargetUsers(order)
      ..groupKey = 'photos_${order.id}_${DateTime.now().toIso8601String().substring(0, 10)}'
      ..createdAt = DateTime.now();

    await _repository.createActivity(companyId, activity);
  }

  /// Criar alerta de prazo
  Future<void> onDueDateAlert(
    String companyId,
    Order order,
    int daysRemaining,
  ) async {
    final activity = Activity()
      ..type = 'due_date_alert'
      ..order = ActivityOrder()
        ..id = order.id
        ..number = order.number
        ..customerName = order.customer?.name
      ..actor = null // Sistema
      ..data = ActivityData()
        ..dueDate = order.dueDate
        ..daysRemaining = daysRemaining
      ..targetUsers = _getOrderTargetUsers(order)
      ..createdAt = DateTime.now();

    await _repository.createActivity(companyId, activity);
  }

  // Helpers

  List<String> _getCommentTargetUsers(Order order, Comment comment) {
    final targets = <String>{};

    // Criador da OS
    if (order.createdBy?.id != null) {
      targets.add(order.createdBy!.id!);
    }

    // Responsavel pela OS (se houver)
    if (order.assignedTo?.id != null) {
      targets.add(order.assignedTo!.id!);
    }

    // Mencionados
    for (final mention in comment.mentions ?? []) {
      if (mention.userId != null) {
        targets.add(mention.userId!);
      }
    }

    // Remover o autor do comentario (nao notificar a si mesmo)
    targets.remove(comment.author?.id);

    return targets.toList();
  }

  List<String> _getOrderTargetUsers(Order order) {
    final targets = <String>{};

    if (order.createdBy?.id != null) {
      targets.add(order.createdBy!.id!);
    }

    if (order.assignedTo?.id != null) {
      targets.add(order.assignedTo!.id!);
    }

    // Remover usuario atual
    targets.remove(Global.currentUser?.id);

    return targets.toList();
  }

  String _truncateText(String? text, int maxLength) {
    if (text == null) return '';
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
```

### NotificationService (Push Notifications)

```dart
// lib/services/notification_service.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/global.dart';

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Inicializar FCM
  Future<void> initialize() async {
    // Solicitar permissao
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Obter token
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveToken(token);
      }

      // Listener para token refresh
      _messaging.onTokenRefresh.listen(_saveToken);
    }

    // Handler para notificacoes em foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handler para quando app abre via notificacao
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);
  }

  Future<void> _saveToken(String token) async {
    final userId = Global.currentUser?.id;
    final companyId = Global.companyAggr?.id;

    if (userId == null || companyId == null) return;

    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('collaborators')
        .doc(userId)
        .update({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'lastTokenUpdate': FieldValue.serverTimestamp(),
    });
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // Mostrar local notification ou atualizar badge
    // TODO: Implementar local notification
  }

  void _handleNotificationOpen(RemoteMessage message) {
    // Navegar para a OS ou comentario especifico
    final orderId = message.data['orderId'];
    final commentId = message.data['commentId'];

    // TODO: Implementar navegacao
  }

  /// Marcar notificacao como lida
  Future<void> markAsRead(String companyId, String notificationId) async {
    final userId = Global.currentUser?.id;
    if (userId == null) return;

    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('collaborators')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  /// Marcar todas como lidas
  Future<void> markAllAsRead(String companyId) async {
    final userId = Global.currentUser?.id;
    if (userId == null) return;

    final batch = _firestore.batch();

    final unreadDocs = await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('collaborators')
        .doc(userId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get();

    for (final doc in unreadDocs.docs) {
      batch.update(doc.reference, {
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Stream de contagem de nao lidas
  Stream<int> getUnreadCount(String companyId) {
    final userId = Global.currentUser?.id;
    if (userId == null) return Stream.value(0);

    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('collaborators')
        .doc(userId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
```

---

## UI Components

### Tela do Feed

```dart
// lib/screens/feed/activity_feed_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:praticos/mobx/activity_feed_store.dart';
import 'package:praticos/models/activity.dart';
import 'package:praticos/extensions/context_extensions.dart';

class ActivityFeedScreen extends StatefulWidget {
  @override
  _ActivityFeedScreenState createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> {
  late ActivityFeedStore _store;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _store = Provider.of<ActivityFeedStore>(context);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(context.l10n.activity),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              child: Text(context.l10n.markAllRead),
              onPressed: () {
                // TODO: Mark all as read
              },
            ),
          ),
          _buildFilterSegment(),
          _buildActivityList(),
        ],
      ),
    );
  }

  Widget _buildFilterSegment() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Observer(
          builder: (_) => CupertinoSlidingSegmentedControl<FeedFilter>(
            groupValue: _store.currentFilter,
            children: {
              FeedFilter.forYou: Text(context.l10n.forYou),
              FeedFilter.team: Text(context.l10n.team),
              FeedFilter.following: Text(context.l10n.following),
            },
            onValueChanged: (value) {
              if (value != null) {
                _store.setFilter(value);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildActivityList() {
    return Observer(
      builder: (_) {
        if (_store.isLoading && _store.activities.isEmpty) {
          return const SliverFillRemaining(
            child: Center(child: CupertinoActivityIndicator()),
          );
        }

        if (_store.activities.isEmpty) {
          return SliverFillRemaining(
            child: _buildEmptyState(),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index >= _store.activities.length) return null;
              return _buildActivityCard(_store.activities[index]);
            },
            childCount: _store.activities.length,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.bell,
            size: 48,
            color: CupertinoColors.systemGrey.resolveFrom(context),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.noActivity,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.noActivityDescription,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(Activity activity) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => _navigateToOrder(activity),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildActivityIcon(activity),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildActivityTitle(activity),
                    const SizedBox(height: 2),
                    _buildActivitySubtitle(activity),
                    const SizedBox(height: 4),
                    _buildActivityTimestamp(activity),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: CupertinoColors.systemGrey3.resolveFrom(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityIcon(Activity activity) {
    IconData icon;
    Color color;

    switch (activity.type) {
      case 'comment':
      case 'mention':
        icon = CupertinoIcons.chat_bubble_fill;
        color = CupertinoColors.systemBlue;
        break;
      case 'status_change':
        icon = CupertinoIcons.flag_fill;
        color = CupertinoColors.systemPurple;
        break;
      case 'order_assigned':
        icon = CupertinoIcons.doc_text_fill;
        color = CupertinoColors.systemOrange;
        break;
      case 'photos_added':
        icon = CupertinoIcons.photo_fill;
        color = CupertinoColors.systemGreen;
        break;
      case 'due_date_alert':
        icon = CupertinoIcons.exclamationmark_triangle_fill;
        color = CupertinoColors.systemRed;
        break;
      default:
        icon = CupertinoIcons.bell_fill;
        color = CupertinoColors.systemGrey;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  Widget _buildActivityTitle(Activity activity) {
    String title;

    switch (activity.type) {
      case 'mention':
        title = '${activity.actor?.name} ${context.l10n.mentionedYou}';
        break;
      case 'comment':
        title = '${activity.actor?.name} ${context.l10n.commented}';
        break;
      case 'status_change':
        title = '${activity.actor?.name} ${context.l10n.changedStatus}';
        break;
      case 'order_assigned':
        title = context.l10n.orderAssignedToYou;
        break;
      case 'photos_added':
        final count = activity.data?.photoCount ?? 0;
        title = '${activity.actor?.name} ${context.l10n.addedPhotos(count)}';
        break;
      case 'due_date_alert':
        final days = activity.data?.daysRemaining ?? 0;
        title = days == 0
            ? context.l10n.dueDateToday
            : context.l10n.dueDateIn(days);
        break;
      default:
        title = context.l10n.newActivity;
    }

    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: CupertinoColors.label.resolveFrom(context),
      ),
    );
  }

  Widget _buildActivitySubtitle(Activity activity) {
    String subtitle = '';

    if (activity.order != null) {
      subtitle = 'OS #${activity.order!.number}';
      if (activity.order!.customerName != null) {
        subtitle += ' • ${activity.order!.customerName}';
      }
    }

    if (activity.data?.commentText != null) {
      subtitle += '\n"${activity.data!.commentText}"';
    }

    if (activity.type == 'status_change') {
      subtitle += '\n${activity.data?.oldStatus} → ${activity.data?.newStatus}';
    }

    return Text(
      subtitle,
      style: TextStyle(
        fontSize: 13,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildActivityTimestamp(Activity activity) {
    return Text(
      _formatTimestamp(activity.createdAt),
      style: TextStyle(
        fontSize: 12,
        color: CupertinoColors.tertiaryLabel.resolveFrom(context),
      ),
    );
  }

  String _formatTimestamp(DateTime? date) {
    if (date == null) return '';

    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return context.l10n.justNow;
    if (diff.inMinutes < 60) return context.l10n.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return context.l10n.hoursAgo(diff.inHours);
    if (diff.inDays < 7) return context.l10n.daysAgo(diff.inDays);

    return '${date.day}/${date.month}/${date.year}';
  }

  void _navigateToOrder(Activity activity) {
    if (activity.order?.id != null) {
      Navigator.of(context, rootNavigator: true).pushNamed(
        '/order',
        arguments: {'orderId': activity.order!.id},
      );
    }
  }
}
```

### Secao de Comentarios na OS

```dart
// lib/screens/widgets/order_comments_section.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/mobx/comment_store.dart';
import 'package:praticos/models/comment.dart';
import 'package:praticos/extensions/context_extensions.dart';

class OrderCommentsSection extends StatefulWidget {
  final String companyId;
  final String orderId;

  const OrderCommentsSection({
    required this.companyId,
    required this.orderId,
  });

  @override
  _OrderCommentsSectionState createState() => _OrderCommentsSectionState();
}

class _OrderCommentsSectionState extends State<OrderCommentsSection> {
  final CommentStore _store = CommentStore();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _store.init(widget.companyId, widget.orderId);
  }

  @override
  void dispose() {
    _store.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        _buildCommentsList(),
        _buildCommentInput(),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            context.l10n.activity.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: () {
              // TODO: Navigate to full activity view
            },
            child: Text(
              context.l10n.seeAll,
              style: TextStyle(
                fontSize: 15,
                color: CupertinoTheme.of(context).primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Observer(
        builder: (_) {
          final comments = _store.commentsStream?.value ?? [];

          if (comments.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  context.l10n.noComments,
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            );
          }

          // Mostrar apenas os 3 mais recentes
          final displayComments = comments.take(3).toList();

          return Column(
            children: displayComments.asMap().entries.map((entry) {
              final isLast = entry.key == displayComments.length - 1;
              return _buildCommentCard(entry.value, isLast);
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildCommentCard(Comment comment, bool isLast) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 16,
                backgroundColor: CupertinoColors.systemGrey5.resolveFrom(context),
                backgroundImage: comment.author?.photoUrl != null
                    ? NetworkImage(comment.author!.photoUrl!)
                    : null,
                child: comment.author?.photoUrl == null
                    ? Icon(
                        CupertinoIcons.person_fill,
                        size: 16,
                        color: CupertinoColors.systemGrey.resolveFrom(context),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comment.author?.name ?? 'Usuario',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.label.resolveFrom(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTimestamp(comment.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    _buildCommentText(comment),
                    if (comment.attachments?.isNotEmpty ?? false)
                      _buildAttachments(comment.attachments!),
                    const SizedBox(height: 6),
                    _buildReactionBar(comment),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 50,
            color: CupertinoColors.systemGrey5.resolveFrom(context),
          ),
      ],
    );
  }

  Widget _buildCommentText(Comment comment) {
    // TODO: Implementar rich text com mentions destacadas
    return Text(
      comment.text ?? '',
      style: TextStyle(
        fontSize: 14,
        color: CupertinoColors.label.resolveFrom(context),
      ),
    );
  }

  Widget _buildAttachments(List<CommentAttachment> attachments) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 60,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: attachments.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final attachment = attachments[index];
            return ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                attachment.thumbnailUrl ?? attachment.url ?? '',
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildReactionBar(Comment comment) {
    final reactions = comment.reactions ?? {};
    final hasThumbsUp = reactions['thumbsUp']?.isNotEmpty ?? false;
    final thumbsUpCount = reactions['thumbsUp']?.length ?? 0;

    return Row(
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () => _store.toggleReaction(comment.id!, 'thumbsUp'),
          child: Row(
            children: [
              Icon(
                hasThumbsUp
                    ? CupertinoIcons.hand_thumbsup_fill
                    : CupertinoIcons.hand_thumbsup,
                size: 16,
                color: hasThumbsUp
                    ? CupertinoColors.activeBlue
                    : CupertinoColors.systemGrey,
              ),
              if (thumbsUpCount > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '$thumbsUpCount',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 16),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () {
            // TODO: Focus reply input
          },
          child: Text(
            context.l10n.reply,
            style: TextStyle(
              fontSize: 12,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentInput() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: CupertinoColors.systemGrey5.resolveFrom(context),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: CupertinoTextField.borderless(
              controller: _textController,
              focusNode: _focusNode,
              placeholder: context.l10n.writeComment,
              maxLines: null,
              style: TextStyle(
                fontSize: 15,
                color: CupertinoColors.label.resolveFrom(context),
              ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: () {
              // TODO: Abrir seletor de fotos
            },
            child: Icon(
              CupertinoIcons.paperclip,
              size: 22,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(width: 8),
          Observer(
            builder: (_) => CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: _store.isLoading ? null : _sendComment,
              child: _store.isLoading
                  ? const CupertinoActivityIndicator()
                  : Icon(
                      CupertinoIcons.arrow_up_circle_fill,
                      size: 28,
                      color: CupertinoTheme.of(context).primaryColor,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendComment() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // TODO: Parse mentions from text
    final mentions = _parseMentions(text);

    await _store.addComment(text, mentions: mentions);

    if (_store.error == null) {
      _textController.clear();
      _focusNode.unfocus();
    }
  }

  List<MentionRef> _parseMentions(String text) {
    // TODO: Implementar parser de @mentions
    return [];
  }

  String _formatTimestamp(DateTime? date) {
    if (date == null) return '';

    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return context.l10n.justNow;
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';

    return '${date.day}/${date.month}';
  }
}
```

---

## Atualizacao da Navegacao

### navigation_controller.dart (Atualizado)

```dart
// Adicionar Feed como nova aba

final _pageOptions = [
  Home(),
  ActivityFeedScreen(),  // NOVA ABA
  HomeCustomerList(),
  Settings(),
];

// TabBar items atualizados
items: <BottomNavigationBarItem>[
  BottomNavigationBarItem(
    icon: const Icon(CupertinoIcons.house),
    activeIcon: const Icon(CupertinoIcons.house_fill),
    label: context.l10n.home,
  ),
  BottomNavigationBarItem(
    icon: Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(CupertinoIcons.bell),
        // Badge de notificacoes
        Positioned(
          right: -6,
          top: -4,
          child: Observer(
            builder: (_) {
              final count = notificationStore.unreadCount;
              if (count == 0) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemRed,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
    activeIcon: const Icon(CupertinoIcons.bell_fill),
    label: context.l10n.activity,
  ),
  BottomNavigationBarItem(
    icon: const Icon(CupertinoIcons.person_2),
    activeIcon: const Icon(CupertinoIcons.person_2_fill),
    label: context.l10n.customers,
  ),
  BottomNavigationBarItem(
    icon: const Icon(CupertinoIcons.ellipsis),
    label: context.l10n.more,
  ),
],
```

---

## Integracao na Tela de OS

### order_form.dart (Atualizacoes)

Adicionar secao de comentarios no final:

```dart
// No build(), adicionar antes do SizedBox final:

SliverList(
  delegate: SliverChildListDelegate([
    _buildPhotosSection(context),
    _buildClientDeviceSection(context, config),
    _buildSummarySection(context, config),
    _buildServicesSection(context, config),
    _buildProductsSection(context, config),
    _buildFormsSection(context, config),

    // NOVA SECAO
    if (_store.order?.id != null)
      OrderCommentsSection(
        companyId: _store.companyId!,
        orderId: _store.order!.id!,
      ),

    const SizedBox(height: 40),
  ]),
),
```

---

## Internationalizacao (i18n)

### Novas Strings

```json
// lib/l10n/app_pt.arb
{
  "activity": "Atividade",
  "forYou": "Para Você",
  "team": "Equipe",
  "following": "Seguindo",
  "noActivity": "Nenhuma atividade",
  "noActivityDescription": "Quando sua equipe comentar ou te mencionar, você verá aqui.",
  "mentionedYou": "mencionou você",
  "commented": "comentou",
  "changedStatus": "alterou o status",
  "orderAssignedToYou": "Nova OS atribuída a você",
  "addedPhotos": "{count, plural, =1{adicionou 1 foto} other{adicionou {count} fotos}}",
  "dueDateToday": "Prazo vence hoje",
  "dueDateIn": "{count, plural, =1{Prazo vence em 1 dia} other{Prazo vence em {count} dias}}",
  "newActivity": "Nova atividade",
  "justNow": "agora",
  "minutesAgo": "{count, plural, =1{há 1 minuto} other{há {count} minutos}}",
  "hoursAgo": "{count, plural, =1{há 1 hora} other{há {count} horas}}",
  "daysAgo": "{count, plural, =1{há 1 dia} other{há {count} dias}}",
  "noComments": "Nenhum comentário ainda",
  "writeComment": "Escreva um comentário...",
  "reply": "Responder",
  "seeAll": "Ver tudo",
  "markAllRead": "Marcar tudo como lido"
}

// lib/l10n/app_en.arb
{
  "activity": "Activity",
  "forYou": "For You",
  "team": "Team",
  "following": "Following",
  "noActivity": "No activity yet",
  "noActivityDescription": "When your team comments or mentions you, you'll see it here.",
  "mentionedYou": "mentioned you",
  "commented": "commented",
  "changedStatus": "changed status",
  "orderAssignedToYou": "New order assigned to you",
  "addedPhotos": "{count, plural, =1{added 1 photo} other{added {count} photos}}",
  "dueDateToday": "Due date is today",
  "dueDateIn": "{count, plural, =1{Due in 1 day} other{Due in {count} days}}",
  "newActivity": "New activity",
  "justNow": "just now",
  "minutesAgo": "{count, plural, =1{1 minute ago} other{{count} minutes ago}}",
  "hoursAgo": "{count, plural, =1{1 hour ago} other{{count} hours ago}}",
  "daysAgo": "{count, plural, =1{1 day ago} other{{count} days ago}}",
  "noComments": "No comments yet",
  "writeComment": "Write a comment...",
  "reply": "Reply",
  "seeAll": "See all",
  "markAllRead": "Mark all as read"
}

// lib/l10n/app_es.arb
{
  "activity": "Actividad",
  "forYou": "Para Ti",
  "team": "Equipo",
  "following": "Siguiendo",
  "noActivity": "Sin actividad",
  "noActivityDescription": "Cuando tu equipo comente o te mencione, lo verás aquí.",
  "mentionedYou": "te mencionó",
  "commented": "comentó",
  "changedStatus": "cambió el estado",
  "orderAssignedToYou": "Nueva OS asignada a ti",
  "addedPhotos": "{count, plural, =1{añadió 1 foto} other{añadió {count} fotos}}",
  "dueDateToday": "La fecha de entrega es hoy",
  "dueDateIn": "{count, plural, =1{Vence en 1 día} other{Vence en {count} días}}",
  "newActivity": "Nueva actividad",
  "justNow": "ahora",
  "minutesAgo": "{count, plural, =1{hace 1 minuto} other{hace {count} minutos}}",
  "hoursAgo": "{count, plural, =1{hace 1 hora} other{hace {count} horas}}",
  "daysAgo": "{count, plural, =1{hace 1 día} other{hace {count} días}}",
  "noComments": "Sin comentarios aún",
  "writeComment": "Escribe un comentario...",
  "reply": "Responder",
  "seeAll": "Ver todo",
  "markAllRead": "Marcar todo como leído"
}
```

---

## Cloud Functions (Backend)

### Enviar Push Notifications

```typescript
// functions/src/notifications.ts

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Trigger quando uma nova atividade e criada
 */
export const onActivityCreated = functions.firestore
  .document('companies/{companyId}/activities/{activityId}')
  .onCreate(async (snap, context) => {
    const activity = snap.data();
    const { companyId } = context.params;

    // Criar notificacoes para cada target user
    const targetUsers = activity.targetUsers || [];

    for (const userId of targetUsers) {
      await createNotification(companyId, userId, activity, snap.id);
    }
  });

async function createNotification(
  companyId: string,
  userId: string,
  activity: any,
  activityId: string
) {
  // Buscar dados do usuario
  const userDoc = await db
    .collection('companies')
    .doc(companyId)
    .collection('collaborators')
    .doc(userId)
    .get();

  if (!userDoc.exists) return;

  const userData = userDoc.data()!;
  const fcmTokens = userData.fcmTokens || [];

  // Criar notificacao no Firestore
  const notification = {
    activityId,
    activityType: activity.type,
    title: getNotificationTitle(activity),
    body: getNotificationBody(activity),
    orderId: activity.order?.id,
    orderNumber: activity.order?.number,
    read: false,
    pushSent: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  const notifRef = await db
    .collection('companies')
    .doc(companyId)
    .collection('collaborators')
    .doc(userId)
    .collection('notifications')
    .add(notification);

  // Enviar push notification
  if (fcmTokens.length > 0) {
    const message = {
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: {
        type: activity.type,
        orderId: activity.order?.id || '',
        activityId,
      },
      tokens: fcmTokens,
    };

    try {
      await messaging.sendEachForMulticast(message);
      await notifRef.update({ pushSent: true, pushSentAt: admin.firestore.FieldValue.serverTimestamp() });
    } catch (error) {
      console.error('Error sending push:', error);
    }
  }
}

function getNotificationTitle(activity: any): string {
  switch (activity.type) {
    case 'mention':
      return `${activity.actor?.name} mencionou você`;
    case 'comment':
      return `Novo comentário em OS #${activity.order?.number}`;
    case 'status_change':
      return `Status alterado: OS #${activity.order?.number}`;
    case 'order_assigned':
      return 'Nova OS atribuída a você';
    case 'due_date_alert':
      return 'Prazo próximo do vencimento';
    default:
      return 'Nova atividade';
  }
}

function getNotificationBody(activity: any): string {
  switch (activity.type) {
    case 'mention':
    case 'comment':
      return activity.data?.commentText || '';
    case 'status_change':
      return `${activity.data?.oldStatus} → ${activity.data?.newStatus}`;
    case 'order_assigned':
      return `OS #${activity.order?.number} - ${activity.order?.customerName}`;
    case 'due_date_alert':
      const days = activity.data?.daysRemaining || 0;
      return days === 0
        ? `OS #${activity.order?.number} vence hoje!`
        : `OS #${activity.order?.number} vence em ${days} dias`;
    default:
      return '';
  }
}

/**
 * Scheduled function para alertas de prazo
 * Roda diariamente as 8h
 */
export const scheduledDueDateAlerts = functions.pubsub
  .schedule('0 8 * * *')
  .timeZone('America/Sao_Paulo')
  .onRun(async () => {
    const companies = await db.collection('companies').get();

    for (const company of companies.docs) {
      await checkDueDatesForCompany(company.id);
    }
  });

async function checkDueDatesForCompany(companyId: string) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);

  const in3Days = new Date(today);
  in3Days.setDate(in3Days.getDate() + 3);

  // Buscar OSs com prazo proximo
  const ordersSnap = await db
    .collection('companies')
    .doc(companyId)
    .collection('orders')
    .where('status', 'not-in', ['done', 'canceled'])
    .where('dueDate', '>=', today)
    .where('dueDate', '<=', in3Days)
    .get();

  for (const orderDoc of ordersSnap.docs) {
    const order = orderDoc.data();
    const dueDate = order.dueDate.toDate();

    const diffTime = dueDate.getTime() - today.getTime();
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

    // Criar atividade de alerta
    const activity = {
      type: 'due_date_alert',
      order: {
        id: orderDoc.id,
        number: order.number,
        customerName: order.customer?.name,
      },
      actor: null,
      data: {
        dueDate: order.dueDate,
        daysRemaining: diffDays,
      },
      targetUsers: getOrderTargetUsers(order),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db
      .collection('companies')
      .doc(companyId)
      .collection('activities')
      .add(activity);
  }
}

function getOrderTargetUsers(order: any): string[] {
  const targets = new Set<string>();

  if (order.createdBy?.id) targets.add(order.createdBy.id);
  if (order.assignedTo?.id) targets.add(order.assignedTo.id);

  return Array.from(targets);
}
```

---

## Firestore Security Rules

```javascript
// firestore.rules

rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }

    function isCompanyMember(companyId) {
      return isAuthenticated() &&
        exists(/databases/$(database)/documents/companies/$(companyId)/collaborators/$(request.auth.uid));
    }

    // Companies
    match /companies/{companyId} {
      allow read: if isCompanyMember(companyId);

      // Orders
      match /orders/{orderId} {
        allow read, write: if isCompanyMember(companyId);

        // Comments (subcollection)
        match /comments/{commentId} {
          allow read: if isCompanyMember(companyId);
          allow create: if isCompanyMember(companyId) &&
            request.resource.data.author.id == request.auth.uid;
          allow update: if isCompanyMember(companyId) &&
            (resource.data.author.id == request.auth.uid ||
             request.resource.data.diff(resource.data).affectedKeys().hasOnly(['reactions']));
          allow delete: if isCompanyMember(companyId) &&
            resource.data.author.id == request.auth.uid;
        }
      }

      // Activities
      match /activities/{activityId} {
        allow read: if isCompanyMember(companyId);
        allow create: if isCompanyMember(companyId);
        // Nao permitir update/delete de atividades
      }

      // Collaborators
      match /collaborators/{userId} {
        allow read: if isCompanyMember(companyId);
        allow update: if isCompanyMember(companyId) &&
          request.auth.uid == userId &&
          request.resource.data.diff(resource.data).affectedKeys().hasOnly(['fcmTokens', 'lastTokenUpdate']);

        // Notifications (subcollection)
        match /notifications/{notificationId} {
          allow read: if request.auth.uid == userId;
          allow update: if request.auth.uid == userId &&
            request.resource.data.diff(resource.data).affectedKeys().hasOnly(['read', 'readAt']);
          // Nao permitir create/delete pelo cliente
        }
      }
    }
  }
}
```

---

## Firestore Indexes

```json
// firestore.indexes.json

{
  "indexes": [
    {
      "collectionGroup": "comments",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "isDeleted", "order": "ASCENDING" },
        { "fieldPath": "parentId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "activities",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "targetUsers", "arrayConfig": "CONTAINS" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "activities",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "order.id", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "notifications",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "read", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ]
}
```

---

## Plano de Implementacao

### Fase 1: Fundacao (MVP)

| Task | Descricao | Arquivos |
|------|-----------|----------|
| 1.1 | Models Comment e Activity | `lib/models/comment.dart`, `lib/models/activity.dart` |
| 1.2 | Repositories | `lib/repositories/comment_repository.dart`, `lib/repositories/activity_repository.dart` |
| 1.3 | Stores MobX | `lib/mobx/comment_store.dart`, `lib/mobx/activity_feed_store.dart` |
| 1.4 | Secao de comentarios na OS | `lib/screens/widgets/order_comments_section.dart` |
| 1.5 | Tela do Feed | `lib/screens/feed/activity_feed_screen.dart` |
| 1.6 | Atualizar navegacao | `lib/screens/menu_navigation/navigation_controller.dart` |
| 1.7 | Strings i18n | `lib/l10n/app_*.arb` |
| 1.8 | Security Rules e Indexes | `firestore.rules`, `firestore.indexes.json` |

### Fase 2: Notificacoes

| Task | Descricao | Arquivos |
|------|-----------|----------|
| 2.1 | ActivityService (criar atividades) | `lib/services/activity_service.dart` |
| 2.2 | NotificationService (FCM) | `lib/services/notification_service.dart` |
| 2.3 | Cloud Function - Push | `functions/src/notifications.ts` |
| 2.4 | Badge na TabBar | `lib/screens/menu_navigation/navigation_controller.dart` |

### Fase 3: Mencoes e Melhorias

| Task | Descricao | Arquivos |
|------|-----------|----------|
| 3.1 | Parser de @mentions | `lib/utils/mention_parser.dart` |
| 3.2 | Seletor de usuarios | `lib/screens/widgets/user_mention_selector.dart` |
| 3.3 | Rich text com mentions | `lib/screens/widgets/mention_text.dart` |
| 3.4 | Seguir OS | `lib/services/follow_service.dart` |
| 3.5 | Alertas de prazo (scheduler) | `functions/src/notifications.ts` |

### Fase 4: Polish

| Task | Descricao | Arquivos |
|------|-----------|----------|
| 4.1 | Reacoes em comentarios | Atualizar `comment_store.dart` |
| 4.2 | Respostas (threading) | Atualizar `order_comments_section.dart` |
| 4.3 | Anexar fotos em comentarios | `lib/services/comment_photo_service.dart` |
| 4.4 | Agrupamento de atividades | Atualizar `activity_feed_store.dart` |
| 4.5 | Pull-to-refresh e animacoes | UI refinements |

---

## Metricas de Sucesso

| Metrica | Descricao | Meta |
|---------|-----------|------|
| Adocao | % de usuarios que usam comentarios | > 50% em 30 dias |
| Engajamento | Comentarios por OS (media) | > 2 |
| Retencao | Usuarios que voltam pelo feed | > 30% DAU |
| Substituicao WhatsApp | Reducao de msgs no grupo | Qualitativo |

---

## Consideracoes Futuras

### Portal do Cliente (Fase 5+)

- Comentarios com `visibility: 'client'` aparecem no portal
- Cliente pode responder
- Notificacoes por email para cliente

### Inteligencia (Fase 6+)

- Base de conhecimento: comentarios marcados como "solucao"
- Busca por problemas similares
- Sugestoes baseadas em historico

### Gamificacao (Opcional)

- Badges por marcos (100 OSs, 50 comentarios)
- Ranking de equipe (semanal/mensal)
- Reconhecimento por solucoes

---

## Referencias

- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [Apple HIG - Notifications](https://developer.apple.com/design/human-interface-guidelines/notifications)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)
