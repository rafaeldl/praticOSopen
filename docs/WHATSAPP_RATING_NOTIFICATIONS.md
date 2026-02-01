# Plano: Notificação WhatsApp para Novas Avaliações

## Objetivo
Enviar notificação via WhatsApp quando um cliente submete uma nova avaliação de OS.

## Arquitetura

```
Cliente avalia OS (magic link)
        ↓
POST /public/orders/:token/rating
        ↓
[Firebase Functions: salva rating + enfileira notificação]
        ↓
Firestore: /notifications/outbound/queue/{id}
        ↓
[Notification Worker monitora via onSnapshot]
        ↓
Worker envia WhatsApp via Baileys → marca como 'sent'
```

## O que já existe
- Rating via magic link: `POST /public/orders/:token/rating`
- WhatsApp linking: `/links/whatsapp/numbers/{phone}` com `userId`, `companyId`, `identifier`
- ClawdBot rodando na VM com sessão Baileys em `/var/clawdbot/.openclaw/credentials/whatsapp/default`

---

## Implementação

### Parte 1: Firebase Functions

#### 1.1 Criar serviço de notificação

**Arquivo:** `firebase/functions/src/services/whatsapp-notification.service.ts`

```typescript
import { db } from './firestore.service';

interface OrderData {
  id: string;
  number: number;
  rating?: {
    customerName?: string;
  };
}

export async function queueRatingNotification(
  companyId: string,
  order: OrderData,
  score: number,
  comment?: string
): Promise<void> {
  // Buscar usuários vinculados ao WhatsApp da empresa
  const linkedUsers = await db
    .collection('links')
    .doc('whatsapp')
    .collection('numbers')
    .where('companyId', '==', companyId)
    .get();

  if (linkedUsers.empty) {
    console.log('No WhatsApp users linked for company:', companyId);
    return;
  }

  // Criar notificação para cada usuário
  const batch = db.batch();

  for (const doc of linkedUsers.docs) {
    const link = doc.data();
    const notificationRef = db
      .collection('notifications')
      .doc('outbound')
      .collection('queue')
      .doc();

    batch.set(notificationRef, {
      type: 'rating',
      channel: 'whatsapp',
      recipient: link.identifier,
      recipientName: link.userName,
      companyId,
      orderId: order.id,
      orderNumber: order.number,
      payload: {
        score,
        comment: comment || null,
        customerName: order.rating?.customerName || 'Cliente'
      },
      status: 'pending',
      createdAt: new Date()
    });
  }

  await batch.commit();
  console.log(`Queued ${linkedUsers.size} WhatsApp notifications for rating`);
}
```

#### 1.2 Integrar no endpoint de rating

**Arquivo:** `firebase/functions/src/routes/public/orders.routes.ts` (~linha 450)

Adicionar import e chamada após salvar o rating:

```typescript
import { queueRatingNotification } from '../../services/whatsapp-notification.service';

// Após a linha que atualiza o documento com o rating:
// await orderRef.update({ rating: ratingData });

// Adicionar:
try {
  await queueRatingNotification(companyId, order, score, comment);
} catch (error) {
  console.error('Failed to queue WhatsApp notification:', error);
  // Não bloqueia o fluxo se notificação falhar
}
```

---

### Parte 2: Notification Worker (VM)

#### 2.1 Estrutura de arquivos

```
/var/clawdbot/notification-worker/
├── index.js
├── package.json
├── service-account.json    # Baixar do Firebase Console
└── .env
```

#### 2.2 package.json

```json
{
  "name": "praticos-notification-worker",
  "version": "1.0.0",
  "main": "index.js",
  "dependencies": {
    "@whiskeysockets/baileys": "^6.7.9",
    "firebase-admin": "^12.0.0",
    "dotenv": "^16.4.5"
  }
}
```

#### 2.3 index.js

```javascript
require('dotenv').config();
const admin = require('firebase-admin');
const { makeWASocket, useMultiFileAuthState, DisconnectReason } = require('@whiskeysockets/baileys');
const { Boom } = require('@hapi/boom');

// Firebase
admin.initializeApp({
  credential: admin.credential.cert('./service-account.json')
});
const db = admin.firestore();

// Config
const WA_SESSION_PATH = process.env.WA_SESSION_PATH || '/var/clawdbot/.openclaw/credentials/whatsapp/default';

let sock = null;

async function connectWhatsApp() {
  const { state, saveCreds } = await useMultiFileAuthState(WA_SESSION_PATH);

  sock = makeWASocket({
    auth: state,
    printQRInTerminal: false,
    browser: ['PraticOS Notifications', 'Chrome', '120.0.0']
  });

  sock.ev.on('creds.update', saveCreds);

  sock.ev.on('connection.update', (update) => {
    const { connection, lastDisconnect } = update;
    if (connection === 'close') {
      const shouldReconnect = (lastDisconnect?.error instanceof Boom) &&
        lastDisconnect.error.output?.statusCode !== DisconnectReason.loggedOut;
      console.log('Connection closed, reconnecting:', shouldReconnect);
      if (shouldReconnect) {
        setTimeout(connectWhatsApp, 5000);
      }
    } else if (connection === 'open') {
      console.log('WhatsApp connected');
      startListener();
    }
  });
}

function startListener() {
  console.log('Starting notification listener...');

  db.collection('notifications')
    .doc('outbound')
    .collection('queue')
    .where('status', '==', 'pending')
    .where('channel', '==', 'whatsapp')
    .onSnapshot(async (snapshot) => {
      for (const change of snapshot.docChanges()) {
        if (change.type === 'added') {
          await processNotification(change.doc);
        }
      }
    }, (error) => {
      console.error('Firestore listener error:', error);
    });
}

async function processNotification(doc) {
  const data = doc.data();
  const { recipient, payload, orderNumber, recipientName } = data;

  console.log(`Processing notification for ${recipientName} (${recipient})`);

  const stars = '⭐'.repeat(payload.score);
  const message = `${stars} *Nova Avaliação!*

📋 OS #${orderNumber}
👤 ${payload.customerName}
⭐ ${payload.score} estrela${payload.score > 1 ? 's' : ''}${payload.comment ? `

💬 _"${payload.comment}"_` : ''}`;

  try {
    const jid = recipient.replace('+', '') + '@s.whatsapp.net';
    await sock.sendMessage(jid, { text: message });

    await doc.ref.update({
      status: 'sent',
      sentAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log(`Notification sent to ${recipientName}`);
  } catch (error) {
    console.error(`Failed to send to ${recipient}:`, error.message);
    await doc.ref.update({
      status: 'failed',
      error: error.message
    });
  }
}

// Start
console.log('PraticOS Notification Worker starting...');
connectWhatsApp();
```

#### 2.4 .env

```bash
WA_SESSION_PATH=/var/clawdbot/.openclaw/credentials/whatsapp/default
```

#### 2.5 Systemd service

**Arquivo:** `/etc/systemd/system/praticos-notifications.service`

```ini
[Unit]
Description=PraticOS WhatsApp Notification Worker
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/var/clawdbot/notification-worker
ExecStart=/usr/bin/node index.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
```

---

## Estrutura Firestore

**Collection:** `/notifications/outbound/queue/{id}`

```json
{
  "type": "rating",
  "channel": "whatsapp",
  "recipient": "+5511999999999",
  "recipientName": "João",
  "companyId": "xxx",
  "orderId": "yyy",
  "orderNumber": 42,
  "payload": {
    "score": 5,
    "comment": "Excelente!",
    "customerName": "Maria"
  },
  "status": "pending",
  "createdAt": "Timestamp",
  "sentAt": null,
  "error": null
}
```

**Status:** `pending` → `sent` | `failed`

---

## Arquivos a Criar/Modificar

| Ação | Arquivo |
|------|---------|
| **Criar** | `firebase/functions/src/services/whatsapp-notification.service.ts` |
| **Modificar** | `firebase/functions/src/routes/public/orders.routes.ts` |
| **Criar** | `backend/notification-worker/index.js` |
| **Criar** | `backend/notification-worker/package.json` |
| **Criar** | `backend/notification-worker/.env.example` |

---

## Deploy

### Firebase Functions
```bash
cd firebase/functions
npm run deploy
```

### Notification Worker (na VM)
```bash
# Copiar arquivos para VM
scp -r backend/notification-worker/* user@vm:/var/clawdbot/notification-worker/

# Na VM
cd /var/clawdbot/notification-worker
npm install

# Baixar service-account.json do Firebase Console
# Configurações do Projeto > Contas de Serviço > Gerar nova chave privada

# Instalar e iniciar serviço
sudo cp praticos-notifications.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable praticos-notifications
sudo systemctl start praticos-notifications

# Verificar logs
sudo journalctl -u praticos-notifications -f
```

---

## Verificação

1. Deploy Firebase Functions
2. Deploy Worker na VM
3. Verificar logs: `sudo journalctl -u praticos-notifications -f`
4. Submeter avaliação via magic link (`/q/{token}`)
5. Verificar documento criado em `/notifications/outbound/queue/`
6. Confirmar mensagem recebida no WhatsApp
7. Verificar que documento foi marcado como `status: 'sent'`

---

## Notas Técnicas

### Por que Worker Separado?

O ClawdBot (OpenClaw) não suporta scripts JavaScript executáveis dentro de skills - skills são apenas arquivos Markdown (prompts para IA). Por isso, a melhor abordagem é um worker Node.js separado que:

- Roda na mesma VM do ClawdBot
- Reutiliza a sessão Baileys existente
- Monitora o Firestore via `onSnapshot`
- É gerenciado pelo systemd (auto-restart, logs)

### Extensibilidade

A fila `/notifications/outbound/queue/` pode ser usada para outros tipos de notificação:

- `type: 'order_approved'` - Cliente aprovou orçamento
- `type: 'order_completed'` - OS concluída
- `type: 'payment_reminder'` - Lembrete de pagamento

Basta adicionar novas chamadas `queueXxxNotification()` e tratar o `type` no worker.
