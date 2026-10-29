/**
 * Business errors of the Asaas integration, mapped to HTTP by the routes.
 * The app (AsaasApiService) shows a message per `code`.
 */

import { AsaasApiError } from './asaas-client';

export type AsaasErrorCode =
  | 'ASAAS_NOT_ENABLED'
  | 'ASAAS_INVALID_API_KEY'
  | 'ASAAS_NOT_CONNECTED'
  | 'ASAAS_VALIDATION_ERROR'
  | 'ASAAS_UNAVAILABLE'
  | 'ORDER_NOT_FOUND'
  | 'ORDER_CANCELED'
  | 'INVALID_VALUE'
  | 'INVALID_INSTALLMENT_COUNT'
  | 'INVALID_DUE_DATE'
  | 'CUSTOMER_REQUIRED'
  | 'TAX_ID_REQUIRED'
  | 'INVALID_TAX_ID'
  | 'CUSTOMER_DATA_REQUIRED'
  | 'NFSE_SETUP_REJECTED'
  | 'CHARGE_NOT_FOUND'
  | 'CHARGE_NOT_OPEN'
  | 'INSTALLMENTS_IN_PROGRESS'
  | 'CUSTOMER_NOT_FOUND'
  | 'ORDER_NOT_OF_CUSTOMER'
  | 'ORDER_NOT_PAYABLE'
  | 'CUSTOMER_CHARGE_OPEN'
  | 'RECEIPT_EXISTS'
  | 'INVALID_PAID_AT'
  | 'INVALID_FILE'
  | 'VALUE_EXCEEDS_BALANCE'
  | 'CHARGE_SUPERSEDED'
  | 'PREVIOUS_LINK_CANCELED'
  | 'NFSE_NOT_ENABLED'
  | 'NFSE_NOT_READY'
  | 'NFSE_SETUP_NEEDED'
  | 'NFSE_RECONNECT_NEEDED'
  | 'INVOICE_OTHER_ACCOUNT'
  | 'NFSE_ORDER_NOT_ALLOWED'
  | 'NO_SERVICES'
  | 'ORDER_HAS_INVOICE'
  | 'INVOICE_NOT_FOUND'
  | 'INVOICE_NOT_CANCELABLE'
  | 'CANCEL_NOT_SUPPORTED'
  | 'INVALID_EFFECTIVE_DATE'
  | 'INVALID_FISCAL_INFO';

const HTTP_STATUS: Record<AsaasErrorCode, number> = {
  ASAAS_NOT_ENABLED: 403,
  ASAAS_INVALID_API_KEY: 400,
  ASAAS_NOT_CONNECTED: 409,
  ASAAS_VALIDATION_ERROR: 400,
  ASAAS_UNAVAILABLE: 502,
  ORDER_NOT_FOUND: 404,
  ORDER_CANCELED: 409,
  INVALID_VALUE: 400,
  INVALID_INSTALLMENT_COUNT: 400,
  INVALID_DUE_DATE: 400,
  CUSTOMER_REQUIRED: 400,
  TAX_ID_REQUIRED: 400,
  INVALID_TAX_ID: 400,
  CUSTOMER_DATA_REQUIRED: 400,
  NFSE_SETUP_REJECTED: 400,
  CHARGE_NOT_FOUND: 404,
  CHARGE_NOT_OPEN: 409,
  INSTALLMENTS_IN_PROGRESS: 409,
  CUSTOMER_NOT_FOUND: 404,
  ORDER_NOT_OF_CUSTOMER: 400,
  ORDER_NOT_PAYABLE: 409,
  CUSTOMER_CHARGE_OPEN: 409,
  RECEIPT_EXISTS: 409,
  INVALID_PAID_AT: 400,
  INVALID_FILE: 400,
  VALUE_EXCEEDS_BALANCE: 409,
  CHARGE_SUPERSEDED: 409,
  PREVIOUS_LINK_CANCELED: 409,
  NFSE_NOT_ENABLED: 403,
  NFSE_NOT_READY: 409,
  NFSE_SETUP_NEEDED: 409,
  NFSE_RECONNECT_NEEDED: 409,
  INVOICE_OTHER_ACCOUNT: 409,
  NFSE_ORDER_NOT_ALLOWED: 409,
  NO_SERVICES: 409,
  ORDER_HAS_INVOICE: 409,
  INVOICE_NOT_FOUND: 404,
  INVOICE_NOT_CANCELABLE: 409,
  CANCEL_NOT_SUPPORTED: 409,
  INVALID_EFFECTIVE_DATE: 400,
  INVALID_FISCAL_INFO: 400,
};

export class AsaasServiceError extends Error {
  readonly code: AsaasErrorCode;
  readonly httpStatus: number;
  /** Asaas's own text (pt-BR), shown to the user when it explains a refusal. */
  readonly detail?: string;

  constructor(code: AsaasErrorCode, message: string, detail?: string | null) {
    super(message);
    this.name = 'AsaasServiceError';
    this.code = code;
    this.httpStatus = HTTP_STATUS[code];
    if (detail) this.detail = detail;
  }
}

export interface HttpErrorBody {
  status: number;
  body: { success: false; error: { code: string; message: string; detail?: string } };
}

/** Asaas's error texts joined ("E-mail do cliente incompleto. CEP ..."), or null. */
export function asaasErrorDescription(error: AsaasApiError): string | null {
  const text = error.errors.map((e) => (e.description ?? '').trim()).filter((d) => d.length > 0).join(' ');
  return text || null;
}

/**
 * Asaas error codes and texts for the log. They describe what is wrong
 * ("CEP do cliente é inválido"), never echo the customer's data.
 */
export function asaasErrorLog(error: AsaasApiError): string {
  const items = error.errors.map((e) => `${e.code ?? '?'}: ${(e.description ?? '').slice(0, 200)}`.trim());
  return `status ${error.status}${items.length > 0 ? ` [${items.join(' | ')}]` : ''}`;
}

/** Raw fetch failures: timeout/abort (AbortSignal.timeout) and network errors ("fetch failed"). */
function isNetworkFailure(error: unknown): boolean {
  if (!error || typeof error !== 'object') return false;
  const { name, message, cause } = error as { name?: string; message?: string; cause?: unknown };
  if (name === 'TimeoutError' || name === 'AbortError') return true;
  return error instanceof TypeError && (/fetch failed/i.test(message ?? '') || cause !== undefined);
}

/**
 * Converts any error thrown by the Asaas services into the API error format.
 * Never includes the API key, tokens or request payloads.
 */
export function toHttpError(error: unknown, fallbackMessage: string): HttpErrorBody {
  if (error instanceof AsaasServiceError) {
    return {
      status: error.httpStatus,
      body: {
        success: false,
        error: { code: error.code, message: error.message, ...(error.detail ? { detail: error.detail } : {}) },
      },
    };
  }
  if (error instanceof AsaasApiError) {
    if (error.status === 400) {
      const detail = asaasErrorDescription(error);
      const message = error.errors[0]?.description || 'Asaas rejected the request';
      return {
        status: 400,
        body: { success: false, error: { code: 'ASAAS_VALIDATION_ERROR', message, ...(detail ? { detail } : {}) } },
      };
    }
    if (error.status === 401 || error.status === 403) {
      return {
        status: HTTP_STATUS.ASAAS_INVALID_API_KEY,
        body: {
          success: false,
          error: { code: 'ASAAS_INVALID_API_KEY', message: 'Asaas API key was rejected' },
        },
      };
    }
    return {
      status: 502,
      body: { success: false, error: { code: 'ASAAS_UNAVAILABLE', message: 'Asaas is unavailable' } },
    };
  }
  if (isNetworkFailure(error)) {
    return {
      status: HTTP_STATUS.ASAAS_UNAVAILABLE,
      body: { success: false, error: { code: 'ASAAS_UNAVAILABLE', message: 'Asaas is unavailable' } },
    };
  }
  return {
    status: 500,
    body: { success: false, error: { code: 'INTERNAL_ERROR', message: fallbackMessage } },
  };
}
