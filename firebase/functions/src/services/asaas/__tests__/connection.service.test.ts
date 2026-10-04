jest.mock('../../firestore.service', () => jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock);

const mockClient = {
  getMyAccount: jest.fn(),
  getWallets: jest.fn(),
  createWebhook: jest.fn(),
  deleteWebhook: jest.fn(),
};
const mockClientOptions: any[] = [];

jest.mock('../asaas-client', () => {
  const actual = jest.requireActual('../asaas-client');
  return {
    ...actual,
    AsaasClient: jest.fn().mockImplementation((opts: any) => {
      mockClientOptions.push(opts);
      return mockClient;
    }),
  };
});

import { randomBytes } from 'node:crypto';
import { read, resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
import { AsaasApiError } from '../asaas-client';
import { decryptSecret, encryptSecret, hashToken } from '../crypto';
import { EncryptedSecret } from '../../../models/asaas.types';
import { connectAsaas, disconnectAsaas, getPaymentSettings } from '../connection.service';

const MASTER_KEY = randomBytes(32).toString('base64');
const USER = { id: 'u1', name: 'Ana', email: 'ana@oficina.com' };

describe('connection.service', () => {
  beforeEach(() => {
    resetFakeDb();
    jest.clearAllMocks();
    mockClientOptions.length = 0;
    process.env.ASAAS_CREDENTIALS_KEY = MASTER_KEY;
    process.env.ASAAS_WEBHOOK_BASE_URL = 'https://example.test/api/';
    mockClient.getMyAccount.mockResolvedValue({ name: 'Ana Silva', tradingName: 'Oficina da Ana', email: 'conta@asaas.com' });
    mockClient.getWallets.mockResolvedValue([{ id: 'wallet_1' }]);
    mockClient.createWebhook.mockResolvedValue({ id: 'wh_1' });
    mockClient.deleteWebhook.mockResolvedValue(undefined);
  });

  afterAll(() => {
    delete process.env.ASAAS_CREDENTIALS_KEY;
    delete process.env.ASAAS_WEBHOOK_BASE_URL;
  });

  describe('connectAsaas', () => {
    it('exige asaasEnabled', async () => {
      const error = await connectAsaas('c1', '$aact_hmlg_k', USER).catch((e) => e);
      expect(error.code).toBe('ASAAS_NOT_ENABLED');
      expect(mockClient.getMyAccount).not.toHaveBeenCalled();
    });

    it('rejeita chave sem prefixo do Asaas sem chamar a API', async () => {
      seed('companies/c1/settings/payments', { asaasEnabled: true, asaasConnected: false });
      const error = await connectAsaas('c1', 'abc', USER).catch((e) => e);
      expect(error.code).toBe('ASAAS_INVALID_API_KEY');
      expect(mockClient.getMyAccount).not.toHaveBeenCalled();
    });

    it('chave recusada pelo Asaas → ASAAS_INVALID_API_KEY e nada gravado', async () => {
      seed('companies/c1/settings/payments', { asaasEnabled: true, asaasConnected: false });
      mockClient.getMyAccount.mockRejectedValue(new AsaasApiError(401, [], '/myAccount/commercialInfo'));

      const error = await connectAsaas('c1', '$aact_hmlg_k', USER).catch((e) => e);

      expect(error.code).toBe('ASAAS_INVALID_API_KEY');
      expect(read('companies/c1/private/asaas')).toBeUndefined();
      expect(read('companies/c1/settings/payments')).toEqual({ asaasEnabled: true, asaasConnected: false });
      expect(mockClient.createWebhook).not.toHaveBeenCalled();
    });

    it('chave válida de sandbox: cria webhook, criptografa e grava settings', async () => {
      seed('companies/c1/settings/payments', { asaasEnabled: true, asaasConnected: false });

      const settings = await connectAsaas('c1', '  $aact_hmlg_k  ', USER);

      expect(settings).toEqual({
        asaasEnabled: true,
        asaasConnected: true,
        asaasAccountName: 'Oficina da Ana',
        asaasEnvironment: 'sandbox',
      });
      expect(mockClientOptions[0]).toEqual({ apiKey: '$aact_hmlg_k', environment: 'sandbox' });

      const webhookInput = mockClient.createWebhook.mock.calls[0][0];
      expect(webhookInput).toMatchObject({
        name: 'PraticOS',
        url: 'https://example.test/api/webhooks/asaas/c1',
        email: 'ana@oficina.com',
        enabled: true,
        interrupted: false,
        apiVersion: 3,
        sendType: 'SEQUENTIALLY',
        events: ['PAYMENT_RECEIVED', 'PAYMENT_CONFIRMED', 'PAYMENT_OVERDUE', 'PAYMENT_REFUNDED', 'PAYMENT_DELETED'],
      });
      expect(webhookInput.authToken).toMatch(/^[A-Za-z0-9_-]{64}$/);

      const stored = read('companies/c1/private/asaas')!;
      expect(stored).toMatchObject({
        mode: 'apiKey',
        environment: 'sandbox',
        accountName: 'Oficina da Ana',
        walletId: 'wallet_1',
        webhookId: 'wh_1',
        status: 'active',
        connectedBy: { id: 'u1', name: 'Ana' },
      });
      expect(stored.webhookTokenHash).toBe(hashToken(webhookInput.authToken));
      expect(JSON.stringify(stored)).not.toContain('aact');
      expect(decryptSecret(stored.encryptedApiKey as EncryptedSecret, MASTER_KEY)).toBe('$aact_hmlg_k');
      expect(read('companies/c1/settings/payments')).toEqual(settings);
    });

    it('preserva campos extras de settings/payments ao conectar (merge)', async () => {
      seed('companies/c1/settings/payments', { asaasEnabled: true, asaasConnected: false, futureField: 'keep' });
      await connectAsaas('c1', '$aact_hmlg_k', USER);
      expect(read('companies/c1/settings/payments')).toMatchObject({
        asaasEnabled: true,
        asaasConnected: true,
        futureField: 'keep',
      });
    });

    it('infere produção pelo prefixo', async () => {
      seed('companies/c1/settings/payments', { asaasEnabled: true });
      const settings = await connectAsaas('c1', '$aact_prod_k', USER);
      expect(settings.asaasEnvironment).toBe('production');
      expect(mockClientOptions[0].environment).toBe('production');
    });

    it('usa email do documento do usuário quando não vem no contexto', async () => {
      seed('companies/c1/settings/payments', { asaasEnabled: true });
      seed('users/u1', { email: 'doc@oficina.com' });
      await connectAsaas('c1', '$aact_hmlg_k', { id: 'u1', name: 'Ana' });
      expect(mockClient.createWebhook.mock.calls[0][0].email).toBe('doc@oficina.com');
    });

    it('usa email da conta Asaas como último recurso', async () => {
      seed('companies/c1/settings/payments', { asaasEnabled: true });
      await connectAsaas('c1', '$aact_hmlg_k', { id: 'u1', name: 'Ana' });
      expect(mockClient.createWebhook.mock.calls[0][0].email).toBe('conta@asaas.com');
    });

    it('reconectar remove o webhook anterior', async () => {
      seed('companies/c1/settings/payments', { asaasEnabled: true, asaasConnected: true });
      seed('companies/c1/private/asaas', {
        mode: 'apiKey',
        environment: 'sandbox',
        encryptedApiKey: encryptSecret('$aact_hmlg_old', MASTER_KEY),
        webhookId: 'wh_old',
        status: 'active',
      });

      await connectAsaas('c1', '$aact_hmlg_new', USER);

      expect(mockClient.deleteWebhook).toHaveBeenCalledWith('wh_old');
      expect(read('companies/c1/private/asaas')!.webhookId).toBe('wh_1');
    });

    it('reconectar: se criar o novo webhook falhar, a conexão antiga fica intacta', async () => {
      seed('companies/c1/settings/payments', { asaasEnabled: true, asaasConnected: true, asaasAccountName: 'Velha' });
      seed('companies/c1/private/asaas', {
        mode: 'apiKey',
        environment: 'sandbox',
        encryptedApiKey: encryptSecret('$aact_hmlg_old', MASTER_KEY),
        webhookId: 'wh_old',
        status: 'active',
      });
      mockClient.createWebhook.mockRejectedValue(new AsaasApiError(500, [], '/webhooks'));

      await expect(connectAsaas('c1', '$aact_hmlg_new', USER)).rejects.toBeInstanceOf(AsaasApiError);

      expect(mockClient.deleteWebhook).not.toHaveBeenCalled();
      expect(read('companies/c1/private/asaas')!.webhookId).toBe('wh_old');
      expect(read('companies/c1/settings/payments')!.asaasAccountName).toBe('Velha');
    });

    it('reconectar: só remove o webhook antigo depois de gravar a nova conexão', async () => {
      seed('companies/c1/settings/payments', { asaasEnabled: true, asaasConnected: true });
      seed('companies/c1/private/asaas', {
        mode: 'apiKey',
        environment: 'sandbox',
        encryptedApiKey: encryptSecret('$aact_hmlg_old', MASTER_KEY),
        webhookId: 'wh_old',
        status: 'active',
      });
      let webhookIdWhenDeleted: unknown;
      mockClient.deleteWebhook.mockImplementation(async () => {
        webhookIdWhenDeleted = read('companies/c1/private/asaas')!.webhookId;
      });

      await connectAsaas('c1', '$aact_hmlg_new', USER);

      expect(mockClient.deleteWebhook).toHaveBeenCalledWith('wh_old');
      expect(webhookIdWhenDeleted).toBe('wh_1');
    });

    it('falha de rede (fetch lança) → ASAAS_UNAVAILABLE e nada gravado', async () => {
      seed('companies/c1/settings/payments', { asaasEnabled: true, asaasConnected: false });
      mockClient.getMyAccount.mockRejectedValue(new TypeError('fetch failed'));

      const error = await connectAsaas('c1', '$aact_hmlg_k', USER).catch((e) => e);

      expect(error.code).toBe('ASAAS_UNAVAILABLE');
      expect(error.httpStatus).toBe(502);
      expect(read('companies/c1/private/asaas')).toBeUndefined();
    });

    it('timeout ao criar webhook → ASAAS_UNAVAILABLE', async () => {
      seed('companies/c1/settings/payments', { asaasEnabled: true, asaasConnected: false });
      const timeout = new Error('The operation was aborted due to timeout');
      timeout.name = 'TimeoutError';
      mockClient.createWebhook.mockRejectedValue(timeout);

      const error = await connectAsaas('c1', '$aact_hmlg_k', USER).catch((e) => e);

      expect(error.code).toBe('ASAAS_UNAVAILABLE');
      expect(read('companies/c1/private/asaas')).toBeUndefined();
    });

    it('se gravar falhar, apaga o webhook criado', async () => {
      seed('companies/c1/settings/payments', { asaasEnabled: true, asaasConnected: false });
      const { fakeDb } = jest.requireActual('../../../__tests__/helpers/fake-firestore');
      const spy = jest.spyOn(fakeDb, 'batch').mockImplementation(() => {
        throw new Error('firestore down');
      });

      await expect(connectAsaas('c1', '$aact_hmlg_k', USER)).rejects.toThrow('firestore down');

      expect(mockClient.deleteWebhook).toHaveBeenCalledWith('wh_1');
      spy.mockRestore();
    });
  });

  describe('disconnectAsaas', () => {
    it('remove webhook, credencial e mapeamentos e marca desconectado', async () => {
      seed('companies/c1/settings/payments', {
        asaasEnabled: true,
        asaasConnected: true,
        asaasAccountName: 'Oficina',
        asaasEnvironment: 'sandbox',
      });
      seed('companies/c1/private/asaas', {
        mode: 'apiKey',
        environment: 'sandbox',
        encryptedApiKey: encryptSecret('$aact_hmlg_k', MASTER_KEY),
        webhookId: 'wh_1',
        status: 'active',
      });
      seed('companies/c1/private/asaas/customers/cust1', { asaasCustomerId: 'cus_1' });

      await disconnectAsaas('c1');

      expect(mockClientOptions[0]).toMatchObject({ apiKey: '$aact_hmlg_k', environment: 'sandbox' });
      expect(mockClient.deleteWebhook).toHaveBeenCalledWith('wh_1');
      expect(read('companies/c1/private/asaas')).toBeUndefined();
      expect(read('companies/c1/private/asaas/customers/cust1')).toBeUndefined();
      expect(read('companies/c1/settings/payments')).toEqual({ asaasEnabled: true, asaasConnected: false });
    });

    it('marca desconectado antes de apagar a credencial', async () => {
      seed('companies/c1/settings/payments', { asaasEnabled: true, asaasConnected: true });
      seed('companies/c1/private/asaas', {
        mode: 'apiKey',
        environment: 'sandbox',
        encryptedApiKey: encryptSecret('$aact_hmlg_k', MASTER_KEY),
        webhookId: 'wh_1',
        status: 'active',
      });
      const { fakeDb } = jest.requireActual('../../../__tests__/helpers/fake-firestore');
      const spy = jest.spyOn(fakeDb, 'recursiveDelete').mockRejectedValue(new Error('crash'));

      await expect(disconnectAsaas('c1')).rejects.toThrow('crash');

      expect(read('companies/c1/settings/payments')!.asaasConnected).toBe(false);
      spy.mockRestore();
    });

    it('desconecta mesmo se o Asaas recusar a remoção do webhook', async () => {
      seed('companies/c1/settings/payments', { asaasEnabled: true, asaasConnected: true });
      seed('companies/c1/private/asaas', {
        mode: 'apiKey',
        environment: 'sandbox',
        encryptedApiKey: encryptSecret('$aact_hmlg_k', MASTER_KEY),
        webhookId: 'wh_1',
        status: 'active',
      });
      mockClient.deleteWebhook.mockRejectedValue(new AsaasApiError(401, [], '/webhooks/wh_1'));

      await disconnectAsaas('c1');

      expect(read('companies/c1/private/asaas')).toBeUndefined();
      expect(read('companies/c1/settings/payments')!.asaasConnected).toBe(false);
    });
  });

  it('getPaymentSettings devolve falso sem documento', async () => {
    expect(await getPaymentSettings('c1')).toEqual({ asaasEnabled: false, asaasConnected: false });
  });
});
