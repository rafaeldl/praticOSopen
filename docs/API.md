# PraticOS Integrations API

API de integrações do PraticOS para bot WhatsApp e integrações externas.

## Base URL

```
Production: https://southamerica-east1-praticos-app.cloudfunctions.net/api
```

## Autenticação

A API suporta três modos de autenticação:

### 1. API Key + Secret (Integrações Externas)

Para Zapier, n8n, parceiros externos.

```
Headers:
  X-API-Key: pk_live_xxxx
  X-API-Secret: sk_live_xxxx
```

### 2. Bot API Key + WhatsApp Number (Clawdbot)

Para o bot WhatsApp.

```
Headers:
  X-API-Key: bot_praticos_xxxxx
  X-WhatsApp-Number: +5511999999999
```

### 3. Bearer Token (App Flutter)

Para chamadas do app mobile/web.

```
Headers:
  Authorization: Bearer {firebase_id_token}
```

---

## API Core v1 (`/api/v1`)

### Autenticação

#### POST /api/v1/auth/token

Gera token de acesso via API Key + Secret.

**Request:**
```json
{
  "apiKey": "pk_live_xxxx",
  "apiSecret": "sk_live_xxxx"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "accessToken": "at_xxxxxxxx",
    "expiresIn": 3600,
    "companyId": "company_xyz"
  }
}
```

#### GET /api/v1/auth/verify

Valida token e retorna contexto.

**Headers:** `Authorization: Bearer {token}`

**Response:**
```json
{
  "success": true,
  "data": {
    "companyId": "company_xyz",
    "permissions": ["read:all", "write:all"],
    "expiresAt": "2025-01-28T12:00:00Z"
  }
}
```

---

### Orders (Ordens de Serviço)

#### GET /api/v1/orders

Lista ordens com filtros e paginação.

**Query Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| status | string | Filtrar por status: quote, approved, progress, done, canceled |
| customerId | string | Filtrar por cliente |
| deviceId | string | Filtrar por dispositivo |
| startDate | string | Data inicial (ISO 8601) |
| endDate | string | Data final (ISO 8601) |
| limit | number | Limite de resultados (default: 20, max: 100) |
| offset | number | Offset para paginação (default: 0) |

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "order_abc123",
      "number": 123,
      "customer": { "id": "...", "name": "João Silva", "phone": "..." },
      "device": { "id": "...", "name": "iPhone 12", "serial": "..." },
      "status": "approved",
      "total": 350.00,
      "dueDate": "2025-01-30T00:00:00Z",
      "createdAt": "2025-01-28T10:00:00Z"
    }
  ],
  "pagination": {
    "total": 150,
    "limit": 20,
    "offset": 0,
    "hasMore": true
  }
}
```

#### GET /api/v1/orders/:id

Retorna detalhes de uma ordem.

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "order_abc123",
    "number": 123,
    "customer": { "id": "...", "name": "João Silva", "phone": "...", "email": "..." },
    "device": { "id": "...", "name": "iPhone 12", "serial": "ABC123" },
    "services": [
      { "service": { "id": "...", "name": "Troca de Tela" }, "value": 250.00 }
    ],
    "products": [
      { "product": { "id": "...", "name": "Tela iPhone 12" }, "value": 100.00, "quantity": 1 }
    ],
    "status": "approved",
    "total": 350.00,
    "discount": 0,
    "paidAmount": 100.00,
    "remainingBalance": 250.00,
    "dueDate": "2025-01-30T00:00:00Z",
    "createdAt": "2025-01-28T10:00:00Z",
    "updatedAt": "2025-01-28T11:00:00Z"
  }
}
```

#### POST /api/v1/orders

Cria uma nova ordem.

**Request:**
```json
{
  "customerId": "customer_xyz",
  "deviceId": "device_abc",
  "services": [
    { "serviceId": "service_123", "value": 250.00, "description": "Troca de tela original" }
  ],
  "products": [
    { "productId": "product_456", "quantity": 1, "value": 100.00 }
  ],
  "dueDate": "2025-01-30T00:00:00Z",
  "status": "quote"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "order_new123",
    "number": 124,
    "status": "quote"
  }
}
```

#### PATCH /api/v1/orders/:id

Atualiza uma ordem existente.

**Request:**
```json
{
  "status": "approved",
  "dueDate": "2025-01-31T00:00:00Z",
  "assignedTo": "user_abc"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "order_abc123",
    "updated": true
  }
}
```

#### POST /api/v1/orders/:id/services

Adiciona serviço a uma ordem.

**Request:**
```json
{
  "serviceId": "service_123",
  "value": 150.00,
  "description": "Serviço adicional"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "success": true,
    "newTotal": 500.00
  }
}
```

#### POST /api/v1/orders/:id/products

Adiciona produto a uma ordem.

**Request:**
```json
{
  "productId": "product_456",
  "quantity": 2,
  "value": 50.00
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "success": true,
    "newTotal": 600.00
  }
}
```

#### POST /api/v1/orders/:id/payments

Registra pagamento ou desconto.

**Request:**
```json
{
  "amount": 200.00,
  "type": "payment",
  "description": "Pagamento parcial via PIX"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "transactionId": "tx_abc123",
    "paidAmount": 300.00,
    "remainingBalance": 50.00,
    "isFullyPaid": false
  }
}
```

---

### Customers (Clientes)

#### GET /api/v1/customers

Lista clientes com filtros.

**Query Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| phone | string | Filtrar por telefone |
| email | string | Filtrar por email |
| name | string | Buscar por nome (parcial) |
| limit | number | Limite de resultados |
| offset | number | Offset para paginação |

#### GET /api/v1/customers/:id

Retorna detalhes de um cliente.

#### POST /api/v1/customers

Cria um novo cliente.

**Request:**
```json
{
  "name": "João Silva",
  "phone": "+5511999999999",
  "email": "joao@email.com",
  "address": "Rua Exemplo, 123"
}
```

#### PATCH /api/v1/customers/:id

Atualiza um cliente existente.

---

### Devices (Dispositivos)

#### GET /api/v1/devices

Lista dispositivos com filtros.

**Query Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| serial | string | Filtrar por serial |
| name | string | Buscar por nome |
| category | string | Filtrar por categoria |
| manufacturer | string | Filtrar por fabricante |

#### GET /api/v1/devices/:id

Retorna detalhes de um dispositivo.

#### POST /api/v1/devices

Cria um novo dispositivo.

**Request:**
```json
{
  "name": "iPhone 12",
  "serial": "ABC123456",
  "manufacturer": "Apple",
  "category": "smartphone"
}
```

#### PATCH /api/v1/devices/:id

Atualiza um dispositivo existente.

---

### Services (Catálogo de Serviços)

#### GET /api/v1/services

Lista serviços do catálogo.

#### GET /api/v1/services/:id

Retorna detalhes de um serviço.

#### POST /api/v1/services

Cria um novo serviço.

**Request:**
```json
{
  "name": "Troca de Tela",
  "value": 250.00
}
```

---

### Products (Catálogo de Produtos)

#### GET /api/v1/products

Lista produtos do catálogo.

#### GET /api/v1/products/:id

Retorna detalhes de um produto.

#### POST /api/v1/products

Cria um novo produto.

**Request:**
```json
{
  "name": "Tela iPhone 12",
  "value": 150.00
}
```

---

### Company (Empresa)

#### GET /api/v1/company

Retorna dados da empresa do usuário autenticado.

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "company_xyz",
    "name": "Oficina do João",
    "segment": "electronics",
    "country": "BR",
    "phone": "+5511999999999",
    "email": "contato@oficina.com",
    "address": "Rua Exemplo, 123",
    "logo": "https://..."
  }
}
```

#### PATCH /api/v1/company

Atualiza dados da empresa (apenas admin/owner).

#### GET /api/v1/company/members

Lista membros da empresa.

**Response:**
```json
{
  "success": true,
  "data": {
    "members": [
      {
        "userId": "user_abc",
        "name": "João Silva",
        "email": "joao@email.com",
        "role": "owner",
        "linkedChannels": ["whatsapp"]
      }
    ]
  }
}
```

#### PATCH /api/v1/company/members/:userId

Atualiza role de um membro.

**Request:**
```json
{
  "role": "technician"
}
```

#### DELETE /api/v1/company/members/:userId

Remove membro da empresa.

---

### Analytics (Dashboard)

#### GET /api/v1/analytics/summary

Retorna resumo analítico para um período.

**Query Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| period | string | today, week, month, year, custom |
| startDate | string | Data inicial (se period=custom) |
| endDate | string | Data final (se period=custom) |

**Response:**
```json
{
  "success": true,
  "data": {
    "period": { "start": "2025-01-28", "end": "2025-01-28" },
    "orders": {
      "total": 15,
      "byStatus": {
        "quote": 3,
        "approved": 5,
        "progress": 4,
        "done": 3,
        "canceled": 0
      }
    },
    "revenue": {
      "total": 5000.00,
      "paid": 3500.00,
      "unpaid": 1500.00,
      "discount": 0
    },
    "topCustomers": [
      { "id": "...", "name": "João", "total": 1200.00, "orderCount": 3 }
    ],
    "topServices": [
      { "id": "...", "name": "Troca de Tela", "total": 2500.00, "count": 10 }
    ]
  }
}
```

#### GET /api/v1/analytics/pending

Retorna pendências (aprovações, entregas, cobranças).

**Response:**
```json
{
  "success": true,
  "data": {
    "toApprove": [
      { "id": "...", "number": 123, "customer": {...}, "total": 350.00 }
    ],
    "dueToday": [
      { "id": "...", "number": 124, "customer": {...}, "device": {...} }
    ],
    "unpaid": [
      { "id": "...", "number": 120, "customer": {...}, "remainingBalance": 150.00 }
    ],
    "overdue": [
      { "id": "...", "number": 115, "customer": {...}, "daysOverdue": 3 }
    ]
  }
}
```

---

## API Bot (`/api/bot`)

### Vinculação de Conta (Flow A - Link Mágico)

#### POST /api/bot/link

Vincula número WhatsApp ao usuário via token do app.

**Headers:**
```
X-API-Key: bot_praticos_xxxxx
```

**Request:**
```json
{
  "token": "LT_xxxxxxxx",
  "whatsappNumber": "+5511999999999"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "success": true,
    "userId": "user_abc",
    "userName": "João Silva",
    "companyId": "company_xyz",
    "companyName": "Oficina do João",
    "role": "technician"
  }
}
```

#### GET /api/bot/link/context

Retorna contexto do usuário vinculado.

**Headers:**
```
X-API-Key: bot_praticos_xxxxx
X-WhatsApp-Number: +5511999999999
```

**Response:**
```json
{
  "success": true,
  "data": {
    "linked": true,
    "userId": "user_abc",
    "userName": "João Silva",
    "companyId": "company_xyz",
    "companyName": "Oficina do João",
    "role": "technician",
    "permissions": ["read:assigned", "write:orders:status"]
  }
}
```

#### DELETE /api/bot/link

Desvincula número WhatsApp.

**Headers:**
```
X-API-Key: bot_praticos_xxxxx
X-WhatsApp-Number: +5511999999999
```

---

### Convite de Colaborador (Flow B)

#### POST /api/bot/invite/create

Cria convite para colaborador (admin/owner/supervisor).

**Request:**
```json
{
  "collaboratorName": "Maria Santos",
  "role": "technician"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "inviteCode": "INVITE_ABC123",
    "inviteLink": "https://wa.me/5511999999999?text=INVITE_ABC123",
    "expiresAt": "2025-01-29T12:00:00Z"
  }
}
```

#### POST /api/bot/invite/accept

Aceita convite e vincula colaborador.

**Request:**
```json
{
  "inviteCode": "INVITE_ABC123",
  "whatsappNumber": "+5511888888888",
  "name": "Maria Santos"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "success": true,
    "userId": "user_new123",
    "userName": "Maria Santos",
    "companyId": "company_xyz",
    "companyName": "Oficina do João",
    "role": "technician"
  }
}
```

#### GET /api/bot/invite/list

Lista convites criados pelo usuário.

#### DELETE /api/bot/invite/:code

Revoga um convite.

---

### Busca Inteligente

#### GET /api/bot/customers/search

Busca clientes por nome ou telefone.

**Query:** `?q=João` ou `?q=11999`

**Response:**
```json
{
  "success": true,
  "data": {
    "exact": { "id": "...", "name": "João Silva", "phone": "+5511999999999" },
    "suggestions": [
      { "id": "...", "name": "João Santos", "phone": "+5511888888888" }
    ]
  }
}
```

#### GET /api/bot/devices/search

Busca dispositivos por nome ou serial.

**Query:** `?q=iPhone` ou `?q=ABC123`

#### GET /api/bot/customers/:id/vcard

Retorna vCard formatado para envio nativo.

**Response:**
```json
{
  "success": true,
  "data": {
    "vcard": "BEGIN:VCARD\nVERSION:3.0\nFN:João Silva\n...",
    "displayName": "João Silva"
  }
}
```

---

### Criação Rápida

#### POST /api/bot/orders/quick

Cria OS rapidamente (cria cliente/dispositivo se necessário).

**Request:**
```json
{
  "customerName": "João Silva",
  "customerPhone": "+5511999999999",
  "deviceName": "iPhone 12",
  "deviceSerial": "ABC123",
  "problem": "Tela quebrada",
  "estimatedValue": 350.00,
  "dueDate": "2025-01-30T00:00:00Z"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "orderId": "order_new123",
    "orderNumber": 125,
    "status": "quote",
    "customerCreated": false,
    "deviceCreated": true
  }
}
```

---

### Resumos Formatados

#### GET /api/bot/summary/today

Retorna resumo do dia formatado para WhatsApp.

**Response:**
```json
{
  "success": true,
  "data": {
    "message": "*Resumo de hoje:*\n\n• 15 OS no total\n• 3 aguardando aprovação\n• 2 para entregar hoje\n• R$ 1.500 a receber",
    "data": {
      "totalOrders": 15,
      "toApprove": 3,
      "dueToday": 2,
      "unpaidAmount": 1500.00
    }
  }
}
```

#### GET /api/bot/summary/pending

Retorna pendências formatadas para WhatsApp.

---

## Códigos de Erro

| Code | HTTP Status | Description |
|------|-------------|-------------|
| UNAUTHORIZED | 401 | Autenticação requerida ou inválida |
| INVALID_API_KEY | 401 | API Key inválida |
| INVALID_TOKEN | 401 | Token inválido |
| TOKEN_EXPIRED | 401 | Token expirado |
| NOT_LINKED | 403 | WhatsApp não vinculado |
| ALREADY_LINKED | 409 | WhatsApp já vinculado |
| FORBIDDEN | 403 | Acesso negado |
| INSUFFICIENT_PERMISSIONS | 403 | Permissão insuficiente |
| VALIDATION_ERROR | 400 | Erro de validação |
| NOT_FOUND | 404 | Recurso não encontrado |
| RATE_LIMIT_EXCEEDED | 429 | Limite de requisições excedido |
| INTERNAL_ERROR | 500 | Erro interno do servidor |

## Rate Limiting

- **API Core:** 100 requisições/minuto por API Key
- **API Bot:** 60 requisições/minuto por número WhatsApp

## Suporte

- Issues: https://github.com/rafaeldl/praticos/issues
- Documentação: https://praticos.web.app/docs
