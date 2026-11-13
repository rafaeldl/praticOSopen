import request from 'supertest';
import express, { Request, Response, NextFunction } from 'express';

jest.mock('../../../services/firestore.service', () =>
  jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock,
);
jest.mock('../../../services/nfse/certificate-vault.service', () => ({
  storeCertificate: jest.fn(),
  deleteCertificate: jest.fn(),
}));

import { resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
import * as vault from '../../../services/nfse/certificate-vault.service';
import { NfseServiceError } from '../../../services/nfse/errors';
import { resetPaidPlansCache } from '../../../services/plan-limits.service';
import router from '../nfse-certificate.routes';

const mockVault = vault as jest.Mocked<typeof vault>;

function buildApp(role: string) {
  const app = express();
  app.use(express.json({ limit: '1mb' }));
  app.use((req: Request, _res: Response, next: NextFunction) => {
    const r = req as any;
    r.userContext = { userId: 'user1', userName: 'Ana', companyId: 'c1', role, permissions: [] };
    next();
  });
  app.use('/', router);
  return app;
}

const BODY = { pfxBase64: Buffer.from('fake-pfx').toString('base64'), password: 'segredo-123', termsVersion: '2026-11-05' };
const RESULT = { emitterId: 'e1', created: true, taxId: '00000000000191', holderName: 'OFICINA EXEMPLO LTDA', notAfter: '2027-03-12T00:00:00.000Z' };

describe('nfse-certificate.routes', () => {
  let errorSpy: jest.SpyInstance;

  beforeEach(() => {
    jest.clearAllMocks();
    resetFakeDb();
    resetPaidPlansCache();
    seed('companies/c1/settings/payments', { nfseDirectEnabled: true });
    errorSpy = jest.spyOn(console, 'error').mockImplementation(() => undefined);
  });
  afterEach(() => errorSpy.mockRestore());

  it('owner adds a CNPJ: file decoded, password passed only to the vault, device audited', async () => {
    mockVault.storeCertificate.mockResolvedValue(RESULT);
    const res = await request(buildApp('owner')).post('/certificate').set('x-app-version', 'ios/1.104.0').send(BODY);
    expect(res.status).toBe(201);
    expect(res.body).toEqual({ success: true, data: RESULT });
    const call = mockVault.storeCertificate.mock.calls[0][0];
    expect(call).toMatchObject({ companyId: 'c1', password: 'segredo-123', termsVersion: '2026-11-05' });
    expect(call.pfx.toString()).toBe('fake-pfx');
    expect(call.actor).toMatchObject({ user: { id: 'user1', name: 'Ana' }, device: 'ios/1.104.0' });
    expect(call.emitterId).toBeUndefined();
  });

  it('admin replaces the certificate of an emitter', async () => {
    mockVault.storeCertificate.mockResolvedValue({ ...RESULT, created: false });
    const res = await request(buildApp('admin')).put('/e1/certificate').send(BODY);
    expect(res.status).toBe(200);
    expect(mockVault.storeCertificate.mock.calls[0][0].emitterId).toBe('e1');
  });

  it.each(['manager', 'supervisor', 'consultant', 'technician'])('%s cannot touch certificates', async (role) => {
    const app = buildApp(role);
    expect((await request(app).post('/certificate').send(BODY)).status).toBe(403);
    expect((await request(app).put('/e1/certificate').send(BODY)).status).toBe(403);
    expect((await request(app).delete('/e1/certificate')).status).toBe(403);
    expect(mockVault.storeCertificate).not.toHaveBeenCalled();
    expect(mockVault.deleteCertificate).not.toHaveBeenCalled();
  });

  it('company outside the pilot gets NFSE_DIRECT_NOT_ENABLED', async () => {
    seed('companies/c1/settings/payments', { nfseDirectEnabled: false });
    const res = await request(buildApp('owner')).post('/certificate').send(BODY);
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('NFSE_DIRECT_NOT_ENABLED');
  });

  it('validates the body without echoing the password', async () => {
    const res = await request(buildApp('owner')).post('/certificate').send({ pfxBase64: '!!!', password: 'segredo-123' });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(JSON.stringify(res.body)).not.toContain('segredo-123');
  });

  it('maps vault errors and never logs the password', async () => {
    mockVault.storeCertificate.mockRejectedValue(new NfseServiceError('CERT_WRONG_PASSWORD', 'Wrong certificate password'));
    const res = await request(buildApp('owner')).post('/certificate').send(BODY);
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('CERT_WRONG_PASSWORD');
    expect(JSON.stringify(errorSpy.mock.calls)).not.toContain('segredo-123');
    expect(JSON.stringify(errorSpy.mock.calls)).not.toContain(BODY.pfxBase64);
  });

  it('unexpected errors are a 500 without details', async () => {
    mockVault.storeCertificate.mockRejectedValue(new Error('boom segredo-123'));
    const res = await request(buildApp('owner')).post('/certificate').send(BODY);
    expect(res.status).toBe(500);
    expect(JSON.stringify(res.body)).not.toContain('segredo-123');
    expect(JSON.stringify(errorSpy.mock.calls)).not.toContain('segredo-123');
  });

  it('deletes a certificate; nothing stored is 404', async () => {
    mockVault.deleteCertificate.mockResolvedValueOnce(true).mockResolvedValueOnce(false);
    const ok = await request(buildApp('owner')).delete('/e1/certificate');
    expect(ok.status).toBe(200);
    expect(mockVault.deleteCertificate.mock.calls[0][0]).toMatchObject({ companyId: 'c1', emitterId: 'e1' });
    const missing = await request(buildApp('owner')).delete('/e1/certificate');
    expect(missing.status).toBe(404);
    expect(missing.body.error.code).toBe('CERT_NOT_FOUND');
  });

  describe('CNPJs of the nota by plan (#723)', () => {
    const starter = { plan: 'starter', status: 'active', source: 'store', tableVersion: '2' };

    it('switch on: Starter with one CNPJ cannot add another (402 PLAN_LIMIT)', async () => {
      seed('config/paidPlans', { enabled: true });
      seed('companies/c1', { subscription: starter });
      seed('companies/c1/fiscalEmitters/e1', { taxId: '1', certificate: { status: 'active' } });
      const res = await request(buildApp('owner')).post('/certificate').send(BODY);
      expect(res.status).toBe(402);
      expect(res.body.error).toMatchObject({ code: 'PLAN_LIMIT', resource: 'nfseCnpj', limit: 1, usage: 1, plan: 'starter' });
      expect(mockVault.storeCertificate).not.toHaveBeenCalled();
    });

    it('a deleted certificate frees its CNPJ; Pro fits two', async () => {
      mockVault.storeCertificate.mockResolvedValue(RESULT);
      seed('config/paidPlans', { enabled: true });
      seed('companies/c1', { subscription: starter });
      seed('companies/c1/fiscalEmitters/e1', { taxId: '1', certificate: { status: 'deleted' } });
      expect((await request(buildApp('owner')).post('/certificate').send(BODY)).status).toBe(201);
      seed('companies/c1', { subscription: { ...starter, plan: 'pro' } });
      seed('companies/c1/fiscalEmitters/e1', { taxId: '1', certificate: { status: 'active' } });
      expect((await request(buildApp('owner')).post('/certificate').send(BODY)).status).toBe(201);
    });

    it('replacing a certificate never asks; switch off has no limit', async () => {
      mockVault.storeCertificate.mockResolvedValue(RESULT);
      seed('companies/c1', { subscription: starter });
      seed('companies/c1/fiscalEmitters/e1', { taxId: '1', certificate: { status: 'active' } });
      expect((await request(buildApp('owner')).post('/certificate').send(BODY)).status).toBe(201);
      seed('config/paidPlans', { enabled: true });
      resetPaidPlansCache();
      expect((await request(buildApp('owner')).put('/e1/certificate').send(BODY)).status).toBe(200);
    });
  });

  it('refuses a malformed emitter id', async () => {
    const res = await request(buildApp('owner')).delete('/bad.id/certificate');
    expect(res.status).toBe(404);
    expect(mockVault.deleteCertificate).not.toHaveBeenCalled();
  });
});
