jest.mock('../../firestore.service', () => jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock);

import { randomBytes } from 'node:crypto';
import { resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
import { encryptSecret } from '../crypto';
import { AsaasClient } from '../asaas-client';
import {
  ApiKeyCredentialProvider,
  getAsaasCredentialProvider,
  setAsaasCredentialProvider,
} from '../credential-provider';
import { AsaasServiceError } from '../errors';

const MASTER_KEY = randomBytes(32).toString('base64');

function seedConnection(status: 'active' | 'invalid') {
  seed('companies/c1/private/asaas', {
    mode: 'apiKey',
    environment: 'sandbox',
    encryptedApiKey: encryptSecret('$aact_hmlg_key', MASTER_KEY),
    accountName: 'Oficina',
    status,
    connectedBy: { id: 'u1', name: 'Ana' },
    connectedAt: '2026-10-04T10:00:00.000Z',
  });
}

describe('ApiKeyCredentialProvider', () => {
  beforeEach(() => {
    resetFakeDb();
    setAsaasCredentialProvider(null);
  });

  it('decripta a chave e monta o client do ambiente salvo', async () => {
    seedConnection('active');
    const calls: Array<{ url: string; headers: Record<string, string> }> = [];
    const fetchImpl = (async (url: string, init: RequestInit) => {
      calls.push({ url, headers: init.headers as Record<string, string> });
      return new Response(JSON.stringify({ name: 'Oficina' }), { status: 200 });
    }) as unknown as typeof fetch;

    const client = await new ApiKeyCredentialProvider(() => MASTER_KEY, fetchImpl).getClient('c1');
    await client.getMyAccount();

    expect(client).toBeInstanceOf(AsaasClient);
    expect(calls[0].url).toContain('https://api-sandbox.asaas.com/v3');
    expect(calls[0].headers.access_token).toBe('$aact_hmlg_key');
  });

  it('falha com ASAAS_NOT_CONNECTED sem credencial', async () => {
    const error = await new ApiKeyCredentialProvider(() => MASTER_KEY).getClient('c1').catch((e) => e);
    expect(error).toBeInstanceOf(AsaasServiceError);
    expect(error.code).toBe('ASAAS_NOT_CONNECTED');
  });

  it('falha com ASAAS_NOT_CONNECTED quando status é invalid', async () => {
    seedConnection('invalid');
    const error = await new ApiKeyCredentialProvider(() => MASTER_KEY).getClient('c1').catch((e) => e);
    expect(error.code).toBe('ASAAS_NOT_CONNECTED');
  });

  it('singleton é substituível em testes', () => {
    const fake = { getClient: jest.fn() };
    setAsaasCredentialProvider(fake);
    expect(getAsaasCredentialProvider()).toBe(fake);
    setAsaasCredentialProvider(null);
    expect(getAsaasCredentialProvider()).toBeInstanceOf(ApiKeyCredentialProvider);
  });
});
