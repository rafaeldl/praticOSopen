/**
 * Business errors of the NFS-e direct engine, mapped to HTTP by the routes.
 * The app shows a sentence per `code`; the text here is for logs only.
 */

export type NfseErrorCode =
  | 'NFSE_DIRECT_NOT_ENABLED'
  | 'FORBIDDEN'
  | 'VALIDATION_ERROR'
  | 'CERT_INVALID_FILE'
  | 'CERT_WRONG_PASSWORD'
  | 'CERT_EXPIRED'
  | 'CERT_NOT_YET_VALID'
  | 'CERT_NOT_ICP_BRASIL'
  | 'CERT_NO_TAX_ID'
  | 'CERT_TAX_ID_MISMATCH'
  | 'CERT_NOT_FOUND'
  | 'EMITTER_NOT_FOUND'
  | 'EMITTER_ALREADY_EXISTS'
  | 'TERMS_NOT_ACCEPTED'
  | 'KEY_VAULT_UNAVAILABLE'
  | 'TOO_MANY_ATTEMPTS'
  | 'CERT_BUSY'
  | 'DAILY_LIMIT_REACHED'
  | 'EMITTER_NOT_READY'
  | 'RECIPIENT_TAX_ID_REQUIRED'
  | 'NFSE_REFUSED'
  | 'INVOICE_NOT_FOUND'
  | 'INVOICE_NOT_CANCELABLE'
  | 'CANCEL_REFUSED'
  | 'SEFIN_UNAVAILABLE'
  | 'ORDER_HAS_INVOICE'
  | 'PDF_NOT_AVAILABLE';

const HTTP_STATUS: Record<NfseErrorCode, number> = {
  NFSE_DIRECT_NOT_ENABLED: 403,
  FORBIDDEN: 403,
  VALIDATION_ERROR: 400,
  CERT_INVALID_FILE: 400,
  CERT_WRONG_PASSWORD: 400,
  CERT_EXPIRED: 400,
  CERT_NOT_YET_VALID: 400,
  CERT_NOT_ICP_BRASIL: 400,
  CERT_NO_TAX_ID: 400,
  CERT_TAX_ID_MISMATCH: 409,
  CERT_NOT_FOUND: 404,
  EMITTER_NOT_FOUND: 404,
  EMITTER_ALREADY_EXISTS: 409,
  TERMS_NOT_ACCEPTED: 400,
  KEY_VAULT_UNAVAILABLE: 503,
  TOO_MANY_ATTEMPTS: 429,
  CERT_BUSY: 409,
  DAILY_LIMIT_REACHED: 429,
  EMITTER_NOT_READY: 409,
  RECIPIENT_TAX_ID_REQUIRED: 400,
  NFSE_REFUSED: 422,
  INVOICE_NOT_FOUND: 404,
  INVOICE_NOT_CANCELABLE: 409,
  CANCEL_REFUSED: 422,
  SEFIN_UNAVAILABLE: 503,
  ORDER_HAS_INVOICE: 409,
  PDF_NOT_AVAILABLE: 409,
};

export class NfseServiceError extends Error {
  readonly code: NfseErrorCode;
  readonly httpStatus: number;
  /** Extra data for the app (e.g. the refusal: group and message in pt/en/es). */
  readonly details?: Record<string, unknown>;

  constructor(code: NfseErrorCode, message: string, details?: Record<string, unknown>) {
    super(message);
    this.name = 'NfseServiceError';
    this.code = code;
    this.httpStatus = HTTP_STATUS[code];
    if (details) this.details = details;
  }
}

export interface NfseHttpError {
  status: number;
  body: { success: false; error: { code: string; message: string; details?: Record<string, unknown> } };
}

/** Business errors keep their code; anything else is a 500 without details (never echoes the input). */
export function toNfseHttpError(error: unknown, fallbackMessage: string): NfseHttpError {
  if (error instanceof NfseServiceError) {
    return {
      status: error.httpStatus,
      body: { success: false, error: { code: error.code, message: error.message, ...(error.details ? { details: error.details } : {}) } },
    };
  }
  return { status: 500, body: { success: false, error: { code: 'INTERNAL_ERROR', message: fallbackMessage } } };
}
