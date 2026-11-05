import request from 'supertest';
import express, { Request, Response, NextFunction } from 'express';

jest.mock('../../../services/nfse/issue.service', () => ({
  previewDirectInvoice: jest.fn(),
  issueDirectInvoice: jest.fn(),
  cancelDirectInvoice: jest.fn(),
  reconcileDirectInvoice: jest.fn(),
}));

jest.mock('../../../services/nfse/danfse.service', () => ({ ensureDanfse: jest.fn() }));
jest.mock('../../../services/firestore.service', () => jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock);
jest.mock('../../../services/notification.service', () => ({ notifyOwnerOfInvoiceAction: jest.fn(async () => undefined) }));

import * as issue from '../../../services/nfse/issue.service';
import * as danfse from '../../../services/nfse/danfse.service';
import { AsaasServiceError } from '../../../services/asaas/errors';
import { NfseServiceError } from '../../../services/nfse/errors';
import router from '../nfse-direct.routes';
import { resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
import { notifyOwnerOfInvoiceAction } from '../../../services/notification.service';

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
    resetFakeDb();
    seed('companies/c1', { owner: { id: 'owner1', name: 'Dona' }, country: 'BR' });
    jest.spyOn(console, 'error').mockImplementation(() => undefined);
  });

  it('the owner turned managers off: manager gets 403, admin still issues (issue #560)', async () => {
    seed('companies/c1/settings/nfse', { managerCanIssue: false });
    mock.issueDirectInvoice.mockResolvedValue({ id: 'nf1', status: 'authorized' } as never);
    const res = await request(buildApp('manager')).post('/invoices').send({ orderIds: ['o1'] });
    expect(res.status).toBe(403);
    expect((await request(buildApp('manager')).post('/invoices/nf1/cancel').send({ reason: 'issueError' })).status).toBe(403);
    expect(mock.issueDirectInvoice).not.toHaveBeenCalled();
    expect((await request(buildApp('admin')).post('/invoices').send({ orderIds: ['o1'] })).status).toBe(201);
  });

  it('someone other than the owner issues or cancels: the owner is told (issue #560)', async () => {
    mock.issueDirectInvoice.mockResolvedValue({ id: 'nf1', status: 'authorized', value: 270, recipient: { legalName: 'REVENDA' } } as never);
    mock.cancelDirectInvoice.mockResolvedValue({ id: 'nf1', status: 'canceled', value: 270 } as never);
    await request(buildApp('manager')).post('/invoices').send({ orderIds: ['o1'] });
    await request(buildApp('manager')).post('/invoices/nf1/cancel').send({ reason: 'issueError' });
    const notify = notifyOwnerOfInvoiceAction as jest.Mock;
    expect(notify.mock.calls.map(([, m]) => m.action)).toEqual(['issued', 'canceled']);
    expect(notify.mock.calls[0][1].body).toContain('Ana emitiu uma nota fiscal para REVENDA');
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

  it('pdf: makes it when needed and returns the Storage path', async () => {
    const ensure = danfse.ensureDanfse as jest.Mock;
    ensure.mockResolvedValue('tenants/c1/invoices/nf1/danfse.pdf');
    const res = await request(buildApp('manager')).post('/invoices/nf1/pdf');
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({ pdfPath: 'tenants/c1/invoices/nf1/danfse.pdf' });
    expect(ensure).toHaveBeenCalledWith('c1', 'nf1');
    ensure.mockRejectedValue(new NfseServiceError('PDF_NOT_AVAILABLE', 'no'));
    expect((await request(buildApp('owner')).post('/invoices/nf1/pdf')).status).toBe(409);
    expect((await request(buildApp('technician')).post('/invoices/nf1/pdf')).status).toBe(403);
  });
});
