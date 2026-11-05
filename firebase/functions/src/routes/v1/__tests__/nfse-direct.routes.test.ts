import request from 'supertest';
import express, { Request, Response, NextFunction } from 'express';

jest.mock('../../../services/nfse/issue.service', () => ({
  previewDirectInvoice: jest.fn(),
  issueDirectInvoice: jest.fn(),
  cancelDirectInvoice: jest.fn(),
  reconcileDirectInvoice: jest.fn(),
}));

import * as issue from '../../../services/nfse/issue.service';
import { AsaasServiceError } from '../../../services/asaas/errors';
import { NfseServiceError } from '../../../services/nfse/errors';
import router from '../nfse-direct.routes';

const mock = issue as jest.Mocked<typeof issue>;

function buildApp(role: string) {
  const app = express();
  app.use(express.json());
  app.use((req: Request, _res: Response, next: NextFunction) => {
    (req as any).userContext = { userId: 'u1', userName: 'Ana', companyId: 'c1', role, permissions: [] };
    next();
  });
  app.use('/', router);
  return app;
}

describe('nfse-direct.routes', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    jest.spyOn(console, 'error').mockImplementation(() => undefined);
  });

  it.each(['owner', 'admin', 'manager'])('%s issues: 201 when issued', async (role) => {
    mock.issueDirectInvoice.mockResolvedValue({ id: 'nf1', status: 'authorized' } as never);
    const res = await request(buildApp(role)).post('/invoices').send({ orderIds: ['o1'], emitterId: 'e1' });
    expect(res.status).toBe(201);
    expect(mock.issueDirectInvoice).toHaveBeenCalledWith('c1', { orderIds: ['o1'], emitterId: 'e1' }, { id: 'u1', name: 'Ana' });
  });

  it('202 while the government has not answered', async () => {
    mock.issueDirectInvoice.mockResolvedValue({ id: 'nf1', status: 'creating' } as never);
    expect((await request(buildApp('owner')).post('/invoices').send({ orderIds: ['o1'] })).status).toBe(202);
  });

  it.each(['supervisor', 'consultant', 'technician'])('%s cannot issue or cancel', async (role) => {
    const app = buildApp(role);
    expect((await request(app).post('/invoices').send({ orderIds: ['o1'] })).status).toBe(403);
    expect((await request(app).post('/invoices/nf1/cancel').send({ reason: 'issueError' })).status).toBe(403);
    expect(mock.issueDirectInvoice).not.toHaveBeenCalled();
  });

  it('refusal goes back with the plain-words details', async () => {
    const refusal = { code: 'E0312', group: 'emitterSetup', message: { pt: 'x', en: 'x', es: 'x' } };
    mock.issueDirectInvoice.mockRejectedValue(new NfseServiceError('NFSE_REFUSED', 'refused', { refusal, invoiceId: 'nf1' }));
    const res = await request(buildApp('owner')).post('/invoices').send({ orderIds: ['o1'] });
    expect(res.status).toBe(422);
    expect(res.body.error).toMatchObject({ code: 'NFSE_REFUSED', details: { refusal, invoiceId: 'nf1' } });
  });

  it('order checks shared with the Asaas nota keep their codes', async () => {
    mock.issueDirectInvoice.mockRejectedValue(new AsaasServiceError('NO_SERVICES', 'no services'));
    const res = await request(buildApp('owner')).post('/invoices').send({ orderIds: ['o1'] });
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('NO_SERVICES');
  });

  it('validates the body', async () => {
    const app = buildApp('owner');
    expect((await request(app).post('/invoices').send({ orderIds: [] })).status).toBe(400);
    expect((await request(app).post('/invoices').send({ orderIds: ['o1'], recipient: { address: { evil: 1 } } })).status).toBe(400);
    expect((await request(app).post('/invoices/nf1/cancel').send({ reason: 'whatever' })).status).toBe(400);
  });

  it('cancel, preview and reconcile', async () => {
    mock.cancelDirectInvoice.mockResolvedValue({ id: 'nf1', status: 'canceled' } as never);
    mock.previewDirectInvoice.mockResolvedValue({ value: 270 } as never);
    mock.reconcileDirectInvoice.mockResolvedValueOnce({ id: 'nf1', status: 'authorized' } as never).mockResolvedValueOnce(null);
    const app = buildApp('manager');
    expect((await request(app).post('/invoices/nf1/cancel').send({ reason: 'serviceNotProvided' })).body.data.status).toBe('canceled');
    expect(mock.cancelDirectInvoice).toHaveBeenCalledWith('c1', 'nf1', 'serviceNotProvided', { id: 'u1', name: 'Ana' });
    expect((await request(app).post('/invoices/preview').send({ orderIds: ['o1'] })).body.data.value).toBe(270);
    expect((await request(app).post('/invoices/nf1/reconcile')).body.data.status).toBe('authorized');
    expect(mock.reconcileDirectInvoice).toHaveBeenCalledWith('c1', 'nf1', undefined, true);
    expect((await request(app).post('/invoices/nf1/reconcile')).status).toBe(404);
  });
});
