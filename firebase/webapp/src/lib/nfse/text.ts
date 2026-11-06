// What a nota says on screen (the app's nfseStatusText): the list, the nota in
// the order and the customer's notas use the same sentence and dot.
import { t } from '@/i18n'
import { formatDate } from '@/lib/format'
import { country } from '@/lib/orders/text'
import { isAutoDirectFailure, type NfseInvoice, type NfseStatus } from './model'

export const DOT: Record<NfseStatus, string> = {
  creating: 'warning',
  scheduled: 'warning',
  synchronized: 'warning',
  authorized: 'success',
  processingCancellation: 'warning',
  cancellationDenied: 'danger',
  canceled: 'hollow',
  error: 'danger',
}

export function invoiceStatusText(invoice: NfseInvoice, todayDay: string): string {
  if (invoice.conflict) return t('nfseConflictNotice')
  switch (invoice.status) {
    case 'scheduled':
      return invoice.effectiveDate && invoice.effectiveDate > todayDay
        ? t('nfseStatusScheduledFor', { date: formatDate(`${invoice.effectiveDate}T12:00:00`, country()) })
        : t('nfseStatusWaiting')
    case 'authorized':
      if (invoice.auto) return invoice.number ? t('nfseStatusIssuedAutoNumber', { number: invoice.number }) : t('nfseStatusIssuedAuto')
      return invoice.number ? t('nfseStatusIssuedNumber', { number: invoice.number }) : t('nfseStatusIssued')
    case 'processingCancellation':
      return t('nfseStatusCanceling')
    case 'cancellationDenied':
      return t('nfseStatusCancelDenied')
    case 'canceled':
      return t('nfseStatusCanceled')
    case 'error':
      return isAutoDirectFailure(invoice) ? autoFailureShort(invoice.errorCode ?? '') : t('nfseStatusError')
    default:
      return t('nfseStatusWaiting')
  }
}

/** Short reason of an automatic direct nota that did not go out (the app's nfseAutoErrorShort). */
export function autoFailureShort(code: string): string {
  switch (code) {
    case 'RECIPIENT_TAX_ID_REQUIRED':
      return t('nfseAutoMissingTaxId')
    case 'CERT_EXPIRED':
      return t('nfseAutoCertificateExpired')
    case 'CERT_NOT_FOUND':
    case 'EMITTER_NOT_READY':
    case 'EMITTER_NOT_FOUND':
      return t('nfseAutoEmitterNotReady')
    case 'DAILY_LIMIT_REACHED':
      return t('nfseAutoDailyLimit')
    default:
      return t('nfseAutoNotIssued')
  }
}

/** Why an automatic direct nota did not go out, in full (the app's nfseAutoErrorReason). */
export function autoFailureReason(code: string): string {
  switch (code) {
    case 'RECIPIENT_TAX_ID_REQUIRED':
      return t('nfseDirectErrorRecipientTaxId')
    case 'CERT_EXPIRED':
      return t('nfseDirectErrorExpired')
    case 'CERT_NOT_FOUND':
    case 'EMITTER_NOT_READY':
      return t('nfseDirectErrorEmitterNotReady')
    case 'EMITTER_NOT_FOUND':
      return t('nfseAutoErrorPickEmitter')
    case 'DAILY_LIMIT_REACHED':
      return t('nfseDirectErrorDailyLimit')
    case 'SEFIN_UNAVAILABLE':
    case 'KEY_VAULT_UNAVAILABLE':
      return t('nfseDirectErrorUnavailable')
    default:
      return t('nfseDirectErrorGeneric')
  }
}
