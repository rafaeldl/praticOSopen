// HTTP client for the Functions API. Errors reach the screen only as message
// keys: the server's text is English, technical and may carry internal detail.
import type { MessageKey } from '@/generated/message-keys'

const CODE_MESSAGES: Record<string, MessageKey> = {
  UNAUTHORIZED: 'web.error.sessionExpired',
  TOKEN_EXPIRED: 'web.error.sessionExpired',
  INVALID_TOKEN: 'web.error.sessionExpired',
  FORBIDDEN: 'web.error.forbidden',
  INSUFFICIENT_PERMISSIONS: 'web.error.forbidden',
  NOT_FOUND: 'web.error.notFound',
  ORDER_NOT_FOUND: 'web.error.notFound',
  CUSTOMER_NOT_FOUND: 'web.error.notFound',
  DEVICE_NOT_FOUND: 'web.error.notFound',
  CHARGE_NOT_FOUND: 'web.error.notFound',
  INVOICE_NOT_FOUND: 'web.error.notFound',
  VALIDATION_ERROR: 'web.error.validation',
  INVALID_REQUEST: 'web.error.validation',
  INVALID_STATUS: 'web.error.conflict',
  INVALID_STATE: 'web.error.conflict',
  INVALID_TRANSITION: 'web.error.conflict',
  ALREADY_MEMBER: 'web.error.conflict',
  RATE_LIMIT_EXCEEDED: 'web.error.rateLimit',
  ASAAS_UNAVAILABLE: 'web.error.unavailable',
  ORDER_CHANGED: 'web.error.orderChanged',
  ITEM_NOT_FOUND: 'web.error.orderChanged',
  TRANSACTION_ID_CONFLICT: 'web.error.orderChanged',
  HOLD_NOT_ALLOWED: 'web.error.holdNotAllowed',
  ORDER_HAS_INVOICE: 'web.error.orderDeleteBlocked',
  CUSTOMER_CHARGE_OPEN: 'web.error.orderDeleteBlocked',
  INSTALLMENTS_IN_PROGRESS: 'web.error.orderDeleteBlocked',
  INVALID_ASSIGNEE: 'web.error.validation',
  PAYMENT_EXCEEDS_BALANCE: 'web.error.paymentExceeds',
  // Asaas and notas fiscais: the same sentences as the app (asaas_error_text.dart, pay.errors.text).
  ASAAS_INVALID_API_KEY: 'asaasErrorInvalidKey',
  ASAAS_VALIDATION_ERROR: 'asaasErrorValidation',
  ORDER_NOT_PAYABLE: 'asaasErrorOrderNotPayable',
  ORDER_CANCELED: 'asaasErrorOrderCanceled',
  INVALID_DUE_DATE: 'asaasErrorInvalidDueDate',
  INVALID_INSTALLMENT_COUNT: 'asaasErrorInvalidInstallmentCount',
  CHARGE_NOT_OPEN: 'asaasErrorChargeNotOpen',
  NFSE_NOT_ENABLED: 'nfseErrorNotEnabled',
  NFSE_NOT_READY: 'nfseErrorNotReady',
  NFSE_SETUP_NEEDED: 'nfseErrorSetupNeeded',
  NFSE_RECONNECT_NEEDED: 'nfseErrorReconnectNeeded',
  NFSE_SETUP_REJECTED: 'nfseErrorSetupRejected',
  INVOICE_OTHER_ACCOUNT: 'nfseErrorOtherAccount',
  INVOICE_NOT_CANCELABLE: 'nfseErrorNotCancelable',
  CANCEL_NOT_SUPPORTED: 'nfseErrorCancelNotSupported',
  INVALID_FISCAL_INFO: 'nfseErrorInvalidFiscalInfo',
  NFSE_ORDER_NOT_ALLOWED: 'nfseErrorOrderNotAllowed',
  NO_SERVICES: 'nfseErrorNoServices',
  ORDER_NOT_OF_CUSTOMER: 'nfseErrorOrderNotOfCustomer',
  INVALID_EFFECTIVE_DATE: 'nfseErrorInvalidDate',
  CUSTOMER_DATA_REQUIRED: 'nfseErrorCustomerData',
  // NFS-e direct: certificate and emitters (the app's nfse_direct_texts.dart).
  CERT_INVALID_FILE: 'nfseDirectErrorInvalidFile',
  CERT_WRONG_PASSWORD: 'nfseDirectErrorWrongPassword',
  CERT_EXPIRED: 'nfseDirectErrorExpired',
  CERT_NOT_YET_VALID: 'nfseDirectErrorNotYetValid',
  CERT_NOT_ICP_BRASIL: 'nfseDirectErrorNotIcpBrasil',
  CERT_NO_TAX_ID: 'nfseDirectErrorNoTaxId',
  CERT_TAX_ID_MISMATCH: 'nfseDirectErrorOtherTaxId',
  EMITTER_ALREADY_EXISTS: 'nfseDirectErrorAlreadyExists',
  EMITTER_NOT_FOUND: 'nfseDirectErrorNotFound',
  CERT_NOT_FOUND: 'nfseDirectErrorNotFound',
  NFSE_DIRECT_NOT_ENABLED: 'nfseDirectErrorNotEnabled',
  KEY_VAULT_UNAVAILABLE: 'nfseDirectErrorUnavailable',
  // NFS-e direct: "Importar notas" (the app's nfse_import_screen.dart).
  SEFIN_UNAVAILABLE: 'nfseDirectErrorGovUnavailable',
  IMPORT_NOT_FOUND: 'nfseDirectErrorNotFound',
  IMPORT_UNDO_EXPIRED: 'nfseImportErrorUndoExpired',
}

/** The sentence for a code the server sends, when there is one of its own (tests). */
export const codeMessageKey = (code: string): MessageKey | undefined => CODE_MESSAGES[code]

function statusMessage(status: number): MessageKey {
  if (status === 401) return 'web.error.sessionExpired'
  if (status === 403) return 'web.error.forbidden'
  if (status === 404) return 'web.error.notFound'
  if (status === 409) return 'web.error.conflict'
  if (status === 429) return 'web.error.rateLimit'
  if (status === 400 || status === 422) return 'web.error.validation'
  if (status === 502 || status === 503 || status === 504) return 'web.error.unavailable'
  return 'web.error.generic'
}

/** `message` stays technical, for logs. Show `messageKey` to people. */
export class ApiError extends Error {
  constructor(
    readonly code: string,
    readonly status: number,
    readonly messageKey: MessageKey,
    /** The server's own text about a refusal (Asaas's, for notas). Shown only where a screen asks for it. */
    readonly detail?: string,
    /** Structured extra data of the error (the NFS-e direct refusal, the emitter problem). */
    readonly details?: Record<string, unknown>,
  ) {
    super(`API ${status} ${code}`)
    this.name = 'ApiError'
  }
}

/** The key to show for any thrown value, never the raw text. */
export function errorMessageKey(error: unknown): MessageKey {
  return error instanceof ApiError ? error.messageKey : 'web.error.generic'
}

export interface ApiDeps {
  baseUrl: () => string
  /** ID token; `forceRefresh` when the server rejected the cached one. */
  getToken: (forceRefresh: boolean) => Promise<string | null>
  getCompanyId: () => string | null
  fetch?: typeof fetch
}

export interface ApiOptions {
  method?: 'GET' | 'POST' | 'PATCH' | 'PUT' | 'DELETE'
  body?: unknown
  signal?: AbortSignal
  /** Sends a specific company instead of the current one. */
  companyId?: string
  /** Account routes must not carry X-Company-Id. */
  noCompany?: boolean
  /** The whole envelope (lists carry `pagination` next to `data`). */
  raw?: boolean
}

interface Envelope<T> {
  success?: boolean
  data?: T
  error?: { code?: unknown; detail?: unknown; details?: unknown }
}

export function createApi(deps: ApiDeps) {
  async function send(path: string, options: ApiOptions, forceRefresh: boolean): Promise<Response> {
    const token = await deps.getToken(forceRefresh)
    if (!token) throw new ApiError('NO_SESSION', 401, 'web.error.sessionExpired')
    const headers: Record<string, string> = { Authorization: `Bearer ${token}` }
    const companyId = options.noCompany ? null : (options.companyId ?? deps.getCompanyId())
    if (companyId) headers['X-Company-Id'] = companyId
    if (options.body !== undefined) headers['Content-Type'] = 'application/json'
    try {
      return await (deps.fetch ?? fetch)(`${deps.baseUrl()}${path}`, {
        method: options.method ?? 'GET',
        headers,
        body: options.body === undefined ? undefined : JSON.stringify(options.body),
        signal: options.signal,
      })
    } catch (error) {
      if ((error as Error)?.name === 'AbortError') throw error
      throw new ApiError('NETWORK', 0, 'web.error.network')
    }
  }

  async function request<T>(path: string, options: ApiOptions = {}): Promise<T> {
    let response = await send(path, options, false)
    if (response.status === 401) response = await send(path, options, true)
    let body: Envelope<T> | undefined
    try {
      body = (await response.json()) as Envelope<T>
    } catch {
      body = undefined
    }
    if (!response.ok || body?.success === false) {
      const code = typeof body?.error?.code === 'string' ? body.error.code : 'UNKNOWN'
      const detail = typeof body?.error?.detail === 'string' ? body.error.detail : undefined
      const raw = body?.error?.details
      const details = raw && typeof raw === 'object' && !Array.isArray(raw) ? (raw as Record<string, unknown>) : undefined
      throw new ApiError(code, response.status, CODE_MESSAGES[code] ?? statusMessage(response.status), detail, details)
    }
    return (options.raw ? body : (body?.data ?? body)) as T
  }

  return { request }
}
