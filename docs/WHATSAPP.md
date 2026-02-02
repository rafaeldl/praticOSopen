# WhatsApp Integration

Technical documentation for WhatsApp integration in PraticOS.

## Overview

The WhatsApp integration enables users to:

1. **Link their account** via QR Code to receive notifications
2. **Share service orders** directly via WhatsApp with customers
3. **Receive notifications** about ratings and order updates (planned)

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         FLUTTER APP                                  │
├─────────────────────────────────────────────────────────────────────┤
│  LinkWhatsAppSheet       WhatsAppLinkService      WhatsAppLinkStore │
│  (UI Component)     ←→   (HTTP Client)       ←→   (MobX State)      │
│                                                                      │
│  ShareLinkSheet                                                      │
│  (WhatsApp share button)                                            │
└─────────────────────────────────────────────────────────────────────┘
                                  ↓ HTTP
┌─────────────────────────────────────────────────────────────────────┐
│                    FIREBASE CLOUD FUNCTIONS                          │
├─────────────────────────────────────────────────────────────────────┤
│  link.routes.ts              channel-link.service.ts                 │
│  (User endpoints)       ←→   (Business Logic)                        │
│                                                                      │
│  share.routes.ts             share-token.service.ts                  │
│  (Bot endpoints)        ←→   (Share Link Logic)                      │
└─────────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────────┐
│                         FIRESTORE                                    │
├─────────────────────────────────────────────────────────────────────┤
│  links/tokens/pending/{token}     (Temporary link tokens)           │
│  links/whatsapp/numbers/{phone}   (Linked WhatsApp accounts)        │
│  notifications/outbound/queue/    (Notification queue)              │
└─────────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────────┐
│                     CLAWDBOT (External)                              │
├─────────────────────────────────────────────────────────────────────┤
│  - Receives link tokens via wa.me deep link                         │
│  - Validates and completes account linking                          │
│  - Sends outbound notifications                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Main Files

| Component | File | Description |
|-----------|------|-------------|
| **Service** | `lib/services/whatsapp_link_service.dart` | HTTP client for WhatsApp linking API |
| **Store** | `lib/mobx/whatsapp_link_store.dart` | MobX state management for linking flow |
| **UI** | `lib/screens/menu_navigation/widgets/link_whatsapp_sheet.dart` | QR Code bottom sheet UI |
| **Backend Service** | `firebase/functions/src/services/channel-link.service.ts` | Token generation and linking logic |
| **Backend Routes** | `firebase/functions/src/routes/user/link.routes.ts` | User-facing API endpoints |

---

## Account Linking (QR Code)

Users can link their WhatsApp account to PraticOS to receive notifications and interact with the bot.

### Linking Flow

```
1. User opens "Link WhatsApp" in app
         ↓
2. App calls POST /user/link/whatsapp/token
         ↓
3. Backend generates token (LT_{uuid}) + wa.me link
         ↓
4. App displays QR Code with wa.me link
         ↓
5. User scans QR Code → Opens WhatsApp → Sends token to bot
         ↓
6. Bot receives token → Validates → Links phone to user
         ↓
7. User is now linked and can receive notifications
```

### Firestore Structure

#### Pending Tokens: `links/tokens/pending/{token}`

Temporary tokens for linking (15 min expiration):

```json
{
  "token": "LT_a1b2c3d4e5f67890abcdef1234567890",
  "userId": "user_abc123",
  "companyId": "company_xyz",
  "role": "admin",
  "userName": "João Silva",
  "companyName": "Oficina do João",
  "expiresAt": "2025-01-09T10:15:00Z",
  "used": false
}
```

#### Linked Numbers: `links/whatsapp/numbers/{phone}`

Permanent record of linked accounts:

```json
{
  "channel": "whatsapp",
  "identifier": "+5511999999999",
  "userId": "user_abc123",
  "companyId": "company_xyz",
  "role": "admin",
  "userName": "João Silva",
  "companyName": "Oficina do João",
  "linkedAt": "2025-01-09T10:05:00Z"
}
```

### API Endpoints

#### `POST /user/link/whatsapp/token`

Generates a new linking token with QR Code data.

**Auth Required:** Firebase Auth (Bearer token)

**Response:**
```json
{
  "success": true,
  "data": {
    "token": "LT_a1b2c3d4e5f67890abcdef1234567890",
    "link": "https://wa.me/5548988794742?text=Vincular%3A%20LT_a1b2c3d4e5f67890abcdef1234567890",
    "botNumber": "+5548988794742",
    "expiresIn": 900
  }
}
```

#### `GET /user/link/whatsapp/status`

Checks if the current user has WhatsApp linked.

**Auth Required:** Firebase Auth (Bearer token)

**Response:**
```json
{
  "success": true,
  "data": {
    "linked": true,
    "number": "+5511999999999",
    "linkedAt": "2025-01-09T10:05:00Z"
  }
}
```

#### `DELETE /user/link/whatsapp`

Unlinks WhatsApp from the current user.

**Auth Required:** Firebase Auth (Bearer token)

**Response:**
```json
{
  "success": true,
  "data": {
    "unlinked": true
  }
}
```

### Security

1. **Token Expiration:** 15 minutes to prevent abuse
2. **Single Use:** Token can only be used once
3. **Phone Normalization:** All numbers normalized to E.164 format
4. **Multi-tenancy:** Each link includes `companyId` for data isolation

---

## Magic Links / Share Links

The WhatsApp share feature integrates with the existing Share Link system. When sharing an order via WhatsApp:

1. A share token is generated (or reused if valid)
2. A formatted message is created with the magic link
3. WhatsApp is opened with the pre-filled message

### WhatsApp Message Format

```
Olá {customerName}! Segue o link para acompanhar sua OS #{orderNumber} da {companyName}:
https://praticos.web.app/q/{token}

Através deste link você pode visualizar os detalhes e aprovar o orçamento.
```

### Integration with ShareLinkSheet

The `ShareLinkSheet` widget includes a WhatsApp button that:

1. Checks if customer has a phone number
2. Generates/reuses share token
3. Opens `wa.me` link with formatted message

See `docs/SHARE_LINK.md` for complete Share Link documentation.

### Bot Endpoints (WhatsApp)

For bot-initiated operations:

| Endpoint | Description |
|----------|-------------|
| `POST /bot/orders/{number}/share` | Generate share token by order number |
| `GET /bot/orders/{number}/share` | List active tokens with formatted message |
| `DELETE /bot/orders/{number}/share/{token}` | Revoke token with formatted response |

---

## Bot Central (ClawdBot)

The PraticOS bot runs on ClawdBot infrastructure, providing:

- Conversational interface for service management
- Voice message transcription
- Photo handling for orders
- Team management via invites

### Architecture

- **Platform:** ClawdBot (Multi-tenant Gateway)
- **Session:** Baileys WebSocket connection
- **Storage:** Shared credentials at `/var/clawdbot/.openclaw/credentials/whatsapp/default`

### Key Features

1. **Assisted Order Creation** - Guided flow with buttons/menus
2. **Proactive Cash Closing** - End-of-day summaries
3. **Collection Management** - Payment reminders
4. **Contact Sharing** - Native vCard format

See `docs/praticos-bot-central.md` for complete bot documentation.

---

## Notifications (Planned)

The system supports outbound WhatsApp notifications via a queue system.

### Notification Queue: `notifications/outbound/queue/{id}`

```json
{
  "type": "rating",
  "channel": "whatsapp",
  "recipient": "+5511999999999",
  "recipientName": "João",
  "companyId": "company_xyz",
  "orderId": "order_123",
  "orderNumber": 42,
  "payload": {
    "score": 5,
    "comment": "Excelente!",
    "customerName": "Maria"
  },
  "status": "pending",
  "createdAt": "2025-01-09T10:00:00Z",
  "sentAt": null,
  "error": null
}
```

**Status Flow:** `pending` → `sent` | `failed`

### Notification Types

| Type | Trigger | Description |
|------|---------|-------------|
| `rating` | Customer submits rating | New review notification |
| `order_approved` | Customer approves quote | Approval notification (planned) |
| `order_completed` | Order marked done | Completion notification (planned) |
| `payment_reminder` | Payment overdue | Collection reminder (planned) |

See `docs/WHATSAPP_RATING_NOTIFICATIONS.md` for implementation details.

---

## Security & Multi-tenancy

### Data Isolation

- Every WhatsApp link includes `companyId` for tenant isolation
- Users can only see their own company's linked numbers
- Bot validates company context before any data operation

### Token Security

- **Link Tokens:** UUID-based, 15-minute expiration, single-use
- **Share Tokens:** UUID-based, configurable expiration (7-30 days)
- **Phone Normalization:** All numbers converted to E.164 format

### Phone Number Normalization

```typescript
function normalizeWhatsAppNumber(number: string): string {
  // Remove all non-digit characters except leading +
  let normalized = number.replace(/[^\d+]/g, '');

  // Ensure it starts with +
  if (!normalized.startsWith('+')) {
    normalized = '+' + normalized;
  }

  return normalized;
}
```

---

## Frontend Implementation

### WhatsAppLinkService

Singleton service for API calls:

```dart
final service = WhatsAppLinkService.instance;

// Generate linking token
final token = await service.generateToken();
print('QR Data: ${token.link}');

// Check status
final status = await service.getStatus();
if (status.linked) {
  print('Linked to: ${status.number}');
}

// Unlink
await service.unlink();
```

### WhatsAppLinkStore (MobX)

Observable state for UI:

```dart
final store = WhatsAppLinkStore();

// Load current status
await store.loadStatus();

// Generate token for QR display
final token = await store.generateToken();

// Unlink
await store.unlink();
```

### LinkWhatsAppSheet (UI)

Bottom sheet with QR Code:

```dart
// Show linking sheet
await LinkWhatsAppSheet.show(context, store);
```

Features:
- Auto-generates token on open
- Displays QR Code with wa.me link
- Shows countdown timer (15 min)
- "Open WhatsApp" button for mobile
- Auto-refresh when token expires

---

## Related Documentation

- `docs/SHARE_LINK.md` - Magic link system for order sharing
- `docs/praticos-bot-central.md` - Bot central architecture and features
- `docs/WHATSAPP_RATING_NOTIFICATIONS.md` - Rating notification implementation
