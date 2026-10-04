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
  | 'CHARGE_NOT_FOUND'
  | 'CHARGE_NOT_OPEN'
  | 'INSTALLMENTS_IN_PROGRESS';

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
  CHARGE_NOT_FOUND: 404,
  CHARGE_NOT_OPEN: 409,
  INSTALLMENTS_IN_PROGRESS: 409,
};

export class AsaasServiceError extends Error {
  readonly code: AsaasErrorCode;
  readonly httpStatus: number;

  constructor(code: AsaasErrorCode, message: string) {
    super(message);
    this.name = 'AsaasServiceError';
    this.code = code;
    this.httpStatus = HTTP_STATUS[code];
  }
}

export interface HttpErrorBody {
  status: number;
  body: { success: false; error: { code: string; message: string } };
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
      body: { success: false, error: { code: error.code, message: error.message } },
    };
  }
  if (error instanceof AsaasApiError) {
    if (error.status === 400) {
      const message = error.errors[0]?.description || 'Asaas rejected the request';
      return {
        status: 400,
        body: { success: false, error: { code: 'ASAAS_VALIDATION_ERROR', message } },
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
