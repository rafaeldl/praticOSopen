# Share Link (Magic Link)

Sistema de compartilhamento de ordens de serviço via links mágicos que permite clientes visualizarem, aprovarem e comentarem em suas OS sem necessidade de cadastro ou login.

## Visão Geral

O Share Link permite que técnicos e empresas compartilhem ordens de serviço com clientes através de um link único e temporário. O cliente pode:

- **Visualizar** detalhes da OS, serviços e valores
- **Aprovar ou Rejeitar** orçamentos
- **Comentar** para comunicação com a equipe

### URLs do Sistema

| Ambiente | URL Base |
|----------|----------|
| Web App | `https://praticos.web.app/q/{token}` |
| API (Prod) | `https://southamerica-east1-praticos.cloudfunctions.net/api` |
| API (Dev) | `http://localhost:5000/praticos/southamerica-east1/api` |

## Arquitetura

### Diagrama de Componentes

```
┌─────────────────────────────────────────────────────────────────┐
│                         FRONTEND (Flutter)                       │
├─────────────────────────────────────────────────────────────────┤
│  ShareLinkSheet          ShareLinkService         ShareToken    │
│  (UI Component)    ←→    (HTTP Client)      ←→    (Model)       │
└─────────────────────────────────────────────────────────────────┘
                                  ↓ HTTP
┌─────────────────────────────────────────────────────────────────┐
│                    BACKEND (Cloud Functions)                     │
├─────────────────────────────────────────────────────────────────┤
│  share.routes.ts         share-token.service.ts                  │
│  orders.routes.ts  ←→    (Business Logic)                        │
│  (public)                                                        │
└─────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────┐
│                         FIRESTORE                                │
├─────────────────────────────────────────────────────────────────┤
│  links/share/tokens/{tokenId}                                    │
│  companies/{companyId}/orders/{orderId}                          │
└─────────────────────────────────────────────────────────────────┘
```

### Arquivos Principais

| Componente | Arquivo | Descrição |
|------------|---------|-----------|
| **Model** | `lib/models/share_token.dart` | Classes ShareToken, ShareLinkResult, ShareTokenPermission |
| **Model** | `lib/models/order.dart` | Classe OrderShareLink (embedded) |
| **Service** | `lib/services/share_link_service.dart` | Cliente HTTP para API |
| **UI** | `lib/screens/widgets/share_link_sheet.dart` | Bottom sheet de compartilhamento |
| **Backend Service** | `firebase/functions/src/services/share-token.service.ts` | Lógica de negócio |
| **Routes Auth** | `firebase/functions/src/routes/v1/share.routes.ts` | Endpoints autenticados |
| **Routes Public** | `firebase/functions/src/routes/public/orders.routes.ts` | Endpoints públicos |
| **Routes Bot** | `firebase/functions/src/routes/bot/share.routes.ts` | Endpoints do bot WhatsApp |
| **Middleware** | `firebase/functions/src/middleware/share-token.middleware.ts` | Validação de tokens |
| **Rules** | `firebase/firestore.rules` | Regras de segurança |

## Estrutura Firestore

### Collection: `links/share/tokens/{tokenId}`

```json
{
  "token": "ST_a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "orderId": "order_123",
  "companyId": "company_456",
  "permissions": ["view", "approve", "comment"],
  "customer": {
    "id": "customer_789",
    "name": "João Silva",
    "phone": "+5511999999999"
  },
  "createdAt": "2025-01-15T10:00:00Z",
  "expiresAt": "2025-01-22T10:00:00Z",
  "createdBy": {
    "id": "user_abc",
    "name": "Técnico Carlos"
  },
  "viewCount": 5,
  "lastViewedAt": "2025-01-16T14:30:00Z",
  "approvedAt": "2025-01-16T15:00:00Z",
  "rejectedAt": null,
  "rejectionReason": null
}
```

### Embedded em Order: `shareLink`

```json
{
  "shareLink": {
    "token": "ST_a1b2c3d4-...",
    "expiresAt": "2025-01-22T10:00:00Z",
    "permissions": ["view", "approve", "comment"]
  }
}
```

## Permissões

| Permissão | Descrição | Ações Permitidas |
|-----------|-----------|------------------|
| `view` | Visualização básica | Ver detalhes da OS, serviços, valores |
| `approve` | Aprovação de orçamento | Aprovar ou rejeitar a OS |
| `comment` | Comentários | Adicionar comentários na OS |

**Padrão:** Todos os links são criados com as 3 permissões (`view`, `approve`, `comment`).

## Formato do Token

```
ST_{uuid}
```

- **Prefixo:** `ST_` (Share Token)
- **Corpo:** UUID v4 para unicidade e segurança
- **Exemplo:** `ST_a1b2c3d4-e5f6-7890-abcd-ef1234567890`

## Fluxo de Dados

### 1. Criação do Link (Usuário Autenticado)

```
User → ShareLinkSheet → ShareLinkService.generateShareLink()
                              ↓
                    POST /v1/app/orders/{orderId}/share
                              ↓
                    shareTokenService.generateShareToken()
                              ↓
           ┌─────────────────────────────────────┐
           │  1. Valida ordem e permissões       │
           │  2. Gera token ST_{uuid}            │
           │  3. Cria doc em links/share/tokens  │
           │  4. Atualiza order.shareLink        │
           │  5. Retorna ShareLinkResult         │
           └─────────────────────────────────────┘
                              ↓
              { token, url, permissions, expiresAt }
```

### 2. Acesso via Link (Cliente sem Auth)

```
Browser → https://praticos.web.app/q/{token}
                    ↓
          GET /public/orders/{token}
                    ↓
       ┌──────────────────────────────┐
       │  shareTokenAuth middleware:  │
       │  1. Busca token no Firestore │
       │  2. Valida expiração         │
       │  3. Incrementa viewCount     │
       │  4. Anexa token ao request   │
       └──────────────────────────────┘
                    ↓
             Retorna Order + Comments
```

### 3. Aprovação/Rejeição

```
Cliente → POST /public/orders/{token}/approve (ou /reject)
                    ↓
        requireSharePermission('approve')
                    ↓
       ┌─────────────────────────────────┐
       │  1. Atualiza order.status       │
       │  2. Marca token como aprovado   │
       │  3. Adiciona comment na OS      │
       │  4. Envia push notification     │
       └─────────────────────────────────┘
```

### 4. Comentário

```
Cliente → POST /public/orders/{token}/comments
                    ↓
        requireSharePermission('comment')
                    ↓
       ┌─────────────────────────────────┐
       │  1. Valida texto (1-2000 chars) │
       │  2. Cria comment com:           │
       │     - source: "magicLink"       │
       │     - shareToken: token         │
       │     - author: customer info     │
       │  3. Envia push notification     │
       └─────────────────────────────────┘
```

## API Endpoints

### Endpoints Autenticados (Requer Firebase Auth)

#### `POST /v1/app/orders/{orderId}/share`

Gera um novo link de compartilhamento.

**Request:**
```json
{
  "permissions": ["view", "approve", "comment"],
  "expiresInDays": 7
}
```

**Response:**
```json
{
  "token": "ST_...",
  "url": "https://praticos.web.app/q/ST_...",
  "permissions": ["view", "approve", "comment"],
  "expiresAt": "2025-01-22T10:00:00Z",
  "customer": {
    "id": "...",
    "name": "João Silva"
  }
}
```

#### `GET /v1/app/orders/{orderId}/share`

Lista todos os tokens ativos de uma ordem.

**Response:**
```json
{
  "tokens": [
    {
      "token": "ST_...",
      "permissions": [...],
      "expiresAt": "...",
      "viewCount": 5,
      "lastViewedAt": "...",
      "approvedAt": null,
      "rejectedAt": null
    }
  ]
}
```

#### `DELETE /v1/app/orders/{orderId}/share/{token}`

Revoga um token específico.

**Response:**
```json
{
  "success": true,
  "message": "Token revoked"
}
```

### Endpoints Públicos (Sem Auth)

#### `GET /public/orders/{token}`

Visualiza ordem via magic link.

**Response:**
```json
{
  "order": {
    "id": "...",
    "number": 123,
    "status": "pending",
    "services": [...],
    "total": 150.00
  },
  "company": {
    "name": "Oficina XYZ",
    "phone": "..."
  },
  "comments": [...],
  "permissions": ["view", "approve", "comment"]
}
```

#### `POST /public/orders/{token}/approve`

Aprova o orçamento.

**Response:**
```json
{
  "success": true,
  "message": "Order approved"
}
```

#### `POST /public/orders/{token}/reject`

Rejeita o orçamento.

**Request:**
```json
{
  "reason": "Valor muito alto"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Order rejected"
}
```

#### `POST /public/orders/{token}/comments`

Adiciona comentário.

**Request:**
```json
{
  "text": "Quando fica pronto?"
}
```

**Response:**
```json
{
  "success": true,
  "commentId": "comment_123"
}
```

#### `GET /public/orders/{token}/comments`

Lista comentários visíveis ao cliente.

### Endpoints Bot (WhatsApp)

#### `POST /bot/orders/{number}/share`

Gera token pelo número da OS.

#### `GET /bot/orders/{number}/share`

Lista tokens ativos com mensagem formatada.

#### `DELETE /bot/orders/{number}/share/{token}`

Revoga token com resposta formatada.

## Regras de Segurança

### Firestore Rules

```javascript
match /links/{linkType}/tokens/{tokenId} {
  // Leitura: membros autenticados da empresa
  allow read: if request.auth != null
    && resource.data.companyId != null
    && belongsToCompany(resource.data.companyId);

  // Escrita: apenas via Cloud Functions (Admin SDK)
  allow write: if false;
}
```

### Validações

1. **Expiração:** Token verifica `expiresAt > now` em cada acesso
2. **Permissões:** Middleware valida permissão antes de cada ação
3. **Multi-tenancy:** `companyId` isola tokens entre empresas
4. **Revogação:** Token pode ser revogado a qualquer momento

## UI: ShareLinkSheet

O `ShareLinkSheet` é um modal bottom sheet que centraliza todas as ações de compartilhamento.

### Comportamento

1. **Auto-detecção:** Verifica se já existe token válido para a OS
2. **Reuso inteligente:** Reutiliza token existente se ainda válido
3. **Geração automática:** Cria novo token se necessário

### Ações Disponíveis

| Ação | Descrição |
|------|-----------|
| **WhatsApp** | Abre WhatsApp com mensagem formatada (se cliente tem telefone) |
| **Compartilhar** | Abre share sheet nativo do sistema |
| **Copiar Link** | Copia URL para clipboard |
| **Revogar** | Remove link com confirmação |

### Opções Avançadas

- **Permissões:** Toggle para cada permissão
- **Validade:** 7, 14 ou 30 dias
- **Visualizações:** Mostra contador de acessos

## Localização

Mensagens de compartilhamento disponíveis em 3 idiomas:

### Português (pt-BR)
```
Olá {name}! Segue o link para acompanhar sua OS #{number} da {company}:
{url}

Através deste link você pode visualizar os detalhes e aprovar o orçamento.
```

### Inglês (en-US)
```
Hi {name}! Here is the link to track your service order #{number} from {company}:
{url}

Through this link you can view details and approve the quote.
```

### Espanhol (es-ES)
```
Hola {name}! Aquí está el enlace para seguir tu orden de servicio #{number} de {company}:
{url}

A través de este enlace puedes ver los detalles y aprobar el presupuesto.
```

## Tracking e Analytics

O sistema registra automaticamente:

| Métrica | Campo | Descrição |
|---------|-------|-----------|
| Visualizações | `viewCount` | Incrementado a cada acesso |
| Último acesso | `lastViewedAt` | Timestamp do último acesso |
| Aprovação | `approvedAt` | Timestamp da aprovação |
| Rejeição | `rejectedAt` | Timestamp da rejeição |
| Motivo rejeição | `rejectionReason` | Texto opcional |

## Integração com Comentários

Comentários criados via magic link são marcados com:

```json
{
  "source": "magicLink",
  "shareToken": "ST_...",
  "author": {
    "type": "customer",
    "name": "João Silva",
    "id": "customer_123"
  }
}
```

Isso permite:
- Filtrar comentários por origem
- Identificar comunicação cliente-empresa
- Manter histórico de interações

## Notificações

O sistema envia push notifications para a equipe quando:

- Cliente **aprova** o orçamento
- Cliente **rejeita** o orçamento
- Cliente **adiciona comentário**
- Cliente **avalia** a OS concluída

## Avaliação do Cliente

Quando a OS está com status `done` (concluída), o cliente pode avaliar o serviço através do link compartilhado.

### Endpoint

```
POST /public/orders/{token}/rating
```

**Request:**
```json
{
  "score": 5,
  "comment": "Excelente serviço!"
}
```

**Validações:**
- Score deve ser inteiro entre 1 e 5
- Comentário é opcional, máximo 500 caracteres
- OS deve estar com status `done`
- OS não pode já ter sido avaliada

### Onde a Avaliação Aparece

1. **Web (Magic Link):** Seção de rating no final da página
2. **App (Order Detail):** Seção de avaliação na tela da OS
3. **App (Ratings Screen):** Lista completa em Configurações > Avaliações

Ver `docs/CUSTOMER_RATING.md` para documentação completa do sistema de avaliação.

## Exemplos de Uso

### Gerar Link (Frontend)

```dart
final service = ShareLinkService();

final result = await service.generateShareLink(
  orderId: order.id!,
  permissions: ['view', 'approve', 'comment'],
  expiresInDays: 7,
);

print('Link: ${result.url}');
// https://praticos.web.app/q/ST_a1b2c3d4-...
```

### Compartilhar via WhatsApp

```dart
await service.shareViaWhatsApp(
  phone: customer.phone!,
  shareLink: result,
  orderNumber: order.number!,
  companyName: company.name!,
  customerName: customer.name!,
);
```

### Copiar para Clipboard

```dart
await service.copyToClipboard(result.url);
```

### Verificar Token Válido

```dart
if (order.shareLink != null && !order.shareLink!.isExpired) {
  // Reutilizar token existente
  final url = order.shareLink!.url;
}
```

## Considerações de Segurança

1. **Tokens são únicos e não previsíveis** (UUID v4)
2. **Expiração automática** previne acesso indefinido
3. **Revogação imediata** remove acesso instantaneamente
4. **Validação em cada request** garante consistência
5. **Multi-tenancy** isola dados entre empresas
6. **Escrita apenas via Admin SDK** previne manipulação direta

## Troubleshooting

### Token Expirado

```
Error: Token expired
```

**Solução:** Gerar novo link com `generateShareLink()`.

### Permissão Negada

```
Error: Permission denied for action 'approve'
```

**Solução:** Verificar se token foi criado com permissão de aprovação.

### Token Não Encontrado

```
Error: Token not found
```

**Possíveis causas:**
- Token foi revogado
- Token nunca existiu (URL incorreta)
- Token digitado incorretamente
