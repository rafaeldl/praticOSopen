# Social Features V2 - Conversas por OS (Estilo WhatsApp)

## Visao Geral

Esta versao propoe uma abordagem diferente para as funcionalidades sociais do PraticOS, inspirada na UX do WhatsApp. Em vez de um feed cronologico de atividades, cada OS se torna uma "conversa" com sua propria timeline.

### Objetivo Principal

**Substituir o WhatsApp** como ferramenta de comunicacao da equipe, oferecendo uma experiencia familiar mas com contexto integrado a OS.

### Diferencas da V1

| Aspecto | V1 (Feed Cronologico) | V2 (Conversas) |
|---------|----------------------|----------------|
| Modelo mental | Timeline de eventos | Lista de conversas |
| Navegacao | Feed → Tap → OS | Lista → Conversa → Detalhes |
| Agrupamento | Por tempo | Por OS |
| Indicador | Nenhum especifico | Nao lidas + Badge |
| Acao esperada | Consumir informacao | Resolver pendencia |

---

## UX Flow

```
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│                 │      │                 │      │                 │
│  Lista de OSs   │      │   Conversas     │      │  Detalhes OS    │
│  (Home atual)   │      │  (Nova aba)     │      │  (Tela atual)   │
│                 │      │                 │      │                 │
└────────┬────────┘      └────────┬────────┘      └────────┬────────┘
         │                        │                        │
         │   Tap OS               │   Tap conversa         │   Tap (i)
         └───────────────────────>│───────────────────────>│
                                  │                        │
                                  │   ┌─────────────┐      │
                                  │   │             │      │
                                  └──>│  Timeline   │<─────┘
                                      │  da OS      │
                                      │  (Chat)     │
                                      │             │
                                      └─────────────┘
```

### Fluxos Principais

1. **Ver conversas pendentes**: Aba Conversas → Lista com nao lidas no topo
2. **Responder mencao**: Notificacao → Conversa → Responder
3. **Discutir OS**: Home → Tap OS → Timeline → Enviar mensagem
4. **Ver detalhes**: Conversa → Botao (i) → Tela de detalhes atual

---

## Estrutura de Navegacao

### TabBar Atualizada

```
┌─────────────────────────────────────────┐
│                                         │
│              [Conteudo]                 │
│                                         │
├─────────────────────────────────────────┤
│  🏠       💬        👥       •••       │
│  OSs    Conversas  Clientes  Mais      │
│           (5)                          │
└─────────────────────────────────────────┘
```

| Tab | Icone | Label | Funcao |
|-----|-------|-------|--------|
| 0 | 🏠 | OSs | Lista de OSs (home atual) |
| 1 | 💬 | Conversas | Lista estilo WhatsApp |
| 2 | 👥 | Clientes | Lista de clientes |
| 3 | ••• | Mais | Configuracoes |

---

## Tela: Lista de Conversas

### Layout

```
┌─────────────────────────────────────────┐
│                                         │
│  Conversas                              │
│                                         │
├─────────────────────────────────────────┤
│  🔍 Buscar...                           │
├─────────────────────────────────────────┤
│                                         │
│  ┌─────────────────────────────────────┐│
│  │┌────┐                               ││
│  ││ 🔵 │ OS #1234 • Joao Silva    10:30││
│  ││img │ Maria: @voce pode usar...     ││
│  │└────┘                               ││
│  └─────────────────────────────────────┘│
│                                         │
│  ┌─────────────────────────────────────┐│
│  │┌────┐                          (3)  ││
│  ││ 🔵 │ OS #1230 • Ana Paula    09:15 ││
│  ││img │ Carlos adicionou 3 fotos      ││
│  │└────┘                               ││
│  └─────────────────────────────────────┘│
│                                         │
│  ┌─────────────────────────────────────┐│
│  │┌────┐                               ││
│  ││    │ OS #1228 • Fernanda     Ontem ││
│  ││img │ Voce: Orcamento enviado ✓✓    ││
│  │└────┘                               ││
│  └─────────────────────────────────────┘│
│                                         │
│  ┌─────────────────────────────────────┐│
│  │┌────┐                               ││
│  ││ ⚠️ │ OS #1220 • Pedro         8:00 ││
│  ││img │ ⚠️ Prazo vence hoje!          ││
│  │└────┘                               ││
│  └─────────────────────────────────────┘│
│                                         │
└─────────────────────────────────────────┘
```

### Componentes do Item

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  ┌──────┐  OS #1234 • Joao Silva              10:30    │
│  │      │                                       🔵     │
│  │ img  │  Maria: @voce pode usar a peca X?    (3)    │
│  │      │                                              │
│  └──────┘                                              │
│                                                         │
│  [thumb]  [titulo]  [cliente]           [hora] [badge] │
│           [preview da ultima atividade]                │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Indicadores Visuais

| Indicador | Significado | Visual |
|-----------|-------------|--------|
| 🔵 Dot azul | Atividade nao lida | Dot 10px ao lado do thumb |
| (N) Badge | Quantidade nao lida | Numero em circulo azul |
| ✓✓ Azul | Mensagem lida | Checkmarks azuis |
| ✓✓ Cinza | Mensagem entregue | Checkmarks cinza |
| ⚠️ Amarelo | Alerta de prazo | Icone de warning |
| 🔴 Vermelho | Prazo vencido | Dot vermelho |

### Ordenacao

1. **Nao lidas** (mais recente primeiro)
2. **Com alertas** (prazo vencendo)
3. **Lidas** (mais recente primeiro)

### Filtros (Opcional - Pull down)

```
┌─────────────────────────────────────────┐
│  [Todas] [Nao lidas] [Minhas] [Alertas] │
└─────────────────────────────────────────┘
```

- **Todas**: Todas as conversas com atividade
- **Nao lidas**: Apenas com pendencias
- **Minhas**: OSs atribuidas a mim ou que criei
- **Alertas**: Com prazo vencendo/vencido

---

## Tela: Timeline da OS (Chat)

### Layout Principal

```
┌─────────────────────────────────────────┐
│  ←  OS #1234                    ℹ️  ••• │
│      Joao Silva • Troca de oleo         │
├─────────────────────────────────────────┤
│                                         │
│           ┌───────────────┐             │
│           │  15 Jan 2025  │             │
│           └───────────────┘             │
│                                         │
│  ┌────────────────────────────┐         │
│  │ 📋 OS Criada               │         │
│  │ Status: Orcamento          │         │
│  │ Cliente: Joao Silva        │         │
│  │ Dispositivo: Fiat Uno 2015 │         │
│  └────────────────────────────┘         │
│                        Sistema, 09:00   │
│                                         │
│  ┌────────────────────────────┐         │
│  │ 📷 3 fotos adicionadas     │         │
│  │ ┌─────┬─────┬─────┐        │         │
│  │ │     │     │     │        │         │
│  │ │ img │ img │ img │        │         │
│  │ │     │     │     │        │         │
│  │ └─────┴─────┴─────┘        │         │
│  └────────────────────────────┘         │
│                        Voce, 09:30  ✓✓  │
│                                         │
│  ┌────────────────────────────┐         │
│  │ 💰 Servico adicionado      │         │
│  │ Troca de oleo - R$ 80,00   │         │
│  └────────────────────────────┘         │
│                        Voce, 09:45  ✓✓  │
│                                         │
│           ┌───────────────┐             │
│           │     Hoje      │             │
│           └───────────────┘             │
│                                         │
│  ┌────────────────────────────┐         │
│  │ ✅ Status alterado         │         │
│  │ Orcamento → Aprovado       │         │
│  └────────────────────────────┘         │
│                       Maria, 10:00      │
│                                         │
│         ┌────────────────────────────┐  │
│         │ @Joao, pode usar a peca   │  │
│         │ alternativa ou precisa    │  │
│         │ ser original?             │  │
│         └────────────────────────────┘  │
│                       Maria, 10:30      │
│                                         │
├─────────────────────────────────────────┤
│  ┌─────────────────────────────────┐    │
│  │ Mensagem...           📷  📎  ➤│    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

### Header da Conversa

```
┌─────────────────────────────────────────┐
│  ←  OS #1234                    ℹ️  ••• │
│      Joao Silva • Troca de oleo         │
└─────────────────────────────────────────┘
     │                             │    │
     │                             │    └── Menu de acoes
     │                             └─────── Ir para detalhes da OS
     └─────────────────────────────────── Numero + Cliente + Servico principal
```

### Tipos de Evento na Timeline

#### 1. Criacao da OS
```
┌────────────────────────────────┐
│ 📋 OS Criada                   │
│                                │
│ Status: Orcamento              │
│ Cliente: Joao Silva            │
│ Dispositivo: Fiat Uno 2015     │
│ Entrega: 20/01/2025            │
└────────────────────────────────┘
                  Sistema, 09:00
```

#### 2. Mudanca de Status
```
┌────────────────────────────────┐
│ ✅ Status alterado             │
│ Orcamento → Aprovado           │
└────────────────────────────────┘
                  Maria, 10:00
```

#### 3. Fotos Adicionadas
```
┌────────────────────────────────┐
│ 📷 3 fotos adicionadas         │
│ ┌─────┬─────┬─────┐            │
│ │     │     │     │            │
│ │ img │ img │ img │            │
│ │     │     │     │            │
│ └─────┴─────┴─────┘            │
└────────────────────────────────┘
                  Voce, 09:30 ✓✓
```

#### 4. Servico/Produto Adicionado
```
┌────────────────────────────────┐
│ 🔧 Servico adicionado          │
│ Troca de oleo - R$ 80,00       │
└────────────────────────────────┘
                  Voce, 09:45 ✓✓

┌────────────────────────────────┐
│ 📦 Produto adicionado          │
│ Oleo 5W30 (4x) - R$ 200,00     │
└────────────────────────────────┘
                  Voce, 09:50 ✓✓
```

#### 5. Comentario/Mensagem
```
        ┌────────────────────────────┐
        │ @Joao, pode usar a peca   │
        │ alternativa ou precisa    │
        │ ser original?             │
        └────────────────────────────┘
                      Maria, 10:30

┌────────────────────────────────┐
│ Pode ser alternativa, tem em   │
│ estoque e o cliente ja aprovou │
└────────────────────────────────┘
Voce, 10:35                   ✓✓
```

#### 6. Formulario Concluido
```
┌────────────────────────────────┐
│ 📝 Checklist concluido         │
│ Vistoria de Entrada            │
│ 15/15 itens ✓                  │
│                    [Ver →]     │
└────────────────────────────────┘
                  Carlos, 11:00
```

#### 7. Pagamento Recebido
```
┌────────────────────────────────┐
│ 💰 Pagamento recebido          │
│ R$ 280,00 via PIX              │
│ Restante: R$ 0,00              │
└────────────────────────────────┘
                  Maria, 14:00
```

#### 8. Alerta de Sistema
```
┌────────────────────────────────┐
│ ⚠️ Prazo vence amanha!         │
│ Entrega prevista: 20/01/2025   │
└────────────────────────────────┘
                  Sistema, 08:00
```

#### 9. Mensagem com Anexo
```
        ┌────────────────────────────┐
        │ Olha o estado da peca:    │
        │                            │
        │ ┌────────────────────┐     │
        │ │                    │     │
        │ │    [foto anexa]    │     │
        │ │                    │     │
        │ └────────────────────┘     │
        └────────────────────────────┘
                      Carlos, 11:30
```

### Input de Mensagem

#### Estado Normal
```
┌─────────────────────────────────────────┐
│  Mensagem...                  📷  📎  ➤ │
└─────────────────────────────────────────┘
```

#### Digitando
```
┌─────────────────────────────────────────┐
│  @Mar|                                  │
│  ┌─────────────────────────────────┐    │
│  │ 👤 Maria Silva                  │    │  ← Autocomplete
│  │ 👤 Marcos Tecnico               │    │
│  └─────────────────────────────────┘    │
│                               📷  📎  ➤ │
└─────────────────────────────────────────┘
```

#### Expandido (Multiline)
```
┌─────────────────────────────────────────┐
│  @Maria, vou precisar pedir a peca     │
│  porque nao tem em estoque. O cliente  │
│  pode esperar ate sexta?               │
│  ─────────────────────────────────────  │
│  📷 Foto  📎 Arquivo           [Enviar] │
└─────────────────────────────────────────┘
```

### Menu de Acoes (...)

```
┌─────────────────────────────────────────┐
│              Opcoes                     │
├─────────────────────────────────────────┤
│  📄  Ver detalhes da OS                 │
│  📷  Adicionar fotos                    │
│  📋  Preencher formulario               │
│  🔔  Silenciar conversa                 │
│  📌  Fixar conversa                     │
├─────────────────────────────────────────┤
│  ❌  Cancelar                           │
└─────────────────────────────────────────┘
```

---

## Arquitetura Firestore

### Estrutura de Collections

```
/companies/{companyId}/
│
├── orders/{orderId}/
│   │
│   ├── ... (campos existentes)
│   │
│   ├── lastActivity: {              // Agregado para lista
│   │     type: 'comment',
│   │     preview: '@Joao pode usar...',
│   │     authorId: 'user123',
│   │     authorName: 'Maria',
│   │     createdAt: Timestamp
│   │   }
│   │
│   ├── unreadCounts: {              // Contadores por usuario
│   │     'user123': 0,
│   │     'user456': 3
│   │   }
│   │
│   └── timeline/{eventId}           // Subcollection de eventos
│         ├── type: string
│         ├── author: { id, name, photoUrl }
│         ├── data: { ... }
│         ├── readBy: ['user123', 'user456']
│         ├── createdAt: Timestamp
│         └── ...
│
└── users/{userId}/
    └── conversationSettings/{orderId}  // Configs por conversa
          ├── muted: boolean
          ├── pinned: boolean
          └── lastReadAt: Timestamp
```

### Timeline Event Schema

```typescript
interface TimelineEvent {
  id: string;

  // Tipo do evento
  type: TimelineEventType;

  // Autor (null para eventos de sistema)
  author: {
    id: string;
    name: string;
    photoUrl?: string;
  } | null;

  // Dados especificos por tipo
  data: TimelineEventData;

  // Tracking de leitura
  readBy: string[];  // Lista de userIds que leram

  // Mencoes (para queries)
  mentions: string[];  // Lista de userIds mencionados

  // Timestamps
  createdAt: Timestamp;
  updatedAt?: Timestamp;

  // Soft delete
  isDeleted: boolean;
}

type TimelineEventType =
  | 'order_created'      // OS criada
  | 'status_change'      // Mudanca de status
  | 'photos_added'       // Fotos adicionadas
  | 'service_added'      // Servico adicionado
  | 'service_updated'    // Servico atualizado
  | 'service_removed'    // Servico removido
  | 'product_added'      // Produto adicionado
  | 'product_updated'    // Produto atualizado
  | 'product_removed'    // Produto removido
  | 'form_completed'     // Formulario concluido
  | 'payment_received'   // Pagamento recebido
  | 'due_date_alert'     // Alerta de prazo
  | 'comment'            // Comentario/mensagem
  | 'assignment_change'; // Mudanca de responsavel

interface TimelineEventData {
  // Para comment
  text?: string;
  attachments?: Attachment[];

  // Para status_change
  oldStatus?: string;
  newStatus?: string;

  // Para photos_added
  photoUrls?: string[];

  // Para service/product
  itemName?: string;
  itemValue?: number;
  itemQuantity?: number;

  // Para form_completed
  formName?: string;
  formId?: string;
  totalItems?: number;

  // Para payment_received
  amount?: number;
  method?: string;
  remaining?: number;

  // Para due_date_alert
  dueDate?: Timestamp;
  daysRemaining?: number;

  // Para assignment_change
  oldAssignee?: { id: string; name: string };
  newAssignee?: { id: string; name: string };
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

### Order Schema (Campos Adicionais)

```typescript
// Adicionar ao modelo Order existente

interface OrderSocialFields {
  // Preview da ultima atividade (para lista)
  lastActivity?: {
    type: TimelineEventType;
    preview: string;        // Texto truncado para exibicao
    authorId?: string;
    authorName?: string;
    createdAt: Timestamp;
  };

  // Contadores de nao lidos por usuario
  unreadCounts?: {
    [userId: string]: number;
  };

  // Usuarios que estao "seguindo" esta OS
  followers?: string[];
}
```

---

## Models Flutter

### TimelineEvent Model

```dart
// lib/models/timeline_event.dart

import 'package:json_annotation/json_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'timeline_event.g.dart';

@JsonSerializable(explicitToJson: true)
class TimelineEvent {
  String? id;
  String? type;
  TimelineAuthor? author;
  TimelineEventData? data;
  List<String>? readBy;
  List<String>? mentions;

  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  DateTime? createdAt;

  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  DateTime? updatedAt;

  bool? isDeleted;

  TimelineEvent();

  factory TimelineEvent.fromJson(Map<String, dynamic> json) =>
      _$TimelineEventFromJson(json);
  Map<String, dynamic> toJson() => _$TimelineEventToJson(this);

  // Helpers
  bool isReadBy(String userId) => readBy?.contains(userId) ?? false;

  bool get isSystemEvent => author == null;

  bool get isComment => type == 'comment';

  static DateTime? _timestampFromJson(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.parse(value);
    return null;
  }

  static dynamic _timestampToJson(DateTime? date) =>
      date != null ? Timestamp.fromDate(date) : null;
}

@JsonSerializable()
class TimelineAuthor {
  String? id;
  String? name;
  String? photoUrl;

  TimelineAuthor();

  factory TimelineAuthor.fromJson(Map<String, dynamic> json) =>
      _$TimelineAuthorFromJson(json);
  Map<String, dynamic> toJson() => _$TimelineAuthorToJson(this);
}

@JsonSerializable(explicitToJson: true)
class TimelineEventData {
  // Comment
  String? text;
  List<TimelineAttachment>? attachments;

  // Status change
  String? oldStatus;
  String? newStatus;

  // Photos
  List<String>? photoUrls;

  // Service/Product
  String? itemName;
  double? itemValue;
  int? itemQuantity;

  // Form
  String? formName;
  String? formId;
  int? totalItems;

  // Payment
  double? amount;
  String? method;
  double? remaining;

  // Due date alert
  @JsonKey(fromJson: TimelineEvent._timestampFromJson, toJson: TimelineEvent._timestampToJson)
  DateTime? dueDate;
  int? daysRemaining;

  // Assignment
  TimelineAuthor? oldAssignee;
  TimelineAuthor? newAssignee;

  TimelineEventData();

  factory TimelineEventData.fromJson(Map<String, dynamic> json) =>
      _$TimelineEventDataFromJson(json);
  Map<String, dynamic> toJson() => _$TimelineEventDataToJson(this);
}

@JsonSerializable()
class TimelineAttachment {
  String? id;
  String? type;
  String? url;
  String? thumbnailUrl;
  String? name;
  int? size;

  TimelineAttachment();

  factory TimelineAttachment.fromJson(Map<String, dynamic> json) =>
      _$TimelineAttachmentFromJson(json);
  Map<String, dynamic> toJson() => _$TimelineAttachmentToJson(this);
}
```

### LastActivity Model (Agregado)

```dart
// lib/models/last_activity.dart

import 'package:json_annotation/json_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'last_activity.g.dart';

@JsonSerializable()
class LastActivity {
  String? type;
  String? preview;
  String? authorId;
  String? authorName;

  @JsonKey(fromJson: _timestampFromJson, toJson: _timestampToJson)
  DateTime? createdAt;

  LastActivity();

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

## Repositories

### TimelineRepository

```dart
// lib/repositories/timeline_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/timeline_event.dart';
import 'package:praticos/global.dart';

class TimelineRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  /// Stream de eventos da timeline (ordenados por data)
  Stream<List<TimelineEvent>> getTimeline(
    String companyId,
    String orderId,
  ) {
    return _timelineRef(companyId, orderId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TimelineEvent.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Criar evento na timeline
  Future<TimelineEvent> createEvent(
    String companyId,
    String orderId,
    TimelineEvent event,
  ) async {
    // Adicionar evento
    final docRef = await _timelineRef(companyId, orderId).add(event.toJson());
    event.id = docRef.id;

    // Atualizar lastActivity na OS
    await _updateLastActivity(companyId, orderId, event);

    // Incrementar contadores de nao lidos (exceto para o autor)
    await _incrementUnreadCounts(companyId, orderId, event.author?.id);

    return event;
  }

  /// Marcar evento como lido
  Future<void> markAsRead(
    String companyId,
    String orderId,
    String eventId,
    String userId,
  ) async {
    await _timelineRef(companyId, orderId).doc(eventId).update({
      'readBy': FieldValue.arrayUnion([userId]),
    });
  }

  /// Marcar todos eventos como lidos
  Future<void> markAllAsRead(
    String companyId,
    String orderId,
    String userId,
  ) async {
    final batch = _firestore.batch();

    // Buscar eventos nao lidos
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

    // Zerar contador de nao lidos
    batch.update(_orderRef(companyId, orderId), {
      'unreadCounts.$userId': 0,
    });

    await batch.commit();
  }

  /// Enviar comentario
  Future<TimelineEvent> sendComment(
    String companyId,
    String orderId,
    String text, {
    List<String>? mentions,
    List<TimelineAttachment>? attachments,
  }) async {
    final event = TimelineEvent()
      ..type = 'comment'
      ..author = TimelineAuthor()
        ..id = Global.currentUser?.id
        ..name = Global.currentUser?.name
        ..photoUrl = Global.currentUser?.photoUrl
      ..data = TimelineEventData()
        ..text = text
        ..attachments = attachments
      ..readBy = [Global.currentUser?.id ?? '']
      ..mentions = mentions ?? _parseMentions(text)
      ..createdAt = DateTime.now()
      ..isDeleted = false;

    return createEvent(companyId, orderId, event);
  }

  /// Criar evento de mudanca de status
  Future<void> createStatusChangeEvent(
    String companyId,
    String orderId,
    String oldStatus,
    String newStatus,
  ) async {
    final event = TimelineEvent()
      ..type = 'status_change'
      ..author = TimelineAuthor()
        ..id = Global.currentUser?.id
        ..name = Global.currentUser?.name
        ..photoUrl = Global.currentUser?.photoUrl
      ..data = TimelineEventData()
        ..oldStatus = oldStatus
        ..newStatus = newStatus
      ..readBy = [Global.currentUser?.id ?? '']
      ..mentions = []
      ..createdAt = DateTime.now()
      ..isDeleted = false;

    await createEvent(companyId, orderId, event);
  }

  /// Criar evento de fotos adicionadas
  Future<void> createPhotosAddedEvent(
    String companyId,
    String orderId,
    List<String> photoUrls,
  ) async {
    final event = TimelineEvent()
      ..type = 'photos_added'
      ..author = TimelineAuthor()
        ..id = Global.currentUser?.id
        ..name = Global.currentUser?.name
        ..photoUrl = Global.currentUser?.photoUrl
      ..data = TimelineEventData()
        ..photoUrls = photoUrls
      ..readBy = [Global.currentUser?.id ?? '']
      ..mentions = []
      ..createdAt = DateTime.now()
      ..isDeleted = false;

    await createEvent(companyId, orderId, event);
  }

  // Helpers privados

  Future<void> _updateLastActivity(
    String companyId,
    String orderId,
    TimelineEvent event,
  ) async {
    String preview = '';

    switch (event.type) {
      case 'comment':
        final authorPrefix = event.author?.id == Global.currentUser?.id
            ? 'Voce'
            : event.author?.name ?? '';
        preview = '$authorPrefix: ${_truncate(event.data?.text ?? '', 50)}';
        break;
      case 'status_change':
        preview = '${event.author?.name}: Status alterado';
        break;
      case 'photos_added':
        final count = event.data?.photoUrls?.length ?? 0;
        preview = '${event.author?.name} adicionou $count foto${count > 1 ? 's' : ''}';
        break;
      case 'form_completed':
        preview = '${event.author?.name} concluiu ${event.data?.formName}';
        break;
      case 'payment_received':
        preview = 'Pagamento recebido: R\$ ${event.data?.amount?.toStringAsFixed(2)}';
        break;
      case 'due_date_alert':
        final days = event.data?.daysRemaining ?? 0;
        preview = days == 0 ? '⚠️ Prazo vence hoje!' : '⚠️ Prazo vence em $days dias';
        break;
      default:
        preview = 'Nova atividade';
    }

    await _orderRef(companyId, orderId).update({
      'lastActivity': {
        'type': event.type,
        'preview': preview,
        'authorId': event.author?.id,
        'authorName': event.author?.name,
        'createdAt': FieldValue.serverTimestamp(),
      },
    });
  }

  Future<void> _incrementUnreadCounts(
    String companyId,
    String orderId,
    String? authorId,
  ) async {
    // Buscar todos os colaboradores da empresa
    final collaborators = await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('collaborators')
        .get();

    final batch = _firestore.batch();

    for (final collab in collaborators.docs) {
      // Nao incrementar para o autor
      if (collab.id != authorId) {
        batch.update(_orderRef(companyId, orderId), {
          'unreadCounts.${collab.id}': FieldValue.increment(1),
        });
      }
    }

    await batch.commit();
  }

  List<String> _parseMentions(String text) {
    final regex = RegExp(r'@(\w+)');
    final matches = regex.allMatches(text);
    // TODO: Mapear usernames para userIds
    return matches.map((m) => m.group(1) ?? '').toList();
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
```

### ConversationRepository

```dart
// lib/repositories/conversation_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/global.dart';

class ConversationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream de conversas ordenadas por ultima atividade
  /// Retorna OSs que tem atividade (lastActivity != null)
  Stream<List<Order>> getConversations(String companyId) {
    final userId = Global.currentUser?.id;

    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('orders')
        .where('lastActivity', isNull: false)
        .orderBy('lastActivity.createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs
              .map((doc) => Order.fromJson({...doc.data(), 'id': doc.id}))
              .toList();

          // Ordenar: nao lidas primeiro, depois por data
          if (userId != null) {
            orders.sort((a, b) {
              final aUnread = a.unreadCounts?[userId] ?? 0;
              final bUnread = b.unreadCounts?[userId] ?? 0;

              // Nao lidas primeiro
              if (aUnread > 0 && bUnread == 0) return -1;
              if (bUnread > 0 && aUnread == 0) return 1;

              // Depois por data
              final aDate = a.lastActivity?.createdAt ?? DateTime(1970);
              final bDate = b.lastActivity?.createdAt ?? DateTime(1970);
              return bDate.compareTo(aDate);
            });
          }

          return orders;
        });
  }

  /// Stream de conversas nao lidas
  Stream<List<Order>> getUnreadConversations(String companyId) {
    final userId = Global.currentUser?.id;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('orders')
        .where('unreadCounts.$userId', isGreaterThan: 0)
        .orderBy('unreadCounts.$userId', descending: true)
        .orderBy('lastActivity.createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Order.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Contagem total de nao lidas
  Stream<int> getTotalUnreadCount(String companyId) {
    final userId = Global.currentUser?.id;
    if (userId == null) return Stream.value(0);

    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('orders')
        .where('unreadCounts.$userId', isGreaterThan: 0)
        .snapshots()
        .map((snapshot) {
          int total = 0;
          for (final doc in snapshot.docs) {
            final unread = (doc.data()['unreadCounts'] as Map<String, dynamic>?)?[userId] ?? 0;
            total += (unread as int);
          }
          return total;
        });
  }

  /// Configuracoes da conversa (mudo, fixado)
  Future<void> updateConversationSettings(
    String companyId,
    String orderId, {
    bool? muted,
    bool? pinned,
  }) async {
    final userId = Global.currentUser?.id;
    if (userId == null) return;

    final updates = <String, dynamic>{};
    if (muted != null) updates['muted'] = muted;
    if (pinned != null) updates['pinned'] = pinned;

    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('users')
        .doc(userId)
        .collection('conversationSettings')
        .doc(orderId)
        .set(updates, SetOptions(merge: true));
  }
}
```

---

## MobX Stores

### ConversationListStore

```dart
// lib/mobx/conversation_list_store.dart

import 'package:mobx/mobx.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/repositories/conversation_repository.dart';
import 'package:praticos/global.dart';

part 'conversation_list_store.g.dart';

enum ConversationFilter { all, unread, mine, alerts }

class ConversationListStore = _ConversationListStore with _$ConversationListStore;

abstract class _ConversationListStore with Store {
  final ConversationRepository _repository = ConversationRepository();

  @observable
  ConversationFilter currentFilter = ConversationFilter.all;

  @observable
  ObservableStream<List<Order>>? conversationsStream;

  @observable
  ObservableStream<int>? totalUnreadStream;

  @observable
  String searchQuery = '';

  String? _companyId;

  @computed
  List<Order> get filteredConversations {
    final conversations = conversationsStream?.value ?? [];

    if (searchQuery.isEmpty) return conversations;

    final query = searchQuery.toLowerCase();
    return conversations.where((order) {
      final number = order.number?.toString() ?? '';
      final customer = order.customer?.name?.toLowerCase() ?? '';
      final device = order.device?.name?.toLowerCase() ?? '';
      return number.contains(query) ||
          customer.contains(query) ||
          device.contains(query);
    }).toList();
  }

  @action
  void init(String companyId) {
    _companyId = companyId;

    conversationsStream = ObservableStream(
      _repository.getConversations(companyId),
    );

    totalUnreadStream = ObservableStream(
      _repository.getTotalUnreadCount(companyId),
    );
  }

  @action
  void setFilter(ConversationFilter filter) {
    currentFilter = filter;
    // TODO: Implementar filtros especificos
  }

  @action
  void setSearchQuery(String query) {
    searchQuery = query;
  }

  @action
  void dispose() {
    conversationsStream = null;
    totalUnreadStream = null;
  }
}
```

### TimelineStore

```dart
// lib/mobx/timeline_store.dart

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
  }

  // Helpers para agrupar eventos por data
  Map<String, List<TimelineEvent>> get eventsByDate {
    final events = timelineStream?.value ?? [];
    final grouped = <String, List<TimelineEvent>>{};

    for (final event in events) {
      final date = _formatDateHeader(event.createdAt);
      grouped.putIfAbsent(date, () => []).add(event);
    }

    return grouped;
  }

  String _formatDateHeader(DateTime? date) {
    if (date == null) return 'Desconhecido';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final eventDate = DateTime(date.year, date.month, date.day);

    if (eventDate == today) return 'Hoje';
    if (eventDate == yesterday) return 'Ontem';
    if (now.difference(date).inDays < 7) {
      const weekdays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab', 'Dom'];
      return weekdays[date.weekday - 1];
    }

    return '${date.day}/${date.month}/${date.year}';
  }
}
```

---

## UI Components

### Tela: Lista de Conversas

```dart
// lib/screens/conversations/conversation_list_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:provider/provider.dart';
import 'package:praticos/mobx/conversation_list_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/widgets/cached_image.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';

class ConversationListScreen extends StatefulWidget {
  @override
  _ConversationListScreenState createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  late ConversationListStore _store;
  final TextEditingController _searchController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _store = Provider.of<ConversationListStore>(context);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: CustomScrollView(
        slivers: [
          _buildNavigationBar(),
          _buildSearchField(),
          _buildConversationList(),
        ],
      ),
    );
  }

  Widget _buildNavigationBar() {
    return CupertinoSliverNavigationBar(
      largeTitle: Text(context.l10n.conversations),
    );
  }

  Widget _buildSearchField() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: CupertinoSearchTextField(
          controller: _searchController,
          placeholder: context.l10n.searchConversations,
          onChanged: (value) => _store.setSearchQuery(value),
        ),
      ),
    );
  }

  Widget _buildConversationList() {
    return Observer(
      builder: (_) {
        final conversations = _store.filteredConversations;

        if (conversations.isEmpty) {
          return SliverFillRemaining(
            child: _buildEmptyState(),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index >= conversations.length) return null;
              return _buildConversationItem(
                conversations[index],
                isLast: index == conversations.length - 1,
              );
            },
            childCount: conversations.length,
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
            CupertinoIcons.chat_bubble_2,
            size: 48,
            color: CupertinoColors.systemGrey.resolveFrom(context),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.noConversations,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.noConversationsDescription,
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

  Widget _buildConversationItem(Order order, {bool isLast = false}) {
    final userId = Global.currentUser?.id;
    final unreadCount = order.unreadCounts?[userId] ?? 0;
    final hasUnread = unreadCount > 0;
    final lastActivity = order.lastActivity;
    final isAlert = lastActivity?.type == 'due_date_alert';

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => _openConversation(order),
      child: Container(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Thumbnail com indicador
                  _buildThumbnail(order, hasUnread, isAlert),
                  const SizedBox(width: 12),

                  // Conteudo
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Linha 1: Titulo + Hora
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'OS #${order.number} • ${order.customer?.name ?? ""}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                                  color: CupertinoColors.label.resolveFrom(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatTime(lastActivity?.createdAt),
                              style: TextStyle(
                                fontSize: 14,
                                color: hasUnread
                                    ? CupertinoColors.activeBlue
                                    : CupertinoColors.secondaryLabel.resolveFrom(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Linha 2: Preview + Badge
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                lastActivity?.preview ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                                  color: hasUnread
                                      ? CupertinoColors.label.resolveFrom(context)
                                      : CupertinoColors.secondaryLabel.resolveFrom(context),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (unreadCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.activeBlue,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  unreadCount > 99 ? '99+' : '$unreadCount',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: CupertinoColors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!isLast)
              Divider(
                height: 1,
                indent: 84,
                color: CupertinoColors.separator.resolveFrom(context),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(Order order, bool hasUnread, bool isAlert) {
    const double size = 56;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Imagem
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: order.coverPhotoUrl != null
                ? CachedImage(
                    imageUrl: order.coverPhotoUrl!,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: size,
                    height: size,
                    color: CupertinoColors.systemGrey5.resolveFrom(context),
                    child: Icon(
                      CupertinoIcons.car_detailed,
                      size: 24,
                      color: CupertinoColors.systemGrey.resolveFrom(context),
                    ),
                  ),
          ),

          // Indicador de nao lido
          if (hasUnread)
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: isAlert
                      ? CupertinoColors.systemOrange
                      : CupertinoColors.activeBlue,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: CupertinoColors.systemBackground.resolveFrom(context),
                    width: 2,
                  ),
                ),
              ),
            ),

          // Indicador de alerta
          if (isAlert && !hasUnread)
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemOrange,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: CupertinoColors.systemBackground.resolveFrom(context),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  CupertinoIcons.exclamationmark,
                  size: 8,
                  color: CupertinoColors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final eventDate = DateTime(date.year, date.month, date.day);

    if (eventDate == today) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    if (eventDate == yesterday) {
      return context.l10n.yesterday;
    }
    if (now.difference(date).inDays < 7) {
      const weekdays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab', 'Dom'];
      return weekdays[date.weekday - 1];
    }

    return '${date.day}/${date.month}';
  }

  void _openConversation(Order order) {
    Navigator.of(context, rootNavigator: true).pushNamed(
      '/conversation',
      arguments: {'order': order},
    );
  }
}
```

### Tela: Timeline (Chat)

```dart
// lib/screens/conversations/conversation_timeline_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:praticos/mobx/timeline_store.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/timeline_event.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/providers/segment_config_provider.dart';
import 'package:provider/provider.dart';

class ConversationTimelineScreen extends StatefulWidget {
  @override
  _ConversationTimelineScreenState createState() => _ConversationTimelineScreenState();
}

class _ConversationTimelineScreenState extends State<ConversationTimelineScreen> {
  final TimelineStore _store = TimelineStore();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Order? _order;

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration.zero, () {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args.containsKey('order')) {
        setState(() => _order = args['order']);

        final companyId = Global.companyAggr?.id;
        if (companyId != null && _order?.id != null) {
          _store.init(companyId, _order!.id!);
        }
      }
    });
  }

  @override
  void dispose() {
    _store.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<SegmentConfigProvider>();

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: _order != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'OS #${_order!.number}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${_order!.customer?.name ?? ""} • ${_getMainService()}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                ],
              )
            : const Text('Conversa'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.info_circle),
              onPressed: () => _openOrderDetails(),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.ellipsis_vertical),
              onPressed: () => _showActionSheet(),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildTimeline(),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    return Observer(
      builder: (_) {
        final eventsByDate = _store.eventsByDate;

        if (eventsByDate.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.chat_bubble,
                  size: 48,
                  color: CupertinoColors.systemGrey.resolveFrom(context),
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.noMessages,
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
          );
        }

        final dateKeys = eventsByDate.keys.toList();

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: dateKeys.length,
          itemBuilder: (context, index) {
            final date = dateKeys[index];
            final events = eventsByDate[date]!;

            return Column(
              children: [
                _buildDateHeader(date),
                ...events.map((event) => _buildEventCard(event)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDateHeader(String date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey5.resolveFrom(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            date,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(TimelineEvent event) {
    final isMyMessage = event.author?.id == Global.currentUser?.id;
    final isSystem = event.isSystemEvent;
    final isComment = event.isComment;

    if (isSystem) {
      return _buildSystemEvent(event);
    }

    if (isComment) {
      return _buildMessageBubble(event, isMyMessage);
    }

    return _buildActivityCard(event, isMyMessage);
  }

  Widget _buildSystemEvent(TimelineEvent event) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6.resolveFrom(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getEventIcon(event.type),
                size: 16,
                color: _getEventColor(event.type),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _getEventText(event),
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(TimelineEvent event, bool isMyMessage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMyMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMyMessage) ...[
            _buildAvatar(event.author),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMyMessage
                    ? CupertinoColors.activeBlue
                    : CupertinoColors.systemGrey5.resolveFrom(context),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMyMessage ? 18 : 4),
                  bottomRight: Radius.circular(isMyMessage ? 4 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMyMessage)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        event.author?.name ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isMyMessage
                              ? CupertinoColors.white.withOpacity(0.8)
                              : CupertinoColors.activeBlue,
                        ),
                      ),
                    ),
                  _buildMessageText(event, isMyMessage),
                  if (event.data?.attachments?.isNotEmpty ?? false)
                    _buildAttachments(event.data!.attachments!),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(event.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: isMyMessage
                              ? CupertinoColors.white.withOpacity(0.7)
                              : CupertinoColors.tertiaryLabel.resolveFrom(context),
                        ),
                      ),
                      if (isMyMessage) ...[
                        const SizedBox(width: 4),
                        Icon(
                          CupertinoIcons.checkmark_alt_circle_fill,
                          size: 14,
                          color: CupertinoColors.white.withOpacity(0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageText(TimelineEvent event, bool isMyMessage) {
    // TODO: Implementar rich text com mentions destacadas
    return Text(
      event.data?.text ?? '',
      style: TextStyle(
        fontSize: 16,
        color: isMyMessage
            ? CupertinoColors.white
            : CupertinoColors.label.resolveFrom(context),
      ),
    );
  }

  Widget _buildActivityCard(TimelineEvent event, bool isMyMessage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMyMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMyMessage) ...[
            _buildAvatar(event.author),
            const SizedBox(width: 8),
          ],
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CupertinoColors.systemGrey5.resolveFrom(context),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getEventIcon(event.type),
                      size: 16,
                      color: _getEventColor(event.type),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getEventTitle(event),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _getEventSubtitle(event),
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
                if (event.type == 'photos_added' &&
                    (event.data?.photoUrls?.isNotEmpty ?? false))
                  _buildPhotoGrid(event.data!.photoUrls!),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      event.author?.name ?? '',
                      style: TextStyle(
                        fontSize: 11,
                        color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '•',
                      style: TextStyle(
                        color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(event.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(TimelineAuthor? author) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: CupertinoColors.systemGrey5.resolveFrom(context),
      backgroundImage:
          author?.photoUrl != null ? NetworkImage(author!.photoUrl!) : null,
      child: author?.photoUrl == null
          ? Icon(
              CupertinoIcons.person_fill,
              size: 14,
              color: CupertinoColors.systemGrey.resolveFrom(context),
            )
          : null,
    );
  }

  Widget _buildAttachments(List<TimelineAttachment> attachments) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: attachments.map((attachment) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              attachment.thumbnailUrl ?? attachment.url ?? '',
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPhotoGrid(List<String> photoUrls) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: photoUrls.take(3).map((url) {
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                url,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        border: Border(
          top: BorderSide(
            color: CupertinoColors.systemGrey5.resolveFrom(context),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            CupertinoButton(
              padding: const EdgeInsets.all(8),
              child: Icon(
                CupertinoIcons.camera_fill,
                color: CupertinoColors.systemGrey,
              ),
              onPressed: () {
                // TODO: Abrir camera
              },
            ),
            CupertinoButton(
              padding: const EdgeInsets.all(8),
              child: Icon(
                CupertinoIcons.paperclip,
                color: CupertinoColors.systemGrey,
              ),
              onPressed: () {
                // TODO: Anexar arquivo
              },
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6.resolveFrom(context),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: CupertinoTextField.borderless(
                  controller: _messageController,
                  placeholder: context.l10n.typeMessage,
                  maxLines: null,
                  style: TextStyle(
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ),
            ),
            Observer(
              builder: (_) => CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: _store.isSending ? null : _sendMessage,
                child: _store.isSending
                    ? const CupertinoActivityIndicator()
                    : Icon(
                        CupertinoIcons.arrow_up_circle_fill,
                        size: 32,
                        color: CupertinoColors.activeBlue,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helpers

  String _getMainService() {
    final services = _order?.services ?? [];
    if (services.isEmpty) return '';
    return services.first.service?.name ?? services.first.description ?? '';
  }

  IconData _getEventIcon(String? type) {
    switch (type) {
      case 'order_created':
        return CupertinoIcons.doc_text_fill;
      case 'status_change':
        return CupertinoIcons.flag_fill;
      case 'photos_added':
        return CupertinoIcons.photo_fill;
      case 'service_added':
      case 'service_updated':
        return CupertinoIcons.wrench_fill;
      case 'product_added':
      case 'product_updated':
        return CupertinoIcons.cube_box_fill;
      case 'form_completed':
        return CupertinoIcons.checkmark_rectangle_fill;
      case 'payment_received':
        return CupertinoIcons.money_dollar_circle_fill;
      case 'due_date_alert':
        return CupertinoIcons.exclamationmark_triangle_fill;
      default:
        return CupertinoIcons.bell_fill;
    }
  }

  Color _getEventColor(String? type) {
    switch (type) {
      case 'order_created':
        return CupertinoColors.activeBlue;
      case 'status_change':
        return CupertinoColors.systemPurple;
      case 'photos_added':
        return CupertinoColors.systemGreen;
      case 'service_added':
      case 'service_updated':
      case 'product_added':
      case 'product_updated':
        return CupertinoColors.systemOrange;
      case 'form_completed':
        return CupertinoColors.systemTeal;
      case 'payment_received':
        return CupertinoColors.systemGreen;
      case 'due_date_alert':
        return CupertinoColors.systemRed;
      default:
        return CupertinoColors.systemGrey;
    }
  }

  String _getEventText(TimelineEvent event) {
    switch (event.type) {
      case 'order_created':
        return 'OS criada';
      case 'due_date_alert':
        final days = event.data?.daysRemaining ?? 0;
        return days == 0 ? 'Prazo vence hoje!' : 'Prazo vence em $days dias';
      default:
        return 'Atividade';
    }
  }

  String _getEventTitle(TimelineEvent event) {
    switch (event.type) {
      case 'status_change':
        return 'Status alterado';
      case 'photos_added':
        final count = event.data?.photoUrls?.length ?? 0;
        return '$count foto${count > 1 ? 's' : ''} adicionada${count > 1 ? 's' : ''}';
      case 'service_added':
        return 'Servico adicionado';
      case 'product_added':
        return 'Produto adicionado';
      case 'form_completed':
        return 'Checklist concluido';
      case 'payment_received':
        return 'Pagamento recebido';
      default:
        return 'Atividade';
    }
  }

  String _getEventSubtitle(TimelineEvent event) {
    switch (event.type) {
      case 'status_change':
        return '${event.data?.oldStatus} → ${event.data?.newStatus}';
      case 'service_added':
      case 'product_added':
        final name = event.data?.itemName ?? '';
        final value = event.data?.itemValue ?? 0;
        return '$name - R\$ ${value.toStringAsFixed(2)}';
      case 'form_completed':
        return event.data?.formName ?? '';
      case 'payment_received':
        final amount = event.data?.amount ?? 0;
        final method = event.data?.method ?? '';
        return 'R\$ ${amount.toStringAsFixed(2)} via $method';
      default:
        return '';
    }
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    await _store.sendMessage(text);

    if (_store.error == null) {
      _messageController.clear();
      // Scroll para o final
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _openOrderDetails() {
    if (_order != null) {
      Navigator.of(context, rootNavigator: true).pushNamed(
        '/order',
        arguments: {'order': _order},
      );
    }
  }

  void _showActionSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            child: Text(context.l10n.viewOrderDetails),
            onPressed: () {
              Navigator.pop(context);
              _openOrderDetails();
            },
          ),
          CupertinoActionSheetAction(
            child: Text(context.l10n.addPhotos),
            onPressed: () {
              Navigator.pop(context);
              // TODO: Adicionar fotos
            },
          ),
          CupertinoActionSheetAction(
            child: Text(context.l10n.muteConversation),
            onPressed: () {
              Navigator.pop(context);
              // TODO: Silenciar
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text(context.l10n.cancel),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }
}
```

---

## Integracao com Funcionalidades Existentes

### Criar Eventos Automaticamente

Quando acoes acontecem no sistema, criar eventos na timeline:

```dart
// Exemplo: No OrderStore, ao mudar status

@action
Future<void> setStatus(String newStatus) async {
  final oldStatus = order?.status;
  order?.status = newStatus;

  // Salvar no Firestore
  await repository.updateItem(companyId!, order!);

  // Criar evento na timeline
  if (order?.id != null && oldStatus != newStatus) {
    await TimelineRepository().createStatusChangeEvent(
      companyId!,
      order!.id!,
      oldStatus ?? '',
      newStatus,
    );
  }
}

// Exemplo: Ao adicionar fotos

Future<void> addPhotos(List<String> photoUrls) async {
  // ... logica existente ...

  // Criar evento na timeline
  if (order?.id != null) {
    await TimelineRepository().createPhotosAddedEvent(
      companyId!,
      order!.id!,
      photoUrls,
    );
  }
}
```

---

## Internationalizacao (i18n)

### Novas Strings

```json
// lib/l10n/app_pt.arb (adicionar)
{
  "conversations": "Conversas",
  "searchConversations": "Buscar conversas...",
  "noConversations": "Nenhuma conversa",
  "noConversationsDescription": "Conversas aparecerao quando houver atividade nas OSs",
  "noMessages": "Nenhuma mensagem ainda",
  "typeMessage": "Digite uma mensagem...",
  "yesterday": "Ontem",
  "viewOrderDetails": "Ver detalhes da OS",
  "addPhotos": "Adicionar fotos",
  "muteConversation": "Silenciar conversa"
}

// lib/l10n/app_en.arb (adicionar)
{
  "conversations": "Conversations",
  "searchConversations": "Search conversations...",
  "noConversations": "No conversations",
  "noConversationsDescription": "Conversations will appear when there's activity on orders",
  "noMessages": "No messages yet",
  "typeMessage": "Type a message...",
  "yesterday": "Yesterday",
  "viewOrderDetails": "View order details",
  "addPhotos": "Add photos",
  "muteConversation": "Mute conversation"
}

// lib/l10n/app_es.arb (adicionar)
{
  "conversations": "Conversaciones",
  "searchConversations": "Buscar conversaciones...",
  "noConversations": "Sin conversaciones",
  "noConversationsDescription": "Las conversaciones apareceran cuando haya actividad en las ordenes",
  "noMessages": "Sin mensajes aun",
  "typeMessage": "Escribe un mensaje...",
  "yesterday": "Ayer",
  "viewOrderDetails": "Ver detalles de la OS",
  "addPhotos": "Agregar fotos",
  "muteConversation": "Silenciar conversacion"
}
```

---

## Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isAuthenticated() {
      return request.auth != null;
    }

    function isCompanyMember(companyId) {
      return isAuthenticated() &&
        exists(/databases/$(database)/documents/companies/$(companyId)/collaborators/$(request.auth.uid));
    }

    match /companies/{companyId} {
      allow read: if isCompanyMember(companyId);

      match /orders/{orderId} {
        allow read, write: if isCompanyMember(companyId);

        // Timeline events
        match /timeline/{eventId} {
          allow read: if isCompanyMember(companyId);

          // Criar evento
          allow create: if isCompanyMember(companyId) &&
            (request.resource.data.author == null ||
             request.resource.data.author.id == request.auth.uid);

          // Atualizar apenas readBy
          allow update: if isCompanyMember(companyId) &&
            request.resource.data.diff(resource.data).affectedKeys().hasOnly(['readBy']);

          // Nao permitir delete
          allow delete: if false;
        }
      }

      match /users/{userId} {
        allow read: if isCompanyMember(companyId);

        match /conversationSettings/{orderId} {
          allow read, write: if request.auth.uid == userId;
        }
      }
    }
  }
}
```

---

## Firestore Indexes

```json
{
  "indexes": [
    {
      "collectionGroup": "orders",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "lastActivity", "order": "ASCENDING" },
        { "fieldPath": "lastActivity.createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "timeline",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "isDeleted", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "ASCENDING" }
      ]
    }
  ]
}
```

---

## Plano de Implementacao

### Fase 1: MVP Conversas

| Task | Descricao |
|------|-----------|
| 1.1 | Model `TimelineEvent` e `LastActivity` |
| 1.2 | `TimelineRepository` com CRUD |
| 1.3 | `ConversationRepository` para lista |
| 1.4 | `TimelineStore` e `ConversationListStore` |
| 1.5 | Tela `ConversationListScreen` |
| 1.6 | Tela `ConversationTimelineScreen` |
| 1.7 | Atualizar navegacao (nova aba) |
| 1.8 | Strings i18n |

### Fase 2: Integracao

| Task | Descricao |
|------|-----------|
| 2.1 | Criar eventos ao mudar status |
| 2.2 | Criar eventos ao adicionar fotos |
| 2.3 | Criar eventos ao adicionar servicos/produtos |
| 2.4 | Criar eventos ao concluir formularios |
| 2.5 | Criar eventos de pagamento |

### Fase 3: Notificacoes

| Task | Descricao |
|------|-----------|
| 3.1 | Badge na TabBar |
| 3.2 | Cloud Function para push |
| 3.3 | Marcar como lido automaticamente |
| 3.4 | Configuracao silenciar/fixar |

### Fase 4: Mencoes e Melhorias

| Task | Descricao |
|------|-----------|
| 4.1 | Parser de @mentions |
| 4.2 | Autocomplete de usuarios |
| 4.3 | Rich text com mentions |
| 4.4 | Anexar fotos em mensagens |
| 4.5 | Alertas automaticos de prazo |

---

## Comparativo V1 vs V2

| Aspecto | V1 (Feed) | V2 (Conversas) |
|---------|-----------|----------------|
| Modelo mental | Rede social | WhatsApp |
| Curva aprendizado | Media | Baixa |
| Contexto | Fragmentado | Unificado |
| Acao do usuario | Scroll | Resolver |
| Substituir WhatsApp | Parcial | Total |
| Complexidade tecnica | Media | Media |
| Melhor para | Empresas grandes | Equipes pequenas/medias |

---

## Referencias

- [WhatsApp Design Guidelines](https://www.whatsapp.com/branding)
- [Apple HIG - Messaging](https://developer.apple.com/design/human-interface-guidelines/messages)
- [Firebase Realtime Updates](https://firebase.google.com/docs/firestore/query-data/listen)
