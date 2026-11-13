jest.mock('../../../services/web-billing/web-billing.service', () => ({ handleBillingEvent: jest.fn() }));
jest.mock('../../../services/web-billing/default-deps', () => ({ defaultWebBillingDeps: jest.fn() }));

import request from 'supertest';
import express from 'express';
import { handleBillingEvent } from '../../../services/web-billing/web-billing.service';
import { createAsaasBillingWebhookRouter } from '../asaas-billing.routes';

const mockHandle = handleBillingEvent as jest.Mock;
const TOKEN = 'whk_asaas_billing_test_value';
const DEPS = { marker: 'deps' } as never;

function app(deps: unknown = DEPS, token: string | undefined = TOKEN) {
  const server = express();
  server.use(express.json());
  server.use('/webhooks/asaas-billing', createAsaasBillingWebhookRouter(() => deps as never, () => token));
  return server;
}

const EVENT = { id: 'evt_1', event: 'PAYMENT_CONFIRMED', payment: { id: 'pay_1', subscription: 'sub_1' } };

beforeEach(() => mockHandle.mockReset());

describe('POST /webhooks/asaas-billing', () => {
  it('500 and nothing processed when not configured', async () => {
    const res = await request(app(null)).post('/webhooks/asaas-billing').set('asaas-access-token', TOKEN).send(EVENT);
    expect(res.status).toBe(500);
    expect(mockHandle).not.toHaveBeenCalled();
    const noToken = await request(app(DEPS, '')).post('/webhooks/asaas-billing').set('asaas-access-token', TOKEN).send(EVENT);
    expect(noToken.status).toBe(500);
  });

  it('401 with a wrong or missing token', async () => {
    expect((await request(app()).post('/webhooks/asaas-billing').send(EVENT)).status).toBe(401);
    expect((await request(app()).post('/webhooks/asaas-billing').set('asaas-access-token', `${TOKEN}x`).send(EVENT)).status).toBe(401);
    expect(mockHandle).not.toHaveBeenCalled();
  });

  it('400 on a malformed event', async () => {
    const res = await request(app()).post('/webhooks/asaas-billing').set('asaas-access-token', TOKEN).send({ event: 'X' });
    expect(res.status).toBe(400);
  });

  it('200 with the result; 500 when processing throws so Asaas retries', async () => {
    mockHandle.mockResolvedValueOnce('done');
    const ok = await request(app()).post('/webhooks/asaas-billing').set('asaas-access-token', TOKEN).send(EVENT);
    expect(ok.status).toBe(200);
    expect(ok.body).toEqual({ success: true, result: 'done' });
    expect(mockHandle).toHaveBeenCalledWith(expect.objectContaining({ id: 'evt_1' }), DEPS);

    mockHandle.mockRejectedValueOnce(new Error('boom'));
    const fail = await request(app()).post('/webhooks/asaas-billing').set('asaas-access-token', TOKEN).send(EVENT);
    expect(fail.status).toBe(500);
  });
});
