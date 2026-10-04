/**
 * Minimal Asaas API v3 client (native fetch).
 * Never logs the API key nor request/response bodies.
 */

import {
  AsaasAccountInfo,
  AsaasCreateCustomerInput,
  AsaasCreatePaymentInput,
  AsaasCreateWebhookInput,
  AsaasCustomer,
  AsaasEnvironment,
  AsaasErrorItem,
  AsaasList,
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

  private async request<T>(method: 'GET' | 'POST' | 'DELETE', path: string, body?: unknown): Promise<T> {
    const headers: Record<string, string> = {
      access_token: this.apiKey,
      'User-Agent': USER_AGENT,
      accept: 'application/json',
    };
    if (body !== undefined) headers['content-type'] = 'application/json';

    const response = await this.fetchImpl(`${this.baseUrl}${path}`, {
      method,
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
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
