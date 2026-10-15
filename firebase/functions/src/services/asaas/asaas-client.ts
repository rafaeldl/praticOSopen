/**
 * Minimal Asaas API v3 client (native fetch).
 * Never logs the API key nor request/response bodies.
 */

import {
  AsaasAccountInfo,
  AsaasCreateCustomerInput,
  AsaasCreateInvoiceInput,
  AsaasCreatePaymentInput,
  AsaasCreateWebhookInput,
  AsaasCustomer,
  AsaasEnvironment,
  AsaasErrorItem,
  AsaasFiscalInfo,
  AsaasInvoice,
  AsaasList,
  AsaasMunicipalOptions,
  AsaasMunicipalService,
  AsaasSaveFiscalInfoInput,
  AsaasPayment,
  AsaasWallet,
  AsaasWebhook,
} from '../../models/asaas.types';

export const ASAAS_BASE_URLS: Record<AsaasEnvironment, string> = {
  sandbox: 'https://api-sandbox.asaas.com/v3',
  production: 'https://api.asaas.com/v3',
};

const USER_AGENT = 'PraticOS';
const REQUEST_TIMEOUT_MS = 20_000;

export class AsaasApiError extends Error {
  readonly status: number;
  readonly errors: AsaasErrorItem[];

  constructor(status: number, errors: AsaasErrorItem[], path: string) {
    super(`Asaas request failed (${status}) on ${path}`);
    this.name = 'AsaasApiError';
    this.status = status;
    this.errors = errors;
  }
}

/** Infers the environment from the key prefix; null when the key is not an Asaas key. */
export function environmentFromApiKey(key: string): AsaasEnvironment | null {
  const trimmed = (key || '').trim();
  if (trimmed.startsWith('$aact_hmlg')) return 'sandbox';
  if (trimmed.startsWith('$aact_prod')) return 'production';
  return null;
}

export interface AsaasClientOptions {
  apiKey: string;
  environment: AsaasEnvironment;
  fetchImpl?: typeof fetch;
}

export class AsaasClient {
  private readonly apiKey: string;
  private readonly baseUrl: string;
  private readonly fetchImpl: typeof fetch;

  constructor(opts: AsaasClientOptions) {
    this.apiKey = opts.apiKey.trim();
    this.baseUrl = ASAAS_BASE_URLS[opts.environment];
    this.fetchImpl = opts.fetchImpl ?? fetch;
  }

  getMyAccount(): Promise<AsaasAccountInfo> {
    return this.request<AsaasAccountInfo>('GET', '/myAccount/commercialInfo');
  }

  async getWallets(): Promise<AsaasWallet[]> {
    const list = await this.request<AsaasList<AsaasWallet>>('GET', '/wallets');
    return list.data ?? [];
  }

  createWebhook(input: AsaasCreateWebhookInput): Promise<AsaasWebhook> {
    return this.request<AsaasWebhook>('POST', '/webhooks', input);
  }

  async deleteWebhook(id: string): Promise<void> {
    await this.request<unknown>('DELETE', `/webhooks/${encodeURIComponent(id)}`);
  }

  async findCustomerByExternalReference(ref: string): Promise<AsaasCustomer | null> {
    const query = new URLSearchParams({ externalReference: ref, limit: '1' });
    const list = await this.request<AsaasList<AsaasCustomer>>('GET', `/customers?${query.toString()}`);
    return list.data?.[0] ?? null;
  }

  createCustomer(input: AsaasCreateCustomerInput): Promise<AsaasCustomer> {
    return this.request<AsaasCustomer>('POST', '/customers', input);
  }

  createPayment(input: AsaasCreatePaymentInput): Promise<AsaasPayment> {
    return this.request<AsaasPayment>('POST', '/payments', input);
  }

  /** GET /payments/{id}: current status of a payment. */
  getPayment(id: string): Promise<AsaasPayment> {
    return this.request<AsaasPayment>('GET', `/payments/${encodeURIComponent(id)}`);
  }

  /** PUT /payments/{id}: only PENDING/OVERDUE payments can be changed. */
  updatePayment(id: string, input: { value: number; description?: string }): Promise<AsaasPayment> {
    return this.request<AsaasPayment>('PUT', `/payments/${encodeURIComponent(id)}`, input);
  }

  /** POST /payments/{id}/receiveInCash: marks the whole payment as received outside Asaas. */
  receiveInCash(
    id: string,
    input: { paymentDate: string; value: number; notifyCustomer: boolean },
  ): Promise<AsaasPayment> {
    return this.request<AsaasPayment>('POST', `/payments/${encodeURIComponent(id)}/receiveInCash`, input);
  }

  async deletePayment(id: string): Promise<void> {
    await this.request<unknown>('DELETE', `/payments/${encodeURIComponent(id)}`);
  }

  async deleteInstallment(id: string): Promise<void> {
    await this.request<unknown>('DELETE', `/installments/${encodeURIComponent(id)}`);
  }

  async listInstallmentPayments(installmentId: string): Promise<AsaasPayment[]> {
    const list = await this.request<AsaasList<AsaasPayment>>(
      'GET',
      `/installments/${encodeURIComponent(installmentId)}/payments?limit=100`,
    );
    return list.data ?? [];
  }

  // --------------------------------------------------------------------------
  // NFS-e (docs/NFSE_ASAAS.md)
  // --------------------------------------------------------------------------

  /** GET /fiscalInfo: null when the account never saved fiscal info (404). */
  async getFiscalInfo(): Promise<AsaasFiscalInfo | null> {
    try {
      return await this.request<AsaasFiscalInfo>('GET', '/fiscalInfo');
    } catch (error) {
      if (error instanceof AsaasApiError && error.status === 404) return null;
      throw error;
    }
  }

  /** POST /fiscalInfo (multipart/form-data, as the Asaas API requires). */
  saveFiscalInfo(input: AsaasSaveFiscalInfoInput): Promise<AsaasFiscalInfo> {
    const form = new FormData();
    for (const [key, value] of Object.entries(input)) {
      if (value === undefined || value === null || value === '') continue;
      form.append(key, String(value));
    }
    return this.request<AsaasFiscalInfo>('POST', '/fiscalInfo', form);
  }

  getMunicipalOptions(): Promise<AsaasMunicipalOptions> {
    return this.request<AsaasMunicipalOptions>('GET', '/fiscalInfo/municipalOptions');
  }

  async listMunicipalServices(description?: string): Promise<AsaasMunicipalService[]> {
    const query = new URLSearchParams({ limit: '100' });
    if (description) query.set('description', description);
    const list = await this.request<AsaasList<AsaasMunicipalService>>(
      'GET',
      `/fiscalInfo/services?${query.toString()}`,
    );
    return list.data ?? [];
  }

  createInvoice(input: AsaasCreateInvoiceInput): Promise<AsaasInvoice> {
    return this.request<AsaasInvoice>('POST', '/invoices', input);
  }

  /** POST /invoices/{id}/authorize: issues a scheduled invoice now. */
  authorizeInvoice(id: string): Promise<AsaasInvoice> {
    return this.request<AsaasInvoice>('POST', `/invoices/${encodeURIComponent(id)}/authorize`);
  }

  /** POST /invoices/{id}/cancel. `onlyOnAsaas`: the city does not cancel through the API. */
  cancelInvoice(id: string, onlyOnAsaas = false): Promise<AsaasInvoice> {
    return this.request<AsaasInvoice>('POST', `/invoices/${encodeURIComponent(id)}/cancel`, {
      cancelOnlyOnAsaas: onlyOnAsaas,
    });
  }

  getInvoice(id: string): Promise<AsaasInvoice> {
    return this.request<AsaasInvoice>('GET', `/invoices/${encodeURIComponent(id)}`);
  }

  private async request<T>(method: 'GET' | 'POST' | 'PUT' | 'DELETE', path: string, body?: unknown): Promise<T> {
    const headers: Record<string, string> = {
      access_token: this.apiKey,
      'User-Agent': USER_AGENT,
      accept: 'application/json',
    };
    const isForm = typeof FormData !== 'undefined' && body instanceof FormData;
    // FormData sets its own multipart boundary header.
    if (body !== undefined && !isForm) headers['content-type'] = 'application/json';

    const response = await this.fetchImpl(`${this.baseUrl}${path}`, {
      method,
      headers,
      body: body === undefined ? undefined : isForm ? (body as FormData) : JSON.stringify(body),
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });

    const text = await response.text();
    let parsed: unknown = undefined;
    if (text) {
      try {
        parsed = JSON.parse(text);
      } catch {
        parsed = undefined;
      }
    }

    if (!response.ok) {
      const errors = (parsed as { errors?: AsaasErrorItem[] } | undefined)?.errors ?? [];
      // Path without query string: query may carry customer references.
      throw new AsaasApiError(response.status, errors, path.split('?')[0]);
    }

    return parsed as T;
  }
}
