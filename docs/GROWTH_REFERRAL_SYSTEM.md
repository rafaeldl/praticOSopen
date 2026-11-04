# Growth: Sistema de Referral com Tracking

## Visão Geral

O bot já suporta indicações informais (o usuário pede para indicar e o bot gera uma mensagem formatada com link do WhatsApp — ver `registration.md` seção "INDICAÇÃO"). Este sistema adiciona **tracking e atribuição** para que cada indicação seja rastreável: quem indicou, quem converteu, quando.

**Motivação:** Referral é o canal de aquisição com menor CAC. Usuários satisfeitos já indicam informalmente — com tracking, podemos medir o impacto, notificar o referrer sobre conversões, e futuramente criar incentivos (descontos, features premium).

**Estimativa de implementação:** ~2-3 dias

## Modelo de Dados

### Firestore: `/links/referrals/tokens/{code}`

Segue o padrão de `links/invites/tokens/{token}` usado pelo sistema de convites existente (`invite.service.ts`).

```typescript
export interface Referral {
  code: string;                    // REF_XXXXXXXX (8 chars alfanuméricos)
  companyId: string;               // Empresa do referrer
  companyName: string;             // Nome da empresa (denormalizado)
  createdBy: {                     // Quem gerou o código
    userId: string;
    userName: string;
  };
  createdAt: string;               // ISO 8601
  totalConversions: number;        // Counter (incrementado a cada conversão)
  totalClicks: number;             // Counter (incrementado a cada acesso ao link)
  status: 'active' | 'disabled';   // Permite desativar códigos
}
```

### Firestore: `/links/referrals/tokens/{code}/conversions/{conversionId}`

Subcollection para rastrear cada conversão individual.

```typescript
export interface ReferralConversion {
  id: string;                      // Auto-generated
  referralCode: string;            // REF_XXXXXXXX
  convertedCompanyId: string;      // Empresa criada pelo indicado
  convertedCompanyName: string;    // Nome da empresa indicada
  convertedUserId: string;         // userId do novo usuário
  convertedUserName: string;       // Nome do novo usuário
  channel: 'whatsapp' | 'web';    // Canal da conversão
  createdAt: string;               // ISO 8601
}
```

### Campos novos no Company model

**Arquivo:** `firebase/functions/src/models/types.ts` — interface `Company` (linha 329)

Adicionar:

```typescript
export interface Company {
  // ... campos existentes (name, email, address, logo, phone, site, segment, country, subspecialties, owner, users, createdAt, createdBy, updatedAt, updatedBy)
  referredBy?: string;              // REF_XXXXXXXX — código de quem indicou
  referralCode?: string;            // REF_XXXXXXXX — código próprio da empresa para indicar outros
}
```

**Arquivo:** `lib/models/company.dart` — classe `Company` (linha 10)

Adicionar:

```dart
@JsonSerializable(explicitToJson: true)
class Company extends BaseAudit {
  // ... campos existentes
  String? referredBy;    // REF code that referred this company
  String? referralCode;  // This company's own referral code
  // ...
}
```

> **Importante:** Após alterar o model Dart, executar `fvm flutter pub run build_runner build --delete-conflicting-outputs`.

## Geração de Código Referral

Reutilizar o padrão de `invite.service.ts:generateToken()` (linha 76):

```typescript
// invite.service.ts (existente)
export function generateToken(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let result = 'INV_';
  for (let i = 0; i < 8; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}
```

Para referral, usar prefixo `REF_`:

```typescript
// referral.service.ts (novo)
export function generateReferralCode(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let result = 'REF_';
  for (let i = 0; i < 8; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}
```

Garantir unicidade com retry (mesmo pattern de `invite.service.ts:createInvite()`, linhas 108-123).

## Novo Service

### `firebase/functions/src/services/referral.service.ts`

**Criar este arquivo.**

```typescript
/**
 * Referral Service
 * Manages referral code generation, tracking, and conversion attribution
 */

import { db } from './firestore.service';

// Types (definidos acima: Referral, ReferralConversion)

// Collection references
function getReferralsCollection() {
  return db.collection('links').doc('referrals').collection('tokens');
}

function getConversionsCollection(code: string) {
  return getReferralsCollection().doc(code).collection('conversions');
}

// ============================================================================
// Operations
// ============================================================================

/**
 * Generate a referral code for a company
 * - Se a empresa já tem um código, retorna o existente
 * - Senão, gera novo, salva no doc da empresa e na collection de referrals
 */
export async function generateOrGetReferralCode(
  companyId: string,
  companyName: string,
  userId: string,
  userName: string
): Promise<{ code: string; isNew: boolean }> { ... }

/**
 * Get referral stats for a company
 * Returns: totalConversions, totalClicks, recent conversions list
 */
export async function getReferralStats(
  companyId: string
): Promise<{
  code: string | null;
  totalConversions: number;
  totalClicks: number;
  conversions: ReferralConversion[];
}> { ... }

/**
 * Redeem a referral code during registration
 * - Valida que o código existe e está ativo
 * - Registra a conversão
 * - Incrementa counter no doc do referral
 * - Salva `referredBy` no doc da nova empresa
 * - Notifica o referrer via bot
 */
export async function redeemReferral(
  code: string,
  convertedCompanyId: string,
  convertedCompanyName: string,
  convertedUserId: string,
  convertedUserName: string,
  channel: 'whatsapp' | 'web'
): Promise<{ success: boolean; error?: string; referrerCompanyName?: string }> { ... }

/**
 * Track a click on a referral link (increment counter)
 */
export async function trackClick(code: string): Promise<void> { ... }

/**
 * Get referral by code
 */
export async function getByCode(code: string): Promise<Referral | null> { ... }

/**
 * Generate WhatsApp referral link
 * Reutiliza padrão de invite.service.ts:generateWhatsAppInviteLink()
 */
export function generateWhatsAppReferralLink(code: string): string {
  const botNumber = process.env.BOT_WHATSAPP_NUMBER || '+5548988794742';
  const cleanNumber = botNumber.replace(/\D/g, '');
  const message = encodeURIComponent(code);
  return `https://wa.me/${cleanNumber}?text=${message}`;
}
```

## Novos Endpoints

### Arquivo: `firebase/functions/src/routes/bot/referral.routes.ts`

**Criar este arquivo.**

```typescript
const router: Router = Router();

/**
 * POST /api/bot/referral/generate
 * Gera ou retorna o referral code da empresa do usuário
 *
 * Headers: X-API-Key, X-WhatsApp-Number
 * Response: { code, link, isNew }
 */
router.post('/generate', botAuth, async (req, res) => { ... });

/**
 * GET /api/bot/referral/stats
 * Retorna estatísticas de referral do usuário
 *
 * Headers: X-API-Key, X-WhatsApp-Number
 * Response: { code, totalConversions, totalClicks, conversions[] }
 */
router.get('/stats', botAuth, async (req, res) => { ... });

/**
 * POST /api/bot/referral/redeem
 * Resgata um código de referral durante o cadastro
 * Chamado pelo registration.service quando detecta prefixo REF_
 *
 * Headers: X-API-Key, X-WhatsApp-Number
 * Body: { code, companyId, companyName }
 * Response: { success, referrerCompanyName }
 */
router.post('/redeem', botAuth, async (req, res) => { ... });

export default router;
```

### Registrar rotas

**Arquivo:** `firebase/functions/src/routes/bot/` — importar e registrar em `index.ts` (ou onde as rotas bot são montadas):

```typescript
import referralRoutes from './referral.routes';
router.use('/referral', referralRoutes);
```

## Integração com o Bot

### 1. Atualizar `registration.md` — Detecção de prefixo `REF_`

**Arquivo:** `backend/bot/workspace/skills/praticos/references/registration.md`

O arquivo já detecta prefixos `LT_` e `INV_` (linha 10):

```
**Se enviou CODIGO (LT_, INV_):**
```

Adicionar `REF_` à lista de prefixos detectados:

```
**Se enviou CODIGO (LT_, INV_, REF_):**
```

**Novo fluxo para `REF_`:**

```markdown
**Se enviou CODIGO REF_:**
- Código de indicação, NÃO é convite para empresa existente
- Salvar o código na memória do usuário
- Iniciar AUTO-CADASTRO normalmente (POST /bot/registration/start)
- Ao completar (POST /bot/registration/complete), incluir `{"referralCode":"REF_XXXXXXXX"}` no body
- O backend resgata automaticamente o referral durante o complete
- Após sucesso, informar: "Sua conta foi criada! Você foi indicado por [referrerCompanyName]."
```

### 2. Atualizar SKILL.md — Novo endpoint na tabela

**Arquivo:** `backend/bot/workspace/skills/praticos/SKILL.md`

Adicionar à tabela de endpoints rápidos (linha 34):

```markdown
| Gerar referral | POST /bot/referral/generate |
| Stats referral | GET /bot/referral/stats |
```

### 3. Atualizar fluxo de indicação em `registration.md`

A seção "INDICAÇÃO / REFERRAL" (linha 40) atualmente gera uma mensagem genérica. Atualizar para incluir o referral code:

```markdown
## INDICAÇÃO / REFERRAL

1. Gerar código de referral: POST /bot/referral/generate
2. Usar o `code` e `link` retornados na mensagem formatada

Exemplo pt-BR:
message(action="send", message="Conheça o *PraticOS* — gestão de O.S. direto no celular!\n\n📱 Chama no WhatsApp: {link}\n🌐 Ou acesse: https://praticos.app\n\nÉ só mandar um oi que eu ajudo a criar sua conta na hora!")

3. Após enviar, orientar o usuário a encaminhar e compartilhar contato do bot
```

## Conexão com CTA da Página de OS (Fase 1)

Quando o referral system estiver implementado, o CTA da página de OS pode incluir o `referralCode` da empresa dona da OS.

### Alteração no endpoint público

**Arquivo:** `firebase/functions/src/routes/public/orders.routes.ts` — `GET /public/orders/:token` (linha 23)

No response, dentro do objeto `company`, expor o `referralCode`:

```typescript
company: company ? {
  name: company.name,
  logo: company.logo,
  phone: company.phone,
  email: company.email,
  address: company.address,
  country: company.country,
  referralCode: company.referralCode || null,  // NOVO
} : null,
```

### Alteração no CTA do footer

**Arquivo:** `firebase/hosting/src/js/order-view.js` — função `renderFooter()`

Se `orderData.company.referralCode` existir, incluir no link do WhatsApp:

```javascript
function renderFooter() {
    // ...
    const referralCode = orderData?.company?.referralCode;

    const whatsappMessages = {
        pt: referralCode
            ? `${referralCode} Olá! Vi o PraticOS numa OS e quero criar minha conta`
            : 'Olá! Vi o PraticOS numa OS e quero criar minha conta',
        // ... (en, es)
    };
    // ...
}
```

Assim, quando o novo usuário envia a mensagem ao bot com `REF_XXXXXXXX` no início, o bot detecta o prefixo e atribui a conversão.

## Incentivo v1: Notificação ao Referrer

Quando uma conversão é registrada (`redeemReferral`), enviar notificação ao referrer via bot:

```typescript
// Dentro de redeemReferral(), após registrar a conversão:

// Buscar o whatsapp number do owner da empresa referrer
const referrerOwner = referral.createdBy;
// Usar sessions_send para notificar via WhatsApp
// Mensagem: "🎉 Boa notícia! {convertedCompanyName} se cadastrou no PraticOS pela sua indicação!"
```

A implementação exata da notificação depende do mecanismo de push do bot (sessions_send via cron ou direto). O serviço deve expor um callback/hook que o bot possa consumir.

## Arquivos a Criar

| Arquivo | Descrição |
|---------|-----------|
| `firebase/functions/src/services/referral.service.ts` | Service com toda lógica de referral |
| `firebase/functions/src/routes/bot/referral.routes.ts` | Endpoints REST para o bot |

## Arquivos a Modificar

| Arquivo | Alteração |
|---------|-----------|
| `firebase/functions/src/models/types.ts` | Adicionar `referredBy` e `referralCode` à interface `Company` (linha 329) |
| `lib/models/company.dart` | Adicionar `referredBy` e `referralCode` à classe `Company` (linha 10) |
| `firebase/functions/src/routes/public/orders.routes.ts` | Expor `referralCode` no response de `GET /public/orders/:token` (linha 94) |
| `firebase/hosting/src/js/order-view.js` | Usar `referralCode` no link do WhatsApp do CTA footer |
| `backend/bot/workspace/skills/praticos/references/registration.md` | Adicionar detecção de prefixo `REF_` e fluxo de resgate |
| `backend/bot/workspace/skills/praticos/SKILL.md` | Adicionar endpoints `/bot/referral/*` à tabela |
| Rota bot index (onde rotas são montadas) | Registrar `referral.routes.ts` |
| `firebase/functions/src/services/registration.service.ts` | Chamar `redeemReferral()` durante `complete` se `referralCode` presente |

**Total: 2 arquivos criados, 8 arquivos modificados.**

## Fluxo Completo

```
Usuário A (já cadastrado)
    │
    ├── Pede para indicar PraticOS no bot
    │
    ▼
Bot chama POST /bot/referral/generate
    │
    ├── Retorna: { code: "REF_ABC12345", link: "https://wa.me/554888794742?text=REF_ABC12345" }
    │
    ▼
Bot envia mensagem formatada com link referral para Usuário A encaminhar
    │
    ▼
Usuário B (novo) recebe a mensagem e clica no link WhatsApp
    │
    ├── Abre conversa com bot, mensagem pré-preenchida: "REF_ABC12345"
    │
    ▼
Bot detecta prefixo REF_, salva na memória, inicia AUTO-CADASTRO
    │
    ├── Fluxo normal: nome empresa → segmento → especialidades → confirmar
    │
    ▼
Bot chama POST /bot/registration/complete { referralCode: "REF_ABC12345" }
    │
    ├── Backend: cria empresa, link WhatsApp, resgata referral
    ├── Backend: salva referredBy no doc da nova empresa
    ├── Backend: incrementa counter, registra conversão
    │
    ▼
Notificação ao Usuário A: "🎉 {companyName} se cadastrou pela sua indicação!"
```

### Fluxo alternativo: via CTA da página de OS

```
Cliente final visualiza OS em /q/{token}
    │
    ├── Footer mostra CTA com botão WhatsApp
    ├── Link inclui REF_XXXXXXXX da empresa dona da OS
    │
    ▼
Cliente clica no botão → abre WhatsApp com "REF_XXXXXXXX Olá!..."
    │
    ▼
(Mesmo fluxo de cadastro acima)
```

## Critérios de Verificação

- [ ] `POST /bot/referral/generate` retorna código `REF_XXXXXXXX` + link WhatsApp
- [ ] Código é salvo no doc da empresa em Firestore (`company.referralCode`)
- [ ] Chamar generate novamente retorna o mesmo código (não gera duplicatas)
- [ ] `GET /bot/referral/stats` retorna `totalConversions`, `totalClicks` e lista de conversões
- [ ] Quando novo usuário envia `REF_XXXXXXXX` ao bot, o cadastro registra a conversão
- [ ] Doc `/links/referrals/tokens/{code}` tem `totalConversions` incrementado
- [ ] Subcollection `/links/referrals/tokens/{code}/conversions/{id}` tem doc criado
- [ ] Nova empresa tem `referredBy: "REF_XXXXXXXX"` no Firestore
- [ ] Referrer recebe notificação via bot sobre a conversão
- [ ] `GET /public/orders/:token` retorna `company.referralCode` quando existe
- [ ] CTA na página de OS inclui referralCode no link do WhatsApp (se disponível)
- [ ] Model Dart `Company` tem os novos campos e `build_runner` gera sem erros
- [ ] Interface TypeScript `Company` reflete os mesmos campos
