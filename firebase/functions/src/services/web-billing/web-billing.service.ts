/**
 * Web checkout of PraticOS plans (issue #664, docs/WEB_CHECKOUT.md).
 *
 * Asaas (Rafsoft's account) charges through a subscription; each confirmed
 * payment grants the plan as a RevenueCat promotional entitlement until the
 * next due date + WEB_GRACE_DAYS, and syncCompanySubscription writes
 * companies/{cid}.subscription (store 'web'). Everything is off unless
 * config/webCheckout.enabled == true.
 *
 * Firestore (server only, denied to clients by firestore.rules):
 * - companies/{cid}/private/webBilling: WebBillingRecord;
 * - webBillingSubscriptions/{asaasSubscriptionId}: { companyId } (webhook lookup);
 * - webBillingEvents/{eventId}: processed webhook events (idempotency).
 */

import { db } from '../firestore.service';
import type { Subscription } from '../../models/types';
import type { AsaasClient } from '../asaas/asaas-client';
import { AsaasApiError } from '../asaas/asaas-client';
import { isValidTaxId, normalizeTaxId } from '../../utils/tax-id.utils';
import {
  WEB_PRICES,
  checkoutBlock,
  decideBillingAction,
  parseWebCheckoutConfig,
  refundEligible,
  saoPauloDate,
  subscriptionIdOf,
  webOffer,
  type BillingWebhookEvent,
  type WebBillingRecord,
  type WebBillingType,
  type WebCheckoutConfig,
  type WebCycle,
  type WebPlan,
} from './web-billing-rules';
import { readWebBilling, webBillingRef } from './web-origin';

type BillingAsaasClient = Pick<
  AsaasClient,
  | 'findCustomerByExternalReference'
  | 'createCustomer'
  | 'createSubscription'
  | 'listSubscriptionPayments'
  | 'deleteSubscription'
  | 'refundPayment'
>;

export interface WebBillingDeps {
  asaas: BillingAsaasClient;
  environment: 'sandbox' | 'production';
  /** RevenueCat promotional grant (appUserID = companyId, entitlement = plan). */
  grant: (companyId: string, plan: WebPlan, endTimeMs: number) => Promise<void>;
  revoke: (companyId: string, plan: WebPlan) => Promise<void>;
  /** syncCompanySubscription bound to the RevenueCat key. */
  sync: (companyId: string) => Promise<unknown>;
  now?: () => Date;
}

export class WebBillingError extends Error {
  constructor(
    readonly code: string,
    readonly status: number,
    message: string,
  ) {
    super(message);
    this.name = 'WebBillingError';
  }
}

const PLAN_LABEL: Record<WebPlan, string> = { starter: 'Starter', pro: 'Pro', business: 'Business' };
const CYCLE_LABEL: Record<WebCycle, string> = { monthly: 'mensal', yearly: 'anual' };

export async function readWebCheckoutConfig(): Promise<WebCheckoutConfig> {
  const snapshot = await db.collection('config').doc('webCheckout').get();
  return parseWebCheckoutConfig(snapshot.exists ? (snapshot.data() as Record<string, unknown>) : null);
}

async function readCompany(companyId: string): Promise<{ subscription: Subscription | undefined; country: string | null }> {
  const snapshot = await db.collection('companies').doc(companyId).get();
  if (!snapshot.exists) throw new WebBillingError('NOT_FOUND', 404, 'Company not found');
  return {
    subscription: snapshot.get('subscription') as Subscription | undefined,
    country: (snapshot.get('country') as string | undefined) ?? null,
  };
}

// ============================================================================
// GET /v1/app/billing
// ============================================================================

export interface WebBillingView {
  enabled: boolean;
  offer: ReturnType<typeof webOffer> | null;
  /** Why buying is not possible now, or null. */
  block: ReturnType<typeof checkoutBlock>;
  subscription: {
    status: WebBillingRecord['status'];
    plan: WebPlan;
    cycle: WebCycle;
    billingType: WebBillingType;
    value: number;
    paidUntil: string | null;
    nextDueDate: string | null;
    /** Invoice page while the first charge is not paid. */
    checkoutUrl: string | null;
    refundEligible: boolean;
  } | null;
}

/** What the web shows: the offer (only when on), the guard and the company's web subscription. */
export async function billingOverview(companyId: string, now: Date = new Date()): Promise<WebBillingView> {
  const [config, { subscription, country }, record] = await Promise.all([
    readWebCheckoutConfig(),
    readCompany(companyId),
    readWebBilling(companyId),
  ]);
  return {
    enabled: config.enabled,
    offer: config.enabled ? webOffer(config) : null,
    block: checkoutBlock(subscription, record, now, country),
    subscription: record
      ? {
          status: record.status,
          plan: record.plan,
          cycle: record.cycle,
          billingType: record.billingType,
          value: record.value,
          paidUntil: record.paidUntil ?? null,
          nextDueDate: record.status === 'active' ? (record.nextDueDate ?? null) : null,
          checkoutUrl: record.status === 'pending' ? (record.checkoutUrl ?? null) : null,
          refundEligible: refundEligible(record, now),
        }
      : null,
  };
}

// ============================================================================
// POST /v1/app/billing/checkout
// ============================================================================

export interface CheckoutInput {
  plan: WebPlan;
  cycle: WebCycle;
  billingType: WebBillingType;
  name: string;
  taxId: string;
  email: string;
}

function asaasError(error: unknown): never {
  if (error instanceof AsaasApiError && error.status === 400) {
    throw new WebBillingError('VALIDATION_ERROR', 400, 'Asaas rejected the billing data');
  }
  throw new WebBillingError('ASAAS_UNAVAILABLE', 502, 'Asaas is unavailable');
}

/**
 * Creates (or reuses) the company's Asaas customer and a subscription
 * starting today; returns the invoice page of its first charge, where the
 * customer pays with the chosen method. A pending checkout with the same
 * choice is reused; a different one replaces it.
 */
export async function startCheckout(
  companyId: string,
  userId: string,
  input: CheckoutInput,
  deps: WebBillingDeps,
): Promise<{ checkoutUrl: string }> {
  const now = deps.now?.() ?? new Date();
  const config = await readWebCheckoutConfig();
  if (!config.enabled) throw new WebBillingError('WEB_CHECKOUT_DISABLED', 403, 'Web checkout is off');
  if (input.cycle === 'yearly' && !config.yearlyEnabled) {
    throw new WebBillingError('VALIDATION_ERROR', 400, 'Yearly plans are not on sale on the web');
  }
  if (!config.billingTypes[input.cycle].includes(input.billingType)) {
    throw new WebBillingError('VALIDATION_ERROR', 400, 'Payment method not offered for this cycle');
  }
  const taxId = normalizeTaxId(input.taxId);
  if (!isValidTaxId(taxId)) throw new WebBillingError('VALIDATION_ERROR', 400, 'Invalid CPF/CNPJ');

  const [{ subscription, country }, record] = await Promise.all([readCompany(companyId), readWebBilling(companyId)]);
  const block = checkoutBlock(subscription, record, now, country);
  if (block === 'OUTSIDE_BRAZIL') throw new WebBillingError(block, 409, 'Web checkout is only for companies in Brazil');
  if (block) throw new WebBillingError(block, 409, 'The company already has a subscription');

  if (
    record?.status === 'pending' &&
    record.checkoutUrl &&
    record.plan === input.plan &&
    record.cycle === input.cycle &&
    record.billingType === input.billingType
  ) {
    return { checkoutUrl: record.checkoutUrl };
  }

  try {
    if (record?.status === 'pending') {
      await deps.asaas.deleteSubscription(record.asaasSubscriptionId).catch((error: { status?: number }) => {
        if (error?.status !== 404) throw error;
      });
    }

    const reference = `praticos-company:${companyId}`;
    const customer =
      // A sandbox customer id means nothing in production (and the other way round).
      (record?.asaasCustomerId && record.environment === deps.environment ? { id: record.asaasCustomerId } : null) ??
      (await deps.asaas.findCustomerByExternalReference(reference)) ??
      (await deps.asaas.createCustomer({
        name: input.name.trim(),
        cpfCnpj: taxId,
        email: input.email.trim(),
        externalReference: reference,
        // Asaas e-mails the invoices and the Rafsoft NFS-e.
        notificationDisabled: false,
      }));

    const value = WEB_PRICES[input.plan][input.cycle];
    const created = await deps.asaas.createSubscription({
      customer: customer.id,
      billingType: input.billingType,
      value,
      nextDueDate: saoPauloDate(now),
      cycle: input.cycle === 'yearly' ? 'YEARLY' : 'MONTHLY',
      description: `PraticOS ${PLAN_LABEL[input.plan]} (${CYCLE_LABEL[input.cycle]})`,
      externalReference: companyId,
    });
    const payments = await deps.asaas.listSubscriptionPayments(created.id);
    const first = payments.find((payment) => payment.invoiceUrl);
    if (!first) throw new WebBillingError('ASAAS_UNAVAILABLE', 502, 'Asaas did not create the first charge');

    const nowIso = now.toISOString();
    const next: WebBillingRecord = {
      status: 'pending',
      plan: input.plan,
      cycle: input.cycle,
      billingType: input.billingType,
      value,
      environment: deps.environment,
      asaasCustomerId: customer.id,
      asaasSubscriptionId: created.id,
      checkoutUrl: first.invoiceUrl,
      createdAt: nowIso,
      createdBy: userId,
      updatedAt: nowIso,
    };
    const batch = db.batch();
    batch.set(webBillingRef(companyId), next);
    batch.set(db.collection('webBillingSubscriptions').doc(created.id), { companyId, createdAt: nowIso });
    await batch.commit();
    return { checkoutUrl: first.invoiceUrl };
  } catch (error) {
    if (error instanceof WebBillingError) throw error;
    console.error('[WebBilling] checkout failed', { companyId, error: (error as Error).name });
    asaasError(error);
  }
}

// ============================================================================
// POST /v1/app/billing/cancel
// ============================================================================

/**
 * Cancels the web subscription. Without refund: no new charges, the plan
 * lasts until paidUntil. With refund (only inside the 7-day guarantee): every
 * paid charge goes back, the plan drops to Free now.
 */
export async function cancelWebSubscription(
  companyId: string,
  options: { refund: boolean },
  deps: WebBillingDeps,
): Promise<{ status: WebBillingRecord['status'] }> {
  const now = deps.now?.() ?? new Date();
  const record = await readWebBilling(companyId);
  if (!record || record.status === 'refunded') {
    throw new WebBillingError('NOT_FOUND', 404, 'No web subscription');
  }
  if (options.refund && !refundEligible(record, now)) {
    throw new WebBillingError('REFUND_NOT_ALLOWED', 409, 'The 7-day guarantee is over');
  }
  if (!options.refund && record.status === 'cancelled') return { status: 'cancelled' };

  const nowIso = now.toISOString();
  try {
    if (record.status === 'active' || record.status === 'pending') {
      await deps.asaas.deleteSubscription(record.asaasSubscriptionId).catch((error: { status?: number }) => {
        if (error?.status !== 404) throw error;
      });
    }
    if (!options.refund) {
      await webBillingRef(companyId).update({
        status: 'cancelled',
        cancelledAt: nowIso,
        cancelReason: 'customer',
        updatedAt: nowIso,
      });
      if (record.status === 'active') await deps.sync(companyId);
      return { status: 'cancelled' };
    }

    const paid = Object.entries(record.payments ?? {}).filter(([, payment]) => payment.status === 'paid');
    const updates: Record<string, unknown> = {
      status: 'refunded',
      refundedAt: nowIso,
      cancelledAt: record.cancelledAt ?? nowIso,
      cancelReason: 'refund',
      paidUntil: nowIso,
      updatedAt: nowIso,
    };
    // Each refund is saved as soon as Asaas takes it: a retry after a failure in
    // the middle does not refund the same charge twice. A charge Asaas no longer
    // has (404) has nothing to give back.
    for (const [paymentId] of paid) {
      await deps.asaas.refundPayment(paymentId, 'Garantia de 7 dias do PraticOS').catch((error: { status?: number }) => {
        if (error?.status !== 404) throw error;
      });
      await webBillingRef(companyId).update({
        [`payments.${paymentId}.status`]: 'refunded',
        [`payments.${paymentId}.refundedAt`]: nowIso,
        updatedAt: nowIso,
      });
    }
    await webBillingRef(companyId).update(updates);
    await deps.revoke(companyId, record.plan);
    await deps.sync(companyId);
    return { status: 'refunded' };
  } catch (error) {
    if (error instanceof WebBillingError) throw error;
    console.error('[WebBilling] cancel failed', { companyId, refund: options.refund, error: (error as Error).name });
    asaasError(error);
  }
}

// ============================================================================
// POST /webhooks/asaas-billing
// ============================================================================

export type BillingEventResult = 'duplicate' | 'ignored' | 'done';

const eventDocId = (id: string) => id.replace(/\//g, '_').slice(0, 300);

/**
 * Applies one Asaas webhook event. Idempotent by event id (a marker written
 * first, removed again when processing fails so Asaas' retry runs it); the
 * actions themselves are safe to repeat.
 */
export async function handleBillingEvent(event: BillingWebhookEvent, deps: WebBillingDeps): Promise<BillingEventResult> {
  const now = deps.now?.() ?? new Date();
  const marker = db.collection('webBillingEvents').doc(eventDocId(event.id));
  try {
    await marker.create({ event: event.event.slice(0, 64), receivedAt: now.toISOString() });
  } catch (error) {
    if ((error as { code?: number }).code === 6) return 'duplicate';
    throw error;
  }

  try {
    const subscriptionId = subscriptionIdOf(event);
    if (!subscriptionId) return 'ignored';
    const link = await db.collection('webBillingSubscriptions').doc(subscriptionId).get();
    const companyId = link.exists ? (link.get('companyId') as string | undefined) : undefined;
    if (!companyId) return 'ignored';
    const record = await readWebBilling(companyId);
    // A subscription the company replaced (new checkout) no longer moves the plan.
    if (!record || record.asaasSubscriptionId !== subscriptionId) return 'ignored';

    const action = decideBillingAction(event, record);
    const nowIso = now.toISOString();
    const ref = webBillingRef(companyId);

    if (action.kind === 'grant') {
      const endIso = new Date(action.endMs).toISOString();
      const paidUntil = record.paidUntil && record.paidUntil > endIso ? record.paidUntil : endIso;
      await ref.update({
        status: record.status === 'pending' ? 'active' : record.status,
        firstPaidAt: record.firstPaidAt ?? nowIso,
        paidUntil,
        nextDueDate: action.nextDueDate,
        [`payments.${action.paymentId}`]: {
          status: 'paid',
          value: action.value,
          dueDate: action.dueDate,
          paidAt: record.payments?.[action.paymentId]?.paidAt ?? nowIso,
        },
        updatedAt: nowIso,
      });
      await deps.grant(companyId, record.plan, Date.parse(paidUntil));
      await deps.sync(companyId);
    } else if (action.kind === 'revoke') {
      if (record.status === 'active' || record.status === 'pending') {
        await deps.asaas.deleteSubscription(subscriptionId).catch((error: { status?: number }) => {
          if (error?.status !== 404) throw error;
        });
      }
      await ref.update({
        status: 'refunded',
        refundedAt: record.refundedAt ?? nowIso,
        cancelledAt: record.cancelledAt ?? nowIso,
        cancelReason: record.cancelReason === 'refund' ? 'refund' : action.reason,
        paidUntil: record.status === 'refunded' ? (record.paidUntil ?? nowIso) : nowIso,
        [`payments.${action.paymentId}.status`]: 'refunded',
        [`payments.${action.paymentId}.refundedAt`]: nowIso,
        updatedAt: nowIso,
      });
      await deps.revoke(companyId, record.plan);
      await deps.sync(companyId);
    } else if (action.kind === 'markCancelled') {
      await ref.update({ status: 'cancelled', cancelledAt: nowIso, cancelReason: 'asaas', updatedAt: nowIso });
      await deps.sync(companyId);
    } else {
      return 'ignored';
    }
    console.log('[WebBilling] event applied', { companyId, event: event.event, action: action.kind });
    return 'done';
  } catch (error) {
    await marker.delete().catch(() => undefined);
    throw error;
  }
}
