import request from 'supertest';
import express, { Request, Response, NextFunction } from 'express';

jest.mock('../../../services/firestore.service', () =>
  jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock,
);

import { read, resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
import { setAsaasCredentialProvider } from '../../../services/asaas/credential-provider';
import { AsaasApiError } from '../../../services/asaas/asaas-client';
import { ASAAS_WEBHOOK_EVENTS } from '../../../services/asaas/webhook-events';
import router from '../nfse.routes';

const TAXES = { retainIss: false, iss: 2, pis: 0, cofins: 0, csll: 0, inss: 0, ir: 0 };
const ACCOUNT = { asaasEnvironment: 'sandbox', asaasWalletId: 'w1' };

function seedConnection(companyId: string, data: Record<string, unknown> = {}) {
  seed(`companies/${companyId}/private/asaas`, {
    mode: 'apiKey', environment: 'sandbox', walletId: 'w1', status: 'active', webhookEvents: ASAAS_WEBHOOK_EVENTS, ...data,
  });
}

const client = {
  findCustomerByExternalReference: jest.fn(),
  createCustomer: jest.fn(),
  getCustomer: jest.fn(),
  updateCustomer: jest.fn(),
  createInvoice: jest.fn(),
  authorizeInvoice: jest.fn(),
  cancelInvoice: jest.fn(),
  getMunicipalOptions: jest.fn(),
  getFiscalInfo: jest.fn(),
  saveFiscalInfo: jest.fn(),
  listMunicipalServices: jest.fn(),
};

function buildApp(role: string, permissions: string[] = [], companyId = 'c1') {
  const app = express();
  app.use(express.json());
  app.use((req: Request, _res: Response, next: NextFunction) => {
    const r = req as any;
    r.auth = { type: 'bearer', companyId, userId: 'u1' };
    r.userContext = { userId: 'u1', userName: 'Ana', companyId, role, permissions };
    next();
  });
  app.use('/', router);
  return app;
}

const FINANCE = ['manage:payments'];

describe('nfse.routes', () => {
  beforeEach(() => {
    resetFakeDb();
    jest.clearAllMocks();
    jest.spyOn(console, 'log').mockImplementation(() => undefined);
    jest.spyOn(console, 'warn').mockImplementation(() => undefined);
    jest.spyOn(console, 'error').mockImplementation(() => undefined);
    setAsaasCredentialProvider({ getClient: async () => client as any });
    client.findCustomerByExternalReference.mockResolvedValue({ id: 'cus_1' });
    client.getCustomer.mockResolvedValue({
      id: 'cus_1', name: 'João', email: 'joao@example.com', postalCode: '01310000', address: 'Av. Paulista',
      addressNumber: '1000', province: 'Bela Vista',
    });
    client.updateCustomer.mockResolvedValue({ id: 'cus_1' });
    client.createInvoice.mockResolvedValue({ id: 'inv_1', status: 'SCHEDULED' });
    client.authorizeInvoice.mockResolvedValue({ id: 'inv_1', status: 'SYNCHRONIZED' });
    client.cancelInvoice.mockResolvedValue({ id: 'inv_1', status: 'CANCELED' });
    client.getMunicipalOptions.mockResolvedValue({ authenticationType: 'CERTIFICATE', supportsCancellation: true });
    client.getFiscalInfo.mockResolvedValue({ email: 'a@b.com', certificateSent: true });
    client.saveFiscalInfo.mockResolvedValue({});
    client.listMunicipalServices.mockResolvedValue([{ id: 'ms_1', description: '14.01 Manutenção', issTax: 2 }]);

    seed('companies/c1', { name: 'Oficina' });
    seed('companies/c1/settings/payments', { asaasEnabled: true, asaasConnected: true, nfseEnabled: true, nfseReady: true });
    seed('companies/c1/settings/nfse', { municipalServiceId: 'ms_1', municipalServiceName: 'Manutenção', taxes: TAXES, ...ACCOUNT });
    seedConnection('c1');
    seed('companies/c1/customers/cust1', { name: 'João', taxId: '52998224725' });
    seed('companies/c1/orders/o1', {
      number: 1, status: 'done', customer: { id: 'cust1', name: 'João' },
      services: [{ service: { name: 'Troca' }, value: 200 }], products: [], discount: 0,
    });
  });
  afterEach(() => jest.restoreAllMocks());
  afterAll(() => setAsaasCredentialProvider(null));

  describe('configuração', () => {
    it('dono vê o que falta; técnico e gerente não', async () => {
      client.getFiscalInfo.mockResolvedValue({ email: 'a@b.com', certificateSent: false });
      const res = await request(buildApp('owner')).get('/setup');
      expect(res.status).toBe(200);
      expect(res.body.data.missing).toEqual(['cityAccess']);
      expect(res.body.data.ready).toBe(false);
      expect(read('companies/c1/settings/payments')!.nfseReady).toBe(false);

      expect((await request(buildApp('manager', FINANCE)).get('/setup')).status).toBe(403);
      expect((await request(buildApp('technician')).get('/setup')).status).toBe(403);
    });

    it('com tudo preenchido fica pronto', async () => {
      const res = await request(buildApp('admin')).get('/setup');
      expect(res.body.data).toMatchObject({ ready: true, missing: [] });
      expect(read('companies/c1/settings/payments')!.nfseReady).toBe(true);
    });

    it('sem a opção ligada → 403 NFSE_NOT_ENABLED', async () => {
      seed('companies/c1/settings/payments', { asaasEnabled: true, asaasConnected: true });
      const res = await request(buildApp('owner')).get('/setup');
      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('NFSE_NOT_ENABLED');
      expect(client.getFiscalInfo).not.toHaveBeenCalled();
    });

    it('conexão antiga, sem os eventos da nota → 409 NFSE_RECONNECT_NEEDED', async () => {
      seedConnection('c1', { webhookEvents: null });
      const res = await request(buildApp('owner')).get('/setup');
      expect(res.status).toBe(409);
      expect(res.body.error.code).toBe('NFSE_RECONNECT_NEEDED');
      expect(client.getFiscalInfo).not.toHaveBeenCalled();
    });

    it('serviço salvo em outra conta do Asaas volta a faltar', async () => {
      seedConnection('c1', { walletId: 'w2' });
      const res = await request(buildApp('owner')).get('/setup');
      expect(res.body.data).toMatchObject({ ready: false, missing: ['service'], service: null });
      expect(read('companies/c1/settings/payments')!.nfseReady).toBe(false);
    });

    it('salva os dados fiscais no Asaas', async () => {
      const body = { email: 'nf@oficina.com', simplesNacional: true, municipalInscription: '123', cnae: '4520-0/01' };
      const res = await request(buildApp('owner')).post('/setup/fiscal-info').send(body);
      expect(res.status).toBe(200);
      expect(client.saveFiscalInfo).toHaveBeenCalledWith(body);
    });

    it('dados fiscais inválidos → 400 sem chamar o Asaas', async () => {
      const res = await request(buildApp('owner')).post('/setup/fiscal-info').send({ email: 'x', simplesNacional: 'sim' });
      expect(res.status).toBe(400);
      expect(client.saveFiscalInfo).not.toHaveBeenCalled();
    });

    it('busca serviços municipais', async () => {
      const res = await request(buildApp('owner')).get('/setup/municipal-services?q=manut');
      expect(res.status).toBe(200);
      expect(client.listMunicipalServices).toHaveBeenCalledWith('manut');
      expect(res.body.data[0].id).toBe('ms_1');
    });

    it('salva o serviço padrão (id ou código obrigatório)', async () => {
      const ok = await request(buildApp('owner')).put('/setup/service').send({
        municipalServiceCode: '14.01', municipalServiceName: 'Manutenção', taxes: TAXES, descriptionTemplate: '{servicos} - {os}',
      });
      expect(ok.status).toBe(200);
      expect(read('companies/c1/settings/nfse')).toMatchObject({
        municipalServiceId: null, municipalServiceCode: '14.01', descriptionTemplate: '{servicos} - {os}',
        updatedBy: { id: 'u1', name: 'Ana' }, ...ACCOUNT,
      });

      const bad = await request(buildApp('owner')).put('/setup/service').send({ municipalServiceName: 'X', taxes: TAXES });
      expect(bad.status).toBe(400);
      const badTax = await request(buildApp('owner')).put('/setup/service').send({
        municipalServiceId: 'ms_1', municipalServiceName: 'X', taxes: { ...TAXES, iss: 120 },
      });
      expect(badTax.status).toBe(400);
    });
  });

  describe('notas', () => {
    it('prévia e emissão exigem manage:payments (consultor e técnico não)', async () => {
      for (const role of ['consultant', 'technician']) {
        expect((await request(buildApp(role)).post('/invoices/preview').send({ orderIds: ['o1'] })).status).toBe(403);
        expect((await request(buildApp(role)).post('/invoices').send({ orderIds: ['o1'] })).status).toBe(403);
        expect((await request(buildApp(role)).post('/invoices/x/cancel').send({})).status).toBe(403);
      }
      expect(client.createInvoice).not.toHaveBeenCalled();
    });

    it('gerente vê a prévia e emite', async () => {
      const preview = await request(buildApp('manager', FINANCE)).post('/invoices/preview').send({ orderIds: ['o1'] });
      expect(preview.status).toBe(200);
      expect(preview.body.data.value).toBe(200);

      const res = await request(buildApp('manager', FINANCE)).post('/invoices').send({ orderIds: ['o1'] });
      expect(res.status).toBe(201);
      expect(res.body.data.status).toBe('synchronized');
      expect(client.createInvoice.mock.calls[0][0].value).toBe(200);
    });

    it('segunda nota da mesma OS → 409 ORDER_HAS_INVOICE', async () => {
      await request(buildApp('owner', FINANCE)).post('/invoices').send({ orderIds: ['o1'] });
      const res = await request(buildApp('owner', FINANCE)).post('/invoices').send({ orderIds: ['o1'] });
      expect(res.status).toBe(409);
      expect(res.body.error.code).toBe('ORDER_HAS_INVOICE');
    });

    it('OS de outra empresa → 404', async () => {
      seed('companies/c2/settings/payments', { asaasEnabled: true, asaasConnected: true, nfseEnabled: true, nfseReady: true });
      seed('companies/c2/settings/nfse', { municipalServiceId: 'ms_1', municipalServiceName: 'X', taxes: TAXES, ...ACCOUNT });
      seedConnection('c2');
      const res = await request(buildApp('owner', FINANCE, 'c2')).post('/invoices').send({ orderIds: ['o1'] });
      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe('ORDER_NOT_FOUND');
    });

    it('corpo inválido → 400', async () => {
      const app = buildApp('owner', FINANCE);
      expect((await request(app).post('/invoices').send({ orderIds: [] })).status).toBe(400);
      expect((await request(app).post('/invoices').send({ orderIds: ['a/b'] })).status).toBe(400);
      expect((await request(app).post('/invoices').send({ orderIds: ['o1'], effectiveDate: '15/10/2026' })).status).toBe(400);
    });

    it('cliente sem endereço → 400 CUSTOMER_DATA_REQUIRED; com os dados digitados emite', async () => {
      client.getCustomer.mockResolvedValue({ id: 'cus_1', name: 'João', email: 'joao@example.com' });
      const preview = await request(buildApp('owner', FINANCE)).post('/invoices/preview').send({ orderIds: ['o1'] });
      expect(preview.body.data.customer.missingData).toEqual(['postalCode', 'address', 'addressNumber', 'province']);

      const refused = await request(buildApp('owner', FINANCE)).post('/invoices').send({ orderIds: ['o1'] });
      expect(refused.status).toBe(400);
      expect(refused.body.error.code).toBe('CUSTOMER_DATA_REQUIRED');

      const res = await request(buildApp('owner', FINANCE)).post('/invoices').send({
        orderIds: ['o1'],
        customerData: { postalCode: '01310-000', address: 'Av. Paulista', addressNumber: '1000', province: 'Bela Vista' },
      });
      expect(res.status).toBe(201);
      expect(client.updateCustomer).toHaveBeenCalledWith('cus_1', {
        postalCode: '01310000', address: 'Av. Paulista', addressNumber: '1000', province: 'Bela Vista',
      });
    });

    it('erro de validação do Asaas vira ASAAS_VALIDATION_ERROR', async () => {
      client.createInvoice.mockRejectedValue(new AsaasApiError(400, [{ code: 'invalid', description: 'x' }], '/invoices'));
      const res = await request(buildApp('owner', FINANCE)).post('/invoices').send({ orderIds: ['o1'] });
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('ASAAS_VALIDATION_ERROR');
    });

    it('cancela a nota', async () => {
      const created = await request(buildApp('owner', FINANCE)).post('/invoices').send({ orderIds: ['o1'] });
      const path = `companies/c1/invoices/${created.body.data.id}`;
      const waiting = await request(buildApp('owner', FINANCE)).post(`/invoices/${created.body.data.id}/cancel`).send({});
      expect(waiting.status).toBe(409);
      expect(waiting.body.error.code).toBe('INVOICE_NOT_CANCELABLE');
      seed(path, { ...read(path)!, status: 'authorized' });
      const res = await request(buildApp('owner', FINANCE)).post(`/invoices/${created.body.data.id}/cancel`).send({});
      expect(res.status).toBe(200);
      expect(res.body.data.status).toBe('canceled');
      expect((await request(buildApp('owner', FINANCE)).post('/invoices/nope/cancel').send({})).status).toBe(404);
    });
  });
});
