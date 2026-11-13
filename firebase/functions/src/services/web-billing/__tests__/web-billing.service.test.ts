jest.mock('../../firestore.service', () =>
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  require('../../../__tests__/helpers/fake-firestore').fakeFirestoreModule(),
);

import * as firestoreService from '../../firestore.service';
import { FakeFirestore } from '../../../__tests__/helpers/fake-firestore';
import {
  billingOverview,
  cancelWebSubscription,
  handleBillingEvent,
  startCheckout,
  type CheckoutInput,
  type WebBillingDeps,
} from '../web-billing.service';
import type { WebBillingRecord } from '../web-billing-rules';

const fake = (firestoreService as unknown as { __fake: FakeFirestore }).__fake;

const NOW = new Date('2026-11-13T15:00:00.000Z');
const LIMITS = { photosPerMonth: -1, formTemplates: -1, users: 5, ordersPerMonth: -1, pdfWatermark: false };
const USAGE = { photosThisMonth: 0, formTemplatesActive: 0, usersActive: 1, usageResetAt: '2026-12-01T00:00:00.000Z' };
const INPUT: CheckoutInput = {
  plan: 'pro',
  cycle: 'monthly',
  billingType: 'CREDIT_CARD',
  name: 'Oficina Teste',
  taxId: '11.222.333/0001-81',
  email: 'teste@example.com',
  postalCode: '88015-100',
  addressNumber: '100',
};

function deps(overrides: Partial<WebBillingDeps['asaas']> = {}) {
  const asaas = {
    findCustomerByExternalReference: jest.fn().mockResolvedValue(null),
    createCustomer: jest.fn().mockResolvedValue({ id: 'cus_1', name: 'Oficina Teste' }),
    updateCustomer: jest.fn().mockResolvedValue({ id: 'cus_1' }),
    createSubscription: jest.fn().mockResolvedValue({ id: 'sub_1', status: 'ACTIVE' }),
    createSubscriptionInvoiceSettings: jest.fn().mockResolvedValue({}),
    listSubscriptionPayments: jest.fn().mockResolvedValue([{ id: 'pay_1', invoiceUrl: 'https://sandbox.asaas.com/i/pay_1' }]),
    deleteSubscription: jest.fn().mockResolvedValue(undefined),
    refundPayment: jest.fn().mockResolvedValue({ id: 'pay_1', status: 'REFUNDED' }),
    ...overrides,
  };
  return {
    asaas,
    environment: 'sandbox' as const,
    grant: jest.fn().mockResolvedValue(undefined),
    revoke: jest.fn().mockResolvedValue(undefined),
    sync: jest.fn().mockResolvedValue('updated'),
    now: () => NOW,
  };
}

function seedCompany(subscription?: Record<string, unknown>) {
  fake.seed('companies/c1', { name: 'Oficina', ...(subscription ? { subscription } : {}) });
}

const recordOf = () => fake.read('companies/c1/private/webBilling') as WebBillingRecord | undefined;

function seedRecord(partial: Partial<WebBillingRecord> = {}) {
  const record: WebBillingRecord = {
    status: 'active',
    plan: 'pro',
    cycle: 'monthly',
    billingType: 'CREDIT_CARD',
    value: 119.9,
    environment: 'sandbox',
    asaasCustomerId: 'cus_1',
    asaasSubscriptionId: 'sub_1',
    createdAt: '2026-11-10T12:00:00.000Z',
    createdBy: 'u1',
    ...partial,
  };
  fake.seed('companies/c1/private/webBilling', record as unknown as Record<string, unknown>);
  fake.seed('webBillingSubscriptions/sub_1', { companyId: 'c1' });
}

beforeEach(() => {
  fake.reset();
  fake.seed('config/webCheckout', { enabled: true });
});

describe('billingOverview', () => {
  it('no offer while the switch is off', async () => {
    fake.seed('config/webCheckout', { enabled: false });
    seedCompany();
    await expect(billingOverview('c1', NOW)).resolves.toEqual({ enabled: false, offer: null, block: null, subscription: null });
  });

  it('a store subscriber sees the block, a web subscriber the subscription', async () => {
    seedCompany({ plan: 'pro', status: 'active', source: 'store', store: 'play_store', expiresAt: '2026-12-01T00:00:00Z', limits: LIMITS, usage: USAGE });
    expect((await billingOverview('c1', NOW)).block).toBe('STORE_SUBSCRIPTION_ACTIVE');

    seedCompany({ plan: 'pro', status: 'active', source: 'store', store: 'web', limits: LIMITS, usage: USAGE });
    seedRecord({ firstPaidAt: '2026-11-12T00:00:00Z', paidUntil: '2026-12-18T03:00:00.000Z', nextDueDate: '2026-12-12', checkoutUrl: 'https://x' });
    const view = await billingOverview('c1', NOW);
    expect(view.block).toBe('WEB_SUBSCRIPTION_ACTIVE');
    expect(view.subscription).toEqual({
      status: 'active',
      plan: 'pro',
      cycle: 'monthly',
      billingType: 'CREDIT_CARD',
      value: 119.9,
      paidUntil: '2026-12-18T03:00:00.000Z',
      nextDueDate: '2026-12-12',
      checkoutUrl: null,
      refundEligible: true,
    });
  });
});

describe('startCheckout', () => {
  it('refuses while the switch is off', async () => {
    fake.seed('config/webCheckout', { enabled: false });
    seedCompany();
    const d = deps();
    await expect(startCheckout('c1', 'u1', INPUT, d)).rejects.toMatchObject({ code: 'WEB_CHECKOUT_DISABLED', status: 403 });
    expect(d.asaas.createSubscription).not.toHaveBeenCalled();
  });

  it('refuses yearly without store parity and a method not offered', async () => {
    seedCompany();
    await expect(startCheckout('c1', 'u1', { ...INPUT, cycle: 'yearly', billingType: 'PIX' }, deps())).rejects.toMatchObject({
      code: 'VALIDATION_ERROR',
    });
    await expect(startCheckout('c1', 'u1', { ...INPUT, billingType: 'PIX' }, deps())).rejects.toMatchObject({ code: 'VALIDATION_ERROR' });
    await expect(startCheckout('c1', 'u1', { ...INPUT, taxId: '111.111.111-11' }, deps())).rejects.toMatchObject({
      code: 'VALIDATION_ERROR',
    });
  });

  it('never charges a company outside Brazil (it subscribes in the app)', async () => {
    fake.seed('companies/c1', { name: 'Shop', country: 'US' });
    expect((await billingOverview('c1', NOW)).block).toBe('OUTSIDE_BRAZIL');
    const d = deps();
    await expect(startCheckout('c1', 'u1', INPUT, d)).rejects.toMatchObject({ code: 'OUTSIDE_BRAZIL', status: 409 });
    expect(d.asaas.createCustomer).not.toHaveBeenCalled();
  });

  it('never charges a store subscriber', async () => {
    seedCompany({ plan: 'starter', status: 'active', source: 'store', store: 'app_store', expiresAt: '2026-12-01T00:00:00Z', limits: LIMITS, usage: USAGE });
    const d = deps();
    await expect(startCheckout('c1', 'u1', INPUT, d)).rejects.toMatchObject({ code: 'STORE_SUBSCRIPTION_ACTIVE', status: 409 });
    expect(d.asaas.createCustomer).not.toHaveBeenCalled();
  });

  it('creates customer and subscription and returns the invoice page', async () => {
    seedCompany();
    const d = deps();
    await expect(startCheckout('c1', 'u1', INPUT, d)).resolves.toEqual({ checkoutUrl: 'https://sandbox.asaas.com/i/pay_1' });
    expect(d.asaas.createCustomer).toHaveBeenCalledWith(
      expect.objectContaining({
        cpfCnpj: '11222333000181',
        externalReference: 'praticos-company:c1',
        notificationDisabled: false,
        postalCode: '88015100',
        addressNumber: '100',
      }),
    );
    expect(d.asaas.createSubscription).toHaveBeenCalledWith({
      customer: 'cus_1',
      billingType: 'CREDIT_CARD',
      value: 119.9,
      nextDueDate: '2026-11-13',
      cycle: 'MONTHLY',
      description: 'PraticOS Pro (mensal)',
      externalReference: 'c1',
    });
    expect(recordOf()).toMatchObject({ status: 'pending', plan: 'pro', asaasSubscriptionId: 'sub_1', createdBy: 'u1' });
    expect(fake.read('webBillingSubscriptions/sub_1')).toMatchObject({ companyId: 'c1' });
  });

  it('sets up the Rafsoft NFS-e on the subscription from config/webCheckout.invoice', async () => {
    fake.seed('config/webCheckout', { enabled: true, invoice: { municipalServiceId: 'svc_1', municipalServiceName: 'Licenciamento', iss: 2 } });
    seedCompany();
    const d = deps();
    await startCheckout('c1', 'u1', INPUT, d);
    expect(d.asaas.createSubscriptionInvoiceSettings).toHaveBeenCalledWith(
      'sub_1',
      expect.objectContaining({
        municipalServiceId: 'svc_1',
        effectiveDatePeriod: 'ON_PAYMENT_CONFIRMATION',
        receivedOnly: true,
        taxes: expect.objectContaining({ iss: 2, retainIss: false }),
      }),
    );
    expect(recordOf()).toMatchObject({ invoiceSettings: 'ok' });
  });

  it('no invoice config: sells, without NFS-e settings, and says so', async () => {
    seedCompany();
    const d = deps();
    await startCheckout('c1', 'u1', INPUT, d);
    expect(d.asaas.createSubscriptionInvoiceSettings).not.toHaveBeenCalled();
    expect(recordOf()).toMatchObject({ status: 'pending', invoiceSettings: 'off' });
  });

  it('a failure setting up the NFS-e never blocks the sale', async () => {
    fake.seed('config/webCheckout', { enabled: true, invoice: { municipalServiceId: 'svc_1', municipalServiceName: 'Licenciamento', iss: 2 } });
    seedCompany();
    const d = deps({ createSubscriptionInvoiceSettings: jest.fn().mockRejectedValue(Object.assign(new Error('x'), { status: 400 })) });
    await expect(startCheckout('c1', 'u1', INPUT, d)).resolves.toEqual({ checkoutUrl: 'https://sandbox.asaas.com/i/pay_1' });
    expect(recordOf()).toMatchObject({ status: 'pending', invoiceSettings: 'failed' });
  });

  it('yearly with Pix when on sale', async () => {
    fake.seed('config/webCheckout', { enabled: true, yearlyEnabled: true });
    seedCompany();
    const d = deps();
    await startCheckout('c1', 'u1', { ...INPUT, plan: 'business', cycle: 'yearly', billingType: 'PIX' }, d);
    expect(d.asaas.createSubscription).toHaveBeenCalledWith(expect.objectContaining({ value: 2499, cycle: 'YEARLY', billingType: 'PIX' }));
  });

  it('sends the customer back to the web after paying when returnUrl is set', async () => {
    fake.seed('config/webCheckout', { enabled: true, returnUrl: 'https://praticos.app/web/settings/plan?paid=1' });
    seedCompany();
    const d = deps();
    await startCheckout('c1', 'u1', INPUT, d);
    expect(d.asaas.createSubscription).toHaveBeenCalledWith(
      expect.objectContaining({ callback: { successUrl: 'https://praticos.app/web/settings/plan?paid=1', autoRedirect: true } }),
    );
  });

  it('reuses a pending checkout with the same choice, replaces a different one', async () => {
    seedCompany();
    seedRecord({ status: 'pending', checkoutUrl: 'https://sandbox.asaas.com/i/old' });
    const same = deps();
    await expect(startCheckout('c1', 'u1', INPUT, same)).resolves.toEqual({ checkoutUrl: 'https://sandbox.asaas.com/i/old' });
    expect(same.asaas.createSubscription).not.toHaveBeenCalled();

    const other = deps({ createSubscription: jest.fn().mockResolvedValue({ id: 'sub_2' }) });
    await startCheckout('c1', 'u1', { ...INPUT, plan: 'starter' }, other);
    expect(other.asaas.deleteSubscription).toHaveBeenCalledWith('sub_1');
    expect(other.asaas.createCustomer).not.toHaveBeenCalled();
    // The customer is reused with the e-mail and address typed now (the NFS-e uses them).
    expect(other.asaas.updateCustomer).toHaveBeenCalledWith('cus_1', { email: 'teste@example.com', postalCode: '88015100', addressNumber: '100' });
    expect(recordOf()).toMatchObject({ plan: 'starter', value: 59.9, asaasSubscriptionId: 'sub_2' });
  });

  it('CEP with other than 8 digits or no number is refused before Asaas', async () => {
    seedCompany();
    const d = deps();
    await expect(startCheckout('c1', 'u1', { ...INPUT, postalCode: '8801' }, d)).rejects.toMatchObject({ code: 'VALIDATION_ERROR' });
    await expect(startCheckout('c1', 'u1', { ...INPUT, addressNumber: ' ' }, d)).rejects.toMatchObject({ code: 'VALIDATION_ERROR' });
    expect(d.asaas.createCustomer).not.toHaveBeenCalled();
  });

  it('Asaas refusing the data is a validation error', async () => {
    seedCompany();
    const { AsaasApiError } = jest.requireActual('../../asaas/asaas-client');
    const d = deps({ createCustomer: jest.fn().mockRejectedValue(new AsaasApiError(400, [], '/customers')) });
    await expect(startCheckout('c1', 'u1', INPUT, d)).rejects.toMatchObject({ code: 'VALIDATION_ERROR', status: 400 });
    expect(recordOf()).toBeUndefined();
  });
});

describe('handleBillingEvent', () => {
  const confirmed = { id: 'evt_1', event: 'PAYMENT_CONFIRMED', payment: { id: 'pay_1', subscription: 'sub_1', value: 119.9, dueDate: '2026-11-13' } };

  it('first payment: active, guarantee starts, plan granted until next due + 5 days, synced', async () => {
    seedCompany();
    seedRecord({ status: 'pending' });
    const d = deps();
    await expect(handleBillingEvent(confirmed, d)).resolves.toBe('done');
    expect(d.grant).toHaveBeenCalledWith('c1', 'pro', Date.parse('2026-12-19T03:00:00.000Z'));
    expect(d.sync).toHaveBeenCalledWith('c1');
    expect(recordOf()).toMatchObject({
      status: 'active',
      firstPaidAt: NOW.toISOString(),
      paidUntil: '2026-12-19T03:00:00.000Z',
      nextDueDate: '2026-12-13',
      payments: { pay_1: { status: 'paid', value: 119.9, dueDate: '2026-11-13' } },
    });
  });

  it('the same event twice is processed once', async () => {
    seedCompany();
    seedRecord({ status: 'pending' });
    const d = deps();
    await handleBillingEvent(confirmed, d);
    await expect(handleBillingEvent(confirmed, d)).resolves.toBe('duplicate');
    expect(d.grant).toHaveBeenCalledTimes(1);
  });

  it('renewal extends; the guarantee keeps the first payment date', async () => {
    seedCompany();
    seedRecord({ firstPaidAt: '2026-10-13T12:00:00.000Z', paidUntil: '2026-11-19T03:00:00.000Z' });
    const d = deps();
    await handleBillingEvent({ ...confirmed, id: 'evt_9', payment: { ...confirmed.payment, id: 'pay_2' } }, d);
    expect(recordOf()).toMatchObject({ firstPaidAt: '2026-10-13T12:00:00.000Z', paidUntil: '2026-12-19T03:00:00.000Z' });
  });

  it('a failure lets Asaas retry the event', async () => {
    seedCompany();
    seedRecord({ status: 'pending' });
    const d = deps();
    d.grant.mockRejectedValueOnce(new Error('RevenueCat down'));
    await expect(handleBillingEvent(confirmed, d)).rejects.toThrow('RevenueCat down');
    await expect(handleBillingEvent(confirmed, d)).resolves.toBe('done');
  });

  it('refund revokes now and stops the recurrence', async () => {
    seedCompany();
    seedRecord({ firstPaidAt: '2026-11-12T00:00:00Z', payments: { pay_1: { status: 'paid', value: 119.9, dueDate: '2026-11-13' } } });
    const d = deps();
    await handleBillingEvent({ ...confirmed, id: 'evt_r', event: 'PAYMENT_REFUNDED' }, d);
    expect(d.revoke).toHaveBeenCalledWith('c1', 'pro');
    expect(d.asaas.deleteSubscription).toHaveBeenCalledWith('sub_1');
    expect(recordOf()).toMatchObject({ status: 'refunded', cancelReason: 'refund', payments: { pay_1: { status: 'refunded' } } });
    // A late confirmation of the refunded payment does not give the plan back.
    await handleBillingEvent({ ...confirmed, id: 'evt_late', event: 'PAYMENT_RECEIVED' }, d);
    expect(d.grant).not.toHaveBeenCalled();
  });

  it('subscription deleted in Asaas: cancelled, plan kept until paidUntil', async () => {
    seedCompany();
    seedRecord({ paidUntil: '2026-12-19T03:00:00.000Z' });
    const d = deps();
    await handleBillingEvent({ id: 'evt_d', event: 'SUBSCRIPTION_DELETED', subscription: { id: 'sub_1' } }, d);
    expect(d.revoke).not.toHaveBeenCalled();
    expect(recordOf()).toMatchObject({ status: 'cancelled', cancelReason: 'asaas', paidUntil: '2026-12-19T03:00:00.000Z' });
  });

  it('ignores other Rafsoft charges, unknown and replaced subscriptions, and overdue', async () => {
    seedCompany();
    seedRecord();
    const d = deps();
    await expect(handleBillingEvent({ id: 'e1', event: 'PAYMENT_CONFIRMED', payment: { id: 'p', dueDate: '2026-11-13' } }, d)).resolves.toBe('ignored');
    await expect(handleBillingEvent({ ...confirmed, id: 'e2', payment: { ...confirmed.payment, subscription: 'sub_x' } }, d)).resolves.toBe('ignored');
    fake.seed('webBillingSubscriptions/sub_old', { companyId: 'c1' });
    await expect(handleBillingEvent({ ...confirmed, id: 'e3', payment: { ...confirmed.payment, subscription: 'sub_old' } }, d)).resolves.toBe('ignored');
    await expect(handleBillingEvent({ ...confirmed, id: 'e4', event: 'PAYMENT_OVERDUE' }, d)).resolves.toBe('ignored');
    expect(d.grant).not.toHaveBeenCalled();
  });
});

describe('cancelWebSubscription', () => {
  it('cancel: no new charges, plan lasts until the paid date', async () => {
    seedCompany();
    seedRecord({ firstPaidAt: '2026-10-01T00:00:00Z', paidUntil: '2026-12-19T03:00:00.000Z' });
    const d = deps();
    await expect(cancelWebSubscription('c1', { refund: false }, d)).resolves.toEqual({ status: 'cancelled' });
    expect(d.asaas.deleteSubscription).toHaveBeenCalledWith('sub_1');
    expect(d.revoke).not.toHaveBeenCalled();
    expect(d.sync).toHaveBeenCalledWith('c1');
    expect(recordOf()).toMatchObject({ status: 'cancelled', cancelReason: 'customer', paidUntil: '2026-12-19T03:00:00.000Z' });
  });

  it('refund within 7 days: money back, plan revoked now', async () => {
    seedCompany();
    seedRecord({ firstPaidAt: '2026-11-10T00:00:00Z', payments: { pay_1: { status: 'paid', value: 119.9, dueDate: '2026-11-10' } } });
    const d = deps();
    await expect(cancelWebSubscription('c1', { refund: true }, d)).resolves.toEqual({ status: 'refunded' });
    expect(d.asaas.refundPayment).toHaveBeenCalledWith('pay_1', expect.any(String));
    expect(d.revoke).toHaveBeenCalledWith('c1', 'pro');
    expect(recordOf()).toMatchObject({ status: 'refunded', paidUntil: NOW.toISOString(), payments: { pay_1: { status: 'refunded' } } });
  });

  it('refund that fails in the middle: the retry does not refund the same charge twice', async () => {
    seedCompany();
    seedRecord({
      firstPaidAt: '2026-11-10T00:00:00Z',
      payments: {
        pay_1: { status: 'paid', value: 119.9, dueDate: '2026-11-10' },
        pay_2: { status: 'paid', value: 119.9, dueDate: '2026-12-10' },
      },
    });
    const failing = deps({
      refundPayment: jest.fn().mockImplementation(async (id: string) => {
        if (id === 'pay_2') throw Object.assign(new Error('down'), { name: 'AsaasApiError', status: 503 });
        return { id, status: 'REFUNDED' };
      }),
    });
    await expect(cancelWebSubscription('c1', { refund: true }, failing)).rejects.toMatchObject({ code: 'ASAAS_UNAVAILABLE' });
    expect(recordOf()).toMatchObject({ status: 'active', payments: { pay_1: { status: 'refunded' }, pay_2: { status: 'paid' } } });
    expect(failing.revoke).not.toHaveBeenCalled();

    const retry = deps();
    await expect(cancelWebSubscription('c1', { refund: true }, retry)).resolves.toEqual({ status: 'refunded' });
    expect(retry.asaas.refundPayment).toHaveBeenCalledTimes(1);
    expect(retry.asaas.refundPayment).toHaveBeenCalledWith('pay_2', expect.any(String));
    expect(retry.revoke).toHaveBeenCalledWith('c1', 'pro');
  });

  it('refund of a charge Asaas no longer has (404) goes on', async () => {
    seedCompany();
    seedRecord({ firstPaidAt: '2026-11-10T00:00:00Z', payments: { pay_1: { status: 'paid', value: 119.9, dueDate: '2026-11-10' } } });
    const d = deps({ refundPayment: jest.fn().mockRejectedValue(Object.assign(new Error('gone'), { status: 404 })) });
    await expect(cancelWebSubscription('c1', { refund: true }, d)).resolves.toEqual({ status: 'refunded' });
    expect(recordOf()).toMatchObject({ status: 'refunded', payments: { pay_1: { status: 'refunded' } } });
  });

  it('refund also right after a plain cancel, while the 7 days last', async () => {
    seedCompany();
    seedRecord({ status: 'cancelled', firstPaidAt: '2026-11-10T00:00:00Z', payments: { pay_1: { status: 'paid', value: 119.9, dueDate: '2026-11-10' } } });
    const d = deps();
    await expect(cancelWebSubscription('c1', { refund: true }, d)).resolves.toEqual({ status: 'refunded' });
    expect(d.asaas.deleteSubscription).not.toHaveBeenCalled();
  });

  it('no refund after 7 days; nothing to cancel without a web subscription', async () => {
    seedCompany();
    seedRecord({ firstPaidAt: '2026-11-01T00:00:00Z' });
    await expect(cancelWebSubscription('c1', { refund: true }, deps())).rejects.toMatchObject({ code: 'REFUND_NOT_ALLOWED' });
    fake.reset();
    seedCompany();
    await expect(cancelWebSubscription('c1', { refund: false }, deps())).rejects.toMatchObject({ code: 'NOT_FOUND' });
  });
});

describe('nota of the subscription by PraticOS (config/webCheckout.invoiceSource)', () => {
  const ASAAS_INVOICE = { municipalServiceId: 'svc_1', municipalServiceName: 'Licenciamento', iss: 2 };
  const PRATICOS = { enabled: true, invoice: ASAAS_INVOICE, invoiceSource: 'praticos', invoiceIssuerCompanyId: 'issuer' };
  const REQUEST = 'companies/issuer/private/nfse/chargeInvoices/webBilling-pay_1';
  const confirmed = { id: 'evt_1', event: 'PAYMENT_CONFIRMED', payment: { id: 'pay_1', subscription: 'sub_1', value: 119.9, dueDate: '2026-11-13' } };
  const praticosRecord: Partial<WebBillingRecord> = {
    status: 'pending',
    invoiceSource: 'praticos',
    invoiceIssuer: { companyId: 'issuer' },
    invoiceRecipient: { name: 'Oficina Teste', taxId: '11222333000181', email: 'teste@example.com' },
  };

  beforeEach(() => {
    jest.spyOn(console, 'log').mockImplementation(() => undefined);
    jest.spyOn(console, 'warn').mockImplementation(() => undefined);
  });
  afterEach(() => jest.restoreAllMocks());

  it('starts on Asaas: without the key, Asaas issues and nothing is asked of PraticOS', async () => {
    fake.seed('config/webCheckout', { enabled: true, invoice: ASAAS_INVOICE });
    seedCompany();
    const d = deps();
    await startCheckout('c1', 'u1', INPUT, d);
    expect(d.asaas.createSubscriptionInvoiceSettings).toHaveBeenCalled();
    expect(recordOf()).toMatchObject({ invoiceSource: 'asaas', invoiceSettings: 'ok', invoiceIssuer: null });

    await handleBillingEvent(confirmed, d);
    expect(fake.read(REQUEST)).toBeUndefined();
  });

  it('praticos, but the issuer has no NFS-e direct on: Asaas keeps issuing (never a sale without a nota)', async () => {
    fake.seed('config/webCheckout', PRATICOS);
    fake.seed('companies/issuer/settings/payments', { nfseDirectEnabled: false });
    seedCompany();
    const d = deps();
    await startCheckout('c1', 'u1', INPUT, d);
    expect(d.asaas.createSubscriptionInvoiceSettings).toHaveBeenCalled();
    expect(recordOf()).toMatchObject({ invoiceSource: 'asaas' });
  });

  it('praticos on: no Asaas invoice settings (never two notas), the record keeps issuer and recipient', async () => {
    fake.seed('config/webCheckout', { ...PRATICOS, invoiceIssuerEmitterId: 'e1' });
    fake.seed('companies/issuer/settings/payments', { nfseDirectEnabled: true });
    seedCompany();
    const d = deps();
    await startCheckout('c1', 'u1', INPUT, d);
    expect(d.asaas.createSubscriptionInvoiceSettings).not.toHaveBeenCalled();
    expect(recordOf()).toMatchObject({
      invoiceSource: 'praticos',
      invoiceSettings: 'off',
      invoiceIssuer: { companyId: 'issuer', emitterId: 'e1' },
      invoiceRecipient: { name: 'Oficina Teste', taxId: '11222333000181', email: 'teste@example.com' },
    });
  });

  it('paid → asks the issuer for the nota of that payment, once (CONFIRMED then RECEIVED)', async () => {
    seedCompany();
    seedRecord(praticosRecord);
    const d = deps();
    await handleBillingEvent(confirmed, d);
    await handleBillingEvent({ ...confirmed, id: 'evt_2', event: 'PAYMENT_RECEIVED' }, d);
    expect(fake.read(REQUEST)).toMatchObject({
      status: 'pending',
      charge: { key: 'webBilling-pay_1', source: 'webBilling', paymentId: 'pay_1' },
      payerCompanyId: 'c1',
      value: 119.9,
      description: 'Assinatura do sistema PraticOS, plano Pro (mensal), vencimento 13/11/2026',
      recipient: { name: 'Oficina Teste', taxId: '11222333000181', email: 'teste@example.com' },
      emitterId: null,
    });
    expect(d.grant).toHaveBeenCalledTimes(2);
  });

  it('paid by a subscriber in Brazil: the payment records the nota as requested', async () => {
    seedCompany();
    seedRecord(praticosRecord);
    await handleBillingEvent(confirmed, deps());
    expect(recordOf()!.payments!.pay_1).toMatchObject({ status: 'paid', invoice: 'requested' });
  });

  it('subscriber outside Brazil: payment recorded without a nota, no error, no retry', async () => {
    const error = jest.spyOn(console, 'error').mockImplementation(() => undefined);
    fake.seed('companies/c1', { name: 'Shop', country: 'PT' });
    seedRecord(praticosRecord);
    const d = deps();
    await expect(handleBillingEvent(confirmed, d)).resolves.toBe('done');
    expect(fake.read(REQUEST)).toBeUndefined();
    expect(recordOf()).toMatchObject({ status: 'active', payments: { pay_1: { status: 'paid', invoice: 'abroad' } } });
    expect(d.grant).toHaveBeenCalled();
    expect(error).not.toHaveBeenCalled();
    // The renewal does the same; a refund has no nota to cancel.
    await handleBillingEvent({ ...confirmed, id: 'evt_r', event: 'PAYMENT_REFUNDED' }, d);
    expect(fake.read(REQUEST)).toBeUndefined();
  });

  it('a recipient without a Brazilian CPF/CNPJ counts as outside Brazil', async () => {
    seedCompany();
    seedRecord({ ...praticosRecord, invoiceRecipient: { name: 'Foreign Ltd', taxId: '123456789', email: null } });
    await expect(handleBillingEvent(confirmed, deps())).resolves.toBe('done');
    expect(fake.read(REQUEST)).toBeUndefined();
    expect(recordOf()!.payments!.pay_1).toMatchObject({ invoice: 'abroad' });
  });

  it('a subscription sold with Asaas notas stays on Asaas after the key changes', async () => {
    fake.seed('config/webCheckout', PRATICOS);
    seedCompany();
    seedRecord({ status: 'pending', invoiceSource: 'asaas', invoiceSettings: 'ok' });
    await handleBillingEvent(confirmed, deps());
    expect(fake.read(REQUEST)).toBeUndefined();
  });

  it('refund → the nota of that payment is canceled; a chargeback keeps it', async () => {
    seedCompany();
    seedRecord(praticosRecord);
    const d = deps();
    await handleBillingEvent(confirmed, d);
    // As if the nfse-api had issued it.
    fake.seed(REQUEST, { ...fake.read(REQUEST)!, status: 'done', invoiceId: 'inv_1' });

    await handleBillingEvent({ ...confirmed, id: 'evt_cb', event: 'PAYMENT_CHARGEBACK_REQUESTED' }, d);
    expect(fake.read(REQUEST)!.cancel).toBeUndefined();

    await handleBillingEvent({ ...confirmed, id: 'evt_r', event: 'PAYMENT_REFUNDED' }, d);
    expect(fake.read(REQUEST)).toMatchObject({ cancel: { status: 'pending', reason: 'refund' } });
  });
});
