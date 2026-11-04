// What a nota says on screen (the app's nfseStatusText): the list, the nota in
// the order and the customer's notas use the same sentence and dot.
import { t } from '@/i18n'
import { formatDate } from '@/lib/format'
import { country } from '@/lib/orders/text'
import type { NfseInvoice, NfseStatus } from './model'

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
      return invoice.number ? t('nfseStatusIssuedNumber', { number: invoice.number }) : t('nfseStatusIssued')
    case 'processingCancellation':
      return t('nfseStatusCanceling')
    case 'cancellationDenied':
      return t('nfseStatusCancelDenied')
    case 'canceled':
      return t('nfseStatusCanceled')
    case 'error':
      return t('nfseStatusError')
    default:
      return t('nfseStatusWaiting')
  }
}
