jest.mock('../../firestore.service', () => jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock);
jest.mock('../../notification.service', () => ({
  notifyAsaasPaymentReceived: jest.fn().mockResolvedValue(undefined),
}));

import { fakeDb, read, resetFakeDb, seed as seedDoc } from '../../../__tests__/helpers/fake-firestore';
import { handleAsaasEvent, parseExternalReference } from '../webhook.service';
import { notifyAsaasPaymentReceived } from '../../notification.service';
import type { AsaasPaymentEvent, AsaasWebhookEvent, OrderCharge } from '../../../models/asaas.types';

const mockNotify = notifyAsaasPaymentReceived as jest.Mock;
const ORDER_PATH = 'companies/c1/orders/o1';
const CHARGE_PATH = `${ORDER_PATH}/charges/ch1`;
const EVENTS_COLLECTION = 'companies/c1/private/asaas/events';
const EVENTS_PREFIX = `${EVENTS_COLLECTION}/`;

function data(path: string) {
  return read(path)!;
}

function events() {
  return fakeDb.list(EVENTS_COLLECTION);
}

function seed(charge: Partial<OrderCharge> = {}) {
  seedDoc(ORDER_PATH, { number: 42, total: 1000, paidAmount: 0, paid: false, payment: 'unpaid', transactions: [] });
  seedDoc(CHARGE_PATH, {
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
    expect(parseExternalReference(undefined)).toBeNull();
    expect(parseExternalReference('c1:o1')).toBeNull();
    expect(parseExternalReference('c1::ch1')).toBeNull();
    expect(parseExternalReference('c1:o1:ch1:x')).toBeNull();
  });
});

describe('webhook.service - handleAsaasEvent', () => {
  let errorSpy: jest.SpyInstance;
  let warnSpy: jest.SpyInstance;
  let logSpy: jest.SpyInstance;

  beforeEach(() => {
    resetFakeDb();
    mockNotify.mockClear();
    errorSpy = jest.spyOn(console, 'error').mockImplementation(() => undefined);
    warnSpy = jest.spyOn(console, 'warn').mockImplementation(() => undefined);
    logSpy = jest.spyOn(console, 'log').mockImplementation(() => undefined);
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('PAYMENT_RECEIVED lança na OS, notifica e grava o evento com TTL de 30 dias', async () => {
    seed();
    const ev = event('PAYMENT_RECEIVED', {}, 'evt_05b7&368604920');

    await handleAsaasEvent('c1', ev);

    expect(data(ORDER_PATH).payment).toBe('paid');
    expect(mockNotify).toHaveBeenCalledWith('c1', 'o1', 1000);
    const stored = data(`${EVENTS_PREFIX}evt_05b7&368604920`);
    const processedAt = Date.parse(stored.processedAt as string);
    const expiresAt = (stored.expiresAt as { seconds: number }).seconds * 1000;
    expect(Math.round((expiresAt - processedAt) / 86_400_000)).toBe(30);
  });

  it('evento repetido (mesmo id) não reprocessa', async () => {
    seed();
    const ev = event('PAYMENT_RECEIVED');

    await handleAsaasEvent('c1', ev);
    // Simulate the booking being removed: a reprocessed event would re-add it.
    seedDoc(CHARGE_PATH, { ...data(CHARGE_PATH), paidAsaasPaymentIds: [] });
    seedDoc(ORDER_PATH, { ...data(ORDER_PATH), transactions: [] });
    await handleAsaasEvent('c1', ev);

    expect(mockNotify).toHaveBeenCalledTimes(1);
    expect(data(ORDER_PATH).transactions).toEqual([]);
  });

  it('falha no processamento não grava o evento (Asaas reenvia) e o reenvio lança', async () => {
    seed();
    const ev = event('PAYMENT_RECEIVED');
    jest.spyOn(fakeDb, 'runTransaction').mockRejectedValueOnce(new Error('UNAVAILABLE'));

    await expect(handleAsaasEvent('c1', ev)).rejects.toThrow('UNAVAILABLE');
    expect(events()).toHaveLength(0);
    expect(mockNotify).not.toHaveBeenCalled();

    await handleAsaasEvent('c1', ev);
    expect(data(ORDER_PATH).transactions).toHaveLength(1);
    expect(mockNotify).toHaveBeenCalledTimes(1);
    expect(events()).toHaveLength(1);
  });

  it('falha no estorno não grava o evento', async () => {
    seed();
    await handleAsaasEvent('c1', event('PAYMENT_RECEIVED'));
    jest.spyOn(fakeDb, 'runTransaction').mockRejectedValueOnce(new Error('ABORTED'));

    await expect(handleAsaasEvent('c1', event('PAYMENT_REFUNDED', { status: 'REFUNDED' }))).rejects.toThrow('ABORTED');
    expect(events()).toHaveLength(1);
    expect(data(ORDER_PATH).paidAmount).toBe(1000);
  });

  it('cartão: CONFIRMED e depois RECEIVED lançam uma vez só', async () => {
    seed();
    await handleAsaasEvent('c1', event('PAYMENT_CONFIRMED', { billingType: 'CREDIT_CARD', status: 'CONFIRMED' }));
    await handleAsaasEvent('c1', event('PAYMENT_RECEIVED', { billingType: 'CREDIT_CARD' }));

    expect(data(ORDER_PATH).transactions).toHaveLength(1);
    expect(mockNotify).toHaveBeenCalledTimes(1);
    expect(events()).toHaveLength(2);
  });

  it('ignora externalReference de outra empresa, mas registra o evento', async () => {
    seed();
    seedDoc('companies/c2/orders/o1/charges/ch1', { asaasPaymentId: 'pay_1', paidAsaasPaymentIds: [] });

    await handleAsaasEvent('c1', event('PAYMENT_RECEIVED', { externalReference: 'c2:o1:ch1' }));

    expect(data(ORDER_PATH).transactions).toEqual([]);
    expect(data('companies/c2/orders/o1/charges/ch1').paidAsaasPaymentIds).toEqual([]);
    expect(mockNotify).not.toHaveBeenCalled();
    expect(events()).toHaveLength(1);
  });

  it('cobrança referenciada inexistente: alerta sem payload, registra o evento e retorna', async () => {
    seed();
    const ev = event('PAYMENT_RECEIVED', { externalReference: 'c1:o1:gone' });

    await expect(handleAsaasEvent('c1', ev)).resolves.toBeUndefined();

    expect(errorSpy).toHaveBeenCalledTimes(1);
    const logged = JSON.stringify(errorSpy.mock.calls[0]);
    expect(logged).toContain('gone');
    expect(logged).toContain('PAYMENT_RECEIVED');
    expect(logged).not.toContain('OS #42');
    expect(logged).not.toContain('990');
    expect(data(ORDER_PATH).transactions).toEqual([]);
    expect(events()).toHaveLength(1);
  });

  it('ignora pagamento que não pertence à cobrança referenciada', async () => {
    seed();
    await handleAsaasEvent('c1', event('PAYMENT_RECEIVED', { id: 'pay_other' }));
    expect(data(ORDER_PATH).transactions).toEqual([]);
    expect(mockNotify).not.toHaveBeenCalled();
  });

  it('PAYMENT_OVERDUE marca overdue só quando pendente', async () => {
    seed();
    await handleAsaasEvent('c1', event('PAYMENT_OVERDUE', { status: 'OVERDUE' }));
    expect(data(CHARGE_PATH).status).toBe('overdue');

    seed({ status: 'paid' });
    await handleAsaasEvent('c1', event('PAYMENT_OVERDUE', { status: 'OVERDUE' }));
    expect(data(CHARGE_PATH).status).toBe('paid');
  });

  it('PAYMENT_REFUNDED estorna na OS', async () => {
    seed();
    await handleAsaasEvent('c1', event('PAYMENT_RECEIVED'));
    await handleAsaasEvent('c1', event('PAYMENT_REFUNDED', { status: 'REFUNDED' }));

    expect(data(ORDER_PATH).paidAmount).toBe(0);
    expect(data(CHARGE_PATH).status).toBe('refunded');
  });

  it('PAYMENT_DELETED cancela só se não paga', async () => {
    seed({ status: 'overdue' });
    await handleAsaasEvent('c1', event('PAYMENT_DELETED'));
    expect(data(CHARGE_PATH).status).toBe('canceled');

    seed({ status: 'paid' });
    await handleAsaasEvent('c1', event('PAYMENT_DELETED'));
    expect(data(CHARGE_PATH).status).toBe('paid');

    // Installment plan partially paid: one installment deleted keeps the status.
    seed({
      mode: 'cardInstallments', installmentCount: 3, asaasInstallmentId: 'ins_1',
      status: 'pending', paidAsaasPaymentIds: ['pay_1'],
    });
    await handleAsaasEvent('c1', event('PAYMENT_DELETED', { id: 'pay_2', installment: 'ins_1' }));
    expect(data(CHARGE_PATH).status).toBe('pending');

    seed({
      mode: 'cardInstallments', installmentCount: 3, asaasInstallmentId: 'ins_1',
      status: 'overdue', paidAsaasPaymentIds: ['pay_1'],
    });
    await handleAsaasEvent('c1', event('PAYMENT_DELETED', { id: 'pay_3', installment: 'ins_1' }));
    expect(data(CHARGE_PATH).status).toBe('overdue');
  });

  it('sem externalReference, encontra a cobrança parcelada pelo installment', async () => {
    seed({ mode: 'cardInstallments', installmentCount: 2, asaasInstallmentId: 'ins_1' });
    seedDoc('companies/c2/orders/o9/charges/chX', { asaasInstallmentId: 'ins_1', paidAsaasPaymentIds: [] });

    await handleAsaasEvent('c1', event('PAYMENT_CONFIRMED', {
      id: 'pay_2', value: 500, billingType: 'CREDIT_CARD', externalReference: null,
      installment: 'ins_1', installmentNumber: 2,
    }));

    const tx = (data(ORDER_PATH).transactions as any[])[0];
    expect(tx).toEqual(expect.objectContaining({ id: 'asaas_pay_2', amount: 500, description: 'Asaas • Cartão 2/2' }));
    expect(data('companies/c2/orders/o9/charges/chX').paidAsaasPaymentIds).toEqual([]);
    expect(mockNotify).toHaveBeenCalledWith('c1', 'o1', 500);
  });

  it('eventos não assinados só são registrados', async () => {
    seed();
    await handleAsaasEvent('c1', event('PAYMENT_CHECKOUT_VIEWED'));
    expect(data(CHARGE_PATH).status).toBe('pending');
    expect(events()).toHaveLength(1);
  });

  it('nunca loga o payload do webhook', async () => {
    seed();
    await handleAsaasEvent('c1', event('PAYMENT_RECEIVED', { id: 'pay_other', description: 'Cliente João' }));
    await handleAsaasEvent('c1', event('PAYMENT_RECEIVED', { externalReference: 'c9:o1:ch1', description: 'Cliente João' }));

    const all = JSON.stringify([...errorSpy.mock.calls, ...warnSpy.mock.calls, ...logSpy.mock.calls]);
    expect(all).not.toContain('João');
    expect(all).not.toContain('990');
  });
});
