import { AsaasApiError, AsaasClient, environmentFromApiKey } from '../asaas-client';

interface Call {
  url: string;
  init: RequestInit;
}

function fakeFetch(status: number, body: unknown) {
  const calls: Call[] = [];
  const impl = (async (url: string, init: RequestInit) => {
    calls.push({ url, init });
    return new Response(body === undefined ? '' : JSON.stringify(body), { status });
  }) as unknown as typeof fetch;
  return { impl, calls };
}

function headersOf(call: Call): Record<string, string> {
  return call.init.headers as Record<string, string>;
}

describe('environmentFromApiKey', () => {
  it('infere ambiente pelo prefixo', () => {
    expect(environmentFromApiKey('$aact_hmlg_abc')).toBe('sandbox');
    expect(environmentFromApiKey('  $aact_prod_abc ')).toBe('production');
    expect(environmentFromApiKey('abc')).toBeNull();
    expect(environmentFromApiKey('')).toBeNull();
  });
});

describe('AsaasClient', () => {
  it('usa URL do sandbox e headers access_token e User-Agent', async () => {
    const { impl, calls } = fakeFetch(200, { name: 'Oficina X', email: 'a@b.com' });
    const client = new AsaasClient({ apiKey: '$aact_hmlg_k', environment: 'sandbox', fetchImpl: impl });

    const account = await client.getMyAccount();

    expect(account.name).toBe('Oficina X');
    expect(calls[0].url).toBe('https://api-sandbox.asaas.com/v3/myAccount/commercialInfo');
    expect(calls[0].init.method).toBe('GET');
    expect(headersOf(calls[0]).access_token).toBe('$aact_hmlg_k');
    expect(headersOf(calls[0])['User-Agent']).toBe('PraticOS');
  });

  it('usa URL de produção', async () => {
    const { impl, calls } = fakeFetch(200, { object: 'list', data: [{ id: 'w1' }] });
    const client = new AsaasClient({ apiKey: '$aact_prod_k', environment: 'production', fetchImpl: impl });

    const wallets = await client.getWallets();

    expect(wallets).toEqual([{ id: 'w1' }]);
    expect(calls[0].url).toBe('https://api.asaas.com/v3/wallets');
  });

  it('envia corpo JSON no POST', async () => {
    const { impl, calls } = fakeFetch(200, { id: 'pay_1', invoiceUrl: 'https://i' });
    const client = new AsaasClient({ apiKey: '$aact_hmlg_k', environment: 'sandbox', fetchImpl: impl });

    await client.createPayment({
      customer: 'cus_1',
      billingType: 'UNDEFINED',
      value: 100,
      dueDate: '2026-10-07',
      description: 'OS #1 - X',
      externalReference: 'c:o:ch',
    });

    expect(calls[0].url).toBe('https://api-sandbox.asaas.com/v3/payments');
    expect(calls[0].init.method).toBe('POST');
    expect(headersOf(calls[0])['content-type']).toBe('application/json');
    expect(JSON.parse(calls[0].init.body as string)).toMatchObject({ customer: 'cus_1', value: 100 });
  });

  it('busca cliente por externalReference', async () => {
    const { impl, calls } = fakeFetch(200, { object: 'list', data: [{ id: 'cus_9', name: 'Ana' }] });
    const client = new AsaasClient({ apiKey: '$aact_hmlg_k', environment: 'sandbox', fetchImpl: impl });

    const customer = await client.findCustomerByExternalReference('cust1');

    expect(customer?.id).toBe('cus_9');
    expect(calls[0].url).toBe('https://api-sandbox.asaas.com/v3/customers?externalReference=cust1&limit=1');
  });

  it('retorna null quando não acha cliente', async () => {
    const { impl } = fakeFetch(200, { object: 'list', data: [] });
    const client = new AsaasClient({ apiKey: '$aact_hmlg_k', environment: 'sandbox', fetchImpl: impl });
    expect(await client.findCustomerByExternalReference('x')).toBeNull();
  });

  it('DELETE de cobrança, parcelamento e webhook', async () => {
    const { impl, calls } = fakeFetch(200, { deleted: true });
    const client = new AsaasClient({ apiKey: '$aact_hmlg_k', environment: 'sandbox', fetchImpl: impl });

    await client.deletePayment('pay_1');
    await client.deleteInstallment('ins_1');
    await client.deleteWebhook('wh_1');

    expect(calls.map((c) => `${c.init.method} ${c.url}`)).toEqual([
      'DELETE https://api-sandbox.asaas.com/v3/payments/pay_1',
      'DELETE https://api-sandbox.asaas.com/v3/installments/ins_1',
      'DELETE https://api-sandbox.asaas.com/v3/webhooks/wh_1',
    ]);
  });

  it('lista parcelas de um parcelamento', async () => {
    const { impl, calls } = fakeFetch(200, { object: 'list', data: [{ id: 'p1' }, { id: 'p2' }] });
    const client = new AsaasClient({ apiKey: '$aact_hmlg_k', environment: 'sandbox', fetchImpl: impl });

    const payments = await client.listInstallmentPayments('ins_1');

    expect(payments.map((p) => p.id)).toEqual(['p1', 'p2']);
    expect(calls[0].url).toBe('https://api-sandbox.asaas.com/v3/installments/ins_1/payments?limit=100');
  });

  it('lança AsaasApiError com status e errors', async () => {
    const { impl } = fakeFetch(400, { errors: [{ code: 'invalid_value', description: 'Valor inválido' }] });
    const client = new AsaasClient({ apiKey: '$aact_hmlg_k', environment: 'sandbox', fetchImpl: impl });

    const error = await client
      .createCustomer({ name: 'A', cpfCnpj: '1', externalReference: 'c', notificationDisabled: true })
      .catch((e) => e);

    expect(error).toBeInstanceOf(AsaasApiError);
    expect(error.status).toBe(400);
    expect(error.errors).toEqual([{ code: 'invalid_value', description: 'Valor inválido' }]);
    expect(error.message).not.toContain('aact');
  });

  it('lança AsaasApiError 401 com corpo vazio', async () => {
    const { impl } = fakeFetch(401, undefined);
    const client = new AsaasClient({ apiKey: '$aact_hmlg_k', environment: 'sandbox', fetchImpl: impl });

    const error = await client.getMyAccount().catch((e) => e);

    expect(error).toBeInstanceOf(AsaasApiError);
    expect(error.status).toBe(401);
    expect(error.errors).toEqual([]);
  });
});
