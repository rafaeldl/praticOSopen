# Guia de Implementação: Social Features V3 (Unified)

Este documento descreve a especificação técnica final para transformar a Ordem de Serviço (OS) em uma Timeline de eventos (Chat), integrando comunicação da equipe e transparência para o cliente final.

## 1. Arquitetura de Dados (Firestore)

### 1.1 Documento da OS (`/companies/{id}/orders/{id}`)
Adicionar campos de agregação para permitir listas performáticas e controle de acesso.

```typescript
interface Order {
  // ... campos existentes ...
  
  // Agregação para a lista da Home
  lastActivity: {
    type: string;
    icon: string;           // Emoji ou ID do ícone (💬, 📷, ✅, ⚠️, etc.)
    preview: string;        // Texto truncado (Ex: "João: Foto adicionada")
    authorId: string | null;
    authorName: string | null;
    createdAt: Timestamp;
    visibility: 'internal' | 'customer';
  } | null;

  // Contador de não lidos por colaborador
  unreadCounts: {
    [userId: string]: number; // Ex: { 'user_123': 2 }
  };

  // Link Mágico para o Cliente
  customerToken: string; // Token único gerado na criação da OS (Ex: "xK9mP2")
}
```

### 1.2 Sub-coleção Timeline (`/companies/{id}/orders/{id}/timeline/{eventId}`)
Cada evento (mudança de status, foto, comentário) é um documento nesta coleção.

```typescript
interface TimelineEvent {
  id: string;
  type: TimelineEventType;
  
  // Controle de Visibilidade
  visibility: 'internal' | 'customer'; // Padrão: 'internal'
  
  // Detalhes do Autor
  author: {
    id: string;
    name: string;
    type: 'collaborator' | 'customer' | 'system';
    photoUrl?: string;
  } | null;

  // Dados flexíveis por tipo
  data: TimelineEventData;

  // Status de Entrega (Estilo WhatsApp)
  readBy: string[];      // Lista de userIds da equipe que abriram a timeline
  createdAt: Timestamp;
  isDeleted: boolean;
}

type TimelineEventType = 
  | 'comment' | 'status_change' | 'photos_added' 
  | 'service_added' | 'product_added' | 'form_completed' 
  | 'payment_received' | 'due_date_alert' | 'assignment_change';
```

---

## 2. Regras de Visibilidade e Notificação

### 2.1 Matriz de Exposição (Cliente Final)
O cliente acessa via Web (Link Mágico) e vê apenas o que for `visibility: 'customer'`.

| Evento | Visibilidade Padrão | Notifica Cliente? |
|--------|---------------------|-------------------|
| Comentário Equipe | `internal` | Não |
| Comentário Cliente | `customer` | N/A (Autor) |
| Foto | Técnico escolhe (🔒/🌐) | Se 🌐 |
| Mudança de Status | `customer` | Sim (WhatsApp) |
| Serviço/Produto | `customer` | Sim |
| Checklist/Interno | `internal` | Não |

---

## 3. Guia de Implementação (Passo a Passo)

### Fase 1: Models e Repositories (Dart)
1.  **Model `TimelineEvent`:** Implementar com suporte a `visibility` e `author.type`.
2.  **Model `Order` (Update):** Adicionar `lastActivity`, `unreadCounts` e `customerToken`.
3.  **`TimelineRepository`:**
    *   `getTimeline(orderId, isInternal)`: Query filtrada por visibilidade.
    *   `createEvent(...)`: Criar evento e **simultaneamente** atualizar `lastActivity` e incrementar `unreadCounts` no documento pai (OS) via `WriteBatch`.
    *   `markAsRead(orderId, userId)`: Zerar `unreadCounts[userId]` na OS e adicionar `userId` à lista `readBy` dos eventos recentes.

### Fase 2: Interface do Chat (App Técnico)
1.  **`TimelineScreen`:** Lista de balões de chat e "Cards de Eventos" (Log de status, fotos, etc.).
2.  **Input Bar Híbrida:**
    *   Toggle visual (🔒/🌐) para o técnico escolher a visibilidade.
    *   Feedback visual claro: Mensagens públicas com borda/ícone de globo (🌐).
3.  **Checkmarks:** Renderizar `✓`, `✓✓` e `✓✓ azul` baseando-se no campo `readBy`.

### Fase 3: Integração Home (Inbox Style)
1.  **Card de OS:** Substituir o preview do serviço pelo `lastActivity.preview`.
2.  **Indicadores:** Mostrar Dot Azul se `unreadCounts[myId] > 0`.
3.  **Ordenação:** Mover OSs com atividade recente (`lastActivity.createdAt`) para o topo.

### Fase 4: Cloud Functions (Backend)
1.  **`onTimelineEventCreated`:**
    *   Se `visibility == 'customer'`, disparar gatilho para envio de WhatsApp/SMS ao cliente.
    *   Se `author.type == 'customer'`, notificar o responsável (`assignedTo`) e criador via Push.
2.  **`scheduledDueDateAlerts`:** Rotina diária que cria eventos `due_date_alert` na timeline.

---

## 4. Otimizações Técnicas
1.  **Índice Composto:** Criar índice Firestore: `orderId` (ASC) + `visibility` (ASC) + `createdAt` (DESC).
2.  **Segurança:** Regras do Firestore devem validar que `author.type == 'customer'` só pode ser escrito via Cloud Function ou por usuários sem login apenas se o `customerToken` for válido.
3.  **Performance de Lista:** O campo `lastActivity` evita que a Home precise ler a coleção de timeline, economizando milhares de leituras.