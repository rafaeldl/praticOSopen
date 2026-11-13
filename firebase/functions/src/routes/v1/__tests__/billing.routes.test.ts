jest.mock('../../../services/web-billing/web-billing.service', () => {
  const actual = jest.requireActual('../../../services/web-billing/web-billing.service');
  return {
    WebBillingError: actual.WebBillingError,
    billingOverview: jest.fn(),
    startCheckout: jest.fn(),
    cancelWebSubscription: jest.fn(),
  };
});
jest.mock('../../../services/web-billing/default-deps', () => ({ defaultWebBillingDeps: jest.fn() }));

import request from 'supertest';
import express, { NextFunction, Request, Response } from 'express';
import { WebBillingError, billingOverview, cancelWebSubscription, startCheckout } from '../../../services/web-billing/web-billing.service';
import { createBillingRouter } from '../billing.routes';

const DEPS = { marker: 'deps' } as never;
const BODY = { plan: 'pro', cycle: 'monthly', billingType: 'CREDIT_CARD', name: 'Oficina', taxId: '11222333000181', email: 'a@example.com' };

function app(role: string, deps: unknown = DEPS) {
  const server = express();
  server.use(express.json());
  server.use((req: Request, _res: Response, next: NextFunction) => {
    (req as unknown as { userContext: unknown }).userContext = { companyId: 'c1', userId: 'u1', role };
    next();
  });
  server.use('/v1/app/billing', createBillingRouter(() => deps as never));
  return server;
}

beforeEach(() => jest.clearAllMocks());

describe('/v1/app/billing', () => {
  it('only owner and admin', async () => {
    for (const role of ['technician', 'manager', 'supervisor', 'consultant']) {
      expect((await request(app(role)).get('/v1/app/billing')).status).toBe(403);
      expect((await request(app(role)).post('/v1/app/billing/checkout').send(BODY)).status).toBe(403);
      expect((await request(app(role)).post('/v1/app/billing/cancel').send({})).status).toBe(403);
    }
    expect(startCheckout).not.toHaveBeenCalled();
  });

  it('GET answers the overview', async () => {
    (billingOverview as jest.Mock).mockResolvedValue({ enabled: false, offer: null, block: null, subscription: null });
    const res = await request(app('admin')).get('/v1/app/billing');
    expect(res.body).toEqual({ success: true, data: { enabled: false, offer: null, block: null, subscription: null } });
  });

  it('checkout validates the body and passes the company and user', async () => {
    expect((await request(app('owner')).post('/v1/app/billing/checkout').send({ ...BODY, plan: 'free' })).status).toBe(400);
    (startCheckout as jest.Mock).mockResolvedValue({ checkoutUrl: 'https://sandbox.asaas.com/i/1' });
    const res = await request(app('owner')).post('/v1/app/billing/checkout').send(BODY);
    expect(res.body.data).toEqual({ checkoutUrl: 'https://sandbox.asaas.com/i/1' });
    expect(startCheckout).toHaveBeenCalledWith('c1', 'u1', expect.objectContaining({ plan: 'pro' }), DEPS);
  });

  it('service errors keep their code; 503 without secrets', async () => {
    (startCheckout as jest.Mock).mockRejectedValue(new WebBillingError('STORE_SUBSCRIPTION_ACTIVE', 409, 'x'));
    const res = await request(app('owner')).post('/v1/app/billing/checkout').send(BODY);
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('STORE_SUBSCRIPTION_ACTIVE');
    expect((await request(app('owner', null)).post('/v1/app/billing/checkout').send(BODY)).status).toBe(503);
  });

  it('cancel passes refund', async () => {
    (cancelWebSubscription as jest.Mock).mockResolvedValue({ status: 'refunded' });
    const res = await request(app('owner')).post('/v1/app/billing/cancel').send({ refund: true });
    expect(res.body.data).toEqual({ status: 'refunded' });
    expect(cancelWebSubscription).toHaveBeenCalledWith('c1', { refund: true }, DEPS);
  });
});
