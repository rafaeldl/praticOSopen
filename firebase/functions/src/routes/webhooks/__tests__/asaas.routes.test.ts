jest.mock('../../../services/firestore.service', () =>
  jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock);
jest.mock('../../../services/asaas/webhook.service', () => ({ handleAsaasEvent: jest.fn() }));

import request from 'supertest';
import express from 'express';
import { resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
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
    resetFakeDb();
    mockHandle.mockReset();
    mockHandle.mockResolvedValue(undefined);
    seed('companies/c1/private/asaas', { webhookTokenHash: hashToken(TOKEN), status: 'active' });
    logSpies = (['log', 'info', 'warn', 'error'] as const).map((level) =>
      jest.spyOn(console, level).mockImplementation(() => undefined));
  });

  afterEach(() => {
    const logged = logSpies.flatMap((spy) => spy.mock.calls).map((call) => JSON.stringify(call)).join('\n');
    expect(logged).not.toContain(TOKEN);
    expect(logged).not.toContain(hashToken(TOKEN));
    expect(logged).not.toContain('marker_body_must_not_be_logged');
    logSpies.forEach((spy) => spy.mockRestore());
  });

  it('responde 200 e processa o evento com token correto', async () => {
    const res = await request(buildApp())
      .post('/webhooks/asaas/c1')
      .set('asaas-access-token', TOKEN)
      .send(BODY);

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ success: true });
    expect(mockHandle).toHaveBeenCalledWith('c1', BODY);
  });

  it('responde 200 para evento que o serviço ignora (sem lançar)', async () => {
    const res = await request(buildApp())
      .post('/webhooks/asaas/c1')
      .set('asaas-access-token', TOKEN)
      .send({ id: 'evt_2', event: 'PAYMENT_CREATED' });
    expect(res.status).toBe(200);
    expect(mockHandle).toHaveBeenCalledWith('c1', { id: 'evt_2', event: 'PAYMENT_CREATED' });
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

  it('não diferencia empresa inexistente, sem hash ou hash inválido de token errado', async () => {
    seed('companies/c3/private/asaas', { status: 'active' });
    seed('companies/c4/private/asaas', { webhookTokenHash: 'not-hex', status: 'active' });
    const wrongToken = await request(buildApp())
      .post('/webhooks/asaas/c1')
      .set('asaas-access-token', 'wrong')
      .send(BODY);

    for (const companyId of ['c2', 'c3', 'c4']) {
      const res = await request(buildApp())
        .post(`/webhooks/asaas/${companyId}`)
        .set('asaas-access-token', TOKEN)
        .send(BODY);
      expect(res.status).toBe(wrongToken.status);
      expect(res.body).toEqual(wrongToken.body);
    }
    expect(wrongToken.status).toBe(401);
    expect(mockHandle).not.toHaveBeenCalled();
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

  it('limita 300 req/min por companyId', async () => {
    const app = buildApp();
    seed('companies/c5/private/asaas', { webhookTokenHash: hashToken(TOKEN), status: 'active' });
    const send = (companyId: string) => request(app)
      .post(`/webhooks/asaas/${companyId}`)
      .set('asaas-access-token', TOKEN)
      .send(BODY);

    for (let i = 0; i < 300; i++) {
      const res = await send('c5');
      expect(res.status).toBe(200);
    }
    expect((await send('c5')).status).toBe(429);
    // Other companies keep their own budget.
    expect((await send('c1')).status).toBe(200);
  });
});
