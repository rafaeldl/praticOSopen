# Cobrança da OS via Asaas — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** O técnico gera, a partir da OS, uma cobrança Asaas (à vista ou parcelada no cartão) na conta da própria empresa; o pagamento confirmado dá baixa na OS automaticamente e o cliente paga pelo link `/q/{token}`.

**Architecture:** Todas as chamadas ao Asaas saem das Cloud Functions (Express `api`). A chave Asaas de cada empresa fica criptografada (AES-256-GCM) em `companies/{cid}/private/asaas`, inacessível ao app. Cobranças vivem em `companies/{cid}/orders/{oid}/charges` (escrita só servidor) e são a fonte da verdade; um webhook por empresa lança os pagamentos na OS dentro de transação Firestore, e um trigger de reparo reinsere pagamentos apagados por versões antigas do app.

**Tech Stack:** Firebase Functions v2 (Node 22, TypeScript, Express 4, zod, jest + supertest, `fetch` nativo), Firestore + rules, Flutter (MobX, Cupertino, `http`, flutter_test), Nuxt 3 (link público em `firebase/web`).

**Spec:** `docs/superpowers/specs/2026-10-04-asaas-cobranca-os-design.md` (ler antes de qualquer task).

## Global Constraints

- Código, chaves JSON/Firestore e valores no banco em **inglês**; strings de UI em pt-BR via `context.l10n`, nos 3 `.arb` (pt, en, es) + `fvm flutter gen-l10n`.
- Valores e datas no app sempre via `FormatService`; nunca `toStringAsFixed` para exibir.
- UI Cupertino-first; cores dinâmicas com `.resolveFrom(context)`; status com dot colorido (azul pendente, vermelho vencida, verde paga).
- `PaymentTransaction.type` continua só `payment` | `discount` (versões antigas usam `$enumDecode` e quebram com valor novo). `createdAt` gravado pelo servidor como **ISO string**.
- Status de pagamento da OS gravado só como `paid` | `unpaid` (convenção do app; "parcial" é calculado em memória).
- Saldo restante = `total - paidAmount` (o `total` da OS já é líquido de desconto).
- Nunca logar chave Asaas, token de webhook ou payload de webhook. Nunca commitar segredos. Repo é **público**.
- Após alterar models/stores Flutter: `fvm flutter pub run build_runner build --delete-conflicting-outputs`.
- Verificação mínima por task: `cd firebase/functions && npm run lint && npm test` (server) e/ou `fvm flutter analyze && fvm flutter test` (app); `cd firebase/web && npm run build` (web).
- Conventional Commits; um PR por bloco (A–F), branch `tipo/descricao` a partir da `master`, label `risk:high`, `Refs #303`.
- Commits terminam com `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Contrato entre blocos (nomes e assinaturas)

Todas as tasks usam exatamente estes nomes.

**Firestore**
- `companies/{cid}/private/asaas` — doc `AsaasConnectionDoc` (server-only).
- `companies/{cid}/private/asaas/customers/{customerId}` — `{ asaasCustomerId: string }`.
- `companies/{cid}/private/asaas/events/{eventId}` — `{ processedAt: string, expiresAt: Timestamp }` (TTL em `expiresAt`).
- `companies/{cid}/settings/payments` — `{ asaasEnabled: boolean, asaasConnected: boolean, asaasAccountName?: string, asaasEnvironment?: 'sandbox'|'production' }`.
- `companies/{cid}/orders/{oid}/charges/{chargeId}` — doc `OrderCharge`.
- `Customer.taxId` / `CustomerAggr.taxId` (string normalizada: dígitos e, no CNPJ alfanumérico, letras maiúsculas).

**Functions — tipos (`firebase/functions/src/models/asaas.types.ts`)**
```ts
export type AsaasEnvironment = 'sandbox' | 'production';
export type AsaasConnectionMode = 'apiKey' | 'flapp';
export interface EncryptedSecret { iv: string; tag: string; ciphertext: string } // base64
export interface AsaasConnectionDoc {
  mode: AsaasConnectionMode; environment: AsaasEnvironment;
  encryptedApiKey: EncryptedSecret; accountName: string; walletId?: string;
  webhookId?: string; webhookTokenHash?: string; status: 'active' | 'invalid';
  connectedBy: UserAggr; connectedAt: string;
}
export type ChargeMode = 'single' | 'cardInstallments';
export type ChargeStatus = 'pending' | 'paid' | 'overdue' | 'canceled' | 'refunded';
export interface OrderCharge {
  id: string; asaasPaymentId: string; asaasInstallmentId?: string;
  mode: ChargeMode; installmentCount?: number; value: number; dueDate: string; // YYYY-MM-DD
  status: ChargeStatus; invoiceUrl: string; paidAsaasPaymentIds: string[];
  createdBy: UserAggr; createdAt: string; paidAt?: string;
}
export interface PaymentSettingsDoc { asaasEnabled: boolean; asaasConnected: boolean; asaasAccountName?: string; asaasEnvironment?: AsaasEnvironment }
```

**Functions — módulos**
- `src/services/asaas/crypto.ts`: `encryptSecret(plain: string, masterKeyB64: string): EncryptedSecret`, `decryptSecret(enc: EncryptedSecret, masterKeyB64: string): string`, `hashToken(token: string): string` (sha256 hex), `safeEqualHex(a: string, b: string): boolean`.
- `src/services/asaas/asaas-client.ts`: `class AsaasClient { constructor(opts: { apiKey: string; environment: AsaasEnvironment; fetchImpl?: typeof fetch }) ; getMyAccount(); getWallets(); createWebhook(input); deleteWebhook(id); findCustomerByExternalReference(ref); createCustomer(input); createPayment(input); deletePayment(id); deleteInstallment(id); listInstallmentPayments(installmentId) }` + `class AsaasApiError extends Error { status: number; errors: {code:string;description:string}[] }` + `environmentFromApiKey(key: string): AsaasEnvironment | null`.
- `src/services/asaas/credential-provider.ts`: `interface AsaasCredentialProvider { getClient(companyId: string): Promise<AsaasClient> }`, `class ApiKeyCredentialProvider implements AsaasCredentialProvider` (lê `private/asaas`, decripta com `ASAAS_CREDENTIALS_KEY`), `getAsaasCredentialProvider(): AsaasCredentialProvider` (singleton substituível em testes via `setAsaasCredentialProvider(p)`).
- `src/services/asaas/connection.service.ts`: `connectAsaas(companyId: string, apiKey: string, user: UserAggr & { email?: string }): Promise<PaymentSettingsDoc>`, `disconnectAsaas(companyId: string): Promise<void>`, `getPaymentSettings(companyId): Promise<PaymentSettingsDoc>`.
- `src/services/asaas/charge.service.ts`: `createOrderCharge(companyId, orderId, input: CreateChargeInput, user: UserAggr): Promise<OrderCharge>`, `cancelOrderCharge(companyId, orderId, chargeId): Promise<OrderCharge>`, `cancelOpenChargesForOrder(companyId, orderId): Promise<void>`, `getOpenOrLatestPaidCharge(companyId, orderId): Promise<OrderCharge | null>`. `CreateChargeInput = { value: number; mode: ChargeMode; installmentCount?: number; dueDate?: string; customerTaxId?: string }`.
- `src/services/asaas/order-payment.service.ts`: `applyAsaasPayment(companyId, orderId, chargeId, payment: AsaasPaymentEvent): Promise<{ applied: boolean }>`, `revertAsaasPayment(companyId, orderId, chargeId, asaasPaymentId): Promise<{ reverted: boolean }>`, `repairAsaasTransactions(companyId, orderId): Promise<{ repaired: number }>`. Transação lançada tem `id = 'asaas_' + payment.id`.
- `src/services/asaas/webhook.service.ts`: `handleAsaasEvent(companyId: string, event: AsaasWebhookEvent): Promise<void>`.
- Rotas: `src/routes/v1/asaas-connection.routes.ts` (montada em `/v1/app/payments/asaas`), `src/routes/v1/charges.routes.ts` (montada em `/v1/app/orders`, paths `/:orderId/charges` e `/:orderId/charges/:chargeId`), `src/routes/webhooks/asaas.routes.ts` (montada em `/webhooks/asaas`, path `/:companyId`).
- Trigger: `export const repairAsaasPayments = onDocumentUpdated('companies/{companyId}/orders/{orderId}', ...)` em `src/index.ts`.
- Permissão backend nova: `manage:payments` (owner, admin, manager) em `getRolePermissions`.
- Utilitário de saldo: `calculateRemainingBalance(order) = Math.max(0, total - paidAmount)` em `order.service.ts`.
- Env/secrets: `ASAAS_CREDENTIALS_KEY` (`defineSecret`, base64 de 32 bytes), `ASAAS_WEBHOOK_BASE_URL` (env), `ASAAS_SANDBOX_API_KEY` (só script E2E).

**Flutter**
- `PermissionType.chargeOrder` (admin, manager; owner já tem tudo).
- `lib/models/order_charge.dart`: `OrderCharge` (json_serializable) com os mesmos campos; `enum ChargeStatus { pending, paid, overdue, canceled, refunded }`, `enum ChargeMode { single, cardInstallments }`.
- `lib/models/payment_settings.dart`: `PaymentSettings` (`asaasEnabled`, `asaasConnected`, `asaasAccountName`, `asaasEnvironment`).
- `lib/services/api_headers.dart`: `Future<Map<String,String>> appApiHeaders({String? companyId})` — inclui `Authorization: Bearer` e `X-Company-Id` (usar `Global.companyAggr?.id`); `IntegrationApiService` e o novo serviço usam.
- `lib/services/asaas_api_service.dart`: `AsaasApiService` (singleton + `withClient`): `connect(String apiKey) → PaymentSettings`, `disconnect()`, `createCharge(String orderId, {required double value, required ChargeMode mode, int? installmentCount, DateTime? dueDate, String? customerTaxId}) → OrderCharge`, `cancelCharge(String orderId, String chargeId) → OrderCharge`; erros como `AsaasApiException(code, message)`.
- `lib/repositories/tenant/tenant_order_repository.dart`: `createItem` remove `transactions`, `paidAmount`, `paid`, `payment` do JSON quando a OS já existe; novo `Future<Order?> updatePayments(String companyId, String orderId, Order Function(Order fresh) mutate)` com `runTransaction`.
- `lib/repositories/tenant/payment_settings_repository.dart`: `Stream<PaymentSettings> watch(String companyId)`.
- `lib/repositories/tenant/order_charge_repository.dart`: `Stream<List<OrderCharge>> watch(String companyId, String orderId)` (ordenado por `createdAt` desc).
- `lib/utils/tax_id.dart`: `String normalizeTaxId(String)` (ver Ajuste 3; substitui `onlyDigits`), `bool isValidCpf(String)`, `bool isValidCnpj(String)`, `bool isValidTaxId(String)`, `String formatTaxId(String)`.

**Web (`firebase/web`)**
- `GET /public/orders/:token` passa a incluir `charge: { status, value, dueDate, mode, installmentCount?, invoiceUrl } | null`.

## Blocos (PRs)

| Bloco | PR | Conteúdo |
|-------|----|----------|
| A | `fix/payments-foundation` | Saldo corrigido no server, OS sem sobrescrever pagamentos no app, `X-Company-Id`, permissão `chargeOrder`/`manage:payments`, `Customer.taxId` |
| B | `feat/asaas-connection-charges` | crypto, AsaasClient, credential provider, connect/disconnect, charges, cancelamento ao cancelar OS |
| C | `feat/asaas-webhook` | webhook, lançamento/estorno na OS, trigger de reparo, regras Firestore |
| D | `feat/asaas-app` | Integrações > Asaas, Cobrar, card de cobrança, CPF/CNPJ no cliente |
| E | `feat/asaas-share-link` | `charge` no endpoint público e botão "Pagar" no `/q/{token}` |
| F | `docs/asaas-payments` | E2E sandbox, `docs/ASAAS_INTEGRATION.md`, artigo público pt/en/es, rollout |

---
## Ajustes de integração (valem sobre o texto dos blocos)

Revisão cruzada dos blocos. Onde um bloco diz outra coisa, **vale o que está aqui**.

### Ordem de execução e dependências

`A → B → C → D → E → F`. B depende de A (`manage:payments`, saldo); C depende de B (`asaas.types.ts`, `crypto.ts`, `fake-firestore.ts`); D depende de A e B (contrato de respostas e códigos de erro); E depende de B; F depende de B–E.

### Passos manuais (Rafael) que bloqueiam merge

| Antes de mergear | Passo | Por quê |
|---|---|---|
| **Bloco B** | `openssl rand -base64 32 \| gcloud secrets create ASAAS_CREDENTIALS_KEY --data-file=- --project praticos` | Todo push na `master` faz deploy das Functions; sem o secret, o deploy falha |
| Depois do **Bloco C** | `cd firebase && firebase deploy --only firestore:rules,firestore:indexes --project praticos` e o `gcloud firestore fields ttls update` do C7 | O CI não publica regras nem índices |
| Antes do piloto | App novo publicado (TestFlight/Internal → produção) | Versão antiga não tem "Cobrar"; o trigger cobre sobrescrita |

### Correções

1. **Códigos de erro (B ↔ D).** Valem os do `AsaasErrorCode` do Bloco B. O Bloco D já foi ajustado: valor acima do saldo = `INVALID_VALUE`, CPF/CNPJ ausente = `TAX_ID_REQUIRED`. O `asaasErrorText` do D trata também `ORDER_CANCELED`, `INVALID_DUE_DATE`, `INVALID_INSTALLMENT_COUNT`, `CHARGE_NOT_OPEN`, `ASAAS_VALIDATION_ERROR` e `ASAAS_UNAVAILABLE` com mensagens próprias (pt/en/es); qualquer outro código cai na mensagem genérica.

2. **Pagamento manual offline (A3/A4).** `runTransaction` não funciona sem conexão, e técnico em campo registra pagamento offline. Ajuste:
   - `addPayment` e `addDiscountTransaction` gravam com transformações de campo, que funcionam offline e são atômicas: `transactions: FieldValue.arrayUnion([txJson])`, `paidAmount: FieldValue.increment(amount)` (pagamento) ou `discount: FieldValue.increment(amount)` + `total: FieldValue.increment(-amount)` (desconto), mais `payment`/`paid` calculados a partir do estado local. Teste em `order_payment_math.dart` cobre o cálculo do mapa de update (`OrderPaymentMath.addPaymentUpdate(...)` / `addDiscountUpdate(...)` retornando o `Map<String, dynamic>`; o repositório só converte os marcadores em `FieldValue`).
   - `removeTransaction`, `resetAllPayments` e `markAsFullyPaid` continuam com `updatePayments` (`runTransaction`): são raros, precisam do estado fresco, e mostram erro claro offline ("Sem conexão. Tente de novo quando estiver online.", chave l10n `paymentRequiresConnection`).

3. **CNPJ alfanumérico (A7, B5).** Desde julho/2026 a Receita emite CNPJ com letras nas 12 primeiras posições. `lib/utils/tax_id.dart` e `src/utils/tax-id.utils.ts`:
   - `normalizeTaxId(s)` (substitui `onlyDigits` no contrato): maiúsculas, remove `.`, `-`, `/` e espaços; mantém `[0-9A-Z]`.
   - `isValidCnpj` aceita 12 caracteres `[0-9A-Z]` + 2 dígitos verificadores numéricos; valor de cada caractere = `codeUnit - 48` (dígitos 0–9, letras A=17…Z=42), mesmos pesos do CNPJ numérico.
   - Testes com um CNPJ numérico válido, um alfanumérico válido (`12ABC34501DE35`, exemplo oficial da Receita) e um inválido.
   - `Customer.taxId` grava o valor normalizado (pode conter letras). O E2E do F1 confirma se o Asaas aceita CNPJ alfanumérico; se não aceitar, o charge.service devolve `INVALID_TAX_ID` com mensagem específica e isso entra na doc.

4. **Tela desatualizada após pagamento via webhook (D8).** O `orderStream` do store não atualiza campos de pagamento. No `order_charge_card.dart`, quando uma cobrança passa para `paid` ou `refunded` (comparar status anterior × novo no listener), chamar `OrderStore.reloadPayments()` — novo método que lê a OS do servidor (`GetOptions(source: Source.server)`) e atualiza `transactions`, `paidAmount`, `payment`, `discount` e `total` locais. Incluir o método e um teste do mapeamento no Bloco D.

5. **Aviso de total alterado (D8).** Mostrar só quando `charge.value > saldo restante + 0,005` (a OS ficou menor que a cobrança). Cobrança de entrada (valor menor que o saldo) não gera aviso.

6. **`PAYMENT_DELETED` em parcelamento parcialmente pago (C5).** Se a cobrança tem `paidAsaasPaymentIds` não vazio, não mudar para `canceled`; manter o status atual. Acrescentar esse caso ao teste "PAYMENT_DELETED cancela só se não paga".

7. **Fake de Firestore duplicado (B3 × C1).** C usa o `fake-firestore.ts` do B, estendendo-o com `runTransaction` se faltar, em vez de criar `asaas-fake-db.ts`. Se a extensão ficar maior que o fake novo, manter o do C e registrar no PR; não manter os dois sem motivo.

8. **Montagem de rotas (B8).** Em vez de um terceiro `app.use('/v1/app/orders', apiCoreLimiter, bearerAuth, resolveCompanyContext, chargesRoutes)`, juntar num único mount: `app.use('/v1/app/orders', apiCoreLimiter, bearerAuth, resolveCompanyContext, ordersRoutes, shareRoutes, chargesRoutes)`. Isso evita contar o rate limit e validar o token três vezes por requisição (problema que já existia com dois mounts).

9. **Conta Asaas (B2).** `GET /v3/myAccount` foi testado e responde 200 no sandbox (2026-10-04); `getMyAccount()` pode usar `/v3/myAccount/commercialInfo` como o B propõe, mas o teste de conexão do F1 registra qual endpoint foi usado.

### Cobertura da spec

| Spec | Task |
|---|---|
| Saldo corrigido, permissão, `X-Company-Id`, `taxId`, OS sem sobrescrever pagamentos | A1–A8 |
| Credencial criptografada, connect/disconnect, webhook cadastrado | B1–B4, B6 |
| Gerar/cancelar cobrança, cliente Asaas, cancelar ao cancelar OS | B5, B7, B8 |
| Webhook, idempotência, lançamento/estorno, push, reparo, regras, TTL | C1–C7 |
| Integrações > Asaas, Cobrar, card, CPF/CNPJ no cliente, ícone Asaas | D1–D9 |
| Link `/q/{token}` com Pagar/Vencida/Pago e refetch | E1–E3 |
| E2E sandbox, script do piloto, docs técnica e artigo público | F1–F4 |

---
## Bloco A — Base de pagamentos (saldo, gravação atômica, X-Company-Id, permissões, CPF/CNPJ)

> Contract note 1: `TenantOrderRepository.updateItem` **também** remove `transactions`, `paidAmount`, `paid` e `payment` (o `OrderStore` salva OS existentes via `OrderRepositoryV2.updateItem`, não `createItem`). Em `createItem`, a existência da OS é verificada com uma leitura do documento, porque `RepositoryV2.createItem` sempre atribui um id antes de chamar o tenant repo (o id não indica se a OS já existe). `OrderRepositoryV2` ganha `updatePayments(...)` delegando ao `TenantOrderRepository`.
>
> Contract note 2: `updatePayments` grava, além dos 4 campos de pagamento, `discount`, `total` (um desconto altera os dois) e `updatedAt`/`updatedBy`.
>
> Contract note 3: `appApiHeaders({String? companyId, Future<String?> Function()? tokenProvider})` — o parâmetro `tokenProvider` é opcional (ponto de injeção para testes); sem token lança `AppApiUnauthenticatedException`.
>
> Contract note 4: no servidor, `PaymentStatus` passa a ser `'unpaid' | 'paid'`; `order.service.ts` exporta também `applyPaymentTransaction(order, transaction)` e `roundMoney(n)` (Bloco C pode reusar no recálculo). No app, as regras puras ficam em `lib/utils/order_payment_math.dart` (`OrderPaymentMath`), porque o projeto não tem `fake_cloud_firestore`.
>
> Contract note 5: os métodos de pagamento do `OrderStore` passam a ser assíncronos: `addPayment → Future<PaymentTransaction?>`, `addDiscountTransaction/markAsFullyPaid/removeTransaction/resetAllPayments → Future<bool>`. `updatePayment()` continua síncrono e só calcula o rótulo de exibição; a persistência do `payment` ao mudar o status da OS vai para `setStatus` via `updatePayments`.

**Branch:** `fix/payments-foundation` (a partir da `master`). **PR:** `fix(payments): saldo correto, pagamentos atômicos e base para cobrança Asaas`.

Este bloco não fala com o Asaas. Ele corrige o saldo no servidor (o desconto era subtraído duas vezes), faz o app parar de sobrescrever pagamentos ao salvar a OS (requisito para o webhook do Bloco C), passa a enviar `X-Company-Id`, cria as permissões `chargeOrder`/`manage:payments` e adiciona `taxId` (CPF/CNPJ) ao cliente.

**Verificação do PR (rodar antes de abrir):**

```bash
cd firebase/functions && npm run lint && npm run build && npm test
cd ../.. && fvm flutter analyze && fvm flutter test
```

---

### Task A1: Saldo no servidor = total − paidAmount, `addPayment` transacional e analytics sem desconto duplo

**Files:**
- Modify: `firebase/functions/src/models/types.ts:194` (`PaymentStatus`)
- Modify: `firebase/functions/src/services/order.service.ts:7-15` (imports), `:16-29` (imports de tipos), `:555-615` (`addPayment`), `:635-640` (`calculateRemainingBalance`)
- Modify: `firebase/functions/src/services/analytics.service.ts:6` (imports), `:137-157` (`calculateRevenue`), `:278` (saldo em `getPendingItems`)
- Test: `firebase/functions/src/services/__tests__/order.service.test.ts` (novo)
- Test: `firebase/functions/src/services/__tests__/analytics.service.test.ts` (novo)

**Interfaces:**
- Consumes: `runTransaction(fn)` e `getTenantCollection(companyId, 'orders')` de `src/services/firestore.service.ts`.
- Produces: `calculateRemainingBalance(order) = Math.max(0, total - paidAmount)`; `applyPaymentTransaction(order, transaction)`; `roundMoney(value)`; `addPayment(...)` grava `payment` só como `'paid' | 'unpaid'`, desconto reduz `order.total`; `calculateRevenue(orders)` exportada.

- [ ] **Step 1: Criar a branch**

```bash
git checkout master && git pull --ff-only
git checkout -b fix/payments-foundation
```

- [ ] **Step 2: Escrever os testes que falham**

Criar `firebase/functions/src/services/__tests__/order.service.test.ts`:

```ts
jest.mock('uuid', () => ({ v4: () => 'txn-1' }));

const mockTxGet = jest.fn();
const mockTxUpdate = jest.fn();
const mockOrderRef = { id: 'order1' };

jest.mock('../firestore.service', () => ({
  getTenantCollection: jest.fn(() => ({ doc: jest.fn(() => mockOrderRef) })),
  runTransaction: jest.fn((fn: (tx: unknown) => Promise<unknown>) =>
    fn({ get: mockTxGet, update: mockTxUpdate })
  ),
}));

import {
  addPayment,
  applyPaymentTransaction,
  calculateRemainingBalance,
} from '../order.service';
import { Order, PaymentTransaction, UserAggr } from '../../models/types';

const user: UserAggr = { id: 'user1', name: 'Test User' };

function snapshot(data: Partial<Order> | null) {
  return { exists: !!data, id: 'order1', data: () => data };
}

function txn(type: 'payment' | 'discount', amount: number): PaymentTransaction {
  return {
    id: `t-${type}-${amount}`,
    type,
    amount,
    createdAt: '2026-10-04T10:00:00.000Z',
    createdBy: user,
  };
}

describe('calculateRemainingBalance', () => {
  it('usa total - paidAmount (total já é líquido de desconto)', () => {
    expect(calculateRemainingBalance({ total: 90, discount: 10, paidAmount: 30 } as Order)).toBe(60);
  });

  it('nunca retorna negativo', () => {
    expect(calculateRemainingBalance({ total: 50, discount: 0, paidAmount: 80 } as Order)).toBe(0);
  });

  it('trata valores ausentes como zero', () => {
    expect(calculateRemainingBalance({} as Order)).toBe(0);
  });
});

describe('applyPaymentTransaction', () => {
  it('pagamento soma em paidAmount e mantém o total', () => {
    const result = applyPaymentTransaction(
      { total: 100, discount: 0, paidAmount: 0, transactions: [] },
      txn('payment', 40)
    );
    expect(result).toMatchObject({
      total: 100,
      discount: 0,
      paidAmount: 40,
      paid: false,
      payment: 'unpaid',
      remainingBalance: 60,
    });
    expect(result.transactions).toHaveLength(1);
  });

  it('desconto reduz o total e acumula em discount', () => {
    const result = applyPaymentTransaction(
      { total: 100, discount: 0, paidAmount: 50 },
      txn('discount', 10)
    );
    expect(result).toMatchObject({
      total: 90,
      discount: 10,
      paidAmount: 50,
      paid: false,
      payment: 'unpaid',
      remainingBalance: 40,
    });
  });

  it('marca como pago quando paidAmount alcança o total líquido', () => {
    const result = applyPaymentTransaction(
      { total: 90, discount: 10, paidAmount: 50 },
      txn('payment', 40)
    );
    expect(result).toMatchObject({ paid: true, payment: 'paid', remainingBalance: 0 });
  });

  it('desconto que cobre o saldo marca como pago', () => {
    const result = applyPaymentTransaction(
      { total: 100, discount: 0, paidAmount: 90 },
      txn('discount', 10)
    );
    expect(result).toMatchObject({ total: 90, paid: true, payment: 'paid', remainingBalance: 0 });
  });

  it('arredonda para centavos', () => {
    const result = applyPaymentTransaction(
      { total: 0.3, discount: 0, paidAmount: 0.1 },
      txn('payment', 0.2)
    );
    expect(result.paidAmount).toBe(0.3);
    expect(result.payment).toBe('paid');
  });
});

describe('addPayment', () => {
  beforeEach(() => jest.clearAllMocks());

  it('retorna null quando a OS não existe', async () => {
    mockTxGet.mockResolvedValue(snapshot(null));

    await expect(addPayment('comp1', 'order1', 10, 'payment', undefined, user)).resolves.toBeNull();
    expect(mockTxUpdate).not.toHaveBeenCalled();
  });

  it('desconto reduz o total na transação e nunca grava partial', async () => {
    mockTxGet.mockResolvedValue(snapshot({ total: 100, discount: 0, paidAmount: 20, transactions: [] }));

    const result = await addPayment('comp1', 'order1', 10, 'discount', 'Desconto', user);

    expect(result).toEqual({
      transactionId: 'txn-1',
      paidAmount: 20,
      remainingBalance: 70,
      isFullyPaid: false,
    });
    expect(mockTxUpdate).toHaveBeenCalledWith(
      mockOrderRef,
      expect.objectContaining({
        total: 90,
        discount: 10,
        paidAmount: 20,
        paid: false,
        payment: 'unpaid',
        transactions: [
          expect.objectContaining({ id: 'txn-1', type: 'discount', amount: 10, description: 'Desconto' }),
        ],
      })
    );
  });

  it('omite description undefined (Firestore rejeita undefined)', async () => {
    mockTxGet.mockResolvedValue(snapshot({ total: 50, discount: 0, paidAmount: 0 }));

    await addPayment('comp1', 'order1', 50, 'payment', undefined, user);

    const update = mockTxUpdate.mock.calls[0][1];
    expect(update.transactions[0]).not.toHaveProperty('description');
    expect(update.payment).toBe('paid');
    expect(update.paid).toBe(true);
  });
});
```

Criar `firebase/functions/src/services/__tests__/analytics.service.test.ts`:

```ts
const mockGet = jest.fn();

jest.mock('../firestore.service', () => ({
  getTenantCollection: jest.fn(() => ({
    get: mockGet,
    where: jest.fn(() => ({ get: mockGet })),
  })),
  runTransaction: jest.fn(),
}));

import { calculateRevenue, getPendingItems } from '../analytics.service';
import { Order } from '../../models/types';

function docs(orders: Partial<Order>[]) {
  return { docs: orders.map((o, i) => ({ id: `o${i}`, data: () => o })) };
}

describe('analytics.service — saldo sem desconto duplo', () => {
  beforeEach(() => jest.clearAllMocks());

  it('getPendingItems: saldo = total - paidAmount', async () => {
    mockGet.mockResolvedValue(
      docs([
        { number: 1, status: 'done', paid: false, total: 90, discount: 10, paidAmount: 30, createdAt: '2026-10-01T10:00:00.000Z' },
        { number: 2, status: 'done', paid: false, total: 90, discount: 10, paidAmount: 90, createdAt: '2026-10-01T10:00:00.000Z' },
      ])
    );

    const pending = await getPendingItems('comp1');

    expect(pending.unpaid).toHaveLength(1);
    expect(pending.unpaid[0]).toMatchObject({ number: 1, remainingBalance: 60 });
  });

  it('calculateRevenue: unpaid = soma do saldo de cada OS confirmada', () => {
    const revenue = calculateRevenue([
      { status: 'done', total: 90, discount: 10, paidAmount: 30 },
      { status: 'approved', total: 50, discount: 0, paidAmount: 60 },
      { status: 'quote', total: 1000, discount: 0, paidAmount: 0 },
    ] as Order[]);

    expect(revenue).toEqual({ total: 140, paid: 90, unpaid: 60, discount: 10 });
  });
});
```

- [ ] **Step 3: Rodar e ver falhar**

```bash
cd firebase/functions && npx jest src/services/__tests__/order.service.test.ts src/services/__tests__/analytics.service.test.ts
```

Esperado: FAIL com erro de compilação do ts-jest — `Module '"../order.service"' has no exported member 'applyPaymentTransaction'` e `Module '"../analytics.service"' has no exported member 'calculateRevenue'`.

- [ ] **Step 4: Implementar**

Em `firebase/functions/src/models/types.ts`, linha 194, substituir:

```ts
export type PaymentStatus = 'unpaid' | 'partial' | 'paid';
```

por:

```ts
// Stored values only. 'partial' is computed in memory (app convention).
export type PaymentStatus = 'unpaid' | 'paid';
```

Em `firebase/functions/src/services/order.service.ts`, no import de `./firestore.service` (linhas 7-15) acrescentar `runTransaction`:

```ts
import {
  getTenantCollection,
  paginatedQuery,
  getDocument,
  createDocument,
  updateDocument,
  getNextOrderNumber,
  runTransaction,
  QueryFilter,
} from './firestore.service';
```

No import de `../models/types` (linhas 16-29) acrescentar `PaymentStatus` logo depois de `PaymentTransaction,`:

```ts
  PaymentTransaction,
  PaymentStatus,
  TransactionType,
```

Substituir o bloco inteiro de `addPayment` (comentário `/** Add a payment or discount to an order */` até o `}` que fecha a função, linhas 555-615) por:

```ts
/**
 * Round a money value to cents (avoids 0.1 + 0.2 style drift).
 */
export function roundMoney(value: number): number {
  return Math.round(value * 100) / 100;
}

/**
 * Apply a payment or discount transaction to an order (pure).
 * Same rules as the app (lib/utils/order_payment_math.dart):
 * - discount increases `discount` AND lowers `total` (total is net of discount);
 * - remaining balance = total - paidAmount;
 * - `payment` is stored only as 'paid' | 'unpaid'.
 */
export function applyPaymentTransaction(
  order: Pick<Order, 'total' | 'discount' | 'paidAmount' | 'transactions'>,
  transaction: PaymentTransaction
): {
  transactions: PaymentTransaction[];
  total: number;
  discount: number;
  paidAmount: number;
  paid: boolean;
  payment: PaymentStatus;
  remainingBalance: number;
} {
  let total = order.total || 0;
  let discount = order.discount || 0;
  let paidAmount = order.paidAmount || 0;

  if (transaction.type === 'payment') {
    paidAmount = roundMoney(paidAmount + transaction.amount);
  } else {
    discount = roundMoney(discount + transaction.amount);
    total = Math.max(0, roundMoney(total - transaction.amount));
  }

  const paid = total > 0 && paidAmount >= total;

  return {
    transactions: [...(order.transactions || []), transaction],
    total,
    discount,
    paidAmount,
    paid,
    payment: paid ? 'paid' : 'unpaid',
    remainingBalance: calculateRemainingBalance({ total, paidAmount }),
  };
}

/**
 * Add a payment or discount to an order (inside a Firestore transaction,
 * so it never races with the Asaas webhook).
 */
export async function addPayment(
  companyId: string,
  orderId: string,
  amount: number,
  type: TransactionType,
  description: string | undefined,
  createdBy: UserAggr
): Promise<{
  transactionId: string;
  paidAmount: number;
  remainingBalance: number;
  isFullyPaid: boolean;
} | null> {
  const orderRef = getTenantCollection(companyId, 'orders').doc(orderId);

  return runTransaction(async (tx) => {
    const snap = await tx.get(orderRef);
    if (!snap.exists) return null;

    const order = snap.data() as Order;

    const transaction: PaymentTransaction = {
      id: uuidv4(),
      type,
      amount,
      createdAt: new Date().toISOString(),
      createdBy,
      ...(description !== undefined ? { description } : {}),
    };

    const result = applyPaymentTransaction(order, transaction);

    tx.update(orderRef, {
      transactions: result.transactions,
      total: result.total,
      discount: result.discount,
      paidAmount: result.paidAmount,
      paid: result.paid,
      payment: result.payment,
      updatedBy: createdBy,
      updatedAt: new Date().toISOString(),
    });

    return {
      transactionId: transaction.id,
      paidAmount: result.paidAmount,
      remainingBalance: result.remainingBalance,
      isFullyPaid: result.paid,
    };
  });
}
```

Substituir `calculateRemainingBalance` (linhas 635-640) por:

```ts
/**
 * Calculate remaining balance. `total` is already net of discount,
 * so the discount must NOT be subtracted again.
 */
export function calculateRemainingBalance(order: Pick<Order, 'total' | 'paidAmount'>): number {
  return Math.max(0, roundMoney((order.total || 0) - (order.paidAmount || 0)));
}
```

Em `firebase/functions/src/services/analytics.service.ts`, logo abaixo de `import { getTenantCollection } from './firestore.service';` (linha 6), acrescentar:

```ts
import { calculateRemainingBalance, roundMoney } from './order.service';
```

Substituir a função `calculateRevenue` (linhas 133-157, do comentário `/** Calculate revenue metrics` até o `}`) por:

```ts
/**
 * Calculate revenue metrics
 * Only counts confirmed orders (excludes quote and canceled)
 */
export function calculateRevenue(orders: Order[]): RevenueMetrics {
  let total = 0;
  let paid = 0;
  let unpaid = 0;
  let discount = 0;

  for (const order of orders) {
    // Only count confirmed orders (exclude quote and canceled)
    if (order.status !== 'canceled' && order.status !== 'quote') {
      total += order.total || 0;
      paid += order.paidAmount || 0;
      discount += order.discount || 0;
      // order.total is already net of discount
      unpaid += calculateRemainingBalance(order);
    }
  }

  return {
    total: roundMoney(total),
    paid: roundMoney(paid),
    unpaid: roundMoney(unpaid),
    discount: roundMoney(discount),
  };
}
```

Na linha 278 (dentro de `getPendingItems`, bloco `// Unpaid`), substituir:

```ts
      const remaining = (order.total || 0) - (order.discount || 0) - (order.paidAmount || 0);
```

por:

```ts
      const remaining = calculateRemainingBalance(order);
```

- [ ] **Step 5: Rodar os testes e o lint**

```bash
cd firebase/functions && npx jest src/services/__tests__/order.service.test.ts src/services/__tests__/analytics.service.test.ts
npm run lint && npm run build && npm test
```

Esperado: PASS nos 2 arquivos novos (13 testes); lint sem erros; `tsc` sem erros; suíte completa verde (os testes de rotas mockam `order.service`/`analytics.service` e não dependem do cálculo antigo).

- [ ] **Step 6: Commit**

```bash
git add firebase/functions/src/models/types.ts \
  firebase/functions/src/services/order.service.ts \
  firebase/functions/src/services/analytics.service.ts \
  firebase/functions/src/services/__tests__/order.service.test.ts \
  firebase/functions/src/services/__tests__/analytics.service.test.ts
git commit -m "$(cat <<'EOF'
fix(payments): saldo da OS = total - paidAmount no servidor

O total da OS já é líquido de desconto; order.service e analytics
subtraíam o desconto de novo. addPayment agora roda em transação,
o desconto reduz o total (mesma regra do app) e payment é gravado
só como paid/unpaid.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task A2: Regras puras de pagamento no app (`OrderPaymentMath`)

**Files:**
- Create: `lib/utils/order_payment_math.dart`
- Test: `test/utils/order_payment_math_test.dart`

**Interfaces:**
- Consumes: `Order`, `OrderService`, `OrderProduct` (`lib/models/order.dart`), `PaymentTransaction`, `PaymentTransactionType` (`lib/models/payment_transaction.dart`).
- Produces: `OrderPaymentMath.paymentFields`, `stripPaymentFields(json)`, `paymentUpdateOf(order)`, `isAsaasTransaction(t)`, `sameTransaction(a, b)`, `computeTotal(order)`, `paymentStatusFor(...)`, `remainingBalance(order)`, `addPayment`, `addDiscount`, `markAsFullyPaid`, `removeTransaction`, `resetPayments`, `setReceipt`, `applyOrderStatus`; `AsaasTransactionLockedException`.

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/utils/order_payment_math_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/payment_transaction.dart';
import 'package:praticos/utils/order_payment_math.dart';

Order _order({
  double services = 100,
  double discount = 0,
  double paid = 0,
  List<PaymentTransaction>? transactions,
}) {
  final order = Order()
    ..id = 'o1'
    ..status = 'approved'
    ..services = [OrderService()..value = services]
    ..products = []
    ..discount = discount
    ..paidAmount = paid
    ..transactions = transactions ?? [];
  order.total = OrderPaymentMath.computeTotal(order);
  order.payment = 'unpaid';
  return order;
}

PaymentTransaction _payment(String id, double amount) => PaymentTransaction(
      id: id,
      type: PaymentTransactionType.payment,
      amount: amount,
      createdAt: DateTime(2026, 10, 4),
    );

PaymentTransaction _discount(String id, double amount) => PaymentTransaction(
      id: id,
      type: PaymentTransactionType.discount,
      amount: amount,
      createdAt: DateTime(2026, 10, 4),
    );

void main() {
  group('stripPaymentFields', () {
    test('remove os campos de pagamento e mantém o resto', () {
      final json = _order(paid: 10, transactions: [_payment('p1', 10)]).toJson();

      final stripped = OrderPaymentMath.stripPaymentFields(json);

      for (final field in ['transactions', 'paidAmount', 'paid', 'payment']) {
        expect(stripped.containsKey(field), isFalse, reason: field);
      }
      expect(stripped['total'], 100);
      expect(stripped['discount'], 0);
      expect(stripped['status'], 'approved');
      expect(json.containsKey('transactions'), isTrue, reason: 'não altera o map original');
    });
  });

  group('paymentUpdateOf', () {
    test('contém só campos de pagamento, desconto, total e auditoria', () {
      final order = OrderPaymentMath.addPayment(_order(), _payment('p1', 40));
      order.updatedAt = DateTime(2026, 10, 4, 12);

      final update = OrderPaymentMath.paymentUpdateOf(order);

      expect(update.keys.toSet(), {
        'transactions',
        'paidAmount',
        'paid',
        'payment',
        'discount',
        'total',
        'updatedAt',
      });
      expect((update['transactions'] as List).single['id'], 'p1');
      expect(update['paidAmount'], 40);
      expect(update['payment'], 'unpaid');
    });
  });

  group('addPayment', () {
    test('pagamento parcial fica unpaid', () {
      final order = OrderPaymentMath.addPayment(_order(), _payment('p1', 40));

      expect(order.paidAmount, 40);
      expect(order.payment, 'unpaid');
      expect(order.paid, isFalse);
      expect(OrderPaymentMath.remainingBalance(order), 60);
    });

    test('pagamento que quita fica paid', () {
      final order = OrderPaymentMath.addPayment(_order(paid: 60), _payment('p1', 40));

      expect(order.payment, 'paid');
      expect(order.paid, isTrue);
      expect(OrderPaymentMath.remainingBalance(order), 0);
    });

    test('arredonda para centavos', () {
      final order = Order()
        ..total = 0.3
        ..paidAmount = 0.1
        ..transactions = [];

      OrderPaymentMath.addPayment(order, _payment('p1', 0.2));

      expect(order.paidAmount, 0.3);
      expect(order.payment, 'paid');
    });
  });

  group('addDiscount', () {
    test('desconto reduz o total (total líquido)', () {
      final order = OrderPaymentMath.addDiscount(_order(paid: 50), _discount('d1', 10));

      expect(order.discount, 10);
      expect(order.total, 90);
      expect(OrderPaymentMath.remainingBalance(order), 40);
      expect(order.payment, 'unpaid');
    });

    test('desconto que cobre o saldo marca paid', () {
      final order = OrderPaymentMath.addDiscount(_order(paid: 90), _discount('d1', 10));

      expect(order.payment, 'paid');
    });
  });

  group('markAsFullyPaid', () {
    test('lança o saldo restante como pagamento', () {
      final order = OrderPaymentMath.markAsFullyPaid(
        _order(paid: 30),
        (remaining) => _payment('full', remaining),
      );

      expect(order.transactions!.last.amount, 70);
      expect(order.paidAmount, 100);
      expect(order.payment, 'paid');
      expect(order.paid, isTrue);
    });

    test('sem saldo não cria transação', () {
      final order = OrderPaymentMath.markAsFullyPaid(
        _order(paid: 100),
        (remaining) => _payment('full', remaining),
      );

      expect(order.transactions, isEmpty);
      expect(order.payment, 'paid');
    });
  });

  group('removeTransaction', () {
    test('remover pagamento reduz paidAmount', () {
      final p1 = _payment('p1', 100);
      final order = OrderPaymentMath.removeTransaction(
        _order(paid: 100, transactions: [p1])..payment = 'paid',
        p1,
      );

      expect(order.transactions, isEmpty);
      expect(order.paidAmount, 0);
      expect(order.payment, 'unpaid');
    });

    test('remover desconto devolve o total', () {
      final d1 = _discount('d1', 10);
      final order = OrderPaymentMath.removeTransaction(
        _order(discount: 10, transactions: [d1]),
        d1,
      );

      expect(order.discount, 0);
      expect(order.total, 100);
    });

    test('casa pelo id mesmo com transações novas no servidor', () {
      final local = _payment('p1', 20);
      final fresh = _order(paid: 50, transactions: [
        _payment('asaas_pay_1', 30),
        _payment('p1', 20),
      ]);

      final order = OrderPaymentMath.removeTransaction(fresh, local);

      expect(order.transactions!.map((t) => t.id), ['asaas_pay_1']);
      expect(order.paidAmount, 30);
    });

    test('transação do Asaas não pode ser removida', () {
      final asaas = _payment('asaas_pay_1', 30);

      expect(
        () => OrderPaymentMath.removeTransaction(
          _order(paid: 30, transactions: [asaas]),
          asaas,
        ),
        throwsA(isA<AsaasTransactionLockedException>()),
      );
    });

    test('transação sem id casa por tipo, valor e data', () {
      final legacy = PaymentTransaction(
        type: PaymentTransactionType.discount,
        amount: 5,
        createdAt: DateTime(2026, 1, 1),
      );
      final copy = PaymentTransaction.fromJson(legacy.toJson());

      final order = OrderPaymentMath.removeTransaction(
        _order(discount: 5, transactions: [copy]),
        legacy,
      );

      expect(order.transactions, isEmpty);
    });
  });

  group('resetPayments', () {
    test('zera pagamentos manuais e mantém os do Asaas', () {
      final order = OrderPaymentMath.resetPayments(_order(
        discount: 10,
        paid: 50,
        transactions: [
          _payment('p1', 20),
          _discount('d1', 10),
          _payment('asaas_pay_1', 30),
        ],
      ));

      expect(order.transactions!.map((t) => t.id), ['asaas_pay_1']);
      expect(order.paidAmount, 30);
      expect(order.discount, 0);
      expect(order.total, 100);
      expect(order.payment, 'unpaid');
    });
  });

  group('setReceipt', () {
    test('liga e desliga o comprovante da transação', () {
      final p1 = _payment('p1', 10);
      final fresh = _order(paid: 10, transactions: [_payment('p1', 10)]);

      OrderPaymentMath.setReceipt(fresh, p1, 'doc1');
      expect(fresh.transactions!.single.receiptDocumentId, 'doc1');

      OrderPaymentMath.setReceipt(fresh, p1, null);
      expect(fresh.transactions!.single.receiptDocumentId, isNull);
    });
  });

  group('applyOrderStatus', () {
    test('orçamento e cancelada ficam sem payment', () {
      expect(OrderPaymentMath.applyOrderStatus(_order(), 'quote').payment, isNull);
      expect(OrderPaymentMath.applyOrderStatus(_order(), 'canceled').payment, isNull);
    });

    test('ao sair de orçamento recalcula a partir dos valores', () {
      final fresh = _order(paid: 100)..payment = null;

      expect(OrderPaymentMath.applyOrderStatus(fresh, 'approved').payment, 'paid');
    });
  });

  test('remainingBalance nunca é negativo', () {
    expect(OrderPaymentMath.remainingBalance(_order(paid: 150)), 0);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
fvm flutter test test/utils/order_payment_math_test.dart
```

Esperado: FAIL na compilação — `Error: Error when reading 'lib/utils/order_payment_math.dart': No such file or directory`.

- [ ] **Step 3: Implementar**

Criar `lib/utils/order_payment_math.dart`:

```dart
import 'package:praticos/models/order.dart';
import 'package:praticos/models/payment_transaction.dart';

/// Thrown when someone tries to remove a payment created by the Asaas
/// integration. Those can only be undone by refunding the charge in Asaas.
class AsaasTransactionLockedException implements Exception {
  final String transactionId;

  const AsaasTransactionLockedException(this.transactionId);

  @override
  String toString() => 'AsaasTransactionLockedException($transactionId)';
}

/// Pure payment rules for an [Order].
///
/// Used inside Firestore transactions (TenantOrderRepository.updatePayments):
/// every function mutates and returns the `fresh` order it receives and never
/// reads global state. Same rules as the server (order.service.ts):
/// - `total` is net of discount (items - discount);
/// - remaining balance = total - paidAmount;
/// - `payment` is stored only as 'paid' | 'unpaid' ('partial' is in memory).
class OrderPaymentMath {
  OrderPaymentMath._();

  static const String asaasTransactionPrefix = 'asaas_';

  /// Fields owned by the payment flow. A full-order save must never write
  /// them, otherwise it overwrites payments written by the server.
  static const List<String> paymentFields = [
    'transactions',
    'paidAmount',
    'paid',
    'payment',
  ];

  static double roundMoney(double value) =>
      (value * 100).roundToDouble() / 100;

  /// Copy of [json] without [paymentFields].
  static Map<String, dynamic> stripPaymentFields(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);
    for (final field in paymentFields) {
      copy.remove(field);
    }
    return copy;
  }

  /// Map written by updatePayments: payment fields, discount and total
  /// (a discount transaction changes both) and the audit fields.
  static Map<String, dynamic> paymentUpdateOf(Order order) {
    final json = order.toJson();
    return {
      'transactions': json['transactions'] ?? <Map<String, dynamic>>[],
      'paidAmount': order.paidAmount ?? 0.0,
      'paid': order.paid ?? false,
      'payment': order.payment,
      'discount': order.discount ?? 0.0,
      'total': order.total ?? 0.0,
      if (json['updatedAt'] != null) 'updatedAt': json['updatedAt'],
      if (json['updatedBy'] != null) 'updatedBy': json['updatedBy'],
    };
  }

  static bool isAsaasTransaction(PaymentTransaction transaction) =>
      transaction.id?.startsWith(asaasTransactionPrefix) ?? false;

  /// Same transaction? By id when both have one; legacy transactions
  /// (no id) match by type, amount and creation date.
  static bool sameTransaction(PaymentTransaction a, PaymentTransaction b) {
    if (a.id != null && b.id != null) return a.id == b.id;
    return a.type == b.type &&
        a.amount == b.amount &&
        a.createdAt.toIso8601String() == b.createdAt.toIso8601String();
  }

  static double _itemsTotal(Order order) {
    double sum = 0.0;
    for (final service in order.services ?? const <OrderService>[]) {
      sum += service.value ?? 0.0;
    }
    for (final product in order.products ?? const <OrderProduct>[]) {
      sum += product.total ?? 0.0;
    }
    return sum;
  }

  /// total = services + products - discount (same rule as OrderStore.updateTotal).
  static double computeTotal(Order order) =>
      roundMoney(_itemsTotal(order) - (order.discount ?? 0.0));

  static String paymentStatusFor({
    required double total,
    required double paidAmount,
  }) =>
      (total > 0 && roundMoney(paidAmount) >= roundMoney(total))
          ? 'paid'
          : 'unpaid';

  static double remainingBalance(Order order) {
    final remaining =
        roundMoney((order.total ?? 0.0) - (order.paidAmount ?? 0.0));
    return remaining > 0 ? remaining : 0.0;
  }

  static Order _refreshStatus(Order order) {
    order.payment = paymentStatusFor(
      total: order.total ?? 0.0,
      paidAmount: order.paidAmount ?? 0.0,
    );
    order.paid = order.payment == 'paid';
    return order;
  }

  static Order addPayment(Order fresh, PaymentTransaction transaction) {
    fresh.transactions = [...?fresh.transactions, transaction];
    fresh.paidAmount =
        roundMoney((fresh.paidAmount ?? 0.0) + transaction.amount);
    return _refreshStatus(fresh);
  }

  static Order addDiscount(Order fresh, PaymentTransaction transaction) {
    fresh.transactions = [...?fresh.transactions, transaction];
    fresh.discount = roundMoney((fresh.discount ?? 0.0) + transaction.amount);
    fresh.total = computeTotal(fresh);
    return _refreshStatus(fresh);
  }

  /// Adds the remaining balance as a payment (when > 0) and forces 'paid'.
  static Order markAsFullyPaid(
    Order fresh,
    PaymentTransaction Function(double remaining) buildPayment,
  ) {
    final remaining = remainingBalance(fresh);
    if (remaining > 0) {
      addPayment(fresh, buildPayment(remaining));
    }
    fresh.payment = 'paid';
    fresh.paid = true;
    return fresh;
  }

  /// Removes [target] from the fresh order. Asaas transactions are locked.
  static Order removeTransaction(Order fresh, PaymentTransaction target) {
    if (isAsaasTransaction(target)) {
      throw AsaasTransactionLockedException(target.id!);
    }
    final list = [...?fresh.transactions];
    final index = list.indexWhere((t) => sameTransaction(t, target));
    if (index < 0) return fresh;

    final removed = list.removeAt(index);
    fresh.transactions = list;

    if (removed.type == PaymentTransactionType.payment) {
      final paid = roundMoney((fresh.paidAmount ?? 0.0) - removed.amount);
      fresh.paidAmount = paid < 0 ? 0.0 : paid;
    } else {
      final discount = roundMoney((fresh.discount ?? 0.0) - removed.amount);
      fresh.discount = discount < 0 ? 0.0 : discount;
      fresh.total = computeTotal(fresh);
    }
    return _refreshStatus(fresh);
  }

  /// Removes every manual transaction and discount. Asaas payments stay.
  static Order resetPayments(Order fresh) {
    final kept = (fresh.transactions ?? const <PaymentTransaction>[])
        .where(isAsaasTransaction)
        .toList();
    fresh.transactions = kept;
    fresh.paidAmount = roundMoney(kept
        .where((t) => t.type == PaymentTransactionType.payment)
        .fold<double>(0.0, (sum, t) => sum + t.amount));
    fresh.discount = 0.0;
    fresh.total = computeTotal(fresh);
    return _refreshStatus(fresh);
  }

  static Order setReceipt(
    Order fresh,
    PaymentTransaction target,
    String? receiptDocumentId,
  ) {
    for (final transaction in fresh.transactions ?? const <PaymentTransaction>[]) {
      if (sameTransaction(transaction, target)) {
        transaction.receiptDocumentId = receiptDocumentId;
      }
    }
    return fresh;
  }

  /// Payment status driven by the order status: quotes and canceled orders
  /// have no payment status; otherwise keep it (or compute when missing).
  static Order applyOrderStatus(Order fresh, String? orderStatus) {
    if (orderStatus == 'quote' || orderStatus == 'canceled') {
      fresh.payment = null;
      return fresh;
    }
    if (fresh.payment == null) return _refreshStatus(fresh);
    return fresh;
  }
}
```

- [ ] **Step 4: Rodar os testes**

```bash
fvm flutter test test/utils/order_payment_math_test.dart
fvm flutter analyze lib/utils/order_payment_math.dart test/utils/order_payment_math_test.dart
```

Esperado: PASS (todos os testes); analyze sem issues.

- [ ] **Step 5: Commit**

```bash
git add lib/utils/order_payment_math.dart test/utils/order_payment_math_test.dart
git commit -m "$(cat <<'EOF'
feat(payments): regras puras de pagamento da OS no app

OrderPaymentMath concentra soma de pagamentos, desconto líquido no
total, status paid/unpaid, remoção por id e bloqueio de transações
asaas_*, para serem usadas dentro de transações do Firestore.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task A3: `TenantOrderRepository` sem sobrescrever pagamentos + `updatePayments` com `runTransaction`

**Files:**
- Modify: `lib/repositories/tenant_repository.dart:36-39` (expor collection e Firestore para subclasses)
- Modify: `lib/repositories/tenant/tenant_order_repository.dart:1-18` (imports + overrides + `updatePayments`)
- Modify: `lib/repositories/v2/order_repository_v2.dart:66` (delegação `updatePayments`)
- Test: coberto por `test/utils/order_payment_math_test.dart` (Task A2). Não há teste unitário direto: o projeto não tem `fake_cloud_firestore` e `TenantRepository` instancia `FirebaseFirestore.instance` no construtor, o que exige Firebase inicializado.

**Interfaces:**
- Consumes: `OrderPaymentMath.stripPaymentFields`, `OrderPaymentMath.paymentUpdateOf` (Task A2).
- Produces: `TenantOrderRepository.createItem` (remove `transactions`, `paidAmount`, `paid`, `payment` quando a OS já existe), `TenantOrderRepository.updateItem` (sempre remove), `Future<Order?> updatePayments(String companyId, String orderId, Order Function(Order fresh) mutate)` em `TenantOrderRepository` e `OrderRepositoryV2`.

- [ ] **Step 1: Expor a collection no `TenantRepository`**

Em `lib/repositories/tenant_repository.dart`, logo depois do método `_getCollection` (fecha na linha 39), inserir:

```dart

  /// Collection reference for subclasses that need custom writes
  /// (e.g. TenantOrderRepository.updatePayments).
  CollectionReference<Map<String, dynamic>> collectionFor(String companyId) =>
      _getCollection(companyId);

  /// Firestore instance used by this repository.
  FirebaseFirestore get firestore => _db;
```

- [ ] **Step 2: Overrides e `updatePayments` no `TenantOrderRepository`**

Em `lib/repositories/tenant/tenant_order_repository.dart`, substituir os imports (linhas 1-3) por:

```dart
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:praticos/models/order.dart';
import 'package:praticos/repositories/tenant_repository.dart';
import 'package:praticos/repositories/repository.dart';
import 'package:praticos/utils/order_payment_math.dart';
```

Logo depois do override `toJson` (linha 18, `Map<String, dynamic> toJson(Order? order) => order!.toJson();`), inserir:

```dart

  // ═══════════════════════════════════════════════════════════════════
  // Payments-safe writes
  // ═══════════════════════════════════════════════════════════════════
  //
  // Payments (transactions, paidAmount, paid, payment) are written only by
  // updatePayments (app) or by the server (Asaas webhook). Full-order saves
  // must not send them, or they would overwrite payments made elsewhere.

  /// Creates a new order with all fields. When the order already exists,
  /// saves it without the payment fields.
  @override
  Future<void> createItem(String companyId, Order? item, {String? id}) async {
    final docId = item?.id ?? id;
    if (item != null && docId != null) {
      final ref = collectionFor(companyId).doc(docId);
      if (await _exists(ref)) {
        final json = OrderPaymentMath.stripPaymentFields(toJson(item));
        json.remove('number');
        await ref.set(json, SetOptions(merge: true));
        item.id = docId;
        return;
      }
    }
    await super.createItem(companyId, item, id: id);
  }

  /// Saves an existing order without the payment fields.
  @override
  Future<void> updateItem(String companyId, Order? item) {
    final json = OrderPaymentMath.stripPaymentFields(toJson(item));
    return collectionFor(companyId)
        .doc(item?.id)
        .set(json, SetOptions(merge: true));
  }

  /// Offline without cache, `get()` throws: treat as a new order (full write).
  Future<bool> _exists(DocumentReference<Map<String, dynamic>> ref) async {
    try {
      return (await ref.get()).exists;
    } on FirebaseException {
      return false;
    }
  }

  /// Reads the order inside a Firestore transaction, applies [mutate] to the
  /// fresh copy and writes only payment fields, discount, total and audit.
  /// Returns the updated order, or null when it does not exist.
  /// Errors thrown by [mutate] (e.g. AsaasTransactionLockedException) propagate.
  Future<Order?> updatePayments(
    String companyId,
    String orderId,
    Order Function(Order fresh) mutate,
  ) {
    final ref = collectionFor(companyId).doc(orderId);
    return firestore.runTransaction<Order?>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return null;
      final fresh = fromJson({...snap.data()!, 'id': snap.id});
      final updated = mutate(fresh);
      tx.update(ref, OrderPaymentMath.paymentUpdateOf(updated));
      return updated;
    });
  }
```

- [ ] **Step 3: Delegação no `OrderRepositoryV2`**

Em `lib/repositories/v2/order_repository_v2.dart`, depois do método `streamOrders` (fecha na linha 66) e antes do bloco `// Ratings Support`, inserir:

```dart

  /// Atualiza só os pagamentos da OS dentro de uma transação do Firestore.
  /// Ver [TenantOrderRepository.updatePayments].
  Future<Order?> updatePayments(
    String companyId,
    String orderId,
    Order Function(Order fresh) mutate,
  ) =>
      _tenant.updatePayments(companyId, orderId, mutate);
```

- [ ] **Step 4: Verificar**

```bash
fvm flutter analyze lib/repositories
fvm flutter test
```

Esperado: analyze sem issues; suíte completa verde.

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/tenant_repository.dart \
  lib/repositories/tenant/tenant_order_repository.dart \
  lib/repositories/v2/order_repository_v2.dart
git commit -m "$(cat <<'EOF'
fix(orders): salvar a OS não sobrescreve mais os pagamentos

createItem/updateItem de OS existente deixam de enviar transactions,
paidAmount, paid e payment. Novo updatePayments grava só esses campos
(mais discount/total) dentro de runTransaction.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task A4: `OrderStore` e tela de pagamentos usando `updatePayments` (+ bloqueio de `asaas_*`)

**Files:**
- Modify: `lib/mobx/order_store.dart` — import (linha 12), `setStatus` (720-727), `deleteDocument` (1170-1204), bloco de comprovantes/pagamentos (1206-1495: `attachReceiptToTransaction`, `removeReceiptFromTransaction`, `addPayment`, `addDiscountTransaction`, `markAsFullyPaid`, `_updatePaymentStatus`, `removeTransaction`, `resetAllPayments`); `updatePayment` (756-777) só ganha comentário
- Regenerate: `lib/mobx/order_store.g.dart`
- Modify: `lib/screens/payment_management_screen.dart` — import, `_registerTransaction` (845-889), `_resetPayment` (921-926), `_confirmDeleteTransaction` (929-957)
- Modify: `lib/l10n/app_pt.arb:110`, `lib/l10n/app_en.arb:107`, `lib/l10n/app_es.arb:107` (+ arquivos gerados `lib/l10n/app_localizations*.dart`)
- Modify: `docs/FINANCEIRO.md` (seção "Métodos do OrderStore" e nova seção antes de "## Changelog")
- Test: regras cobertas por `test/utils/order_payment_math_test.dart`; o `OrderStore` depende de Firebase e não tem teste unitário. Verificação: `analyze` + suíte + roteiro manual no simulador (Step 7).

**Interfaces:**
- Consumes: `OrderRepositoryV2.updatePayments` (Task A3), `OrderPaymentMath.*` e `AsaasTransactionLockedException` (Task A2).
- Produces: `Future<PaymentTransaction?> addPayment(double amount, {String? description})`, `Future<bool> addDiscountTransaction(double amount, {String? description})`, `Future<bool> markAsFullyPaid({String? description})`, `Future<bool> removeTransaction(int index)`, `Future<bool> resetAllPayments()`; l10n `asaasTransactionCannotBeRemoved`, `paymentUpdateFailed`.

- [ ] **Step 1: Strings l10n**

Em `lib/l10n/app_pt.arb`, logo depois de `"discountApplied": "Desconto aplicado",` (linha 110), inserir:

```json
  "asaasTransactionCannotBeRemoved": "Pagamentos recebidos pelo Asaas não podem ser removidos aqui. Para desfazer, estorne a cobrança no Asaas.",
  "paymentUpdateFailed": "Não foi possível salvar o pagamento. Verifique sua conexão e tente novamente.",
```

Em `lib/l10n/app_en.arb`, depois de `"discountApplied": "Discount applied",` (linha 107):

```json
  "asaasTransactionCannotBeRemoved": "Payments received through Asaas can't be removed here. To undo one, refund the charge in Asaas.",
  "paymentUpdateFailed": "Couldn't save the payment. Check your connection and try again.",
```

Em `lib/l10n/app_es.arb`, depois de `"discountApplied": "Descuento aplicado",` (linha 107):

```json
  "asaasTransactionCannotBeRemoved": "Los pagos recibidos por Asaas no se pueden eliminar aquí. Para deshacerlo, reembolsa el cobro en Asaas.",
  "paymentUpdateFailed": "No se pudo guardar el pago. Verifica tu conexión e inténtalo de nuevo.",
```

Gerar:

```bash
fvm flutter gen-l10n
```

Esperado: sem erros; `lib/l10n/app_localizations.dart` passa a ter `asaasTransactionCannotBeRemoved` e `paymentUpdateFailed`.

- [ ] **Step 2: Import e `setStatus` no `OrderStore`**

Em `lib/mobx/order_store.dart`, depois de `import 'package:praticos/models/payment_transaction.dart';` (linha 12), inserir:

```dart
import 'package:praticos/utils/order_payment_math.dart';
```

Substituir `setStatus` (linhas 720-727) por:

```dart
  @action
  setStatus(String? status) {
    if (status == null) return;
    final previousPayment = order!.payment;
    order!.status = status;
    this.status = status;
    updatePayment();
    createItem();
    // createItem no longer writes `payment`: persist the status-driven change
    // (quote/canceled → null, back to active → recomputed) through updatePayments.
    if (order!.id != null && order!.payment != previousPayment) {
      _runPaymentUpdate(
        (fresh) => OrderPaymentMath.applyOrderStatus(fresh, status),
      );
    }
  }
```

Acima de `void updatePayment() {` (linha 756) acrescentar o comentário:

```dart
  /// Computes the payment label shown in the UI (display only).
  /// Persistence of payment fields happens only through updatePayments.
```

- [ ] **Step 3: `deleteDocument` sem gravar transações via `createItem`**

Em `deleteDocument`, substituir o trecho que vai de `// If this document is a receipt linked to a transaction, clear the reference` até `return true;` (linhas 1185-1203) por:

```dart
    order!.documents!.removeAt(index);
    documents.removeAt(index);
    createItem();

    // If this document is a receipt linked to a transaction, clear the reference
    final linkedId = doc.linkedTransactionId;
    if (linkedId != null) {
      final linked = (order!.transactions ?? const <PaymentTransaction>[])
          .where((t) => t.id == linkedId)
          .toList();
      if (linked.isNotEmpty) {
        await _runPaymentUpdate(
          (fresh) => OrderPaymentMath.setReceipt(fresh, linked.first, null),
        );
      }
    }
    return true;
```

- [ ] **Step 4: Reescrever comprovantes e pagamentos**

Substituir o trecho que começa em `/// Attaches a receipt to a payment transaction as an OrderDocument` (linha 1210) e termina no `}` que fecha `resetAllPayments` (linha 1495, imediatamente antes de `updateTotal() {`) por:

```dart
  /// Attaches a receipt to a payment transaction as an OrderDocument
  @action
  Future<bool> attachReceiptToTransaction(int index, File file,
      String contentType, String fileName) async {
    if (order == null ||
        companyId == null ||
        order!.id == null ||
        order!.company?.id == null ||
        order!.transactions == null ||
        index >= order!.transactions!.length) {
      return false;
    }

    final transaction = order!.transactions![index];

    isUploadingDocument = true;

    try {
      final doc = await photoService.uploadOrderDocument(
        file: file,
        companyId: order!.company!.id!,
        orderId: order!.id!,
        contentType: contentType,
        fileName: fileName,
      );

      isUploadingDocument = false;
      if (doc == null) return false;

      doc.type = OrderDocumentType.receipt;
      doc.linkedTransactionId = transaction.id;

      // Documents are persisted by the regular order save
      order!.documents ??= [];
      order!.documents!.add(doc);
      documents.add(doc);
      createItem();

      // Transactions are persisted only through updatePayments
      return _runPaymentUpdate(
        (fresh) => OrderPaymentMath.setReceipt(fresh, transaction, doc.id),
      );
    } catch (e) {
      isUploadingDocument = false;
      print('Erro no upload do comprovante: $e');
      return false;
    }
  }

  /// Removes a receipt from a payment transaction
  @action
  Future<bool> removeReceiptFromTransaction(int index) async {
    if (order == null ||
        order!.transactions == null ||
        index >= order!.transactions!.length) {
      return false;
    }

    final transaction = order!.transactions![index];
    final docId = transaction.receiptDocumentId;
    if (docId == null) return false;

    final ok = await _runPaymentUpdate(
      (fresh) => OrderPaymentMath.setReceipt(fresh, transaction, null),
    );
    if (!ok) return false;

    await _deleteOrderDocumentById(docId);
    createItem();
    return true;
  }

  /// Deletes an OrderDocument from storage and from the local lists.
  /// The caller persists the documents list with createItem().
  Future<void> _deleteOrderDocumentById(String docId) async {
    final docIndex = order!.documents?.indexWhere((d) => d.id == docId) ?? -1;
    if (docIndex < 0) return;
    final doc = order!.documents![docIndex];
    if (doc.storagePath != null) {
      await photoService.deletePhoto(doc.storagePath!);
    }
    order!.documents!.removeAt(docIndex);
    documents.removeWhere((d) => d.id == docId);
  }

  @action
  setDiscount(double value) {
    order!.discount = value;
    discount = value;
    updateTotal();
    createItem();
  }

  // ============================================================
  // PAYMENTS (written only through updatePayments / runTransaction)
  // ============================================================

  String _newTransactionId() =>
      DateTime.now().millisecondsSinceEpoch.toString();

  /// Runs [mutate] on the fresh order inside a Firestore transaction and
  /// refreshes the local state from the result. Returns false when it can't
  /// be saved (transactions need the server, so this fails offline).
  Future<bool> _runPaymentUpdate(Order Function(Order fresh) mutate) async {
    if (order == null || companyId == null) return false;
    try {
      if (order!.id == null) {
        // New order not saved yet: save it before touching payments
        await repository.createItem(companyId!, order);
      }
      final userAggr = Global.userAggr;
      final fresh = await repository.updatePayments(
        companyId!,
        order!.id!,
        (current) {
          current.updatedAt = DateTime.now();
          current.updatedBy = userAggr;
          return mutate(current);
        },
      );
      if (fresh == null) return false;
      _applyPaymentState(fresh);
      return true;
    } on AsaasTransactionLockedException {
      return false;
    } catch (e) {
      print('[OrderStore] Failed to update payments: $e');
      return false;
    }
  }

  /// Copies the payment fields of [fresh] into the local order and observables.
  void _applyPaymentState(Order fresh) {
    runInAction(() {
      if (order == null) return;
      order!.transactions = fresh.transactions ?? [];
      order!.paidAmount = fresh.paidAmount ?? 0.0;
      order!.paid = fresh.paid;
      order!.payment = fresh.payment;
      order!.discount = fresh.discount ?? 0.0;
      transactions = ObservableList<PaymentTransaction>.of(order!.transactions!);
      paidAmount = order!.paidAmount;
      updateTotal();
      updatePayment();
    });
  }

  /// Adiciona um pagamento parcial. Retorna a transação criada, ou null se
  /// não foi possível salvar.
  @action
  Future<PaymentTransaction?> addPayment(double amount,
      {String? description}) async {
    if (order == null || amount <= 0) return null;

    final transaction = PaymentTransaction.payment(
      amount: amount,
      description: description,
      createdBy: Global.userAggr,
    );
    transaction.id = _newTransactionId();

    final ok = await _runPaymentUpdate(
      (fresh) => OrderPaymentMath.addPayment(fresh, transaction),
    );
    if (!ok) return null;

    AnalyticsService.instance.logPaymentAdded(amount: amount);
    return transaction;
  }

  /// Adiciona um desconto como transação (reduz o total da OS)
  @action
  Future<bool> addDiscountTransaction(double amount,
      {String? description}) async {
    if (order == null || amount <= 0) return false;

    final transaction = PaymentTransaction.discount(
      amount: amount,
      description: description,
      createdBy: Global.userAggr,
    );
    transaction.id = _newTransactionId();

    return _runPaymentUpdate(
      (fresh) => OrderPaymentMath.addDiscount(fresh, transaction),
    );
  }

  /// Marca como totalmente pago (lança o saldo restante como pagamento)
  @action
  Future<bool> markAsFullyPaid({String? description}) async {
    if (order == null) return false;

    final transactionId = _newTransactionId();
    final createdBy = Global.userAggr;

    return _runPaymentUpdate(
      (fresh) => OrderPaymentMath.markAsFullyPaid(fresh, (remaining) {
        final transaction = PaymentTransaction.payment(
          amount: remaining,
          description: description ?? 'Pagamento total',
          createdBy: createdBy,
        );
        transaction.id = transactionId;
        return transaction;
      }),
    );
  }

  /// Remove uma transação pelo índice. Transações do Asaas (`asaas_*`) não
  /// podem ser removidas aqui: o estorno é feito no Asaas.
  @action
  Future<bool> removeTransaction(int index) async {
    if (order == null ||
        order!.transactions == null ||
        index >= order!.transactions!.length) {
      return false;
    }

    final transaction = order!.transactions![index];
    if (OrderPaymentMath.isAsaasTransaction(transaction)) return false;

    final ok = await _runPaymentUpdate(
      (fresh) => OrderPaymentMath.removeTransaction(fresh, transaction),
    );
    if (!ok) return false;

    // Delete the receipt only after the transaction is gone
    final receiptId = transaction.receiptDocumentId;
    if (receiptId != null) {
      await _deleteOrderDocumentById(receiptId);
      createItem();
    }
    return true;
  }

  /// Resets all manual payments and discounts (and their receipts).
  /// Payments received through Asaas are kept.
  @action
  Future<bool> resetAllPayments() async {
    if (order == null) return false;

    final removable = (order!.transactions ?? const <PaymentTransaction>[])
        .where((t) => !OrderPaymentMath.isAsaasTransaction(t))
        .toList();

    final ok = await _runPaymentUpdate(OrderPaymentMath.resetPayments);
    if (!ok) return false;

    var removedDocument = false;
    for (final transaction in removable) {
      final receiptId = transaction.receiptDocumentId;
      if (receiptId != null) {
        await _deleteOrderDocumentById(receiptId);
        removedDocument = true;
      }
    }
    if (removedDocument) createItem();
    return true;
  }
```

Regenerar o MobX:

```bash
fvm flutter pub run build_runner build --delete-conflicting-outputs
```

Esperado: `lib/mobx/order_store.g.dart` regenerado, com `addPayment`, `addDiscountTransaction`, `markAsFullyPaid` e `resetAllPayments` agora como `AsyncAction`.

- [ ] **Step 5: Tela de pagamentos**

Em `lib/screens/payment_management_screen.dart`, depois de `import 'package:praticos/services/photo_service.dart';` inserir:

```dart
import 'package:praticos/utils/order_payment_math.dart';
```

Substituir `_registerTransaction` (linhas 845-889) por:

```dart
  void _registerTransaction() async {
    final error = _validateValue(_valueController.text);
    if (error != null) {
      _showError(error);
      return;
    }

    final store = _store;
    if (store == null) return;

    final value = _parseValue(_valueController.text);
    final description = _descriptionController.text.isNotEmpty
        ? _descriptionController.text
        : null;
    final isPayment = _selectedType == 0;

    bool ok;
    if (isPayment) {
      final transaction =
          await store.addPayment(value, description: description);
      ok = transaction != null;

      // Upload receipt if one was attached
      if (transaction != null && _receiptFile != null) {
        final txnIndex =
            store.transactions.indexWhere((t) => t.id == transaction.id);
        if (txnIndex >= 0) {
          await store.attachReceiptToTransaction(
            txnIndex,
            _receiptFile!,
            _receiptContentType ?? 'application/octet-stream',
            _receiptFileName ?? 'receipt',
          );
        }
      }
    } else {
      ok = await store.addDiscountTransaction(value, description: description);
    }

    if (!mounted) return;
    if (!ok) {
      _showError(context.l10n.paymentUpdateFailed);
      return;
    }

    // Clear form and refill with new remaining balance
    _descriptionController.clear();
    setState(() {
      _receiptFile = null;
      _receiptContentType = null;
      _receiptFileName = null;
    });
    _prefillValue();

    // Show feedback
    _showSuccess(isPayment
        ? context.l10n.paymentRegistered
        : context.l10n.discountApplied);
  }
```

Substituir `_resetPayment` (linhas 921-926) por:

```dart
  void _resetPayment() async {
    final store = _store;
    if (store == null) return;
    final ok = await store.resetAllPayments();
    if (!mounted) return;
    if (!ok) {
      _showError(context.l10n.paymentUpdateFailed);
      return;
    }
    _prefillValue();
  }
```

Substituir `_confirmDeleteTransaction` (linhas 929-957) por:

```dart
  void _confirmDeleteTransaction(int index, PaymentTransaction transaction) {
    if (OrderPaymentMath.isAsaasTransaction(transaction)) {
      _showError(context.l10n.asaasTransactionCannotBeRemoved);
      return;
    }

    showCupertinoDialog(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text('${context.l10n.remove} ${transaction.typeLabel(context.l10n)}'),
        content: Text(
          context.l10n.confirmRemoveTransaction(
            transaction.typeLabel(context.l10n).toLowerCase(),
            FormatService().formatCurrency(transaction.amount),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text(context.l10n.cancel),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(dialogContext);
              final ok = await _store?.removeTransaction(index) ?? false;
              if (!mounted) return;
              if (!ok) {
                _showError(context.l10n.paymentUpdateFailed);
                return;
              }
              _prefillValue();
            },
            child: Text(context.l10n.remove),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 6: Documentação técnica (`docs/FINANCEIRO.md`)**

Na seção `### Métodos do OrderStore`, substituir o bloco de código por:

````markdown
```dart
// Registrar pagamento (retorna a transação ou null se não salvou)
Future<PaymentTransaction?> addPayment(double amount, {String? description})

// Registrar desconto (reduz o total da OS)
Future<bool> addDiscountTransaction(double amount, {String? description})

// Marcar como totalmente pago
Future<bool> markAsFullyPaid({String? description})

// Remover transação (transações asaas_* são bloqueadas)
Future<bool> removeTransaction(int index)

// Zerar pagamentos manuais (mantém os do Asaas)
Future<bool> resetAllPayments()
```
````

Logo antes de `## Changelog`, inserir:

```markdown
### Persistência dos pagamentos (Outubro 2026)

- Salvar a OS (`createItem`/`updateItem` do `TenantOrderRepository`) **não envia** `transactions`, `paidAmount`, `paid` nem `payment` quando a OS já existe. Isso evita que o app sobrescreva pagamentos lançados pelo servidor (webhook do Asaas, API, bot).
- Pagamentos, descontos, remoções e "zerar" usam `TenantOrderRepository.updatePayments(companyId, orderId, mutate)`, que lê a OS dentro de `runTransaction`, aplica as regras de `lib/utils/order_payment_math.dart` e grava só os campos de pagamento, `discount`, `total` e auditoria.
- Transações exigem conexão: sem internet o app mostra "Não foi possível salvar o pagamento".
- Saldo restante = `total - paidAmount` (o `total` já é líquido de desconto), no app e no servidor.
- Transações com id `asaas_*` são lançadas pelo servidor e não podem ser removidas no app (estornar no Asaas).
- Mudança de status para orçamento/cancelada grava `payment = null` via `updatePayments`.

---
```

- [ ] **Step 7: Verificar**

```bash
fvm flutter analyze
fvm flutter test
```

Esperado: analyze sem issues; suíte verde.

Roteiro manual (simulador iOS, conta de teste): abrir uma OS aprovada com total R$ 100 → Pagamentos → registrar R$ 40 (aparece "Parcial" e saldo R$ 60) → registrar desconto R$ 10 (total R$ 90, saldo R$ 50) → anexar comprovante em um novo pagamento de R$ 10 → remover o pagamento com comprovante (o documento some da OS) → "Marcar como a receber" zera tudo. No Firestore, conferir que editar um serviço da OS depois disso não altera `transactions`/`paidAmount`. Com o modo avião ligado, registrar pagamento mostra o erro `paymentUpdateFailed`.

- [ ] **Step 8: Commit**

```bash
git add lib/mobx/order_store.dart lib/mobx/order_store.g.dart \
  lib/screens/payment_management_screen.dart \
  lib/l10n/app_pt.arb lib/l10n/app_en.arb lib/l10n/app_es.arb \
  lib/l10n/app_localizations.dart lib/l10n/app_localizations_pt.dart \
  lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_es.dart \
  docs/FINANCEIRO.md
git commit -m "$(cat <<'EOF'
fix(payments): pagamentos da OS gravados em transação no app

addPayment, desconto, marcar como pago, remover e zerar pagamentos
passam por updatePayments (runTransaction) e atualizam o estado local
com a OS recém-lida. Transações asaas_* não podem ser removidas.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task A5: `X-Company-Id` nas chamadas do app (`appApiHeaders`)

**Files:**
- Create: `lib/services/api_headers.dart`
- Modify: `lib/services/integration_api_service.dart:1-6` (imports), `:35-39` (`_defaultTokenProvider`), `:69-78` (`_headers`)
- Test: `test/services/api_headers_test.dart` (novo), `test/services/integration_api_service_test.dart` (novos casos)

**Interfaces:**
- Consumes: `Global.companyAggr?.id` (`lib/global.dart`), `FirebaseAuth.instance.currentUser`.
- Produces: `Future<Map<String, String>> appApiHeaders({String? companyId, Future<String?> Function()? tokenProvider})`, `Future<String?> defaultIdTokenProvider()`, `AppApiUnauthenticatedException`. O `AsaasApiService` (Bloco D) usa o mesmo helper.

- [ ] **Step 1: Escrever os testes que falham**

Criar `test/services/api_headers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/company.dart';
import 'package:praticos/services/api_headers.dart';

void main() {
  group('appApiHeaders', () {
    tearDown(() => Global.companyAggr = null);

    test('inclui Authorization e X-Company-Id da empresa atual', () async {
      Global.companyAggr = CompanyAggr()..id = 'comp-42';

      final headers = await appApiHeaders(tokenProvider: () async => 'tok');

      expect(headers['Authorization'], 'Bearer tok');
      expect(headers['Content-Type'], 'application/json');
      expect(headers['X-Company-Id'], 'comp-42');
    });

    test('companyId explícito tem prioridade', () async {
      Global.companyAggr = CompanyAggr()..id = 'comp-42';

      final headers = await appApiHeaders(
        companyId: 'other',
        tokenProvider: () async => 'tok',
      );

      expect(headers['X-Company-Id'], 'other');
    });

    test('sem empresa selecionada não envia X-Company-Id', () async {
      final headers = await appApiHeaders(tokenProvider: () async => 'tok');

      expect(headers.containsKey('X-Company-Id'), isFalse);
    });

    test('sem token lança AppApiUnauthenticatedException', () async {
      expect(
        () => appApiHeaders(tokenProvider: () async => null),
        throwsA(isA<AppApiUnauthenticatedException>()),
      );
    });
  });
}
```

Em `test/services/integration_api_service_test.dart`, acrescentar aos imports:

```dart
import 'package:praticos/global.dart';
import 'package:praticos/models/company.dart';
```

e, dentro do `group('IntegrationApiService', () { ... })`, antes do `});` final do grupo, os casos:

```dart
    test('envia X-Company-Id da empresa atual', () async {
      Global.companyAggr = CompanyAggr()..id = 'comp-42';
      addTearDown(() => Global.companyAggr = null);

      final service = IntegrationApiService.withClient(
        MockClient((request) async {
          expect(request.headers['X-Company-Id'], 'comp-42');
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }),
        tokenProvider: () async => 'fake-id-token',
      );

      await service.list();
    });

    test('sem token lança exceção com code UNAUTHENTICATED', () async {
      final service = IntegrationApiService.withClient(
        MockClient((_) async => http.Response('{}', 200)),
        tokenProvider: () async => null,
      );

      expect(
        () => service.list(),
        throwsA(
          isA<IntegrationApiException>()
              .having((e) => e.code, 'code', 'UNAUTHENTICATED'),
        ),
      );
    });
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
fvm flutter test test/services/api_headers_test.dart test/services/integration_api_service_test.dart
```

Esperado: FAIL — `api_headers_test.dart` não compila (`Error when reading 'lib/services/api_headers.dart'`) e `envia X-Company-Id da empresa atual` falha com `Expected: 'comp-42' Actual: <null>`.

- [ ] **Step 3: Implementar**

Criar `lib/services/api_headers.dart`:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:praticos/global.dart';

/// Thrown when there is no signed-in user to authenticate an API call.
class AppApiUnauthenticatedException implements Exception {
  const AppApiUnauthenticatedException();

  @override
  String toString() => 'User not authenticated';
}

/// Firebase ID token of the signed-in user, or null.
Future<String?> defaultIdTokenProvider() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  return user.getIdToken();
}

/// Headers for calls to `/v1/app/*` on the Functions API.
///
/// Sends `X-Company-Id` (the selected company, or [companyId]) so users that
/// belong to several companies don't fall back to the first one on the server.
Future<Map<String, String>> appApiHeaders({
  String? companyId,
  Future<String?> Function()? tokenProvider,
}) async {
  final token = await (tokenProvider ?? defaultIdTokenProvider)();
  if (token == null || token.isEmpty) {
    throw const AppApiUnauthenticatedException();
  }
  final resolvedCompanyId = companyId ?? Global.companyAggr?.id;
  return {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
    if (resolvedCompanyId != null && resolvedCompanyId.isNotEmpty)
      'X-Company-Id': resolvedCompanyId,
  };
}
```

Em `lib/services/integration_api_service.dart`:

1. Substituir os imports (linhas 1-6) por:

```dart
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'package:praticos/models/integration_token.dart';
import 'package:praticos/services/api_headers.dart';
```

2. Em `static final IntegrationApiService instance = IntegrationApiService._(http.Client(), _defaultTokenProvider);` trocar `_defaultTokenProvider` por `defaultIdTokenProvider`, e apagar o método `static Future<String?> _defaultTokenProvider() async { ... }` (linhas 35-39).

3. Substituir `_headers()` (linhas 69-78) por:

```dart
  Future<Map<String, String>> _headers() async {
    try {
      return await appApiHeaders(tokenProvider: _tokenProvider);
    } on AppApiUnauthenticatedException {
      throw IntegrationApiException('User not authenticated',
          code: 'UNAUTHENTICATED');
    }
  }
```

- [ ] **Step 4: Rodar os testes**

```bash
fvm flutter test test/services/api_headers_test.dart test/services/integration_api_service_test.dart
fvm flutter analyze lib/services
```

Esperado: PASS em todos; analyze sem issues.

- [ ] **Step 5: Commit**

```bash
git add lib/services/api_headers.dart lib/services/integration_api_service.dart \
  test/services/api_headers_test.dart test/services/integration_api_service_test.dart
git commit -m "$(cat <<'EOF'
fix(api): app envia X-Company-Id nas chamadas às Functions

Sem o header, usuários de várias empresas caíam sempre na primeira.
appApiHeaders centraliza Authorization + X-Company-Id.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task A6: Permissões `chargeOrder` (app) e `manage:payments` (servidor)

**Files:**
- Modify: `lib/models/permission.dart:47` (enum), `:228` (`_adminPermissions`), `:265` (`_managerPermissions`)
- Modify: `lib/services/authorization_service.dart:415` (helper `canChargeOrder`)
- Modify: `firebase/functions/src/middleware/auth.middleware.ts:386-410` (`getRolePermissions`)
- Test: `test/models/permission_test.dart` (novo), `firebase/functions/src/middleware/__tests__/auth.middleware.test.ts` (novo)

**Interfaces:**
- Produces: `PermissionType.chargeOrder` (admin, manager; no app o dono é `admin`), `AuthorizationService.canChargeOrder`, permissão backend `manage:payments` (owner, admin, manager) usada pelas rotas dos Blocos B/C via `requirePermission('manage:payments')`.

- [ ] **Step 1: Escrever os testes que falham**

Criar `test/models/permission_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/models/user_role.dart';

void main() {
  group('PermissionType.chargeOrder', () {
    test('admin e gerente podem cobrar a OS', () {
      expect(
        RolePermissions.hasPermission(RolesType.admin, PermissionType.chargeOrder),
        isTrue,
      );
      expect(
        RolePermissions.hasPermission(RolesType.manager, PermissionType.chargeOrder),
        isTrue,
      );
    });

    test('supervisor, consultor e técnico não podem', () {
      for (final role in [
        RolesType.supervisor,
        RolesType.consultant,
        RolesType.technician,
      ]) {
        expect(
          RolePermissions.hasPermission(role, PermissionType.chargeOrder),
          isFalse,
          reason: role.name,
        );
      }
    });
  });
}
```

Criar `firebase/functions/src/middleware/__tests__/auth.middleware.test.ts`:

```ts
jest.mock('../../services/firestore.service', () => ({ db: {}, auth: {} }));

import { getRolePermissions, hasPermission } from '../auth.middleware';

describe('getRolePermissions — manage:payments', () => {
  it.each(['owner', 'admin', 'manager'])('%s pode gerenciar pagamentos', (role) => {
    const permissions = getRolePermissions(role);
    expect(permissions).toContain('manage:payments');
    expect(hasPermission({ permissions }, 'manage:payments')).toBe(true);
  });

  it.each(['supervisor', 'consultant', 'technician'])('%s não pode', (role) => {
    expect(hasPermission({ permissions: getRolePermissions(role) }, 'manage:payments')).toBe(false);
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
fvm flutter test test/models/permission_test.dart
cd firebase/functions && npx jest src/middleware/__tests__/auth.middleware.test.ts
```

Esperado: Flutter FAIL na compilação (`Member not found: 'chargeOrder'`); jest FAIL em 3 casos (`Expected value: "manage:payments"` não contido).

- [ ] **Step 3: Implementar**

Em `lib/models/permission.dart`, no enum, logo depois de `editPrices,` (linha 48), inserir:

```dart

  /// Gerar e cancelar cobranças (Asaas) a partir da OS
  chargeOrder,
```

No `_adminPermissions`, logo depois de `PermissionType.editPrices,` (linha 228), inserir `PermissionType.chargeOrder,`. No `_managerPermissions`, logo depois de `PermissionType.editPrices,` (linha 265), inserir `PermissionType.chargeOrder,`. Os dois blocos ficam assim no trecho de dados financeiros:

```dart
    // Dados Financeiros
    PermissionType.viewPrices,
    PermissionType.viewBilling,
    PermissionType.viewFinancialReports,
    PermissionType.editPrices,
    PermissionType.chargeOrder,
```

```dart
    // Dados Financeiros (acesso total)
    PermissionType.viewPrices,
    PermissionType.viewBilling,
    PermissionType.viewFinancialReports,
    PermissionType.editPrices,
    PermissionType.chargeOrder,
```

Em `lib/services/authorization_service.dart`, depois de `bool get canViewDashboard => hasPermission(PermissionType.viewDashboard);` (linha 415), inserir:

```dart

  /// Verifica se o usuário pode gerar/cancelar cobranças da OS (Asaas).
  bool get canChargeOrder => hasPermission(PermissionType.chargeOrder);
```

Em `firebase/functions/src/middleware/auth.middleware.ts`, em `getRolePermissions`, acrescentar `'manage:payments'` nos arrays `owner`, `admin` e `manager`:

```ts
    owner: [
      'read:all',
      'write:all',
      'delete:all',
      'manage:company',
      'manage:members',
      'manage:payments',
      'view:financial',
    ],
    admin: [
      'read:all',
      'write:all',
      'delete:all',
      'manage:members',
      'manage:payments',
      'view:financial',
    ],
```

```ts
    manager: [
      'read:all',
      'write:orders',
      'write:customers',
      'write:devices',
      'manage:payments',
      'view:financial',
    ],
```

- [ ] **Step 4: Rodar os testes**

```bash
fvm flutter test test/models/permission_test.dart && fvm flutter analyze lib/models lib/services
cd firebase/functions && npx jest src/middleware && npm run lint
```

Esperado: PASS (Flutter 2 testes; jest 6 casos + `company.middleware.test.ts` continua verde); lint sem erros.

- [ ] **Step 5: Commit**

```bash
git add lib/models/permission.dart lib/services/authorization_service.dart \
  test/models/permission_test.dart \
  firebase/functions/src/middleware/auth.middleware.ts \
  firebase/functions/src/middleware/__tests__/auth.middleware.test.ts
git commit -m "$(cat <<'EOF'
feat(auth): permissões chargeOrder (app) e manage:payments (API)

Dono, admin e gerente poderão gerar cobranças da OS.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task A7: Utilitário de CPF/CNPJ (`lib/utils/tax_id.dart`)

**Files:**
- Create: `lib/utils/tax_id.dart`
- Test: `test/utils/tax_id_test.dart`

**Interfaces:**
- Produces: `String onlyDigits(String)`, `bool isValidCpf(String)`, `bool isValidCnpj(String)`, `bool isValidTaxId(String)`, `String formatTaxId(String)` (usados no Bloco D: tela de cobrança e cadastro de cliente).

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/utils/tax_id_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/utils/tax_id.dart';

void main() {
  test('onlyDigits remove máscara', () {
    expect(onlyDigits('529.982.247-25'), '52998224725');
    expect(onlyDigits('11.222.333/0001-81'), '11222333000181');
    expect(onlyDigits(''), '');
  });

  group('CPF', () {
    test('válidos', () {
      expect(isValidCpf('529.982.247-25'), isTrue);
      expect(isValidCpf('12345678909'), isTrue);
    });

    test('inválidos', () {
      expect(isValidCpf('529.982.247-24'), isFalse, reason: 'dígito errado');
      expect(isValidCpf('111.111.111-11'), isFalse, reason: 'repetido');
      expect(isValidCpf('1234567890'), isFalse, reason: 'tamanho');
    });
  });

  group('CNPJ', () {
    test('válidos', () {
      expect(isValidCnpj('11.222.333/0001-81'), isTrue);
      expect(isValidCnpj('11444777000161'), isTrue);
    });

    test('inválidos', () {
      expect(isValidCnpj('11.222.333/0001-82'), isFalse, reason: 'dígito errado');
      expect(isValidCnpj('00.000.000/0000-00'), isFalse, reason: 'repetido');
      expect(isValidCnpj('1122233300018'), isFalse, reason: 'tamanho');
    });
  });

  test('isValidTaxId decide pelo tamanho', () {
    expect(isValidTaxId('529.982.247-25'), isTrue);
    expect(isValidTaxId('11.222.333/0001-81'), isTrue);
    expect(isValidTaxId('123'), isFalse);
    expect(isValidTaxId('52998224725000'), isFalse);
  });

  test('formatTaxId aplica a máscara', () {
    expect(formatTaxId('52998224725'), '529.982.247-25');
    expect(formatTaxId('11222333000181'), '11.222.333/0001-81');
    expect(formatTaxId('12-3'), '123');
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
fvm flutter test test/utils/tax_id_test.dart
```

Esperado: FAIL na compilação (`Error when reading 'lib/utils/tax_id.dart'`).

- [ ] **Step 3: Implementar**

Criar `lib/utils/tax_id.dart`:

```dart
/// CPF/CNPJ helpers. `Customer.taxId` is stored with digits only.

String onlyDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

bool _allSameDigit(String digits) => digits.split('').toSet().length == 1;

List<int> _toNumbers(String digits) => digits.split('').map(int.parse).toList();

/// Brazilian CPF (11 digits, two mod-11 check digits).
bool isValidCpf(String value) {
  final digits = onlyDigits(value);
  if (digits.length != 11 || _allSameDigit(digits)) return false;
  final numbers = _toNumbers(digits);
  for (var position = 9; position <= 10; position++) {
    var sum = 0;
    for (var i = 0; i < position; i++) {
      sum += numbers[i] * (position + 1 - i);
    }
    final check = (sum * 10) % 11 % 10;
    if (check != numbers[position]) return false;
  }
  return true;
}

/// Brazilian CNPJ (14 digits, two mod-11 check digits).
bool isValidCnpj(String value) {
  final digits = onlyDigits(value);
  if (digits.length != 14 || _allSameDigit(digits)) return false;
  final numbers = _toNumbers(digits);
  const firstWeights = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  const secondWeights = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];

  int checkDigit(List<int> weights) {
    var sum = 0;
    for (var i = 0; i < weights.length; i++) {
      sum += numbers[i] * weights[i];
    }
    final rest = sum % 11;
    return rest < 2 ? 0 : 11 - rest;
  }

  return checkDigit(firstWeights) == numbers[12] &&
      checkDigit(secondWeights) == numbers[13];
}

/// CPF when 11 digits, CNPJ when 14; anything else is invalid.
bool isValidTaxId(String value) {
  final digits = onlyDigits(value);
  if (digits.length == 11) return isValidCpf(digits);
  if (digits.length == 14) return isValidCnpj(digits);
  return false;
}

/// 000.000.000-00 (CPF) or 00.000.000/0000-00 (CNPJ); other sizes return digits.
String formatTaxId(String value) {
  final d = onlyDigits(value);
  if (d.length == 11) {
    return '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6, 9)}-${d.substring(9)}';
  }
  if (d.length == 14) {
    return '${d.substring(0, 2)}.${d.substring(2, 5)}.${d.substring(5, 8)}/${d.substring(8, 12)}-${d.substring(12)}';
  }
  return d;
}
```

- [ ] **Step 4: Rodar os testes**

```bash
fvm flutter test test/utils/tax_id_test.dart && fvm flutter analyze lib/utils/tax_id.dart
```

Esperado: PASS; analyze sem issues.

- [ ] **Step 5: Commit**

```bash
git add lib/utils/tax_id.dart test/utils/tax_id_test.dart
git commit -m "$(cat <<'EOF'
feat(customers): validação e máscara de CPF/CNPJ

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task A8: `Customer.taxId` no app e no servidor

**Files:**
- Modify: `lib/models/customer.dart:13` (`Customer`) e `:32` (`CustomerAggr`)
- Regenerate: `lib/models/customer.g.dart`
- Modify: `firebase/functions/src/models/types.ts:116-121` (`CustomerAggr`, herdado por `Customer`)
- Test: `test/models/customer_test.dart` (novo)

**Interfaces:**
- Produces: `Customer.taxId` / `CustomerAggr.taxId` (`String?`, só dígitos) no app; `taxId?: string | null` em `CustomerAggr`/`Customer` no servidor (Bloco B lê e grava).

- [ ] **Step 1: Escrever o teste que falha**

Criar `test/models/customer_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/customer.dart';

void main() {
  test('taxId vai e volta no JSON e é copiado para o agregado', () {
    final customer = Customer()
      ..id = 'c1'
      ..name = 'Maria'
      ..taxId = '52998224725';

    final json = customer.toJson();
    expect(json['taxId'], '52998224725');
    expect(Customer.fromJson(json).taxId, '52998224725');

    final aggr = customer.toAggr();
    expect(aggr.taxId, '52998224725');
    expect(aggr.toJson()['taxId'], '52998224725');
    expect(CustomerAggr.fromJson(aggr.toJson()).taxId, '52998224725');
  });

  test('cliente sem taxId continua válido', () {
    final customer = Customer.fromJson({'id': 'c2', 'name': 'João'});

    expect(customer.taxId, isNull);
    expect(customer.toAggr().taxId, isNull);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
fvm flutter test test/models/customer_test.dart
```

Esperado: FAIL na compilação (`The setter 'taxId' isn't defined for the class 'Customer'`).

- [ ] **Step 3: Implementar**

Em `lib/models/customer.dart`, na classe `Customer`, depois de `String? email;` (linha 13), inserir:

```dart

  /// CPF or CNPJ, digits only (see lib/utils/tax_id.dart).
  String? taxId;
```

Na classe `CustomerAggr`, depois de `String? email;` (linha 32), inserir:

```dart

  /// CPF or CNPJ, digits only.
  String? taxId;
```

Regenerar:

```bash
fvm flutter pub run build_runner build --delete-conflicting-outputs
```

Esperado: `lib/models/customer.g.dart` com `..taxId = json['taxId'] as String?` e `'taxId': instance.taxId` em `Customer` e `CustomerAggr`.

Em `firebase/functions/src/models/types.ts`, substituir `CustomerAggr` (linhas 116-121) por:

```ts
export interface CustomerAggr {
  id: string;
  name: string;
  phone?: string | null;
  email?: string | null;
  /** CPF or CNPJ, digits only */
  taxId?: string | null;
}
```

- [ ] **Step 4: Rodar os testes**

```bash
fvm flutter test test/models/customer_test.dart && fvm flutter analyze lib/models
cd firebase/functions && npm run build && npm run lint
```

Esperado: PASS; analyze sem issues; `tsc` e lint sem erros.

- [ ] **Step 5: Commit**

```bash
git add lib/models/customer.dart lib/models/customer.g.dart \
  test/models/customer_test.dart firebase/functions/src/models/types.ts
git commit -m "$(cat <<'EOF'
feat(customers): campo taxId (CPF/CNPJ) no cliente

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task A9: Open PR

**Files:** nenhum.

- [ ] **Step 1: Verificação completa**

```bash
cd firebase/functions && npm run lint && npm run build && npm test
cd ../.. && fvm flutter analyze && fvm flutter test
```

Esperado: tudo verde.

- [ ] **Step 2: Push e PR**

```bash
git push -u origin fix/payments-foundation
gh pr create --base master --head fix/payments-foundation --label risk:high \
  --title "fix(payments): saldo correto, pagamentos atômicos e base para cobrança Asaas" \
  --body "$(cat <<'EOF'
Refs #303

## O que muda

Base da cobrança da OS via Asaas (Bloco A do plano). Nada aqui fala com o Asaas ainda.

- **Saldo no servidor:** `calculateRemainingBalance = max(0, total - paidAmount)`. `order.service.ts` e `analytics.service.ts` subtraíam o desconto duas vezes (o `total` da OS já é líquido de desconto).
- **`addPayment` (API/bot):** roda em transação do Firestore, desconto reduz `total` (mesma regra do app) e `payment` é gravado só como `paid`/`unpaid` (nunca `partial`). `description` indefinida deixa de ir como `undefined` para o Firestore.
- **App não sobrescreve pagamentos:** salvar a OS existente deixa de enviar `transactions`, `paidAmount`, `paid` e `payment`. Pagamento, desconto, marcar como pago, remover e zerar usam `TenantOrderRepository.updatePayments` (`runTransaction`) e atualizam a tela com a OS recém-lida. Regras puras em `lib/utils/order_payment_math.dart`.
- **Transações `asaas_*`** não podem ser removidas no app (mensagem pedindo estorno no Asaas); "zerar pagamentos" mantém essas transações.
- **`X-Company-Id`:** novo `appApiHeaders` usado pelo `IntegrationApiService`; usuários de várias empresas não caem mais sempre na primeira.
- **Permissões:** `PermissionType.chargeOrder` (admin, gerente) e `manage:payments` (dono, admin, gerente) na API.
- **Cliente:** `taxId` (CPF/CNPJ, só dígitos) em `Customer`/`CustomerAggr` (app e tipos do servidor) e `lib/utils/tax_id.dart` com validação e máscara.
- `docs/FINANCEIRO.md` atualizado (persistência dos pagamentos).

## Riscos

- Registrar/remover pagamento agora exige conexão (transação do Firestore); offline o app mostra erro em vez de salvar localmente.
- Salvar uma OS com id já atribuído via `createItem` faz uma leitura extra para saber se ela existe.
- Versões antigas do app continuam enviando os campos de pagamento ao salvar; o reparo vem no Bloco C (trigger).
- `revenue.unpaid` do analytics passa a ser a soma do saldo de cada OS (OS paga a mais não abate o saldo de outra).

## Como testar

- `cd firebase/functions && npm run lint && npm run build && npm test`
- `fvm flutter analyze && fvm flutter test`
- Simulador: registrar pagamento parcial, desconto, comprovante, remover e zerar numa OS; editar um serviço depois e conferir no Firestore que `transactions`/`paidAmount` não mudaram.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Esperado: URL do PR impressa.
## Bloco B — Conexão Asaas e cobranças (server)

Branch `feat/asaas-connection-charges` a partir da `master` **depois do merge do Bloco A** (usa `manage:payments` em `getRolePermissions` e `calculateRemainingBalance = total - paidAmount`). Só servidor (`firebase/functions`). PR: **"feat(payments): conexão Asaas e cobrança da OS (server)"**.

Verificação do PR (rodar antes de abrir e após cada task):

```bash
cd /Users/rafaeldl/Projetos/praticOSopen/.claude/worktrees/bold-sutherland-509639/firebase/functions
npm run lint        # 0 errors (warnings de `any` antigos são esperados)
npm run build       # tsc sem erros
npm test            # todas as suítes passando
```

> Contract note: `AsaasClient.getMyAccount()` chama `GET /v3/myAccount/commercialInfo` (endpoint documentado; devolve `name`, `companyName`, `tradingName`, `email`). A spec cita `GET /myAccount`, que não aparece na referência oficial. `accountName = tradingName || companyName || name`.

> Contract note: exports extras, além do contrato, que os Blocos C–F podem reutilizar: `src/services/asaas/errors.ts` (`AsaasServiceError`, `AsaasErrorCode`, `toHttpError`), `CreateChargeInput` e DTOs da API em `asaas.types.ts`, `asaasConnectionRef`/`clientFromConnection` (credential-provider), `paymentSettingsRef`/`webhookUrl`/`ASAAS_WEBHOOK_EVENTS` (connection.service), `chargesRef`/`todayInSaoPaulo`/`defaultDueDate`/`handleOrderStatusChange` (charge.service), `readMasterKeyFromEnv` (crypto), `src/utils/tax-id.utils.ts` (espelho server de `lib/utils/tax_id.dart`) e o fake de Firestore `src/services/asaas/__tests__/fake-firestore.ts` para testes de serviço.

> Contract note: `src/index.ts` passa a declarar `const asaasCredentialsKey = defineSecret('ASAAS_CREDENTIALS_KEY')` no nível do módulo; o Bloco C reutiliza essa constante no trigger `repairAsaasPayments` e na `api` (já ligada aqui). O Bloco B também adiciona `/webhooks/asaas/**` à redação de payload de log (`shouldLogPayload`), então o Bloco C não precisa mexer em `log-redaction.utils.ts`.

> Contract note: formato das respostas (consumido pelo Bloco D): `POST/DELETE /v1/app/payments/asaas/connect` e `GET /settings` → `{ success, data: PaymentSettingsDoc }` (DELETE → `{ success: true }`); `POST /v1/app/orders/:orderId/charges` → **201** `{ success, data: OrderCharge }` (inclui `id`, `invoiceUrl`, `status`); `DELETE .../charges/:chargeId` → `{ success, data: OrderCharge }`. Erros: `{ success: false, error: { code, message } }` com `code` em `AsaasErrorCode` (`ASAAS_NOT_ENABLED` 403, `ASAAS_INVALID_API_KEY` 400/409, `ASAAS_NOT_CONNECTED` 409, `ASAAS_VALIDATION_ERROR` 400, `ASAAS_UNAVAILABLE` 502, `ORDER_NOT_FOUND` 404, `ORDER_CANCELED` 409, `INVALID_VALUE` 400, `INVALID_INSTALLMENT_COUNT` 400, `INVALID_DUE_DATE` 400, `CUSTOMER_REQUIRED` 400, `TAX_ID_REQUIRED` 400, `INVALID_TAX_ID` 400, `CHARGE_NOT_FOUND` 404, `CHARGE_NOT_OPEN` 409) ou `VALIDATION_ERROR`/`FORBIDDEN`/`INSUFFICIENT_PERMISSIONS`/`INTERNAL_ERROR`.

> Contract note: o e-mail do webhook vem de `user.email` → `users/{uid}.email` → e-mail da conta Asaas (nessa ordem), porque `UserContext` não tem e-mail. `charge.service` lê `Customer.taxId` via tipo local `Customer & { taxId?: string | null }`, então não depende de o Bloco A ter tipado `taxId` em `models/types.ts`.

**Pré-requisito de deploy (Rafael, antes do merge):** o workflow `firebase-functions-deploy.yml` publica a cada push na `master` e o deploy falha se o secret declarado não existir. Criar antes de mergear:

```bash
openssl rand -base64 32 | firebase functions:secrets:set ASAAS_CREDENTIALS_KEY --project praticos --data-file=-
```

Para o emulador local: `firebase/functions/.secret.local` com `ASAAS_CREDENTIALS_KEY=<saída de openssl rand -base64 32>` (gitignored na Task B8).

### Task B1: Tipos Asaas e criptografia AES-256-GCM

**Files:**
- Create: `firebase/functions/src/models/asaas.types.ts`
- Create: `firebase/functions/src/services/asaas/crypto.ts`
- Test: `firebase/functions/src/services/asaas/__tests__/crypto.test.ts`

**Interfaces:**
- Consumes: `UserAggr` de `firebase/functions/src/models/types.ts` (linhas 90–95).
- Produces: `AsaasEnvironment`, `AsaasConnectionMode`, `EncryptedSecret`, `AsaasConnectionDoc`, `ChargeMode`, `ChargeStatus`, `OrderCharge`, `PaymentSettingsDoc`, `CreateChargeInput` e DTOs da API (`AsaasAccountInfo`, `AsaasWallet`, `AsaasCreateWebhookInput`, `AsaasWebhook`, `AsaasCustomer`, `AsaasCreateCustomerInput`, `AsaasCreatePaymentInput`, `AsaasPayment`, `AsaasList<T>`, `AsaasErrorItem`, `AsaasWebhookEventType`); `encryptSecret(plain: string, masterKeyB64: string): EncryptedSecret`, `decryptSecret(enc: EncryptedSecret, masterKeyB64: string): string`, `hashToken(token: string): string`, `safeEqualHex(a: string, b: string): boolean`, `readMasterKeyFromEnv(): string`.

- [ ] **Step 1: Criar a branch**

```bash
cd /Users/rafaeldl/Projetos/praticOSopen/.claude/worktrees/bold-sutherland-509639
git checkout master && git pull
git checkout -b feat/asaas-connection-charges
```

- [ ] **Step 2: Escrever o teste que falha** — `firebase/functions/src/services/asaas/__tests__/crypto.test.ts`

```ts
import { randomBytes } from 'node:crypto';
import {
  decryptSecret,
  encryptSecret,
  hashToken,
  readMasterKeyFromEnv,
  safeEqualHex,
} from '../crypto';

const MASTER_KEY = randomBytes(32).toString('base64');

describe('asaas crypto', () => {
  it('criptografa e decripta (ida e volta)', () => {
    const enc = encryptSecret('$aact_hmlg_secret', MASTER_KEY);
    expect(enc.ciphertext).not.toContain('aact');
    expect(decryptSecret(enc, MASTER_KEY)).toBe('$aact_hmlg_secret');
  });

  it('usa IV diferente a cada chamada', () => {
    const a = encryptSecret('same', MASTER_KEY);
    const b = encryptSecret('same', MASTER_KEY);
    expect(a.iv).not.toBe(b.iv);
    expect(a.ciphertext).not.toBe(b.ciphertext);
  });

  it('falha com tag adulterada', () => {
    const enc = encryptSecret('$aact_hmlg_secret', MASTER_KEY);
    const tag = Buffer.from(enc.tag, 'base64');
    tag[0] = tag[0] ^ 0xff;
    expect(() => decryptSecret({ ...enc, tag: tag.toString('base64') }, MASTER_KEY)).toThrow();
  });

  it('falha com ciphertext adulterado', () => {
    const enc = encryptSecret('$aact_hmlg_secret', MASTER_KEY);
    const data = Buffer.from(enc.ciphertext, 'base64');
    data[0] = data[0] ^ 0xff;
    expect(() => decryptSecret({ ...enc, ciphertext: data.toString('base64') }, MASTER_KEY)).toThrow();
  });

  it('falha com outra chave mestra', () => {
    const enc = encryptSecret('x', MASTER_KEY);
    expect(() => decryptSecret(enc, randomBytes(32).toString('base64'))).toThrow();
  });

  it('rejeita chave mestra que não tem 32 bytes', () => {
    expect(() => encryptSecret('x', randomBytes(16).toString('base64'))).toThrow(/32 bytes/);
  });

  it('hashToken gera sha256 hex e safeEqualHex compara', () => {
    const hash = hashToken('token-1');
    expect(hash).toMatch(/^[0-9a-f]{64}$/);
    expect(safeEqualHex(hash, hashToken('token-1'))).toBe(true);
    expect(safeEqualHex(hash, hashToken('token-2'))).toBe(false);
    expect(safeEqualHex(hash, 'abc')).toBe(false);
    expect(safeEqualHex('', '')).toBe(false);
  });

  it('readMasterKeyFromEnv exige a variável', () => {
    const previous = process.env.ASAAS_CREDENTIALS_KEY;
    delete process.env.ASAAS_CREDENTIALS_KEY;
    expect(() => readMasterKeyFromEnv()).toThrow(/not configured/);
    process.env.ASAAS_CREDENTIALS_KEY = MASTER_KEY;
    expect(readMasterKeyFromEnv()).toBe(MASTER_KEY);
    if (previous === undefined) delete process.env.ASAAS_CREDENTIALS_KEY;
    else process.env.ASAAS_CREDENTIALS_KEY = previous;
  });
});
```

- [ ] **Step 3: Rodar e ver falhar**

```bash
cd /Users/rafaeldl/Projetos/praticOSopen/.claude/worktrees/bold-sutherland-509639/firebase/functions
npx jest src/services/asaas/__tests__/crypto.test.ts
```

Esperado: FAIL com `Cannot find module '../crypto'`.

- [ ] **Step 4: Criar os tipos** — `firebase/functions/src/models/asaas.types.ts`

```ts
/**
 * Asaas integration types (server-only documents and API DTOs).
 * See docs/superpowers/specs/2026-10-04-asaas-cobranca-os-design.md
 */

import { UserAggr } from './types';

export type AsaasEnvironment = 'sandbox' | 'production';
export type AsaasConnectionMode = 'apiKey' | 'flapp';

/** AES-256-GCM output, every field base64 */
export interface EncryptedSecret {
  iv: string;
  tag: string;
  ciphertext: string;
}

/** companies/{companyId}/private/asaas */
export interface AsaasConnectionDoc {
  mode: AsaasConnectionMode;
  environment: AsaasEnvironment;
  encryptedApiKey: EncryptedSecret;
  accountName: string;
  walletId?: string;
  webhookId?: string;
  webhookTokenHash?: string;
  status: 'active' | 'invalid';
  connectedBy: UserAggr;
  connectedAt: string;
}

export type ChargeMode = 'single' | 'cardInstallments';
export type ChargeStatus = 'pending' | 'paid' | 'overdue' | 'canceled' | 'refunded';

/** companies/{companyId}/orders/{orderId}/charges/{chargeId} */
export interface OrderCharge {
  id: string;
  asaasPaymentId: string;
  asaasInstallmentId?: string;
  mode: ChargeMode;
  installmentCount?: number;
  value: number;
  dueDate: string; // YYYY-MM-DD
  status: ChargeStatus;
  invoiceUrl: string;
  paidAsaasPaymentIds: string[];
  createdBy: UserAggr;
  createdAt: string;
  paidAt?: string;
}

/** companies/{companyId}/settings/payments */
export interface PaymentSettingsDoc {
  asaasEnabled: boolean;
  asaasConnected: boolean;
  asaasAccountName?: string;
  asaasEnvironment?: AsaasEnvironment;
}

/** Input of POST /v1/app/orders/:orderId/charges */
export interface CreateChargeInput {
  value: number;
  mode: ChargeMode;
  installmentCount?: number;
  dueDate?: string;
  customerTaxId?: string;
}

// ============================================================================
// Asaas API DTOs (only the fields PraticOS uses)
// ============================================================================

export interface AsaasErrorItem {
  code: string;
  description: string;
}

/** GET /v3/myAccount/commercialInfo */
export interface AsaasAccountInfo {
  name?: string;
  companyName?: string;
  tradingName?: string;
  email?: string;
  cpfCnpj?: string;
}

export interface AsaasWallet {
  id: string;
}

export type AsaasWebhookEventType =
  | 'PAYMENT_RECEIVED'
  | 'PAYMENT_CONFIRMED'
  | 'PAYMENT_OVERDUE'
  | 'PAYMENT_REFUNDED'
  | 'PAYMENT_DELETED';

export interface AsaasCreateWebhookInput {
  name: string;
  url: string;
  email: string;
  enabled: boolean;
  interrupted: boolean;
  apiVersion: number;
  authToken: string;
  sendType: 'SEQUENTIALLY' | 'NON_SEQUENTIALLY';
  events: AsaasWebhookEventType[];
}

export interface AsaasWebhook {
  id: string;
}

export interface AsaasCustomer {
  id: string;
  name: string;
  cpfCnpj?: string;
  externalReference?: string | null;
}

export interface AsaasCreateCustomerInput {
  name: string;
  cpfCnpj: string;
  email?: string;
  externalReference: string;
  notificationDisabled: boolean;
}

export type AsaasBillingType = 'UNDEFINED' | 'BOLETO' | 'CREDIT_CARD' | 'PIX';

export interface AsaasCreatePaymentInput {
  customer: string;
  billingType: AsaasBillingType;
  dueDate: string;
  description: string;
  externalReference: string;
  value?: number;
  installmentCount?: number;
  totalValue?: number;
}

export interface AsaasPayment {
  id: string;
  customer: string;
  status: string;
  billingType: AsaasBillingType;
  value: number;
  dueDate: string;
  invoiceUrl: string;
  externalReference?: string | null;
  installment?: string | null;
  installmentNumber?: number | null;
}

export interface AsaasList<T> {
  object: 'list';
  hasMore: boolean;
  totalCount: number;
  limit: number;
  offset: number;
  data: T[];
}
```

- [ ] **Step 5: Implementar** — `firebase/functions/src/services/asaas/crypto.ts`

```ts
/**
 * Secret encryption for the Asaas integration.
 * AES-256-GCM with a 32-byte master key (secret ASAAS_CREDENTIALS_KEY, base64).
 */

import { createCipheriv, createDecipheriv, createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import { EncryptedSecret } from '../../models/asaas.types';

const ALGORITHM = 'aes-256-gcm';
const IV_BYTES = 12;

function parseMasterKey(masterKeyB64: string): Buffer {
  const key = Buffer.from(masterKeyB64 || '', 'base64');
  if (key.length !== 32) {
    throw new Error('ASAAS_CREDENTIALS_KEY must be 32 bytes encoded as base64');
  }
  return key;
}

export function encryptSecret(plain: string, masterKeyB64: string): EncryptedSecret {
  const key = parseMasterKey(masterKeyB64);
  const iv = randomBytes(IV_BYTES);
  const cipher = createCipheriv(ALGORITHM, key, iv);
  const ciphertext = Buffer.concat([cipher.update(plain, 'utf8'), cipher.final()]);
  return {
    iv: iv.toString('base64'),
    tag: cipher.getAuthTag().toString('base64'),
    ciphertext: ciphertext.toString('base64'),
  };
}

/** Throws when the master key is wrong or any part was tampered with. */
export function decryptSecret(enc: EncryptedSecret, masterKeyB64: string): string {
  const key = parseMasterKey(masterKeyB64);
  const decipher = createDecipheriv(ALGORITHM, key, Buffer.from(enc.iv, 'base64'));
  decipher.setAuthTag(Buffer.from(enc.tag, 'base64'));
  const plain = Buffer.concat([
    decipher.update(Buffer.from(enc.ciphertext, 'base64')),
    decipher.final(),
  ]);
  return plain.toString('utf8');
}

/** SHA-256 hex of a token (webhook auth token is stored only as this hash). */
export function hashToken(token: string): string {
  return createHash('sha256').update(token, 'utf8').digest('hex');
}

/** Timing-safe comparison of two hex strings; false when lengths differ. */
export function safeEqualHex(a: string, b: string): boolean {
  const left = Buffer.from(a || '', 'hex');
  const right = Buffer.from(b || '', 'hex');
  if (left.length === 0 || left.length !== right.length) return false;
  return timingSafeEqual(left, right);
}

/** Master key from the bound secret (process.env at runtime). */
export function readMasterKeyFromEnv(): string {
  const key = process.env.ASAAS_CREDENTIALS_KEY;
  if (!key) {
    throw new Error('ASAAS_CREDENTIALS_KEY is not configured');
  }
  return key;
}
```

- [ ] **Step 6: Rodar os testes**

```bash
npx jest src/services/asaas/__tests__/crypto.test.ts && npm run lint && npm run build
```

Esperado: PASS (8 testes), lint sem erros, build ok.

- [ ] **Step 7: Commit**

```bash
cd /Users/rafaeldl/Projetos/praticOSopen/.claude/worktrees/bold-sutherland-509639
git add firebase/functions/src/models/asaas.types.ts firebase/functions/src/services/asaas/crypto.ts firebase/functions/src/services/asaas/__tests__/crypto.test.ts
git commit -F - <<'EOF'
feat(payments): add Asaas types and AES-256-GCM secret encryption

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

### Task B2: AsaasClient (fetch nativo)

**Files:**
- Create: `firebase/functions/src/services/asaas/asaas-client.ts`
- Test: `firebase/functions/src/services/asaas/__tests__/asaas-client.test.ts`

**Interfaces:**
- Consumes: DTOs de `asaas.types.ts` (Task B1).
- Produces: `class AsaasClient { constructor(opts: { apiKey: string; environment: AsaasEnvironment; fetchImpl?: typeof fetch }); getMyAccount(): Promise<AsaasAccountInfo>; getWallets(): Promise<AsaasWallet[]>; createWebhook(input: AsaasCreateWebhookInput): Promise<AsaasWebhook>; deleteWebhook(id: string): Promise<void>; findCustomerByExternalReference(ref: string): Promise<AsaasCustomer | null>; createCustomer(input: AsaasCreateCustomerInput): Promise<AsaasCustomer>; createPayment(input: AsaasCreatePaymentInput): Promise<AsaasPayment>; deletePayment(id: string): Promise<void>; deleteInstallment(id: string): Promise<void>; listInstallmentPayments(installmentId: string): Promise<AsaasPayment[]> }`, `class AsaasApiError extends Error { status: number; errors: { code: string; description: string }[] }`, `environmentFromApiKey(key: string): AsaasEnvironment | null`, `ASAAS_BASE_URLS`.

Notas: base URLs `https://api-sandbox.asaas.com/v3` e `https://api.asaas.com/v3`; headers `access_token` e `User-Agent: PraticOS`; timeout de 20 s (`AbortSignal.timeout`); a mensagem do `AsaasApiError` leva só método/caminho sem query string, nunca a chave nem o corpo.

- [ ] **Step 1: Escrever o teste que falha** — `firebase/functions/src/services/asaas/__tests__/asaas-client.test.ts`

```ts
import { AsaasApiError, AsaasClient, environmentFromApiKey } from '../asaas-client';

interface Call {
  url: string;
  init: RequestInit;
}

function fakeFetch(status: number, body: unknown) {
  const calls: Call[] = [];
  const impl = (async (url: string, init: RequestInit) => {
    calls.push({ url, init });
    return new Response(body === undefined ? '' : JSON.stringify(body), { status });
  }) as unknown as typeof fetch;
  return { impl, calls };
}

function headersOf(call: Call): Record<string, string> {
  return call.init.headers as Record<string, string>;
}

describe('environmentFromApiKey', () => {
  it('infere ambiente pelo prefixo', () => {
    expect(environmentFromApiKey('$aact_hmlg_abc')).toBe('sandbox');
    expect(environmentFromApiKey('  $aact_prod_abc ')).toBe('production');
    expect(environmentFromApiKey('abc')).toBeNull();
    expect(environmentFromApiKey('')).toBeNull();
  });
});

describe('AsaasClient', () => {
  it('usa URL do sandbox e headers access_token e User-Agent', async () => {
    const { impl, calls } = fakeFetch(200, { name: 'Oficina X', email: 'a@b.com' });
    const client = new AsaasClient({ apiKey: '$aact_hmlg_k', environment: 'sandbox', fetchImpl: impl });

    const account = await client.getMyAccount();

    expect(account.name).toBe('Oficina X');
    expect(calls[0].url).toBe('https://api-sandbox.asaas.com/v3/myAccount/commercialInfo');
    expect(calls[0].init.method).toBe('GET');
    expect(headersOf(calls[0]).access_token).toBe('$aact_hmlg_k');
    expect(headersOf(calls[0])['User-Agent']).toBe('PraticOS');
  });

  it('usa URL de produção', async () => {
    const { impl, calls } = fakeFetch(200, { object: 'list', data: [{ id: 'w1' }] });
    const client = new AsaasClient({ apiKey: '$aact_prod_k', environment: 'production', fetchImpl: impl });

    const wallets = await client.getWallets();

    expect(wallets).toEqual([{ id: 'w1' }]);
    expect(calls[0].url).toBe('https://api.asaas.com/v3/wallets');
  });

  it('envia corpo JSON no POST', async () => {
    const { impl, calls } = fakeFetch(200, { id: 'pay_1', invoiceUrl: 'https://i' });
    const client = new AsaasClient({ apiKey: '$aact_hmlg_k', environment: 'sandbox', fetchImpl: impl });

    await client.createPayment({
      customer: 'cus_1',
      billingType: 'UNDEFINED',
      value: 100,
      dueDate: '2026-10-07',
      description: 'OS #1 - X',
      externalReference: 'c:o:ch',
    });

    expect(calls[0].url).toBe('https://api-sandbox.asaas.com/v3/payments');
    expect(calls[0].init.method).toBe('POST');
    expect(headersOf(calls[0])['content-type']).toBe('application/json');
    expect(JSON.parse(calls[0].init.body as string)).toMatchObject({ customer: 'cus_1', value: 100 });
  });

  it('busca cliente por externalReference', async () => {
    const { impl, calls } = fakeFetch(200, { object: 'list', data: [{ id: 'cus_9', name: 'Ana' }] });
    const client = new AsaasClient({ apiKey: '$aact_hmlg_k', environment: 'sandbox', fetchImpl: impl });

    const customer = await client.findCustomerByExternalReference('cust1');

    expect(customer?.id).toBe('cus_9');
    expect(calls[0].url).toBe('https://api-sandbox.asaas.com/v3/customers?externalReference=cust1&limit=1');
  });

  it('retorna null quando não acha cliente', async () => {
    const { impl } = fakeFetch(200, { object: 'list', data: [] });
    const client = new AsaasClient({ apiKey: '$aact_hmlg_k', environment: 'sandbox', fetchImpl: impl });
    expect(await client.findCustomerByExternalReference('x')).toBeNull();
  });

  it('DELETE de cobrança, parcelamento e webhook', async () => {
    const { impl, calls } = fakeFetch(200, { deleted: true });
    const client = new AsaasClient({ apiKey: '$aact_hmlg_k', environment: 'sandbox', fetchImpl: impl });

    await client.deletePayment('pay_1');
    await client.deleteInstallment('ins_1');
    await client.deleteWebhook('wh_1');

    expect(calls.map((c) => `${c.init.method} ${c.url}`)).toEqual([
      'DELETE https://api-sandbox.asaas.com/v3/payments/pay_1',
      'DELETE https://api-sandbox.asaas.com/v3/installments/ins_1',
      'DELETE https://api-sandbox.asaas.com/v3/webhooks/wh_1',
    ]);
  });

  it('lista parcelas de um parcelamento', async () => {
    const { impl, calls } = fakeFetch(200, { object: 'list', data: [{ id: 'p1' }, { id: 'p2' }] });
    const client = new AsaasClient({ apiKey: '$aact_hmlg_k', environment: 'sandbox', fetchImpl: impl });

    const payments = await client.listInstallmentPayments('ins_1');

    expect(payments.map((p) => p.id)).toEqual(['p1', 'p2']);
    expect(calls[0].url).toBe('https://api-sandbox.asaas.com/v3/installments/ins_1/payments?limit=100');
  });

  it('lança AsaasApiError com status e errors', async () => {
    const { impl } = fakeFetch(400, { errors: [{ code: 'invalid_value', description: 'Valor inválido' }] });
    const client = new AsaasClient({ apiKey: '$aact_hmlg_k', environment: 'sandbox', fetchImpl: impl });

    const error = await client
      .createCustomer({ name: 'A', cpfCnpj: '1', externalReference: 'c', notificationDisabled: true })
      .catch((e) => e);

    expect(error).toBeInstanceOf(AsaasApiError);
    expect(error.status).toBe(400);
    expect(error.errors).toEqual([{ code: 'invalid_value', description: 'Valor inválido' }]);
    expect(error.message).not.toContain('aact');
  });

  it('lança AsaasApiError 401 com corpo vazio', async () => {
    const { impl } = fakeFetch(401, undefined);
    const client = new AsaasClient({ apiKey: '$aact_hmlg_k', environment: 'sandbox', fetchImpl: impl });

    const error = await client.getMyAccount().catch((e) => e);

    expect(error).toBeInstanceOf(AsaasApiError);
    expect(error.status).toBe(401);
    expect(error.errors).toEqual([]);
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
cd /Users/rafaeldl/Projetos/praticOSopen/.claude/worktrees/bold-sutherland-509639/firebase/functions
npx jest src/services/asaas/__tests__/asaas-client.test.ts
```

Esperado: FAIL com `Cannot find module '../asaas-client'`.

- [ ] **Step 3: Implementar** — `firebase/functions/src/services/asaas/asaas-client.ts`

```ts
/**
 * Minimal Asaas API v3 client (native fetch).
 * Never logs the API key nor request/response bodies.
 */

import {
  AsaasAccountInfo,
  AsaasCreateCustomerInput,
  AsaasCreatePaymentInput,
  AsaasCreateWebhookInput,
  AsaasCustomer,
  AsaasEnvironment,
  AsaasErrorItem,
  AsaasList,
  AsaasPayment,
  AsaasWallet,
  AsaasWebhook,
} from '../../models/asaas.types';

export const ASAAS_BASE_URLS: Record<AsaasEnvironment, string> = {
  sandbox: 'https://api-sandbox.asaas.com/v3',
  production: 'https://api.asaas.com/v3',
};

const USER_AGENT = 'PraticOS';
const REQUEST_TIMEOUT_MS = 20_000;

export class AsaasApiError extends Error {
  readonly status: number;
  readonly errors: AsaasErrorItem[];

  constructor(status: number, errors: AsaasErrorItem[], path: string) {
    super(`Asaas request failed (${status}) on ${path}`);
    this.name = 'AsaasApiError';
    this.status = status;
    this.errors = errors;
  }
}

/** Infers the environment from the key prefix; null when the key is not an Asaas key. */
export function environmentFromApiKey(key: string): AsaasEnvironment | null {
  const trimmed = (key || '').trim();
  if (trimmed.startsWith('$aact_hmlg')) return 'sandbox';
  if (trimmed.startsWith('$aact_prod')) return 'production';
  return null;
}

export interface AsaasClientOptions {
  apiKey: string;
  environment: AsaasEnvironment;
  fetchImpl?: typeof fetch;
}

export class AsaasClient {
  private readonly apiKey: string;
  private readonly baseUrl: string;
  private readonly fetchImpl: typeof fetch;

  constructor(opts: AsaasClientOptions) {
    this.apiKey = opts.apiKey.trim();
    this.baseUrl = ASAAS_BASE_URLS[opts.environment];
    this.fetchImpl = opts.fetchImpl ?? fetch;
  }

  getMyAccount(): Promise<AsaasAccountInfo> {
    return this.request<AsaasAccountInfo>('GET', '/myAccount/commercialInfo');
  }

  async getWallets(): Promise<AsaasWallet[]> {
    const list = await this.request<AsaasList<AsaasWallet>>('GET', '/wallets');
    return list.data ?? [];
  }

  createWebhook(input: AsaasCreateWebhookInput): Promise<AsaasWebhook> {
    return this.request<AsaasWebhook>('POST', '/webhooks', input);
  }

  async deleteWebhook(id: string): Promise<void> {
    await this.request<unknown>('DELETE', `/webhooks/${encodeURIComponent(id)}`);
  }

  async findCustomerByExternalReference(ref: string): Promise<AsaasCustomer | null> {
    const query = new URLSearchParams({ externalReference: ref, limit: '1' });
    const list = await this.request<AsaasList<AsaasCustomer>>('GET', `/customers?${query.toString()}`);
    return list.data?.[0] ?? null;
  }

  createCustomer(input: AsaasCreateCustomerInput): Promise<AsaasCustomer> {
    return this.request<AsaasCustomer>('POST', '/customers', input);
  }

  createPayment(input: AsaasCreatePaymentInput): Promise<AsaasPayment> {
    return this.request<AsaasPayment>('POST', '/payments', input);
  }

  async deletePayment(id: string): Promise<void> {
    await this.request<unknown>('DELETE', `/payments/${encodeURIComponent(id)}`);
  }

  async deleteInstallment(id: string): Promise<void> {
    await this.request<unknown>('DELETE', `/installments/${encodeURIComponent(id)}`);
  }

  async listInstallmentPayments(installmentId: string): Promise<AsaasPayment[]> {
    const list = await this.request<AsaasList<AsaasPayment>>(
      'GET',
      `/installments/${encodeURIComponent(installmentId)}/payments?limit=100`,
    );
    return list.data ?? [];
  }

  private async request<T>(method: 'GET' | 'POST' | 'DELETE', path: string, body?: unknown): Promise<T> {
    const headers: Record<string, string> = {
      access_token: this.apiKey,
      'User-Agent': USER_AGENT,
      accept: 'application/json',
    };
    if (body !== undefined) headers['content-type'] = 'application/json';

    const response = await this.fetchImpl(`${this.baseUrl}${path}`, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });

    const text = await response.text();
    let parsed: unknown = undefined;
    if (text) {
      try {
        parsed = JSON.parse(text);
      } catch {
        parsed = undefined;
      }
    }

    if (!response.ok) {
      const errors = (parsed as { errors?: AsaasErrorItem[] } | undefined)?.errors ?? [];
      // Path without query string: query may carry customer references.
      throw new AsaasApiError(response.status, errors, path.split('?')[0]);
    }

    return parsed as T;
  }
}
```

- [ ] **Step 4: Rodar os testes**

```bash
npx jest src/services/asaas && npm run lint && npm run build
```

Esperado: PASS (crypto 8 + client 10), lint sem erros, build ok.

- [ ] **Step 5: Commit**

```bash
cd /Users/rafaeldl/Projetos/praticOSopen/.claude/worktrees/bold-sutherland-509639
git add firebase/functions/src/services/asaas/asaas-client.ts firebase/functions/src/services/asaas/__tests__/asaas-client.test.ts
git commit -F - <<'EOF'
feat(payments): add Asaas API client

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

### Task B3: Erros de negócio, credential provider e fake de Firestore

**Files:**
- Create: `firebase/functions/src/services/asaas/errors.ts`
- Create: `firebase/functions/src/services/asaas/credential-provider.ts`
- Create: `firebase/functions/src/services/asaas/__tests__/fake-firestore.ts` (helper de teste, não é suíte: sem sufixo `.test`; `tsconfig.json` já exclui `src/**/__tests__` do build)
- Test: `firebase/functions/src/services/asaas/__tests__/errors.test.ts`
- Test: `firebase/functions/src/services/asaas/__tests__/credential-provider.test.ts`

**Interfaces:**
- Consumes: `db` de `firebase/functions/src/services/firestore.service.ts` (linha 16); `AsaasClient`, `AsaasApiError` (B2); `decryptSecret`, `readMasterKeyFromEnv` (B1).
- Produces: `class AsaasServiceError extends Error { code: AsaasErrorCode; httpStatus: number }`, `toHttpError(error: unknown, fallbackMessage: string): { status: number; body: { success: false; error: { code: string; message: string } } }`; `interface AsaasCredentialProvider { getClient(companyId: string): Promise<AsaasClient> }`, `class ApiKeyCredentialProvider implements AsaasCredentialProvider` (construtor `(masterKey: () => string = readMasterKeyFromEnv, fetchImpl?: typeof fetch)`), `getAsaasCredentialProvider(): AsaasCredentialProvider`, `setAsaasCredentialProvider(p: AsaasCredentialProvider | null): void`, `asaasConnectionRef(companyId)`, `clientFromConnection(connection, masterKey, fetchImpl?)`. Fake: `fakeDb`, `seed(path, data)`, `read(path)`, `list(collectionPath)`, `resetFakeDb()`, `firestoreServiceMock`.

Os testes de serviço mockam `firestore.service` assim (padrão dos testes existentes, como `src/services/__tests__/integration-token.service.test.ts`, só que com um fake em memória em vez de mocks encadeados): `jest.mock('../../firestore.service', () => jest.requireActual('./fake-firestore').firestoreServiceMock);` — `jest.requireActual` em vez de `require` por causa da regra `@typescript-eslint/no-require-imports`.

- [ ] **Step 1: Escrever os testes que falham**

`firebase/functions/src/services/asaas/__tests__/errors.test.ts`:

```ts
import { AsaasApiError } from '../asaas-client';
import { AsaasServiceError, toHttpError } from '../errors';

describe('toHttpError', () => {
  it('mapeia AsaasServiceError pelo código', () => {
    const result = toHttpError(new AsaasServiceError('INVALID_VALUE', 'Value exceeds balance'), 'x');
    expect(result).toEqual({
      status: 400,
      body: { success: false, error: { code: 'INVALID_VALUE', message: 'Value exceeds balance' } },
    });
    expect(toHttpError(new AsaasServiceError('ASAAS_NOT_ENABLED', 'm'), 'x').status).toBe(403);
    expect(toHttpError(new AsaasServiceError('CHARGE_NOT_FOUND', 'm'), 'x').status).toBe(404);
    expect(toHttpError(new AsaasServiceError('ASAAS_NOT_CONNECTED', 'm'), 'x').status).toBe(409);
  });

  it('mapeia 400 do Asaas com a descrição', () => {
    const error = new AsaasApiError(400, [{ code: 'invalid_cpfCnpj', description: 'CPF inválido' }], '/customers');
    expect(toHttpError(error, 'x')).toEqual({
      status: 400,
      body: { success: false, error: { code: 'ASAAS_VALIDATION_ERROR', message: 'CPF inválido' } },
    });
  });

  it('mapeia 401 do Asaas para chave recusada', () => {
    const result = toHttpError(new AsaasApiError(401, [], '/payments'), 'x');
    expect(result.status).toBe(409);
    expect(result.body.error.code).toBe('ASAAS_INVALID_API_KEY');
  });

  it('mapeia 5xx do Asaas para 502', () => {
    const result = toHttpError(new AsaasApiError(503, [], '/payments'), 'x');
    expect(result.status).toBe(502);
    expect(result.body.error.code).toBe('ASAAS_UNAVAILABLE');
  });

  it('erro desconhecido vira 500 com a mensagem padrão', () => {
    expect(toHttpError(new Error('boom'), 'Failed to create charge')).toEqual({
      status: 500,
      body: { success: false, error: { code: 'INTERNAL_ERROR', message: 'Failed to create charge' } },
    });
  });
});
```

`firebase/functions/src/services/asaas/__tests__/credential-provider.test.ts`:

```ts
jest.mock('../../firestore.service', () => jest.requireActual('./fake-firestore').firestoreServiceMock);

import { randomBytes } from 'node:crypto';
import { resetFakeDb, seed } from './fake-firestore';
import { encryptSecret } from '../crypto';
import { AsaasClient } from '../asaas-client';
import {
  ApiKeyCredentialProvider,
  getAsaasCredentialProvider,
  setAsaasCredentialProvider,
} from '../credential-provider';
import { AsaasServiceError } from '../errors';

const MASTER_KEY = randomBytes(32).toString('base64');

function seedConnection(status: 'active' | 'invalid') {
  seed('companies/c1/private/asaas', {
    mode: 'apiKey',
    environment: 'sandbox',
    encryptedApiKey: encryptSecret('$aact_hmlg_key', MASTER_KEY),
    accountName: 'Oficina',
    status,
    connectedBy: { id: 'u1', name: 'Ana' },
    connectedAt: '2026-10-04T10:00:00.000Z',
  });
}

describe('ApiKeyCredentialProvider', () => {
  beforeEach(() => {
    resetFakeDb();
    setAsaasCredentialProvider(null);
  });

  it('decripta a chave e monta o client do ambiente salvo', async () => {
    seedConnection('active');
    const calls: Array<{ url: string; headers: Record<string, string> }> = [];
    const fetchImpl = (async (url: string, init: RequestInit) => {
      calls.push({ url, headers: init.headers as Record<string, string> });
      return new Response(JSON.stringify({ name: 'Oficina' }), { status: 200 });
    }) as unknown as typeof fetch;

    const client = await new ApiKeyCredentialProvider(() => MASTER_KEY, fetchImpl).getClient('c1');
    await client.getMyAccount();

    expect(client).toBeInstanceOf(AsaasClient);
    expect(calls[0].url).toContain('https://api-sandbox.asaas.com/v3');
    expect(calls[0].headers.access_token).toBe('$aact_hmlg_key');
  });

  it('falha com ASAAS_NOT_CONNECTED sem credencial', async () => {
    const error = await new ApiKeyCredentialProvider(() => MASTER_KEY).getClient('c1').catch((e) => e);
    expect(error).toBeInstanceOf(AsaasServiceError);
    expect(error.code).toBe('ASAAS_NOT_CONNECTED');
  });

  it('falha com ASAAS_NOT_CONNECTED quando status é invalid', async () => {
    seedConnection('invalid');
    const error = await new ApiKeyCredentialProvider(() => MASTER_KEY).getClient('c1').catch((e) => e);
    expect(error.code).toBe('ASAAS_NOT_CONNECTED');
  });

  it('singleton é substituível em testes', () => {
    const fake = { getClient: jest.fn() };
    setAsaasCredentialProvider(fake);
    expect(getAsaasCredentialProvider()).toBe(fake);
    setAsaasCredentialProvider(null);
    expect(getAsaasCredentialProvider()).toBeInstanceOf(ApiKeyCredentialProvider);
  });
});
```

- [ ] **Step 2: Criar o fake de Firestore** — `firebase/functions/src/services/asaas/__tests__/fake-firestore.ts`

```ts
/**
 * In-memory Firestore fake for the Asaas service tests.
 * Supports only what the Asaas services use: doc/collection refs, get/set
 * (with merge)/update/delete, where('==' | 'in'), batch, runTransaction and
 * recursiveDelete. Not a test file (no .test suffix); excluded from tsc by tsconfig.
 */

type Data = Record<string, any>;

const store = new Map<string, Data>();
let autoId = 0;

function clone<T>(value: T): T {
  return value === undefined ? value : JSON.parse(JSON.stringify(value));
}

function deepMerge(target: Data, source: Data): Data {
  const result: Data = { ...target };
  for (const [key, value] of Object.entries(source)) {
    if (value && typeof value === 'object' && !Array.isArray(value) && result[key] && typeof result[key] === 'object' && !Array.isArray(result[key])) {
      result[key] = deepMerge(result[key], value);
    } else {
      result[key] = value;
    }
  }
  return result;
}

export class FakeDocSnapshot {
  constructor(public readonly ref: FakeDocRef, private readonly value: Data | undefined) {}
  get id() { return this.ref.id; }
  get exists() { return this.value !== undefined; }
  data() { return clone(this.value); }
}

export class FakeDocRef {
  constructor(public readonly path: string) {}
  get id() { return this.path.split('/').pop() as string; }
  collection(name: string) { return new FakeCollectionRef(`${this.path}/${name}`); }
  async get() { return new FakeDocSnapshot(this, clone(store.get(this.path))); }
  async set(data: Data, options?: { merge?: boolean }) {
    const current = store.get(this.path);
    store.set(this.path, options?.merge && current ? deepMerge(current, clone(data)) : clone(data));
  }
  async update(data: Data) {
    const current = store.get(this.path);
    if (!current) throw new Error(`NOT_FOUND: ${this.path}`);
    store.set(this.path, { ...current, ...clone(data) });
  }
  async delete() { store.delete(this.path); }
}

type Filter = { field: string; op: '==' | 'in'; value: any };

export class FakeQuery {
  constructor(public readonly path: string, protected readonly filters: Filter[] = []) {}
  where(field: string, op: '==' | 'in', value: any) {
    return new FakeQuery(this.path, [...this.filters, { field, op, value }]);
  }
  async get() {
    const prefix = `${this.path}/`;
    const docs: FakeDocSnapshot[] = [];
    for (const [path, value] of store.entries()) {
      if (!path.startsWith(prefix) || path.slice(prefix.length).includes('/')) continue;
      const matches = this.filters.every((f) =>
        f.op === '==' ? value[f.field] === f.value : (f.value as any[]).includes(value[f.field]),
      );
      if (matches) docs.push(new FakeDocSnapshot(new FakeDocRef(path), clone(value)));
    }
    return { docs, empty: docs.length === 0, size: docs.length };
  }
}

export class FakeCollectionRef extends FakeQuery {
  doc(id?: string) {
    return new FakeDocRef(`${this.path}/${id ?? `auto${++autoId}`}`);
  }
}

export const fakeDb = {
  collection: (name: string) => new FakeCollectionRef(name),
  doc: (path: string) => new FakeDocRef(path),
  batch() {
    const ops: Array<() => Promise<void>> = [];
    const batch = {
      set: (ref: FakeDocRef, data: Data, options?: { merge?: boolean }) => { ops.push(() => ref.set(data, options)); return batch; },
      update: (ref: FakeDocRef, data: Data) => { ops.push(() => ref.update(data)); return batch; },
      delete: (ref: FakeDocRef) => { ops.push(() => ref.delete()); return batch; },
      commit: async () => { for (const op of ops) await op(); },
    };
    return batch;
  },
  async runTransaction<T>(fn: (tx: any) => Promise<T>): Promise<T> {
    const tx = {
      get: (ref: FakeDocRef) => ref.get(),
      set: (ref: FakeDocRef, data: Data, options?: { merge?: boolean }) => { void ref.set(data, options); return tx; },
      update: (ref: FakeDocRef, data: Data) => { void ref.update(data); return tx; },
      delete: (ref: FakeDocRef) => { void ref.delete(); return tx; },
    };
    return fn(tx);
  },
  async recursiveDelete(ref: FakeDocRef) {
    for (const path of Array.from(store.keys())) {
      if (path === ref.path || path.startsWith(`${ref.path}/`)) store.delete(path);
    }
  },
};

/** Seeds a document by full path, e.g. seed('companies/c1/settings/payments', {...}) */
export function seed(path: string, data: Data): void {
  store.set(path, clone(data));
}

/** Reads a document by full path (undefined when missing). */
export function read(path: string): Data | undefined {
  return clone(store.get(path));
}

/** Lists the documents directly under a collection path. */
export function list(collectionPath: string): Array<{ id: string; data: Data }> {
  const prefix = `${collectionPath}/`;
  return Array.from(store.entries())
    .filter(([path]) => path.startsWith(prefix) && !path.slice(prefix.length).includes('/'))
    .map(([path, data]) => ({ id: path.slice(prefix.length), data: clone(data) }));
}

export function resetFakeDb(): void {
  store.clear();
  autoId = 0;
}

/** Module shape used by jest.mock('<relative>/firestore.service', ...) */
export const firestoreServiceMock = {
  db: fakeDb,
  getTenantCollection: (companyId: string, collection: string) =>
    fakeDb.collection('companies').doc(companyId).collection(collection),
};
```

- [ ] **Step 3: Rodar e ver falhar**

```bash
cd /Users/rafaeldl/Projetos/praticOSopen/.claude/worktrees/bold-sutherland-509639/firebase/functions
npx jest src/services/asaas/__tests__/errors.test.ts src/services/asaas/__tests__/credential-provider.test.ts
```

Esperado: FAIL com `Cannot find module '../errors'` e `Cannot find module '../credential-provider'`.

- [ ] **Step 4: Implementar os erros** — `firebase/functions/src/services/asaas/errors.ts`

```ts
/**
 * Business errors of the Asaas integration, mapped to HTTP by the routes.
 * The app (AsaasApiService) shows a message per `code`.
 */

import { AsaasApiError } from './asaas-client';

export type AsaasErrorCode =
  | 'ASAAS_NOT_ENABLED'
  | 'ASAAS_INVALID_API_KEY'
  | 'ASAAS_NOT_CONNECTED'
  | 'ASAAS_VALIDATION_ERROR'
  | 'ASAAS_UNAVAILABLE'
  | 'ORDER_NOT_FOUND'
  | 'ORDER_CANCELED'
  | 'INVALID_VALUE'
  | 'INVALID_INSTALLMENT_COUNT'
  | 'INVALID_DUE_DATE'
  | 'CUSTOMER_REQUIRED'
  | 'TAX_ID_REQUIRED'
  | 'INVALID_TAX_ID'
  | 'CHARGE_NOT_FOUND'
  | 'CHARGE_NOT_OPEN';

const HTTP_STATUS: Record<AsaasErrorCode, number> = {
  ASAAS_NOT_ENABLED: 403,
  ASAAS_INVALID_API_KEY: 400,
  ASAAS_NOT_CONNECTED: 409,
  ASAAS_VALIDATION_ERROR: 400,
  ASAAS_UNAVAILABLE: 502,
  ORDER_NOT_FOUND: 404,
  ORDER_CANCELED: 409,
  INVALID_VALUE: 400,
  INVALID_INSTALLMENT_COUNT: 400,
  INVALID_DUE_DATE: 400,
  CUSTOMER_REQUIRED: 400,
  TAX_ID_REQUIRED: 400,
  INVALID_TAX_ID: 400,
  CHARGE_NOT_FOUND: 404,
  CHARGE_NOT_OPEN: 409,
};

export class AsaasServiceError extends Error {
  readonly code: AsaasErrorCode;
  readonly httpStatus: number;

  constructor(code: AsaasErrorCode, message: string) {
    super(message);
    this.name = 'AsaasServiceError';
    this.code = code;
    this.httpStatus = HTTP_STATUS[code];
  }
}

export interface HttpErrorBody {
  status: number;
  body: { success: false; error: { code: string; message: string } };
}

/**
 * Converts any error thrown by the Asaas services into the API error format.
 * Never includes the API key, tokens or request payloads.
 */
export function toHttpError(error: unknown, fallbackMessage: string): HttpErrorBody {
  if (error instanceof AsaasServiceError) {
    return {
      status: error.httpStatus,
      body: { success: false, error: { code: error.code, message: error.message } },
    };
  }
  if (error instanceof AsaasApiError) {
    if (error.status === 400) {
      const message = error.errors[0]?.description || 'Asaas rejected the request';
      return {
        status: 400,
        body: { success: false, error: { code: 'ASAAS_VALIDATION_ERROR', message } },
      };
    }
    if (error.status === 401) {
      return {
        status: 409,
        body: {
          success: false,
          error: { code: 'ASAAS_INVALID_API_KEY', message: 'Asaas API key was rejected' },
        },
      };
    }
    return {
      status: 502,
      body: { success: false, error: { code: 'ASAAS_UNAVAILABLE', message: 'Asaas is unavailable' } },
    };
  }
  return {
    status: 500,
    body: { success: false, error: { code: 'INTERNAL_ERROR', message: fallbackMessage } },
  };
}
```

- [ ] **Step 5: Implementar o provider** — `firebase/functions/src/services/asaas/credential-provider.ts`

```ts
/**
 * Resolves an authenticated AsaasClient for a company.
 * Stage 1: API key pasted by the owner/admin (mode 'apiKey').
 * Stage 3 (Flapp Store) adds another provider behind the same interface.
 */

import { db } from '../firestore.service';
import { AsaasConnectionDoc } from '../../models/asaas.types';
import { AsaasClient } from './asaas-client';
import { decryptSecret, readMasterKeyFromEnv } from './crypto';
import { AsaasServiceError } from './errors';

export interface AsaasCredentialProvider {
  getClient(companyId: string): Promise<AsaasClient>;
}

export function asaasConnectionRef(companyId: string) {
  return db.collection('companies').doc(companyId).collection('private').doc('asaas');
}

/** Builds a client from a stored connection doc (also used by disconnect). */
export function clientFromConnection(
  connection: AsaasConnectionDoc,
  masterKey: string,
  fetchImpl?: typeof fetch,
): AsaasClient {
  const apiKey = decryptSecret(connection.encryptedApiKey, masterKey);
  return new AsaasClient({ apiKey, environment: connection.environment, fetchImpl });
}

export class ApiKeyCredentialProvider implements AsaasCredentialProvider {
  constructor(
    private readonly masterKey: () => string = readMasterKeyFromEnv,
    private readonly fetchImpl?: typeof fetch,
  ) {}

  async getClient(companyId: string): Promise<AsaasClient> {
    const snapshot = await asaasConnectionRef(companyId).get();
    const connection = snapshot.data() as AsaasConnectionDoc | undefined;
    if (!snapshot.exists || !connection || connection.status !== 'active') {
      throw new AsaasServiceError('ASAAS_NOT_CONNECTED', 'Asaas account is not connected');
    }
    return clientFromConnection(connection, this.masterKey(), this.fetchImpl);
  }
}

let provider: AsaasCredentialProvider | null = null;

export function getAsaasCredentialProvider(): AsaasCredentialProvider {
  if (!provider) provider = new ApiKeyCredentialProvider();
  return provider;
}

/** Test hook: replace the singleton (pass null to restore the default). */
export function setAsaasCredentialProvider(p: AsaasCredentialProvider | null): void {
  provider = p;
}
```

- [ ] **Step 6: Rodar os testes**

```bash
npx jest src/services/asaas && npm run lint && npm run build
```

Esperado: PASS (4 suítes), lint sem erros, build ok.

- [ ] **Step 7: Commit**

```bash
cd /Users/rafaeldl/Projetos/praticOSopen/.claude/worktrees/bold-sutherland-509639
git add firebase/functions/src/services/asaas/errors.ts firebase/functions/src/services/asaas/credential-provider.ts firebase/functions/src/services/asaas/__tests__/fake-firestore.ts firebase/functions/src/services/asaas/__tests__/errors.test.ts firebase/functions/src/services/asaas/__tests__/credential-provider.test.ts
git commit -F - <<'EOF'
feat(payments): add Asaas credential provider and error mapping

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

### Task B4: connection.service (conectar / desconectar / settings)

**Files:**
- Create: `firebase/functions/src/services/asaas/connection.service.ts`
- Test: `firebase/functions/src/services/asaas/__tests__/connection.service.test.ts`

**Interfaces:**
- Consumes: `AsaasClient`, `AsaasApiError`, `environmentFromApiKey` (B2); `encryptSecret`, `hashToken`, `readMasterKeyFromEnv` (B1); `asaasConnectionRef`, `clientFromConnection`, `AsaasServiceError` (B3); `db` de `firestore.service`.
- Produces: `connectAsaas(companyId: string, apiKey: string, user: UserAggr & { email?: string }): Promise<PaymentSettingsDoc>`, `disconnectAsaas(companyId: string): Promise<void>`, `getPaymentSettings(companyId: string): Promise<PaymentSettingsDoc>`, `paymentSettingsRef(companyId)`, `webhookUrl(companyId): string`, `ASAAS_WEBHOOK_EVENTS`.

Regras implementadas:
1. `connectAsaas` exige `settings/payments.asaasEnabled === true` (senão `ASAAS_NOT_ENABLED`); prefixo `$aact_hmlg`/`$aact_prod` define o ambiente (senão `ASAAS_INVALID_API_KEY` sem chamar a API); `getMyAccount` com 401/403 → `ASAAS_INVALID_API_KEY` e **nada é gravado**; lê `getWallets()` (primeiro `walletId`).
2. Reconexão: remove (best effort) o webhook da credencial anterior.
3. Webhook: `name: 'PraticOS'`, `url: ${ASAAS_WEBHOOK_BASE_URL}/webhooks/asaas/${companyId}` (default `https://southamerica-east1-praticos.cloudfunctions.net/api`, barra final removida), e-mail do usuário, `enabled: true`, `interrupted: false`, `apiVersion: 3`, `sendType: 'SEQUENTIALLY'`, `authToken = randomBytes(48).toString('base64url')` (64 caracteres), eventos `PAYMENT_RECEIVED`, `PAYMENT_CONFIRMED`, `PAYMENT_OVERDUE`, `PAYMENT_REFUNDED`, `PAYMENT_DELETED`.
4. Grava `private/asaas` (chave criptografada, `webhookTokenHash = sha256(authToken)`, `status: 'active'`) e `settings/payments` num batch; se o batch falhar, apaga o webhook criado.
5. `disconnectAsaas` apaga o webhook (best effort, loga só o status HTTP), `recursiveDelete` em `private/asaas` (credencial + mapa de clientes + eventos) e regrava `settings/payments` como `{ asaasEnabled, asaasConnected: false }`. Cobranças abertas continuam no Asaas.

- [ ] **Step 1: Escrever o teste que falha** — `firebase/functions/src/services/asaas/__tests__/connection.service.test.ts`

```ts
jest.mock('../../firestore.service', () => jest.requireActual('./fake-firestore').firestoreServiceMock);

const mockClient = {
  getMyAccount: jest.fn(),
  getWallets: jest.fn(),
  createWebhook: jest.fn(),
  deleteWebhook: jest.fn(),
};
const mockClientOptions: any[] = [];

jest.mock('../asaas-client', () => {
  const actual = jest.requireActual('../asaas-client');
  return {
    ...actual,
    AsaasClient: jest.fn().mockImplementation((opts: any) => {
      mockClientOptions.push(opts);
      return mockClient;
    }),
  };
});

import { randomBytes } from 'node:crypto';
import { read, resetFakeDb, seed } from './fake-firestore';
import { AsaasApiError } from '../asaas-client';
import { decryptSecret, encryptSecret, hashToken } from '../crypto';
import { connectAsaas, disconnectAsaas, getPaymentSettings } from '../connection.service';

const MASTER_KEY = randomBytes(32).toString('base64');
const USER = { id: 'u1', name: 'Ana', email: 'ana@oficina.com' };

describe('connection.service', () => {
  beforeEach(() => {
    resetFakeDb();
    jest.clearAllMocks();
    mockClientOptions.length = 0;
    process.env.ASAAS_CREDENTIALS_KEY = MASTER_KEY;
    process.env.ASAAS_WEBHOOK_BASE_URL = 'https://example.test/api/';
    mockClient.getMyAccount.mockResolvedValue({ name: 'Ana Silva', tradingName: 'Oficina da Ana', email: 'conta@asaas.com' });
    mockClient.getWallets.mockResolvedValue([{ id: 'wallet_1' }]);
    mockClient.createWebhook.mockResolvedValue({ id: 'wh_1' });
    mockClient.deleteWebhook.mockResolvedValue(undefined);
  });

  afterAll(() => {
    delete process.env.ASAAS_CREDENTIALS_KEY;
    delete process.env.ASAAS_WEBHOOK_BASE_URL;
  });

  describe('connectAsaas', () => {
    it('exige asaasEnabled', async () => {
      const error = await connectAsaas('c1', '$aact_hmlg_k', USER).catch((e) => e);
      expect(error.code).toBe('ASAAS_NOT_ENABLED');
      expect(mockClient.getMyAccount).not.toHaveBeenCalled();
    });

    it('rejeita chave sem prefixo do Asaas sem chamar a API', async () => {
      seed('companies/c1/settings/payments', { asaasEnabled: true, asaasConnected: false });
      const error = await connectAsaas('c1', 'abc', USER).catch((e) => e);
      expect(error.code).toBe('ASAAS_INVALID_API_KEY');
      expect(mockClient.getMyAccount).not.toHaveBeenCalled();
    });

    it('chave recusada pelo Asaas → ASAAS_INVALID_API_KEY e nada gravado', async () => {
      seed('companies/c1/settings/payments', { asaasEnabled: true, asaasConnected: false });
      mockClient.getMyAccount.mockRejectedValue(new AsaasApiError(401, [], '/myAccount/commercialInfo'));

      const error = await connectAsaas('c1', '$aact_hmlg_k', USER).catch((e) => e);

      expect(error.code).toBe('ASAAS_INVALID_API_KEY');
      expect(read('companies/c1/private/asaas')).toBeUndefined();
      expect(read('companies/c1/settings/payments')).toEqual({ asaasEnabled: true, asaasConnected: false });
      expect(mockClient.createWebhook).not.toHaveBeenCalled();
    });

    it('chave válida de sandbox: cria webhook, criptografa e grava settings', async () => {
      seed('companies/c1/settings/payments', { asaasEnabled: true, asaasConnected: false });

      const settings = await connectAsaas('c1', '  $aact_hmlg_k  ', USER);

      expect(settings).toEqual({
        asaasEnabled: true,
        asaasConnected: true,
        asaasAccountName: 'Oficina da Ana',
        asaasEnvironment: 'sandbox',
      });
      expect(mockClientOptions[0]).toEqual({ apiKey: '$aact_hmlg_k', environment: 'sandbox' });

      const webhookInput = mockClient.createWebhook.mock.calls[0][0];
      expect(webhookInput).toMatchObject({
        name: 'PraticOS',
        url: 'https://example.test/api/webhooks/asaas/c1',
        email: 'ana@oficina.com',
        enabled: true,
        interrupted: false,
        apiVersion: 3,
        sendType: 'SEQUENTIALLY',
        events: ['PAYMENT_RECEIVED', 'PAYMENT_CONFIRMED', 'PAYMENT_OVERDUE', 'PAYMENT_REFUNDED', 'PAYMENT_DELETED'],
      });
      expect(webhookInput.authToken).toMatch(/^[A-Za-z0-9_-]{64}$/);

      const stored = read('companies/c1/private/asaas')!;
      expect(stored).toMatchObject({
        mode: 'apiKey',
        environment: 'sandbox',
        accountName: 'Oficina da Ana',
        walletId: 'wallet_1',
        webhookId: 'wh_1',
        status: 'active',
        connectedBy: { id: 'u1', name: 'Ana' },
      });
      expect(stored.webhookTokenHash).toBe(hashToken(webhookInput.authToken));
      expect(JSON.stringify(stored)).not.toContain('aact');
      expect(decryptSecret(stored.encryptedApiKey, MASTER_KEY)).toBe('$aact_hmlg_k');
      expect(read('companies/c1/settings/payments')).toEqual(settings);
    });

    it('infere produção pelo prefixo', async () => {
      seed('companies/c1/settings/payments', { asaasEnabled: true });
      const settings = await connectAsaas('c1', '$aact_prod_k', USER);
      expect(settings.asaasEnvironment).toBe('production');
      expect(mockClientOptions[0].environment).toBe('production');
    });

    it('usa email do documento do usuário quando não vem no contexto', async () => {
      seed('companies/c1/settings/payments', { asaasEnabled: true });
      seed('users/u1', { email: 'doc@oficina.com' });
      await connectAsaas('c1', '$aact_hmlg_k', { id: 'u1', name: 'Ana' });
      expect(mockClient.createWebhook.mock.calls[0][0].email).toBe('doc@oficina.com');
    });

    it('usa email da conta Asaas como último recurso', async () => {
      seed('companies/c1/settings/payments', { asaasEnabled: true });
      await connectAsaas('c1', '$aact_hmlg_k', { id: 'u1', name: 'Ana' });
      expect(mockClient.createWebhook.mock.calls[0][0].email).toBe('conta@asaas.com');
    });

    it('reconectar remove o webhook anterior', async () => {
      seed('companies/c1/settings/payments', { asaasEnabled: true, asaasConnected: true });
      seed('companies/c1/private/asaas', {
        mode: 'apiKey',
        environment: 'sandbox',
        encryptedApiKey: encryptSecret('$aact_hmlg_old', MASTER_KEY),
        webhookId: 'wh_old',
        status: 'active',
      });

      await connectAsaas('c1', '$aact_hmlg_new', USER);

      expect(mockClient.deleteWebhook).toHaveBeenCalledWith('wh_old');
      expect(read('companies/c1/private/asaas')!.webhookId).toBe('wh_1');
    });
  });

  describe('disconnectAsaas', () => {
    it('remove webhook, credencial e mapeamentos e marca desconectado', async () => {
      seed('companies/c1/settings/payments', {
        asaasEnabled: true,
        asaasConnected: true,
        asaasAccountName: 'Oficina',
        asaasEnvironment: 'sandbox',
      });
      seed('companies/c1/private/asaas', {
        mode: 'apiKey',
        environment: 'sandbox',
        encryptedApiKey: encryptSecret('$aact_hmlg_k', MASTER_KEY),
        webhookId: 'wh_1',
        status: 'active',
      });
      seed('companies/c1/private/asaas/customers/cust1', { asaasCustomerId: 'cus_1' });

      await disconnectAsaas('c1');

      expect(mockClientOptions[0]).toMatchObject({ apiKey: '$aact_hmlg_k', environment: 'sandbox' });
      expect(mockClient.deleteWebhook).toHaveBeenCalledWith('wh_1');
      expect(read('companies/c1/private/asaas')).toBeUndefined();
      expect(read('companies/c1/private/asaas/customers/cust1')).toBeUndefined();
      expect(read('companies/c1/settings/payments')).toEqual({ asaasEnabled: true, asaasConnected: false });
    });

    it('desconecta mesmo se o Asaas recusar a remoção do webhook', async () => {
      seed('companies/c1/settings/payments', { asaasEnabled: true, asaasConnected: true });
      seed('companies/c1/private/asaas', {
        mode: 'apiKey',
        environment: 'sandbox',
        encryptedApiKey: encryptSecret('$aact_hmlg_k', MASTER_KEY),
        webhookId: 'wh_1',
        status: 'active',
      });
      mockClient.deleteWebhook.mockRejectedValue(new AsaasApiError(401, [], '/webhooks/wh_1'));

      await disconnectAsaas('c1');

      expect(read('companies/c1/private/asaas')).toBeUndefined();
      expect(read('companies/c1/settings/payments')!.asaasConnected).toBe(false);
    });
  });

  it('getPaymentSettings devolve falso sem documento', async () => {
    expect(await getPaymentSettings('c1')).toEqual({ asaasEnabled: false, asaasConnected: false });
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
cd /Users/rafaeldl/Projetos/praticOSopen/.claude/worktrees/bold-sutherland-509639/firebase/functions
npx jest src/services/asaas/__tests__/connection.service.test.ts
```

Esperado: FAIL com `Cannot find module '../connection.service'`.

- [ ] **Step 3: Implementar** — `firebase/functions/src/services/asaas/connection.service.ts`

```ts
/**
 * Connects / disconnects a company's Asaas account (API key mode).
 * The key is validated against Asaas, encrypted (AES-256-GCM) and stored in
 * companies/{cid}/private/asaas; a webhook is registered with a random token
 * stored only as SHA-256.
 */

import { randomBytes } from 'node:crypto';
import { db } from '../firestore.service';
import { UserAggr } from '../../models/types';
import {
  AsaasConnectionDoc,
  AsaasCreateWebhookInput,
  PaymentSettingsDoc,
} from '../../models/asaas.types';
import { AsaasApiError, AsaasClient, environmentFromApiKey } from './asaas-client';
import { encryptSecret, hashToken, readMasterKeyFromEnv } from './crypto';
import { asaasConnectionRef, clientFromConnection } from './credential-provider';
import { AsaasServiceError } from './errors';

const DEFAULT_WEBHOOK_BASE_URL = 'https://southamerica-east1-praticos.cloudfunctions.net/api';

export const ASAAS_WEBHOOK_EVENTS: AsaasCreateWebhookInput['events'] = [
  'PAYMENT_RECEIVED',
  'PAYMENT_CONFIRMED',
  'PAYMENT_OVERDUE',
  'PAYMENT_REFUNDED',
  'PAYMENT_DELETED',
];

export function paymentSettingsRef(companyId: string) {
  return db.collection('companies').doc(companyId).collection('settings').doc('payments');
}

export function webhookUrl(companyId: string): string {
  const base = (process.env.ASAAS_WEBHOOK_BASE_URL || DEFAULT_WEBHOOK_BASE_URL).replace(/\/+$/, '');
  return `${base}/webhooks/asaas/${companyId}`;
}

export async function getPaymentSettings(companyId: string): Promise<PaymentSettingsDoc> {
  const snapshot = await paymentSettingsRef(companyId).get();
  const data = (snapshot.data() || {}) as Partial<PaymentSettingsDoc>;
  const settings: PaymentSettingsDoc = {
    asaasEnabled: data.asaasEnabled === true,
    asaasConnected: data.asaasConnected === true,
  };
  if (data.asaasAccountName) settings.asaasAccountName = data.asaasAccountName;
  if (data.asaasEnvironment) settings.asaasEnvironment = data.asaasEnvironment;
  return settings;
}

async function resolveWebhookEmail(
  user: UserAggr & { email?: string },
  accountEmail: string | undefined,
): Promise<string> {
  if (user.email) return user.email;
  const userDoc = await db.collection('users').doc(user.id).get();
  const email = userDoc.data()?.email as string | undefined;
  if (email) return email;
  if (accountEmail) return accountEmail;
  throw new AsaasServiceError('ASAAS_VALIDATION_ERROR', 'An email is required to register the Asaas webhook');
}

/** Best effort: removes the webhook of a stored connection. Never throws. */
async function deleteStoredWebhook(companyId: string, connection: AsaasConnectionDoc): Promise<void> {
  if (!connection.webhookId) return;
  try {
    const client = clientFromConnection(connection, readMasterKeyFromEnv());
    await client.deleteWebhook(connection.webhookId);
  } catch (error) {
    const status = error instanceof AsaasApiError ? error.status : 'unknown';
    console.warn(`[Asaas] Could not delete webhook of company ${companyId} (status ${status})`);
  }
}

export async function connectAsaas(
  companyId: string,
  apiKey: string,
  user: UserAggr & { email?: string },
): Promise<PaymentSettingsDoc> {
  const settings = await getPaymentSettings(companyId);
  if (!settings.asaasEnabled) {
    throw new AsaasServiceError('ASAAS_NOT_ENABLED', 'Asaas is not enabled for this company');
  }

  const key = (apiKey || '').trim();
  const environment = environmentFromApiKey(key);
  if (!environment) {
    throw new AsaasServiceError('ASAAS_INVALID_API_KEY', 'Invalid Asaas API key');
  }

  const client = new AsaasClient({ apiKey: key, environment });

  let account;
  try {
    account = await client.getMyAccount();
  } catch (error) {
    if (error instanceof AsaasApiError && (error.status === 401 || error.status === 403)) {
      throw new AsaasServiceError('ASAAS_INVALID_API_KEY', 'Invalid Asaas API key');
    }
    throw error;
  }

  const wallets = await client.getWallets();
  const accountName = account.tradingName || account.companyName || account.name || '';
  const email = await resolveWebhookEmail(user, account.email);
  const masterKey = readMasterKeyFromEnv();

  const connectionRef = asaasConnectionRef(companyId);
  const existing = await connectionRef.get();
  if (existing.exists) {
    await deleteStoredWebhook(companyId, existing.data() as AsaasConnectionDoc);
  }

  const authToken = randomBytes(48).toString('base64url');
  const webhook = await client.createWebhook({
    name: 'PraticOS',
    url: webhookUrl(companyId),
    email,
    enabled: true,
    interrupted: false,
    apiVersion: 3,
    sendType: 'SEQUENTIALLY',
    authToken,
    events: ASAAS_WEBHOOK_EVENTS,
  });

  const connection: AsaasConnectionDoc = {
    mode: 'apiKey',
    environment,
    encryptedApiKey: encryptSecret(key, masterKey),
    accountName,
    webhookId: webhook.id,
    webhookTokenHash: hashToken(authToken),
    status: 'active',
    connectedBy: { id: user.id, name: user.name },
    connectedAt: new Date().toISOString(),
  };
  if (wallets[0]?.id) connection.walletId = wallets[0].id;

  const newSettings: PaymentSettingsDoc = {
    asaasEnabled: true,
    asaasConnected: true,
    asaasAccountName: accountName,
    asaasEnvironment: environment,
  };

  try {
    const batch = db.batch();
    batch.set(connectionRef, connection);
    batch.set(paymentSettingsRef(companyId), newSettings);
    await batch.commit();
  } catch (error) {
    await client.deleteWebhook(webhook.id).catch(() => undefined);
    throw error;
  }

  console.log(`[Asaas] Company ${companyId} connected (${environment})`);
  return newSettings;
}

export async function disconnectAsaas(companyId: string): Promise<void> {
  const connectionRef = asaasConnectionRef(companyId);
  const snapshot = await connectionRef.get();
  if (snapshot.exists) {
    await deleteStoredWebhook(companyId, snapshot.data() as AsaasConnectionDoc);
  }

  // Removes the credential and the server-only subcollections (customers map, events).
  await db.recursiveDelete(connectionRef);

  const settings = await getPaymentSettings(companyId);
  await paymentSettingsRef(companyId).set({
    asaasEnabled: settings.asaasEnabled,
    asaasConnected: false,
  });

  console.log(`[Asaas] Company ${companyId} disconnected`);
}
```

- [ ] **Step 4: Rodar os testes**

```bash
npx jest src/services/asaas && npm run lint && npm run build
```

Esperado: PASS (connection.service: 11 testes), lint sem erros, build ok.

- [ ] **Step 5: Commit**

```bash
cd /Users/rafaeldl/Projetos/praticOSopen/.claude/worktrees/bold-sutherland-509639
git add firebase/functions/src/services/asaas/connection.service.ts firebase/functions/src/services/asaas/__tests__/connection.service.test.ts
git commit -F - <<'EOF'
feat(payments): connect and disconnect Asaas account with webhook

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

### Task B5: Validação de CPF/CNPJ e charge.service

**Files:**
- Create: `firebase/functions/src/utils/tax-id.utils.ts`
- Create: `firebase/functions/src/services/asaas/charge.service.ts`
- Test: `firebase/functions/src/utils/tax-id.utils.test.ts`
- Test: `firebase/functions/src/services/asaas/__tests__/charge.service.test.ts`

**Interfaces:**
- Consumes: `calculateRemainingBalance(order: Order)` de `firebase/functions/src/services/order.service.ts` (linha 638; corrigida pelo Bloco A para `total - paidAmount`); `getAsaasCredentialProvider`, `AsaasServiceError` (B3); `getPaymentSettings` (B4); `AsaasApiError`, `AsaasClient` (B2).
- Produces: `onlyDigits`, `isValidCpf`, `isValidCnpj`, `isValidTaxId`; `createOrderCharge(companyId, orderId, input: CreateChargeInput, user: UserAggr): Promise<OrderCharge>`, `cancelOrderCharge(companyId, orderId, chargeId): Promise<OrderCharge>`, `cancelOpenChargesForOrder(companyId, orderId): Promise<void>`, `getOpenOrLatestPaidCharge(companyId, orderId): Promise<OrderCharge | null>`, `handleOrderStatusChange(companyId, orderId, beforeStatus?, afterStatus?): Promise<void>`, `chargesRef(companyId, orderId)`, `todayInSaoPaulo(now?)`, `addDays(date, days)`, `defaultDueDate(now?)`.

Regras implementadas em `createOrderCharge` (nesta ordem):
1. `settings/payments.asaasConnected` (senão `ASAAS_NOT_CONNECTED`); OS existe (`ORDER_NOT_FOUND`) e não está `canceled` (`ORDER_CANCELED`).
2. `value` arredondado a centavos, `0 < value <= saldo restante` (tolerância de meio centavo) → `INVALID_VALUE`; `cardInstallments` exige `installmentCount` inteiro 2–12 → `INVALID_INSTALLMENT_COUNT`; `dueDate` `YYYY-MM-DD` ≥ hoje em `America/Sao_Paulo`, default hoje + 3 → `INVALID_DUE_DATE`.
3. OS precisa de cliente (`CUSTOMER_REQUIRED`). CPF/CNPJ: `customerTaxId` do corpo, se vier, é validado (`INVALID_TAX_ID`) e salvo no cliente só com dígitos; senão usa `customer.taxId` (`TAX_ID_REQUIRED` se faltar).
4. Cancela no Asaas e marca `canceled` toda cobrança `pending`/`overdue` da OS (404 do Asaas conta como já cancelada).
5. Find-or-create do cliente Asaas: mapa `private/asaas/customers/{customerId}` → `findCustomerByExternalReference(customerId)` → `createCustomer({ name, cpfCnpj, email (se válido), externalReference: customerId, notificationDisabled: true })`; grava o mapa.
6. `createPayment`: `single` → `billingType: 'UNDEFINED'` + `value`; `cardInstallments` → `billingType: 'CREDIT_CARD'` + `installmentCount` + `totalValue`. `description: 'OS #<number> - <nome da empresa>'`, `externalReference: '<companyId>:<orderId>:<chargeId>'` (id do doc gerado antes da chamada).
7. Grava o `OrderCharge` (`status: 'pending'`, `paidAsaasPaymentIds: []`, `asaasInstallmentId = payment.installment` no parcelado). Se a gravação falhar, cancela a cobrança recém-criada no Asaas.

`cancelOrderCharge` usa `deleteInstallment` quando há `asaasInstallmentId`, senão `deletePayment`; só aceita `pending`/`overdue` (`CHARGE_NOT_OPEN`). `handleOrderStatusChange` só age quando o status muda para `canceled` e a empresa tem `asaasConnected`.

- [ ] **Step 1: Escrever os testes que falham**

`firebase/functions/src/utils/tax-id.utils.test.ts`:

```ts
import { isValidCnpj, isValidCpf, isValidTaxId, onlyDigits } from './tax-id.utils';

describe('tax-id.utils', () => {
  it('onlyDigits remove máscara', () => {
    expect(onlyDigits('529.982.247-25')).toBe('52998224725');
    expect(onlyDigits(undefined)).toBe('');
  });

  it('valida CPF', () => {
    expect(isValidCpf('529.982.247-25')).toBe(true);
    expect(isValidCpf('52998224724')).toBe(false);
    expect(isValidCpf('11111111111')).toBe(false);
    expect(isValidCpf('123')).toBe(false);
  });

  it('valida CNPJ', () => {
    expect(isValidCnpj('11.222.333/0001-81')).toBe(true);
    expect(isValidCnpj('11222333000180')).toBe(false);
    expect(isValidCnpj('00000000000000')).toBe(false);
  });

  it('isValidTaxId escolhe pelo tamanho', () => {
    expect(isValidTaxId('52998224725')).toBe(true);
    expect(isValidTaxId('11222333000181')).toBe(true);
    expect(isValidTaxId('5299822472')).toBe(false);
  });
});
```

`firebase/functions/src/services/asaas/__tests__/charge.service.test.ts`:

```ts
jest.mock('../../firestore.service', () => jest.requireActual('./fake-firestore').firestoreServiceMock);

import { list, read, resetFakeDb, seed } from './fake-firestore';
import { AsaasApiError } from '../asaas-client';
import { setAsaasCredentialProvider } from '../credential-provider';
import {
  addDays,
  cancelOpenChargesForOrder,
  cancelOrderCharge,
  createOrderCharge,
  defaultDueDate,
  getOpenOrLatestPaidCharge,
  handleOrderStatusChange,
  todayInSaoPaulo,
} from '../charge.service';

const USER = { id: 'u1', name: 'Ana' };
const CPF = '52998224725';
const ORDER_PATH = 'companies/c1/orders/o1';

const client = {
  findCustomerByExternalReference: jest.fn(),
  createCustomer: jest.fn(),
  createPayment: jest.fn(),
  deletePayment: jest.fn(),
  deleteInstallment: jest.fn(),
};

function seedBase(options: { taxId?: string; order?: Record<string, unknown>; connected?: boolean } = {}) {
  seed('companies/c1', { name: 'Oficina da Ana' });
  seed('companies/c1/settings/payments', { asaasEnabled: true, asaasConnected: options.connected ?? true });
  seed('companies/c1/customers/cust1', {
    name: 'João',
    email: 'joao@cliente.com',
    ...(options.taxId !== undefined ? { taxId: options.taxId } : {}),
  });
  seed(ORDER_PATH, {
    number: 42,
    status: 'approved',
    total: 1000,
    discount: 0,
    paidAmount: 0,
    customer: { id: 'cust1', name: 'João' },
    ...options.order,
  });
}

function seedCharge(id: string, data: Record<string, unknown>) {
  seed(`${ORDER_PATH}/charges/${id}`, {
    id,
    asaasPaymentId: `pay_${id}`,
    mode: 'single',
    value: 100,
    dueDate: '2026-10-07',
    status: 'pending',
    invoiceUrl: `https://sandbox.asaas.com/i/${id}`,
    paidAsaasPaymentIds: [],
    createdBy: USER,
    createdAt: '2026-10-04T10:00:00.000Z',
    ...data,
  });
}

describe('charge.service', () => {
  beforeEach(() => {
    resetFakeDb();
    jest.clearAllMocks();
    setAsaasCredentialProvider({ getClient: async () => client as any });
    client.findCustomerByExternalReference.mockResolvedValue(null);
    client.createCustomer.mockResolvedValue({ id: 'cus_1', name: 'João' });
    client.createPayment.mockResolvedValue({
      id: 'pay_1',
      invoiceUrl: 'https://sandbox.asaas.com/i/pay_1',
      status: 'PENDING',
      installment: null,
    });
    client.deletePayment.mockResolvedValue(undefined);
    client.deleteInstallment.mockResolvedValue(undefined);
  });

  afterAll(() => setAsaasCredentialProvider(null));

  describe('datas', () => {
    it('hoje em America/Sao_Paulo', () => {
      // 02:00 UTC de 5/out = 23:00 de 4/out em São Paulo
      expect(todayInSaoPaulo(new Date('2026-10-05T02:00:00.000Z'))).toBe('2026-10-04');
    });

    it('vencimento padrão é hoje + 3 dias', () => {
      expect(defaultDueDate(new Date('2026-10-30T15:00:00.000Z'))).toBe('2026-11-02');
      expect(addDays('2026-12-30', 3)).toBe('2027-01-02');
    });
  });

  describe('createOrderCharge', () => {
    it('à vista: cria cliente, cobrança UNDEFINED e grava o documento', async () => {
      seedBase({ taxId: CPF });

      const charge = await createOrderCharge('c1', 'o1', { value: 1000, mode: 'single' }, USER);

      expect(client.createCustomer).toHaveBeenCalledWith({
        name: 'João',
        cpfCnpj: CPF,
        email: 'joao@cliente.com',
        externalReference: 'cust1',
        notificationDisabled: true,
      });
      expect(read('companies/c1/private/asaas/customers/cust1')).toEqual({ asaasCustomerId: 'cus_1' });

      const paymentInput = client.createPayment.mock.calls[0][0];
      expect(paymentInput).toEqual({
        customer: 'cus_1',
        billingType: 'UNDEFINED',
        value: 1000,
        dueDate: defaultDueDate(),
        description: 'OS #42 - Oficina da Ana',
        externalReference: `c1:o1:${charge.id}`,
      });

      expect(charge).toMatchObject({
        asaasPaymentId: 'pay_1',
        mode: 'single',
        value: 1000,
        status: 'pending',
        invoiceUrl: 'https://sandbox.asaas.com/i/pay_1',
        paidAsaasPaymentIds: [],
        createdBy: USER,
      });
      expect(read(`${ORDER_PATH}/charges/${charge.id}`)).toEqual(charge);
    });

    it('parcelado no cartão: CREDIT_CARD + installmentCount + totalValue', async () => {
      seedBase({ taxId: CPF });
      client.createPayment.mockResolvedValue({
        id: 'pay_1',
        invoiceUrl: 'https://sandbox.asaas.com/i/pay_1',
        installment: 'ins_1',
      });

      const charge = await createOrderCharge(
        'c1',
        'o1',
        { value: 700, mode: 'cardInstallments', installmentCount: 3, dueDate: '2099-01-10' },
        USER,
      );

      const paymentInput = client.createPayment.mock.calls[0][0];
      expect(paymentInput).toMatchObject({
        billingType: 'CREDIT_CARD',
        installmentCount: 3,
        totalValue: 700,
        dueDate: '2099-01-10',
      });
      expect(paymentInput.value).toBeUndefined();
      expect(charge).toMatchObject({ mode: 'cardInstallments', installmentCount: 3, asaasInstallmentId: 'ins_1' });
    });

    it('reusa o cliente mapeado sem chamar o Asaas', async () => {
      seedBase({ taxId: CPF });
      seed('companies/c1/private/asaas/customers/cust1', { asaasCustomerId: 'cus_mapped' });

      await createOrderCharge('c1', 'o1', { value: 100, mode: 'single' }, USER);

      expect(client.findCustomerByExternalReference).not.toHaveBeenCalled();
      expect(client.createCustomer).not.toHaveBeenCalled();
      expect(client.createPayment.mock.calls[0][0].customer).toBe('cus_mapped');
    });

    it('acha cliente existente no Asaas pelo externalReference', async () => {
      seedBase({ taxId: CPF });
      client.findCustomerByExternalReference.mockResolvedValue({ id: 'cus_existing', name: 'João' });

      await createOrderCharge('c1', 'o1', { value: 100, mode: 'single' }, USER);

      expect(client.findCustomerByExternalReference).toHaveBeenCalledWith('cust1');
      expect(client.createCustomer).not.toHaveBeenCalled();
      expect(read('companies/c1/private/asaas/customers/cust1')).toEqual({ asaasCustomerId: 'cus_existing' });
    });

    it('valor acima do saldo restante → INVALID_VALUE', async () => {
      seedBase({ taxId: CPF, order: { paidAmount: 300 } });
      const error = await createOrderCharge('c1', 'o1', { value: 700.01, mode: 'single' }, USER).catch((e) => e);
      expect(error.code).toBe('INVALID_VALUE');
      expect(client.createPayment).not.toHaveBeenCalled();
    });

    it('valor zero → INVALID_VALUE', async () => {
      seedBase({ taxId: CPF });
      const error = await createOrderCharge('c1', 'o1', { value: 0, mode: 'single' }, USER).catch((e) => e);
      expect(error.code).toBe('INVALID_VALUE');
    });

    it('parcelas fora de 2–12 → INVALID_INSTALLMENT_COUNT', async () => {
      seedBase({ taxId: CPF });
      for (const installmentCount of [1, 13, undefined]) {
        const error = await createOrderCharge(
          'c1', 'o1', { value: 100, mode: 'cardInstallments', installmentCount }, USER,
        ).catch((e) => e);
        expect(error.code).toBe('INVALID_INSTALLMENT_COUNT');
      }
    });

    it('vencimento no passado → INVALID_DUE_DATE', async () => {
      seedBase({ taxId: CPF });
      const error = await createOrderCharge(
        'c1', 'o1', { value: 100, mode: 'single', dueDate: '2020-01-01' }, USER,
      ).catch((e) => e);
      expect(error.code).toBe('INVALID_DUE_DATE');
    });

    it('conta não conectada → ASAAS_NOT_CONNECTED', async () => {
      seedBase({ taxId: CPF, connected: false });
      const error = await createOrderCharge('c1', 'o1', { value: 100, mode: 'single' }, USER).catch((e) => e);
      expect(error.code).toBe('ASAAS_NOT_CONNECTED');
    });

    it('OS inexistente → ORDER_NOT_FOUND', async () => {
      seedBase({ taxId: CPF });
      const error = await createOrderCharge('c1', 'nope', { value: 100, mode: 'single' }, USER).catch((e) => e);
      expect(error.code).toBe('ORDER_NOT_FOUND');
    });

    it('OS cancelada → ORDER_CANCELED', async () => {
      seedBase({ taxId: CPF, order: { status: 'canceled' } });
      const error = await createOrderCharge('c1', 'o1', { value: 100, mode: 'single' }, USER).catch((e) => e);
      expect(error.code).toBe('ORDER_CANCELED');
    });

    it('OS sem cliente → CUSTOMER_REQUIRED', async () => {
      seedBase({ taxId: CPF, order: { customer: null } });
      const error = await createOrderCharge('c1', 'o1', { value: 100, mode: 'single' }, USER).catch((e) => e);
      expect(error.code).toBe('CUSTOMER_REQUIRED');
    });

    it('cliente sem taxId e sem customerTaxId → TAX_ID_REQUIRED', async () => {
      seedBase();
      const error = await createOrderCharge('c1', 'o1', { value: 100, mode: 'single' }, USER).catch((e) => e);
      expect(error.code).toBe('TAX_ID_REQUIRED');
      expect(client.createPayment).not.toHaveBeenCalled();
    });

    it('customerTaxId inválido → INVALID_TAX_ID', async () => {
      seedBase();
      const error = await createOrderCharge(
        'c1', 'o1', { value: 100, mode: 'single', customerTaxId: '111.111.111-11' }, USER,
      ).catch((e) => e);
      expect(error.code).toBe('INVALID_TAX_ID');
    });

    it('customerTaxId válido é salvo no cliente (só dígitos)', async () => {
      seedBase();
      await createOrderCharge('c1', 'o1', { value: 100, mode: 'single', customerTaxId: '529.982.247-25' }, USER);
      expect(read('companies/c1/customers/cust1')!.taxId).toBe(CPF);
      expect(client.createCustomer.mock.calls[0][0].cpfCnpj).toBe(CPF);
    });

    it('cancela a cobrança aberta anterior antes de criar outra', async () => {
      seedBase({ taxId: CPF });
      seedCharge('old', { status: 'pending' });
      seedCharge('oldInst', { status: 'overdue', mode: 'cardInstallments', asaasInstallmentId: 'ins_old' });
      seedCharge('paid', { status: 'paid' });

      await createOrderCharge('c1', 'o1', { value: 100, mode: 'single' }, USER);

      expect(client.deletePayment).toHaveBeenCalledWith('pay_old');
      expect(client.deleteInstallment).toHaveBeenCalledWith('ins_old');
      expect(read(`${ORDER_PATH}/charges/old`)!.status).toBe('canceled');
      expect(read(`${ORDER_PATH}/charges/oldInst`)!.status).toBe('canceled');
      expect(read(`${ORDER_PATH}/charges/paid`)!.status).toBe('paid');
      expect(list(`${ORDER_PATH}/charges`).filter((c) => c.data.status === 'pending')).toHaveLength(1);
    });
  });

  describe('cancelOrderCharge', () => {
    it('cancela cobrança à vista com deletePayment', async () => {
      seedBase({ taxId: CPF });
      seedCharge('ch1', {});

      const charge = await cancelOrderCharge('c1', 'o1', 'ch1');

      expect(client.deletePayment).toHaveBeenCalledWith('pay_ch1');
      expect(charge.status).toBe('canceled');
      expect(read(`${ORDER_PATH}/charges/ch1`)!.status).toBe('canceled');
    });

    it('cancela parcelamento com deleteInstallment', async () => {
      seedBase({ taxId: CPF });
      seedCharge('ch1', { mode: 'cardInstallments', asaasInstallmentId: 'ins_1' });

      await cancelOrderCharge('c1', 'o1', 'ch1');

      expect(client.deleteInstallment).toHaveBeenCalledWith('ins_1');
      expect(client.deletePayment).not.toHaveBeenCalled();
    });

    it('404 no Asaas conta como já cancelada', async () => {
      seedBase({ taxId: CPF });
      seedCharge('ch1', {});
      client.deletePayment.mockRejectedValue(new AsaasApiError(404, [], '/payments/pay_ch1'));

      const charge = await cancelOrderCharge('c1', 'o1', 'ch1');

      expect(charge.status).toBe('canceled');
    });

    it('cobrança inexistente → CHARGE_NOT_FOUND', async () => {
      seedBase({ taxId: CPF });
      const error = await cancelOrderCharge('c1', 'o1', 'nope').catch((e) => e);
      expect(error.code).toBe('CHARGE_NOT_FOUND');
    });

    it('cobrança paga → CHARGE_NOT_OPEN', async () => {
      seedBase({ taxId: CPF });
      seedCharge('ch1', { status: 'paid' });
      const error = await cancelOrderCharge('c1', 'o1', 'ch1').catch((e) => e);
      expect(error.code).toBe('CHARGE_NOT_OPEN');
      expect(client.deletePayment).not.toHaveBeenCalled();
    });
  });

  describe('cancelOpenChargesForOrder / handleOrderStatusChange', () => {
    it('cancela todas as abertas e continua se uma falhar', async () => {
      seedBase({ taxId: CPF });
      seedCharge('a', {});
      seedCharge('b', {});
      client.deletePayment.mockImplementation(async (id: string) => {
        if (id === 'pay_a') throw new AsaasApiError(500, [], '/payments/pay_a');
      });
      const errorSpy = jest.spyOn(console, 'error').mockImplementation(() => undefined);

      await cancelOpenChargesForOrder('c1', 'o1');

      expect(read(`${ORDER_PATH}/charges/a`)!.status).toBe('pending');
      expect(read(`${ORDER_PATH}/charges/b`)!.status).toBe('canceled');
      expect(errorSpy).toHaveBeenCalled();
      errorSpy.mockRestore();
    });

    it('OS mudou para canceled com Asaas conectado → cancela', async () => {
      seedBase({ taxId: CPF });
      seedCharge('a', {});
      await handleOrderStatusChange('c1', 'o1', 'approved', 'canceled');
      expect(read(`${ORDER_PATH}/charges/a`)!.status).toBe('canceled');
    });

    it('ignora quando não mudou para canceled ou Asaas desconectado', async () => {
      seedBase({ taxId: CPF, connected: false });
      seedCharge('a', {});
      await handleOrderStatusChange('c1', 'o1', 'approved', 'canceled');
      await handleOrderStatusChange('c1', 'o1', 'canceled', 'canceled');
      await handleOrderStatusChange('c1', 'o1', 'approved', 'done');
      expect(client.deletePayment).not.toHaveBeenCalled();
    });
  });

  describe('getOpenOrLatestPaidCharge', () => {
    it('prefere a aberta; senão a última paga; senão null', async () => {
      expect(await getOpenOrLatestPaidCharge('c1', 'o1')).toBeNull();

      seedCharge('paid1', { status: 'paid', paidAt: '2026-10-01T10:00:00.000Z' });
      seedCharge('paid2', { status: 'paid', paidAt: '2026-10-02T10:00:00.000Z' });
      seedCharge('canceled', { status: 'canceled', createdAt: '2026-10-05T10:00:00.000Z' });
      expect((await getOpenOrLatestPaidCharge('c1', 'o1'))!.id).toBe('paid2');

      seedCharge('open', { status: 'overdue' });
      expect((await getOpenOrLatestPaidCharge('c1', 'o1'))!.id).toBe('open');
    });
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
cd /Users/rafaeldl/Projetos/praticOSopen/.claude/worktrees/bold-sutherland-509639/firebase/functions
npx jest src/utils/tax-id.utils.test.ts src/services/asaas/__tests__/charge.service.test.ts
```

Esperado: FAIL com `Cannot find module './tax-id.utils'` e `Cannot find module '../charge.service'`.

- [ ] **Step 3: Implementar CPF/CNPJ** — `firebase/functions/src/utils/tax-id.utils.ts`

```ts
/**
 * Brazilian CPF / CNPJ helpers (check digits). Mirrors lib/utils/tax_id.dart.
 */

export function onlyDigits(value: string | null | undefined): string {
  return (value || '').replace(/\D/g, '');
}

export function isValidCpf(value: string): boolean {
  const cpf = onlyDigits(value);
  if (cpf.length !== 11 || /^(\d)\1{10}$/.test(cpf)) return false;
  const digits = cpf.split('').map(Number);
  for (const length of [9, 10]) {
    let sum = 0;
    for (let i = 0; i < length; i++) sum += digits[i] * (length + 1 - i);
    const check = ((sum * 10) % 11) % 10;
    if (check !== digits[length]) return false;
  }
  return true;
}

export function isValidCnpj(value: string): boolean {
  const cnpj = onlyDigits(value);
  if (cnpj.length !== 14 || /^(\d)\1{13}$/.test(cnpj)) return false;
  const digits = cnpj.split('').map(Number);
  const weights = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  for (const length of [12, 13]) {
    const w = weights.slice(weights.length - length);
    let sum = 0;
    for (let i = 0; i < length; i++) sum += digits[i] * w[i];
    const rest = sum % 11;
    const check = rest < 2 ? 0 : 11 - rest;
    if (check !== digits[length]) return false;
  }
  return true;
}

export function isValidTaxId(value: string): boolean {
  const digits = onlyDigits(value);
  if (digits.length === 11) return isValidCpf(digits);
  if (digits.length === 14) return isValidCnpj(digits);
  return false;
}
```

- [ ] **Step 4: Implementar cobranças** — `firebase/functions/src/services/asaas/charge.service.ts`

```ts
/**
 * Order charges (cobranças da OS) on the company's Asaas account.
 * companies/{cid}/orders/{oid}/charges/{chargeId} is written only here and by
 * the webhook; it is the source of truth for Asaas payments of the order.
 */

import { db } from '../firestore.service';
import { calculateRemainingBalance } from '../order.service';
import { Customer, Order, UserAggr } from '../../models/types';
import {
  AsaasCreatePaymentInput,
  ChargeStatus,
  CreateChargeInput,
  OrderCharge,
} from '../../models/asaas.types';
import { AsaasApiError, AsaasClient } from './asaas-client';
import { getAsaasCredentialProvider } from './credential-provider';
import { AsaasServiceError } from './errors';
import { getPaymentSettings } from './connection.service';
import { isValidTaxId, onlyDigits } from '../../utils/tax-id.utils';

const OPEN_STATUSES: ChargeStatus[] = ['pending', 'overdue'];
const TIME_ZONE = 'America/Sao_Paulo';
const DEFAULT_DUE_DAYS = 3;
const MIN_INSTALLMENTS = 2;
const MAX_INSTALLMENTS = 12;
const CENT_TOLERANCE = 0.005;

type CustomerWithTaxId = Customer & { taxId?: string | null };

function companyRef(companyId: string) {
  return db.collection('companies').doc(companyId);
}

function orderRef(companyId: string, orderId: string) {
  return companyRef(companyId).collection('orders').doc(orderId);
}

export function chargesRef(companyId: string, orderId: string) {
  return orderRef(companyId, orderId).collection('charges');
}

function asaasCustomerMapRef(companyId: string, customerId: string) {
  return companyRef(companyId)
    .collection('private')
    .doc('asaas')
    .collection('customers')
    .doc(customerId);
}

function roundMoney(value: number): number {
  return Math.round(value * 100) / 100;
}

/** YYYY-MM-DD of `now` in America/Sao_Paulo */
export function todayInSaoPaulo(now: Date = new Date()): string {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(now);
}

export function addDays(date: string, days: number): string {
  const [year, month, day] = date.split('-').map(Number);
  return new Date(Date.UTC(year, month - 1, day + days)).toISOString().slice(0, 10);
}

/** Default due date: today + 3 days in America/Sao_Paulo */
export function defaultDueDate(now: Date = new Date()): string {
  return addDays(todayInSaoPaulo(now), DEFAULT_DUE_DAYS);
}

function isOpen(charge: OrderCharge): boolean {
  return OPEN_STATUSES.includes(charge.status);
}

async function cancelInAsaas(client: AsaasClient, charge: OrderCharge): Promise<void> {
  try {
    if (charge.asaasInstallmentId) {
      await client.deleteInstallment(charge.asaasInstallmentId);
    } else {
      await client.deletePayment(charge.asaasPaymentId);
    }
  } catch (error) {
    // Already removed on Asaas: treat as canceled.
    if (error instanceof AsaasApiError && error.status === 404) return;
    throw error;
  }
}

async function listCharges(companyId: string, orderId: string): Promise<OrderCharge[]> {
  const snapshot = await chargesRef(companyId, orderId).get();
  return snapshot.docs.map((doc) => ({ ...(doc.data() as OrderCharge), id: doc.id }));
}

async function cancelCharge(
  client: AsaasClient,
  companyId: string,
  orderId: string,
  charge: OrderCharge,
): Promise<OrderCharge> {
  await cancelInAsaas(client, charge);
  await chargesRef(companyId, orderId).doc(charge.id).update({ status: 'canceled' });
  return { ...charge, status: 'canceled' };
}

async function resolveTaxId(
  companyId: string,
  customer: CustomerWithTaxId,
  inputTaxId: string | undefined,
): Promise<string> {
  if (inputTaxId !== undefined && onlyDigits(inputTaxId) !== '') {
    const digits = onlyDigits(inputTaxId);
    if (!isValidTaxId(digits)) {
      throw new AsaasServiceError('INVALID_TAX_ID', 'Invalid CPF/CNPJ');
    }
    if (onlyDigits(customer.taxId) !== digits) {
      await companyRef(companyId).collection('customers').doc(customer.id).update({ taxId: digits });
    }
    return digits;
  }

  const stored = onlyDigits(customer.taxId);
  if (!stored) {
    throw new AsaasServiceError('TAX_ID_REQUIRED', 'Customer CPF/CNPJ is required');
  }
  if (!isValidTaxId(stored)) {
    throw new AsaasServiceError('INVALID_TAX_ID', 'Invalid CPF/CNPJ');
  }
  return stored;
}

async function findOrCreateAsaasCustomer(
  client: AsaasClient,
  companyId: string,
  customer: CustomerWithTaxId,
  taxId: string,
): Promise<string> {
  const mapRef = asaasCustomerMapRef(companyId, customer.id);
  const mapped = await mapRef.get();
  const mappedId = mapped.data()?.asaasCustomerId as string | undefined;
  if (mappedId) return mappedId;

  const existing = await client.findCustomerByExternalReference(customer.id);
  let asaasCustomerId = existing?.id;

  if (!asaasCustomerId) {
    const email = customer.email && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(customer.email) ? customer.email : undefined;
    const created = await client.createCustomer({
      name: customer.name,
      cpfCnpj: taxId,
      externalReference: customer.id,
      notificationDisabled: true,
      ...(email ? { email } : {}),
    });
    asaasCustomerId = created.id;
  }

  await mapRef.set({ asaasCustomerId });
  return asaasCustomerId;
}

function validateInput(input: CreateChargeInput, remaining: number): { value: number; dueDate: string } {
  const value = roundMoney(Number(input.value));
  if (!Number.isFinite(value) || value <= 0) {
    throw new AsaasServiceError('INVALID_VALUE', 'Value must be greater than zero');
  }
  if (value > remaining + CENT_TOLERANCE) {
    throw new AsaasServiceError('INVALID_VALUE', 'Value exceeds the order remaining balance');
  }

  if (input.mode === 'cardInstallments') {
    const count = input.installmentCount;
    if (!Number.isInteger(count) || (count as number) < MIN_INSTALLMENTS || (count as number) > MAX_INSTALLMENTS) {
      throw new AsaasServiceError('INVALID_INSTALLMENT_COUNT', 'installmentCount must be between 2 and 12');
    }
  }

  const today = todayInSaoPaulo();
  const dueDate = input.dueDate ?? defaultDueDate();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dueDate) || dueDate < today) {
    throw new AsaasServiceError('INVALID_DUE_DATE', 'dueDate must be today or later (YYYY-MM-DD)');
  }
  return { value, dueDate };
}

export async function createOrderCharge(
  companyId: string,
  orderId: string,
  input: CreateChargeInput,
  user: UserAggr,
): Promise<OrderCharge> {
  const settings = await getPaymentSettings(companyId);
  if (!settings.asaasConnected) {
    throw new AsaasServiceError('ASAAS_NOT_CONNECTED', 'Asaas account is not connected');
  }

  const orderSnap = await orderRef(companyId, orderId).get();
  if (!orderSnap.exists) {
    throw new AsaasServiceError('ORDER_NOT_FOUND', 'Order not found');
  }
  const order = { ...(orderSnap.data() as Order), id: orderSnap.id };
  if (order.status === 'canceled') {
    throw new AsaasServiceError('ORDER_CANCELED', 'Order is canceled');
  }

  const remaining = calculateRemainingBalance({
    ...order,
    total: order.total || 0,
    discount: order.discount || 0,
    paidAmount: order.paidAmount || 0,
  });
  const { value, dueDate } = validateInput(input, remaining);

  const customerId = order.customer?.id;
  if (!customerId) {
    throw new AsaasServiceError('CUSTOMER_REQUIRED', 'Order has no customer');
  }
  const customerSnap = await companyRef(companyId).collection('customers').doc(customerId).get();
  if (!customerSnap.exists) {
    throw new AsaasServiceError('CUSTOMER_REQUIRED', 'Order customer not found');
  }
  const customer = { ...(customerSnap.data() as CustomerWithTaxId), id: customerSnap.id };
  const taxId = await resolveTaxId(companyId, customer, input.customerTaxId);

  const client = await getAsaasCredentialProvider().getClient(companyId);

  // One open charge per order: cancel the previous one first.
  const openCharges = (await listCharges(companyId, orderId)).filter(isOpen);
  for (const charge of openCharges) {
    await cancelCharge(client, companyId, orderId, charge);
  }

  const asaasCustomerId = await findOrCreateAsaasCustomer(client, companyId, customer, taxId);

  const companySnap = await companyRef(companyId).get();
  const companyName = (companySnap.data()?.name as string | undefined) || '';
  const chargeDoc = chargesRef(companyId, orderId).doc();

  const paymentInput: AsaasCreatePaymentInput = {
    customer: asaasCustomerId,
    billingType: input.mode === 'cardInstallments' ? 'CREDIT_CARD' : 'UNDEFINED',
    dueDate,
    description: `OS #${order.number ?? ''} - ${companyName}`,
    externalReference: `${companyId}:${orderId}:${chargeDoc.id}`,
  };
  if (input.mode === 'cardInstallments') {
    paymentInput.installmentCount = input.installmentCount;
    paymentInput.totalValue = value;
  } else {
    paymentInput.value = value;
  }

  const payment = await client.createPayment(paymentInput);

  const charge: OrderCharge = {
    id: chargeDoc.id,
    asaasPaymentId: payment.id,
    mode: input.mode,
    value,
    dueDate,
    status: 'pending',
    invoiceUrl: payment.invoiceUrl,
    paidAsaasPaymentIds: [],
    createdBy: { id: user.id, name: user.name },
    createdAt: new Date().toISOString(),
  };
  if (input.mode === 'cardInstallments') {
    charge.installmentCount = input.installmentCount;
    if (payment.installment) charge.asaasInstallmentId = payment.installment;
  }

  try {
    await chargeDoc.set(charge);
  } catch (error) {
    // Do not leave an orphan charge on Asaas.
    await cancelInAsaas(client, charge).catch(() => undefined);
    throw error;
  }

  console.log(`[Asaas] Charge ${charge.id} created for order ${orderId} of company ${companyId}`);
  return charge;
}

export async function cancelOrderCharge(
  companyId: string,
  orderId: string,
  chargeId: string,
): Promise<OrderCharge> {
  const snapshot = await chargesRef(companyId, orderId).doc(chargeId).get();
  if (!snapshot.exists) {
    throw new AsaasServiceError('CHARGE_NOT_FOUND', 'Charge not found');
  }
  const charge = { ...(snapshot.data() as OrderCharge), id: snapshot.id };
  if (!isOpen(charge)) {
    throw new AsaasServiceError('CHARGE_NOT_OPEN', 'Only pending or overdue charges can be canceled');
  }

  const client = await getAsaasCredentialProvider().getClient(companyId);
  return cancelCharge(client, companyId, orderId, charge);
}

/** Cancels every pending/overdue charge of the order. Logs failures, never throws per charge. */
export async function cancelOpenChargesForOrder(companyId: string, orderId: string): Promise<void> {
  const openCharges = (await listCharges(companyId, orderId)).filter(isOpen);
  if (openCharges.length === 0) return;

  const client = await getAsaasCredentialProvider().getClient(companyId);
  for (const charge of openCharges) {
    try {
      await cancelCharge(client, companyId, orderId, charge);
    } catch (error) {
      const status = error instanceof AsaasApiError ? error.status : 'unknown';
      console.error(`[Asaas] Failed to cancel charge ${charge.id} of order ${orderId} (status ${status})`);
    }
  }
}

/** Open charge (most recent) or, when none, the most recently paid one. */
export async function getOpenOrLatestPaidCharge(
  companyId: string,
  orderId: string,
): Promise<OrderCharge | null> {
  const charges = await listCharges(companyId, orderId);
  const newestFirst = (a: OrderCharge, b: OrderCharge) =>
    (b.paidAt || b.createdAt || '').localeCompare(a.paidAt || a.createdAt || '');

  const open = charges.filter(isOpen).sort(newestFirst);
  if (open.length > 0) return open[0];

  const paid = charges.filter((c) => c.status === 'paid').sort(newestFirst);
  return paid[0] ?? null;
}

/**
 * Firestore trigger handler: when an order changes to 'canceled' and the
 * company has Asaas connected, cancel its open charges on Asaas.
 */
export async function handleOrderStatusChange(
  companyId: string,
  orderId: string,
  beforeStatus: string | undefined,
  afterStatus: string | undefined,
): Promise<void> {
  if (afterStatus !== 'canceled' || beforeStatus === 'canceled') return;
  const settings = await getPaymentSettings(companyId);
  if (!settings.asaasConnected) return;
  await cancelOpenChargesForOrder(companyId, orderId);
}
```

- [ ] **Step 5: Rodar os testes**

```bash
npx jest src/utils/tax-id.utils.test.ts src/services/asaas && npm run lint && npm run build
```

Esperado: PASS (tax-id 4, charge.service 27), lint sem erros, build ok. Os testes usam `discount: 0`, então passam com ou sem a correção de saldo do Bloco A.

- [ ] **Step 6: Commit**

```bash
cd /Users/rafaeldl/Projetos/praticOSopen/.claude/worktrees/bold-sutherland-509639
git add firebase/functions/src/utils/tax-id.utils.ts firebase/functions/src/utils/tax-id.utils.test.ts firebase/functions/src/services/asaas/charge.service.ts firebase/functions/src/services/asaas/__tests__/charge.service.test.ts
git commit -F - <<'EOF'
feat(payments): create and cancel Asaas charges for orders

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

### Task B6: Rotas de conexão Asaas

**Files:**
- Create: `firebase/functions/src/routes/v1/asaas-connection.routes.ts`
- Test: `firebase/functions/src/routes/v1/__tests__/asaas-connection.routes.test.ts`

**Interfaces:**
- Consumes: `connectAsaas`, `disconnectAsaas`, `getPaymentSettings` (B4); `toHttpError` (B3); `validateInput` de `firebase/functions/src/utils/validation.utils.ts` (linha 359); padrão `ensureManager` de `firebase/functions/src/routes/v1/integrations.routes.ts` (linhas 11–26).
- Produces: router montado em `/v1/app/payments/asaas` (Task B8): `GET /settings`, `POST /connect` `{ apiKey }`, `DELETE /connect` — só `owner`/`admin`.

Logs de erro registram só `error.name`, nunca o objeto (pode carregar detalhes da requisição).

- [ ] **Step 1: Escrever o teste que falha** — `firebase/functions/src/routes/v1/__tests__/asaas-connection.routes.test.ts`

```ts
import request from 'supertest';
import express, { Request, Response, NextFunction } from 'express';

jest.mock('../../../services/asaas/connection.service');

import * as connectionService from '../../../services/asaas/connection.service';
import { AsaasServiceError } from '../../../services/asaas/errors';
import router from '../asaas-connection.routes';

const mockService = connectionService as jest.Mocked<typeof connectionService>;

function buildApp(role: string) {
  const app = express();
  app.use(express.json());
  app.use((req: Request, _res: Response, next: NextFunction) => {
    const r = req as any;
    r.auth = { type: 'bearer', companyId: 'comp1', userId: 'user1' };
    r.userContext = { userId: 'user1', userName: 'Ana', companyId: 'comp1', role, permissions: [] };
    next();
  });
  app.use('/', router);
  return app;
}

const CONNECTED = {
  asaasEnabled: true,
  asaasConnected: true,
  asaasAccountName: 'Oficina da Ana',
  asaasEnvironment: 'sandbox' as const,
};

describe('asaas-connection.routes', () => {
  beforeEach(() => jest.clearAllMocks());

  it('conecta para admin', async () => {
    mockService.connectAsaas.mockResolvedValue(CONNECTED);

    const res = await request(buildApp('admin')).post('/connect').send({ apiKey: '$aact_hmlg_k' });

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ success: true, data: CONNECTED });
    expect(mockService.connectAsaas).toHaveBeenCalledWith('comp1', '$aact_hmlg_k', { id: 'user1', name: 'Ana' });
  });

  it('bloqueia gerente e técnico com 403', async () => {
    for (const role of ['manager', 'technician']) {
      const res = await request(buildApp(role)).post('/connect').send({ apiKey: '$aact_hmlg_k' });
      expect(res.status).toBe(403);
    }
    expect(mockService.connectAsaas).not.toHaveBeenCalled();
  });

  it('exige apiKey', async () => {
    const res = await request(buildApp('owner')).post('/connect').send({});
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('chave inválida → 400 ASAAS_INVALID_API_KEY', async () => {
    mockService.connectAsaas.mockRejectedValue(new AsaasServiceError('ASAAS_INVALID_API_KEY', 'Invalid Asaas API key'));
    const res = await request(buildApp('owner')).post('/connect').send({ apiKey: 'x' });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('ASAAS_INVALID_API_KEY');
  });

  it('empresa fora do piloto → 403 ASAAS_NOT_ENABLED', async () => {
    mockService.connectAsaas.mockRejectedValue(new AsaasServiceError('ASAAS_NOT_ENABLED', 'Asaas is not enabled'));
    const res = await request(buildApp('owner')).post('/connect').send({ apiKey: '$aact_hmlg_k' });
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('ASAAS_NOT_ENABLED');
  });

  it('erro inesperado → 500 sem detalhes', async () => {
    mockService.connectAsaas.mockRejectedValue(new Error('$aact_hmlg_k leaked'));
    const res = await request(buildApp('owner')).post('/connect').send({ apiKey: '$aact_hmlg_k' });
    expect(res.status).toBe(500);
    expect(JSON.stringify(res.body)).not.toContain('aact');
  });

  it('desconecta para owner', async () => {
    mockService.disconnectAsaas.mockResolvedValue(undefined);
    const res = await request(buildApp('owner')).delete('/connect');
    expect(res.status).toBe(200);
    expect(mockService.disconnectAsaas).toHaveBeenCalledWith('comp1');
  });

  it('GET /settings devolve o estado da conexão', async () => {
    mockService.getPaymentSettings.mockResolvedValue(CONNECTED);
    const res = await request(buildApp('admin')).get('/settings');
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual(CONNECTED);
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
cd /Users/rafaeldl/Projetos/praticOSopen/.claude/worktrees/bold-sutherland-509639/firebase/functions
npx jest src/routes/v1/__tests__/asaas-connection.routes.test.ts
```

Esperado: FAIL com `Cannot find module '../asaas-connection.routes'`.

- [ ] **Step 3: Implementar** — `firebase/functions/src/routes/v1/asaas-connection.routes.ts`

```ts
/**
 * Asaas connection routes (Flutter app, bearer auth).
 * Mounted at /v1/app/payments/asaas. Owner/admin only.
 */

import { Router, Response } from 'express';
import { z } from 'zod';
import { AuthenticatedRequest } from '../../models/types';
import { validateInput } from '../../utils/validation.utils';
import {
  connectAsaas,
  disconnectAsaas,
  getPaymentSettings,
} from '../../services/asaas/connection.service';
import { toHttpError } from '../../services/asaas/errors';

const router: Router = Router();

const MANAGER_ROLES = ['owner', 'admin'];

const connectSchema = z.object({
  apiKey: z.string().trim().min(1, 'apiKey is required').max(500),
});

function ensureManager(req: AuthenticatedRequest, res: Response): boolean {
  const role = req.userContext?.role;
  if (!role || !MANAGER_ROLES.includes(role)) {
    res.status(403).json({
      success: false,
      error: {
        code: 'FORBIDDEN',
        message: 'Only owners and admins can manage the Asaas connection',
      },
    });
    return false;
  }
  return true;
}

router.get('/settings', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (!ensureManager(req, res)) return;
    const data = await getPaymentSettings(req.userContext!.companyId);
    res.json({ success: true, data });
  } catch (error) {
    console.error('Get Asaas settings error:', (error as Error).name);
    const { status, body } = toHttpError(error, 'Failed to get payment settings');
    res.status(status).json(body);
  }
});

router.post('/connect', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (!ensureManager(req, res)) return;

    const validation = validateInput(connectSchema, req.body);
    if (!validation.success) {
      res.status(400).json({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: validation.errors.join(', ') },
      });
      return;
    }

    const { companyId, userId, userName } = req.userContext!;
    const data = await connectAsaas(companyId, validation.data.apiKey, { id: userId, name: userName });
    res.json({ success: true, data });
  } catch (error) {
    // Never log the error object: it may carry request details.
    console.error('Connect Asaas error:', (error as Error).name);
    const { status, body } = toHttpError(error, 'Failed to connect Asaas account');
    res.status(status).json(body);
  }
});

router.delete('/connect', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (!ensureManager(req, res)) return;
    await disconnectAsaas(req.userContext!.companyId);
    res.json({ success: true });
  } catch (error) {
    console.error('Disconnect Asaas error:', (error as Error).name);
    const { status, body } = toHttpError(error, 'Failed to disconnect Asaas account');
    res.status(status).json(body);
  }
});

export default router;
```

- [ ] **Step 4: Rodar os testes**

```bash
npx jest src/routes/v1 && npm run lint && npm run build
```

Esperado: PASS (8 testes novos + `integrations.routes.test.ts`), lint sem erros, build ok.

- [ ] **Step 5: Commit**

```bash
cd /Users/rafaeldl/Projetos/praticOSopen/.claude/worktrees/bold-sutherland-509639
git add firebase/functions/src/routes/v1/asaas-connection.routes.ts firebase/functions/src/routes/v1/__tests__/asaas-connection.routes.test.ts
git commit -F - <<'EOF'
feat(payments): add Asaas connection routes

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

### Task B7: Rotas de cobrança da OS

**Files:**
- Create: `firebase/functions/src/routes/v1/charges.routes.ts`
- Test: `firebase/functions/src/routes/v1/__tests__/charges.routes.test.ts`

**Interfaces:**
- Consumes: `createOrderCharge`, `cancelOrderCharge` (B5); `toHttpError` (B3); `requirePermission` de `firebase/functions/src/middleware/auth.middleware.ts` (linha 449); `getUserAggr` de `firebase/functions/src/middleware/company.middleware.ts` (linha 128); permissão `manage:payments` (Bloco A).
- Produces: router montado em `/v1/app/orders` (Task B8): `POST /:orderId/charges` (201, `data: OrderCharge`), `DELETE /:orderId/charges/:chargeId` (`data: OrderCharge`); `createChargeSchema` (zod).

- [ ] **Step 1: Escrever o teste que falha** — `firebase/functions/src/routes/v1/__tests__/charges.routes.test.ts`

```ts
import request from 'supertest';
import express, { Request, Response, NextFunction } from 'express';

jest.mock('../../../services/asaas/charge.service');

import * as chargeService from '../../../services/asaas/charge.service';
import { AsaasServiceError } from '../../../services/asaas/errors';
import router from '../charges.routes';

const mockService = chargeService as jest.Mocked<typeof chargeService>;

function buildApp(permissions: string[]) {
  const app = express();
  app.use(express.json());
  app.use((req: Request, _res: Response, next: NextFunction) => {
    const r = req as any;
    r.auth = { type: 'bearer', companyId: 'comp1', userId: 'user1' };
    r.userContext = { userId: 'user1', userName: 'Ana', companyId: 'comp1', role: 'manager', permissions };
    next();
  });
  app.use('/', router);
  return app;
}

const CHARGE = {
  id: 'ch1',
  asaasPaymentId: 'pay_1',
  mode: 'single' as const,
  value: 100,
  dueDate: '2026-10-07',
  status: 'pending' as const,
  invoiceUrl: 'https://sandbox.asaas.com/i/pay_1',
  paidAsaasPaymentIds: [],
  createdBy: { id: 'user1', name: 'Ana' },
  createdAt: '2026-10-04T10:00:00.000Z',
};

describe('charges.routes', () => {
  beforeEach(() => jest.clearAllMocks());

  it('cria cobrança com manage:payments', async () => {
    mockService.createOrderCharge.mockResolvedValue(CHARGE);

    const res = await request(buildApp(['manage:payments']))
      .post('/o1/charges')
      .send({ value: 100, mode: 'single' });

    expect(res.status).toBe(201);
    expect(res.body).toEqual({ success: true, data: CHARGE });
    expect(mockService.createOrderCharge).toHaveBeenCalledWith(
      'comp1',
      'o1',
      { value: 100, mode: 'single' },
      { id: 'user1', name: 'Ana' },
    );
  });

  it('sem manage:payments → 403', async () => {
    const res = await request(buildApp(['read:all', 'write:orders']))
      .post('/o1/charges')
      .send({ value: 100, mode: 'single' });
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('INSUFFICIENT_PERMISSIONS');
    expect(mockService.createOrderCharge).not.toHaveBeenCalled();
  });

  it('valida corpo com zod', async () => {
    const app = buildApp(['manage:payments']);
    const cases = [
      {},
      { value: -1, mode: 'single' },
      { value: 100, mode: 'pix' },
      { value: 100, mode: 'cardInstallments' },
      { value: 100, mode: 'cardInstallments', installmentCount: 13 },
      { value: 100, mode: 'single', dueDate: '07/10/2026' },
    ];
    for (const body of cases) {
      const res = await request(app).post('/o1/charges').send(body);
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    }
    expect(mockService.createOrderCharge).not.toHaveBeenCalled();
  });

  it('erro de negócio vira status e código do serviço', async () => {
    mockService.createOrderCharge.mockRejectedValue(
      new AsaasServiceError('INVALID_VALUE', 'Value exceeds the order remaining balance'),
    );
    const res = await request(buildApp(['manage:payments']))
      .post('/o1/charges')
      .send({ value: 5000, mode: 'single' });
    expect(res.status).toBe(400);
    expect(res.body.error).toEqual({ code: 'INVALID_VALUE', message: 'Value exceeds the order remaining balance' });
  });

  it('cancela cobrança', async () => {
    mockService.cancelOrderCharge.mockResolvedValue({ ...CHARGE, status: 'canceled' });
    const res = await request(buildApp(['manage:payments'])).delete('/o1/charges/ch1');
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('canceled');
    expect(mockService.cancelOrderCharge).toHaveBeenCalledWith('comp1', 'o1', 'ch1');
  });

  it('cancelar cobrança inexistente → 404', async () => {
    mockService.cancelOrderCharge.mockRejectedValue(new AsaasServiceError('CHARGE_NOT_FOUND', 'Charge not found'));
    const res = await request(buildApp(['manage:payments'])).delete('/o1/charges/nope');
    expect(res.status).toBe(404);
  });

  it('cancelar sem permissão → 403', async () => {
    const res = await request(buildApp(['read:all'])).delete('/o1/charges/ch1');
    expect(res.status).toBe(403);
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
cd /Users/rafaeldl/Projetos/praticOSopen/.claude/worktrees/bold-sutherland-509639/firebase/functions
npx jest src/routes/v1/__tests__/charges.routes.test.ts
```

Esperado: FAIL com `Cannot find module '../charges.routes'`.

- [ ] **Step 3: Implementar** — `firebase/functions/src/routes/v1/charges.routes.ts`

```ts
/**
 * Order charge routes (Flutter app, bearer auth).
 * Mounted at /v1/app/orders. Requires permission 'manage:payments'.
 */

import { Router, Response } from 'express';
import { z } from 'zod';
import { AuthenticatedRequest } from '../../models/types';
import { requirePermission } from '../../middleware/auth.middleware';
import { getUserAggr } from '../../middleware/company.middleware';
import { validateInput } from '../../utils/validation.utils';
import { cancelOrderCharge, createOrderCharge } from '../../services/asaas/charge.service';
import { toHttpError } from '../../services/asaas/errors';

const router: Router = Router();

export const createChargeSchema = z
  .object({
    value: z.number().positive(),
    mode: z.enum(['single', 'cardInstallments']),
    installmentCount: z.number().int().min(2).max(12).optional(),
    dueDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'dueDate must be YYYY-MM-DD').optional(),
    customerTaxId: z.string().max(20).optional(),
  })
  .refine((data) => data.mode !== 'cardInstallments' || data.installmentCount !== undefined, {
    message: 'installmentCount is required for cardInstallments',
    path: ['installmentCount'],
  });

function param(value: string | string[]): string {
  return Array.isArray(value) ? value[0] : value;
}

router.post(
  '/:orderId/charges',
  requirePermission('manage:payments'),
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const validation = validateInput(createChargeSchema, req.body);
      if (!validation.success) {
        res.status(400).json({
          success: false,
          error: { code: 'VALIDATION_ERROR', message: validation.errors.join(', ') },
        });
        return;
      }

      const charge = await createOrderCharge(
        req.userContext!.companyId,
        param(req.params.orderId),
        validation.data,
        getUserAggr(req),
      );
      res.status(201).json({ success: true, data: charge });
    } catch (error) {
      console.error('Create charge error:', (error as Error).name);
      const { status, body } = toHttpError(error, 'Failed to create charge');
      res.status(status).json(body);
    }
  },
);

router.delete(
  '/:orderId/charges/:chargeId',
  requirePermission('manage:payments'),
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const charge = await cancelOrderCharge(
        req.userContext!.companyId,
        param(req.params.orderId),
        param(req.params.chargeId),
      );
      res.json({ success: true, data: charge });
    } catch (error) {
      console.error('Cancel charge error:', (error as Error).name);
      const { status, body } = toHttpError(error, 'Failed to cancel charge');
      res.status(status).json(body);
    }
  },
);

export default router;
```

- [ ] **Step 4: Rodar os testes**

```bash
npx jest src/routes/v1 && npm run lint && npm run build
```

Esperado: PASS (7 testes novos), lint sem erros, build ok.

- [ ] **Step 5: Commit**

```bash
cd /Users/rafaeldl/Projetos/praticOSopen/.claude/worktrees/bold-sutherland-509639
git add firebase/functions/src/routes/v1/charges.routes.ts firebase/functions/src/routes/v1/__tests__/charges.routes.test.ts
git commit -F - <<'EOF'
feat(payments): add order charge routes

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

### Task B8: Montar rotas, secret, trigger de OS cancelada e redação de logs

**Files:**
- Modify: `firebase/functions/src/index.ts` (linha 11: imports; após linha 118, antes do bloco `SCHEDULED FUNCTIONS` das linhas 120–122: secret + trigger; após linha 254: imports das rotas; após linha 446: montagem; linha 528: `secrets` da `api`)
- Modify: `firebase/functions/src/utils/log-redaction.utils.ts` (linhas 118–123)
- Modify: `firebase/functions/.env.example` (fim do arquivo)
- Modify: `firebase/functions/.gitignore` (linhas 7–11)
- Test: `firebase/functions/src/utils/log-redaction.utils.test.ts` (após linha 268)

**Interfaces:**
- Consumes: `handleOrderStatusChange` (B5); routers de B6 e B7.
- Produces: `export const onOrderCanceledCancelAsaasCharges` (Firestore `onDocumentUpdated` em `companies/{companyId}/orders/{orderId}`, região `southamerica-east1` — mesma do Firestore `(default)`, conferida com `gcloud firestore databases list --project praticos`); `const asaasCredentialsKey = defineSecret('ASAAS_CREDENTIALS_KEY')` ligado à `api` e ao trigger; rotas `/v1/app/payments/asaas/*` e `/v1/app/orders/:orderId/charges*`.

O app muda o status da OS direto no Firestore, por isso o cancelamento das cobranças é um trigger e não parte de uma rota. O trigger sai cedo (sem ler nada) quando o status não mudou para `canceled`; a checagem de `asaasConnected` fica em `handleOrderStatusChange`, já testada na Task B5.

- [ ] **Step 1: Escrever o teste que falha** — em `firebase/functions/src/utils/log-redaction.utils.test.ts`, dentro de `describe('isPayloadLoggingEnabled', ...)`, logo após o teste `'still skips the always-sensitive routes in the emulator'` (linha 268), adicionar:

```ts
  it('never logs Asaas connect bodies (API key) nor Asaas webhook payloads', () => {
    expect(isPayloadLoggingEnabled('/v1/app/payments/asaas/connect', emulator)).toBe(false);
    expect(isPayloadLoggingEnabled('/v1/app/payments/asaas/settings', emulator)).toBe(false);
    expect(isPayloadLoggingEnabled('/webhooks/asaas/comp1', emulator)).toBe(false);
    expect(isPayloadLoggingEnabled('/v1/app/orders/o1/charges', emulator)).toBe(true);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
cd /Users/rafaeldl/Projetos/praticOSopen/.claude/worktrees/bold-sutherland-509639/firebase/functions
npx jest src/utils/log-redaction.utils.test.ts
```

Esperado: FAIL em `never logs Asaas connect bodies` (`Expected: false, Received: true`).

- [ ] **Step 3: Redação de logs** — em `firebase/functions/src/utils/log-redaction.utils.ts`, substituir as linhas 118–123:

```ts
 * Every other path keeps logging its payload as before. Matched
 * case-insensitively because Express routes that way.
 */
export function shouldLogPayload(path: string): boolean {
  return !/^\/(mcp|public)(\/|$)|\/share(\/|$)/i.test(path);
}
```

por:

```ts
 * - `/v1/app/payments/asaas/**`: the connect body carries the company's
 *   Asaas API key.
 * - `/webhooks/asaas/**`: Asaas webhook payloads carry end-customer data
 *   (name, CPF/CNPJ, amounts).
 *
 * Every other path keeps logging its payload as before. Matched
 * case-insensitively because Express routes that way.
 */
export function shouldLogPayload(path: string): boolean {
  return !/^\/(mcp|public|webhooks\/asaas)(\/|$)|\/share(\/|$)|\/payments\/asaas(\/|$)/i.test(path);
}
```

- [ ] **Step 4: `src/index.ts`**

4a. Após a linha 11 (`import { beforeUserCreated } from 'firebase-functions/v2/identity';`):

```ts
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';
```

4b. Entre o fim de `updateUserClaims` (linha 118, `  });`) e o comentário `// SCHEDULED FUNCTIONS` (linhas 120–122), inserir:

```ts
import { handleOrderStatusChange } from './services/asaas/charge.service';

/**
 * Asaas master key (AES-256-GCM, base64 of 32 bytes) — see services/asaas/crypto.ts.
 * Bound to every function that reads or writes companies/{cid}/private/asaas.
 */
const asaasCredentialsKey = defineSecret('ASAAS_CREDENTIALS_KEY');

/**
 * [Asaas] Cancels open charges on Asaas when an order is canceled.
 * The app changes the order status directly in Firestore, so this runs as a
 * trigger instead of inside an API route. No-op unless the company has Asaas connected.
 */
export const onOrderCanceledCancelAsaasCharges = onDocumentUpdated(
  {
    document: 'companies/{companyId}/orders/{orderId}',
    region: 'southamerica-east1',
    secrets: [asaasCredentialsKey],
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after || after.status !== 'canceled' || before?.status === 'canceled') return;

    const { companyId, orderId } = event.params;
    await handleOrderStatusChange(companyId, orderId, before?.status, after.status);
  }
);
```

4c. Após a linha 254 (`import integrationsRoutes from './routes/v1/integrations.routes';`):

```ts
import asaasConnectionRoutes from './routes/v1/asaas-connection.routes';
import chargesRoutes from './routes/v1/charges.routes';
```

4d. Após a linha 446 (`app.use('/v1/app/integrations', ...)`):

```ts
app.use('/v1/app/payments/asaas', apiCoreLimiter, bearerAuth, resolveCompanyContext, asaasConnectionRoutes);
app.use('/v1/app/orders', apiCoreLimiter, bearerAuth, resolveCompanyContext, chargesRoutes);
```

(`ordersRoutes` e `shareRoutes` não têm rota que case com `/:id/charges`, então a requisição cai no `chargesRoutes`.)

4e. Na linha 528, dentro de `export const api = onRequest({ ... })`, trocar `secrets: [ssrApiSecret],` por:

```ts
    secrets: [ssrApiSecret, asaasCredentialsKey],
```

- [ ] **Step 5: Variáveis de ambiente** — no fim de `firebase/functions/.env.example`, acrescentar:

```bash

# Public base URL of the `api` function, used to register the Asaas webhook
# (`<base>/webhooks/asaas/<companyId>`). Defaults to production when unset.
# In local development Asaas cannot reach the emulator: use a tunnel (ngrok).
ASAAS_WEBHOOK_BASE_URL=https://southamerica-east1-praticos.cloudfunctions.net/api

# ASAAS_CREDENTIALS_KEY is a Secret Manager secret (not an env var):
#   openssl rand -base64 32 | firebase functions:secrets:set ASAAS_CREDENTIALS_KEY --data-file=-
# For the emulator put ASAAS_CREDENTIALS_KEY=<base64 of 32 bytes> in .secret.local (gitignored).
```

E em `firebase/functions/.gitignore`, na seção `# Local environment` (linhas 7–11), acrescentar uma linha depois de `.env.praticos`:

```
.secret.local
```

- [ ] **Step 6: Rodar a verificação completa**

```bash
cd /Users/rafaeldl/Projetos/praticOSopen/.claude/worktrees/bold-sutherland-509639/firebase/functions
npm run lint && npm run build && npm test
```

Esperado: lint 0 errors; build ok (gera `lib/index.js` com `onOrderCanceledCancelAsaasCharges`); todas as suítes PASS (as 463 anteriores + as novas deste bloco).

- [ ] **Step 7: Commit**

```bash
cd /Users/rafaeldl/Projetos/praticOSopen/.claude/worktrees/bold-sutherland-509639
git add firebase/functions/src/index.ts firebase/functions/src/utils/log-redaction.utils.ts firebase/functions/src/utils/log-redaction.utils.test.ts firebase/functions/.env.example firebase/functions/.gitignore
git commit -F - <<'EOF'
feat(payments): mount Asaas routes and cancel charges when order is canceled

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

### Task B9: Open PR

- [ ] **Step 1: Conferir o secret de produção** (o merge dispara deploy; sem o secret o deploy falha)

```bash
firebase functions:secrets:access ASAAS_CREDENTIALS_KEY --project praticos >/dev/null && echo "secret ok"
```

Se não existir, pedir ao Rafael para rodar o comando de criação do topo deste bloco antes do merge. Não criar o secret sem ele.

- [ ] **Step 2: Push e PR**

```bash
cd /Users/rafaeldl/Projetos/praticOSopen/.claude/worktrees/bold-sutherland-509639
git push -u origin feat/asaas-connection-charges
gh pr create --base master --head feat/asaas-connection-charges --label risk:high \
  --title "feat(payments): conexão Asaas e cobrança da OS (server)" \
  --body-file - <<'EOF'
## Resumo

Bloco B da cobrança da OS via Asaas (spec `docs/superpowers/specs/2026-10-04-asaas-cobranca-os-design.md`). Só servidor.

- `AsaasClient` (fetch nativo, sandbox/produção pelo prefixo da chave, `access_token` + `User-Agent: PraticOS`).
- Chave Asaas da empresa criptografada com AES-256-GCM (`ASAAS_CREDENTIALS_KEY` no Secret Manager) em `companies/{cid}/private/asaas`.
- `POST/DELETE /v1/app/payments/asaas/connect` e `GET /v1/app/payments/asaas/settings` (dono/admin, empresa com `asaasEnabled`): valida a chave, cadastra o webhook com token aleatório guardado só como hash, grava `settings/payments`.
- `POST /v1/app/orders/:orderId/charges` e `DELETE /v1/app/orders/:orderId/charges/:chargeId` (`manage:payments`): valida saldo, parcelas (2–12) e CPF/CNPJ, cancela a cobrança aberta anterior, faz find-or-create do cliente no Asaas e cria a cobrança à vista (`UNDEFINED`) ou parcelada no cartão.
- Trigger `onOrderCanceledCancelAsaasCharges`: OS cancelada cancela as cobranças abertas no Asaas.
- Payload de `/v1/app/payments/asaas/**` e `/webhooks/asaas/**` nunca vai para o log, nem no emulador.

## Antes do merge

- [ ] Secret `ASAAS_CREDENTIALS_KEY` criado em produção (`openssl rand -base64 32 | firebase functions:secrets:set ASAAS_CREDENTIALS_KEY --project praticos --data-file=-`). O deploy automático da `master` falha sem ele.
- [ ] Bloco A já mergeado (`manage:payments` e saldo `total - paidAmount`).

## Testes

- `cd firebase/functions && npm run lint && npm run build && npm test`
- Jest com Asaas mockado: criptografia (ida e volta, tag adulterada falha), client com fetch falso, connect (chave válida/inválida, ambiente, webhook), charges (permissão, valor > saldo, parcelas, CPF/CNPJ, cancela a anterior), cancelamento ao cancelar OS.
- E2E no sandbox fica para o Bloco F.

Refs #303

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
```

## Bloco C — Webhook Asaas, baixa na OS, trigger de reparo e regras

> Contract note 1: `OrderCharge` ganha o campo opcional server-only `appliedTransactions?: PaymentTransaction[]` (cópia de cada transação lançada). Sem ele o reparo não sabe o valor/descrição de cada parcela apagada por app antigo. O model Flutter (`lib/models/order_charge.dart`) ignora a chave (json_serializable ignora campos extras), então não muda nada no Bloco D.
>
> Contract note 2: `CommentSource` (`src/models/types.ts`) ganha `'asaas'`. O registro do estorno no histórico da OS segue o padrão existente de "comentário de auditoria" (`orders/{oid}/comments`, como aprovação/rejeição/avaliação em `routes/public/orders.routes.ts`). O app lê `source` como `String?`, sem enum decode.
>
> Contract note 3: exports novos além do contrato: `runAsaasRepairOnOrderUpdate` e helpers puros em `order-payment.service.ts`, `parseExternalReference` em `webhook.service.ts`, `notifyAsaasPaymentReceived(companyId, orderId, amount)` em `notification.service.ts`.
>
> Contract note 4: eventos que não dá para processar (cobrança não encontrada, `companyId` do `externalReference` diferente da URL, evento não assinado) são registrados em `private/asaas/events` e respondidos com **200**. O webhook é `SEQUENTIALLY`: responder erro para um evento que nunca vai dar certo trava a fila da empresa e o Asaas a interrompe. Só falha transitória (Firestore etc.) responde 500.
>
> Contract note 5: o Bloco C depende do Bloco B mergeado (`src/models/asaas.types.ts` e `src/services/asaas/crypto.ts` já existem na `master`).

**Branch:** `feat/asaas-webhook` (a partir da `master` com o Bloco B mergeado). **PR:** `feat(asaas): webhook de pagamentos, baixa na OS, reparo e regras`.

Entrega o endpoint `POST /webhooks/asaas/:companyId`, o lançamento/estorno transacional na OS, a notificação push de pagamento recebido, o trigger `repairAsaasPayments` e as regras Firestore de `private/**`, `settings/payments` e `charges`. Todos os testes usam um Firestore em memória (`asaas-fake-db.ts`), sem emulador.

Verificação do PR:

```bash
cd firebase/functions && npm run lint && npm test && npm run build
cd firebase && firebase emulators:exec --only firestore --project demo-praticos "echo rules-ok"
```

---

### Task C1: Tipos do webhook, Firestore em memória e `applyAsaasPayment`

**Files:**
- Modify: `firebase/functions/src/models/asaas.types.ts` (criado no Bloco B): campo `appliedTransactions` em `OrderCharge` + tipos do webhook no fim do arquivo
- Create: `firebase/functions/src/services/asaas/__tests__/asaas-fake-db.ts`
- Create: `firebase/functions/src/services/asaas/order-payment.service.ts`
- Test: `firebase/functions/src/services/asaas/__tests__/order-payment.service.test.ts`

**Interfaces:**
- Consumes: `OrderCharge`, `ChargeStatus` (`asaas.types.ts`), `PaymentTransaction`, `UserAggr` (`models/types.ts`), `db`, `FieldValue` (`services/firestore.service.ts`)
- Produces: `applyAsaasPayment(companyId: string, orderId: string, chargeId: string, payment: AsaasPaymentEvent): Promise<{ applied: boolean }>`; `AsaasPaymentEvent`, `AsaasWebhookEvent`, `AsaasWebhookEventName`; helpers `asaasTransactionId`, `describeAsaasPayment`, `buildAsaasTransaction`, `computePaymentFields`, `ASAAS_ACTOR`

- [ ] **Step 1: Criar o Firestore em memória usado pelos testes do bloco**

`firebase/functions/src/services/asaas/__tests__/asaas-fake-db.ts`:

```ts
/**
 * In-memory Firestore double for the Asaas tests.
 *
 * Covers the subset used by order-payment.service, webhook.service,
 * notification.service and the Asaas webhook route: doc/collection refs,
 * get/set/update/create/delete, add, where('==')/limit, collectionGroup and
 * runTransaction (writes are applied after the callback resolves).
 * `update` is a shallow merge: services must not use dotted field paths.
 *
 * Usage in a test file:
 *   jest.mock('../../firestore.service', () =>
 *     jest.requireActual('./asaas-fake-db').firestoreServiceMock);
 *   import { fakeDb } from './asaas-fake-db';
 */
import { Timestamp } from 'firebase-admin/firestore';

type Data = Record<string, unknown>;

function clone<T>(value: T): T {
  if (Array.isArray(value)) return value.map((item) => clone(item)) as unknown as T;
  if (value && typeof value === 'object' && Object.getPrototypeOf(value) === Object.prototype) {
    const out: Data = {};
    for (const [key, item] of Object.entries(value as Data)) out[key] = clone(item);
    return out as T;
  }
  return value;
}

function getField(data: Data | undefined, field: string): unknown {
  return field
    .split('.')
    .reduce<unknown>((acc, key) => (acc && typeof acc === 'object' ? (acc as Data)[key] : undefined), data);
}

function parentPath(path: string): string {
  return path.split('/').slice(0, -1).join('/');
}

let autoIdCounter = 0;
function autoId(): string {
  autoIdCounter += 1;
  return `auto_${autoIdCounter}`;
}

export class FakeFirestoreError extends Error {
  constructor(readonly code: number, message: string) {
    super(message);
  }
}

export class FakeStore {
  readonly docs = new Map<string, Data>();

  read(path: string): Data | undefined {
    const data = this.docs.get(path);
    return data === undefined ? undefined : clone(data);
  }

  set(path: string, data: Data, merge: boolean): void {
    const base = merge ? this.docs.get(path) ?? {} : {};
    this.docs.set(path, { ...clone(base), ...clone(data) });
  }

  update(path: string, data: Data): void {
    const current = this.docs.get(path);
    if (!current) throw new FakeFirestoreError(5, `NOT_FOUND: ${path}`);
    this.docs.set(path, { ...current, ...clone(data) });
  }

  create(path: string, data: Data): void {
    if (this.docs.has(path)) throw new FakeFirestoreError(6, `ALREADY_EXISTS: ${path}`);
    this.docs.set(path, clone(data));
  }

  delete(path: string): void {
    this.docs.delete(path);
  }

  paths(): string[] {
    return [...this.docs.keys()].sort();
  }
}

export class FakeDocSnapshot {
  constructor(readonly ref: FakeDocRef, private readonly value: Data | undefined) {}

  get exists(): boolean {
    return this.value !== undefined;
  }

  get id(): string {
    return this.ref.id;
  }

  data(): Data | undefined {
    return this.value === undefined ? undefined : clone(this.value);
  }
}

export interface FakeQuerySnapshot {
  docs: FakeDocSnapshot[];
  empty: boolean;
  size: number;
}

export class FakeDocRef {
  constructor(readonly store: FakeStore, readonly path: string) {}

  get id(): string {
    return this.path.split('/').pop() as string;
  }

  get parent(): FakeCollectionRef {
    return new FakeCollectionRef(this.store, parentPath(this.path));
  }

  collection(name: string): FakeCollectionRef {
    return new FakeCollectionRef(this.store, `${this.path}/${name}`);
  }

  async get(): Promise<FakeDocSnapshot> {
    return new FakeDocSnapshot(this, this.store.read(this.path));
  }

  async set(data: Data, options?: { merge?: boolean }): Promise<void> {
    this.store.set(this.path, data, options?.merge === true);
  }

  async update(data: Data): Promise<void> {
    this.store.update(this.path, data);
  }

  async create(data: Data): Promise<void> {
    this.store.create(this.path, data);
  }

  async delete(): Promise<void> {
    this.store.delete(this.path);
  }
}

export class FakeQuery {
  constructor(
    protected readonly store: FakeStore,
    private readonly matches: (path: string) => boolean,
    private readonly filters: Array<[string, unknown]> = [],
    private readonly max?: number,
  ) {}

  where(field: string, op: string, value: unknown): FakeQuery {
    if (op !== '==') throw new Error(`FakeQuery only supports '==' (got ${op})`);
    return new FakeQuery(this.store, this.matches, [...this.filters, [field, value]], this.max);
  }

  limit(max: number): FakeQuery {
    return new FakeQuery(this.store, this.matches, this.filters, max);
  }

  async get(): Promise<FakeQuerySnapshot> {
    const docs = this.store
      .paths()
      .filter(this.matches)
      .map((path) => new FakeDocSnapshot(new FakeDocRef(this.store, path), this.store.read(path)))
      .filter((snap) => this.filters.every(([field, value]) => getField(snap.data(), field) === value))
      .slice(0, this.max ?? Number.MAX_SAFE_INTEGER);
    return { docs, empty: docs.length === 0, size: docs.length };
  }
}

export class FakeCollectionRef extends FakeQuery {
  constructor(store: FakeStore, readonly path: string) {
    super(store, (candidate) => parentPath(candidate) === path);
  }

  get id(): string {
    return this.path.split('/').pop() as string;
  }

  get parent(): FakeDocRef | null {
    const parts = this.path.split('/');
    return parts.length > 1 ? new FakeDocRef(this.store, parts.slice(0, -1).join('/')) : null;
  }

  doc(id?: string): FakeDocRef {
    return new FakeDocRef(this.store, `${this.path}/${id ?? autoId()}`);
  }

  async add(data: Data): Promise<FakeDocRef> {
    const ref = this.doc();
    await ref.set(data);
    return ref;
  }
}

export interface FakeTransaction {
  get(target: FakeDocRef | FakeQuery): Promise<any>;
  set(ref: FakeDocRef, data: Data, options?: { merge?: boolean }): FakeTransaction;
  update(ref: FakeDocRef, data: Data): FakeTransaction;
  create(ref: FakeDocRef, data: Data): FakeTransaction;
  delete(ref: FakeDocRef): FakeTransaction;
}

export class FakeDb {
  readonly store = new FakeStore();

  collection(name: string): FakeCollectionRef {
    return new FakeCollectionRef(this.store, name);
  }

  doc(path: string): FakeDocRef {
    return new FakeDocRef(this.store, path);
  }

  collectionGroup(name: string): FakeQuery {
    return new FakeQuery(this.store, (path) => {
      const parts = path.split('/');
      return parts.length >= 2 && parts[parts.length - 2] === name;
    });
  }

  async runTransaction<T>(callback: (tx: FakeTransaction) => Promise<T>): Promise<T> {
    const writes: Array<() => void> = [];
    const tx: FakeTransaction = {
      get: (target) => target.get(),
      set: (ref, data, options) => {
        writes.push(() => this.store.set(ref.path, data, options?.merge === true));
        return tx;
      },
      update: (ref, data) => {
        writes.push(() => this.store.update(ref.path, data));
        return tx;
      },
      create: (ref, data) => {
        writes.push(() => this.store.create(ref.path, data));
        return tx;
      },
      delete: (ref) => {
        writes.push(() => this.store.delete(ref.path));
        return tx;
      },
    };
    const result = await callback(tx);
    for (const write of writes) write();
    return result;
  }

  seed(path: string, data: Data): void {
    this.store.set(path, data, false);
  }

  data(path: string): Data | undefined {
    return this.store.read(path);
  }

  pathsUnder(prefix: string): string[] {
    return this.store.paths().filter((path) => path.startsWith(prefix));
  }

  reset(): void {
    this.store.docs.clear();
  }
}

// One instance per test file (globalThis is per-file in Jest), shared by the
// mocked firestore.service and by the test itself.
const globalScope = globalThis as unknown as { __asaasFakeDb?: FakeDb };
export const fakeDb: FakeDb = globalScope.__asaasFakeDb ?? (globalScope.__asaasFakeDb = new FakeDb());

export const SERVER_TIMESTAMP = { __fake: 'serverTimestamp' };

export const firestoreServiceMock = {
  db: fakeDb,
  getTenantCollection: (companyId: string, collection: string) =>
    fakeDb.collection('companies').doc(companyId).collection(collection),
  Timestamp,
  FieldValue: { serverTimestamp: () => SERVER_TIMESTAMP },
};
```

- [ ] **Step 2: Adicionar os tipos do webhook em `asaas.types.ts`**

Em `firebase/functions/src/models/asaas.types.ts`, adicionar no topo (junto dos outros imports):

```ts
import type { PaymentTransaction } from './types';
```

Dentro de `export interface OrderCharge { ... }`, logo depois do campo `paidAt?: string;`:

```ts
  /** Server-only copy of every transaction booked on the order (used by the repair trigger). */
  appliedTransactions?: PaymentTransaction[];
```

No fim do arquivo:

```ts
// ============================================================================
// Webhook (POST /webhooks/asaas/:companyId)
// ============================================================================

export type AsaasWebhookEventName =
  | 'PAYMENT_RECEIVED'
  | 'PAYMENT_CONFIRMED'
  | 'PAYMENT_OVERDUE'
  | 'PAYMENT_REFUNDED'
  | 'PAYMENT_DELETED';

/** Subset of the Asaas payment object sent in webhook events (extra fields are ignored). */
export interface AsaasPaymentEvent {
  id: string;
  value: number;
  netValue?: number;
  /** PIX | BOLETO | CREDIT_CARD | DEBIT_CARD | UNDEFINED | RECEIVED_IN_CASH ... */
  billingType: string;
  status: string;
  /** '<companyId>:<orderId>:<chargeId>' set by createOrderCharge. */
  externalReference?: string | null;
  /** Installment id, only for installment payments. */
  installment?: string | null;
  installmentNumber?: number | null;
  description?: string | null;
}

export interface AsaasWebhookEvent {
  /** Unique event id (e.g. 'evt_05b7...&368604920'), used for idempotency. */
  id: string;
  /** Event name; only AsaasWebhookEventName values are handled. */
  event: string;
  dateCreated?: string;
  payment?: AsaasPaymentEvent;
}
```

- [ ] **Step 3: Escrever o teste que falha**

`firebase/functions/src/services/asaas/__tests__/order-payment.service.test.ts`:

```ts
jest.mock('../../firestore.service', () => jest.requireActual('./asaas-fake-db').firestoreServiceMock);

import { fakeDb } from './asaas-fake-db';
import { applyAsaasPayment, computePaymentFields } from '../order-payment.service';
import type { AsaasPaymentEvent, OrderCharge } from '../../../models/asaas.types';

const ORDER_PATH = 'companies/c1/orders/o1';
const CHARGE_PATH = `${ORDER_PATH}/charges/ch1`;

function seedOrder(overrides: Record<string, unknown> = {}) {
  fakeDb.seed(ORDER_PATH, {
    number: 42,
    total: 1000,
    paidAmount: 0,
    paid: false,
    payment: 'unpaid',
    transactions: [],
    ...overrides,
  });
}

function seedCharge(overrides: Partial<OrderCharge> = {}) {
  fakeDb.seed(CHARGE_PATH, {
    id: 'ch1',
    asaasPaymentId: 'pay_1',
    mode: 'single',
    value: 1000,
    dueDate: '2026-10-10',
    status: 'pending',
    invoiceUrl: 'https://sandbox.asaas.com/i/1',
    paidAsaasPaymentIds: [],
    createdBy: { id: 'u1', name: 'Ana' },
    createdAt: '2026-10-04T10:00:00.000Z',
    ...overrides,
  });
}

function payment(overrides: Partial<AsaasPaymentEvent> = {}): AsaasPaymentEvent {
  return {
    id: 'pay_1',
    value: 1000,
    netValue: 990.01,
    billingType: 'PIX',
    status: 'RECEIVED',
    externalReference: 'c1:o1:ch1',
    installment: null,
    description: 'OS #42 - Oficina',
    ...overrides,
  };
}

describe('order-payment.service - applyAsaasPayment', () => {
  beforeEach(() => fakeDb.reset());

  it('lança o pagamento Pix na OS e marca a cobrança como paga', async () => {
    seedOrder();
    seedCharge();

    const result = await applyAsaasPayment('c1', 'o1', 'ch1', payment());

    expect(result).toEqual({ applied: true });
    const order = fakeDb.data(ORDER_PATH)!;
    expect(order.paidAmount).toBe(1000);
    expect(order.paid).toBe(true);
    expect(order.payment).toBe('paid');
    expect(order.transactions).toEqual([
      {
        id: 'asaas_pay_1',
        type: 'payment',
        amount: 1000,
        description: 'Asaas • Pix',
        createdAt: expect.stringMatching(/^\d{4}-\d{2}-\d{2}T/),
        createdBy: { id: 'asaas', name: 'Asaas' },
      },
    ]);
    const charge = fakeDb.data(CHARGE_PATH)!;
    expect(charge.status).toBe('paid');
    expect(charge.paidAt).toEqual(expect.stringMatching(/^\d{4}-\d{2}-\d{2}T/));
    expect(charge.paidAsaasPaymentIds).toEqual(['pay_1']);
    expect(charge.appliedTransactions).toEqual(order.transactions);
  });

  it('não lança duas vezes o mesmo pagamento (CONFIRMED + RECEIVED)', async () => {
    seedOrder();
    seedCharge();

    await applyAsaasPayment('c1', 'o1', 'ch1', payment({ billingType: 'CREDIT_CARD', status: 'CONFIRMED' }));
    const second = await applyAsaasPayment('c1', 'o1', 'ch1', payment({ billingType: 'CREDIT_CARD' }));

    expect(second).toEqual({ applied: false });
    const order = fakeDb.data(ORDER_PATH)!;
    expect(order.transactions).toHaveLength(1);
    expect(order.paidAmount).toBe(1000);
  });

  it('entrada menor que o total deixa a OS unpaid e a cobrança à vista paga', async () => {
    seedOrder();
    seedCharge({ value: 300 });

    await applyAsaasPayment('c1', 'o1', 'ch1', payment({ value: 300, billingType: 'BOLETO' }));

    const order = fakeDb.data(ORDER_PATH)!;
    expect(order.paidAmount).toBe(300);
    expect(order.paid).toBe(false);
    expect(order.payment).toBe('unpaid');
    expect((order.transactions as any[])[0].description).toBe('Asaas • Boleto');
    expect(fakeDb.data(CHARGE_PATH)!.status).toBe('paid');
  });

  it('parcelado: só marca a cobrança paga quando todas as parcelas entram', async () => {
    seedOrder({ total: 900 });
    seedCharge({ mode: 'cardInstallments', installmentCount: 3, value: 900, asaasInstallmentId: 'ins_1' });

    for (const n of [1, 2]) {
      await applyAsaasPayment('c1', 'o1', 'ch1', payment({
        id: `pay_${n}`, value: 300, billingType: 'CREDIT_CARD', installment: 'ins_1', installmentNumber: n,
      }));
    }
    expect(fakeDb.data(CHARGE_PATH)!.status).toBe('pending');
    expect(fakeDb.data(ORDER_PATH)!.payment).toBe('unpaid');

    await applyAsaasPayment('c1', 'o1', 'ch1', payment({
      id: 'pay_3', value: 300, billingType: 'CREDIT_CARD', installment: 'ins_1', installmentNumber: 3,
    }));

    const order = fakeDb.data(ORDER_PATH)!;
    expect((order.transactions as any[]).map((t) => t.description)).toEqual([
      'Asaas • Cartão 1/3',
      'Asaas • Cartão 2/3',
      'Asaas • Cartão 3/3',
    ]);
    expect(order.paidAmount).toBe(900);
    expect(order.payment).toBe('paid');
    expect(fakeDb.data(CHARGE_PATH)!.status).toBe('paid');
  });

  it('mantém pagamentos manuais existentes ao recalcular', async () => {
    seedOrder({
      paidAmount: 200,
      transactions: [{
        id: 'manual1', type: 'payment', amount: 200, description: 'Dinheiro',
        createdAt: '2026-10-01T10:00:00.000Z', createdBy: { id: 'u1', name: 'Ana' },
      }],
    });
    seedCharge({ value: 800 });

    await applyAsaasPayment('c1', 'o1', 'ch1', payment({ value: 800 }));

    const order = fakeDb.data(ORDER_PATH)!;
    expect(order.paidAmount).toBe(1000);
    expect(order.payment).toBe('paid');
    expect(order.transactions).toHaveLength(2);
  });

  it('retorna applied=false quando a OS não existe', async () => {
    seedCharge();
    await expect(applyAsaasPayment('c1', 'o1', 'ch1', payment())).resolves.toEqual({ applied: false });
  });
});

describe('order-payment.service - computePaymentFields', () => {
  it('preserva paidAmount legado sem transações', () => {
    const fields = computePaymentFields(
      { total: 1000, paidAmount: 200, transactions: [] },
      [{ id: 'asaas_x', type: 'payment', amount: 300, createdAt: '2026-10-04T00:00:00.000Z', createdBy: { id: 'asaas', name: 'Asaas' } }],
    );
    expect(fields.paidAmount).toBe(500);
    expect(fields.payment).toBe('unpaid');
  });

  it('OS com total zero nunca fica paga', () => {
    const fields = computePaymentFields({ total: 0, paidAmount: 0, transactions: [] }, []);
    expect(fields).toEqual({ transactions: [], paidAmount: 0, paid: false, payment: 'unpaid' });
  });
});
```

- [ ] **Step 4: Rodar e ver falhar**

```bash
cd firebase/functions && npx jest src/services/asaas/__tests__/order-payment.service.test.ts
```

Esperado: FAIL com `Cannot find module '../order-payment.service'`.

- [ ] **Step 5: Implementar `order-payment.service.ts` (lançamento)**

`firebase/functions/src/services/asaas/order-payment.service.ts`:

```ts
/**
 * Order payment bookkeeping for Asaas charges.
 *
 * Every Asaas payment confirmed for an order charge becomes one
 * PaymentTransaction on the order (`id = asaas_<paymentId>`, type `payment`,
 * never a new type: old app versions decode it with $enumDecode). The charge
 * document is the source of truth: `paidAsaasPaymentIds` lists the payments
 * already booked and `appliedTransactions` keeps a copy of each booked
 * transaction so the repair trigger can restore one that an old app version
 * overwrote.
 *
 * Payment status follows the app convention: `paid` | `unpaid` ("partial" is
 * computed in memory by the app).
 */
import { db } from '../firestore.service';
import type { PaymentTransaction, UserAggr } from '../../models/types';
import type { AsaasPaymentEvent, OrderCharge } from '../../models/asaas.types';

export const ASAAS_TRANSACTION_PREFIX = 'asaas_';
export const ASAAS_ACTOR: UserAggr = { id: 'asaas', name: 'Asaas' };

export interface OrderPaymentState {
  total?: number;
  paidAmount?: number;
  transactions?: PaymentTransaction[];
}

export interface OrderPaymentFields {
  transactions: PaymentTransaction[];
  paidAmount: number;
  paid: boolean;
  payment: 'paid' | 'unpaid';
}

const BILLING_TYPE_LABELS: Record<string, string> = {
  PIX: 'Pix',
  BOLETO: 'Boleto',
  CREDIT_CARD: 'Cartão',
  DEBIT_CARD: 'Cartão',
};

function roundCents(value: number): number {
  return Math.round(value * 100) / 100;
}

export function orderRef(companyId: string, orderId: string) {
  return db.collection('companies').doc(companyId).collection('orders').doc(orderId);
}

export function chargeRef(companyId: string, orderId: string, chargeId: string) {
  return orderRef(companyId, orderId).collection('charges').doc(chargeId);
}

export function asaasTransactionId(asaasPaymentId: string): string {
  return `${ASAAS_TRANSACTION_PREFIX}${asaasPaymentId}`;
}

/** 'Asaas • Pix' | 'Asaas • Boleto' | 'Asaas • Cartão' (+ ' n/N' for card installments). */
export function describeAsaasPayment(
  payment: AsaasPaymentEvent,
  charge: Pick<OrderCharge, 'mode' | 'installmentCount'>,
  fallbackInstallmentNumber?: number,
): string {
  const label = BILLING_TYPE_LABELS[payment.billingType];
  let description = label ? `Asaas • ${label}` : 'Asaas';
  const installmentNumber = payment.installmentNumber ?? fallbackInstallmentNumber;
  if (charge.mode === 'cardInstallments' && charge.installmentCount && installmentNumber) {
    description += ` ${installmentNumber}/${charge.installmentCount}`;
  }
  return description;
}

export function buildAsaasTransaction(
  payment: AsaasPaymentEvent,
  charge: Pick<OrderCharge, 'mode' | 'installmentCount'>,
  now: Date,
  fallbackInstallmentNumber?: number,
): PaymentTransaction {
  return {
    id: asaasTransactionId(payment.id),
    type: 'payment',
    amount: roundCents(Number(payment.value) || 0),
    description: describeAsaasPayment(payment, charge, fallbackInstallmentNumber),
    createdAt: now.toISOString(),
    createdBy: { ...ASAAS_ACTOR },
  };
}

function sumPayments(transactions: PaymentTransaction[]): number {
  return transactions
    .filter((t) => t.type === 'payment')
    .reduce((sum, t) => sum + (Number(t.amount) || 0), 0);
}

/**
 * Recomputes paidAmount/paid/payment for a new transaction list.
 * Any paidAmount the previous state had beyond its payment transactions
 * (legacy orders paid before transactions existed) is preserved.
 */
export function computePaymentFields(
  previous: OrderPaymentState,
  nextTransactions: PaymentTransaction[],
): OrderPaymentFields {
  const untracked = Math.max(0, roundCents((previous.paidAmount ?? 0) - sumPayments(previous.transactions ?? [])));
  const paidAmount = roundCents(sumPayments(nextTransactions) + untracked);
  const total = Number(previous.total ?? 0);
  const paid = total > 0 && paidAmount >= total;
  return { transactions: nextTransactions, paidAmount, paid, payment: paid ? 'paid' : 'unpaid' };
}

function expectedPaymentCount(charge: OrderCharge): number {
  return Math.max(1, charge.installmentCount ?? 1);
}

/**
 * Books an Asaas payment on the order inside a transaction. Idempotent per
 * payment id: returns { applied: false } if it was already booked or if the
 * order/charge no longer exists.
 */
export async function applyAsaasPayment(
  companyId: string,
  orderId: string,
  chargeId: string,
  payment: AsaasPaymentEvent,
): Promise<{ applied: boolean }> {
  const oRef = orderRef(companyId, orderId);
  const cRef = chargeRef(companyId, orderId, chargeId);

  return db.runTransaction(async (tx) => {
    const [orderSnap, chargeSnap] = await Promise.all([tx.get(oRef), tx.get(cRef)]);
    if (!orderSnap.exists || !chargeSnap.exists) {
      console.warn('[AsaasPayment] order or charge not found', { companyId, orderId, chargeId });
      return { applied: false };
    }

    const order = orderSnap.data() as OrderPaymentState;
    const charge = chargeSnap.data() as OrderCharge;
    const paidIds = charge.paidAsaasPaymentIds ?? [];
    if (paidIds.includes(payment.id)) return { applied: false };

    const now = new Date();
    const transaction = buildAsaasTransaction(payment, charge, now, paidIds.length + 1);
    const current = order.transactions ?? [];
    const nextTransactions = current.some((t) => t.id === transaction.id) ? current : [...current, transaction];
    const fields = computePaymentFields(order, nextTransactions);

    const nextPaidIds = [...paidIds, payment.id];
    const chargeUpdate: FirebaseFirestore.DocumentData = {
      paidAsaasPaymentIds: nextPaidIds,
      appliedTransactions: [
        ...(charge.appliedTransactions ?? []).filter((t) => t.id !== transaction.id),
        transaction,
      ],
    };
    if (nextPaidIds.length >= expectedPaymentCount(charge)) {
      chargeUpdate.status = 'paid';
      chargeUpdate.paidAt = now.toISOString();
    }

    tx.update(oRef, { ...fields, updatedAt: now.toISOString(), updatedBy: { ...ASAAS_ACTOR } });
    tx.update(cRef, chargeUpdate);
    return { applied: true };
  });
}
```

- [ ] **Step 6: Rodar os testes**

```bash
cd firebase/functions && npx jest src/services/asaas/__tests__/order-payment.service.test.ts && npm run lint
```

Esperado: PASS (8 testes) e lint sem erros.

- [ ] **Step 7: Commit**

```bash
git add firebase/functions/src/models/asaas.types.ts \
  firebase/functions/src/services/asaas/order-payment.service.ts \
  firebase/functions/src/services/asaas/__tests__/asaas-fake-db.ts \
  firebase/functions/src/services/asaas/__tests__/order-payment.service.test.ts
git commit -m "feat(asaas): lança pagamento Asaas na OS em transação

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task C2: `revertAsaasPayment` com registro no histórico da OS

**Files:**
- Modify: `firebase/functions/src/models/types.ts:512` (`CommentSource`)
- Modify: `firebase/functions/src/services/asaas/order-payment.service.ts` (import + função nova no fim)
- Test: `firebase/functions/src/services/asaas/__tests__/order-payment.service.test.ts` (novo `describe` no fim)

**Interfaces:**
- Consumes: `applyAsaasPayment`, `computePaymentFields`, `FieldValue.serverTimestamp()`
- Produces: `revertAsaasPayment(companyId: string, orderId: string, chargeId: string, asaasPaymentId: string): Promise<{ reverted: boolean }>`

- [ ] **Step 1: Escrever o teste que falha**

No `order-payment.service.test.ts`, trocar o import do serviço por:

```ts
import { applyAsaasPayment, computePaymentFields, revertAsaasPayment } from '../order-payment.service';
```

e acrescentar no fim do arquivo:

```ts
describe('order-payment.service - revertAsaasPayment', () => {
  beforeEach(() => fakeDb.reset());

  it('remove a transação, recalcula, marca refunded e registra no histórico', async () => {
    seedOrder();
    seedCharge();
    await applyAsaasPayment('c1', 'o1', 'ch1', payment());

    const result = await revertAsaasPayment('c1', 'o1', 'ch1', 'pay_1');

    expect(result).toEqual({ reverted: true });
    const order = fakeDb.data(ORDER_PATH)!;
    expect(order.transactions).toEqual([]);
    expect(order.paidAmount).toBe(0);
    expect(order.paid).toBe(false);
    expect(order.payment).toBe('unpaid');

    const charge = fakeDb.data(CHARGE_PATH)!;
    expect(charge.status).toBe('refunded');
    expect(charge.paidAsaasPaymentIds).toEqual([]);
    expect(charge.appliedTransactions).toEqual([]);

    const commentPaths = fakeDb.pathsUnder(`${ORDER_PATH}/comments/`);
    expect(commentPaths).toHaveLength(1);
    const comment = fakeDb.data(commentPaths[0])!;
    expect(comment).toEqual(expect.objectContaining({
      authorType: 'internal',
      author: { name: 'Asaas' },
      source: 'asaas',
      isInternal: true,
    }));
    expect(comment.text).toContain('estornado');
    expect(comment.text).toContain('1.000,00');
    expect(comment.text).toContain('Asaas • Pix');
  });

  it('não faz nada quando o pagamento nunca foi lançado', async () => {
    seedOrder();
    seedCharge();

    const result = await revertAsaasPayment('c1', 'o1', 'ch1', 'pay_1');

    expect(result).toEqual({ reverted: false });
    expect(fakeDb.data(CHARGE_PATH)!.status).toBe('pending');
    expect(fakeDb.pathsUnder(`${ORDER_PATH}/comments/`)).toHaveLength(0);
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
cd firebase/functions && npx jest src/services/asaas/__tests__/order-payment.service.test.ts
```

Esperado: FAIL — `revertAsaasPayment is not a function` (erro de import/TS `has no exported member 'revertAsaasPayment'`).

- [ ] **Step 3: Implementar**

Em `firebase/functions/src/models/types.ts`, linha 512, trocar:

```ts
export type CommentSource = 'app' | 'magicLink' | 'bot';
```

por:

```ts
export type CommentSource = 'app' | 'magicLink' | 'bot' | 'asaas';
```

Em `order-payment.service.ts`, trocar o import do firestore por:

```ts
import { db, FieldValue } from '../firestore.service';
```

e acrescentar no fim do arquivo:

```ts
const brlFormatter = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' });

/**
 * Reverts a refunded Asaas payment: removes `asaas_<id>` from the order,
 * recomputes the payment fields, marks the charge `refunded` and adds an
 * internal audit comment to the order history (same pattern as the magic-link
 * approve/reject/rating comments).
 */
export async function revertAsaasPayment(
  companyId: string,
  orderId: string,
  chargeId: string,
  asaasPaymentId: string,
): Promise<{ reverted: boolean }> {
  const oRef = orderRef(companyId, orderId);
  const cRef = chargeRef(companyId, orderId, chargeId);
  const transactionId = asaasTransactionId(asaasPaymentId);

  return db.runTransaction(async (tx) => {
    const [orderSnap, chargeSnap] = await Promise.all([tx.get(oRef), tx.get(cRef)]);
    if (!orderSnap.exists || !chargeSnap.exists) {
      console.warn('[AsaasPayment] order or charge not found on refund', { companyId, orderId, chargeId });
      return { reverted: false };
    }

    const order = orderSnap.data() as OrderPaymentState;
    const charge = chargeSnap.data() as OrderCharge;
    const current = order.transactions ?? [];
    const paidIds = charge.paidAsaasPaymentIds ?? [];
    const wasApplied = paidIds.includes(asaasPaymentId) || current.some((t) => t.id === transactionId);
    if (!wasApplied) return { reverted: false };

    const removed =
      current.find((t) => t.id === transactionId) ??
      (charge.appliedTransactions ?? []).find((t) => t.id === transactionId);
    const now = new Date();
    const fields = computePaymentFields(order, current.filter((t) => t.id !== transactionId));

    tx.update(oRef, { ...fields, updatedAt: now.toISOString(), updatedBy: { ...ASAAS_ACTOR } });
    tx.update(cRef, {
      status: 'refunded',
      paidAsaasPaymentIds: paidIds.filter((id) => id !== asaasPaymentId),
      appliedTransactions: (charge.appliedTransactions ?? []).filter((t) => t.id !== transactionId),
    });

    const detail = removed
      ? `: ${brlFormatter.format(Number(removed.amount) || 0)} (${removed.description ?? 'Asaas'})`
      : '';
    tx.set(oRef.collection('comments').doc(), {
      text: `Pagamento estornado no Asaas${detail}. O saldo da OS foi recalculado.`,
      authorType: 'internal',
      author: { name: 'Asaas' },
      source: 'asaas',
      isInternal: true,
      createdAt: FieldValue.serverTimestamp(),
    });

    return { reverted: true };
  });
}
```

- [ ] **Step 4: Rodar os testes**

```bash
cd firebase/functions && npx jest src/services/asaas/__tests__/order-payment.service.test.ts && npm run lint
```

Esperado: PASS (10 testes).

- [ ] **Step 5: Commit**

```bash
git add firebase/functions/src/models/types.ts \
  firebase/functions/src/services/asaas/order-payment.service.ts \
  firebase/functions/src/services/asaas/__tests__/order-payment.service.test.ts
git commit -m "feat(asaas): estorna pagamento Asaas na OS e registra no histórico

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task C3: `repairAsaasTransactions` e trigger `repairAsaasPayments`

**Files:**
- Modify: `firebase/functions/src/services/asaas/order-payment.service.ts` (funções novas no fim)
- Modify: `firebase/functions/src/index.ts` — import na linha 11 (depois de `import { beforeUserCreated } ...`) e bloco novo antes de `// AUTH BLOCKING FUNCTIONS` (linha 149 na master atual)
- Test: `firebase/functions/src/services/asaas/__tests__/order-payment.service.test.ts` (novo `describe`)

**Interfaces:**
- Consumes: `applyAsaasPayment`, `revertAsaasPayment`, `computePaymentFields`, `companies/{cid}/settings/payments.asaasConnected`
- Produces: `repairAsaasTransactions(companyId: string, orderId: string): Promise<{ repaired: number }>`, `runAsaasRepairOnOrderUpdate(companyId: string, orderId: string, before: OrderPaymentState | undefined, after: OrderPaymentState | undefined): Promise<{ repaired: number }>`, `transactionsChanged(before, after): boolean`, `export const repairAsaasPayments = onDocumentUpdated(...)`

- [ ] **Step 1: Escrever o teste que falha**

Trocar o import do serviço no teste por:

```ts
import {
  applyAsaasPayment,
  computePaymentFields,
  repairAsaasTransactions,
  revertAsaasPayment,
  runAsaasRepairOnOrderUpdate,
} from '../order-payment.service';
```

e acrescentar no fim:

```ts
describe('order-payment.service - repair', () => {
  const SETTINGS_PATH = 'companies/c1/settings/payments';

  beforeEach(() => fakeDb.reset());

  async function overwriteLikeOldApp() {
    // Old app version saves a stale copy of the order without the Asaas payment.
    seedOrder({ paidAmount: 0, paid: false, payment: 'unpaid', transactions: [] });
  }

  it('reinsere a transação Asaas apagada por versão antiga do app', async () => {
    seedOrder();
    seedCharge();
    await applyAsaasPayment('c1', 'o1', 'ch1', payment());
    const booked = fakeDb.data(ORDER_PATH)!.transactions;
    await overwriteLikeOldApp();

    await expect(repairAsaasTransactions('c1', 'o1')).resolves.toEqual({ repaired: 1 });

    const order = fakeDb.data(ORDER_PATH)!;
    expect(order.transactions).toEqual(booked);
    expect(order.paidAmount).toBe(1000);
    expect(order.payment).toBe('paid');
  });

  it('não escreve quando nada falta (sem loop no trigger)', async () => {
    seedOrder();
    seedCharge();
    await applyAsaasPayment('c1', 'o1', 'ch1', payment());
    const before = fakeDb.data(ORDER_PATH);

    await expect(repairAsaasTransactions('c1', 'o1')).resolves.toEqual({ repaired: 0 });
    expect(fakeDb.data(ORDER_PATH)).toEqual(before);
  });

  it('não reinsere pagamento estornado', async () => {
    seedOrder();
    seedCharge();
    await applyAsaasPayment('c1', 'o1', 'ch1', payment());
    await revertAsaasPayment('c1', 'o1', 'ch1', 'pay_1');

    await expect(repairAsaasTransactions('c1', 'o1')).resolves.toEqual({ repaired: 0 });
    expect(fakeDb.data(ORDER_PATH)!.transactions).toEqual([]);
  });

  it('runAsaasRepairOnOrderUpdate ignora updates sem mudança em transactions', async () => {
    fakeDb.seed(SETTINGS_PATH, { asaasEnabled: true, asaasConnected: true });
    seedOrder();
    seedCharge();
    await applyAsaasPayment('c1', 'o1', 'ch1', payment());
    await overwriteLikeOldApp();

    const same = { transactions: [] };
    await expect(runAsaasRepairOnOrderUpdate('c1', 'o1', same, same)).resolves.toEqual({ repaired: 0 });
    expect(fakeDb.data(ORDER_PATH)!.transactions).toEqual([]);
  });

  it('runAsaasRepairOnOrderUpdate ignora empresas sem Asaas conectado', async () => {
    fakeDb.seed(SETTINGS_PATH, { asaasEnabled: true, asaasConnected: false });
    seedOrder();
    seedCharge();
    await applyAsaasPayment('c1', 'o1', 'ch1', payment());
    const applied = fakeDb.data(ORDER_PATH)!.transactions as any[];
    await overwriteLikeOldApp();

    await expect(
      runAsaasRepairOnOrderUpdate('c1', 'o1', { transactions: applied }, { transactions: [] }),
    ).resolves.toEqual({ repaired: 0 });
  });

  it('runAsaasRepairOnOrderUpdate repara quando transactions mudou e a conta está conectada', async () => {
    fakeDb.seed(SETTINGS_PATH, { asaasEnabled: true, asaasConnected: true });
    seedOrder();
    seedCharge();
    await applyAsaasPayment('c1', 'o1', 'ch1', payment());
    const applied = fakeDb.data(ORDER_PATH)!.transactions as any[];
    await overwriteLikeOldApp();

    await expect(
      runAsaasRepairOnOrderUpdate('c1', 'o1', { transactions: applied }, { transactions: [] }),
    ).resolves.toEqual({ repaired: 1 });
    expect(fakeDb.data(ORDER_PATH)!.paidAmount).toBe(1000);
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
cd firebase/functions && npx jest src/services/asaas/__tests__/order-payment.service.test.ts
```

Esperado: FAIL — `has no exported member 'repairAsaasTransactions'`.

- [ ] **Step 3: Implementar o reparo**

No fim de `order-payment.service.ts`:

```ts
/**
 * Puts back every booked Asaas transaction that is missing from the order
 * (an old app version saved a stale copy of `transactions`). Charges are the
 * source of truth. Writes only when something is missing, so the trigger that
 * calls it does not loop.
 */
export async function repairAsaasTransactions(
  companyId: string,
  orderId: string,
): Promise<{ repaired: number }> {
  const oRef = orderRef(companyId, orderId);
  const chargesRef = oRef.collection('charges');

  return db.runTransaction(async (tx) => {
    const orderSnap = await tx.get(oRef);
    if (!orderSnap.exists) return { repaired: 0 };
    const chargesSnap = await tx.get(chargesRef);

    const order = orderSnap.data() as OrderPaymentState;
    const current = order.transactions ?? [];
    const present = new Set(current.map((t) => t.id));
    const missing: PaymentTransaction[] = [];

    for (const doc of chargesSnap.docs) {
      const charge = doc.data() as OrderCharge;
      const paidIds = new Set(charge.paidAsaasPaymentIds ?? []);
      for (const transaction of charge.appliedTransactions ?? []) {
        const paymentId = transaction.id.slice(ASAAS_TRANSACTION_PREFIX.length);
        if (paidIds.has(paymentId) && !present.has(transaction.id)) {
          missing.push(transaction);
          present.add(transaction.id);
        }
      }
    }

    if (missing.length === 0) return { repaired: 0 };

    const fields = computePaymentFields(order, [...current, ...missing]);
    tx.update(oRef, { ...fields, updatedAt: new Date().toISOString(), updatedBy: { ...ASAAS_ACTOR } });
    console.log('[AsaasPayment] repaired order transactions', { companyId, orderId, repaired: missing.length });
    return { repaired: missing.length };
  });
}

export function transactionsChanged(
  before: OrderPaymentState | undefined,
  after: OrderPaymentState | undefined,
): boolean {
  return JSON.stringify(before?.transactions ?? []) !== JSON.stringify(after?.transactions ?? []);
}

/**
 * Body of the `repairAsaasPayments` trigger. Cheap exit (no reads) when the
 * update did not touch `transactions`; then only for companies with Asaas
 * connected.
 */
export async function runAsaasRepairOnOrderUpdate(
  companyId: string,
  orderId: string,
  before: OrderPaymentState | undefined,
  after: OrderPaymentState | undefined,
): Promise<{ repaired: number }> {
  if (!transactionsChanged(before, after)) return { repaired: 0 };

  const settingsSnap = await db
    .collection('companies').doc(companyId)
    .collection('settings').doc('payments')
    .get();
  if (!settingsSnap.exists || settingsSnap.data()?.asaasConnected !== true) return { repaired: 0 };

  return repairAsaasTransactions(companyId, orderId);
}
```

- [ ] **Step 4: Registrar o trigger em `index.ts`**

Em `firebase/functions/src/index.ts`, depois da linha `import { beforeUserCreated } from 'firebase-functions/v2/identity';`:

```ts
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';
```

Antes do bloco `// AUTH BLOCKING FUNCTIONS` (cabeçalho `// ====` que o precede):

```ts
// ============================================================================
// ASAAS PAYMENTS REPAIR
// ============================================================================

import { runAsaasRepairOnOrderUpdate } from './services/asaas/order-payment.service';

/**
 * Restores Asaas payment transactions removed from an order by old app
 * versions that save the whole order document. Charges are the source of
 * truth; the repair only writes when a booked `asaas_<id>` transaction is
 * missing, so its own write does not trigger another write.
 */
export const repairAsaasPayments = onDocumentUpdated(
  {
    document: 'companies/{companyId}/orders/{orderId}',
    region: 'southamerica-east1',
    memory: '256MiB',
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    const { companyId, orderId } = event.params;
    await runAsaasRepairOnOrderUpdate(companyId, orderId, before, after);
  }
);
```

- [ ] **Step 5: Rodar testes, lint e build**

```bash
cd firebase/functions && npx jest src/services/asaas/__tests__/order-payment.service.test.ts && npm run lint && npm run build
```

Esperado: PASS (16 testes), lint limpo, `tsc` sem erros.

- [ ] **Step 6: Commit**

```bash
git add firebase/functions/src/services/asaas/order-payment.service.ts \
  firebase/functions/src/services/asaas/__tests__/order-payment.service.test.ts \
  firebase/functions/src/index.ts
git commit -m "feat(asaas): trigger de reparo de pagamentos Asaas sobrescritos

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task C4: Push "Pagamento recebido" para dono/admin/gerente

**Files:**
- Modify: `firebase/functions/src/services/notification.service.ts` (função nova antes de `notifyOrderApproved`, linha 199 na master atual)
- Test: `firebase/functions/src/services/__tests__/notification.asaas.test.ts`

**Interfaces:**
- Consumes: `sendNotification` (privada, mesmo arquivo), `companies/{cid}` (`owner`, `users[]`), `companies/{cid}/orders/{oid}.number`
- Produces: `notifyAsaasPaymentReceived(companyId: string, orderId: string, amount: number): Promise<void>` (nunca lança)

- [ ] **Step 1: Escrever o teste que falha**

`firebase/functions/src/services/__tests__/notification.asaas.test.ts`:

```ts
const mockSendEachForMulticast = jest.fn();

jest.mock('firebase-admin/messaging', () => ({
  getMessaging: () => ({ sendEachForMulticast: mockSendEachForMulticast }),
}));
jest.mock('../firestore.service', () => jest.requireActual('../asaas/__tests__/asaas-fake-db').firestoreServiceMock);

import { fakeDb } from '../asaas/__tests__/asaas-fake-db';
import { notifyAsaasPaymentReceived } from '../notification.service';

describe('notification.service - notifyAsaasPaymentReceived', () => {
  beforeEach(() => {
    fakeDb.reset();
    jest.clearAllMocks();
    mockSendEachForMulticast.mockResolvedValue({ successCount: 3, failureCount: 0, responses: [] });

    fakeDb.seed('companies/c1', {
      name: 'Oficina',
      owner: { id: 'owner1', name: 'Dono' },
      users: [
        { user: { id: 'owner1', name: 'Dono' }, role: 'admin' },
        { user: { id: 'adm1', name: 'Admin' }, role: 'admin' },
        { user: { id: 'mgr1', name: 'Gerente' }, role: 'manager' },
        { user: { id: 'sup1', name: 'Supervisor' }, role: 'supervisor' },
        { user: { id: 'tec1', name: 'Técnico' }, role: 'technician' },
      ],
    });
    fakeDb.seed('companies/c1/orders/o1', {
      number: 42,
      assignedTo: { id: 'tec1', name: 'Técnico' },
      createdBy: { id: 'tec1', name: 'Técnico' },
    });
    for (const id of ['owner1', 'adm1', 'mgr1', 'sup1', 'tec1']) {
      fakeDb.seed(`users/${id}`, { fcmTokens: [{ token: `fcm_${id}` }] });
    }
  });

  it('notifica só dono, admin e gerente com OS e valor', async () => {
    await notifyAsaasPaymentReceived('c1', 'o1', 150);

    const notifications = fakeDb
      .pathsUnder('companies/c1/notifications/')
      .map((path) => fakeDb.data(path)!);
    expect(notifications.map((n) => n.recipientId).sort()).toEqual(['adm1', 'mgr1', 'owner1']);
    expect(notifications[0].type).toBe('payment_received');
    expect(notifications[0].orderId).toBe('o1');
    expect(notifications[0].body).toMatch(/OS #42/);
    expect(notifications[0].body).toMatch(/R\$\s?150,00/);

    expect(mockSendEachForMulticast).toHaveBeenCalledTimes(1);
    const message = mockSendEachForMulticast.mock.calls[0][0];
    expect(message.tokens.sort()).toEqual(['fcm_adm1', 'fcm_mgr1', 'fcm_owner1']);
    expect(message.notification.title).toBe('Pagamento recebido');
  });

  it('não lança quando a empresa não existe', async () => {
    fakeDb.reset();
    await expect(notifyAsaasPaymentReceived('c1', 'o1', 10)).resolves.toBeUndefined();
    expect(mockSendEachForMulticast).not.toHaveBeenCalled();
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
cd firebase/functions && npx jest src/services/__tests__/notification.asaas.test.ts
```

Esperado: FAIL — `has no exported member 'notifyAsaasPaymentReceived'`.

- [ ] **Step 3: Implementar**

Em `notification.service.ts`, antes do comentário `/** Notify when a customer approves a quote via magic link */`:

```ts
// Roles that receive Asaas payment notifications (financial roles only)
const PAYMENT_NOTIFICATION_ROLES: RoleType[] = ['owner', 'admin', 'manager'];

const brlFormatter = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' });

/**
 * Owner + users with a financial role. Unlike getNotificationRecipients, the
 * assigned technician and the order creator are not included.
 */
async function getPaymentNotificationRecipients(companyId: string): Promise<NotificationRecipient[]> {
  const recipients: NotificationRecipient[] = [];
  const added = new Set<string>();
  const companyDoc = await db.collection('companies').doc(companyId).get();
  if (!companyDoc.exists) return recipients;
  const company = companyDoc.data() as Company;

  if (company.owner?.id) {
    recipients.push({ userId: company.owner.id, name: company.owner.name });
    added.add(company.owner.id);
  }
  for (const userRole of company.users ?? []) {
    if (userRole.user?.id && PAYMENT_NOTIFICATION_ROLES.includes(userRole.role) && !added.has(userRole.user.id)) {
      recipients.push({ userId: userRole.user.id, name: userRole.user.name });
      added.add(userRole.user.id);
    }
  }
  return recipients;
}

/**
 * Notify owner/admin/manager that an Asaas payment was booked on an order.
 * Never throws: a failed push must not fail the webhook.
 */
export async function notifyAsaasPaymentReceived(
  companyId: string,
  orderId: string,
  amount: number
): Promise<void> {
  try {
    const recipients = await getPaymentNotificationRecipients(companyId);
    if (recipients.length === 0) {
      console.log('[NOTIFICATION] No recipients for Asaas payment notification');
      return;
    }

    const orderDoc = await db.collection('companies').doc(companyId).collection('orders').doc(orderId).get();
    const orderNumber = orderDoc.exists ? String(orderDoc.data()?.number ?? '') : '';

    const payload: NotificationPayload = {
      title: 'Pagamento recebido',
      body: `OS #${orderNumber} – ${brlFormatter.format(amount)}`,
      data: {
        type: 'payment_received',
        orderId,
        orderNumber,
        companyId,
      },
    };

    await sendNotification(recipients, payload, companyId);
  } catch (error) {
    console.error('Error sending Asaas payment notification:', error);
  }
}
```

- [ ] **Step 4: Rodar os testes**

```bash
cd firebase/functions && npx jest src/services/__tests__/notification.asaas.test.ts && npm run lint
```

Esperado: PASS (2 testes).

- [ ] **Step 5: Commit**

```bash
git add firebase/functions/src/services/notification.service.ts \
  firebase/functions/src/services/__tests__/notification.asaas.test.ts
git commit -m "feat(notifications): push de pagamento Asaas recebido para dono, admin e gerente

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task C5: `handleAsaasEvent` (idempotência, roteamento de eventos)

**Files:**
- Create: `firebase/functions/src/services/asaas/webhook.service.ts`
- Modify: `firebase/firestore.indexes.json:481-493` (`fieldOverrides`: índice de collection group para `charges.asaasInstallmentId`)
- Test: `firebase/functions/src/services/asaas/__tests__/webhook.service.test.ts`

**Interfaces:**
- Consumes: `applyAsaasPayment`, `revertAsaasPayment`, `chargeRef` (`order-payment.service.ts`), `notifyAsaasPaymentReceived`, `Timestamp` (`firestore.service.ts`)
- Produces: `handleAsaasEvent(companyId: string, event: AsaasWebhookEvent): Promise<void>`, `parseExternalReference(ref?: string | null): { companyId: string; orderId: string; chargeId: string } | null`; doc `companies/{cid}/private/asaas/events/{eventId}` = `{ processedAt: string, expiresAt: Timestamp }`

- [ ] **Step 1: Escrever o teste que falha**

`firebase/functions/src/services/asaas/__tests__/webhook.service.test.ts`:

```ts
jest.mock('../../firestore.service', () => jest.requireActual('./asaas-fake-db').firestoreServiceMock);
jest.mock('../../notification.service', () => ({
  notifyAsaasPaymentReceived: jest.fn().mockResolvedValue(undefined),
}));

import { fakeDb } from './asaas-fake-db';
import { handleAsaasEvent, parseExternalReference } from '../webhook.service';
import { notifyAsaasPaymentReceived } from '../../notification.service';
import type { AsaasPaymentEvent, AsaasWebhookEvent, OrderCharge } from '../../../models/asaas.types';

const mockNotify = notifyAsaasPaymentReceived as jest.Mock;
const ORDER_PATH = 'companies/c1/orders/o1';
const CHARGE_PATH = `${ORDER_PATH}/charges/ch1`;
const EVENTS_PREFIX = 'companies/c1/private/asaas/events/';

function seed(charge: Partial<OrderCharge> = {}) {
  fakeDb.seed(ORDER_PATH, { number: 42, total: 1000, paidAmount: 0, paid: false, payment: 'unpaid', transactions: [] });
  fakeDb.seed(CHARGE_PATH, {
    id: 'ch1', asaasPaymentId: 'pay_1', mode: 'single', value: 1000, dueDate: '2026-10-10',
    status: 'pending', invoiceUrl: 'https://sandbox.asaas.com/i/1', paidAsaasPaymentIds: [],
    createdBy: { id: 'u1', name: 'Ana' }, createdAt: '2026-10-04T10:00:00.000Z', ...charge,
  });
}

let eventCounter = 0;
function event(name: string, payment: Partial<AsaasPaymentEvent> = {}, id?: string): AsaasWebhookEvent {
  eventCounter += 1;
  return {
    id: id ?? `evt_${eventCounter}&368604920`,
    event: name,
    dateCreated: '2026-10-04 10:00:00',
    payment: {
      id: 'pay_1', value: 1000, netValue: 990, billingType: 'PIX', status: 'RECEIVED',
      externalReference: 'c1:o1:ch1', installment: null, description: 'OS #42', ...payment,
    },
  };
}

describe('webhook.service - parseExternalReference', () => {
  it('separa companyId, orderId e chargeId', () => {
    expect(parseExternalReference('c1:o1:ch1')).toEqual({ companyId: 'c1', orderId: 'o1', chargeId: 'ch1' });
  });

  it('rejeita formatos inválidos', () => {
    expect(parseExternalReference(null)).toBeNull();
    expect(parseExternalReference('c1:o1')).toBeNull();
    expect(parseExternalReference('c1::ch1')).toBeNull();
    expect(parseExternalReference('c1:o1:ch1:x')).toBeNull();
  });
});

describe('webhook.service - handleAsaasEvent', () => {
  beforeEach(() => {
    fakeDb.reset();
    mockNotify.mockClear();
  });

  it('PAYMENT_RECEIVED lança na OS, notifica e grava o evento com TTL de 30 dias', async () => {
    seed();
    const ev = event('PAYMENT_RECEIVED', {}, 'evt_05b7&368604920');

    await handleAsaasEvent('c1', ev);

    expect(fakeDb.data(ORDER_PATH)!.payment).toBe('paid');
    expect(mockNotify).toHaveBeenCalledWith('c1', 'o1', 1000);
    const stored = fakeDb.data(`${EVENTS_PREFIX}evt_05b7&368604920`)!;
    const processedAt = Date.parse(stored.processedAt as string);
    const expiresAt = (stored.expiresAt as { toDate(): Date }).toDate().getTime();
    expect(Math.round((expiresAt - processedAt) / 86_400_000)).toBe(30);
  });

  it('evento repetido (mesmo id) não reprocessa', async () => {
    seed();
    const ev = event('PAYMENT_RECEIVED');

    await handleAsaasEvent('c1', ev);
    // Simulate the app/manual flow removing the booking: a reprocessed event would re-add it.
    fakeDb.seed(CHARGE_PATH, { ...fakeDb.data(CHARGE_PATH)!, paidAsaasPaymentIds: [] });
    await handleAsaasEvent('c1', ev);

    expect(mockNotify).toHaveBeenCalledTimes(1);
    expect(fakeDb.data(ORDER_PATH)!.transactions).toHaveLength(1);
  });

  it('cartão: CONFIRMED e depois RECEIVED lançam uma vez só', async () => {
    seed();
    await handleAsaasEvent('c1', event('PAYMENT_CONFIRMED', { billingType: 'CREDIT_CARD', status: 'CONFIRMED' }));
    await handleAsaasEvent('c1', event('PAYMENT_RECEIVED', { billingType: 'CREDIT_CARD' }));

    expect(fakeDb.data(ORDER_PATH)!.transactions).toHaveLength(1);
    expect(mockNotify).toHaveBeenCalledTimes(1);
    expect(fakeDb.pathsUnder(EVENTS_PREFIX)).toHaveLength(2);
  });

  it('ignora externalReference de outra empresa, mas registra o evento', async () => {
    seed();
    fakeDb.seed('companies/c2/orders/o1/charges/ch1', { asaasPaymentId: 'pay_1', paidAsaasPaymentIds: [] });

    await handleAsaasEvent('c1', event('PAYMENT_RECEIVED', { externalReference: 'c2:o1:ch1' }));

    expect(fakeDb.data(ORDER_PATH)!.transactions).toEqual([]);
    expect(mockNotify).not.toHaveBeenCalled();
    expect(fakeDb.pathsUnder(EVENTS_PREFIX)).toHaveLength(1);
  });

  it('ignora pagamento que não pertence à cobrança referenciada', async () => {
    seed();
    await handleAsaasEvent('c1', event('PAYMENT_RECEIVED', { id: 'pay_other' }));
    expect(fakeDb.data(ORDER_PATH)!.transactions).toEqual([]);
  });

  it('PAYMENT_OVERDUE marca overdue só quando pendente', async () => {
    seed();
    await handleAsaasEvent('c1', event('PAYMENT_OVERDUE', { status: 'OVERDUE' }));
    expect(fakeDb.data(CHARGE_PATH)!.status).toBe('overdue');

    seed({ status: 'paid' });
    await handleAsaasEvent('c1', event('PAYMENT_OVERDUE', { status: 'OVERDUE' }));
    expect(fakeDb.data(CHARGE_PATH)!.status).toBe('paid');
  });

  it('PAYMENT_REFUNDED estorna na OS', async () => {
    seed();
    await handleAsaasEvent('c1', event('PAYMENT_RECEIVED'));
    await handleAsaasEvent('c1', event('PAYMENT_REFUNDED', { status: 'REFUNDED' }));

    expect(fakeDb.data(ORDER_PATH)!.paidAmount).toBe(0);
    expect(fakeDb.data(CHARGE_PATH)!.status).toBe('refunded');
  });

  it('PAYMENT_DELETED cancela só se não paga', async () => {
    seed({ status: 'overdue' });
    await handleAsaasEvent('c1', event('PAYMENT_DELETED'));
    expect(fakeDb.data(CHARGE_PATH)!.status).toBe('canceled');

    seed({ status: 'paid' });
    await handleAsaasEvent('c1', event('PAYMENT_DELETED'));
    expect(fakeDb.data(CHARGE_PATH)!.status).toBe('paid');
  });

  it('sem externalReference, encontra a cobrança parcelada pelo installment', async () => {
    seed({ mode: 'cardInstallments', installmentCount: 2, asaasInstallmentId: 'ins_1' });
    fakeDb.seed('companies/c2/orders/o9/charges/chX', { asaasInstallmentId: 'ins_1', paidAsaasPaymentIds: [] });

    await handleAsaasEvent('c1', event('PAYMENT_CONFIRMED', {
      id: 'pay_2', value: 500, billingType: 'CREDIT_CARD', externalReference: null,
      installment: 'ins_1', installmentNumber: 2,
    }));

    const tx = (fakeDb.data(ORDER_PATH)!.transactions as any[])[0];
    expect(tx).toEqual(expect.objectContaining({ id: 'asaas_pay_2', amount: 500, description: 'Asaas • Cartão 2/2' }));
    expect(fakeDb.data('companies/c2/orders/o9/charges/chX')!.paidAsaasPaymentIds).toEqual([]);
  });

  it('eventos não assinados só são registrados', async () => {
    seed();
    await handleAsaasEvent('c1', event('PAYMENT_CHECKOUT_VIEWED'));
    expect(fakeDb.data(CHARGE_PATH)!.status).toBe('pending');
    expect(fakeDb.pathsUnder(EVENTS_PREFIX)).toHaveLength(1);
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
cd firebase/functions && npx jest src/services/asaas/__tests__/webhook.service.test.ts
```

Esperado: FAIL com `Cannot find module '../webhook.service'`.

- [ ] **Step 3: Implementar `webhook.service.ts`**

`firebase/functions/src/services/asaas/webhook.service.ts`:

```ts
/**
 * Asaas webhook event handling (POST /webhooks/asaas/:companyId).
 *
 * - Idempotency: every handled event id is stored in
 *   companies/{cid}/private/asaas/events/{eventId} (TTL on expiresAt, 30 days).
 *   The id is only recorded after processing, so a failed event is retried by
 *   Asaas; every handler below is idempotent on its own.
 * - Events that can never succeed (unknown charge, other company, unhandled
 *   event name) are recorded and acknowledged, otherwise the SEQUENTIALLY
 *   queue of the company gets stuck and Asaas interrupts it.
 * - Never logs the payload: only ids and the event name.
 */
import { db, Timestamp } from '../firestore.service';
import { notifyAsaasPaymentReceived } from '../notification.service';
import { applyAsaasPayment, chargeRef, revertAsaasPayment } from './order-payment.service';
import type {
  AsaasPaymentEvent,
  AsaasWebhookEvent,
  AsaasWebhookEventName,
  ChargeStatus,
  OrderCharge,
} from '../../models/asaas.types';

const EVENT_TTL_MS = 30 * 24 * 60 * 60 * 1000;

const HANDLED_EVENTS: ReadonlySet<string> = new Set<AsaasWebhookEventName>([
  'PAYMENT_RECEIVED',
  'PAYMENT_CONFIRMED',
  'PAYMENT_OVERDUE',
  'PAYMENT_REFUNDED',
  'PAYMENT_DELETED',
]);

interface ChargeTarget {
  orderId: string;
  chargeId: string;
}

export function parseExternalReference(
  ref?: string | null,
): { companyId: string; orderId: string; chargeId: string } | null {
  if (!ref) return null;
  const parts = ref.split(':');
  if (parts.length !== 3 || parts.some((part) => !part)) return null;
  const [companyId, orderId, chargeId] = parts;
  return { companyId, orderId, chargeId };
}

function eventsCollection(companyId: string) {
  return db.collection('companies').doc(companyId).collection('private').doc('asaas').collection('events');
}

/** Firestore doc ids cannot contain '/'. Asaas ids look like 'evt_<hex>&<n>'. */
function eventDocId(eventId: string): string {
  return eventId.replace(/\//g, '_');
}

function chargeMatchesPayment(charge: OrderCharge, payment: AsaasPaymentEvent): boolean {
  return (
    charge.asaasPaymentId === payment.id ||
    (!!charge.asaasInstallmentId && charge.asaasInstallmentId === payment.installment)
  );
}

async function resolveCharge(companyId: string, payment: AsaasPaymentEvent): Promise<ChargeTarget | null> {
  const parsed = parseExternalReference(payment.externalReference);
  if (parsed) {
    if (parsed.companyId !== companyId) {
      console.warn('[AsaasWebhook] externalReference belongs to another company', { companyId });
      return null;
    }
    const snap = await chargeRef(companyId, parsed.orderId, parsed.chargeId).get();
    if (!snap.exists) return null;
    if (!chargeMatchesPayment(snap.data() as OrderCharge, payment)) {
      console.warn('[AsaasWebhook] payment does not belong to the referenced charge', {
        companyId,
        chargeId: parsed.chargeId,
      });
      return null;
    }
    return { orderId: parsed.orderId, chargeId: parsed.chargeId };
  }

  if (payment.installment) {
    const snap = await db
      .collectionGroup('charges')
      .where('asaasInstallmentId', '==', payment.installment)
      .limit(10)
      .get();
    const prefix = `companies/${companyId}/orders/`;
    const doc = snap.docs.find((candidate) => candidate.ref.path.startsWith(prefix));
    const orderDoc = doc?.ref.parent.parent;
    if (doc && orderDoc) return { orderId: orderDoc.id, chargeId: doc.id };
  }

  return null;
}

async function updateChargeStatus(
  companyId: string,
  target: ChargeTarget,
  from: ChargeStatus[],
  to: ChargeStatus,
): Promise<boolean> {
  const ref = chargeRef(companyId, target.orderId, target.chargeId);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return false;
    const status = (snap.data() as OrderCharge).status;
    if (!from.includes(status)) return false;
    tx.update(ref, { status: to });
    return true;
  });
}

async function processPaymentEvent(
  companyId: string,
  name: AsaasWebhookEventName,
  payment: AsaasPaymentEvent,
  target: ChargeTarget,
): Promise<void> {
  switch (name) {
    case 'PAYMENT_RECEIVED':
    case 'PAYMENT_CONFIRMED': {
      const { applied } = await applyAsaasPayment(companyId, target.orderId, target.chargeId, payment);
      if (applied) await notifyAsaasPaymentReceived(companyId, target.orderId, Number(payment.value) || 0);
      return;
    }
    case 'PAYMENT_OVERDUE':
      await updateChargeStatus(companyId, target, ['pending'], 'overdue');
      return;
    case 'PAYMENT_REFUNDED':
      await revertAsaasPayment(companyId, target.orderId, target.chargeId, payment.id);
      return;
    case 'PAYMENT_DELETED':
      await updateChargeStatus(companyId, target, ['pending', 'overdue'], 'canceled');
      return;
  }
}

export async function handleAsaasEvent(companyId: string, event: AsaasWebhookEvent): Promise<void> {
  const eventRef = eventsCollection(companyId).doc(eventDocId(event.id));
  if ((await eventRef.get()).exists) {
    console.log('[AsaasWebhook] duplicate event skipped', { companyId, event: event.event });
    return;
  }

  const payment = event.payment;
  if (payment?.id && HANDLED_EVENTS.has(event.event)) {
    const target = await resolveCharge(companyId, payment);
    if (target) {
      await processPaymentEvent(companyId, event.event as AsaasWebhookEventName, payment, target);
    } else {
      console.warn('[AsaasWebhook] charge not found, event acknowledged', {
        companyId,
        event: event.event,
        paymentId: payment.id,
      });
    }
  }

  const now = new Date();
  await eventRef.set({
    processedAt: now.toISOString(),
    expiresAt: Timestamp.fromDate(new Date(now.getTime() + EVENT_TTL_MS)),
  });
}
```

- [ ] **Step 4: Índice de collection group para o fallback por `installment`**

Em `firebase/firestore.indexes.json`, substituir o bloco `"fieldOverrides": [ ... ]` (linhas 481–493) por:

```json
  "fieldOverrides": [
    {
      "collectionGroup": "orders",
      "fieldPath": "createdAt",
      "ttl": false,
      "indexes": [
        { "order": "ASCENDING", "queryScope": "COLLECTION" },
        { "order": "DESCENDING", "queryScope": "COLLECTION" },
        { "arrayConfig": "CONTAINS", "queryScope": "COLLECTION" },
        { "order": "DESCENDING", "queryScope": "COLLECTION_GROUP" }
      ]
    },
    {
      "collectionGroup": "charges",
      "fieldPath": "asaasInstallmentId",
      "ttl": false,
      "indexes": [
        { "order": "ASCENDING", "queryScope": "COLLECTION" },
        { "order": "DESCENDING", "queryScope": "COLLECTION" },
        { "arrayConfig": "CONTAINS", "queryScope": "COLLECTION" },
        { "order": "ASCENDING", "queryScope": "COLLECTION_GROUP" }
      ]
    }
  ]
```

- [ ] **Step 5: Rodar os testes**

```bash
cd firebase/functions && npx jest src/services/asaas && npm run lint && npm run build
```

Esperado: PASS (testes de `order-payment` + 12 de `webhook.service`).

- [ ] **Step 6: Commit**

```bash
git add firebase/functions/src/services/asaas/webhook.service.ts \
  firebase/functions/src/services/asaas/__tests__/webhook.service.test.ts \
  firebase/firestore.indexes.json
git commit -m "feat(asaas): processa eventos de webhook com idempotência

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task C6: Rota `POST /webhooks/asaas/:companyId`

**Files:**
- Create: `firebase/functions/src/routes/webhooks/asaas.routes.ts`
- Modify: `firebase/functions/src/index.ts` — import depois de `import revenuecatWebhookRoutes ...` (linha 263) e `app.use` depois de `app.use('/webhooks/revenuecat', revenuecatWebhookRoutes);` (linha 427)
- Modify: `firebase/functions/src/utils/log-redaction.utils.ts:122` (`shouldLogPayload` também exclui `/webhooks`)
- Test: `firebase/functions/src/routes/webhooks/__tests__/asaas.routes.test.ts`, `firebase/functions/src/utils/log-redaction.utils.test.ts` (novo `it`)

**Interfaces:**
- Consumes: `hashToken(token: string): string`, `safeEqualHex(a: string, b: string): boolean` (`services/asaas/crypto.ts`), `handleAsaasEvent`, `companies/{cid}/private/asaas.webhookTokenHash`
- Produces: router default export montado em `/webhooks/asaas`, path `/:companyId`; `asaasWebhookLimiter` (300 req/min por `companyId`)

- [ ] **Step 1: Escrever os testes que falham**

`firebase/functions/src/routes/webhooks/__tests__/asaas.routes.test.ts`:

```ts
jest.mock('../../../services/firestore.service', () =>
  jest.requireActual('../../../services/asaas/__tests__/asaas-fake-db').firestoreServiceMock);
jest.mock('../../../services/asaas/webhook.service', () => ({ handleAsaasEvent: jest.fn() }));

import request from 'supertest';
import express from 'express';
import { fakeDb } from '../../../services/asaas/__tests__/asaas-fake-db';
import { hashToken } from '../../../services/asaas/crypto';
import { handleAsaasEvent } from '../../../services/asaas/webhook.service';
import router from '../asaas.routes';

const mockHandle = handleAsaasEvent as jest.Mock;
const TOKEN = 'whk_token_value_for_tests_only';
const BODY = {
  id: 'evt_1&1',
  event: 'PAYMENT_RECEIVED',
  payment: { id: 'pay_1', value: 10, billingType: 'PIX', status: 'RECEIVED', description: 'marker_body_must_not_be_logged' },
};

function buildApp() {
  const app = express();
  app.use(express.json());
  app.use('/webhooks/asaas', router);
  return app;
}

describe('POST /webhooks/asaas/:companyId', () => {
  let logSpies: jest.SpyInstance[];

  beforeEach(() => {
    fakeDb.reset();
    mockHandle.mockReset();
    mockHandle.mockResolvedValue(undefined);
    fakeDb.seed('companies/c1/private/asaas', { webhookTokenHash: hashToken(TOKEN), status: 'active' });
    logSpies = (['log', 'warn', 'error'] as const).map((level) =>
      jest.spyOn(console, level).mockImplementation(() => undefined));
  });

  afterEach(() => {
    const logged = logSpies.flatMap((spy) => spy.mock.calls).map((call) => JSON.stringify(call)).join('\n');
    expect(logged).not.toContain(TOKEN);
    expect(logged).not.toContain('marker_body_must_not_be_logged');
    logSpies.forEach((spy) => spy.mockRestore());
  });

  it('responde 200 e processa o evento com token correto', async () => {
    const res = await request(buildApp())
      .post('/webhooks/asaas/c1')
      .set('asaas-access-token', TOKEN)
      .send(BODY);

    expect(res.status).toBe(200);
    expect(mockHandle).toHaveBeenCalledWith('c1', BODY);
  });

  it('401 sem header', async () => {
    const res = await request(buildApp()).post('/webhooks/asaas/c1').send(BODY);
    expect(res.status).toBe(401);
    expect(mockHandle).not.toHaveBeenCalled();
  });

  it('401 com token errado', async () => {
    const res = await request(buildApp())
      .post('/webhooks/asaas/c1')
      .set('asaas-access-token', 'wrong')
      .send(BODY);
    expect(res.status).toBe(401);
    expect(mockHandle).not.toHaveBeenCalled();
  });

  it('401 para empresa sem conexão Asaas', async () => {
    const res = await request(buildApp())
      .post('/webhooks/asaas/c2')
      .set('asaas-access-token', TOKEN)
      .send(BODY);
    expect(res.status).toBe(401);
  });

  it('401 para companyId com caracteres inválidos (ex.: barra codificada)', async () => {
    const res = await request(buildApp())
      .post('/webhooks/asaas/c1%2Fprivate')
      .set('asaas-access-token', TOKEN)
      .send(BODY);
    expect(res.status).toBe(401);
    expect(mockHandle).not.toHaveBeenCalled();
  });

  it('400 para payload sem id/evento', async () => {
    const res = await request(buildApp())
      .post('/webhooks/asaas/c1')
      .set('asaas-access-token', TOKEN)
      .send({ payment: { id: 'pay_1' } });
    expect(res.status).toBe(400);
    expect(mockHandle).not.toHaveBeenCalled();
  });

  it('500 quando o processamento falha (Asaas reenvia)', async () => {
    mockHandle.mockRejectedValue(new Error('firestore unavailable'));
    const res = await request(buildApp())
      .post('/webhooks/asaas/c1')
      .set('asaas-access-token', TOKEN)
      .send(BODY);
    expect(res.status).toBe(500);
  });
});
```

Em `firebase/functions/src/utils/log-redaction.utils.test.ts`, dentro de `describe('shouldLogPayload', ...)`, depois do `it('disallows logging for share-link management routes...')`:

```ts
  it('disallows logging for webhook routes (payment payloads, customer data)', () => {
    expect(shouldLogPayload('/webhooks/asaas/comp1')).toBe(false);
    expect(shouldLogPayload('/WEBHOOKS/revenuecat')).toBe(false);
    expect(shouldLogPayload('/webhooks')).toBe(false);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
cd firebase/functions && npx jest src/routes/webhooks src/utils/log-redaction.utils.test.ts
```

Esperado: FAIL — `Cannot find module '../asaas.routes'` e o novo `it` de `shouldLogPayload` falha (`Expected: false, Received: true`).

- [ ] **Step 3: Implementar a rota**

`firebase/functions/src/routes/webhooks/asaas.routes.ts`:

```ts
/**
 * Asaas Webhook Routes
 * POST /webhooks/asaas/:companyId — one webhook per company, registered by
 * connectAsaas with a random authToken that is stored only as a SHA-256 hash.
 *
 * Responses: 401 bad/missing token, 400 malformed event, 200 handled (or
 * acknowledged), 500 internal failure so Asaas retries the event.
 * Never logs the request body or the token.
 */

import { Router, Request, Response } from 'express';
import type { Router as RouterType } from 'express';
import rateLimit from 'express-rate-limit';
import { db } from '../../services/firestore.service';
import { hashToken, safeEqualHex } from '../../services/asaas/crypto';
import { handleAsaasEvent } from '../../services/asaas/webhook.service';
import type { AsaasWebhookEvent } from '../../models/asaas.types';

const router: RouterType = Router();

// Firestore auto ids; also blocks '/' smuggled in via %2F (req.params is decoded).
const COMPANY_ID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;

export const asaasWebhookLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    error: { code: 'RATE_LIMIT_EXCEEDED', message: 'Too many requests, please try again later' },
  },
  keyGenerator: (req: Request) => `asaas-webhook:${req.params.companyId || 'unknown'}`,
});

function unauthorized(res: Response): Response {
  return res.status(401).json({
    success: false,
    error: { code: 'UNAUTHORIZED', message: 'Invalid webhook token' },
  });
}

router.post('/:companyId', asaasWebhookLimiter, async (req: Request, res: Response) => {
  const { companyId } = req.params;
  try {
    const token = req.header('asaas-access-token');
    if (!COMPANY_ID_PATTERN.test(companyId) || !token) {
      console.warn('[AsaasWebhook] missing token or invalid company id');
      return unauthorized(res);
    }

    const connection = await db.collection('companies').doc(companyId).collection('private').doc('asaas').get();
    const storedHash = connection.exists ? connection.data()?.webhookTokenHash : undefined;
    if (typeof storedHash !== 'string' || !safeEqualHex(hashToken(token), storedHash)) {
      console.warn('[AsaasWebhook] invalid token', { companyId });
      return unauthorized(res);
    }

    const event = req.body as AsaasWebhookEvent | undefined;
    if (!event || typeof event.id !== 'string' || !event.id || typeof event.event !== 'string') {
      console.warn('[AsaasWebhook] malformed event', { companyId });
      return res.status(400).json({
        success: false,
        error: { code: 'INVALID_PAYLOAD', message: 'Missing event id or name' },
      });
    }

    await handleAsaasEvent(companyId, event);
    return res.status(200).json({ success: true });
  } catch (error) {
    console.error('[AsaasWebhook] processing failed', {
      companyId,
      error: error instanceof Error ? error.message : 'unknown',
    });
    return res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Internal server error' },
    });
  }
});

export default router;
```

- [ ] **Step 4: Montar em `index.ts` e excluir webhooks do log de payload**

Em `firebase/functions/src/index.ts`, depois de `import revenuecatWebhookRoutes from './routes/webhooks/revenuecat.routes';`:

```ts
import asaasWebhookRoutes from './routes/webhooks/asaas.routes';
```

Depois de `app.use('/webhooks/revenuecat', revenuecatWebhookRoutes);` (antes das rotas `/v1`):

```ts
app.use('/webhooks/asaas', asaasWebhookRoutes);
```

Em `firebase/functions/src/utils/log-redaction.utils.ts`, linha 122, trocar:

```ts
  return !/^\/(mcp|public)(\/|$)|\/share(\/|$)/i.test(path);
```

por:

```ts
  return !/^\/(mcp|public|webhooks)(\/|$)|\/share(\/|$)/i.test(path);
```

e acrescentar ao JSDoc de `shouldLogPayload`, antes de `* Every other path keeps logging...`:

```ts
 * - `/webhooks/**`: payment events (Asaas, RevenueCat) carry customer and
 *   payment data; the Asaas webhook payload must never be logged.
```

- [ ] **Step 5: Rodar os testes**

```bash
cd firebase/functions && npx jest src/routes/webhooks src/utils/log-redaction.utils.test.ts && npm run lint && npm run build
```

Esperado: PASS (7 testes da rota + log-redaction).

- [ ] **Step 6: Commit**

```bash
git add firebase/functions/src/routes/webhooks/asaas.routes.ts \
  firebase/functions/src/routes/webhooks/__tests__/asaas.routes.test.ts \
  firebase/functions/src/index.ts \
  firebase/functions/src/utils/log-redaction.utils.ts \
  firebase/functions/src/utils/log-redaction.utils.test.ts
git commit -m "feat(asaas): endpoint de webhook autenticado por token por empresa

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task C7: Regras Firestore, TTL de eventos e passos de rollout

O repo não tem `@firebase/rules-unit-testing` (nenhum `package.json` o referencia), então a verificação das regras é manual no emulador, documentada abaixo e em `docs/ASAAS_INTEGRATION.md`.

**Files:**
- Modify: `firebase/firestore.rules` — helpers depois de `canViewFinancial` (linha 58); `match /charges/{chargeId}` dentro de `match /orders/{orderId}` depois do bloco `comments` (linha 367); `settings/payments` e `private/**` depois do bloco `notifications` (linha 471)
- Modify: `firebase/firestore.indexes.json` (`fieldOverrides`: TTL em `events.expiresAt`)
- Modify: `docs/ASAAS_INTEGRATION.md` (seção nova no fim)
- Test: verificação manual no emulador (Step 4)

**Interfaces:**
- Consumes: claims `roles[companyId]`, `companies/{cid}.owner.id`
- Produces: `private/**` negado; `settings/payments` leitura para membros; `orders/{oid}/charges/{cid}` leitura para owner/admin/manager; escrita só servidor

- [ ] **Step 1: Helpers de dono e leitura de cobrança**

Em `firebase/firestore.rules`, logo depois da função `canViewFinancial` (termina na linha 58):

```
    // Verifica se o usuário é o dono da empresa (role 'owner' nas claims ou owner.id no doc)
    function isCompanyOwner(companyId) {
      return request.auth != null && (
        hasRole(companyId, 'owner')
        || get(/databases/$(database)/documents/companies/$(companyId)).data.owner.id == request.auth.uid
      );
    }

    // Cobranças Asaas: dono, admin e gerente (mesmo público da permissão chargeOrder)
    function canViewCharges(companyId) {
      return canViewFinancial(companyId) || isCompanyOwner(companyId);
    }
```

- [ ] **Step 2: Regras de `charges`, `settings/payments` e `private/**`**

Dentro de `match /orders/{orderId}`, depois do bloco `match /comments/{commentId} { ... }` (fecha na linha 367):

```
        // Cobranças Asaas da OS — escrita só via Cloud Functions (Admin SDK)
        match /charges/{chargeId} {
          allow read: if canViewCharges(companyId);
          allow write: if false;
        }
```

Dentro de `match /companies/{companyId}`, depois do bloco `match /notifications/{notificationId} { ... }` (fecha na linha 471):

```
      // ──────────────────────────────────────────────────────────────────────
      // PAGAMENTOS (ASAAS)
      // settings/payments: membros leem (flag do piloto e conta conectada);
      // escrita só via Cloud Functions.
      // private/**: credencial criptografada, mapa de clientes e eventos do
      // webhook. Nunca acessível pelo cliente.
      // ──────────────────────────────────────────────────────────────────────
      match /settings/payments {
        allow read: if belongsToCompany(companyId);
        allow write: if false;
      }

      match /private/{document=**} {
        allow read, write: if false;
      }
```

- [ ] **Step 3: TTL declarado em `firestore.indexes.json`**

No array `fieldOverrides` (depois do objeto `charges.asaasInstallmentId` da Task C5), acrescentar:

```json
    {
      "collectionGroup": "events",
      "fieldPath": "expiresAt",
      "ttl": true,
      "indexes": []
    }
```

(`events` hoje só existe em `companies/{cid}/private/asaas/events`; o campo não precisa de índice.)

- [ ] **Step 4: Verificação manual das regras no emulador**

Terminal 1:

```bash
cd firebase && firebase emulators:start --only firestore --project demo-praticos
```

Esperado: `All emulators ready` sem erro de compilação de regras.

Terminal 2, **em `bash`** (rodar `bash` antes; o zsh interativo não aceita os comentários `#` do bloco). Os dados são semeados com `Bearer owner`, que ignora as regras no emulador:

```bash
BASE='http://127.0.0.1:8080/v1/projects/demo-praticos/databases/(default)/documents'
mkjwt() { node -e '
const b=o=>Buffer.from(JSON.stringify(o)).toString("base64url");
const [uid,role]=process.argv.slice(1); const now=Math.floor(Date.now()/1000);
console.log(b({alg:"none",typ:"JWT"})+"."+b({iss:"https://securetoken.google.com/demo-praticos",aud:"demo-praticos",
auth_time:now,iat:now,exp:now+3600,sub:uid,user_id:uid,roles:{c1:role},firebase:{sign_in_provider:"custom",identities:{}}})+".");
' "$1" "$2"; }
seed() { curl -s -o /dev/null -w "%{http_code} seed $1\n" -X PATCH "$BASE/$1" -H 'Authorization: Bearer owner' \
  -H 'Content-Type: application/json' -d "$2"; }
check() { curl -s -o /dev/null -w "%{http_code} GET $1 as $2\n" "$BASE/$1" \
  -H "Authorization: Bearer $(mkjwt "$2" "$3")"; }
write() { curl -s -o /dev/null -w "%{http_code} PATCH $1 as $2\n" -X PATCH "$BASE/$1" \
  -H "Authorization: Bearer $(mkjwt "$2" "$3")" -H 'Content-Type: application/json' -d "$4"; }

seed 'companies/c1' '{"fields":{"owner":{"mapValue":{"fields":{"id":{"stringValue":"owner1"}}}}}}'
seed 'companies/c1/private/asaas' '{"fields":{"webhookTokenHash":{"stringValue":"x"}}}'
seed 'companies/c1/settings/payments' '{"fields":{"asaasConnected":{"booleanValue":true}}}'
seed 'companies/c1/orders/o1/charges/ch1' '{"fields":{"status":{"stringValue":"pending"}}}'

check 'companies/c1/private/asaas' adm1 admin            # esperado 403
check 'companies/c1/settings/payments' tec1 technician   # esperado 200
write 'companies/c1/settings/payments' adm1 admin '{"fields":{"asaasConnected":{"booleanValue":false}}}'  # esperado 403
check 'companies/c1/orders/o1/charges/ch1' mgr1 manager  # esperado 200
check 'companies/c1/orders/o1/charges/ch1' adm1 admin    # esperado 200
check 'companies/c1/orders/o1/charges/ch1' owner1 supervisor  # esperado 200 (owner.id no doc)
check 'companies/c1/orders/o1/charges/ch1' tec1 technician    # esperado 403
write 'companies/c1/orders/o1/charges/ch1' adm1 admin '{"fields":{"status":{"stringValue":"paid"}}}'  # esperado 403
```

Todas as linhas devem bater com o comentário. Encerrar o emulador com Ctrl+C.

- [ ] **Step 5: Documentar webhook, regras e rollout**

Acrescentar no fim de `docs/ASAAS_INTEGRATION.md`:

````markdown
## Webhook e baixa na OS

- Endpoint: `POST /webhooks/asaas/{companyId}` (função `api`). Header `asaas-access-token` comparado (timing-safe) com `webhookTokenHash` de `companies/{cid}/private/asaas`; sem match → 401. Rate limit de 300 req/min por empresa. Erro interno → 500 (o Asaas reenvia). Eventos sem cobrança correspondente são registrados e respondidos com 200 para não travar a fila `SEQUENTIALLY`.
- Idempotência: `companies/{cid}/private/asaas/events/{eventId}` = `{ processedAt, expiresAt }` (TTL 30 dias).
- `PAYMENT_RECEIVED`/`PAYMENT_CONFIRMED`: transação `asaas_{paymentId}` (`type: payment`) na OS, `paidAmount`/`paid`/`payment` recalculados, push "Pagamento recebido" para dono/admin/gerente. `PAYMENT_OVERDUE`: cobrança `overdue` (se `pending`). `PAYMENT_REFUNDED`: remove a transação, cobrança `refunded`, comentário interno no histórico da OS. `PAYMENT_DELETED`: cobrança `canceled` (se não paga).
- Cobrança é a fonte da verdade (`paidAsaasPaymentIds` + `appliedTransactions`). O trigger `repairAsaasPayments` (orders onUpdate) reinsere transações Asaas apagadas por versões antigas do app, só para empresas com `asaasConnected`.
- Nunca logar o payload nem o token: `/webhooks/**` fica fora do log de payload até no emulador.

## Regras Firestore

- `companies/{cid}/private/**`: negado para o cliente.
- `companies/{cid}/settings/payments`: leitura para membros, escrita só servidor.
- `companies/{cid}/orders/{oid}/charges/{chargeId}`: leitura para dono/admin/gerente, escrita só servidor.
- Sem `@firebase/rules-unit-testing` no repo: verificação manual no emulador (`firebase emulators:start --only firestore --project demo-praticos` + chamadas REST com JWT sem assinatura). Roteiro no plano do Bloco C.

## Rollout do webhook (Bloco C)

1. Deploy de regras e índices antes do app que lê `charges`:
   `cd firebase && firebase deploy --only firestore:rules,firestore:indexes --project praticos`
2. Política de TTL dos eventos de webhook (também declarada em `firestore.indexes.json`; o comando garante e confere):
   ```bash
   gcloud firestore fields ttls update expiresAt \
     --collection-group=events --enable-ttl --project=praticos
   gcloud firestore fields ttls list --project=praticos
   ```
   A política leva alguns minutos para ficar `ACTIVE`; a exclusão acontece em até ~24 h depois de `expiresAt`.
3. Deploy das functions (`api` e o trigger novo `repairAsaasPayments`):
   `cd firebase && firebase deploy --only functions:api,functions:repairAsaasPayments --project praticos`
   É o primeiro trigger Firestore v2 do projeto: o CLI pode pedir para habilitar Eventarc/Pub/Sub; aceitar.
````

- [ ] **Step 6: Validar regras e índices**

```bash
cd firebase && firebase emulators:exec --only firestore --project demo-praticos "echo rules-ok"
node -e "JSON.parse(require('fs').readFileSync('firestore.indexes.json','utf8')); console.log('indexes-ok')"
```

Esperado: `rules-ok` (regras compilam) e `indexes-ok`.

- [ ] **Step 7: Commit**

```bash
git add firebase/firestore.rules firebase/firestore.indexes.json docs/ASAAS_INTEGRATION.md
git commit -m "feat(rules): protege dados de pagamento Asaas e TTL de eventos do webhook

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task C8: Open PR

- [ ] **Step 1: Verificação final**

```bash
cd firebase/functions && npm run lint && npm test && npm run build
cd ../ && firebase emulators:exec --only firestore --project demo-praticos "echo rules-ok"
```

Esperado: lint limpo, todos os testes PASS, build sem erros, `rules-ok`.

- [ ] **Step 2: Push e PR**

```bash
git push -u origin feat/asaas-webhook
gh pr create --base master --head feat/asaas-webhook --label risk:high \
  --title "feat(asaas): webhook de pagamentos, baixa na OS, reparo e regras" \
  --body "$(cat <<'EOF'
## Resumo

Bloco C da cobrança da OS via Asaas (Refs #303).

- `POST /webhooks/asaas/:companyId`: autentica o header `asaas-access-token` contra o hash salvo em `private/asaas` (comparação timing-safe), rate limit de 300/min por empresa, 500 em erro interno para o Asaas reenviar. Nunca loga o payload nem o token (`/webhooks/**` saiu do log de payload).
- `handleAsaasEvent`: idempotência por `private/asaas/events/{eventId}` (TTL 30 dias); localiza a cobrança pelo `externalReference` (ou `installment`) e recusa referência de outra empresa.
- Pagamento recebido/confirmado vira transação `asaas_{id}` na OS dentro de transação Firestore; recalcula `paidAmount`/`paid`/`payment`; cobrança fica `paid` quando todas as parcelas entram; push "Pagamento recebido" para dono/admin/gerente.
- Estorno remove a transação, marca `refunded` e registra comentário interno no histórico da OS. Vencida → `overdue`; excluída → `canceled` (se não paga).
- Trigger `repairAsaasPayments`: reinsere transações Asaas apagadas por versões antigas do app (só empresas com `asaasConnected`, só escreve quando falta algo).
- Regras: `private/**` negado; `settings/payments` leitura para membros; `charges` leitura para dono/admin/gerente; escrita só servidor.

## Notas de contrato

- `OrderCharge.appliedTransactions` (server-only) guarda a cópia das transações lançadas, usada pelo reparo.
- `CommentSource` ganhou `asaas`.
- Eventos sem cobrança correspondente são confirmados com 200 para não travar a fila `SEQUENTIALLY`.

## Como testar

```bash
cd firebase/functions && npm run lint && npm test && npm run build
cd firebase && firebase emulators:exec --only firestore --project demo-praticos "echo rules-ok"
```

Regras: roteiro manual no emulador em `docs/ASAAS_INTEGRATION.md` (seção "Regras Firestore").

## Rollout

1. `firebase deploy --only firestore:rules,firestore:indexes`
2. `gcloud firestore fields ttls update expiresAt --collection-group=events --enable-ttl --project=praticos`
3. `firebase deploy --only functions:api,functions:repairAsaasPayments` (primeiro trigger Firestore v2: aceitar habilitar Eventarc)

Refs #303

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```
## Bloco D — App: Integrações > Asaas, Cobrar e card de cobrança

> Contract note 1 (dependência): este bloco parte da `master` **depois do merge do Bloco A** e consome dele, sem redefinir: `appApiHeaders()` (`lib/services/api_headers.dart`), `PermissionType.chargeOrder`, `Customer.taxId` / `CustomerAggr.taxId` e `lib/utils/tax_id.dart` (`onlyDigits`, `isValidTaxId`, `formatTaxId`). Os Blocos B e C só são necessários em tempo de execução (rotas e regras); o código e os testes deste bloco compilam e passam sem eles.
>
> Contract note 2 (`AsaasApiService.withClient`): o seam de teste recebe `headersProvider: Future<Map<String, String>> Function()` em vez do `tokenProvider` do `IntegrationApiService`, porque os headers (Bearer + `X-Company-Id`) vêm prontos de `appApiHeaders()`. A instância padrão usa `() => appApiHeaders()`. Sem `Authorization` nos headers → `AsaasApiException('UNAUTHENTICATED', ...)` sem chamar a rede.
>
> Contract note 3 (respostas do Bloco B): o app espera o envelope já usado em `/v1/app/integrations` — sucesso `{ success: true, data }`, erro `{ success: false, error: { code, message } }`. `connect` → `data` = `PaymentSettingsDoc`; `createCharge` e `cancelCharge` → `data` = documento `OrderCharge` (com `id`); o parser também aceita `chargeId` no lugar de `id` (formato `{ chargeId, invoiceUrl, status }` citado na spec). Códigos de erro que a UI traduz (qualquer outro vira mensagem genérica, nunca o `message` cru): `FORBIDDEN`, `ASAAS_INVALID_API_KEY`, `ASAAS_NOT_CONNECTED`, `ASAAS_NOT_ENABLED`, `INVALID_VALUE`, `TAX_ID_REQUIRED`, `INVALID_TAX_ID`, `CUSTOMER_REQUIRED`. Códigos alinhados com o `AsaasErrorCode` do Bloco B (`INVALID_VALUE` cobre valor acima do saldo e valor zero).
>
> Contract note 4 (modelo Dart): em `OrderCharge` todos os campos são anuláveis e `mode`/`status` usam `JsonKey.nullForUndefinedEnumValue` (o servidor é a fonte da verdade; um valor novo não pode quebrar o app). `dueDate` fica `String` (`YYYY-MM-DD`, igual ao servidor) com o getter `dueDateValue`. `PaymentSettings.asaasEnvironment` é `String?` (`'sandbox' | 'production'`).
>
> Contract note 5 (onde fica "Cobrar"): o botão e o card ficam em `lib/screens/payment_management_screen.dart` (tela aberta pela linha "Pagamento" do resumo da OS), não em `order_form.dart`: é a área de pagamentos existente e já recebe o `OrderStore`. "Dono/admin" no app = `PermissionType.manageUsers` (o `RolesType` do Flutter não tem `owner`; é o mesmo guard que já abre Integrações em `settings.dart:248`).

**Branch:** `feat/asaas-app` (a partir da `master` com o Bloco A mergeado).
**PR:** `feat(payments): cobrança Asaas no app`.
**Verificação do PR:**

```bash
fvm flutter pub run build_runner build --delete-conflicting-outputs
fvm flutter gen-l10n
fvm flutter analyze
fvm flutter test
```

Esperado: `No issues found!` e todos os testes passando. Verificação manual (com Blocos B e C no ambiente): simulador iOS em debug (usa o ngrok de `IntegrationApiService._baseUrl`), empresa com `asaasEnabled=true`, conectar a chave do sandbox, gerar cobrança numa OS aprovada, copiar o link da fatura, cancelar.

---

### Task D1: Modelos `OrderCharge` e `PaymentSettings`

**Files:**
- Create: `lib/models/order_charge.dart`, `lib/models/order_charge.g.dart` (gerado)
- Create: `lib/models/payment_settings.dart`, `lib/models/payment_settings.g.dart` (gerado)
- Modify: `lib/models/payment_transaction.dart:50-51` (getter `isAsaas` logo depois de `hasReceipt`)
- Test: `test/models/order_charge_test.dart`, `test/models/payment_settings_test.dart`

**Interfaces:**
- Consumes: `UserAggr` (`lib/models/user.dart`).
- Produces: `enum ChargeStatus { pending, paid, overdue, canceled, refunded }`, `enum ChargeMode { single, cardInstallments }`, `class OrderCharge` (`fromJson`, `toJson`, `isOpen`, `dueDateValue`, `static OrderCharge? current(List<OrderCharge>)`), `class PaymentSettings` (`asaasEnabled`, `asaasConnected`, `asaasAccountName`, `asaasEnvironment`, `isSandbox`), `PaymentTransaction.isAsaas`.

- [ ] **Step 1: Criar a branch**

```bash
git checkout master
git pull origin master
git checkout -b feat/asaas-app
test -f lib/services/api_headers.dart && test -f lib/utils/tax_id.dart && echo "Bloco A presente"
```

Esperado: `Bloco A presente`. Se não aparecer, pare: o Bloco A ainda não foi mergeado.

- [ ] **Step 2: Escrever os testes que falham**

`test/models/order_charge_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/models/payment_transaction.dart';

void main() {
  group('OrderCharge.fromJson', () {
    test('lê cobrança parcelada gravada pelo servidor', () {
      final charge = OrderCharge.fromJson({
        'id': 'ch1',
        'asaasPaymentId': 'pay_1',
        'asaasInstallmentId': 'ins_1',
        'mode': 'cardInstallments',
        'installmentCount': 3,
        'value': 700,
        'dueDate': '2026-10-07',
        'status': 'pending',
        'invoiceUrl': 'https://sandbox.asaas.com/i/abc',
        'paidAsaasPaymentIds': ['pay_1'],
        'createdBy': {'id': 'u1', 'name': 'Rafael'},
        'createdAt': '2026-10-04T12:00:00.000Z',
      });

      expect(charge.id, 'ch1');
      expect(charge.mode, ChargeMode.cardInstallments);
      expect(charge.installmentCount, 3);
      expect(charge.value, 700.0);
      expect(charge.status, ChargeStatus.pending);
      expect(charge.paidAsaasPaymentIds, ['pay_1']);
      expect(charge.createdBy?.name, 'Rafael');
      expect(charge.createdAt, DateTime.utc(2026, 10, 4, 12));
      expect(charge.dueDateValue, DateTime(2026, 10, 7));
      expect(charge.isOpen, isTrue);
    });

    test('status e modo desconhecidos viram null sem lançar', () {
      final charge = OrderCharge.fromJson({
        'id': 'ch1',
        'status': 'awaiting_risk_analysis',
        'mode': 'pix',
      });

      expect(charge.status, isNull);
      expect(charge.mode, isNull);
      expect(charge.isOpen, isFalse);
    });

    test('vencida conta como em aberto', () {
      expect(OrderCharge(status: ChargeStatus.overdue).isOpen, isTrue);
      expect(OrderCharge(status: ChargeStatus.paid).isOpen, isFalse);
    });
  });

  group('OrderCharge.current', () {
    OrderCharge charge(String id, ChargeStatus status) =>
        OrderCharge(id: id, status: status);

    test('prefere a cobrança em aberto', () {
      final current = OrderCharge.current([
        charge('a', ChargeStatus.paid),
        charge('b', ChargeStatus.overdue),
      ]);

      expect(current?.id, 'b');
    });

    test('sem cobrança em aberto devolve a mais recente', () {
      final current = OrderCharge.current([
        charge('a', ChargeStatus.canceled),
        charge('b', ChargeStatus.paid),
      ]);

      expect(current?.id, 'a');
    });

    test('lista vazia devolve null', () {
      expect(OrderCharge.current(const []), isNull);
    });
  });

  group('PaymentTransaction.isAsaas', () {
    test('id com prefixo asaas_ é transação do Asaas', () {
      final txn = PaymentTransaction(
        id: 'asaas_pay_1',
        type: PaymentTransactionType.payment,
        amount: 10,
      );

      expect(txn.isAsaas, isTrue);
    });

    test('pagamento manual não é do Asaas', () {
      final manual = PaymentTransaction(
        id: '1728000000000',
        type: PaymentTransactionType.payment,
        amount: 10,
      );
      final withoutId = PaymentTransaction(
        type: PaymentTransactionType.discount,
        amount: 10,
      );

      expect(manual.isAsaas, isFalse);
      expect(withoutId.isAsaas, isFalse);
    });

    test('isAsaas não vai para o JSON', () {
      final txn = PaymentTransaction(
        id: 'asaas_pay_1',
        type: PaymentTransactionType.payment,
        amount: 10,
      );

      expect(txn.toJson().containsKey('isAsaas'), isFalse);
    });
  });
}
```

`test/models/payment_settings_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/payment_settings.dart';

void main() {
  group('PaymentSettings', () {
    test('documento vazio vira tudo desligado', () {
      final settings = PaymentSettings.fromJson({});

      expect(settings.asaasEnabled, isFalse);
      expect(settings.asaasConnected, isFalse);
      expect(settings.asaasAccountName, isNull);
      expect(settings.isSandbox, isFalse);
    });

    test('lê conta conectada no sandbox', () {
      final settings = PaymentSettings.fromJson({
        'asaasEnabled': true,
        'asaasConnected': true,
        'asaasAccountName': 'Rafsoft',
        'asaasEnvironment': 'sandbox',
      });

      expect(settings.asaasEnabled, isTrue);
      expect(settings.asaasConnected, isTrue);
      expect(settings.asaasAccountName, 'Rafsoft');
      expect(settings.isSandbox, isTrue);
    });

    test('produção não é sandbox', () {
      final settings = PaymentSettings(
        asaasEnabled: true,
        asaasConnected: true,
        asaasEnvironment: 'production',
      );

      expect(settings.isSandbox, isFalse);
    });
  });
}
```

- [ ] **Step 3: Rodar e ver falhar**

```bash
fvm flutter test test/models/order_charge_test.dart test/models/payment_settings_test.dart
```

Esperado: FAIL de compilação — `Error when reading 'lib/models/order_charge.dart': No such file or directory` (e o mesmo para `payment_settings.dart`).

- [ ] **Step 4: Implementar**

`lib/models/order_charge.dart`:

```dart
import 'package:json_annotation/json_annotation.dart';
import 'package:praticos/models/user.dart';

part 'order_charge.g.dart';

/// Lifecycle of an Asaas charge, mirrored from the server.
enum ChargeStatus { pending, paid, overdue, canceled, refunded }

/// How the customer pays the charge.
///
/// `single`: the customer picks Pix, boleto or card on the Asaas invoice.
/// `cardInstallments`: credit card split in 2–12 installments.
enum ChargeMode { single, cardInstallments }

/// Asaas charge of an order.
///
/// Path: `/companies/{companyId}/orders/{orderId}/charges/{chargeId}`.
/// Written only by Cloud Functions; the app only reads it.
@JsonSerializable(explicitToJson: true)
class OrderCharge {
  String? id;
  String? asaasPaymentId;
  String? asaasInstallmentId;

  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  ChargeMode? mode;

  int? installmentCount;
  double? value;

  /// Due date in the server format `YYYY-MM-DD`.
  String? dueDate;

  @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)
  ChargeStatus? status;

  String? invoiceUrl;
  List<String>? paidAsaasPaymentIds;
  UserAggr? createdBy;
  DateTime? createdAt;
  DateTime? paidAt;

  OrderCharge({
    this.id,
    this.asaasPaymentId,
    this.asaasInstallmentId,
    this.mode,
    this.installmentCount,
    this.value,
    this.dueDate,
    this.status,
    this.invoiceUrl,
    this.paidAsaasPaymentIds,
    this.createdBy,
    this.createdAt,
    this.paidAt,
  });

  factory OrderCharge.fromJson(Map<String, dynamic> json) =>
      _$OrderChargeFromJson(json);

  Map<String, dynamic> toJson() => _$OrderChargeToJson(this);

  /// Pending or overdue: the customer can still pay it.
  bool get isOpen =>
      status == ChargeStatus.pending || status == ChargeStatus.overdue;

  /// [dueDate] parsed as a local date (no time).
  DateTime? get dueDateValue =>
      dueDate == null ? null : DateTime.tryParse(dueDate!);

  /// The charge the order screen shows: the open one, else the most recent.
  ///
  /// [charges] must be sorted by `createdAt` descending, as
  /// `OrderChargeRepository.watch` returns them.
  static OrderCharge? current(List<OrderCharge> charges) {
    for (final charge in charges) {
      if (charge.isOpen) return charge;
    }
    return charges.isEmpty ? null : charges.first;
  }
}
```

`lib/models/payment_settings.dart`:

```dart
import 'package:json_annotation/json_annotation.dart';

part 'payment_settings.g.dart';

/// Payment integrations of a company.
///
/// Path: `/companies/{companyId}/settings/payments`. Readable by members,
/// written only by Cloud Functions (connect/disconnect) and the pilot script.
@JsonSerializable()
class PaymentSettings {
  /// Pilot flag, turned on per company by script.
  @JsonKey(defaultValue: false)
  bool asaasEnabled;

  /// An Asaas account is connected.
  @JsonKey(defaultValue: false)
  bool asaasConnected;

  String? asaasAccountName;

  /// 'sandbox' | 'production'
  String? asaasEnvironment;

  PaymentSettings({
    this.asaasEnabled = false,
    this.asaasConnected = false,
    this.asaasAccountName,
    this.asaasEnvironment,
  });

  factory PaymentSettings.fromJson(Map<String, dynamic> json) =>
      _$PaymentSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$PaymentSettingsToJson(this);

  bool get isSandbox => asaasEnvironment == 'sandbox';
}
```

Em `lib/models/payment_transaction.dart`, logo abaixo de `bool get hasReceipt => receiptDocumentId != null;` (linha 51), adicionar:

```dart

  /// Payment posted by the Asaas webhook (`id = 'asaas_' + payment.id`).
  /// It can only be undone by a refund in Asaas, never removed in the app.
  bool get isAsaas => id?.startsWith('asaas_') ?? false;
```

Gerar o código:

```bash
fvm flutter pub run build_runner build --delete-conflicting-outputs
```

Esperado: cria `lib/models/order_charge.g.dart` e `lib/models/payment_settings.g.dart`; `payment_transaction.g.dart` não muda (getters não entram no JSON).

- [ ] **Step 5: Rodar os testes**

```bash
fvm flutter test test/models/order_charge_test.dart test/models/payment_settings_test.dart
fvm flutter analyze lib/models
```

Esperado: todos PASS; `No issues found!`.

- [ ] **Step 6: Commit**

```bash
git add lib/models/order_charge.dart lib/models/order_charge.g.dart \
  lib/models/payment_settings.dart lib/models/payment_settings.g.dart \
  lib/models/payment_transaction.dart \
  test/models/order_charge_test.dart test/models/payment_settings_test.dart
git commit -m "$(cat <<'EOF'
feat(payments): add OrderCharge and PaymentSettings models

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task D2: Repositórios `PaymentSettingsRepository` e `OrderChargeRepository`

**Files:**
- Create: `lib/repositories/tenant/payment_settings_repository.dart`
- Create: `lib/repositories/tenant/order_charge_repository.dart`
- Test: `test/repositories/tenant/asaas_repositories_test.dart`

**Interfaces:**
- Consumes: `PaymentSettings`, `OrderCharge` (Task D1).
- Produces: `PaymentSettingsRepository({FirebaseFirestore? firestore})` com `Stream<PaymentSettings> watch(String companyId)` e `static PaymentSettings fromData(Map<String, dynamic>? data)`; `OrderChargeRepository({FirebaseFirestore? firestore})` com `Stream<List<OrderCharge>> watch(String companyId, String orderId)` (ordenado por `createdAt` desc) e `static OrderCharge fromDoc(String id, Map<String, dynamic> data)`.

Os dois documentos são escritos só pelo servidor, então os repositórios são só leitura e não estendem `TenantRepository` (que exige `BaseAuditCompany` e expõe escrita). O `FirebaseFirestore` é resolvido de forma preguiçosa para os testes poderem usar os mapeadores estáticos sem Firebase.

- [ ] **Step 1: Escrever o teste que falha**

`test/repositories/tenant/asaas_repositories_test.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/repositories/tenant/order_charge_repository.dart';
import 'package:praticos/repositories/tenant/payment_settings_repository.dart';

void main() {
  group('PaymentSettingsRepository.fromData', () {
    test('documento ausente vira settings desligado', () {
      final settings = PaymentSettingsRepository.fromData(null);

      expect(settings.asaasEnabled, isFalse);
      expect(settings.asaasConnected, isFalse);
    });

    test('lê os campos do documento', () {
      final settings = PaymentSettingsRepository.fromData({
        'asaasEnabled': true,
        'asaasConnected': true,
        'asaasAccountName': 'Rafsoft',
        'asaasEnvironment': 'production',
      });

      expect(settings.asaasEnabled, isTrue);
      expect(settings.asaasConnected, isTrue);
      expect(settings.asaasAccountName, 'Rafsoft');
      expect(settings.isSandbox, isFalse);
    });
  });

  group('OrderChargeRepository.fromDoc', () {
    test('usa o id do documento', () {
      final charge = OrderChargeRepository.fromDoc('ch1', {
        'status': 'paid',
        'value': 300,
        'createdAt': '2026-10-04T12:00:00.000Z',
      });

      expect(charge.id, 'ch1');
      expect(charge.status, ChargeStatus.paid);
      expect(charge.value, 300.0);
    });

    test('converte Timestamp em data', () {
      final charge = OrderChargeRepository.fromDoc('ch1', {
        'status': 'pending',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 4, 12)),
      });

      expect(charge.createdAt!.toUtc(), DateTime.utc(2026, 10, 4, 12));
    });
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
fvm flutter test test/repositories/tenant/asaas_repositories_test.dart
```

Esperado: FAIL de compilação — `Error when reading 'lib/repositories/tenant/order_charge_repository.dart': No such file or directory`.

- [ ] **Step 3: Implementar**

`lib/repositories/tenant/payment_settings_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/payment_settings.dart';

/// Read-only access to `/companies/{companyId}/settings/payments`.
///
/// The document is written only by Cloud Functions; a missing document
/// means the integration is off.
class PaymentSettingsRepository {
  PaymentSettingsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  static PaymentSettings fromData(Map<String, dynamic>? data) {
    if (data == null) return PaymentSettings();
    return PaymentSettings.fromJson(data);
  }

  Stream<PaymentSettings> watch(String companyId) {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('settings')
        .doc('payments')
        .snapshots()
        .map((snap) => fromData(snap.data()));
  }
}
```

`lib/repositories/tenant/order_charge_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:praticos/models/order_charge.dart';

/// Read-only access to `/companies/{companyId}/orders/{orderId}/charges`.
///
/// Charges are written only by Cloud Functions. Firestore rules allow
/// reading only to owner/admin/manager, so only listen when the user has
/// `PermissionType.chargeOrder`.
class OrderChargeRepository {
  OrderChargeRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  static OrderCharge fromDoc(String id, Map<String, dynamic> data) {
    final json = <String, dynamic>{};
    data.forEach((key, value) {
      json[key] = value is Timestamp
          ? value.toDate().toUtc().toIso8601String()
          : value;
    });
    json['id'] = id;
    return OrderCharge.fromJson(json);
  }

  /// Charges of an order, newest first.
  Stream<List<OrderCharge>> watch(String companyId, String orderId) {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('orders')
        .doc(orderId)
        .collection('charges')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => fromDoc(doc.id, doc.data())).toList());
  }
}
```

- [ ] **Step 4: Rodar os testes**

```bash
fvm flutter test test/repositories/tenant/asaas_repositories_test.dart
fvm flutter analyze lib/repositories/tenant
```

Esperado: 4 testes PASS; `No issues found!`.

- [ ] **Step 5: Commit**

```bash
git add lib/repositories/tenant/payment_settings_repository.dart \
  lib/repositories/tenant/order_charge_repository.dart \
  test/repositories/tenant/asaas_repositories_test.dart
git commit -m "$(cat <<'EOF'
feat(payments): add read-only repositories for payment settings and charges

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task D3: `AsaasApiService`

**Files:**
- Create: `lib/services/asaas_api_service.dart`
- Test: `test/services/asaas_api_service_test.dart`

**Interfaces:**
- Consumes: `appApiHeaders()` (Bloco A), `PaymentSettings`, `OrderCharge`, `ChargeMode` (Task D1). Rotas do Bloco B: `POST|DELETE /v1/app/payments/asaas/connect`, `POST /v1/app/orders/:orderId/charges`, `DELETE /v1/app/orders/:orderId/charges/:chargeId`.
- Produces: `class AsaasApiException implements Exception { final String? code; final String message; AsaasApiException(this.code, this.message); }`; `class AsaasApiService` com `static final instance`, `static AsaasApiService withClient(http.Client, {required Future<Map<String, String>> Function() headersProvider})`, `Future<PaymentSettings> connect(String apiKey)`, `Future<void> disconnect()`, `Future<OrderCharge> createCharge(String orderId, {required double value, required ChargeMode mode, int? installmentCount, DateTime? dueDate, String? customerTaxId})`, `Future<OrderCharge> cancelCharge(String orderId, String chargeId)`, `static Map<String, dynamic> buildChargeBody(...)`, `static PaymentSettings parseSettings(String body)`, `static OrderCharge parseCharge(String body)`.

- [ ] **Step 1: Escrever o teste que falha**

`test/services/asaas_api_service_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/services/asaas_api_service.dart';

const _headers = {
  'Authorization': 'Bearer fake-id-token',
  'X-Company-Id': 'company1',
};

AsaasApiService _service(MockClientHandler handler) =>
    AsaasApiService.withClient(
      MockClient(handler),
      headersProvider: () async => Map.of(_headers),
    );

Map<String, dynamic> _chargeJson({String status = 'pending'}) => {
      'id': 'ch1',
      'asaasPaymentId': 'pay_1',
      'mode': 'single',
      'value': 300,
      'dueDate': '2026-10-07',
      'status': status,
      'invoiceUrl': 'https://sandbox.asaas.com/i/abc',
      'paidAsaasPaymentIds': <String>[],
      'createdAt': '2026-10-04T12:00:00.000Z',
    };

http.Response _ok(Object data, [int status = 200]) =>
    http.Response(jsonEncode({'success': true, 'data': data}), status);

http.Response _error(String code, int status) => http.Response(
      jsonEncode({
        'success': false,
        'error': {'code': code, 'message': 'raw backend text'},
      }),
      status,
    );

void main() {
  group('AsaasApiService', () {
    test('connect() faz POST com a chave e devolve PaymentSettings', () async {
      final service = _service((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, endsWith('/v1/app/payments/asaas/connect'));
        expect(request.headers['Authorization'], 'Bearer fake-id-token');
        expect(request.headers['X-Company-Id'], 'company1');
        expect(request.headers['Content-Type'], startsWith('application/json'));
        expect(jsonDecode(request.body), {'apiKey': '\$aact_hmlg_000'});
        return _ok({
          'asaasEnabled': true,
          'asaasConnected': true,
          'asaasAccountName': 'Rafsoft',
          'asaasEnvironment': 'sandbox',
        });
      });

      final settings = await service.connect('\$aact_hmlg_000');

      expect(settings.asaasConnected, isTrue);
      expect(settings.asaasAccountName, 'Rafsoft');
      expect(settings.isSandbox, isTrue);
    });

    test('connect() com chave inválida lança ASAAS_INVALID_API_KEY', () async {
      final service =
          _service((_) async => _error('ASAAS_INVALID_API_KEY', 400));

      expect(
        () => service.connect('\$aact_hmlg_bad'),
        throwsA(isA<AsaasApiException>()
            .having((e) => e.code, 'code', 'ASAAS_INVALID_API_KEY')),
      );
    });

    test('disconnect() faz DELETE', () async {
      var called = false;
      final service = _service((request) async {
        called = true;
        expect(request.method, 'DELETE');
        expect(request.url.path, endsWith('/v1/app/payments/asaas/connect'));
        return http.Response(jsonEncode({'success': true}), 200);
      });

      await service.disconnect();

      expect(called, isTrue);
    });

    test('createCharge() à vista envia valor, modo e vencimento', () async {
      final service = _service((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, endsWith('/v1/app/orders/o1/charges'));
        expect(jsonDecode(request.body), {
          'value': 300,
          'mode': 'single',
          'dueDate': '2026-10-07',
        });
        return _ok(_chargeJson(), 201);
      });

      final charge = await service.createCharge(
        'o1',
        value: 300,
        mode: ChargeMode.single,
        installmentCount: 5,
        dueDate: DateTime(2026, 10, 7),
      );

      expect(charge.id, 'ch1');
      expect(charge.status, ChargeStatus.pending);
      expect(charge.invoiceUrl, 'https://sandbox.asaas.com/i/abc');
    });

    test('createCharge() parcelado envia parcelas e CPF', () async {
      final service = _service((request) async {
        expect(jsonDecode(request.body), {
          'value': 700,
          'mode': 'cardInstallments',
          'installmentCount': 3,
          'dueDate': '2026-10-07',
          'customerTaxId': '52998224725',
        });
        return _ok(_chargeJson(), 201);
      });

      await service.createCharge(
        'o1',
        value: 700,
        mode: ChargeMode.cardInstallments,
        installmentCount: 3,
        dueDate: DateTime(2026, 10, 7),
        customerTaxId: '52998224725',
      );
    });

    test('buildChargeBody arredonda para centavos', () {
      final body = AsaasApiService.buildChargeBody(
        value: 333.333,
        mode: ChargeMode.single,
      );

      expect(body, {'value': 333.33, 'mode': 'single'});
    });

    test('parseCharge aceita chargeId no lugar de id', () {
      final charge = AsaasApiService.parseCharge(jsonEncode({
        'success': true,
        'data': {
          'chargeId': 'ch9',
          'invoiceUrl': 'https://sandbox.asaas.com/i/xyz',
          'status': 'pending',
        },
      }));

      expect(charge.id, 'ch9');
      expect(charge.invoiceUrl, 'https://sandbox.asaas.com/i/xyz');
    });

    test('cancelCharge() faz DELETE na cobrança', () async {
      final service = _service((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, endsWith('/v1/app/orders/o1/charges/ch1'));
        return _ok(_chargeJson(status: 'canceled'));
      });

      final charge = await service.cancelCharge('o1', 'ch1');

      expect(charge.status, ChargeStatus.canceled);
    });

    test('sem Authorization lança UNAUTHENTICATED sem chamar a rede', () async {
      var calls = 0;
      final service = AsaasApiService.withClient(
        MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
        headersProvider: () async => {'X-Company-Id': 'company1'},
      );

      await expectLater(
        service.disconnect(),
        throwsA(isA<AsaasApiException>()
            .having((e) => e.code, 'code', 'UNAUTHENTICATED')),
      );
      expect(calls, 0);
    });

    test('headersProvider que lança vira UNAUTHENTICATED', () async {
      final service = AsaasApiService.withClient(
        MockClient((_) async => http.Response('{}', 200)),
        headersProvider: () async => throw StateError('no user'),
      );

      expect(
        () => service.disconnect(),
        throwsA(isA<AsaasApiException>()
            .having((e) => e.code, 'code', 'UNAUTHENTICATED')),
      );
    });

    test('falha de rede vira NETWORK_ERROR', () async {
      final service =
          _service((_) async => throw http.ClientException('offline'));

      expect(
        () => service.disconnect(),
        throwsA(isA<AsaasApiException>()
            .having((e) => e.code, 'code', 'NETWORK_ERROR')),
      );
    });

    test('corpo HTML com 502 lança code null', () async {
      final service = _service(
          (_) async => http.Response('<html>Bad Gateway</html>', 502));

      expect(
        () => service.disconnect(),
        throwsA(isA<AsaasApiException>()
            .having((e) => e.code, 'code', isNull)
            .having((e) => e.message, 'message', 'Request failed (502)')),
      );
    });
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
fvm flutter test test/services/asaas_api_service_test.dart
```

Esperado: FAIL de compilação — `Error when reading 'lib/services/asaas_api_service.dart': No such file or directory`.

- [ ] **Step 3: Implementar**

`lib/services/asaas_api_service.dart`:

```dart
import 'dart:convert';
import 'dart:io' show Platform, SocketException;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' show DateFormat;
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/models/payment_settings.dart';
import 'package:praticos/services/api_headers.dart';

/// Error from the Asaas endpoints of the PraticOS API.
///
/// [message] is raw diagnostic text and must never reach the UI; map
/// [code] with `asaasErrorText` instead.
class AsaasApiException implements Exception {
  final String? code;
  final String message;

  AsaasApiException(this.code, this.message);

  @override
  String toString() => message;
}

typedef ApiHeadersProvider = Future<Map<String, String>> Function();

/// Client for the Asaas endpoints: account connection and order charges.
///
/// The app never talks to Asaas directly and never keeps the API key.
class AsaasApiService {
  final http.Client _client;
  final ApiHeadersProvider _headersProvider;

  AsaasApiService._(this._client, this._headersProvider);

  static final AsaasApiService instance =
      AsaasApiService._(http.Client(), () => appApiHeaders());

  /// Test seam: lets a test inject a mock client and fake headers.
  static AsaasApiService withClient(
    http.Client client, {
    required ApiHeadersProvider headersProvider,
  }) =>
      AsaasApiService._(client, headersProvider);

  static String get _baseUrl {
    if (kDebugMode) {
      // Same targets as IntegrationApiService: emulator on Android,
      // ngrok tunnel on the iOS simulator (localhost:5000 is AirTunes).
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:5000/praticos/southamerica-east1/api';
      }
      return 'https://acidogenic-lorinda-unnymphean.ngrok-free.dev/praticos/southamerica-east1/api';
    }
    return 'https://southamerica-east1-praticos.cloudfunctions.net/api';
  }

  static Map<String, dynamic> _data(String body) {
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    return Map<String, dynamic>.from(decoded['data'] as Map);
  }

  static PaymentSettings parseSettings(String body) =>
      PaymentSettings.fromJson(_data(body));

  static OrderCharge parseCharge(String body) {
    final data = _data(body);
    if (data['id'] == null && data['chargeId'] != null) {
      data['id'] = data['chargeId'];
    }
    return OrderCharge.fromJson(data);
  }

  static Map<String, dynamic> buildChargeBody({
    required double value,
    required ChargeMode mode,
    int? installmentCount,
    DateTime? dueDate,
    String? customerTaxId,
  }) {
    return {
      'value': (value * 100).round() / 100,
      'mode': mode.name,
      if (mode == ChargeMode.cardInstallments && installmentCount != null)
        'installmentCount': installmentCount,
      if (dueDate != null) 'dueDate': DateFormat('yyyy-MM-dd').format(dueDate),
      if (customerTaxId != null && customerTaxId.isNotEmpty)
        'customerTaxId': customerTaxId,
    };
  }

  Future<Map<String, String>> _headers() async {
    final Map<String, String> headers;
    try {
      headers = await _headersProvider();
    } catch (_) {
      throw AsaasApiException('UNAUTHENTICATED', 'User not authenticated');
    }
    final authorization = headers['Authorization'];
    if (authorization == null || authorization.isEmpty) {
      throw AsaasApiException('UNAUTHENTICATED', 'User not authenticated');
    }
    return {...headers, 'Content-Type': 'application/json'};
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request();
    } on http.ClientException catch (e) {
      throw AsaasApiException('NETWORK_ERROR', e.message);
    } on SocketException catch (e) {
      throw AsaasApiException('NETWORK_ERROR', e.message);
    }
  }

  void _ensureOk(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    String message = 'Request failed (${response.statusCode})';
    String? code;
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>?;
      if (error?['message'] is String) message = error!['message'] as String;
      if (error?['code'] is String) code = error!['code'] as String;
    } catch (_) {
      // keep the default message and leave code as null
    }
    throw AsaasApiException(code, message);
  }

  /// Validates and stores the company's Asaas API key on the server.
  Future<PaymentSettings> connect(String apiKey) async {
    final headers = await _headers();
    final response = await _send(() => _client.post(
          Uri.parse('$_baseUrl/v1/app/payments/asaas/connect'),
          headers: headers,
          body: jsonEncode({'apiKey': apiKey}),
        ));
    _ensureOk(response);
    return parseSettings(response.body);
  }

  Future<void> disconnect() async {
    final headers = await _headers();
    final response = await _send(() => _client.delete(
          Uri.parse('$_baseUrl/v1/app/payments/asaas/connect'),
          headers: headers,
        ));
    _ensureOk(response);
  }

  /// Creates an Asaas charge for the order. The server cancels any open
  /// charge of the same order first.
  Future<OrderCharge> createCharge(
    String orderId, {
    required double value,
    required ChargeMode mode,
    int? installmentCount,
    DateTime? dueDate,
    String? customerTaxId,
  }) async {
    final headers = await _headers();
    final body = buildChargeBody(
      value: value,
      mode: mode,
      installmentCount: installmentCount,
      dueDate: dueDate,
      customerTaxId: customerTaxId,
    );
    final response = await _send(() => _client.post(
          Uri.parse('$_baseUrl/v1/app/orders/$orderId/charges'),
          headers: headers,
          body: jsonEncode(body),
        ));
    _ensureOk(response);
    return parseCharge(response.body);
  }

  Future<OrderCharge> cancelCharge(String orderId, String chargeId) async {
    final headers = await _headers();
    final response = await _send(() => _client.delete(
          Uri.parse('$_baseUrl/v1/app/orders/$orderId/charges/$chargeId'),
          headers: headers,
        ));
    _ensureOk(response);
    return parseCharge(response.body);
  }
}
```

- [ ] **Step 4: Rodar os testes**

```bash
fvm flutter test test/services/asaas_api_service_test.dart
fvm flutter analyze lib/services/asaas_api_service.dart
```

Esperado: 12 testes PASS; `No issues found!`.

- [ ] **Step 5: Commit**

```bash
git add lib/services/asaas_api_service.dart test/services/asaas_api_service_test.dart
git commit -m "$(cat <<'EOF'
feat(payments): add AsaasApiService for connection and order charges

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task D4: Strings (pt/en/es) e `asaasErrorText`

**Files:**
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb` (fim do arquivo, depois de `"viewPlans"`)
- Modify (gerados): `lib/l10n/app_localizations.dart`, `lib/l10n/app_localizations_pt.dart`, `lib/l10n/app_localizations_en.dart`, `lib/l10n/app_localizations_es.dart`
- Create: `lib/screens/payments/asaas_error_text.dart`
- Test: `test/screens/payments/asaas_error_text_test.dart`

**Interfaces:**
- Consumes: `AsaasApiException` (Task D3).
- Produces: `String asaasErrorText(AppLocalizations l10n, AsaasApiException e)` e todas as chaves l10n usadas nas Tasks D5–D9.

Todas as strings do bloco entram de uma vez porque as Tasks D5–D9 dependem delas; o teste desta task cobre o mapeamento de erros. "Asaas" é nome próprio e não é traduzido.

- [ ] **Step 1: Escrever o teste que falha**

`test/screens/payments/asaas_error_text_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/screens/payments/asaas_error_text.dart';
import 'package:praticos/services/asaas_api_service.dart';

void main() {
  final l10n = AppLocalizationsPt();

  String text(String? code) =>
      asaasErrorText(l10n, AsaasApiException(code, 'raw backend text'));

  group('asaasErrorText', () {
    test('FORBIDDEN', () {
      expect(text('FORBIDDEN'), l10n.asaasErrorForbidden);
    });

    test('ASAAS_INVALID_API_KEY', () {
      expect(text('ASAAS_INVALID_API_KEY'), l10n.asaasErrorInvalidKey);
    });

    test('ASAAS_NOT_CONNECTED e ASAAS_NOT_ENABLED', () {
      expect(text('ASAAS_NOT_CONNECTED'), l10n.asaasErrorNotConnected);
      expect(text('ASAAS_NOT_ENABLED'), l10n.asaasErrorNotConnected);
    });

    test('INVALID_VALUE', () {
      expect(text('INVALID_VALUE'), l10n.asaasErrorExceedsBalance);
    });

    test('TAX_ID_REQUIRED e INVALID_TAX_ID', () {
      expect(text('TAX_ID_REQUIRED'), l10n.asaasErrorTaxIdRequired);
      expect(text('INVALID_TAX_ID'), l10n.invalidTaxId);
    });

    test('CUSTOMER_REQUIRED', () {
      expect(text('CUSTOMER_REQUIRED'), l10n.asaasErrorCustomerRequired);
    });

    test('código desconhecido ou null vira genérico', () {
      expect(text('INTERNAL_ERROR'), l10n.asaasErrorGeneric);
      expect(text(null), l10n.asaasErrorGeneric);
    });

    test('nunca devolve a mensagem crua', () {
      expect(text('FORBIDDEN'), isNot(contains('raw backend text')));
      expect(text(null), isNot(contains('raw backend text')));
    });
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
fvm flutter test test/screens/payments/asaas_error_text_test.dart
```

Esperado: FAIL de compilação — `Error when reading 'lib/screens/payments/asaas_error_text.dart': No such file or directory`.

- [ ] **Step 3: Adicionar as strings**

Em `lib/l10n/app_pt.arb`, substituir as duas últimas linhas

```
  "viewPlans": "Ver planos"
}
```

por (se o Bloco A tiver acrescentado chaves depois de `viewPlans`, inserir o bloco abaixo depois da última chave existente, com vírgula, antes do `}` final; se o Bloco A já criou `invalidTaxId`, não repetir essa chave):

```json
  "viewPlans": "Ver planos",
  "asaasConnected": "Conectado",
  "asaasDisconnected": "Não conectado",
  "asaasConnectTitle": "Conectar conta Asaas",
  "asaasConnectIntro": "Receba por Pix, boleto ou cartão na conta Asaas da sua empresa. Quando o pagamento é confirmado, a OS dá baixa sozinha.",
  "asaasConnectStep1": "1. No painel do Asaas, abra Integrações > Chaves de API.",
  "asaasConnectStep2": "2. Gere uma nova chave e copie.",
  "asaasConnectStep3": "3. Cole a chave abaixo e toque em Conectar.",
  "asaasOpenPanel": "Abrir painel do Asaas",
  "asaasOpenSandboxPanel": "Abrir painel de teste (sandbox)",
  "asaasApiKey": "Chave de API",
  "asaasApiKeyPlaceholder": "Cole a chave aqui",
  "asaasApiKeyHint": "A chave fica guardada com criptografia no servidor e não aparece de novo no app.",
  "asaasConnect": "Conectar",
  "asaasAccount": "Conta",
  "asaasEnvironment": "Ambiente",
  "asaasEnvironmentSandbox": "Teste",
  "asaasEnvironmentProduction": "Produção",
  "asaasDisconnect": "Desconectar",
  "asaasDisconnectConfirm": "Desconectar a conta Asaas? As cobranças em aberto continuam no Asaas, mas os pagamentos deixam de dar baixa na OS.",
  "asaasErrorInvalidKey": "Chave de API inválida. Confira e tente de novo.",
  "asaasErrorForbidden": "Você não tem permissão para esta ação.",
  "asaasErrorNotConnected": "Conecte a conta Asaas em Configurações > Integrações.",
  "asaasErrorExceedsBalance": "O valor é maior que o saldo da OS.",
  "asaasErrorTaxIdRequired": "Informe o CPF ou CNPJ do cliente.",
  "asaasErrorCustomerRequired": "Adicione um cliente à OS antes de cobrar.",
  "asaasErrorGeneric": "Não foi possível concluir. Tente novamente.",
  "asaasTransactionCannotRemove": "Pagamentos recebidos pelo Asaas não podem ser removidos aqui. Para desfazer, estorne no Asaas.",
  "invalidTaxId": "CPF ou CNPJ inválido",
  "chargeWithAsaas": "Cobrar com Asaas",
  "chargeSectionTitle": "Cobrança",
  "createChargeTitle": "Nova cobrança",
  "chargeValue": "Valor",
  "chargeBalanceHint": "Saldo da OS: {value}",
  "@chargeBalanceHint": { "placeholders": { "value": { "type": "String" } } },
  "chargeModeSingle": "À vista",
  "chargeModeInstallments": "Parcelado no cartão",
  "chargeSingleHint": "O cliente escolhe Pix, boleto ou cartão.",
  "chargeInstallmentsHint": "O cliente paga no cartão de crédito, nas parcelas escolhidas.",
  "chargeInstallments": "Parcelas",
  "chargeInstallmentOption": "{count}x de {value}",
  "@chargeInstallmentOption": { "placeholders": { "count": { "type": "int" }, "value": { "type": "String" } } },
  "chargeDueDate": "Vencimento",
  "chargeTaxIdHint": "O Asaas exige CPF ou CNPJ. Ele fica salvo no cadastro do cliente.",
  "chargeGenerate": "Gerar cobrança",
  "chargeCreated": "Cobrança gerada",
  "chargeStatusPending": "Aguardando pagamento",
  "chargeStatusOverdue": "Vencida",
  "chargeStatusPaid": "Paga",
  "chargeStatusCanceled": "Cancelada",
  "chargeStatusRefunded": "Estornada",
  "chargeDueOn": "Vence em {date}",
  "@chargeDueOn": { "placeholders": { "date": { "type": "String" } } },
  "chargeInstallmentsSummary": "{count}x no cartão",
  "@chargeInstallmentsSummary": { "placeholders": { "count": { "type": "int" } } },
  "chargeShareOrderLink": "Compartilhar link da OS",
  "chargeCopyInvoiceLink": "Copiar link da fatura",
  "chargeInvoiceLinkCopied": "Link da fatura copiado",
  "chargeCancel": "Cancelar cobrança",
  "chargeCancelConfirm": "Cancelar esta cobrança no Asaas? O cliente não poderá mais pagar por ela.",
  "chargeKeep": "Manter",
  "chargeReplaceTitle": "Já existe uma cobrança em aberto",
  "chargeReplaceConfirm": "Gerar uma nova cobrança cancela a anterior no Asaas.",
  "chargeReplace": "Gerar nova",
  "chargeTotalChanged": "O saldo da OS ({balance}) está diferente do valor da cobrança ({value}).",
  "@chargeTotalChanged": { "placeholders": { "balance": { "type": "String" }, "value": { "type": "String" } } },
  "chargeRegenerate": "Gerar nova cobrança"
}
```

Em `lib/l10n/app_en.arb`, substituir

```
  "viewPlans": "View plans"
}
```

por:

```json
  "viewPlans": "View plans",
  "asaasConnected": "Connected",
  "asaasDisconnected": "Not connected",
  "asaasConnectTitle": "Connect Asaas account",
  "asaasConnectIntro": "Get paid by Pix, boleto or card in your company's Asaas account. When the payment is confirmed, the order is marked as paid automatically.",
  "asaasConnectStep1": "1. In the Asaas dashboard, open Integrations > API Keys.",
  "asaasConnectStep2": "2. Generate a new key and copy it.",
  "asaasConnectStep3": "3. Paste the key below and tap Connect.",
  "asaasOpenPanel": "Open Asaas dashboard",
  "asaasOpenSandboxPanel": "Open test dashboard (sandbox)",
  "asaasApiKey": "API key",
  "asaasApiKeyPlaceholder": "Paste the key here",
  "asaasApiKeyHint": "The key is stored encrypted on the server and is never shown in the app again.",
  "asaasConnect": "Connect",
  "asaasAccount": "Account",
  "asaasEnvironment": "Environment",
  "asaasEnvironmentSandbox": "Test",
  "asaasEnvironmentProduction": "Production",
  "asaasDisconnect": "Disconnect",
  "asaasDisconnectConfirm": "Disconnect the Asaas account? Open charges stay in Asaas, but payments will no longer update the order.",
  "asaasErrorInvalidKey": "Invalid API key. Check it and try again.",
  "asaasErrorForbidden": "You don't have permission for this action.",
  "asaasErrorNotConnected": "Connect the Asaas account in Settings > Integrations.",
  "asaasErrorExceedsBalance": "The amount is higher than the order balance.",
  "asaasErrorTaxIdRequired": "Enter the customer's CPF or CNPJ.",
  "asaasErrorCustomerRequired": "Add a customer to the order before charging.",
  "asaasErrorGeneric": "Could not complete. Please try again.",
  "asaasTransactionCannotRemove": "Payments received through Asaas can't be removed here. To undo, refund them in Asaas.",
  "invalidTaxId": "Invalid CPF or CNPJ",
  "chargeWithAsaas": "Charge with Asaas",
  "chargeSectionTitle": "Charge",
  "createChargeTitle": "New charge",
  "chargeValue": "Amount",
  "chargeBalanceHint": "Order balance: {value}",
  "@chargeBalanceHint": { "placeholders": { "value": { "type": "String" } } },
  "chargeModeSingle": "One-time",
  "chargeModeInstallments": "Card installments",
  "chargeSingleHint": "The customer chooses Pix, boleto or card.",
  "chargeInstallmentsHint": "The customer pays by credit card in the chosen installments.",
  "chargeInstallments": "Installments",
  "chargeInstallmentOption": "{count}x of {value}",
  "@chargeInstallmentOption": { "placeholders": { "count": { "type": "int" }, "value": { "type": "String" } } },
  "chargeDueDate": "Due date",
  "chargeTaxIdHint": "Asaas requires a CPF or CNPJ. It is saved to the customer record.",
  "chargeGenerate": "Create charge",
  "chargeCreated": "Charge created",
  "chargeStatusPending": "Awaiting payment",
  "chargeStatusOverdue": "Overdue",
  "chargeStatusPaid": "Paid",
  "chargeStatusCanceled": "Canceled",
  "chargeStatusRefunded": "Refunded",
  "chargeDueOn": "Due {date}",
  "@chargeDueOn": { "placeholders": { "date": { "type": "String" } } },
  "chargeInstallmentsSummary": "{count}x on card",
  "@chargeInstallmentsSummary": { "placeholders": { "count": { "type": "int" } } },
  "chargeShareOrderLink": "Share order link",
  "chargeCopyInvoiceLink": "Copy invoice link",
  "chargeInvoiceLinkCopied": "Invoice link copied",
  "chargeCancel": "Cancel charge",
  "chargeCancelConfirm": "Cancel this charge in Asaas? The customer will no longer be able to pay it.",
  "chargeKeep": "Keep",
  "chargeReplaceTitle": "There is already an open charge",
  "chargeReplaceConfirm": "Creating a new charge cancels the previous one in Asaas.",
  "chargeReplace": "Create new",
  "chargeTotalChanged": "The order balance ({balance}) differs from the charge amount ({value}).",
  "@chargeTotalChanged": { "placeholders": { "balance": { "type": "String" }, "value": { "type": "String" } } },
  "chargeRegenerate": "Create new charge"
}
```

Em `lib/l10n/app_es.arb`, substituir

```
  "viewPlans": "Ver planes"
}
```

por:

```json
  "viewPlans": "Ver planes",
  "asaasConnected": "Conectado",
  "asaasDisconnected": "No conectado",
  "asaasConnectTitle": "Conectar cuenta Asaas",
  "asaasConnectIntro": "Cobra por Pix, boleto o tarjeta en la cuenta Asaas de tu empresa. Cuando se confirma el pago, la orden se marca como pagada automáticamente.",
  "asaasConnectStep1": "1. En el panel de Asaas, abre Integraciones > Claves de API.",
  "asaasConnectStep2": "2. Genera una nueva clave y cópiala.",
  "asaasConnectStep3": "3. Pega la clave abajo y toca Conectar.",
  "asaasOpenPanel": "Abrir panel de Asaas",
  "asaasOpenSandboxPanel": "Abrir panel de prueba (sandbox)",
  "asaasApiKey": "Clave de API",
  "asaasApiKeyPlaceholder": "Pega la clave aquí",
  "asaasApiKeyHint": "La clave se guarda cifrada en el servidor y no vuelve a mostrarse en la app.",
  "asaasConnect": "Conectar",
  "asaasAccount": "Cuenta",
  "asaasEnvironment": "Entorno",
  "asaasEnvironmentSandbox": "Prueba",
  "asaasEnvironmentProduction": "Producción",
  "asaasDisconnect": "Desconectar",
  "asaasDisconnectConfirm": "¿Desconectar la cuenta Asaas? Los cobros abiertos siguen en Asaas, pero los pagos dejarán de actualizar la orden.",
  "asaasErrorInvalidKey": "Clave de API inválida. Revísala e inténtalo de nuevo.",
  "asaasErrorForbidden": "No tienes permiso para esta acción.",
  "asaasErrorNotConnected": "Conecta la cuenta Asaas en Configuración > Integraciones.",
  "asaasErrorExceedsBalance": "El monto es mayor que el saldo de la orden.",
  "asaasErrorTaxIdRequired": "Ingresa el CPF o CNPJ del cliente.",
  "asaasErrorCustomerRequired": "Agrega un cliente a la orden antes de cobrar.",
  "asaasErrorGeneric": "No se pudo completar. Inténtalo de nuevo.",
  "asaasTransactionCannotRemove": "Los pagos recibidos por Asaas no se pueden eliminar aquí. Para deshacerlos, reembólsalos en Asaas.",
  "invalidTaxId": "CPF o CNPJ inválido",
  "chargeWithAsaas": "Cobrar con Asaas",
  "chargeSectionTitle": "Cobro",
  "createChargeTitle": "Nuevo cobro",
  "chargeValue": "Monto",
  "chargeBalanceHint": "Saldo de la orden: {value}",
  "@chargeBalanceHint": { "placeholders": { "value": { "type": "String" } } },
  "chargeModeSingle": "Al contado",
  "chargeModeInstallments": "En cuotas con tarjeta",
  "chargeSingleHint": "El cliente elige Pix, boleto o tarjeta.",
  "chargeInstallmentsHint": "El cliente paga con tarjeta de crédito en las cuotas elegidas.",
  "chargeInstallments": "Cuotas",
  "chargeInstallmentOption": "{count}x de {value}",
  "@chargeInstallmentOption": { "placeholders": { "count": { "type": "int" }, "value": { "type": "String" } } },
  "chargeDueDate": "Vencimiento",
  "chargeTaxIdHint": "Asaas exige CPF o CNPJ. Se guarda en el registro del cliente.",
  "chargeGenerate": "Generar cobro",
  "chargeCreated": "Cobro generado",
  "chargeStatusPending": "Esperando pago",
  "chargeStatusOverdue": "Vencido",
  "chargeStatusPaid": "Pagado",
  "chargeStatusCanceled": "Cancelado",
  "chargeStatusRefunded": "Reembolsado",
  "chargeDueOn": "Vence el {date}",
  "@chargeDueOn": { "placeholders": { "date": { "type": "String" } } },
  "chargeInstallmentsSummary": "{count}x con tarjeta",
  "@chargeInstallmentsSummary": { "placeholders": { "count": { "type": "int" } } },
  "chargeShareOrderLink": "Compartir enlace de la orden",
  "chargeCopyInvoiceLink": "Copiar enlace de la factura",
  "chargeInvoiceLinkCopied": "Enlace de la factura copiado",
  "chargeCancel": "Cancelar cobro",
  "chargeCancelConfirm": "¿Cancelar este cobro en Asaas? El cliente ya no podrá pagarlo.",
  "chargeKeep": "Mantener",
  "chargeReplaceTitle": "Ya hay un cobro abierto",
  "chargeReplaceConfirm": "Generar un nuevo cobro cancela el anterior en Asaas.",
  "chargeReplace": "Generar nuevo",
  "chargeTotalChanged": "El saldo de la orden ({balance}) es distinto del monto del cobro ({value}).",
  "@chargeTotalChanged": { "placeholders": { "balance": { "type": "String" }, "value": { "type": "String" } } },
  "chargeRegenerate": "Generar nuevo cobro"
}
```

Gerar:

```bash
fvm flutter gen-l10n
```

Esperado: sem erros; `lib/l10n/app_localizations*.dart` ganham os getters novos (ex.: `chargeWithAsaas`, `chargeInstallmentOption(int count, String value)`).

- [ ] **Step 4: Implementar `asaasErrorText`**

`lib/screens/payments/asaas_error_text.dart`:

```dart
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/services/asaas_api_service.dart';

/// Maps an [AsaasApiException] to a localized, user-visible message.
///
/// The exception's `message` is the backend's raw diagnostic text and must
/// never reach the UI. Only `code` is used; unknown codes fall back to the
/// generic message.
String asaasErrorText(AppLocalizations l10n, AsaasApiException e) {
  switch (e.code) {
    case 'FORBIDDEN':
      return l10n.asaasErrorForbidden;
    case 'ASAAS_INVALID_API_KEY':
      return l10n.asaasErrorInvalidKey;
    case 'ASAAS_NOT_CONNECTED':
    case 'ASAAS_NOT_ENABLED':
      return l10n.asaasErrorNotConnected;
    case 'INVALID_VALUE':
      return l10n.asaasErrorExceedsBalance;
    case 'TAX_ID_REQUIRED':
      return l10n.asaasErrorTaxIdRequired;
    case 'INVALID_TAX_ID':
      return l10n.invalidTaxId;
    case 'CUSTOMER_REQUIRED':
      return l10n.asaasErrorCustomerRequired;
    default:
      return l10n.asaasErrorGeneric;
  }
}
```

- [ ] **Step 5: Rodar os testes**

```bash
fvm flutter test test/screens/payments/asaas_error_text_test.dart
fvm flutter analyze lib/l10n lib/screens/payments
```

Esperado: 8 testes PASS; `No issues found!`.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_pt.arb lib/l10n/app_en.arb lib/l10n/app_es.arb \
  lib/l10n/app_localizations.dart lib/l10n/app_localizations_pt.dart \
  lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_es.dart \
  lib/screens/payments/asaas_error_text.dart \
  test/screens/payments/asaas_error_text_test.dart
git commit -m "$(cat <<'EOF'
feat(payments): add Asaas strings (pt/en/es) and error mapping

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task D5: Campo CPF/CNPJ no cadastro do cliente

**Files:**
- Create: `lib/widgets/tax_id_form_field.dart`
- Modify: `lib/screens/customers/customer_form_screen.dart:1-9` (imports), `:122-130` (novo campo depois do e-mail), `:180-185` (`_builtInFieldKeys`)
- Test: `test/widgets/tax_id_form_field_test.dart`

**Interfaces:**
- Consumes: `onlyDigits`, `isValidTaxId`, `formatTaxId` (`lib/utils/tax_id.dart`, Bloco A); `Customer.taxId` (Bloco A); `easy_mask` (`TextInputMask`, já usado em `lib/widgets/dynamic_text_field.dart`).
- Produces: `TextInputFormatter taxIdInputMask()`, `String? validateTaxIdInput(AppLocalizations l10n, String? value, {bool required = false})`, `class TaxIdFormField extends StatelessWidget` (`initialValue`, `onSaved: ValueChanged<String?>?` — devolve só dígitos ou `null`).

A máscara segue o padrão de `docs/FIELD_VALIDATION_MASKS.md` (easy_mask com lista de máscaras escolhida pelo tamanho: CPF com 11 dígitos, CNPJ com 14). O campo só aparece para empresas do Brasil (ou sem país definido), porque CPF/CNPJ é brasileiro.

- [ ] **Step 1: Escrever o teste que falha**

`test/widgets/tax_id_form_field_test.dart`:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/widgets/tax_id_form_field.dart';

void main() {
  final l10n = AppLocalizationsPt();

  Future<GlobalKey<FormState>> pumpField(
    WidgetTester tester, {
    String? initialValue,
    required ValueChanged<String?> onSaved,
  }) async {
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CupertinoPageScaffold(
          child: Form(
            key: formKey,
            child: ListView(
              children: [
                CupertinoListSection.insetGrouped(
                  children: [
                    TaxIdFormField(initialValue: initialValue, onSaved: onSaved),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return formKey;
  }

  group('validateTaxIdInput', () {
    test('vazio é válido quando opcional', () {
      expect(validateTaxIdInput(l10n, ''), isNull);
      expect(validateTaxIdInput(l10n, null), isNull);
    });

    test('vazio é erro quando obrigatório', () {
      expect(validateTaxIdInput(l10n, '', required: true),
          l10n.asaasErrorTaxIdRequired);
    });

    test('CPF e CNPJ válidos com ou sem máscara', () {
      expect(validateTaxIdInput(l10n, '529.982.247-25'), isNull);
      expect(validateTaxIdInput(l10n, '11222333000181'), isNull);
    });

    test('dígito verificador errado é inválido', () {
      expect(validateTaxIdInput(l10n, '123.456.789-00'), l10n.invalidTaxId);
    });
  });

  group('TaxIdFormField', () {
    testWidgets('aplica máscara de CPF e salva só dígitos', (tester) async {
      String? saved = 'untouched';
      final formKey = await pumpField(tester, onSaved: (v) => saved = v);

      await tester.enterText(find.byType(CupertinoTextField), '52998224725');
      await tester.pump();

      expect(find.text('529.982.247-25'), findsOneWidget);
      expect(formKey.currentState!.validate(), isTrue);
      formKey.currentState!.save();
      expect(saved, '52998224725');
    });

    testWidgets('CPF inválido mostra erro', (tester) async {
      final formKey = await pumpField(tester, onSaved: (_) {});

      await tester.enterText(find.byType(CupertinoTextField), '12345678900');
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();

      expect(find.text(l10n.invalidTaxId), findsOneWidget);
    });

    testWidgets('vazio salva null', (tester) async {
      String? saved = 'untouched';
      final formKey = await pumpField(tester, onSaved: (v) => saved = v);

      expect(formKey.currentState!.validate(), isTrue);
      formKey.currentState!.save();
      expect(saved, isNull);
    });

    testWidgets('valor inicial aparece formatado como CNPJ', (tester) async {
      await pumpField(tester, initialValue: '11222333000181', onSaved: (_) {});

      expect(find.text('11.222.333/0001-81'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
fvm flutter test test/widgets/tax_id_form_field_test.dart
```

Esperado: FAIL de compilação — `Error when reading 'lib/widgets/tax_id_form_field.dart': No such file or directory`.

- [ ] **Step 3: Implementar o widget**

`lib/widgets/tax_id_form_field.dart`:

```dart
import 'package:easy_mask/easy_mask.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/utils/tax_id.dart';

/// CPF (11 digits) or CNPJ (14 digits); easy_mask picks the mask by length.
TextInputFormatter taxIdInputMask() =>
    TextInputMask(mask: ['999.999.999-99', '99.999.999/9999-99']);

/// Validates a CPF/CNPJ typed with or without mask.
String? validateTaxIdInput(
  AppLocalizations l10n,
  String? value, {
  bool required = false,
}) {
  final digits = onlyDigits(value ?? '');
  if (digits.isEmpty) return required ? l10n.asaasErrorTaxIdRequired : null;
  return isValidTaxId(digits) ? null : l10n.invalidTaxId;
}

/// Optional CPF/CNPJ row for Cupertino forms. Saves digits only, or null.
class TaxIdFormField extends StatelessWidget {
  const TaxIdFormField({super.key, this.initialValue, this.onSaved});

  final String? initialValue;
  final ValueChanged<String?>? onSaved;

  @override
  Widget build(BuildContext context) {
    final initial = initialValue ?? '';
    return CupertinoTextFormFieldRow(
      key: const Key('taxIdFormField'),
      prefix: Text(context.l10n.cpfCnpj, style: const TextStyle(fontSize: 16)),
      initialValue: initial.isEmpty ? null : formatTaxId(initial),
      placeholder: context.l10n.optional,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.right,
      inputFormatters: [taxIdInputMask()],
      validator: (value) => validateTaxIdInput(context.l10n, value),
      onSaved: (value) {
        final digits = onlyDigits(value ?? '');
        onSaved?.call(digits.isEmpty ? null : digits);
      },
    );
  }
}
```

- [ ] **Step 4: Usar no cadastro do cliente**

Em `lib/screens/customers/customer_form_screen.dart`:

1. Adicionar ao bloco de imports (depois da linha 9):

```dart
import 'package:praticos/widgets/tax_id_form_field.dart';
```

2. Logo depois do `CupertinoTextFormFieldRow` do e-mail (o que termina em `onSaved: (val) => _customer?.email = val,` + `),`, linhas 122-130) e antes do campo de endereço, inserir:

```dart
                  // CPF/CNPJ (Brazil only): required by Asaas to charge
                  if (config.countryCode == null || config.countryCode == 'BR')
                    TaxIdFormField(
                      initialValue: _customer?.taxId,
                      onSaved: (val) => _customer?.taxId = val,
                    ),
```

3. Em `_builtInFieldKeys` (linhas 180-185), acrescentar `'customer.taxId'` para o segmento não renderizar o campo duplicado:

```dart
  static const _builtInFieldKeys = {
    'customer.name',
    'customer.phone',
    'customer.email',
    'customer.address',
    'customer.taxId',
  };
```

- [ ] **Step 5: Rodar os testes**

```bash
fvm flutter test test/widgets/tax_id_form_field_test.dart
fvm flutter analyze lib/widgets/tax_id_form_field.dart lib/screens/customers
```

Esperado: 8 testes PASS; `No issues found!`.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/tax_id_form_field.dart lib/screens/customers/customer_form_screen.dart \
  test/widgets/tax_id_form_field_test.dart
git commit -m "$(cat <<'EOF'
feat(customers): add CPF/CNPJ field with mask and validation

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task D6: Integrações > Pagamentos > Asaas

**Files:**
- Create: `lib/screens/integrations/asaas_connection_screen.dart`
- Modify: `lib/screens/integrations/integration_list_screen.dart:1-8` (imports), `:81-85` (campo de estado), `:236-246` (nova sliver)
- Test: `test/screens/integrations/asaas_connection_screen_test.dart`

**Interfaces:**
- Consumes: `AsaasApiService.connect/disconnect`, `AsaasApiException` (D3); `PaymentSettings` (D1); `PaymentSettingsRepository.watch` (D2); `asaasErrorText` (D4); `AuthorizationService.instance.hasPermission(PermissionType.manageUsers)`; `url_launcher`.
- Produces: `const asaasPanelUrl`, `const asaasSandboxPanelUrl`, `class PaymentsIntegrationSection extends StatelessWidget({required Stream<PaymentSettings> settingsStream})`, `class AsaasConnectionScreen extends StatefulWidget({AsaasApiService? service, Stream<PaymentSettings>? settingsStream})`.

A seção "Pagamentos" só aparece com `asaasEnabled` e só é montada para dono/admin (`manageUsers`, o mesmo guard que abre Integrações). A chave digitada é apagada do campo logo depois do `connect` e nunca é guardada no app.

- [ ] **Step 1: Escrever o teste que falha**

`test/screens/integrations/asaas_connection_screen_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/models/payment_settings.dart';
import 'package:praticos/screens/integrations/asaas_connection_screen.dart';
import 'package:praticos/services/asaas_api_service.dart';

void main() {
  final l10n = AppLocalizationsPt();

  AsaasApiService service(MockClientHandler handler) =>
      AsaasApiService.withClient(
        MockClient(handler),
        headersProvider: () async => {'Authorization': 'Bearer t'},
      );

  Widget app(Widget home) => CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      );

  Future<void> pumpScreen(
    WidgetTester tester, {
    required PaymentSettings settings,
    required AsaasApiService api,
  }) async {
    await tester.pumpWidget(app(AsaasConnectionScreen(
      service: api,
      settingsStream: Stream.value(settings),
    )));
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  final disconnected = PaymentSettings(asaasEnabled: true);

  group('AsaasConnectionScreen desconectada', () {
    testWidgets('mostra instruções, links e campo oculto', (tester) async {
      await pumpScreen(tester,
          settings: disconnected,
          api: service((_) async => http.Response('{}', 500)));

      expect(find.text(l10n.asaasConnectStep1), findsOneWidget);
      expect(find.text(l10n.asaasOpenPanel), findsOneWidget);
      expect(find.text(l10n.asaasOpenSandboxPanel), findsOneWidget);
      final field = tester.widget<CupertinoTextField>(
          find.byKey(const Key('asaasApiKeyField')));
      expect(field.obscureText, isTrue);
      expect(field.enableSuggestions, isFalse);
    });

    testWidgets('Conectar sem chave não chama a API', (tester) async {
      var calls = 0;
      await pumpScreen(tester,
          settings: disconnected,
          api: service((_) async {
            calls++;
            return http.Response('{}', 200);
          }));

      await tapKey(tester, 'asaasConnectButton');

      expect(calls, 0);
    });

    testWidgets('conecta e mostra conta e ambiente Teste', (tester) async {
      await pumpScreen(tester,
          settings: disconnected,
          api: service((request) async {
            expect(jsonDecode(request.body), {'apiKey': '\$aact_hmlg_000'});
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'asaasEnabled': true,
                  'asaasConnected': true,
                  'asaasAccountName': 'Rafsoft',
                  'asaasEnvironment': 'sandbox',
                },
              }),
              200,
            );
          }));

      await tester.enterText(
          find.byKey(const Key('asaasApiKeyField')), '\$aact_hmlg_000');
      await tapKey(tester, 'asaasConnectButton');

      expect(find.text('Rafsoft'), findsOneWidget);
      expect(find.text(l10n.asaasEnvironmentSandbox), findsOneWidget);
      expect(find.byKey(const Key('asaasApiKeyField')), findsNothing);
    });

    testWidgets('chave inválida mostra erro traduzido', (tester) async {
      await pumpScreen(tester,
          settings: disconnected,
          api: service((_) async => http.Response(
                jsonEncode({
                  'success': false,
                  'error': {
                    'code': 'ASAAS_INVALID_API_KEY',
                    'message': 'raw backend text',
                  },
                }),
                400,
              )));

      await tester.enterText(
          find.byKey(const Key('asaasApiKeyField')), '\$aact_hmlg_bad');
      await tapKey(tester, 'asaasConnectButton');

      expect(find.text(l10n.asaasErrorInvalidKey), findsOneWidget);
      expect(find.textContaining('raw backend text'), findsNothing);
    });
  });

  group('AsaasConnectionScreen conectada', () {
    final connected = PaymentSettings(
      asaasEnabled: true,
      asaasConnected: true,
      asaasAccountName: 'Oficina do João',
      asaasEnvironment: 'production',
    );

    testWidgets('mostra conta, ambiente Produção e desconecta', (tester) async {
      var deleted = false;
      await pumpScreen(tester,
          settings: connected,
          api: service((request) async {
            expect(request.method, 'DELETE');
            deleted = true;
            return http.Response(jsonEncode({'success': true}), 200);
          }));

      expect(find.text('Oficina do João'), findsOneWidget);
      expect(find.text(l10n.asaasEnvironmentProduction), findsOneWidget);

      await tapKey(tester, 'asaasDisconnectTile');
      expect(find.text(l10n.asaasDisconnectConfirm), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirmAsaasDisconnectAction')));
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
      expect(find.byKey(const Key('asaasConnectButton')), findsOneWidget);
    });

    testWidgets('cancelar o diálogo não desconecta', (tester) async {
      var calls = 0;
      await pumpScreen(tester,
          settings: connected,
          api: service((_) async {
            calls++;
            return http.Response('{}', 200);
          }));

      await tapKey(tester, 'asaasDisconnectTile');
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();

      expect(calls, 0);
      expect(find.text('Oficina do João'), findsOneWidget);
    });
  });

  group('PaymentsIntegrationSection', () {
    testWidgets('some quando o piloto está desligado', (tester) async {
      await tester.pumpWidget(app(CupertinoPageScaffold(
        child: PaymentsIntegrationSection(
          settingsStream: Stream.value(PaymentSettings()),
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Asaas'), findsNothing);
    });

    testWidgets('mostra Asaas com status de conexão', (tester) async {
      await tester.pumpWidget(app(CupertinoPageScaffold(
        child: PaymentsIntegrationSection(
          settingsStream: Stream.value(
              PaymentSettings(asaasEnabled: true, asaasConnected: true)),
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Asaas'), findsOneWidget);
      expect(find.text(l10n.asaasConnected), findsOneWidget);
      expect(find.text(l10n.payments.toUpperCase()), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
fvm flutter test test/screens/integrations/asaas_connection_screen_test.dart
```

Esperado: FAIL de compilação — `Error when reading 'lib/screens/integrations/asaas_connection_screen.dart': No such file or directory`.

- [ ] **Step 3: Implementar a tela**

`lib/screens/integrations/asaas_connection_screen.dart`:

```dart
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/payment_settings.dart';
import 'package:praticos/repositories/tenant/payment_settings_repository.dart';
import 'package:praticos/screens/payments/asaas_error_text.dart';
import 'package:praticos/services/asaas_api_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Asaas dashboard page where the user creates an API key.
const asaasPanelUrl = 'https://www.asaas.com/customerConfigIntegrations/index';
const asaasSandboxPanelUrl =
    'https://sandbox.asaas.com/customerConfigIntegrations/index';

Stream<PaymentSettings> _defaultSettingsStream() {
  final companyId = Global.companyAggr?.id;
  if (companyId == null) return Stream.value(PaymentSettings());
  return PaymentSettingsRepository().watch(companyId);
}

/// "Payments" section of the Integrations screen. Hidden until the company
/// is in the Asaas pilot (`asaasEnabled`).
class PaymentsIntegrationSection extends StatelessWidget {
  const PaymentsIntegrationSection({super.key, required this.settingsStream});

  final Stream<PaymentSettings> settingsStream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PaymentSettings>(
      stream: settingsStream,
      builder: (context, snapshot) {
        final settings = snapshot.data;
        if (settings == null || !settings.asaasEnabled) {
          return const SizedBox.shrink();
        }
        final l10n = context.l10n;
        return CupertinoListSection.insetGrouped(
          header: Text(l10n.payments.toUpperCase()),
          children: [
            CupertinoListTile(
              key: const Key('asaasIntegrationTile'),
              leading: const Icon(CupertinoIcons.creditcard),
              title: const Text('Asaas'),
              additionalInfo: Text(settings.asaasConnected
                  ? l10n.asaasConnected
                  : l10n.asaasDisconnected),
              trailing: const CupertinoListTileChevron(),
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => const AsaasConnectionScreen(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Connects or disconnects the company's Asaas account.
///
/// The API key goes straight to the server and is cleared from the field;
/// the app never stores it.
class AsaasConnectionScreen extends StatefulWidget {
  const AsaasConnectionScreen({super.key, this.service, this.settingsStream});

  /// Test seam; defaults to [AsaasApiService.instance].
  final AsaasApiService? service;

  /// Test seam; defaults to the company's `settings/payments` document.
  final Stream<PaymentSettings>? settingsStream;

  @override
  State<AsaasConnectionScreen> createState() => _AsaasConnectionScreenState();
}

class _AsaasConnectionScreenState extends State<AsaasConnectionScreen> {
  final _apiKeyController = TextEditingController();
  StreamSubscription<PaymentSettings>? _subscription;
  PaymentSettings? _settings;
  bool _busy = false;

  AsaasApiService get _service => widget.service ?? AsaasApiService.instance;

  @override
  void initState() {
    super.initState();
    _subscription =
        (widget.settingsStream ?? _defaultSettingsStream()).listen((settings) {
      if (!mounted) return;
      setState(() => _settings = settings);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty || _busy) return;

    setState(() => _busy = true);
    try {
      final settings = await _service.connect(apiKey);
      _apiKeyController.clear();
      if (!mounted) return;
      setState(() => _settings = settings);
    } on AsaasApiException catch (e) {
      if (!mounted) return;
      _showMessage(asaasErrorText(context.l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(dialogContext.l10n.asaasDisconnect),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(dialogContext.l10n.asaasDisconnectConfirm),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.cancel),
          ),
          CupertinoDialogAction(
            key: const Key('confirmAsaasDisconnectAction'),
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.asaasDisconnect),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _service.disconnect();
      if (!mounted) return;
      setState(() => _settings = PaymentSettings(
            asaasEnabled: _settings?.asaasEnabled ?? true,
            asaasConnected: false,
          ));
    } on AsaasApiException catch (e) {
      if (!mounted) return;
      _showMessage(asaasErrorText(context.l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPanel(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _showMessage(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.l10n.ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return CupertinoPageScaffold(
      backgroundColor:
          CupertinoColors.systemGroupedBackground.resolveFrom(context),
      navigationBar: const CupertinoNavigationBar(middle: Text('Asaas')),
      child: SafeArea(
        child: settings == null
            ? const Center(child: CupertinoActivityIndicator())
            : ListView(
                children: settings.asaasConnected
                    ? _buildConnected(context, settings)
                    : _buildDisconnected(context),
              ),
      ),
    );
  }

  List<Widget> _buildDisconnected(BuildContext context) {
    final l10n = context.l10n;
    final stepStyle = TextStyle(
      fontSize: 15,
      color: CupertinoColors.secondaryLabel.resolveFrom(context),
    );

    return [
      CupertinoListSection.insetGrouped(
        header: Text(l10n.asaasConnectTitle.toUpperCase()),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.asaasConnectIntro,
                  style: TextStyle(
                    fontSize: 15,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 12),
                Text(l10n.asaasConnectStep1, style: stepStyle),
                const SizedBox(height: 4),
                Text(l10n.asaasConnectStep2, style: stepStyle),
                const SizedBox(height: 4),
                Text(l10n.asaasConnectStep3, style: stepStyle),
              ],
            ),
          ),
          CupertinoListTile(
            title: Text(l10n.asaasOpenPanel),
            trailing: const Icon(CupertinoIcons.arrow_up_right_square),
            onTap: () => _openPanel(asaasPanelUrl),
          ),
          CupertinoListTile(
            title: Text(l10n.asaasOpenSandboxPanel),
            trailing: const Icon(CupertinoIcons.arrow_up_right_square),
            onTap: () => _openPanel(asaasSandboxPanelUrl),
          ),
        ],
      ),
      CupertinoListSection.insetGrouped(
        header: Text(l10n.asaasApiKey.toUpperCase()),
        footer: Text(l10n.asaasApiKeyHint),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: CupertinoTextField(
              key: const Key('asaasApiKeyField'),
              controller: _apiKeyController,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              placeholder: l10n.asaasApiKeyPlaceholder,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6.resolveFrom(context),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: SizedBox(
          width: double.infinity,
          child: CupertinoButton.filled(
            key: const Key('asaasConnectButton'),
            onPressed: _busy ? null : _connect,
            child: _busy
                ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                : Text(l10n.asaasConnect),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildConnected(BuildContext context, PaymentSettings settings) {
    final l10n = context.l10n;
    final isSandbox = settings.isSandbox;
    final badgeColor = isSandbox
        ? CupertinoColors.systemOrange.resolveFrom(context)
        : CupertinoColors.systemGreen.resolveFrom(context);

    return [
      CupertinoListSection.insetGrouped(
        children: [
          CupertinoListTile(
            title: Text(l10n.asaasAccount),
            additionalInfo: Text(settings.asaasAccountName ?? ''),
          ),
          CupertinoListTile(
            title: Text(l10n.asaasEnvironment),
            additionalInfo: Container(
              key: const Key('asaasEnvironmentBadge'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isSandbox
                    ? l10n.asaasEnvironmentSandbox
                    : l10n.asaasEnvironmentProduction,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: badgeColor,
                ),
              ),
            ),
          ),
        ],
      ),
      CupertinoListSection.insetGrouped(
        children: [
          CupertinoListTile(
            key: const Key('asaasDisconnectTile'),
            title: Text(
              l10n.asaasDisconnect,
              style: const TextStyle(color: CupertinoColors.systemRed),
            ),
            trailing: _busy ? const CupertinoActivityIndicator() : null,
            onTap: _busy ? null : _disconnect,
          ),
        ],
      ),
    ];
  }
}
```

- [ ] **Step 4: Ligar na tela de Integrações**

Em `lib/screens/integrations/integration_list_screen.dart`:

1. Imports (depois da linha 8):

```dart
import 'package:praticos/global.dart';
import 'package:praticos/models/payment_settings.dart';
import 'package:praticos/models/permission.dart';
import 'package:praticos/repositories/tenant/payment_settings_repository.dart';
import 'package:praticos/screens/integrations/asaas_connection_screen.dart';
import 'package:praticos/services/authorization_service.dart';
```

2. Em `_IntegrationListScreenState`, logo depois de `String? _error;` (linha 85):

```dart

  /// Only owner/admin manage payment integrations (same guard that opens
  /// this screen in Settings). Null hides the Payments section.
  late final Stream<PaymentSettings>? _paymentSettings =
      _paymentSettingsStream();

  static Stream<PaymentSettings>? _paymentSettingsStream() {
    final companyId = Global.companyAggr?.id;
    if (companyId == null ||
        !AuthorizationService.instance
            .hasPermission(PermissionType.manageUsers)) {
      return null;
    }
    return PaymentSettingsRepository().watch(companyId);
  }
```

3. Em `build`, na lista `slivers`, logo depois de `SliverToBoxAdapter(child: _buildBody(context)),` (linha 245):

```dart
          if (_paymentSettings != null)
            SliverToBoxAdapter(
              child: PaymentsIntegrationSection(
                settingsStream: _paymentSettings!,
              ),
            ),
```

- [ ] **Step 5: Rodar os testes**

```bash
fvm flutter test test/screens/integrations/
fvm flutter analyze lib/screens/integrations
```

Esperado: os 8 testes novos e os testes existentes de `test/screens/integrations/` PASS; `No issues found!`.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/integrations/asaas_connection_screen.dart \
  lib/screens/integrations/integration_list_screen.dart \
  test/screens/integrations/asaas_connection_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(integrations): connect and disconnect the Asaas account

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task D7: Tela "Nova cobrança" (`create_charge_screen.dart`)

**Files:**
- Create: `lib/screens/payments/create_charge_screen.dart`
- Test: `test/screens/payments/create_charge_screen_test.dart`

**Interfaces:**
- Consumes: `Order`, `CustomerAggr.taxId` (Bloco A), `ChargeMode`, `OrderCharge` (D1), `AsaasApiService.createCharge`, `AsaasApiException` (D3), `asaasErrorText` (D4), `taxIdInputMask` (D5), `onlyDigits`, `isValidTaxId` (Bloco A), `TenantCustomerRepository.getSingle`, `FormatService`.
- Produces: `enum ChargeFormError { customerRequired, valueRequired, valueExceedsBalance, taxIdRequired, taxIdInvalid }`, `ChargeFormError? validateChargeInput({required bool hasCustomer, required double value, required double remainingBalance, required bool needsTaxId, required String taxIdInput})`, `String chargeFormErrorText(AppLocalizations, ChargeFormError)`, `double parseCurrencyInput(String)`, `class CreateChargeScreen extends StatefulWidget({required Order order, required double remainingBalance, AsaasApiService? service, Future<String?> Function()? customerTaxIdLoader})` — faz `Navigator.pop(context, OrderCharge)` ao gerar.

Regras na tela: valor padrão = saldo restante, editável só para menos; parcelado 2–12x (padrão 2) mostrando o valor da parcela; vencimento padrão hoje + 3 dias, sem datas passadas; CPF/CNPJ pedido só quando nem o agregado do cliente na OS nem o cadastro do cliente têm `taxId` (OS antigas embutem `CustomerAggr` sem `taxId`, por isso o cadastro é consultado). O campo de valor usa o mesmo `CurrencyTextInputFormatter` em BRL de `payment_management_screen.dart` (o Asaas só cobra em real).

- [ ] **Step 1: Escrever o teste que falha**

`test/screens/payments/create_charge_screen_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/models/customer.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/screens/payments/create_charge_screen.dart';
import 'package:praticos/services/asaas_api_service.dart';
import 'package:praticos/services/format_service.dart';

void main() {
  final l10n = AppLocalizationsPt();
  final format = FormatService();

  Order order({String? taxId, bool withCustomer = true}) => Order()
    ..id = 'o1'
    ..number = 42
    ..total = 1000
    ..paidAmount = 0
    ..customer = withCustomer
        ? (CustomerAggr()
          ..id = 'c1'
          ..name = 'Maria'
          ..taxId = taxId)
        : null;

  AsaasApiService service(MockClientHandler handler) =>
      AsaasApiService.withClient(
        MockClient(handler),
        headersProvider: () async => {'Authorization': 'Bearer t'},
      );

  Future<List<OrderCharge?>> pumpHost(
    WidgetTester tester, {
    required Order order,
    required AsaasApiService api,
    double remaining = 1000,
    String? loadedTaxId,
  }) async {
    final results = <OrderCharge?>[];
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => CupertinoButton(
            child: const Text('open'),
            onPressed: () async {
              results.add(await Navigator.of(context).push<OrderCharge>(
                CupertinoPageRoute(
                  builder: (_) => CreateChargeScreen(
                    order: order,
                    remainingBalance: remaining,
                    service: api,
                    customerTaxIdLoader: () async => loadedTaxId,
                  ),
                ),
              ));
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  group('validateChargeInput', () {
    ChargeFormError? validate({
      bool hasCustomer = true,
      double value = 100,
      double remaining = 1000,
      bool needsTaxId = false,
      String taxId = '',
    }) =>
        validateChargeInput(
          hasCustomer: hasCustomer,
          value: value,
          remainingBalance: remaining,
          needsTaxId: needsTaxId,
          taxIdInput: taxId,
        );

    test('entrada válida', () {
      expect(validate(), isNull);
      expect(validate(value: 1000), isNull);
    });

    test('OS sem cliente', () {
      expect(validate(hasCustomer: false), ChargeFormError.customerRequired);
    });

    test('valor zero', () {
      expect(validate(value: 0), ChargeFormError.valueRequired);
    });

    test('valor acima do saldo', () {
      expect(validate(value: 1000.01), ChargeFormError.valueExceedsBalance);
    });

    test('CPF/CNPJ obrigatório, vazio ou inválido', () {
      expect(validate(needsTaxId: true), ChargeFormError.taxIdRequired);
      expect(validate(needsTaxId: true, taxId: '123.456.789-00'),
          ChargeFormError.taxIdInvalid);
      expect(validate(needsTaxId: true, taxId: '529.982.247-25'), isNull);
    });
  });

  group('parseCurrencyInput', () {
    test('lê o valor formatado pelo FormatService', () {
      expect(parseCurrencyInput(format.formatCurrency(1234.56)), 1234.56);
    });

    test('lê o texto do campo com máscara', () {
      expect(parseCurrencyInput('R\$ 1.500,00'), 1500.0);
    });

    test('vazio é zero', () {
      expect(parseCurrencyInput(''), 0);
    });
  });

  group('CreateChargeScreen', () {
    testWidgets('preenche o valor com o saldo e não pede CPF se já existe',
        (tester) async {
      await pumpHost(tester,
          order: order(taxId: '52998224725'),
          api: service((_) async => http.Response('{}', 500)));

      final field = tester
          .widget<CupertinoTextField>(find.byKey(const Key('chargeValueField')));
      expect(field.controller!.text, format.formatCurrency(1000));
      expect(find.byKey(const Key('chargeTaxIdField')), findsNothing);
      expect(find.text(l10n.chargeBalanceHint(format.formatCurrency(1000))),
          findsOneWidget);
    });

    testWidgets('usa o CPF do cadastro quando o agregado não tem',
        (tester) async {
      await pumpHost(tester,
          order: order(),
          loadedTaxId: '52998224725',
          api: service((_) async => http.Response('{}', 500)));

      expect(find.byKey(const Key('chargeTaxIdField')), findsNothing);
    });

    testWidgets('valor acima do saldo mostra erro e não chama a API',
        (tester) async {
      var calls = 0;
      await pumpHost(tester,
          order: order(taxId: '52998224725'),
          api: service((_) async {
            calls++;
            return http.Response('{}', 500);
          }));

      await tester.enterText(
          find.byKey(const Key('chargeValueField')), '150000');
      await tapKey(tester, 'generateChargeButton');

      expect(find.text(l10n.asaasErrorExceedsBalance), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('cliente sem CPF/CNPJ exige o documento', (tester) async {
      await pumpHost(tester,
          order: order(),
          api: service((_) async => http.Response('{}', 500)));

      expect(find.byKey(const Key('chargeTaxIdField')), findsOneWidget);
      await tapKey(tester, 'generateChargeButton');

      expect(find.text(l10n.asaasErrorTaxIdRequired), findsOneWidget);
    });

    testWidgets('CPF inválido mostra erro', (tester) async {
      await pumpHost(tester,
          order: order(),
          api: service((_) async => http.Response('{}', 500)));

      await tester.ensureVisible(find.byKey(const Key('chargeTaxIdField')));
      await tester.enterText(
          find.byKey(const Key('chargeTaxIdField')), '12345678900');
      await tapKey(tester, 'generateChargeButton');

      expect(find.text(l10n.invalidTaxId), findsOneWidget);
    });

    testWidgets('OS sem cliente mostra erro', (tester) async {
      await pumpHost(tester,
          order: order(withCustomer: false),
          api: service((_) async => http.Response('{}', 500)));

      await tapKey(tester, 'generateChargeButton');

      expect(find.text(l10n.asaasErrorCustomerRequired), findsOneWidget);
    });

    testWidgets('parcelado em 3x envia parcelas, vencimento e CPF e fecha',
        (tester) async {
      final now = DateTime.now();
      final due = DateTime(now.year, now.month, now.day + 3);

      final results = await pumpHost(tester,
          order: order(),
          api: service((request) async {
            expect(request.url.path, endsWith('/v1/app/orders/o1/charges'));
            expect(jsonDecode(request.body), {
              'value': 1000,
              'mode': 'cardInstallments',
              'installmentCount': 3,
              'dueDate': DateFormat('yyyy-MM-dd').format(due),
              'customerTaxId': '52998224725',
            });
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'id': 'ch1',
                  'mode': 'cardInstallments',
                  'installmentCount': 3,
                  'value': 1000,
                  'status': 'pending',
                  'invoiceUrl': 'https://sandbox.asaas.com/i/abc',
                },
              }),
              201,
            );
          }));

      await tester.tap(find.text(l10n.chargeModeInstallments));
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.chargeInstallmentOption(2, format.formatCurrency(500))),
        findsOneWidget,
      );

      await tapKey(tester, 'chargeInstallmentsTile');
      await tester.tap(find.text(
          l10n.chargeInstallmentOption(3, format.formatCurrency(1000 / 3))));
      await tester.pumpAndSettle();
      expect(
        find.text(
            l10n.chargeInstallmentOption(3, format.formatCurrency(1000 / 3))),
        findsOneWidget,
      );

      await tester.ensureVisible(find.byKey(const Key('chargeTaxIdField')));
      await tester.enterText(
          find.byKey(const Key('chargeTaxIdField')), '52998224725');
      await tapKey(tester, 'generateChargeButton');

      expect(results, hasLength(1));
      expect(results.single?.id, 'ch1');
      expect(find.byType(CreateChargeScreen), findsNothing);
    });

    testWidgets('erro da API aparece traduzido e a tela continua aberta',
        (tester) async {
      await pumpHost(tester,
          order: order(taxId: '52998224725'),
          api: service((_) async => http.Response(
                jsonEncode({
                  'success': false,
                  'error': {
                    'code': 'ASAAS_NOT_CONNECTED',
                    'message': 'raw backend text',
                  },
                }),
                409,
              )));

      await tapKey(tester, 'generateChargeButton');

      expect(find.text(l10n.asaasErrorNotConnected), findsOneWidget);
      expect(find.byType(CreateChargeScreen), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
fvm flutter test test/screens/payments/create_charge_screen_test.dart
```

Esperado: FAIL de compilação — `Error when reading 'lib/screens/payments/create_charge_screen.dart': No such file or directory`.

- [ ] **Step 3: Implementar**

`lib/screens/payments/create_charge_screen.dart`:

```dart
import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';
import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/repositories/tenant/tenant_customer_repository.dart';
import 'package:praticos/screens/payments/asaas_error_text.dart';
import 'package:praticos/services/asaas_api_service.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/utils/tax_id.dart';
import 'package:praticos/widgets/tax_id_form_field.dart' show taxIdInputMask;

enum ChargeFormError {
  customerRequired,
  valueRequired,
  valueExceedsBalance,
  taxIdRequired,
  taxIdInvalid,
}

/// Client-side checks before calling the API. The server validates again.
ChargeFormError? validateChargeInput({
  required bool hasCustomer,
  required double value,
  required double remainingBalance,
  required bool needsTaxId,
  required String taxIdInput,
}) {
  if (!hasCustomer) return ChargeFormError.customerRequired;
  if (value <= 0) return ChargeFormError.valueRequired;
  if (value > remainingBalance + 0.004) {
    return ChargeFormError.valueExceedsBalance;
  }
  if (needsTaxId) {
    final digits = onlyDigits(taxIdInput);
    if (digits.isEmpty) return ChargeFormError.taxIdRequired;
    if (!isValidTaxId(digits)) return ChargeFormError.taxIdInvalid;
  }
  return null;
}

String chargeFormErrorText(AppLocalizations l10n, ChargeFormError error) {
  switch (error) {
    case ChargeFormError.customerRequired:
      return l10n.asaasErrorCustomerRequired;
    case ChargeFormError.valueRequired:
      return l10n.valueMustBeGreaterThanZero;
    case ChargeFormError.valueExceedsBalance:
      return l10n.asaasErrorExceedsBalance;
    case ChargeFormError.taxIdRequired:
      return l10n.asaasErrorTaxIdRequired;
    case ChargeFormError.taxIdInvalid:
      return l10n.invalidTaxId;
  }
}

/// Parses the currency field: first with the locale format, then by
/// stripping symbols (same fallback as PaymentManagementScreen._parseValue).
double parseCurrencyInput(String text) {
  final value = text.trim();
  if (value.isEmpty) return 0;
  try {
    return FormatService().currencyFormat.parse(value).toDouble();
  } catch (_) {
    final clean = value
        .replaceAll(RegExp(r'[^0-9,.\-]'), '')
        .replaceAll(RegExp(r'\.(?=.*,)'), '')
        .replaceAll(RegExp(r',(?=.*\.)'), '')
        .replaceAll(',', '.');
    return double.tryParse(clean) ?? 0;
  }
}

/// Creates an Asaas charge for an order. Pops with the created [OrderCharge].
class CreateChargeScreen extends StatefulWidget {
  const CreateChargeScreen({
    super.key,
    required this.order,
    required this.remainingBalance,
    this.service,
    this.customerTaxIdLoader,
  });

  final Order order;
  final double remainingBalance;

  /// Test seam; defaults to [AsaasApiService.instance].
  final AsaasApiService? service;

  /// Test seam; defaults to reading `taxId` from the customer document.
  final Future<String?> Function()? customerTaxIdLoader;

  @override
  State<CreateChargeScreen> createState() => _CreateChargeScreenState();
}

class _CreateChargeScreenState extends State<CreateChargeScreen> {
  static const _minInstallments = 2;
  static const _maxInstallments = 12;

  final _formatService = FormatService();
  late final TextEditingController _valueController;
  final _taxIdController = TextEditingController();

  ChargeMode _mode = ChargeMode.single;
  int _installmentCount = _minInstallments;
  late DateTime _dueDate;
  String? _knownTaxId;
  bool _loadingTaxId = false;
  bool _submitting = false;

  AsaasApiService get _service => widget.service ?? AsaasApiService.instance;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get _needsTaxId => !_loadingTaxId && (_knownTaxId ?? '').isEmpty;

  @override
  void initState() {
    super.initState();
    final today = _today();
    _dueDate = DateTime(today.year, today.month, today.day + 3);
    _valueController = TextEditingController(
      text: widget.remainingBalance > 0
          ? _formatService.formatCurrency(widget.remainingBalance)
          : '',
    );
    _valueController.addListener(_onValueChanged);

    _knownTaxId = widget.order.customer?.taxId;
    if ((_knownTaxId ?? '').isEmpty && widget.order.customer?.id != null) {
      _loadingTaxId = true;
      _loadCustomerTaxId();
    }
  }

  @override
  void dispose() {
    _valueController.removeListener(_onValueChanged);
    _valueController.dispose();
    _taxIdController.dispose();
    super.dispose();
  }

  void _onValueChanged() => setState(() {});

  Future<void> _loadCustomerTaxId() async {
    String? taxId;
    try {
      final loader = widget.customerTaxIdLoader ?? _loadTaxIdFromCustomer;
      taxId = await loader();
    } catch (_) {
      taxId = null;
    }
    if (!mounted) return;
    setState(() {
      _knownTaxId = taxId;
      _loadingTaxId = false;
    });
  }

  /// Orders embed an older CustomerAggr without taxId; the customer document
  /// is the source of truth.
  Future<String?> _loadTaxIdFromCustomer() async {
    final companyId = widget.order.company?.id ?? Global.companyAggr?.id;
    final customerId = widget.order.customer?.id;
    if (companyId == null || customerId == null) return null;
    final customer =
        await TenantCustomerRepository().getSingle(companyId, customerId);
    return customer?.taxId;
  }

  Future<void> _submit() async {
    final value = parseCurrencyInput(_valueController.text);
    final error = validateChargeInput(
      hasCustomer: widget.order.customer?.id != null,
      value: value,
      remainingBalance: widget.remainingBalance,
      needsTaxId: _needsTaxId,
      taxIdInput: _taxIdController.text,
    );
    if (error != null) {
      _showMessage(chargeFormErrorText(context.l10n, error));
      return;
    }

    setState(() => _submitting = true);
    try {
      final charge = await _service.createCharge(
        widget.order.id!,
        value: value,
        mode: _mode,
        installmentCount:
            _mode == ChargeMode.cardInstallments ? _installmentCount : null,
        dueDate: _dueDate,
        customerTaxId: _needsTaxId ? onlyDigits(_taxIdController.text) : null,
      );
      if (!mounted) return;
      Navigator.pop(context, charge);
    } on AsaasApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showMessage(asaasErrorText(context.l10n, e));
    }
  }

  void _pickInstallments() {
    final value = parseCurrencyInput(_valueController.text);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(sheetContext.l10n.chargeInstallments),
        actions: [
          for (var count = _minInstallments; count <= _maxInstallments; count++)
            CupertinoActionSheetAction(
              onPressed: () {
                setState(() => _installmentCount = count);
                Navigator.pop(sheetContext);
              },
              child: Text(sheetContext.l10n.chargeInstallmentOption(
                count,
                _formatService.formatCurrency(value / count),
              )),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: Text(sheetContext.l10n.cancel),
        ),
      ),
    );
  }

  void _pickDueDate() {
    var selected = _dueDate;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) => Container(
        height: 300,
        color: CupertinoColors.systemBackground.resolveFrom(popupContext),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: CupertinoButton(
                  onPressed: () {
                    setState(() => _dueDate = selected);
                    Navigator.pop(popupContext);
                  },
                  child: Text(popupContext.l10n.confirm),
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _dueDate,
                  minimumDate: _today(),
                  onDateTimeChanged: (date) =>
                      selected = DateTime(date.year, date.month, date.day),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.l10n.ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _formatService.setLocale(Localizations.localeOf(context).toString());
    final l10n = context.l10n;
    final value = parseCurrencyInput(_valueController.text);
    final fieldDecoration = BoxDecoration(
      color: CupertinoColors.systemGrey6.resolveFrom(context),
      borderRadius: BorderRadius.circular(8),
    );

    return CupertinoPageScaffold(
      backgroundColor:
          CupertinoColors.systemGroupedBackground.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.createChargeTitle),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              header: Text(l10n.chargeValue.toUpperCase()),
              footer: Text(l10n.chargeBalanceHint(
                  _formatService.formatCurrency(widget.remainingBalance))),
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: CupertinoTextField(
                    key: const Key('chargeValueField'),
                    controller: _valueController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      CurrencyTextInputFormatter.currency(
                        locale: 'pt_BR',
                        symbol: 'R\$',
                        decimalDigits: 2,
                      ),
                    ],
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                    decoration: fieldDecoration,
                  ),
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              footer: Text(_mode == ChargeMode.single
                  ? l10n.chargeSingleHint
                  : l10n.chargeInstallmentsHint),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: CupertinoSlidingSegmentedControl<ChargeMode>(
                      groupValue: _mode,
                      onValueChanged: (mode) {
                        if (mode != null) setState(() => _mode = mode);
                      },
                      children: {
                        ChargeMode.single: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(l10n.chargeModeSingle),
                        ),
                        ChargeMode.cardInstallments: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(l10n.chargeModeInstallments),
                        ),
                      },
                    ),
                  ),
                ),
                if (_mode == ChargeMode.cardInstallments)
                  CupertinoListTile(
                    key: const Key('chargeInstallmentsTile'),
                    title: Text(l10n.chargeInstallments),
                    additionalInfo: Text(l10n.chargeInstallmentOption(
                      _installmentCount,
                      _formatService.formatCurrency(value / _installmentCount),
                    )),
                    trailing: const CupertinoListTileChevron(),
                    onTap: _pickInstallments,
                  ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              children: [
                CupertinoListTile(
                  key: const Key('chargeDueDateTile'),
                  title: Text(l10n.chargeDueDate),
                  additionalInfo: Text(_formatService.formatDate(_dueDate)),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _pickDueDate,
                ),
              ],
            ),
            if (_needsTaxId)
              CupertinoListSection.insetGrouped(
                header: Text(l10n.cpfCnpj.toUpperCase()),
                footer: Text(l10n.chargeTaxIdHint),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: CupertinoTextField(
                      key: const Key('chargeTaxIdField'),
                      controller: _taxIdController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [taxIdInputMask()],
                      placeholder: l10n.cpfCnpj,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: fieldDecoration,
                    ),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  key: const Key('generateChargeButton'),
                  onPressed: (_submitting || _loadingTaxId) ? null : _submit,
                  child: _submitting
                      ? const CupertinoActivityIndicator(
                          color: CupertinoColors.white)
                      : Text(l10n.chargeGenerate),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Rodar os testes**

```bash
fvm flutter test test/screens/payments/create_charge_screen_test.dart
fvm flutter analyze lib/screens/payments
```

Esperado: 16 testes PASS; `No issues found!`.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/payments/create_charge_screen.dart \
  test/screens/payments/create_charge_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(payments): add create charge screen (one-time or card installments)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task D8: Card "Cobrança" (`order_charge_card.dart`)

**Files:**
- Create: `lib/screens/payments/widgets/order_charge_card.dart`
- Test: `test/screens/payments/order_charge_card_test.dart`

**Interfaces:**
- Consumes: `OrderCharge`, `ChargeStatus`, `ChargeMode` (D1), `OrderChargeRepository.watch` (D2), `AsaasApiService.cancelCharge`, `AsaasApiException` (D3), `asaasErrorText` (D4), `ShareLinkSheet.show(BuildContext, Order)` (`lib/screens/widgets/share_link_sheet.dart`), `Clipboard`, `FormatService`.
- Produces: `Color chargeStatusColor(ChargeStatus? status)`, `String chargeStatusLabel(AppLocalizations l10n, ChargeStatus? status)`, `class OrderChargeCard extends StatefulWidget({required Order order, required double remainingBalance, required bool canCreateCharge, required VoidCallback onCreateCharge, Stream<List<OrderCharge>>? chargesStream, AsaasApiService? service})`.

O card escuta `charges` e mostra a cobrança atual (`OrderCharge.current`): dot de status (azul pendente, vermelho vencida, verde paga, cinza cancelada/estornada), valor, vencimento e, se parcelada, "Nx no cartão". Ações: "Compartilhar link da OS" (reusa `ShareLinkSheet`), "Copiar link da fatura" (`Clipboard`), "Cancelar cobrança" (com `CupertinoAlertDialog`). Também contém o botão "Cobrar com Asaas" (`canCreateCharge && remainingBalance > 0`); com cobrança em aberto, pede confirmação porque gerar outra cancela a anterior. Se a cobrança em aberto tem valor diferente do saldo, mostra o aviso de total alterado com "Gerar nova cobrança". Erro de leitura do stream (ex.: regra negou) é tratado como lista vazia.

- [ ] **Step 1: Escrever o teste que falha**

`test/screens/payments/order_charge_card_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/l10n/app_localizations_pt.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/screens/payments/widgets/order_charge_card.dart';
import 'package:praticos/services/asaas_api_service.dart';
import 'package:praticos/services/format_service.dart';

void main() {
  final l10n = AppLocalizationsPt();
  final format = FormatService();

  final order = Order()
    ..id = 'o1'
    ..number = 42
    ..total = 1000
    ..paidAmount = 0;

  OrderCharge charge({
    ChargeStatus status = ChargeStatus.pending,
    double value = 1000,
    ChargeMode mode = ChargeMode.single,
    int? installmentCount,
  }) =>
      OrderCharge(
        id: 'ch1',
        status: status,
        value: value,
        mode: mode,
        installmentCount: installmentCount,
        dueDate: '2026-10-07',
        invoiceUrl: 'https://sandbox.asaas.com/i/abc',
      );

  AsaasApiService service(MockClientHandler handler) =>
      AsaasApiService.withClient(
        MockClient(handler),
        headersProvider: () async => {'Authorization': 'Bearer t'},
      );

  final unusedService = service((_) async => http.Response('{}', 500));

  Future<void> pumpCard(
    WidgetTester tester, {
    required List<OrderCharge> charges,
    double remaining = 1000,
    bool canCreate = true,
    VoidCallback? onCreate,
    AsaasApiService? api,
  }) async {
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CupertinoPageScaffold(
          child: ListView(
            children: [
              OrderChargeCard(
                order: order,
                remainingBalance: remaining,
                canCreateCharge: canCreate,
                onCreateCharge: onCreate ?? () {},
                chargesStream: Stream.value(charges),
                service: api ?? unusedService,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  int dotColor(WidgetTester tester) {
    final dot =
        tester.widget<Container>(find.byKey(const Key('chargeStatusDot')));
    return (dot.decoration as BoxDecoration).color!.toARGB32();
  }

  group('chargeStatusColor', () {
    test('azul pendente, vermelho vencida, verde paga, cinza encerrada', () {
      expect(chargeStatusColor(ChargeStatus.pending), CupertinoColors.systemBlue);
      expect(chargeStatusColor(ChargeStatus.overdue), CupertinoColors.systemRed);
      expect(chargeStatusColor(ChargeStatus.paid), CupertinoColors.systemGreen);
      expect(chargeStatusColor(ChargeStatus.canceled), CupertinoColors.systemGrey);
      expect(chargeStatusColor(ChargeStatus.refunded), CupertinoColors.systemGrey);
      expect(chargeStatusColor(null), CupertinoColors.systemGrey);
    });
  });

  group('OrderChargeCard', () {
    testWidgets('sem cobrança mostra só o botão Cobrar', (tester) async {
      var created = 0;
      await pumpCard(tester, charges: const [], onCreate: () => created++);

      expect(find.byKey(const Key('chargeStatusTile')), findsNothing);
      await tester.tap(find.text(l10n.chargeWithAsaas));
      await tester.pumpAndSettle();

      expect(created, 1);
    });

    testWidgets('sem cobrança e sem permissão não mostra nada', (tester) async {
      await pumpCard(tester, charges: const [], canCreate: false);

      expect(find.byType(CupertinoListSection), findsNothing);
    });

    testWidgets('saldo zero esconde o botão Cobrar', (tester) async {
      await pumpCard(tester,
          charges: [charge(status: ChargeStatus.paid)], remaining: 0);

      expect(find.text(l10n.chargeWithAsaas), findsNothing);
    });

    testWidgets('pendente: dot azul, valor, vencimento e ações',
        (tester) async {
      await pumpCard(tester, charges: [charge()]);

      expect(find.text(l10n.chargeStatusPending), findsOneWidget);
      expect(dotColor(tester), CupertinoColors.systemBlue.color.toARGB32());
      expect(find.text(format.formatCurrency(1000)), findsOneWidget);
      expect(
        find.text(l10n.chargeDueOn(format.formatDate(DateTime(2026, 10, 7)))),
        findsOneWidget,
      );
      expect(find.text(l10n.chargeShareOrderLink), findsOneWidget);
      expect(find.text(l10n.chargeCopyInvoiceLink), findsOneWidget);
      expect(find.byKey(const Key('chargeCancelTile')), findsOneWidget);
      expect(find.byKey(const Key('chargeBalanceWarning')), findsNothing);
    });

    testWidgets('parcelada mostra Nx no cartão', (tester) async {
      await pumpCard(tester,
          charges: [
            charge(mode: ChargeMode.cardInstallments, installmentCount: 3),
          ]);

      expect(find.textContaining(l10n.chargeInstallmentsSummary(3)),
          findsOneWidget);
    });

    testWidgets('vencida: dot vermelho', (tester) async {
      await pumpCard(tester, charges: [charge(status: ChargeStatus.overdue)]);

      expect(find.text(l10n.chargeStatusOverdue), findsOneWidget);
      expect(dotColor(tester), CupertinoColors.systemRed.color.toARGB32());
    });

    testWidgets('paga: dot verde e sem cancelar', (tester) async {
      await pumpCard(tester,
          charges: [charge(status: ChargeStatus.paid)], remaining: 0);

      expect(find.text(l10n.chargeStatusPaid), findsOneWidget);
      expect(dotColor(tester), CupertinoColors.systemGreen.color.toARGB32());
      expect(find.byKey(const Key('chargeCancelTile')), findsNothing);
      expect(find.text(l10n.chargeCopyInvoiceLink), findsOneWidget);
    });

    testWidgets('cancelada: sem ações', (tester) async {
      await pumpCard(tester, charges: [charge(status: ChargeStatus.canceled)]);

      expect(find.text(l10n.chargeStatusCanceled), findsOneWidget);
      expect(find.text(l10n.chargeShareOrderLink), findsNothing);
      expect(find.byKey(const Key('chargeCancelTile')), findsNothing);
    });

    testWidgets('saldo diferente mostra aviso e oferece regerar',
        (tester) async {
      var created = 0;
      await pumpCard(tester,
          charges: [charge(value: 1000)],
          remaining: 1200,
          onCreate: () => created++);

      expect(
        find.text(l10n.chargeTotalChanged(
            format.formatCurrency(1200), format.formatCurrency(1000))),
        findsOneWidget,
      );
      await tester.tap(find.text(l10n.chargeRegenerate));
      await tester.pumpAndSettle();

      expect(created, 1);
    });

    testWidgets('Cobrar com cobrança aberta pede confirmação', (tester) async {
      var created = 0;
      await pumpCard(tester, charges: [charge()], onCreate: () => created++);

      await tester.tap(find.text(l10n.chargeWithAsaas));
      await tester.pumpAndSettle();
      expect(find.text(l10n.chargeReplaceTitle), findsOneWidget);
      expect(created, 0);

      await tester.tap(find.byKey(const Key('confirmReplaceChargeAction')));
      await tester.pumpAndSettle();
      expect(created, 1);
    });

    testWidgets('copia o link da fatura', (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await pumpCard(tester, charges: [charge()]);
      await tester.tap(find.text(l10n.chargeCopyInvoiceLink));
      await tester.pumpAndSettle();

      expect(copied, ['https://sandbox.asaas.com/i/abc']);
      expect(find.text(l10n.chargeInvoiceLinkCopied), findsOneWidget);
    });

    testWidgets('cancela a cobrança após confirmar', (tester) async {
      var deleted = false;
      await pumpCard(tester,
          charges: [charge()],
          api: service((request) async {
            expect(request.method, 'DELETE');
            expect(request.url.path, endsWith('/v1/app/orders/o1/charges/ch1'));
            deleted = true;
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {'id': 'ch1', 'status': 'canceled'},
              }),
              200,
            );
          }));

      await tester.tap(find.byKey(const Key('chargeCancelTile')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.chargeCancelConfirm), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirmCancelChargeAction')));
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
    });

    testWidgets('Manter no diálogo não cancela', (tester) async {
      var calls = 0;
      await pumpCard(tester,
          charges: [charge()],
          api: service((_) async {
            calls++;
            return http.Response('{}', 200);
          }));

      await tester.tap(find.byKey(const Key('chargeCancelTile')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.chargeKeep));
      await tester.pumpAndSettle();

      expect(calls, 0);
    });
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
fvm flutter test test/screens/payments/order_charge_card_test.dart
```

Esperado: FAIL de compilação — `Error when reading 'lib/screens/payments/widgets/order_charge_card.dart': No such file or directory`.

- [ ] **Step 3: Implementar**

`lib/screens/payments/widgets/order_charge_card.dart`:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/l10n/app_localizations.dart';
import 'package:praticos/models/order.dart';
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/repositories/tenant/order_charge_repository.dart';
import 'package:praticos/screens/payments/asaas_error_text.dart';
import 'package:praticos/screens/widgets/share_link_sheet.dart';
import 'package:praticos/services/asaas_api_service.dart';
import 'package:praticos/services/format_service.dart';

/// Status dot color: blue pending, red overdue, green paid, grey closed.
Color chargeStatusColor(ChargeStatus? status) {
  switch (status) {
    case ChargeStatus.pending:
      return CupertinoColors.systemBlue;
    case ChargeStatus.overdue:
      return CupertinoColors.systemRed;
    case ChargeStatus.paid:
      return CupertinoColors.systemGreen;
    case ChargeStatus.canceled:
    case ChargeStatus.refunded:
    case null:
      return CupertinoColors.systemGrey;
  }
}

String chargeStatusLabel(AppLocalizations l10n, ChargeStatus? status) {
  switch (status) {
    case ChargeStatus.pending:
    case null:
      return l10n.chargeStatusPending;
    case ChargeStatus.overdue:
      return l10n.chargeStatusOverdue;
    case ChargeStatus.paid:
      return l10n.chargeStatusPaid;
    case ChargeStatus.canceled:
      return l10n.chargeStatusCanceled;
    case ChargeStatus.refunded:
      return l10n.chargeStatusRefunded;
  }
}

/// "Charge" card of an order: current Asaas charge, its actions and the
/// "Charge with Asaas" button.
///
/// Only build it for users with `PermissionType.chargeOrder`: Firestore rules
/// deny reading `charges` to other roles.
class OrderChargeCard extends StatefulWidget {
  const OrderChargeCard({
    super.key,
    required this.order,
    required this.remainingBalance,
    required this.canCreateCharge,
    required this.onCreateCharge,
    this.chargesStream,
    this.service,
  });

  final Order order;
  final double remainingBalance;

  /// Account connected and user allowed to charge.
  final bool canCreateCharge;

  /// Opens the create charge screen.
  final VoidCallback onCreateCharge;

  /// Test seam; defaults to [OrderChargeRepository.watch].
  final Stream<List<OrderCharge>>? chargesStream;

  /// Test seam; defaults to [AsaasApiService.instance].
  final AsaasApiService? service;

  @override
  State<OrderChargeCard> createState() => _OrderChargeCardState();
}

class _OrderChargeCardState extends State<OrderChargeCard> {
  final _formatService = FormatService();
  late final Stream<List<OrderCharge>> _charges;
  bool _canceling = false;

  AsaasApiService get _service => widget.service ?? AsaasApiService.instance;

  bool get _showCreateButton =>
      widget.canCreateCharge && widget.remainingBalance > 0;

  @override
  void initState() {
    super.initState();
    _charges = widget.chargesStream ?? _watchCharges();
  }

  Stream<List<OrderCharge>> _watchCharges() {
    final companyId = widget.order.company?.id ?? Global.companyAggr?.id;
    final orderId = widget.order.id;
    if (companyId == null || orderId == null) {
      return Stream.value(const <OrderCharge>[]);
    }
    return OrderChargeRepository().watch(companyId, orderId);
  }

  @override
  Widget build(BuildContext context) {
    _formatService.setLocale(Localizations.localeOf(context).toString());
    return StreamBuilder<List<OrderCharge>>(
      stream: _charges,
      builder: (context, snapshot) {
        final charge = OrderCharge.current(snapshot.data ?? const []);
        if (charge == null && !_showCreateButton) {
          return const SizedBox.shrink();
        }
        return CupertinoListSection.insetGrouped(
          header: Text(context.l10n.chargeSectionTitle.toUpperCase()),
          children: [
            if (charge != null) ..._buildChargeRows(context, charge),
            if (_showCreateButton) _buildCreateTile(context, charge),
          ],
        );
      },
    );
  }

  List<Widget> _buildChargeRows(BuildContext context, OrderCharge charge) {
    final l10n = context.l10n;
    final value = charge.value ?? 0;
    final balanceDiffers =
        charge.isOpen && (value - widget.remainingBalance).abs() >= 0.01;
    final canShare = charge.isOpen || charge.status == ChargeStatus.paid;
    final hasInvoice = (charge.invoiceUrl ?? '').isNotEmpty;

    return [
      CupertinoListTile(
        key: const Key('chargeStatusTile'),
        leading: Center(
          child: Container(
            key: const Key('chargeStatusDot'),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: CupertinoDynamicColor.resolve(
                  chargeStatusColor(charge.status), context),
              shape: BoxShape.circle,
            ),
          ),
        ),
        title: Text(chargeStatusLabel(l10n, charge.status)),
        subtitle: Text(_subtitle(l10n, charge)),
        additionalInfo: Text(_formatService.formatCurrency(value)),
      ),
      if (balanceDiffers) _buildBalanceWarning(context, charge),
      if (canShare)
        CupertinoListTile(
          key: const Key('chargeShareTile'),
          leading: const Icon(CupertinoIcons.square_arrow_up),
          title: Text(l10n.chargeShareOrderLink),
          onTap: () => ShareLinkSheet.show(context, widget.order),
        ),
      if (canShare && hasInvoice)
        CupertinoListTile(
          key: const Key('chargeCopyInvoiceTile'),
          leading: const Icon(CupertinoIcons.doc_on_doc),
          title: Text(l10n.chargeCopyInvoiceLink),
          onTap: () => _copyInvoice(charge),
        ),
      if (charge.isOpen)
        CupertinoListTile(
          key: const Key('chargeCancelTile'),
          leading: const Icon(
            CupertinoIcons.xmark_circle,
            color: CupertinoColors.systemRed,
          ),
          title: Text(
            l10n.chargeCancel,
            style: const TextStyle(color: CupertinoColors.systemRed),
          ),
          trailing: _canceling ? const CupertinoActivityIndicator() : null,
          onTap: _canceling ? null : () => _confirmCancel(charge),
        ),
    ];
  }

  String _subtitle(AppLocalizations l10n, OrderCharge charge) {
    final due = l10n.chargeDueOn(_formatService.formatDate(charge.dueDateValue));
    if (charge.mode == ChargeMode.cardInstallments &&
        charge.installmentCount != null) {
      return '${l10n.chargeInstallmentsSummary(charge.installmentCount!)} · $due';
    }
    return due;
  }

  Widget _buildBalanceWarning(BuildContext context, OrderCharge charge) {
    final l10n = context.l10n;
    return Padding(
      key: const Key('chargeBalanceWarning'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_triangle_fill,
                color: CupertinoColors.systemOrange,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.chargeTotalChanged(
                    _formatService.formatCurrency(widget.remainingBalance),
                    _formatService.formatCurrency(charge.value ?? 0),
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ),
            ],
          ),
          if (_showCreateButton)
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(
                padding: const EdgeInsets.only(top: 6),
                minimumSize: Size.zero,
                onPressed: widget.onCreateCharge,
                child: Text(
                  l10n.chargeRegenerate,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCreateTile(BuildContext context, OrderCharge? current) {
    final primary = CupertinoTheme.of(context).primaryColor;
    return CupertinoListTile(
      key: const Key('createChargeTile'),
      leading: Icon(CupertinoIcons.creditcard, color: primary),
      title: Text(
        context.l10n.chargeWithAsaas,
        style: TextStyle(color: primary),
      ),
      trailing: const CupertinoListTileChevron(),
      onTap: () => _onCreatePressed(current),
    );
  }

  Future<void> _onCreatePressed(OrderCharge? current) async {
    if (current == null || !current.isOpen) {
      widget.onCreateCharge();
      return;
    }
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(dialogContext.l10n.chargeReplaceTitle),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(dialogContext.l10n.chargeReplaceConfirm),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.cancel),
          ),
          CupertinoDialogAction(
            key: const Key('confirmReplaceChargeAction'),
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.chargeReplace),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onCreateCharge();
  }

  Future<void> _copyInvoice(OrderCharge charge) async {
    await Clipboard.setData(ClipboardData(text: charge.invoiceUrl!));
    if (!mounted) return;
    _showMessage(context.l10n.chargeInvoiceLinkCopied);
  }

  Future<void> _confirmCancel(OrderCharge charge) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(dialogContext.l10n.chargeCancel),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(dialogContext.l10n.chargeCancelConfirm),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.chargeKeep),
          ),
          CupertinoDialogAction(
            key: const Key('confirmCancelChargeAction'),
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.chargeCancel),
          ),
        ],
      ),
    );
    if (confirmed != true || charge.id == null || widget.order.id == null) {
      return;
    }
    if (!mounted) return;

    setState(() => _canceling = true);
    try {
      await _service.cancelCharge(widget.order.id!, charge.id!);
    } on AsaasApiException catch (e) {
      if (mounted) _showMessage(asaasErrorText(context.l10n, e));
    } finally {
      if (mounted) setState(() => _canceling = false);
    }
  }

  void _showMessage(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(dialogContext.l10n.ok),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Rodar os testes**

```bash
fvm flutter test test/screens/payments/order_charge_card_test.dart
fvm flutter analyze lib/screens/payments
```

Esperado: 14 testes PASS; `No issues found!`.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/payments/widgets/order_charge_card.dart \
  test/screens/payments/order_charge_card_test.dart
git commit -m "$(cat <<'EOF'
feat(payments): add order charge card with share, copy and cancel actions

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task D9: Integração na tela de pagamentos da OS

**Files:**
- Create: `lib/screens/payments/widgets/payment_transaction_icon.dart`
- Modify: `lib/screens/payment_management_screen.dart` — imports (linhas 1-17), campos de estado (linhas 31-43), `didChangeDependencies` (linhas 46-57), lista do `build` (linhas 90-97), nova seção depois de `_buildFormOrPaidSection` (linha 235), ícone e `confirmDismiss` em `_buildTransactionRow` (linhas 633-677), `_confirmResetPayment` (linha 898). Os números são da `master` atual; se o Bloco A deslocou linhas, localize pelos trechos citados.
- Test: `test/screens/payments/payment_transaction_icon_test.dart`

**Interfaces:**
- Consumes: `PaymentTransaction.isAsaas`, `PaymentSettings` (D1), `PaymentSettingsRepository.watch` (D2), `CreateChargeScreen` (D7), `OrderChargeCard` (D8), `PermissionType.chargeOrder` (Bloco A), `OrderStore.companyId`, `OrderStore.remainingBalance`, `OrderStore.order`.
- Produces: `class PaymentTransactionIcon extends StatelessWidget({required PaymentTransaction transaction})`; seção "Cobrança" na tela de pagamentos.

Regras: a seção só existe para quem tem `chargeOrder`, com `asaasEnabled`, e com a OS fora de `quote`/`canceled` (mesma regra dos pagamentos manuais). O botão "Cobrar" exige `asaasConnected`; o card continua mostrando a cobrança existente mesmo se a conta for desconectada. Transações `asaas_*` ganham ícone de cartão e não podem ser removidas (swipe nem "Marcar a receber"): a mensagem orienta estornar no Asaas.

- [ ] **Step 1: Escrever o teste que falha**

`test/screens/payments/payment_transaction_icon_test.dart`:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/models/payment_transaction.dart';
import 'package:praticos/screens/payments/widgets/payment_transaction_icon.dart';

void main() {
  Future<void> pumpIcon(WidgetTester tester, PaymentTransaction txn) async {
    await tester.pumpWidget(
      CupertinoApp(home: Center(child: PaymentTransactionIcon(transaction: txn))),
    );
  }

  group('PaymentTransactionIcon', () {
    testWidgets('transação Asaas usa ícone de cartão', (tester) async {
      await pumpIcon(
        tester,
        PaymentTransaction(
          id: 'asaas_pay_1',
          type: PaymentTransactionType.payment,
          amount: 100,
        ),
      );

      expect(find.byIcon(CupertinoIcons.creditcard_fill), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.arrow_down_circle), findsNothing);
    });

    testWidgets('pagamento manual mantém a seta', (tester) async {
      await pumpIcon(
        tester,
        PaymentTransaction(
          id: '1728000000000',
          type: PaymentTransactionType.payment,
          amount: 100,
        ),
      );

      expect(find.byIcon(CupertinoIcons.arrow_down_circle), findsOneWidget);
    });

    testWidgets('desconto mantém a etiqueta', (tester) async {
      await pumpIcon(
        tester,
        PaymentTransaction(type: PaymentTransactionType.discount, amount: 10),
      );

      expect(find.byIcon(CupertinoIcons.tag), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
fvm flutter test test/screens/payments/payment_transaction_icon_test.dart
```

Esperado: FAIL de compilação — `Error when reading 'lib/screens/payments/widgets/payment_transaction_icon.dart': No such file or directory`.

- [ ] **Step 3: Implementar o ícone**

`lib/screens/payments/widgets/payment_transaction_icon.dart`:

```dart
import 'package:flutter/cupertino.dart';
import 'package:praticos/models/payment_transaction.dart';

/// Leading icon of a payment history row. Asaas payments get a card icon so
/// they stand out from manual payments.
class PaymentTransactionIcon extends StatelessWidget {
  const PaymentTransactionIcon({super.key, required this.transaction});

  final PaymentTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final isPayment = transaction.type == PaymentTransactionType.payment;
    final Color color;
    final IconData icon;
    if (transaction.isAsaas) {
      color = CupertinoColors.systemIndigo;
      icon = CupertinoIcons.creditcard_fill;
    } else if (isPayment) {
      color = CupertinoColors.systemGreen;
      icon = CupertinoIcons.arrow_down_circle;
    } else {
      color = CupertinoColors.systemOrange;
      icon = CupertinoIcons.tag;
    }
    final resolved = CupertinoDynamicColor.resolve(color, context);

    return Container(
      key: const Key('paymentTransactionIcon'),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: resolved, size: 20),
    );
  }
}
```

- [ ] **Step 4: Ligar na tela de pagamentos**

Em `lib/screens/payment_management_screen.dart`:

1. Imports (junto aos existentes, linhas 7-17):

```dart
import 'package:praticos/models/order_charge.dart';
import 'package:praticos/models/payment_settings.dart';
import 'package:praticos/repositories/tenant/payment_settings_repository.dart';
import 'package:praticos/screens/payments/create_charge_screen.dart';
import 'package:praticos/screens/payments/widgets/order_charge_card.dart';
import 'package:praticos/screens/payments/widgets/payment_transaction_icon.dart';
```

2. Campo de estado, logo depois de `String? _receiptFileName;` (linha 43):

```dart

  // Asaas: null when the user cannot charge (no chargeOrder permission)
  Stream<PaymentSettings>? _paymentSettingsStream;
```

3. Em `didChangeDependencies`, dentro do `if (args != null && args.containsKey('orderStore'))`, logo depois de `_prefillValue();` (linha 53):

```dart
        final companyId = _store?.companyId;
        if (companyId != null &&
            AuthorizationService.instance
                .hasPermission(PermissionType.chargeOrder)) {
          _paymentSettingsStream =
              PaymentSettingsRepository().watch(companyId);
        }
```

4. Na lista do `build`, trocar

```dart
                  _buildFormOrPaidSection(),
                  const SizedBox(height: 20),
                  _buildHistorySection(),
```

por

```dart
                  _buildFormOrPaidSection(),
                  _buildAsaasChargeSection(),
                  const SizedBox(height: 20),
                  _buildHistorySection(),
```

5. Logo depois do método `_buildFormOrPaidSection()` (termina na linha 235), adicionar:

```dart

  // ============================================================
  // ASAAS CHARGE SECTION
  // ============================================================

  Widget _buildAsaasChargeSection() {
    final settingsStream = _paymentSettingsStream;
    final order = _store?.order;
    if (settingsStream == null || order?.id == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<PaymentSettings>(
      stream: settingsStream,
      builder: (context, snapshot) {
        final settings = snapshot.data;
        if (settings == null || !settings.asaasEnabled) {
          return const SizedBox.shrink();
        }
        return Observer(
          builder: (_) {
            final status = _store?.status;
            if (status == 'quote' || status == 'canceled') {
              return const SizedBox.shrink();
            }
            final remaining = _store?.remainingBalance ?? 0.0;
            return OrderChargeCard(
              order: order!,
              remainingBalance: remaining,
              canCreateCharge: settings.asaasConnected,
              onCreateCharge: () => _openCreateCharge(remaining),
            );
          },
        );
      },
    );
  }

  Future<void> _openCreateCharge(double remaining) async {
    final order = _store?.order;
    if (order?.id == null) return;

    final charge = await Navigator.of(context).push<OrderCharge>(
      CupertinoPageRoute(
        builder: (_) => CreateChargeScreen(
          order: order!,
          remainingBalance: remaining,
        ),
      ),
    );
    if (charge != null && mounted) {
      _showSuccess(context.l10n.chargeCreated);
    }
  }
```

6. Em `_buildTransactionRow`, trocar o `confirmDismiss`

```dart
      confirmDismiss: (direction) async {
        _confirmDeleteTransaction(index, transaction);
        return false;
      },
```

por

```dart
      confirmDismiss: (direction) async {
        // Asaas payments are undone only by a refund in Asaas
        if (transaction.isAsaas) {
          _showError(context.l10n.asaasTransactionCannotRemove);
          return false;
        }
        _confirmDeleteTransaction(index, transaction);
        return false;
      },
```

e trocar o bloco do ícone (o `Container` de 40x40 que começa em `// Icon container` e termina no `),` depois do `Icon(... size: 20,)`) por:

```dart
                  // Icon container
                  PaymentTransactionIcon(transaction: transaction),
```

7. No início de `_confirmResetPayment()` (linha 898), antes de `showCupertinoDialog(`:

```dart
    if (_store?.transactions.any((t) => t.isAsaas) ?? false) {
      _showError(context.l10n.asaasTransactionCannotRemove);
      return;
    }
```

- [ ] **Step 5: Rodar os testes e a análise**

```bash
fvm flutter test test/screens/payments/
fvm flutter analyze
```

Esperado: todos os testes de `test/screens/payments/` PASS (incluindo os 3 novos); `No issues found!`.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/payments/widgets/payment_transaction_icon.dart \
  lib/screens/payment_management_screen.dart \
  test/screens/payments/payment_transaction_icon_test.dart
git commit -m "$(cat <<'EOF'
feat(payments): show Asaas charge card and protect Asaas payments in the order

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task D10: Abrir o PR

**Files:** nenhum.

**Interfaces:** nenhuma.

- [ ] **Step 1: Verificação completa**

```bash
fvm flutter pub run build_runner build --delete-conflicting-outputs
fvm flutter gen-l10n
git status --porcelain
fvm flutter analyze
fvm flutter test
```

Esperado: `git status --porcelain` vazio (código gerado já commitado); `No issues found!`; todos os testes PASS.

- [ ] **Step 2: Push e PR**

```bash
git push -u origin feat/asaas-app
gh pr create --base master --head feat/asaas-app \
  --title "feat(payments): cobrança Asaas no app" \
  --label risk:high \
  --body "$(cat <<'EOF'
Refs #303

## O que muda

- **Integrações > Pagamentos > Asaas** (dono/admin, só com `asaasEnabled`): instruções, link para o painel do Asaas (produção e sandbox), campo oculto para a chave e "Conectar". Conectado: nome da conta, ambiente (Teste/Produção) e "Desconectar" com confirmação. A chave vai direto para o servidor e é apagada do campo.
- **Tela de pagamentos da OS**: card "Cobrança" com a cobrança atual (dot azul pendente, vermelho vencida, verde paga), valor, vencimento e ações "Compartilhar link da OS", "Copiar link da fatura" e "Cancelar cobrança". Botão "Cobrar com Asaas" para quem tem `chargeOrder`, com conta conectada e saldo > 0. Aviso quando o saldo da OS difere da cobrança em aberto, com opção de gerar outra.
- **Nova cobrança**: valor (padrão = saldo), À vista / Parcelado no cartão (2–12x com valor da parcela), vencimento (padrão hoje + 3 dias) e CPF/CNPJ quando o cliente não tem.
- Pagamentos do Asaas com ícone próprio no histórico; não podem ser removidos nem zerados no app (orienta estornar no Asaas).
- **Cliente**: campo CPF/CNPJ com máscara e validação de dígitos.
- `AsaasApiService` (singleton + `withClient`), modelos `OrderCharge` e `PaymentSettings`, repositórios só leitura, strings pt/en/es.

## Dependências

- Bloco A (`fix/payments-foundation`) já na master: `appApiHeaders`, `PermissionType.chargeOrder`, `Customer.taxId`, `lib/utils/tax_id.dart`.
- Em tempo de execução: rotas do Bloco B e regras/webhook do Bloco C. Documentação no Bloco F.

## Como testar

```bash
fvm flutter analyze
fvm flutter test
```

Manual (simulador, debug com ngrok, empresa com `asaasEnabled=true`): conectar a chave do sandbox, gerar cobrança numa OS aprovada (à vista e parcelada), copiar o link da fatura, cancelar, conferir o aviso ao mudar o total da OS.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Esperado: URL do PR impressa.
## Bloco E — Botão "Pagar" no link da OS

> Contract note: o contrato manda pôr o botão em `OrderTotalSection.vue`, mas esse componente **não é usado** em nenhuma página (`grep -rn OrderTotalSection firebase/web/pages firebase/web/components` não acha uso). O total exibido no `/q/{token}` vem de `components/order/OrderSummaryCard.vue`, renderizado nos layouts mobile e desktop de `pages/q/[token].vue`. Por isso o botão vai num componente novo, `OrderChargeAction.vue`, embutido no `OrderSummaryCard`. O campo `charge` fica em `data.charge` (irmão de `data.order`) na resposta de `GET /public/orders/:token`, com o formato exato do contrato. `firebase/web` não tem pasta `types/` (os dados da OS são `any`), então os tipos públicos da cobrança ficam em `firebase/web/utils/charge.ts`. O web também não tem runner de testes: esta task cria `npm test` com `node --test` (Node ≥ 22.18 roda `.ts` direto, sem dependência nova).

**Branch:** `feat/asaas-share-link`, criada a partir da `master` depois do merge dos Blocos A, B e C (este bloco consome `getOpenOrLatestPaidCharge` e `OrderCharge` do Bloco B).
**PR:** `feat(share-link): botão "Pagar" da cobrança Asaas no link da OS`
**Verificação do PR:**

```bash
cd firebase/functions && npm run lint && npm test
cd ../web && npm ci && npm test && npm run build
```

---

### Task E1: `charge` no endpoint público da OS

**Files:**
- Modify: `firebase/functions/src/routes/public/orders.routes.ts` (imports nas linhas 6–15; novo helper antes de `router.get('/:token'` na linha 49; leitura da cobrança depois da linha 68; campo novo depois da linha 153)
- Modify: `docs/SHARE_LINK.md` (exemplo de resposta nas linhas 272–289)
- Test: `firebase/functions/src/routes/public/__tests__/orders.routes.test.ts` (novo; hoje não há teste das rotas públicas)

**Interfaces:**
- Consumes: `getOpenOrLatestPaidCharge(companyId: string, orderId: string): Promise<OrderCharge | null>` de `src/services/asaas/charge.service.ts`; `OrderCharge`, `ChargeStatus` de `src/models/asaas.types.ts`.
- Produces: `GET /public/orders/:token` → `data.charge: { status, value, dueDate, mode, installmentCount?, invoiceUrl } | null`. Só `pending`, `overdue` e `paid` aparecem; `canceled`/`refunded` viram `null`. Falha ao ler a cobrança não derruba a página (devolve `null`).

- [ ] **Step 1: Escrever o teste que falha**

Criar `firebase/functions/src/routes/public/__tests__/orders.routes.test.ts`:

```ts
import express from 'express';
import request from 'supertest';

// ---- Mocks ----------------------------------------------------------------

jest.mock('../../../middleware/share-token.middleware', () => ({
  shareTokenAuth: (req: any, _res: any, next: any) => {
    req.shareTokenAuth = {
      type: 'shareToken',
      token: req.params.token,
      companyId: 'comp1',
      orderId: 'ord1',
      permissions: ['view'],
      customer: { id: 'cust1', name: 'Alice Souza', phone: '+5511999998888' },
    };
    next();
  },
  requireSharePermission: () => (_req: any, _res: any, next: any) => next(),
}));

jest.mock('../../../services/firestore.service', () => ({
  db: {
    collection: jest.fn(() => ({
      doc: jest.fn(() => ({
        get: jest.fn().mockResolvedValue({
          exists: true,
          data: () => ({ name: 'Oficina Teste', country: 'BR' }),
        }),
      })),
    })),
  },
  getTenantCollection: jest.fn(),
}));

jest.mock('../../../services/share-token.service', () => ({}));
jest.mock('../../../services/notification.service', () => ({}));
jest.mock('../../../services/comment.service', () => ({
  getCustomerVisibleComments: jest.fn().mockResolvedValue([]),
}));
jest.mock('../../../services/order.service', () => ({
  getOrder: jest.fn(),
  calculateRemainingBalance: jest.fn(() => 100),
}));
jest.mock('../../../services/asaas/charge.service', () => ({
  getOpenOrLatestPaidCharge: jest.fn(),
}));

import * as orderService from '../../../services/order.service';
import * as chargeService from '../../../services/asaas/charge.service';
import { OrderCharge } from '../../../models/asaas.types';
import router from '../orders.routes';

const mockGetOrder = orderService.getOrder as jest.Mock;
const mockGetCharge = chargeService.getOpenOrLatestPaidCharge as jest.Mock;

// ---- Fixtures --------------------------------------------------------------

const fakeOrder = {
  id: 'ord1',
  number: 42,
  status: 'done',
  customer: { id: 'cust1', name: 'Alice Souza' },
  services: [],
  products: [],
  total: 100,
  discount: 0,
  paidAmount: 0,
  company: { id: 'comp1', name: 'Oficina Teste' },
  createdAt: '2026-10-01T10:00:00.000Z',
};

function makeCharge(overrides: Partial<OrderCharge> = {}): OrderCharge {
  return {
    id: 'chg1',
    asaasPaymentId: 'pay_123',
    mode: 'single',
    value: 100,
    dueDate: '2026-10-07',
    status: 'pending',
    invoiceUrl: 'https://sandbox.asaas.com/i/abc123',
    paidAsaasPaymentIds: [],
    createdBy: { id: 'user1', name: 'Rafael' },
    createdAt: '2026-10-04T12:00:00.000Z',
    ...overrides,
  };
}

function buildApp() {
  const app = express();
  app.use(express.json());
  app.use('/public/orders', router);
  return app;
}

// ---- Tests -----------------------------------------------------------------

describe('GET /public/orders/:token — charge', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockGetOrder.mockResolvedValue(fakeOrder);
  });

  it('returns charge null when the order has no charge', async () => {
    mockGetCharge.mockResolvedValue(null);

    const res = await request(buildApp()).get('/public/orders/tok123');

    expect(res.status).toBe(200);
    expect(mockGetCharge).toHaveBeenCalledWith('comp1', 'ord1');
    expect(res.body.data.charge).toBeNull();
  });

  it('exposes only the public fields of a pending single charge', async () => {
    mockGetCharge.mockResolvedValue(makeCharge());

    const res = await request(buildApp()).get('/public/orders/tok123');

    expect(res.status).toBe(200);
    expect(res.body.data.charge).toEqual({
      status: 'pending',
      value: 100,
      dueDate: '2026-10-07',
      mode: 'single',
      invoiceUrl: 'https://sandbox.asaas.com/i/abc123',
    });
    const raw = JSON.stringify(res.body);
    expect(raw).not.toContain('pay_123');
    expect(raw).not.toContain('chg1');
    expect(raw).not.toContain('paidAsaasPaymentIds');
  });

  it('includes installmentCount for a paid card-installments charge', async () => {
    mockGetCharge.mockResolvedValue(makeCharge({
      mode: 'cardInstallments',
      installmentCount: 3,
      asaasInstallmentId: 'ins_1',
      status: 'paid',
      paidAt: '2026-10-05T09:00:00.000Z',
      paidAsaasPaymentIds: ['pay_1', 'pay_2', 'pay_3'],
    }));

    const res = await request(buildApp()).get('/public/orders/tok123');

    expect(res.body.data.charge).toEqual({
      status: 'paid',
      value: 100,
      dueDate: '2026-10-07',
      mode: 'cardInstallments',
      installmentCount: 3,
      invoiceUrl: 'https://sandbox.asaas.com/i/abc123',
    });
  });

  it('shows an overdue charge', async () => {
    mockGetCharge.mockResolvedValue(makeCharge({ status: 'overdue' }));

    const res = await request(buildApp()).get('/public/orders/tok123');

    expect(res.body.data.charge.status).toBe('overdue');
  });

  it.each(['canceled', 'refunded'] as const)('hides a %s charge', async (status) => {
    mockGetCharge.mockResolvedValue(makeCharge({ status }));

    const res = await request(buildApp()).get('/public/orders/tok123');

    expect(res.status).toBe(200);
    expect(res.body.data.charge).toBeNull();
  });

  it('returns charge null and still 200 when loading the charge fails', async () => {
    mockGetCharge.mockRejectedValue(new Error('firestore down'));

    const res = await request(buildApp()).get('/public/orders/tok123');

    expect(res.status).toBe(200);
    expect(res.body.data.order.number).toBe(42);
    expect(res.body.data.charge).toBeNull();
  });
});
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
cd firebase/functions && npx jest src/routes/public/__tests__/orders.routes.test.ts
```

Esperado: FAIL. `res.body.data.charge` é `undefined` (`expect(received).toBeNull()` / `toEqual` recebe `undefined`) e `mockGetCharge` nunca é chamado.

- [ ] **Step 3: Implementar**

Em `firebase/functions/src/routes/public/orders.routes.ts`, depois da linha 15 (`import { maskName, maskPhone, maskSerial } ...`), acrescentar:

```ts
import * as chargeService from '../../services/asaas/charge.service';
import { OrderCharge, ChargeStatus } from '../../models/asaas.types';
```

Antes do comentário `/** GET /public/orders/:token` (linha 45), acrescentar:

```ts
/**
 * Charge fields the customer may see on the magic link.
 * Never expose Asaas ids, audit fields or anything about the Asaas account.
 */
interface PublicOrderCharge {
  status: ChargeStatus;
  value: number;
  dueDate: string;
  mode: OrderCharge['mode'];
  installmentCount?: number;
  invoiceUrl: string;
}

const PUBLIC_CHARGE_STATUSES: ChargeStatus[] = ['pending', 'overdue', 'paid'];

function toPublicCharge(charge: OrderCharge | null): PublicOrderCharge | null {
  if (!charge || !PUBLIC_CHARGE_STATUSES.includes(charge.status)) return null;
  return {
    status: charge.status,
    value: charge.value,
    dueDate: charge.dueDate,
    mode: charge.mode,
    ...(charge.installmentCount ? { installmentCount: charge.installmentCount } : {}),
    invoiceUrl: charge.invoiceUrl,
  };
}

/**
 * Load the open (or latest paid) Asaas charge for the magic link.
 * A failure here must not break the order page, so it degrades to null.
 */
async function getPublicCharge(companyId: string, orderId: string): Promise<PublicOrderCharge | null> {
  try {
    return toPublicCharge(await chargeService.getOpenOrLatestPaidCharge(companyId, orderId));
  } catch (error) {
    console.error('Failed to load order charge:', error instanceof Error ? error.message : 'unknown error');
    return null;
  }
}
```

Depois da linha 68 (`const comments = await commentService.getCustomerVisibleComments(companyId, orderId);`), acrescentar:

```ts
    const charge = await getPublicCharge(companyId, orderId);
```

No objeto `data` da resposta, depois da linha 153 (`customer: maskedCustomer,`, a segunda ocorrência, logo após `permissions: req.shareTokenAuth!.permissions,`), acrescentar:

```ts
        charge,
```

Em `docs/SHARE_LINK.md`, no exemplo de resposta de `GET /public/orders/{token}` (linhas 286–288), trocar:

```json
  "comments": [...],
  "permissions": ["view", "approve", "comment"]
}
```

por:

```json
  "comments": [...],
  "permissions": ["view", "approve", "comment"],
  "charge": {
    "status": "pending",
    "value": 150.00,
    "dueDate": "2026-10-07",
    "mode": "single",
    "invoiceUrl": "https://www.asaas.com/i/..."
  }
}
```

E logo depois do bloco ```` ``` ```` que fecha esse exemplo, acrescentar o parágrafo:

```markdown
`charge` é a cobrança Asaas aberta (`pending`/`overdue`) ou a última paga da OS (`getOpenOrLatestPaidCharge`), ou `null`. Só esses campos saem; ids do Asaas e auditoria nunca são expostos. `installmentCount` aparece só em `mode: "cardInstallments"`. Ver `docs/ASAAS_INTEGRATION.md`.
```

- [ ] **Step 4: Rodar e ver passar**

```bash
cd firebase/functions && npx jest src/routes/public/__tests__/orders.routes.test.ts && npm run lint && npm test
```

Esperado: 7 testes PASS no arquivo novo; lint sem erros; suíte toda verde.

- [ ] **Step 5: Commit**

```bash
git add firebase/functions/src/routes/public/orders.routes.ts \
        firebase/functions/src/routes/public/__tests__/orders.routes.test.ts \
        docs/SHARE_LINK.md
git commit -m "$(cat <<'EOF'
feat(share-link): expose open Asaas charge on public order endpoint

GET /public/orders/:token now returns data.charge with only status, value,
dueDate, mode, installmentCount and invoiceUrl. Canceled/refunded charges and
lookup failures return null so the page never breaks.

Refs #303

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task E2: Botão "Pagar", "Cobrança vencida" e "Pago ✓" no `/q/{token}`

**Files:**
- Create: `firebase/web/utils/charge.ts`
- Create: `firebase/web/components/order/OrderChargeAction.vue`
- Create: `firebase/web/tests/charge.test.ts`
- Modify: `firebase/web/package.json` (bloco `scripts`, linhas 4–10)
- Modify: `firebase/web/composables/useOrderI18n.ts` (depois de `termsRequiredError` nas linhas 123, 220 e 317)
- Modify: `firebase/web/components/order/OrderSummaryCard.vue` (linha 28 e script nas linhas 70–76)
- Modify: `firebase/web/pages/q/[token].vue` (linhas 45, 72 e 159–162)
- Test: `firebase/web/tests/charge.test.ts`

**Interfaces:**
- Consumes: `data.charge` de `GET /public/orders/:token` (Task E1), via `useFetch('/api/orders/${token}')` (proxy Nitro em `server/api/orders/[token].get.ts`).
- Produces: `utils/charge.ts` → `PublicOrderCharge`, `getChargeView(charge): ChargeView`, `isSafeInvoiceUrl(url): boolean`, `shouldRefreshCharge(charge): boolean`, `formatChargeDueDate(dueDate, lang): string`; componente `<OrderChargeAction :charge :country>`; prop nova `charge` em `OrderSummaryCard`.

- [ ] **Step 1: Escrever o teste que falha**

Em `firebase/web/package.json`, no bloco `scripts`, acrescentar depois de `"preview": "nuxt preview",`:

```json
    "test": "node --test tests/*.test.ts",
```

Criar `firebase/web/tests/charge.test.ts`:

```ts
import { test } from 'node:test'
import assert from 'node:assert/strict'
import {
  getChargeView,
  formatChargeDueDate,
  shouldRefreshCharge,
  type PublicOrderCharge,
} from '../utils/charge.ts'

const pending: PublicOrderCharge = {
  status: 'pending',
  value: 150.5,
  dueDate: '2026-10-07',
  mode: 'single',
  invoiceUrl: 'https://sandbox.asaas.com/i/abc123',
}

test('pending charge renders the pay button with the invoice url', () => {
  assert.deepEqual(getChargeView(pending), {
    kind: 'pay',
    value: 150.5,
    dueDate: '2026-10-07',
    invoiceUrl: 'https://sandbox.asaas.com/i/abc123',
    installmentCount: null,
  })
})

test('card installments expose the installment count', () => {
  const view = getChargeView({ ...pending, mode: 'cardInstallments', installmentCount: 3 })
  assert.equal(view.kind, 'pay')
  assert.equal(view.kind === 'pay' ? view.installmentCount : 0, 3)
})

test('pending charge with a non-https invoice url renders nothing', () => {
  assert.deepEqual(getChargeView({ ...pending, invoiceUrl: 'javascript:alert(1)' }), { kind: 'none' })
  assert.deepEqual(getChargeView({ ...pending, invoiceUrl: 'http://asaas.com/i/x' }), { kind: 'none' })
})

test('overdue and paid charges render their messages', () => {
  assert.deepEqual(getChargeView({ ...pending, status: 'overdue' }), { kind: 'overdue' })
  assert.deepEqual(getChargeView({ ...pending, status: 'paid' }), { kind: 'paid' })
})

test('missing charge renders nothing', () => {
  assert.deepEqual(getChargeView(null), { kind: 'none' })
  assert.deepEqual(getChargeView(undefined), { kind: 'none' })
})

test('formats the due date per language without timezone shift', () => {
  assert.equal(formatChargeDueDate('2026-10-07', 'pt'), '07/10/2026')
  assert.equal(formatChargeDueDate('2026-10-07', 'en'), '10/07/2026')
  assert.equal(formatChargeDueDate('2026-10-07', 'es'), '07/10/2026')
  assert.equal(formatChargeDueDate('invalid', 'pt'), 'invalid')
})

test('refreshes only while the charge can still change', () => {
  assert.equal(shouldRefreshCharge(pending), true)
  assert.equal(shouldRefreshCharge({ ...pending, status: 'overdue' }), true)
  assert.equal(shouldRefreshCharge({ ...pending, status: 'paid' }), false)
  assert.equal(shouldRefreshCharge(null), false)
})
```

- [ ] **Step 2: Rodar e ver falhar**

```bash
cd firebase/web && npm ci && npm test
```

Esperado: FAIL com `ERR_MODULE_NOT_FOUND` para `utils/charge.ts`.

- [ ] **Step 3: Implementar `utils/charge.ts`**

Criar `firebase/web/utils/charge.ts` (sem imports, para rodar direto no `node --test`):

```ts
export type PublicChargeStatus = 'pending' | 'overdue' | 'paid'
export type PublicChargeMode = 'single' | 'cardInstallments'
export type ChargeLang = 'pt' | 'en' | 'es'

/** Shape of data.charge returned by GET /public/orders/:token */
export interface PublicOrderCharge {
  status: PublicChargeStatus
  value: number
  /** YYYY-MM-DD */
  dueDate: string
  mode: PublicChargeMode
  installmentCount?: number
  invoiceUrl: string
}

export type ChargeView =
  | { kind: 'pay'; value: number; dueDate: string; invoiceUrl: string; installmentCount: number | null }
  | { kind: 'overdue' }
  | { kind: 'paid' }
  | { kind: 'none' }

export function isSafeInvoiceUrl(url: string | undefined): boolean {
  if (!url) return false
  try {
    return new URL(url).protocol === 'https:'
  } catch {
    return false
  }
}

export function getChargeView(charge: PublicOrderCharge | null | undefined): ChargeView {
  if (!charge) return { kind: 'none' }
  if (charge.status === 'paid') return { kind: 'paid' }
  if (charge.status === 'overdue') return { kind: 'overdue' }
  if (charge.status === 'pending' && isSafeInvoiceUrl(charge.invoiceUrl)) {
    return {
      kind: 'pay',
      value: charge.value,
      dueDate: charge.dueDate,
      invoiceUrl: charge.invoiceUrl,
      installmentCount: charge.mode === 'cardInstallments' && charge.installmentCount
        ? charge.installmentCount
        : null,
    }
  }
  return { kind: 'none' }
}

/** A pending or overdue charge can still turn into paid while the customer is away. */
export function shouldRefreshCharge(charge: PublicOrderCharge | null | undefined): boolean {
  return charge?.status === 'pending' || charge?.status === 'overdue'
}

/** Formats a YYYY-MM-DD due date as a calendar date (no timezone shift). */
export function formatChargeDueDate(dueDate: string, lang: ChargeLang): string {
  const [year, month, day] = dueDate.split('-').map(Number)
  if (!year || !month || !day) return dueDate
  const locale = lang === 'en' ? 'en-US' : lang === 'es' ? 'es-ES' : 'pt-BR'
  return new Date(Date.UTC(year, month - 1, day)).toLocaleDateString(locale, {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    timeZone: 'UTC',
  })
}
```

- [ ] **Step 4: Rodar e ver passar**

```bash
cd firebase/web && npm test
```

Esperado: `# pass 7`, `# fail 0` (pode aparecer o aviso `ExperimentalWarning: Type Stripping`, é normal).

- [ ] **Step 5: Strings i18n (pt/en/es)**

Em `firebase/web/composables/useOrderI18n.ts`, no bloco `pt`, depois de `termsRequiredError: 'Você deve aceitar os termos para aprovar o orçamento',` (linha 123):

```ts
    chargePay: 'Pagar {amount}',
    chargeMethods: 'Pix, boleto ou cartão',
    chargeInstallments: 'Em {count}x no cartão',
    chargeDue: 'Vence em {date}',
    chargeOverdue: 'Cobrança vencida. Fale com a empresa',
    chargePaid: 'Pago ✓',
```

No bloco `en`, depois de `termsRequiredError: 'You must accept the terms to approve the quote',` (linha 220 original):

```ts
    chargePay: 'Pay {amount}',
    chargeMethods: 'Pix, bank slip or card',
    chargeInstallments: '{count} card installments',
    chargeDue: 'Due {date}',
    chargeOverdue: 'Payment overdue. Please contact the company',
    chargePaid: 'Paid ✓',
```

No bloco `es`, depois de `termsRequiredError: 'Debes aceptar los términos para aprobar el presupuesto',` (linha 317 original):

```ts
    chargePay: 'Pagar {amount}',
    chargeMethods: 'Pix, boleto o tarjeta',
    chargeInstallments: 'En {count} cuotas con tarjeta',
    chargeDue: 'Vence el {date}',
    chargeOverdue: 'Cobro vencido. Contacta a la empresa',
    chargePaid: 'Pagado ✓',
```

- [ ] **Step 6: Componente `OrderChargeAction.vue`**

Criar `firebase/web/components/order/OrderChargeAction.vue` (o Nuxt registra como `<OrderChargeAction>`, igual a `OrderHeader`):

```vue
<template>
  <div v-if="view.kind !== 'none'" class="mt-4">
    <template v-if="view.kind === 'pay'">
      <a
        :href="view.invoiceUrl"
        target="_blank"
        rel="noopener noreferrer"
        class="flex w-full items-center justify-center gap-2 rounded-xl bg-[#1B5E7B] px-4 py-3 text-[15px] font-semibold text-white transition hover:bg-[#164E66] active:scale-[0.99]"
      >
        <svg class="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true">
          <rect x="1" y="4" width="22" height="16" rx="2" ry="2" /><line x1="1" y1="10" x2="23" y2="10" />
        </svg>
        {{ payLabel }}
      </a>
      <p class="mt-2 text-center text-[12px] text-[#5A7184]">{{ detailLabel }}</p>
    </template>

    <div
      v-else-if="view.kind === 'overdue'"
      role="status"
      class="flex items-center gap-2 rounded-xl bg-[#FEF2F2] px-4 py-3 text-[13px] font-medium text-[#B91C1C]"
    >
      <span class="h-2 w-2 shrink-0 rounded-full bg-[#EF4444]" aria-hidden="true" />
      {{ t.chargeOverdue }}
    </div>

    <div
      v-else
      role="status"
      class="flex items-center justify-center gap-2 rounded-xl bg-[#F0FDF4] px-4 py-3 text-[14px] font-semibold text-[#16A34A]"
    >
      {{ t.chargePaid }}
    </div>
  </div>
</template>

<script setup lang="ts">
import { formatCurrency } from '~/utils/format'
import { getChargeView, formatChargeDueDate, type PublicOrderCharge } from '~/utils/charge'

const props = defineProps<{
  charge?: PublicOrderCharge | null
  country?: string
}>()

const { t, lang } = useOrderI18n()

const view = computed(() => getChargeView(props.charge))

const payLabel = computed(() => {
  const v = view.value
  if (v.kind !== 'pay') return ''
  return t.value.chargePay.replace('{amount}', formatCurrency(v.value, props.country))
})

const detailLabel = computed(() => {
  const v = view.value
  if (v.kind !== 'pay') return ''
  const how = v.installmentCount
    ? t.value.chargeInstallments.replace('{count}', String(v.installmentCount))
    : t.value.chargeMethods
  const due = t.value.chargeDue.replace('{date}', formatChargeDueDate(v.dueDate, lang.value))
  return `${how} · ${due}`
})
</script>
```

- [ ] **Step 7: Ligar no `OrderSummaryCard` e na página**

Em `firebase/web/components/order/OrderSummaryCard.vue`, depois da linha 28 (o `</div>` que fecha o bloco `<!-- Subtotal / discount / paid breakdown -->`), acrescentar:

```vue

    <!-- Asaas charge: pay button / overdue / paid -->
    <OrderChargeAction :charge="charge" :country="country" />
```

No `<script setup>`, trocar a linha 71 e as linhas 73–76:

```ts
import { formatCurrency } from '~/utils/format'

const props = defineProps<{
  order: any
  country?: string
}>()
```

por:

```ts
import { formatCurrency } from '~/utils/format'
import type { PublicOrderCharge } from '~/utils/charge'

const props = defineProps<{
  order: any
  country?: string
  charge?: PublicOrderCharge | null
}>()
```

Em `firebase/web/pages/q/[token].vue`:

Linha 45 (layout mobile), trocar:

```vue
        <OrderSummaryCard :order="order" :country="company?.country" />
```

por:

```vue
        <OrderSummaryCard :order="order" :country="company?.country" :charge="charge" />
```

Linha 72 (layout desktop), mesma troca (com a indentação de 10 espaços):

```vue
          <OrderSummaryCard :order="order" :country="company?.country" :charge="charge" />
```

Depois da linha 162 (`const permissions = computed(...)`), acrescentar:

```ts
const charge = computed(() => (orderData.value as any)?.data?.charge ?? null)
```

- [ ] **Step 8: Build**

```bash
cd firebase/web && npm test && npm run build
```

Esperado: testes PASS; `nuxt build` termina com `✨ Build complete!` (ou `Σ Total size` sem erros). Conferir que o componente foi resolvido: `grep -rl "chargePay" .output/server | head -1` devolve um arquivo.

- [ ] **Step 9: Commit**

```bash
git add firebase/web/utils/charge.ts firebase/web/tests/charge.test.ts firebase/web/package.json \
        firebase/web/components/order/OrderChargeAction.vue firebase/web/components/order/OrderSummaryCard.vue \
        firebase/web/composables/useOrderI18n.ts "firebase/web/pages/q/[token].vue"
git commit -m "$(cat <<'EOF'
feat(web): show Asaas pay button on order link

The order summary shows "Pagar R$ X" (opens the Asaas invoice in a new tab)
for a pending charge, an overdue notice, or "Pago ✓", in pt/en/es. Adds a
node --test runner for web utils.

Refs #303

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task E3: Refazer o fetch quando o cliente volta para a aba

**Files:**
- Create: `firebase/web/composables/useRefreshOnVisible.ts`
- Modify: `firebase/web/pages/q/[token].vue` (linha 4 e depois do `const charge` criado na Task E2)
- Modify: `docs/SHARE_LINK.md` (parágrafo das linhas 165–169)
- Test: verificação manual no navegador (o efeito depende de `document.visibilitychange`; a regra de quando refazer, `shouldRefreshCharge`, já está coberta na Task E2)

**Interfaces:**
- Consumes: `refresh` do `useFetch('/api/orders/${token}')` (caminho já usado após aprovar/avaliar; o rewrite `/api/orders/**` do Hosting aponta para o Cloud Run `praticos-web` com `Cache-Control: private, no-store`), `shouldRefreshCharge` (Task E2).
- Produces: `useRefreshOnVisible(refresh: () => unknown, options?: { when?: () => boolean; minIntervalMs?: number }): void`.

- [ ] **Step 1: Composable**

Criar `firebase/web/composables/useRefreshOnVisible.ts`:

```ts
interface RefreshOnVisibleOptions {
  /** Only refresh while this returns true (e.g. charge still pending). */
  when?: () => boolean
  /** Minimum time between refreshes; the public API allows 30 req/min per link. */
  minIntervalMs?: number
}

/**
 * Re-runs `refresh` when the tab becomes visible again, e.g. after the customer
 * pays the Asaas invoice in another tab and comes back to the order link.
 */
export function useRefreshOnVisible(refresh: () => unknown, options: RefreshOnVisibleOptions = {}) {
  const minIntervalMs = options.minIntervalMs ?? 10_000
  let lastRun = 0

  function onVisibilityChange() {
    if (document.visibilityState !== 'visible') return
    if (options.when && !options.when()) return
    const now = Date.now()
    if (now - lastRun < minIntervalMs) return
    lastRun = now
    void refresh()
  }

  onMounted(() => document.addEventListener('visibilitychange', onVisibilityChange))
  onBeforeUnmount(() => document.removeEventListener('visibilitychange', onVisibilityChange))
}
```

- [ ] **Step 2: Usar na página e evitar o spinner de tela cheia no refresh**

Em `firebase/web/pages/q/[token].vue`, linha 4, trocar:

```vue
    <div v-if="pending" class="flex min-h-[60vh] flex-col items-center justify-center gap-6">
```

por (o `refresh()` do `useFetch` volta `pending` para `true`; sem isso a página inteira vira spinner a cada volta para a aba):

```vue
    <div v-if="pending && !orderData" class="flex min-h-[60vh] flex-col items-center justify-center gap-6">
```

No topo do `<script setup lang="ts">` (linha 149, antes de `const route = useRoute()`), acrescentar:

```ts
import { shouldRefreshCharge } from '~/utils/charge'
```

E logo depois da linha `const charge = computed(...)` (criada na Task E2), acrescentar:

```ts

// Customer pays the Asaas invoice in another tab; reflect it when they come back
useRefreshOnVisible(() => refreshOrder(), { when: () => shouldRefreshCharge(charge.value) })
```

- [ ] **Step 3: Atualizar `docs/SHARE_LINK.md`**

No parágrafo das linhas 165–169 (que começa com "A página `/q/{token}` (Nuxt, Cloud Run `praticos-web`)"), trocar a frase "no navegador, o `refresh()` (após aprovar/rejeitar ou avaliar)" por:

```markdown
no navegador, o `refresh()` (após aprovar/rejeitar, avaliar ou quando a aba volta a ficar visível com cobrança Asaas pendente/vencida, via `useRefreshOnVisible`, no máximo 1 vez a cada 10 s)
```

- [ ] **Step 4: Build e verificação manual**

```bash
cd firebase/web && npm test && npm run build
```

Esperado: PASS e build sem erros.

Verificação manual (depois do deploy das Functions do Bloco E, com uma OS de teste conectada ao sandbox e cobrança pendente, ou usando o `npm run e2e:asaas -- --with-api` do Bloco F):

1. `cd firebase/web && API_BASE_URL=https://southamerica-east1-praticos.cloudfunctions.net/api npm run dev` e abrir `http://localhost:3000/q/{token}`.
2. Ver o botão "Pagar R$ X"; clicar abre a fatura do Asaas em nova aba.
3. Confirmar o pagamento no sandbox (`POST /v3/sandbox/payment/{id}/confirm`), voltar para a aba do link: na aba Network aparece um GET `/api/orders/{token}`, sem spinner de tela cheia, e o card mostra "Pago ✓".
4. Voltar de novo para a aba: nenhum novo GET (`shouldRefreshCharge` é `false` para `paid`).

- [ ] **Step 5: Commit**

```bash
git add firebase/web/composables/useRefreshOnVisible.ts "firebase/web/pages/q/[token].vue" docs/SHARE_LINK.md
git commit -m "$(cat <<'EOF'
feat(web): refresh order link when tab regains focus

While the Asaas charge is pending or overdue, the /q/{token} page refetches
the order when the tab becomes visible again (throttled to 10s) so the
customer sees "Pago" after paying. Refreshes no longer show the full-page
spinner.

Refs #303

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task E4: Open PR

- [ ] **Step 1: Verificação final**

```bash
cd firebase/functions && npm run lint && npm test
cd ../web && npm test && npm run build
```

Esperado: tudo verde.

- [ ] **Step 2: Push e PR**

```bash
git push -u origin feat/asaas-share-link
gh pr create --base master --head feat/asaas-share-link --label risk:high \
  --title 'feat(share-link): botão "Pagar" da cobrança Asaas no link da OS' \
  --body "$(cat <<'EOF'
## Resumo

- `GET /public/orders/:token` devolve `charge: { status, value, dueDate, mode, installmentCount?, invoiceUrl } | null` (cobrança aberta ou a última paga; nada da conta Asaas, sem ids). Cobrança cancelada/estornada ou erro na leitura → `null`, a página nunca quebra.
- Link `/q/{token}`: cobrança pendente mostra **"Pagar R$ X"** (abre a fatura do Asaas em nova aba), vencida mostra **"Cobrança vencida. Fale com a empresa"**, paga mostra **"Pago ✓"**. Strings em pt/en/es.
- Ao voltar para a aba com cobrança pendente/vencida, a página refaz o fetch (no máximo a cada 10 s, respeitando o rate limit de 30 req/min por link) e não mostra mais o spinner de tela cheia no refresh.
- `OrderTotalSection.vue` não é usado; o botão entrou no `OrderSummaryCard` via componente novo `OrderChargeAction`.
- `firebase/web` ganhou `npm test` (`node --test`, sem dependência nova) para `utils/charge.ts`.

## Testes

- `cd firebase/functions && npm run lint && npm test` (novo `routes/public/__tests__/orders.routes.test.ts`)
- `cd firebase/web && npm test && npm run build`
- Manual: pagar no sandbox e voltar à aba → "Pago ✓"

Refs #303

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Bloco F — E2E sandbox, documentação e rollout

> Contract note: `dotenv` não está nas dependências de `firebase/functions`. O script E2E usa `process.loadEnvFile()` do Node 22 (mesmo formato de `.env`, aceita a chave entre aspas simples por causa do `$`), sem dependência nova. O modo opcional com a API localiza a cobrança no Asaas por `externalReference = {companyId}:{orderId}:{chargeId}` (spec, "Gerar cobrança" passo 4), então não depende do corpo exato devolvido por `POST /v1/app/orders/:orderId/charges` além de `chargeId` (ou `id`). Sobre `ASAAS_WEBHOOK_BASE_URL`: o deploy das Functions roda no CI (`.github/workflows/firebase-functions-deploy.yml`) a partir do git, e todos os `.env*` de `firebase/functions` estão no `.gitignore`; o rollout abaixo exige conferir que o Bloco B definiu o valor de produção (`https://southamerica-east1-praticos.cloudfunctions.net/api`) como default do parâmetro, porque um `.env` local não chega ao deploy do CI.

**Branch:** `docs/asaas-payments`, a partir da `master` depois do merge dos Blocos A–E.
**PR:** `docs(asaas): E2E sandbox, rollout e artigo público da cobrança com Asaas`
**Verificação do PR:**

```bash
cd firebase/functions && npm run lint && npm test && npm run e2e:asaas
cd ../hosting && npm ci && npm run build
grep -n "ASAAS_INTEGRATION" ../../CLAUDE.md
```

---

### Task F1: Script E2E no sandbox do Asaas

**Files:**
- Create: `firebase/functions/scripts/asaas-sandbox-e2e.ts`
- Modify: `firebase/functions/package.json` (bloco `scripts`, depois de `"setup-test"` na linha 17)
- Test: execução real contra o sandbox (`npm run e2e:asaas`) + checagem de tipos com `tsc`

**Interfaces:**
- Consumes: `ASAAS_SANDBOX_API_KEY` (em `firebase/functions/.env.local`, gitignored); Asaas sandbox `GET /v3/myAccount`, `GET|POST /v3/customers`, `POST /v3/payments`, `POST /v3/sandbox/payment/{id}/confirm`, `GET /v3/payments/{id}`, `GET /v3/payments?externalReference=`. Modo `--with-api`: `GET /public/orders/:token` (com `data.charge` do Bloco E), `POST /v1/app/orders/:orderId/charges` (Bloco B) com `Authorization: Bearer` + `X-Company-Id` (Bloco A).
- Produces: `npm run e2e:asaas [-- --with-api]`.

- [ ] **Step 1: Escrever o script**

Criar `firebase/functions/scripts/asaas-sandbox-e2e.ts`:

```ts
/**
 * Asaas sandbox end-to-end check. See docs/ASAAS_INTEGRATION.md ("E2E no sandbox").
 *
 * Asaas-only flow (does not touch PraticOS):
 *   npm run e2e:asaas
 *
 * Full flow against a deployed or tunneled PraticOS API. The company must already be
 * connected (Integrações > Asaas) with the SAME sandbox key, and the order must have
 * a remaining balance and a share link:
 *   npm run e2e:asaas -- --with-api
 *
 * Env (firebase/functions/.env.local is loaded when present; it is gitignored):
 *   ASAAS_SANDBOX_API_KEY   required, must start with $aact_hmlg
 *   PRATICOS_API_BASE       --with-api, e.g. https://southamerica-east1-praticos.cloudfunctions.net/api
 *   PRATICOS_ID_TOKEN       --with-api, Firebase ID token of an owner/admin/manager
 *   PRATICOS_COMPANY_ID     --with-api
 *   PRATICOS_ORDER_ID       --with-api
 *   PRATICOS_SHARE_TOKEN    --with-api, token of the order share link (/q/{token})
 *
 * Never prints the API key or the ID token.
 */

import * as fs from 'fs';
import * as path from 'path';

const ASAAS_SANDBOX_BASE = 'https://api-sandbox.asaas.com/v3';
const USER_AGENT = 'praticos-e2e';
const E2E_CUSTOMER_REF = 'praticos-e2e';
const E2E_CUSTOMER_CPF = '24971563792'; // valid test CPF (check digits OK), sandbox only
const E2E_PAYMENT_VALUE = 10;
const PAID_STATUSES = ['RECEIVED', 'CONFIRMED'];
const POLL_INTERVAL_MS = 3000;
const API_POLL_INTERVAL_MS = 5000; // public API allows 30 req/min per link
const ASAAS_POLL_TIMEOUT_MS = 60_000;
const API_POLL_TIMEOUT_MS = 120_000;

interface AsaasAccount { name?: string; email?: string }
interface AsaasList<T> { data: T[] }
interface AsaasCustomer { id: string; name: string }
interface AsaasPayment { id: string; status: string; value: number; invoiceUrl: string }
interface ApiEnvelope<T> { success: boolean; data?: T; error?: { code: string; message: string } }
interface PublicOrderData {
  order: { number: number; remainingBalance: number; paidAmount: number };
  charge: { status: string; value: number; invoiceUrl: string } | null;
}
interface CreatedCharge { chargeId?: string; id?: string; invoiceUrl?: string; status?: string }

function loadLocalEnv(): void {
  const envPath = path.resolve(__dirname, '..', '.env.local');
  if (fs.existsSync(envPath)) process.loadEnvFile(envPath);
}

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing env var ${name}`);
  return value;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function isoDatePlusDays(days: number): string {
  const date = new Date();
  date.setDate(date.getDate() + days);
  return date.toISOString().slice(0, 10);
}

async function readJson(res: Response): Promise<unknown> {
  const text = await res.text();
  if (!text) return {};
  try {
    return JSON.parse(text);
  } catch {
    return { raw: text.slice(0, 200) };
  }
}

async function asaas<T>(apiKey: string, method: 'GET' | 'POST', pathname: string, body?: unknown): Promise<T> {
  const res = await fetch(`${ASAAS_SANDBOX_BASE}${pathname}`, {
    method,
    headers: { 'access_token': apiKey, 'User-Agent': USER_AGENT, 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const json = await readJson(res);
  if (!res.ok) {
    const errors = (json as { errors?: { code: string; description: string }[] }).errors
      ?.map((e) => `${e.code}: ${e.description}`)
      .join('; ');
    throw new Error(`Asaas ${method} ${pathname} -> HTTP ${res.status} ${errors ?? ''}`.trim());
  }
  return json as T;
}

async function praticos<T>(
  base: string,
  method: 'GET' | 'POST',
  pathname: string,
  opts: { idToken?: string; companyId?: string; body?: unknown } = {},
): Promise<T> {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (opts.idToken) headers.Authorization = `Bearer ${opts.idToken}`;
  if (opts.companyId) headers['X-Company-Id'] = opts.companyId;
  const res = await fetch(`${base}${pathname}`, {
    method,
    headers,
    body: opts.body === undefined ? undefined : JSON.stringify(opts.body),
  });
  const json = (await readJson(res)) as ApiEnvelope<T>;
  if (!res.ok || !json.success || json.data === undefined) {
    throw new Error(
      `PraticOS ${method} ${pathname} -> HTTP ${res.status} ${json.error?.code ?? ''} ${json.error?.message ?? ''}`.trim(),
    );
  }
  return json.data;
}

async function findOrCreateCustomer(apiKey: string): Promise<AsaasCustomer> {
  const found = await asaas<AsaasList<AsaasCustomer>>(
    apiKey, 'GET', `/customers?externalReference=${E2E_CUSTOMER_REF}&limit=1`,
  );
  if (found.data.length > 0) return found.data[0];
  return asaas<AsaasCustomer>(apiKey, 'POST', '/customers', {
    name: 'Cliente E2E PraticOS',
    cpfCnpj: E2E_CUSTOMER_CPF,
    externalReference: E2E_CUSTOMER_REF,
    notificationDisabled: true,
  });
}

async function confirmAndWait(apiKey: string, paymentId: string): Promise<AsaasPayment> {
  await asaas<AsaasPayment>(apiKey, 'POST', `/sandbox/payment/${paymentId}/confirm`, {});
  const deadline = Date.now() + ASAAS_POLL_TIMEOUT_MS;
  for (;;) {
    const payment = await asaas<AsaasPayment>(apiKey, 'GET', `/payments/${paymentId}`);
    console.log(`  payment ${paymentId}: ${payment.status}`);
    if (PAID_STATUSES.includes(payment.status)) return payment;
    if (Date.now() > deadline) {
      throw new Error(`Payment ${paymentId} not paid after ${ASAAS_POLL_TIMEOUT_MS / 1000}s (last: ${payment.status})`);
    }
    await sleep(POLL_INTERVAL_MS);
  }
}

async function runAsaasOnly(apiKey: string) {
  console.log('1/5 GET /myAccount');
  const account = await asaas<AsaasAccount>(apiKey, 'GET', '/myAccount');
  console.log(`  account: ${account.name ?? '(no name)'}`);

  console.log('2/5 customer (find-or-create by externalReference)');
  const customer = await findOrCreateCustomer(apiKey);
  console.log(`  customer: ${customer.id}`);

  console.log('3/5 POST /payments (billingType UNDEFINED)');
  const created = await asaas<AsaasPayment>(apiKey, 'POST', '/payments', {
    customer: customer.id,
    billingType: 'UNDEFINED',
    value: E2E_PAYMENT_VALUE,
    dueDate: isoDatePlusDays(3),
    description: 'PraticOS E2E',
    externalReference: `praticos-e2e:${Date.now()}`,
  });
  console.log(`  payment: ${created.id} (${created.status}) ${created.invoiceUrl}`);

  console.log('4/5 POST /sandbox/payment/{id}/confirm');
  console.log('5/5 poll GET /payments/{id}');
  const paid = await confirmAndWait(apiKey, created.id);

  return {
    accountName: account.name ?? '',
    customerId: customer.id,
    paymentId: paid.id,
    status: paid.status,
    value: paid.value,
    invoiceUrl: created.invoiceUrl,
  };
}

async function runWithApi(apiKey: string) {
  const base = requireEnv('PRATICOS_API_BASE').replace(/\/$/, '');
  const idToken = requireEnv('PRATICOS_ID_TOKEN');
  const companyId = requireEnv('PRATICOS_COMPANY_ID');
  const orderId = requireEnv('PRATICOS_ORDER_ID');
  const shareToken = requireEnv('PRATICOS_SHARE_TOKEN');

  console.log('A/5 GET /public/orders/{token} (remaining balance)');
  const before = await praticos<PublicOrderData>(base, 'GET', `/public/orders/${shareToken}`);
  const balance = before.order.remainingBalance;
  if (!(balance > 0)) throw new Error(`Order #${before.order.number} has no remaining balance`);
  console.log(`  order #${before.order.number}, remaining ${balance}`);

  console.log('B/5 POST /v1/app/orders/{orderId}/charges');
  const created = await praticos<CreatedCharge>(base, 'POST', `/v1/app/orders/${orderId}/charges`, {
    idToken,
    companyId,
    body: { value: balance, mode: 'single' },
  });
  const chargeId = created.chargeId ?? created.id;
  if (!chargeId) throw new Error('Charge response without chargeId');
  console.log(`  charge: ${chargeId}`);

  console.log('C/5 find the Asaas payment by externalReference');
  const ref = `${companyId}:${orderId}:${chargeId}`;
  const list = await asaas<AsaasList<AsaasPayment>>(
    apiKey, 'GET', `/payments?externalReference=${encodeURIComponent(ref)}`,
  );
  if (list.data.length === 0) {
    throw new Error(`No Asaas payment with externalReference ${ref}. Is the company connected with the same sandbox key?`);
  }
  const paymentId = list.data[0].id;

  console.log('D/5 confirm in the sandbox');
  await confirmAndWait(apiKey, paymentId);

  console.log('E/5 poll /public/orders/{token} until the webhook marks the order paid');
  const deadline = Date.now() + API_POLL_TIMEOUT_MS;
  for (;;) {
    const after = await praticos<PublicOrderData>(base, 'GET', `/public/orders/${shareToken}`);
    console.log(`  charge: ${after.charge?.status ?? 'none'}, remaining ${after.order.remainingBalance}`);
    if (after.charge?.status === 'paid' && after.order.remainingBalance <= 0.005) {
      return { orderNumber: after.order.number, chargeId, paymentId, paidAmount: after.order.paidAmount };
    }
    if (Date.now() > deadline) {
      throw new Error('Order not marked paid in time: check webhook delivery (ASAAS_WEBHOOK_BASE_URL, tunnel, function logs)');
    }
    await sleep(API_POLL_INTERVAL_MS);
  }
}

async function main(): Promise<void> {
  loadLocalEnv();
  const apiKey = requireEnv('ASAAS_SANDBOX_API_KEY');
  if (!apiKey.startsWith('$aact_hmlg')) {
    throw new Error('ASAAS_SANDBOX_API_KEY is not a sandbox key ($aact_hmlg...). Aborting.');
  }

  const started = Date.now();
  const asaasSummary = await runAsaasOnly(apiKey);
  const apiSummary = process.argv.includes('--with-api') ? await runWithApi(apiKey) : null;

  console.log('\n=== Asaas sandbox E2E: OK ===');
  console.log(`Account:      ${asaasSummary.accountName}`);
  console.log(`Customer:     ${asaasSummary.customerId}`);
  console.log(`Payment:      ${asaasSummary.paymentId} -> ${asaasSummary.status} (${asaasSummary.value})`);
  console.log(`Invoice:      ${asaasSummary.invoiceUrl}`);
  if (apiSummary) {
    console.log(`Order:        #${apiSummary.orderNumber} paid (paidAmount ${apiSummary.paidAmount})`);
    console.log(`Charge:       ${apiSummary.chargeId} / ${apiSummary.paymentId}`);
  } else {
    console.log('API check:    skipped (run with -- --with-api)');
  }
  console.log(`Elapsed:      ${Math.round((Date.now() - started) / 1000)}s`);
}

main().catch((error: unknown) => {
  console.error(`E2E failed: ${error instanceof Error ? error.message : String(error)}`);
  process.exit(1);
});
```

Em `firebase/functions/package.json`, depois da linha 17 (`"setup-test": "npx ts-node scripts/setup-test-data.ts",`), acrescentar:

```json
    "e2e:asaas": "ts-node scripts/asaas-sandbox-e2e.ts",
```

- [ ] **Step 2: Checar tipos**

```bash
cd firebase/functions && npx tsc --noEmit --strict --noUnusedLocals --esModuleInterop --skipLibCheck \
  --target ES2022 --module commonjs --types node scripts/asaas-sandbox-e2e.ts
```

Esperado: sem saída (exit 0).

- [ ] **Step 3: Rodar contra o sandbox**

Pré-requisito: `firebase/functions/.env.local` com `ASAAS_SANDBOX_API_KEY='$aact_hmlg_...'` (já existe na máquina do Rafael; ver `docs/ASAAS_INTEGRATION.md`).

```bash
cd firebase/functions && npm run e2e:asaas
```

Esperado: passos `1/5`…`5/5`, linhas `payment pay_...: RECEIVED` (ou `CONFIRMED`) e o resumo `=== Asaas sandbox E2E: OK ===` com `API check: skipped`. Exit 0. Nenhuma linha contém `$aact`:

```bash
npm run e2e:asaas 2>&1 | grep -c '\$aact'
```

Esperado: `0`.

Se o Asaas recusar o `confirm` para `billingType: UNDEFINED` (erro `invalid_action` ou similar), trocar `billingType: 'UNDEFINED'` por `billingType: 'PIX'` em `runAsaasOnly` e registrar no doc (Task F3, seção "E2E no sandbox") que o confirm do sandbox exige forma definida; o webhook real continua testado no modo `--with-api`.

- [ ] **Step 4: Commit**

```bash
git add firebase/functions/scripts/asaas-sandbox-e2e.ts firebase/functions/package.json
git commit -m "$(cat <<'EOF'
test(asaas): add sandbox end-to-end script

npm run e2e:asaas checks the sandbox key, finds or creates a test customer,
creates an UNDEFINED payment, confirms it with the sandbox endpoint and polls
until paid. With --with-api it also creates the charge through the PraticOS API
and waits for the webhook to mark the order paid on the public link.

Refs #303

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task F2: Script para liberar empresas do piloto

**Files:**
- Create: `firebase/functions/scripts/enable-asaas-pilot.ts`
- Modify: `firebase/functions/package.json` (bloco `scripts`, depois da linha de `e2e:asaas` da Task F1)
- Test: execução contra o emulador do Firestore com os dados de `npm run setup-test`

**Interfaces:**
- Consumes: doc `companies/{cid}/settings/payments` (`PaymentSettingsDoc`, contrato).
- Produces: `npm run asaas:pilot -- --company <companyId> [--dry-run] [--disable]`; grava `{ asaasEnabled: true }` com `merge` (e `asaasConnected: false` quando o doc ainda não existe).

- [ ] **Step 1: Escrever o script**

Criar `firebase/functions/scripts/enable-asaas-pilot.ts`:

```ts
/**
 * Enable (or disable) the Asaas pilot for one company.
 * Sets companies/{companyId}/settings/payments.asaasEnabled. The app only shows
 * Integrações > Asaas when this flag is true; users can never set it themselves.
 *
 * Usage (production, uses Application Default Credentials:
 * `gcloud auth application-default login`):
 *   npx ts-node scripts/enable-asaas-pilot.ts --company <companyId> --dry-run
 *   npx ts-node scripts/enable-asaas-pilot.ts --company <companyId>
 *   npx ts-node scripts/enable-asaas-pilot.ts --company <companyId> --disable
 *
 * Usage (emulator):
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 GCLOUD_PROJECT=praticos-app \
 *     npx ts-node scripts/enable-asaas-pilot.ts --company test_company_001
 */

import * as admin from 'firebase-admin';

interface Args {
  companyId: string;
  dryRun: boolean;
  disable: boolean;
}

function parseArgs(argv: string[]): Args {
  const index = argv.indexOf('--company');
  const companyId = index >= 0 ? argv[index + 1] : undefined;
  if (!companyId || companyId.startsWith('--')) {
    console.error('Usage: enable-asaas-pilot.ts --company <companyId> [--dry-run] [--disable]');
    process.exit(1);
  }
  return {
    companyId,
    dryRun: argv.includes('--dry-run'),
    disable: argv.includes('--disable'),
  };
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || 'praticos' });
  const db = admin.firestore();

  const companyRef = db.collection('companies').doc(args.companyId);
  const company = await companyRef.get();
  if (!company.exists) {
    console.error(`Company ${args.companyId} not found`);
    process.exit(1);
  }

  const settingsRef = companyRef.collection('settings').doc('payments');
  const current = await settingsRef.get();
  const asaasEnabled = !args.disable;
  const update = current.exists ? { asaasEnabled } : { asaasEnabled, asaasConnected: false };

  console.log(`Company:  ${company.get('name') ?? '(no name)'} (${args.companyId})`);
  console.log(`Before:   ${JSON.stringify(current.exists ? current.data() : null)}`);

  if (args.dryRun) {
    console.log(`[dry-run] would merge ${JSON.stringify(update)} into settings/payments`);
    return;
  }

  await settingsRef.set(update, { merge: true });
  const after = await settingsRef.get();
  console.log(`After:    ${JSON.stringify(after.data())}`);
  console.log(asaasEnabled ? 'Asaas pilot ENABLED' : 'Asaas pilot DISABLED');
}

main().catch((error: unknown) => {
  console.error(`Failed: ${error instanceof Error ? error.message : String(error)}`);
  process.exit(1);
});
```

Em `firebase/functions/package.json`, depois da linha `"e2e:asaas": ...` (Task F1), acrescentar:

```json
    "asaas:pilot": "ts-node scripts/enable-asaas-pilot.ts",
```

- [ ] **Step 2: Checar tipos**

```bash
cd firebase/functions && npx tsc --noEmit --strict --noUnusedLocals --esModuleInterop --skipLibCheck \
  --target ES2022 --module commonjs --types node scripts/enable-asaas-pilot.ts
```

Esperado: sem saída (exit 0).

- [ ] **Step 3: Rodar no emulador**

Terminal 1:

```bash
cd firebase && npx firebase-tools emulators:start --only firestore,auth --project praticos-app
```

Terminal 2:

```bash
cd firebase/functions
npm run setup-test
export FIRESTORE_EMULATOR_HOST=localhost:8080 GCLOUD_PROJECT=praticos-app
npm run asaas:pilot -- --company does_not_exist; echo "exit=$?"
npm run asaas:pilot -- --company test_company_001 --dry-run
npm run asaas:pilot -- --company test_company_001
npm run asaas:pilot -- --company test_company_001 --disable
npm run asaas:pilot
```

Esperado, em ordem:
1. `Company does_not_exist not found` e `exit=1`.
2. `Before:   null` e `[dry-run] would merge {"asaasEnabled":true,"asaasConnected":false} into settings/payments`.
3. `After:    {"asaasEnabled":true,"asaasConnected":false}` e `Asaas pilot ENABLED`.
4. `After:    {"asaasEnabled":false,"asaasConnected":false}` e `Asaas pilot DISABLED`.
5. A linha de uso e exit 1.

- [ ] **Step 4: Commit**

```bash
git add firebase/functions/scripts/enable-asaas-pilot.ts firebase/functions/package.json
git commit -m "$(cat <<'EOF'
chore(asaas): add script to enable the Asaas pilot per company

npm run asaas:pilot -- --company <id> [--dry-run] [--disable] merges
asaasEnabled into companies/{id}/settings/payments after checking the company
exists.

Refs #303

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task F3: `docs/ASAAS_INTEGRATION.md` (status, endpoints, dados, webhook, rollout)

**Files:**
- Modify: `docs/ASAAS_INTEGRATION.md` (reescrita completa; hoje 72 linhas com "Arquitetura planejada")
- Modify: `CLAUDE.md` (linha 842, item de `docs/ASAAS_INTEGRATION.md` em "Documentação Adicional")
- Test: checagens com `grep` (links, comandos, ausência de chaves)

**Interfaces:**
- Consumes: nomes do contrato (coleções, endpoints, `ASAAS_CREDENTIALS_KEY`, `ASAAS_WEBHOOK_BASE_URL`, `ASAAS_SANDBOX_API_KEY`), scripts das Tasks F1 e F2.
- Produces: documentação técnica e roteiro de rollout.

- [ ] **Step 1: Conferir o que o código entregou**

```bash
grep -rn "ASAAS_WEBHOOK_BASE_URL\|ASAAS_CREDENTIALS_KEY" firebase/functions/src | grep -v __tests__
grep -n "payments/asaas\|charges\|webhooks/asaas" firebase/functions/src/index.ts
grep -n "private\|settings/payments\|charges" firebase/firestore.rules | head -20
```

Esperado: `defineSecret('ASAAS_CREDENTIALS_KEY')`; `ASAAS_WEBHOOK_BASE_URL` lido com default de produção; as três rotas montadas (`/v1/app/payments/asaas`, `/v1/app/orders`, `/webhooks/asaas`); regras para `private`, `settings/payments` e `charges`. Se `ASAAS_WEBHOOK_BASE_URL` não tiver default no código, parar e abrir issue no Bloco B antes do rollout (o deploy do CI não lê `.env` local).

- [ ] **Step 2: Reescrever o doc**

Substituir todo o conteúdo de `docs/ASAAS_INTEGRATION.md` por:

````markdown
# Integração Asaas

> Status: **etapa 1 (núcleo de cobrança) implementada, em piloto** (issue #303).
> Spec: [`docs/superpowers/specs/2026-10-04-asaas-cobranca-os-design.md`](superpowers/specs/2026-10-04-asaas-cobranca-os-design.md).
> Estratégia e parceria: [`business/PARCERIAS.md`](../business/PARCERIAS.md).

## Visão Geral

O técnico cobra o cliente da OS por Pix, boleto ou cartão (à vista ou parcelado no cartão em 2–12x) pela conta Asaas da própria empresa. O cliente paga pelo link da OS (`/q/{token}`, botão "Pagar"). Quando o Asaas confirma o pagamento, um webhook lança o pagamento na OS e dá baixa automática.

Etapas seguintes (specs próprias): criar a empresa e importar clientes a partir da conta Asaas (etapa 2) e distribuição pela **Flapp Store** (etapa 3). Fora do escopo atual: split para a Rafsoft, NFS-e, cliente escolher o número de parcelas.

## Ambientes

| Ambiente | Painel | API base |
|----------|--------|----------|
| Sandbox | https://sandbox.asaas.com | `https://api-sandbox.asaas.com/v3` |
| Produção | https://www.asaas.com | `https://api.asaas.com/v3` |

- Autenticação: header `access_token: <chave>` + `User-Agent` identificando o PraticOS.
- Chaves de sandbox começam com `$aact_hmlg`; de produção, com `$aact_prod`. O ambiente da conexão é inferido desse prefixo. Em `.env`, usar aspas simples por causa do `$`.
- Chaves sem uso por 3 meses são desabilitadas pelo Asaas.
- Documentação oficial: https://docs.asaas.com (também via MCP `asaas` no Claude Code).

## Arquitetura

```
App ──► /v1/app/payments/asaas/*  ──► Asaas API (conta da empresa)
App ──► /v1/app/orders/:id/charges ─┘          │
                                               ▼
Firestore ◄── /webhooks/asaas/:companyId ◄── webhook (PAYMENT_*)
   │
   └── trigger repairAsaasPayments (orders onUpdate)
Link /q/{token} ◄── /public/orders/:token (cobrança aberta + invoiceUrl)
```

Todas as chamadas ao Asaas saem das Cloud Functions (`api`). O app nunca vê a chave.

| Peça | Arquivo |
|------|---------|
| Tipos | `firebase/functions/src/models/asaas.types.ts` |
| Criptografia (AES-256-GCM, hash de token) | `firebase/functions/src/services/asaas/crypto.ts` |
| Cliente HTTP do Asaas | `firebase/functions/src/services/asaas/asaas-client.ts` |
| Credencial por empresa (`AsaasCredentialProvider`; hoje `ApiKeyCredentialProvider`) | `firebase/functions/src/services/asaas/credential-provider.ts` |
| Conectar/desconectar | `firebase/functions/src/services/asaas/connection.service.ts` |
| Cobranças | `firebase/functions/src/services/asaas/charge.service.ts` |
| Lançar/estornar pagamento na OS, reparo | `firebase/functions/src/services/asaas/order-payment.service.ts` |
| Webhook | `firebase/functions/src/services/asaas/webhook.service.ts`, `src/routes/webhooks/asaas.routes.ts` |
| App | `lib/services/asaas_api_service.dart`, `lib/models/order_charge.dart`, `lib/models/payment_settings.dart`, `lib/screens/integrations/` |
| Link público | `firebase/web/components/order/OrderChargeAction.vue`, `firebase/web/utils/charge.ts` |

## Endpoints

Rotas `/v1/app/*` usam `bearerAuth` + `resolveCompanyContext`; o app envia `X-Company-Id`.

| Método | Rota | Permissão | Comportamento |
|--------|------|-----------|---------------|
| POST | `/v1/app/payments/asaas/connect` `{ apiKey }` | owner/admin (`manage:payments`) + `asaasEnabled` | Valida com `GET /myAccount`, infere ambiente, criptografa e salva em `private/asaas`, cadastra o webhook no Asaas, grava `settings/payments`. Chave inválida → 400 sem gravar nada |
| DELETE | `/v1/app/payments/asaas/connect` | owner/admin | Remove o webhook no Asaas, apaga a credencial, `asaasConnected=false`. Cobranças abertas continuam no Asaas, sem baixa automática |
| POST | `/v1/app/orders/:orderId/charges` `{ value, mode, installmentCount?, dueDate?, customerTaxId? }` | `chargeOrder` (owner/admin/manager) | Valida (conta conectada, OS não cancelada, `0 < value <= total - paidAmount`, 2–12 parcelas, CPF/CNPJ do cliente), cancela a cobrança aberta anterior, find-or-create do cliente no Asaas, cria a cobrança (`externalReference = {companyId}:{orderId}:{chargeId}`), grava em `charges` |
| DELETE | `/v1/app/orders/:orderId/charges/:chargeId` | `chargeOrder` | Cancela no Asaas (`DELETE /payments/{id}` ou `/installments/{id}`), `status=canceled` |
| POST | `/webhooks/asaas/:companyId` | header `asaas-access-token` | Ver "Webhook" |
| GET | `/public/orders/:token` | share token | Inclui `charge: { status, value, dueDate, mode, installmentCount?, invoiceUrl } \| null` |

## Modelo de dados (Firestore)

| Caminho | Acesso | Conteúdo |
|---------|--------|----------|
| `companies/{cid}/private/asaas` | só servidor | `mode` (`apiKey`\|`flapp`), `environment`, `encryptedApiKey { iv, tag, ciphertext }`, `accountName`, `walletId`, `webhookId`, `webhookTokenHash` (SHA-256), `status` (`active`\|`invalid`), `connectedBy`, `connectedAt` |
| `companies/{cid}/private/asaas/customers/{customerId}` | só servidor | `{ asaasCustomerId }` |
| `companies/{cid}/private/asaas/events/{eventId}` | só servidor | `{ processedAt, expiresAt }` — idempotência do webhook, TTL de 30 dias em `expiresAt` |
| `companies/{cid}/settings/payments` | leitura membros, escrita servidor | `asaasEnabled` (piloto, só via script), `asaasConnected`, `asaasAccountName`, `asaasEnvironment` |
| `companies/{cid}/orders/{oid}/charges/{chargeId}` | leitura owner/admin/manager, escrita servidor | `asaasPaymentId`, `asaasInstallmentId?`, `mode` (`single`\|`cardInstallments`), `installmentCount?`, `value`, `dueDate` (YYYY-MM-DD), `status` (`pending`\|`paid`\|`overdue`\|`canceled`\|`refunded`), `invoiceUrl`, `paidAsaasPaymentIds`, `createdBy`, `createdAt`, `paidAt?` |
| `Customer.taxId` / `CustomerAggr.taxId` | app | CPF/CNPJ só com dígitos |

As cobranças são a fonte da verdade dos pagamentos Asaas da OS.

## Webhook

- URL por empresa: `{ASAAS_WEBHOOK_BASE_URL}/webhooks/asaas/{companyId}`, cadastrada no connect com `sendType: SEQUENTIALLY`, `apiVersion: 3` e um `authToken` aleatório de 48 bytes (guardado só como hash).
- Autenticação: SHA-256 do header `asaas-access-token` comparado (timing-safe) com `webhookTokenHash`. Sem match → 401.
- Idempotência por `event.id` em `private/asaas/events`. Erro interno → 500 para o Asaas reenviar.
- Nunca logar chave, token nem payload.

| Evento | Efeito |
|--------|--------|
| `PAYMENT_RECEIVED` / `PAYMENT_CONFIRMED` | Lança `PaymentTransaction` `id = asaas_{payment.id}`, `type = payment`, descrição "Asaas • Pix" / "Asaas • Boleto" / "Asaas • Cartão 2/3", em transação Firestore; recalcula `paidAmount`, `paid` e `payment` (`paid`\|`unpaid`). Cobrança `paid` quando todos os pagamentos dela foram lançados. Push para dono/admin/gerente |
| `PAYMENT_OVERDUE` | `status=overdue` |
| `PAYMENT_REFUNDED` | Remove `asaas_{payment.id}` da OS, recalcula, `status=refunded`, registra no histórico |
| `PAYMENT_DELETED` | `status=canceled` (se não pago) |

**Proteção contra sobrescrita:** o app novo não envia `transactions`, `paidAmount`, `paid` nem `payment` ao salvar a OS (pagamentos manuais usam `runTransaction`). Para versões antigas, o trigger `repairAsaasPayments` (`onDocumentUpdated` em `companies/{cid}/orders/{oid}`, só para empresas com `asaasConnected`) reinsere qualquer `asaas_{id}` listado em `paidAsaasPaymentIds` que tenha sumido.

## Configuração local (desenvolvimento)

`firebase/functions/.env.local` (gitignored):

```bash
ASAAS_SANDBOX_API_KEY='$aact_hmlg_...'
```

Nunca commitar chaves. Onde cada credencial está fica no inventário privado de acessos (fora deste repositório).

Teste rápido da chave:

```bash
curl -s https://api-sandbox.asaas.com/v3/myAccount -H "access_token: $ASAAS_SANDBOX_API_KEY" -H "User-Agent: praticos-dev"
```

O Asaas não alcança o emulador local. Para receber webhooks do sandbox em dev, expor a porta das Functions do emulador (5000) com um túnel (`ngrok http 5000`) e usar como `ASAAS_WEBHOOK_BASE_URL` a URL do túnel + `/{projectId}/southamerica-east1/api` antes de conectar a conta no app.

## E2E no sandbox

Script: `firebase/functions/scripts/asaas-sandbox-e2e.ts` (lê `.env.local` sozinho, aborta se a chave não for `$aact_hmlg`).

```bash
cd firebase/functions
npm run e2e:asaas                 # só Asaas: myAccount, cliente de teste, cobrança UNDEFINED, sandbox confirm, polling
npm run e2e:asaas -- --with-api   # também cria a cobrança pela API do PraticOS e espera o webhook dar baixa
```

Modo `--with-api` (API publicada ou via túnel; a empresa já conectada com a **mesma** chave de sandbox; a OS com saldo e link compartilhado):

```bash
export PRATICOS_API_BASE=https://southamerica-east1-praticos.cloudfunctions.net/api
export PRATICOS_ID_TOKEN=...      # Firebase ID token de dono/admin/gerente (não commitar)
export PRATICOS_COMPANY_ID=... PRATICOS_ORDER_ID=... PRATICOS_SHARE_TOKEN=...
npm run e2e:asaas -- --with-api
```

Sucesso: `=== Asaas sandbox E2E: OK ===` e `Order: #N paid`. Para simular vencimento: `POST /v3/sandbox/payment/{id}/overdue`.

## Rollout

1. **Secret da chave mestra** (passo do Rafael, uma vez):

   ```bash
   openssl rand -base64 32 | gcloud secrets create ASAAS_CREDENTIALS_KEY --data-file=- --project praticos
   gcloud secrets versions list ASAAS_CREDENTIALS_KEY --project praticos
   ```

   O deploy das Functions dá acesso ao secret para a conta de serviço da `api`. **Não trocar** essa chave depois que houver empresas conectadas: as credenciais gravadas deixam de abrir e todas precisam reconectar.

2. **`ASAAS_WEBHOOK_BASE_URL`**: em produção é `https://southamerica-east1-praticos.cloudfunctions.net/api` (webhook final `.../webhooks/asaas/{companyId}`). O deploy roda no CI (`.github/workflows/firebase-functions-deploy.yml`) sem os `.env` de `firebase/functions` (estão no `.gitignore`), então o valor de produção é o default definido no código. Conferir:

   ```bash
   grep -rn "ASAAS_WEBHOOK_BASE_URL" firebase/functions/src | grep -v __tests__
   ```

   Em dev, sobrescrever com a URL do túnel (seção "Configuração local").

3. **Deploy**: merge na `master` publica as Functions pelo CI. Regras do Firestore (`private/**`, `charges`, `settings/payments`) não são publicadas pelo CI:

   ```bash
   cd firebase && firebase deploy --only firestore:rules --project praticos
   ```

4. **TTL dos eventos de webhook** (uma vez):

   ```bash
   gcloud firestore fields ttls update expiresAt --collection-group=events --enable-ttl --project=praticos
   gcloud firestore fields ttls list --project=praticos
   ```

   `events` só existe em `companies/{cid}/private/asaas/events`; nenhuma outra coleção usa esse nome.

5. **Teste no sandbox** com a conta sandbox da Rafsoft: conectar a chave numa empresa de teste (depois do passo 7 para essa empresa) e rodar `npm run e2e:asaas -- --with-api`. Conferir no app o card "Cobrança" verde e a transação "Asaas • ..." na OS, e no link `/q/{token}` o "Pago ✓".

6. **App novo publicado** antes de liberar qualquer piloto (versões antigas não mostram "Cobrar"; o trigger de reparo cobre sobrescrita de pagamentos por elas).

7. **Liberar empresas piloto** (só empresas com conta Asaas própria em produção):

   ```bash
   cd firebase/functions
   gcloud auth application-default login
   npm run asaas:pilot -- --company <companyId> --dry-run
   npm run asaas:pilot -- --company <companyId>
   ```

   O dono/admin conecta a chave `$aact_prod...` em Ajustes > Integrações > Asaas.

8. **Primeira cobrança real** do piloto: valor baixo, pagar e estornar no painel do Asaas; conferir baixa e estorno na OS.

**Rollback de uma empresa:** desconectar no app (remove webhook e credencial) e `npm run asaas:pilot -- --company <companyId> --disable`. Cobranças abertas continuam no Asaas e podem ser canceladas no painel dele.

## Regras de Negócio

- Uma cobrança em aberto por OS; gerar outra cancela a anterior. Valor padrão = saldo restante (`total - paidAmount`; o `total` já é líquido de desconto), editável para menos (entrada).
- À vista (`billingType: UNDEFINED`, cliente escolhe Pix/boleto/cartão) ou parcelado no cartão (2–12x, definido pelo técnico). Vencimento padrão hoje + 3 dias.
- Notificações do Asaas desligadas (`notificationDisabled: true`): o cliente recebe a cobrança pelo link da OS.
- Cancelar a OS cancela a cobrança pendente no Asaas.
- Estorno no Asaas remove o pagamento da OS. Transações `asaas_*` não podem ser removidas no app.
- Recursos de cobrança de serviço físico ficam fora do IAP da Apple; não amarrar recursos pagos do app iOS a planos vendidos fora da loja sem revisar a guideline 3.1.1.

## Recursos do Asaas usados

| Recurso | Doc |
|---------|-----|
| Cobranças | https://docs.asaas.com/reference/criar-nova-cobranca |
| Clientes | https://docs.asaas.com/reference/criar-novo-cliente |
| Webhooks de cobrança | https://docs.asaas.com/docs/webhook-para-cobrancas |
| Ações de sandbox | https://docs.asaas.com/reference/confirmar-pagamento |
| Split (futuro) | https://docs.asaas.com/docs/split-de-pagamentos |
| NFS-e (futuro) | https://docs.asaas.com/docs/notas-fiscais |
| Flapp Store (etapa 3) | https://docs.asaas.com/docs/flappstore |
````

- [ ] **Step 3: Ajustar o `CLAUDE.md`**

`CLAUDE.md` já linka o doc (linha 842). Conferir e atualizar a descrição:

```bash
grep -n "docs/ASAAS_INTEGRATION.md" CLAUDE.md
```

Esperado: `842:- \`docs/ASAAS_INTEGRATION.md\` - Integração Asaas (ambientes, configuração, arquitetura da cobrança na OS)`. Trocar essa linha por:

```markdown
- `docs/ASAAS_INTEGRATION.md` - Integração Asaas (cobrança na OS: endpoints, dados, webhook, E2E no sandbox e rollout do piloto)
```

- [ ] **Step 4: Verificar**

```bash
grep -c "ASAAS_CREDENTIALS_KEY\|ASAAS_WEBHOOK_BASE_URL\|ttls update\|asaas:pilot\|e2e:asaas" docs/ASAAS_INTEGRATION.md
test -f docs/superpowers/specs/2026-10-04-asaas-cobranca-os-design.md && echo spec-ok
git diff | grep -E '\$aact_(prod|hmlg)_[A-Za-z0-9]{8,}' | wc -l
```

Esperado: contagem ≥ 8; `spec-ok`; `0` (nenhuma chave real no diff).

- [ ] **Step 5: Commit**

```bash
git add docs/ASAAS_INTEGRATION.md CLAUDE.md
git commit -m "$(cat <<'EOF'
docs(asaas): document charges, webhook, sandbox E2E and pilot rollout

Refs #303

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task F4: Artigo público "Cobrança com Asaas" (pt/en/es)

**Files:**
- Create: `firebase/hosting/src/_data/docs/cobranca-asaas.json`
- Create: `firebase/hosting/src/docs/cobranca-asaas.njk`, `firebase/hosting/src/docs/cobranca-asaas-en.njk`, `firebase/hosting/src/docs/cobranca-asaas-es.njk`
- Modify: `firebase/hosting/src/_data/docs.json` (novo card no hub, logo depois de "Sistema Financeiro" em pt/en/es)
- Test: `npm run build` do Eleventy + checagem dos HTML gerados em `public/docs/` (gitignored, não commitar)

**Interfaces:**
- Consumes: layout `layouts/docs-article.njk` + `components/docs/section-renderer.njk` (campos `intro`, `infoCard`, `warningCard`, `features`, `statusCards`, `subsections[].steps|content|validationList`, `table`, `faq`, `paragraphs`).
- Produces: `/docs/cobranca-asaas.html`, `/docs/cobranca-asaas-en.html`, `/docs/cobranca-asaas-es.html` e card no hub.

- [ ] **Step 1: Dados do artigo**

Criar `firebase/hosting/src/_data/docs/cobranca-asaas.json`:

```json
{
  "pt": {
    "sections": [
      {
        "id": "visao-geral",
        "title": "Visão Geral",
        "intro": "Cobre o cliente da OS por Pix, boleto ou cartão usando a conta Asaas da sua empresa. O cliente paga pelo link da OS e, quando o pagamento é confirmado, a OS dá baixa sozinha. O dinheiro cai direto na sua conta Asaas.",
        "infoCard": {
          "title": "Disponível no programa piloto",
          "content": "A cobrança com Asaas está sendo liberada aos poucos para empresas que já têm conta no Asaas. Fale com o suporte para participar."
        },
        "features": [
          {
            "icon": "<svg width=\"24\" height=\"24\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><rect x=\"1\" y=\"4\" width=\"22\" height=\"16\" rx=\"2\" ry=\"2\"></rect><line x1=\"1\" y1=\"10\" x2=\"23\" y2=\"10\"></line></svg>",
            "color": "green",
            "title": "Pix, boleto ou cartão",
            "description": "O cliente escolhe como pagar na fatura do Asaas"
          },
          {
            "icon": "<svg width=\"24\" height=\"24\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><line x1=\"8\" y1=\"6\" x2=\"21\" y2=\"6\"></line><line x1=\"8\" y1=\"12\" x2=\"21\" y2=\"12\"></line><line x1=\"8\" y1=\"18\" x2=\"21\" y2=\"18\"></line><line x1=\"3\" y1=\"6\" x2=\"3.01\" y2=\"6\"></line><line x1=\"3\" y1=\"12\" x2=\"3.01\" y2=\"12\"></line><line x1=\"3\" y1=\"18\" x2=\"3.01\" y2=\"18\"></line></svg>",
            "color": "blue",
            "title": "Parcelado no cartão",
            "description": "De 2 a 12 vezes, com o número de parcelas definido por você"
          },
          {
            "icon": "<svg width=\"24\" height=\"24\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><path d=\"M22 11.08V12a10 10 0 1 1-5.93-9.14\"></path><polyline points=\"22 4 12 14.01 9 11.01\"></polyline></svg>",
            "color": "orange",
            "title": "Baixa automática",
            "description": "Pagamento confirmado entra na OS sem digitar nada"
          }
        ]
      },
      {
        "id": "conectar",
        "title": "Conectar sua conta Asaas",
        "intro": "A conexão é feita uma vez por empresa, pelo dono ou por um administrador. Você precisa de uma conta Asaas aprovada.",
        "subsections": [
          {
            "title": "Gerar a chave de API no Asaas",
            "steps": [
              "Entre no painel do Asaas com a conta da sua empresa",
              "Abra a área de <strong>Integrações</strong> e gere uma nova <strong>chave de API</strong>",
              "Copie a chave (ela começa com <strong>$aact_</strong>)"
            ]
          },
          {
            "title": "Conectar no PraticOS",
            "steps": [
              "No app, abra <strong>Ajustes</strong> > <strong>Integrações</strong>",
              "Em <strong>Pagamentos</strong>, toque em <strong>Asaas</strong>",
              "Cole a chave e toque em <strong>Conectar</strong>",
              "O app mostra o nome da conta e o ambiente (<strong>Teste</strong> ou <strong>Produção</strong>)"
            ]
          }
        ],
        "warningCard": {
          "title": "Guarde a chave com cuidado",
          "content": "A chave dá acesso à sua conta Asaas. Cole somente no app PraticOS: ela fica criptografada no servidor e nunca volta a aparecer no app. Se suspeitar de vazamento, gere outra chave no Asaas e conecte de novo."
        }
      },
      {
        "id": "cobrar",
        "title": "Cobrar o cliente da OS",
        "intro": "Dono, administradores e gerentes podem gerar a cobrança direto na OS.",
        "subsections": [
          {
            "title": "Gerar a cobrança",
            "steps": [
              "Abra a OS e toque em <strong>Cobrar com Asaas</strong>, na área de pagamentos",
              "Confira o valor. Ele vem com o saldo restante da OS e pode ser diminuído para cobrar uma entrada",
              "Escolha <strong>À vista</strong> (o cliente escolhe Pix, boleto ou cartão) ou <strong>Parcelado no cartão</strong> (2 a 12x)",
              "Ajuste o vencimento, se precisar (o padrão é daqui a 3 dias)",
              "Se o cliente ainda não tiver CPF ou CNPJ cadastrado, informe agora",
              "Toque em <strong>Gerar cobrança</strong>"
            ]
          },
          {
            "title": "Entrada e restante",
            "content": "Exemplo: cobre R$ 300 de entrada no Pix. Depois que for pago, gere uma segunda cobrança com os R$ 700 restantes em 3x no cartão."
          }
        ],
        "statusCards": [
          { "color": "blue", "title": "Pendente", "description": "Cobrança gerada, aguardando o pagamento do cliente." },
          { "color": "orange", "title": "Vencida", "description": "Passou do vencimento sem pagamento. Gere uma nova cobrança." },
          { "color": "green", "title": "Paga", "description": "Pagamento confirmado pelo Asaas e lançado na OS." }
        ],
        "infoCard": {
          "title": "Uma cobrança aberta por vez",
          "content": "Gerar uma nova cobrança cancela a anterior que ainda não foi paga. Se o total da OS mudar, o app avisa e oferece gerar de novo com o valor atualizado. Cancelar a OS cancela a cobrança pendente."
        }
      },
      {
        "id": "link-do-cliente",
        "title": "Como o cliente paga",
        "intro": "O cliente paga pelo mesmo link da OS que você já compartilha. O Asaas não envia e-mail nem SMS ao cliente.",
        "subsections": [
          {
            "title": "Passo a passo do cliente",
            "steps": [
              "No card da cobrança, toque em <strong>Compartilhar link da OS</strong> e envie pelo WhatsApp",
              "O cliente abre o link e vê o botão <strong>Pagar</strong> com o valor",
              "O botão abre a fatura do Asaas, onde ele escolhe a forma de pagamento",
              "Ao voltar para o link, a OS mostra <strong>Pago ✓</strong>"
            ]
          }
        ],
        "paragraphs": [
          "Se a cobrança vencer, o link mostra <strong>Cobrança vencida. Fale com a empresa</strong>. Gere uma nova cobrança na OS.",
          "Também é possível copiar o link da fatura no card da cobrança e enviar direto."
        ]
      },
      {
        "id": "baixa-automatica",
        "title": "Baixa automática na OS",
        "intro": "Quando o Asaas confirma o pagamento, o PraticOS registra o pagamento na OS e atualiza o saldo.",
        "subsections": [
          {
            "title": "O que acontece",
            "validationList": [
              { "label": "Pagamento confirmado", "text": "Entra como pagamento na OS, com a descrição Asaas • Pix, Asaas • Boleto ou Asaas • Cartão" },
              { "label": "Parcelado", "text": "Cada parcela confirmada entra como um pagamento" },
              { "label": "Estorno", "text": "Estornou no Asaas, o pagamento sai da OS e o saldo volta" },
              { "label": "Aviso", "text": "Dono, administradores e gerentes recebem notificação no celular" }
            ]
          }
        ],
        "warningCard": {
          "title": "Pagamentos do Asaas não são apagados no app",
          "content": "Para desfazer um pagamento recebido pelo Asaas, estorne a cobrança no painel do Asaas. O estorno remove o pagamento da OS automaticamente."
        }
      },
      {
        "id": "permissoes",
        "title": "Permissões",
        "intro": "Quem pode fazer o quê na cobrança com Asaas:",
        "table": {
          "headers": ["Perfil", "Conectar conta Asaas", "Cobrar na OS"],
          "rows": [
            { "label": "Administrador", "cells": [{ "class": "yes" }, { "class": "yes" }] },
            { "label": "Gerente", "cells": [{ "class": "no" }, { "class": "yes" }] },
            { "label": "Supervisor", "cells": [{ "class": "no" }, { "class": "no" }] },
            { "label": "Consultor", "cells": [{ "class": "no" }, { "class": "no" }] },
            { "label": "Técnico", "cells": [{ "class": "no" }, { "class": "no" }] }
          ],
          "note": "O dono da empresa tem todas as permissões."
        }
      },
      {
        "id": "faq",
        "title": "Perguntas Frequentes",
        "faq": [
          { "question": "O PraticOS cobra taxa sobre os pagamentos?", "answer": "Não. Valem apenas as taxas da sua conta Asaas." },
          { "question": "Preciso ter conta no Asaas?", "answer": "Sim. A cobrança usa a conta Asaas da sua empresa, que precisa estar aprovada." },
          { "question": "Posso testar antes de cobrar de verdade?", "answer": "Sim. Uma chave do ambiente de testes do Asaas (sandbox) conecta em modo Teste e nada é cobrado de verdade." },
          { "question": "O cliente pode escolher o número de parcelas?", "answer": "Não. Você define de 2 a 12 parcelas ao gerar a cobrança." },
          { "question": "E se eu desconectar a conta?", "answer": "As cobranças abertas continuam no Asaas, mas pagamentos feitos depois não dão baixa automática na OS. Registre-os manualmente ou cancele as cobranças no painel do Asaas." }
        ]
      }
    ]
  },
  "en": {
    "sections": [
      {
        "id": "overview",
        "title": "Overview",
        "intro": "Charge your customer for a work order by Pix, bank slip or card using your company's Asaas account. The customer pays through the order link and, once the payment is confirmed, the order is marked as paid automatically. The money goes straight to your Asaas account.",
        "infoCard": {
          "title": "Available in the pilot program",
          "content": "Asaas charges are being rolled out gradually to companies that already have an Asaas account. Contact support to join."
        },
        "features": [
          {
            "icon": "<svg width=\"24\" height=\"24\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><rect x=\"1\" y=\"4\" width=\"22\" height=\"16\" rx=\"2\" ry=\"2\"></rect><line x1=\"1\" y1=\"10\" x2=\"23\" y2=\"10\"></line></svg>",
            "color": "green",
            "title": "Pix, bank slip or card",
            "description": "The customer picks how to pay on the Asaas invoice"
          },
          {
            "icon": "<svg width=\"24\" height=\"24\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><line x1=\"8\" y1=\"6\" x2=\"21\" y2=\"6\"></line><line x1=\"8\" y1=\"12\" x2=\"21\" y2=\"12\"></line><line x1=\"8\" y1=\"18\" x2=\"21\" y2=\"18\"></line><line x1=\"3\" y1=\"6\" x2=\"3.01\" y2=\"6\"></line><line x1=\"3\" y1=\"12\" x2=\"3.01\" y2=\"12\"></line><line x1=\"3\" y1=\"18\" x2=\"3.01\" y2=\"18\"></line></svg>",
            "color": "blue",
            "title": "Card installments",
            "description": "2 to 12 installments, with the number set by you"
          },
          {
            "icon": "<svg width=\"24\" height=\"24\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><path d=\"M22 11.08V12a10 10 0 1 1-5.93-9.14\"></path><polyline points=\"22 4 12 14.01 9 11.01\"></polyline></svg>",
            "color": "orange",
            "title": "Automatic settlement",
            "description": "Confirmed payments are added to the order with no typing"
          }
        ]
      },
      {
        "id": "connect",
        "title": "Connect your Asaas account",
        "intro": "The connection is done once per company, by the owner or an administrator. You need an approved Asaas account.",
        "subsections": [
          {
            "title": "Create the API key in Asaas",
            "steps": [
              "Sign in to the Asaas dashboard with your company account",
              "Open the <strong>Integrations</strong> area and create a new <strong>API key</strong>",
              "Copy the key (it starts with <strong>$aact_</strong>)"
            ]
          },
          {
            "title": "Connect in PraticOS",
            "steps": [
              "In the app, open <strong>Settings</strong> > <strong>Integrations</strong>",
              "Under <strong>Payments</strong>, tap <strong>Asaas</strong>",
              "Paste the key and tap <strong>Connect</strong>",
              "The app shows the account name and the environment (<strong>Test</strong> or <strong>Production</strong>)"
            ]
          }
        ],
        "warningCard": {
          "title": "Keep the key safe",
          "content": "The key gives access to your Asaas account. Paste it only in the PraticOS app: it is stored encrypted on the server and is never shown in the app again. If you suspect a leak, create a new key in Asaas and connect again."
        }
      },
      {
        "id": "charge",
        "title": "Charge the customer",
        "intro": "Owners, administrators and managers can create the charge right from the work order.",
        "subsections": [
          {
            "title": "Create the charge",
            "steps": [
              "Open the order and tap <strong>Charge with Asaas</strong> in the payments area",
              "Check the amount. It defaults to the order's remaining balance and can be lowered to charge a down payment",
              "Choose <strong>Single payment</strong> (the customer picks Pix, bank slip or card) or <strong>Card installments</strong> (2 to 12x)",
              "Adjust the due date if needed (default is 3 days from today)",
              "If the customer has no CPF or CNPJ on file, enter it now",
              "Tap <strong>Create charge</strong>"
            ]
          },
          {
            "title": "Down payment and balance",
            "content": "Example: charge R$ 300 down by Pix. Once it is paid, create a second charge for the remaining R$ 700 in 3 card installments."
          }
        ],
        "statusCards": [
          { "color": "blue", "title": "Pending", "description": "Charge created, waiting for the customer's payment." },
          { "color": "orange", "title": "Overdue", "description": "Past the due date without payment. Create a new charge." },
          { "color": "green", "title": "Paid", "description": "Payment confirmed by Asaas and added to the order." }
        ],
        "infoCard": {
          "title": "One open charge at a time",
          "content": "Creating a new charge cancels the previous unpaid one. If the order total changes, the app warns you and offers to create it again with the new amount. Canceling the order cancels the pending charge."
        }
      },
      {
        "id": "customer-link",
        "title": "How the customer pays",
        "intro": "The customer pays through the same order link you already share. Asaas does not send e-mail or SMS to the customer.",
        "subsections": [
          {
            "title": "Customer steps",
            "steps": [
              "On the charge card, tap <strong>Share order link</strong> and send it by WhatsApp",
              "The customer opens the link and sees the <strong>Pay</strong> button with the amount",
              "The button opens the Asaas invoice, where they choose how to pay",
              "Back on the link, the order shows <strong>Paid ✓</strong>"
            ]
          }
        ],
        "paragraphs": [
          "If the charge is overdue, the link shows <strong>Payment overdue. Please contact the company</strong>. Create a new charge on the order.",
          "You can also copy the invoice link on the charge card and send it directly."
        ]
      },
      {
        "id": "automatic-payment",
        "title": "Automatic settlement",
        "intro": "When Asaas confirms the payment, PraticOS records it on the order and updates the balance.",
        "subsections": [
          {
            "title": "What happens",
            "validationList": [
              { "label": "Payment confirmed", "text": "Added as a payment on the order, described as Asaas • Pix, Asaas • Boleto or Asaas • Cartão" },
              { "label": "Installments", "text": "Each confirmed installment is added as one payment" },
              { "label": "Refund", "text": "Refunded in Asaas, the payment is removed from the order and the balance returns" },
              { "label": "Notification", "text": "Owner, administrators and managers get a push notification" }
            ]
          }
        ],
        "warningCard": {
          "title": "Asaas payments cannot be deleted in the app",
          "content": "To undo a payment received through Asaas, refund the charge in the Asaas dashboard. The refund removes the payment from the order automatically."
        }
      },
      {
        "id": "permissions",
        "title": "Permissions",
        "intro": "Who can do what with Asaas charges:",
        "table": {
          "headers": ["Profile", "Connect Asaas account", "Charge on the order"],
          "rows": [
            { "label": "Administrator", "cells": [{ "class": "yes" }, { "class": "yes" }] },
            { "label": "Manager", "cells": [{ "class": "no" }, { "class": "yes" }] },
            { "label": "Supervisor", "cells": [{ "class": "no" }, { "class": "no" }] },
            { "label": "Consultant", "cells": [{ "class": "no" }, { "class": "no" }] },
            { "label": "Technician", "cells": [{ "class": "no" }, { "class": "no" }] }
          ],
          "note": "The company owner has every permission."
        }
      },
      {
        "id": "faq",
        "title": "FAQ",
        "faq": [
          { "question": "Does PraticOS charge a fee on payments?", "answer": "No. Only your Asaas account fees apply." },
          { "question": "Do I need an Asaas account?", "answer": "Yes. Charges use your company's Asaas account, which must be approved." },
          { "question": "Can I test before charging for real?", "answer": "Yes. A key from the Asaas test environment (sandbox) connects in Test mode and nothing is charged for real." },
          { "question": "Can the customer choose the number of installments?", "answer": "No. You set 2 to 12 installments when creating the charge." },
          { "question": "What if I disconnect the account?", "answer": "Open charges stay in Asaas, but payments made afterwards are not settled automatically on the order. Record them manually or cancel the charges in the Asaas dashboard." }
        ]
      }
    ]
  },
  "es": {
    "sections": [
      {
        "id": "vision-general",
        "title": "Visión General",
        "intro": "Cobra al cliente de la OS por Pix, boleto o tarjeta usando la cuenta Asaas de tu empresa. El cliente paga desde el enlace de la OS y, cuando se confirma el pago, la OS se marca como pagada automáticamente. El dinero entra directo en tu cuenta Asaas.",
        "infoCard": {
          "title": "Disponible en el programa piloto",
          "content": "El cobro con Asaas se está habilitando de a poco para empresas que ya tienen cuenta en Asaas. Contacta al soporte para participar."
        },
        "features": [
          {
            "icon": "<svg width=\"24\" height=\"24\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><rect x=\"1\" y=\"4\" width=\"22\" height=\"16\" rx=\"2\" ry=\"2\"></rect><line x1=\"1\" y1=\"10\" x2=\"23\" y2=\"10\"></line></svg>",
            "color": "green",
            "title": "Pix, boleto o tarjeta",
            "description": "El cliente elige cómo pagar en la factura de Asaas"
          },
          {
            "icon": "<svg width=\"24\" height=\"24\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><line x1=\"8\" y1=\"6\" x2=\"21\" y2=\"6\"></line><line x1=\"8\" y1=\"12\" x2=\"21\" y2=\"12\"></line><line x1=\"8\" y1=\"18\" x2=\"21\" y2=\"18\"></line><line x1=\"3\" y1=\"6\" x2=\"3.01\" y2=\"6\"></line><line x1=\"3\" y1=\"12\" x2=\"3.01\" y2=\"12\"></line><line x1=\"3\" y1=\"18\" x2=\"3.01\" y2=\"18\"></line></svg>",
            "color": "blue",
            "title": "Cuotas con tarjeta",
            "description": "De 2 a 12 cuotas, con el número definido por ti"
          },
          {
            "icon": "<svg width=\"24\" height=\"24\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><path d=\"M22 11.08V12a10 10 0 1 1-5.93-9.14\"></path><polyline points=\"22 4 12 14.01 9 11.01\"></polyline></svg>",
            "color": "orange",
            "title": "Baja automática",
            "description": "El pago confirmado entra en la OS sin escribir nada"
          }
        ]
      },
      {
        "id": "conectar",
        "title": "Conectar tu cuenta Asaas",
        "intro": "La conexión se hace una vez por empresa, por el dueño o un administrador. Necesitas una cuenta Asaas aprobada.",
        "subsections": [
          {
            "title": "Generar la clave de API en Asaas",
            "steps": [
              "Ingresa al panel de Asaas con la cuenta de tu empresa",
              "Abre el área de <strong>Integraciones</strong> y genera una nueva <strong>clave de API</strong>",
              "Copia la clave (empieza con <strong>$aact_</strong>)"
            ]
          },
          {
            "title": "Conectar en PraticOS",
            "steps": [
              "En la app, abre <strong>Ajustes</strong> > <strong>Integraciones</strong>",
              "En <strong>Pagos</strong>, toca <strong>Asaas</strong>",
              "Pega la clave y toca <strong>Conectar</strong>",
              "La app muestra el nombre de la cuenta y el ambiente (<strong>Prueba</strong> o <strong>Producción</strong>)"
            ]
          }
        ],
        "warningCard": {
          "title": "Guarda la clave con cuidado",
          "content": "La clave da acceso a tu cuenta Asaas. Pégala solo en la app PraticOS: queda cifrada en el servidor y nunca vuelve a mostrarse en la app. Si sospechas de una filtración, genera otra clave en Asaas y conecta de nuevo."
        }
      },
      {
        "id": "cobrar",
        "title": "Cobrar al cliente de la OS",
        "intro": "Dueños, administradores y gerentes pueden generar el cobro directamente en la OS.",
        "subsections": [
          {
            "title": "Generar el cobro",
            "steps": [
              "Abre la OS y toca <strong>Cobrar con Asaas</strong> en el área de pagos",
              "Revisa el valor. Viene con el saldo restante de la OS y puede reducirse para cobrar un anticipo",
              "Elige <strong>Al contado</strong> (el cliente elige Pix, boleto o tarjeta) o <strong>Cuotas con tarjeta</strong> (2 a 12)",
              "Ajusta el vencimiento si hace falta (por defecto, dentro de 3 días)",
              "Si el cliente no tiene CPF o CNPJ registrado, ingrésalo ahora",
              "Toca <strong>Generar cobro</strong>"
            ]
          },
          {
            "title": "Anticipo y saldo",
            "content": "Ejemplo: cobra R$ 300 de anticipo por Pix. Cuando se pague, genera un segundo cobro con los R$ 700 restantes en 3 cuotas con tarjeta."
          }
        ],
        "statusCards": [
          { "color": "blue", "title": "Pendiente", "description": "Cobro generado, esperando el pago del cliente." },
          { "color": "orange", "title": "Vencido", "description": "Pasó el vencimiento sin pago. Genera un nuevo cobro." },
          { "color": "green", "title": "Pagado", "description": "Pago confirmado por Asaas y registrado en la OS." }
        ],
        "infoCard": {
          "title": "Un cobro abierto a la vez",
          "content": "Generar un nuevo cobro cancela el anterior que aún no se pagó. Si el total de la OS cambia, la app avisa y ofrece generarlo de nuevo con el valor actualizado. Cancelar la OS cancela el cobro pendiente."
        }
      },
      {
        "id": "enlace-cliente",
        "title": "Cómo paga el cliente",
        "intro": "El cliente paga desde el mismo enlace de la OS que ya compartes. Asaas no envía e-mail ni SMS al cliente.",
        "subsections": [
          {
            "title": "Pasos del cliente",
            "steps": [
              "En la tarjeta del cobro, toca <strong>Compartir enlace de la OS</strong> y envíalo por WhatsApp",
              "El cliente abre el enlace y ve el botón <strong>Pagar</strong> con el valor",
              "El botón abre la factura de Asaas, donde elige la forma de pago",
              "Al volver al enlace, la OS muestra <strong>Pagado ✓</strong>"
            ]
          }
        ],
        "paragraphs": [
          "Si el cobro vence, el enlace muestra <strong>Cobro vencido. Contacta a la empresa</strong>. Genera un nuevo cobro en la OS.",
          "También puedes copiar el enlace de la factura en la tarjeta del cobro y enviarlo directamente."
        ]
      },
      {
        "id": "baja-automatica",
        "title": "Baja automática en la OS",
        "intro": "Cuando Asaas confirma el pago, PraticOS registra el pago en la OS y actualiza el saldo.",
        "subsections": [
          {
            "title": "Qué sucede",
            "validationList": [
              { "label": "Pago confirmado", "text": "Entra como pago en la OS, con la descripción Asaas • Pix, Asaas • Boleto o Asaas • Cartão" },
              { "label": "Cuotas", "text": "Cada cuota confirmada entra como un pago" },
              { "label": "Reembolso", "text": "Reembolsado en Asaas, el pago sale de la OS y el saldo vuelve" },
              { "label": "Aviso", "text": "Dueño, administradores y gerentes reciben una notificación en el celular" }
            ]
          }
        ],
        "warningCard": {
          "title": "Los pagos de Asaas no se borran en la app",
          "content": "Para deshacer un pago recibido por Asaas, reembolsa el cobro en el panel de Asaas. El reembolso quita el pago de la OS automáticamente."
        }
      },
      {
        "id": "permisos",
        "title": "Permisos",
        "intro": "Quién puede hacer qué en el cobro con Asaas:",
        "table": {
          "headers": ["Perfil", "Conectar cuenta Asaas", "Cobrar en la OS"],
          "rows": [
            { "label": "Administrador", "cells": [{ "class": "yes" }, { "class": "yes" }] },
            { "label": "Gerente", "cells": [{ "class": "no" }, { "class": "yes" }] },
            { "label": "Supervisor", "cells": [{ "class": "no" }, { "class": "no" }] },
            { "label": "Consultor", "cells": [{ "class": "no" }, { "class": "no" }] },
            { "label": "Técnico", "cells": [{ "class": "no" }, { "class": "no" }] }
          ],
          "note": "El dueño de la empresa tiene todos los permisos."
        }
      },
      {
        "id": "faq",
        "title": "Preguntas Frecuentes",
        "faq": [
          { "question": "¿PraticOS cobra comisión sobre los pagos?", "answer": "No. Solo aplican las tarifas de tu cuenta Asaas." },
          { "question": "¿Necesito cuenta en Asaas?", "answer": "Sí. El cobro usa la cuenta Asaas de tu empresa, que debe estar aprobada." },
          { "question": "¿Puedo probar antes de cobrar de verdad?", "answer": "Sí. Una clave del ambiente de pruebas de Asaas (sandbox) conecta en modo Prueba y no se cobra nada de verdad." },
          { "question": "¿El cliente puede elegir el número de cuotas?", "answer": "No. Tú defines de 2 a 12 cuotas al generar el cobro." },
          { "question": "¿Y si desconecto la cuenta?", "answer": "Los cobros abiertos siguen en Asaas, pero los pagos hechos después no se registran automáticamente en la OS. Regístralos manualmente o cancela los cobros en el panel de Asaas." }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Templates (pt/en/es)**

Criar `firebase/hosting/src/docs/cobranca-asaas.njk`:

```njk
---
layout: layouts/docs-article.njk
permalink: /docs/cobranca-asaas.html
lang: pt-BR
langCode: pt
title: Cobrança com Asaas - PraticOS Documentacao
description: Cobre o cliente da OS por Pix, boleto ou cartão pela sua conta Asaas, com botão Pagar no link da OS e baixa automática do pagamento.
keywords: praticos, documentacao, asaas, cobranca, pix, boleto, cartao, parcelado, pagamento
indexPage: ../
faqLink: ../faq.html
supportLink: ../support.html
docsIndexLink: ./
breadcrumbRoot: Documentacao
breadcrumbCurrent: Cobrança com Asaas
heroTitle: Cobrança com
heroTitleHighlight: Asaas
heroSubtitle: Cobre por Pix, boleto ou cartão pela sua conta Asaas. O cliente paga pelo link da OS e o pagamento dá baixa sozinho.
sidebarTitle: Nesta pagina
sidebarNav:
  - id: visao-geral
    label: Visao Geral
  - id: conectar
    label: Conectar Conta
  - id: cobrar
    label: Cobrar na OS
  - id: link-do-cliente
    label: Como o Cliente Paga
  - id: baixa-automatica
    label: Baixa Automatica
  - id: permissoes
    label: Permissoes
  - id: faq
    label: Perguntas Frequentes
prevLink:
  href: financeiro.html
  label: Anterior
  title: Sistema Financeiro
nextLink:
  href: compartilhar.html
  label: Proximo
  title: Compartilhar OS
langSwitch:
  - code: PT
    href: cobranca-asaas.html
    active: true
  - code: EN
    href: cobranca-asaas-en.html
  - code: ES
    href: cobranca-asaas-es.html
relPath: ../
docsData: docs/cobranca-asaas
---
```

Criar `firebase/hosting/src/docs/cobranca-asaas-en.njk`:

```njk
---
layout: layouts/docs-article.njk
permalink: /docs/cobranca-asaas-en.html
lang: en
langCode: en
title: Asaas Charges - PraticOS Documentation
description: Charge your customer by Pix, bank slip or card through your Asaas account, with a Pay button on the order link and automatic payment settlement.
keywords: praticos, documentation, asaas, charges, pix, bank slip, card, installments, payment
indexPage: ../index-en.html
faqLink: ../faq-en.html
supportLink: ../support-en.html
docsIndexLink: index-en.html
breadcrumbRoot: Documentation
breadcrumbCurrent: Asaas Charges
heroTitle: Charges with
heroTitleHighlight: Asaas
heroSubtitle: Charge by Pix, bank slip or card through your Asaas account. The customer pays on the order link and the payment settles itself.
sidebarTitle: On this page
sidebarNav:
  - id: overview
    label: Overview
  - id: connect
    label: Connect Account
  - id: charge
    label: Charge the Customer
  - id: customer-link
    label: How the Customer Pays
  - id: automatic-payment
    label: Automatic Settlement
  - id: permissions
    label: Permissions
  - id: faq
    label: FAQ
prevLink:
  href: financeiro-en.html
  label: Previous
  title: Financial System
nextLink:
  href: compartilhar-en.html
  label: Next
  title: Share Order
langSwitch:
  - code: PT
    href: cobranca-asaas.html
  - code: EN
    href: cobranca-asaas-en.html
    active: true
  - code: ES
    href: cobranca-asaas-es.html
relPath: ../
docsData: docs/cobranca-asaas
---
```

Criar `firebase/hosting/src/docs/cobranca-asaas-es.njk`:

```njk
---
layout: layouts/docs-article.njk
permalink: /docs/cobranca-asaas-es.html
lang: es
langCode: es
title: Cobro con Asaas - Documentacion PraticOS
description: Cobra al cliente de la OS por Pix, boleto o tarjeta con tu cuenta Asaas, con boton Pagar en el enlace de la OS y baja automatica del pago.
keywords: praticos, documentacion, asaas, cobro, pix, boleto, tarjeta, cuotas, pago
indexPage: ../index-es.html
faqLink: ../faq-es.html
supportLink: ../support-es.html
docsIndexLink: index-es.html
breadcrumbRoot: Documentacion
breadcrumbCurrent: Cobro con Asaas
heroTitle: Cobro con
heroTitleHighlight: Asaas
heroSubtitle: Cobra por Pix, boleto o tarjeta con tu cuenta Asaas. El cliente paga desde el enlace de la OS y el pago se registra solo.
sidebarTitle: En esta pagina
sidebarNav:
  - id: vision-general
    label: Vision General
  - id: conectar
    label: Conectar Cuenta
  - id: cobrar
    label: Cobrar en la OS
  - id: enlace-cliente
    label: Como Paga el Cliente
  - id: baja-automatica
    label: Baja Automatica
  - id: permisos
    label: Permisos
  - id: faq
    label: Preguntas Frecuentes
prevLink:
  href: financeiro-es.html
  label: Anterior
  title: Sistema Financiero
nextLink:
  href: compartilhar-es.html
  label: Siguiente
  title: Compartir OS
langSwitch:
  - code: PT
    href: cobranca-asaas.html
  - code: EN
    href: cobranca-asaas-en.html
  - code: ES
    href: cobranca-asaas-es.html
    active: true
relPath: ../
docsData: docs/cobranca-asaas
---
```

Antes de commitar, conferir os títulos reais de `compartilhar*.njk` usados no `nextLink`:

```bash
grep -n "heroTitle\|breadcrumbCurrent" firebase/hosting/src/docs/compartilhar.njk firebase/hosting/src/docs/compartilhar-en.njk firebase/hosting/src/docs/compartilhar-es.njk
```

Se o `breadcrumbCurrent` for diferente de "Compartilhar OS" / "Share Order" / "Compartir OS", usar o valor de lá no `nextLink.title`.

- [ ] **Step 3: Card no hub (`src/_data/docs.json`)**

O arquivo é JSON com indentação de 2 espaços e faz ida e volta idêntica com `json.dumps(..., indent=2, ensure_ascii=False)`. Inserir o card logo depois de "Sistema Financeiro" em cada idioma:

```bash
cd firebase/hosting && python3 - <<'PY'
import json

path = 'src/_data/docs.json'
with open(path, encoding='utf-8') as f:
    data = json.load(f)

icon = ('<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">'
        '<rect x="1" y="4" width="22" height="16" rx="2" ry="2"></rect>'
        '<line x1="1" y1="10" x2="23" y2="10"></line></svg>')

cards = {
    'pt': ('financeiro.html', {
        'title': 'Cobrança com Asaas',
        'description': 'Cobre o cliente da OS por Pix, boleto ou cartão pela sua conta Asaas, com baixa automática do pagamento.',
        'href': 'cobranca-asaas.html',
        'linkText': 'Ver documentação ->',
        'badge': 'Novo',
        'icon': icon,
    }),
    'en': ('financeiro-en.html', {
        'title': 'Asaas Charges',
        'description': 'Charge your customer by Pix, bank slip or card through your Asaas account, with automatic payment settlement.',
        'href': 'cobranca-asaas-en.html',
        'linkText': 'View documentation ->',
        'badge': 'New',
        'icon': icon,
    }),
    'es': ('financeiro-es.html', {
        'title': 'Cobro con Asaas',
        'description': 'Cobra al cliente de la OS por Pix, boleto o tarjeta con tu cuenta Asaas, con baja automática del pago.',
        'href': 'cobranca-asaas-es.html',
        'linkText': 'Ver documentación ->',
        'badge': 'Nuevo',
        'icon': icon,
    }),
}

for lang, (after_href, card) in cards.items():
    categories = data['hub'][lang]['categories']
    if any(c.get('href') == card['href'] for c in categories):
        continue
    index = next(i for i, c in enumerate(categories) if c.get('href') == after_href)
    categories.insert(index + 1, card)

with open(path, 'w', encoding='utf-8') as f:
    f.write(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
PY
git diff --stat src/_data/docs.json
```

Esperado: `src/_data/docs.json | 24 ++++++++++++++++++++++++` (3 cards × 8 linhas), sem outras mudanças.

- [ ] **Step 4: Build e verificação**

```bash
cd firebase/hosting
python3 -m json.tool src/_data/docs/cobranca-asaas.json > /dev/null && echo json-ok
npm ci && npm run build
ls public/docs/cobranca-asaas.html public/docs/cobranca-asaas-en.html public/docs/cobranca-asaas-es.html
grep -c 'class="docs-section"' public/docs/cobranca-asaas.html public/docs/cobranca-asaas-en.html public/docs/cobranca-asaas-es.html
grep -l "cobranca-asaas" public/docs/index.html public/docs/index-en.html public/docs/index-es.html
grep -c "cobranca-asaas" public/sitemap.xml
```

Esperado: `json-ok`; build do Eleventy sem erro (`Wrote N files`); os 3 HTML existem; 7 seções em cada (`:7`); os 3 índices do hub listam o artigo; sitemap com 3 ocorrências. Abrir `public/docs/cobranca-asaas.html` no navegador e conferir: sidebar rola até cada seção, tabela de permissões com ✓/✗, cards de status azul/laranja/verde. `public/` é gitignored, não commitar.

- [ ] **Step 5: Commit**

```bash
git add firebase/hosting/src/_data/docs/cobranca-asaas.json \
        firebase/hosting/src/docs/cobranca-asaas.njk \
        firebase/hosting/src/docs/cobranca-asaas-en.njk \
        firebase/hosting/src/docs/cobranca-asaas-es.njk \
        firebase/hosting/src/_data/docs.json
git commit -m "$(cat <<'EOF'
docs(site): add public article on Asaas charges (pt/en/es)

Covers connecting the Asaas account, charging from the work order, how the
customer pays on the order link, automatic settlement, permissions and FAQ.
Listed in the docs hub after the financial system article.

Refs #303

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task F5: Open PR

- [ ] **Step 1: Verificação final**

```bash
cd firebase/functions && npm run lint && npm test && npm run e2e:asaas
cd ../hosting && npm run build
cd ../.. && grep -n "ASAAS_INTEGRATION" CLAUDE.md
git diff master --stat | tail -1
git diff master | grep -E '\$aact_(prod|hmlg)_[A-Za-z0-9]{8,}' | wc -l
```

Esperado: tudo verde, E2E com `=== Asaas sandbox E2E: OK ===`, link no `CLAUDE.md`, `0` chaves no diff.

- [ ] **Step 2: Push e PR**

```bash
git push -u origin docs/asaas-payments
gh pr create --base master --head docs/asaas-payments --label risk:high \
  --title 'docs(asaas): E2E sandbox, rollout e artigo público da cobrança com Asaas' \
  --body "$(cat <<'EOF'
## Resumo

- `npm run e2e:asaas` (`firebase/functions/scripts/asaas-sandbox-e2e.ts`): valida a chave do sandbox, cria cliente de teste, cobrança `UNDEFINED`, confirma com `POST /v3/sandbox/payment/{id}/confirm` e espera o status pago. Com `-- --with-api`, cria a cobrança pela API do PraticOS e espera o webhook dar baixa na OS (checado no link público). Lê `.env.local` com `process.loadEnvFile` (sem `dotenv`), aborta se a chave não for de sandbox e nunca imprime a chave.
- `npm run asaas:pilot -- --company <id> [--dry-run] [--disable]` (`scripts/enable-asaas-pilot.ts`): liga/desliga `settings/payments.asaasEnabled`.
- `docs/ASAAS_INTEGRATION.md` reescrito: status, arquitetura, endpoints, modelo de dados, webhook, dev com túnel, E2E e rollout (secret `ASAAS_CREDENTIALS_KEY`, `ASAAS_WEBHOOK_BASE_URL`, regras, TTL de `events`, piloto, rollback). `CLAUDE.md` já linkava o doc; descrição atualizada.
- Artigo público "Cobrança com Asaas" em pt/en/es + card no hub de docs.

## Rollout (passos do Rafael, fora do merge)

1. `openssl rand -base64 32 | gcloud secrets create ASAAS_CREDENTIALS_KEY --data-file=- --project praticos`
2. Conferir o default de `ASAAS_WEBHOOK_BASE_URL` no código (o deploy do CI não lê `.env`).
3. `firebase deploy --only firestore:rules --project praticos`
4. `gcloud firestore fields ttls update expiresAt --collection-group=events --enable-ttl --project=praticos`
5. E2E com a conta sandbox da Rafsoft, app novo publicado, depois `npm run asaas:pilot -- --company <id>`.

## Testes

- `cd firebase/functions && npm run lint && npm test && npm run e2e:asaas`
- `cd firebase/hosting && npm run build` (3 páginas novas, hub e sitemap)

Refs #303

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```
