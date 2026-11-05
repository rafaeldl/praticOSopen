/**
 * Who may issue and cancel notas with the company's certificate, and what the
 * owner is told (issue #560, from the security review of the vault):
 *
 * - owner, admin and manager issue and cancel (spec decision 11), but the
 *   owner can turn the manager off (settings/nfse.managerCanIssue = false);
 * - when someone other than the owner issues or cancels, the owner gets a
 *   bell + push with who, which nota and the value.
 *
 * The daily ceiling per emitter is in issue.service (reserveDailySlot).
 */

import { db } from '../firestore.service';
import { companyLanguage } from '../courtesy-notice.service';
import { notifyOwnerOfInvoiceAction } from '../notification.service';
import { NfseServiceError } from './errors';

export const ISSUE_ROLES = ['owner', 'admin', 'manager'];

const settingsRef = (companyId: string) => db.collection('companies').doc(companyId).collection('settings').doc('nfse');

/** Throws FORBIDDEN when [role] may not issue or cancel notas in this company now. */
export async function assertMayIssue(companyId: string, role: string | undefined): Promise<void> {
  if (!role || !ISSUE_ROLES.includes(role)) {
    throw new NfseServiceError('FORBIDDEN', 'Only owners, admins and managers can issue notas');
  }
  if (role !== 'manager') return;
  const settings = (await settingsRef(companyId).get()).data();
  if (settings?.managerCanIssue === false) {
    throw new NfseServiceError('FORBIDDEN', 'The owner turned off notas for managers', { reason: 'managerNotAllowed' });
  }
}

export interface InvoiceActionNotice {
  action: 'issued' | 'canceled';
  invoiceId: string;
  /** Who did it. */
  by: { id: string; name: string };
  number?: string | null;
  value?: number | null;
  customerName?: string | null;
}

/** NFS-e is Brazilian: always reais, written the way the company reads. */
function brl(value: number, language: 'pt' | 'es' | 'en'): string {
  const locale = language === 'pt' ? 'pt-BR' : language === 'es' ? 'es-ES' : 'en-US';
  return new Intl.NumberFormat(locale, { style: 'currency', currency: 'BRL' }).format(value);
}

/** Text of the owner notice, in the company's language. */
export function invoiceActionMessage(notice: InvoiceActionNotice, country: string | undefined): { title: string; body: string } {
  const language = companyLanguage(country);
  const who = notice.by.name.trim() || (language === 'pt' ? 'Alguém da equipe' : language === 'es' ? 'Alguien del equipo' : 'Someone on the team');
  const value = typeof notice.value === 'number' ? brl(notice.value, language) : null;
  const to = notice.customerName?.trim() || null;
  if (language === 'pt') {
    const what = notice.action === 'issued' ? 'emitiu uma nota fiscal' : 'cancelou uma nota fiscal';
    return {
      title: notice.action === 'issued' ? 'Nota fiscal emitida' : 'Nota fiscal cancelada',
      body: [`${who} ${what}`, to ? `para ${to}` : null, value ? `de ${value}` : null].filter(Boolean).join(' ') + '.',
    };
  }
  if (language === 'es') {
    const what = notice.action === 'issued' ? 'emitió una factura' : 'canceló una factura';
    return {
      title: notice.action === 'issued' ? 'Factura emitida' : 'Factura cancelada',
      body: [`${who} ${what}`, to ? `para ${to}` : null, value ? `de ${value}` : null].filter(Boolean).join(' ') + '.',
    };
  }
  const what = notice.action === 'issued' ? 'issued an invoice' : 'canceled an invoice';
  return {
    title: notice.action === 'issued' ? 'Invoice issued' : 'Invoice canceled',
    body: [`${who} ${what}`, to ? `to ${to}` : null, value ? `of ${value}` : null].filter(Boolean).join(' ') + '.',
  };
}

/**
 * Tells the owner when someone else issued or canceled. Best effort: a failed
 * notice never fails the nota (logged with the error name only).
 */
export async function noticeOwnerIfTeamMember(companyId: string, notice: InvoiceActionNotice): Promise<boolean> {
  try {
    const company = (await db.collection('companies').doc(companyId).get()).data() as
      | { owner?: { id?: string }; country?: string }
      | undefined;
    if (!company?.owner?.id || company.owner.id === notice.by.id) return false;
    const message = invoiceActionMessage(notice, company.country);
    await notifyOwnerOfInvoiceAction(companyId, { ...message, invoiceId: notice.invoiceId, action: notice.action });
    return true;
  } catch (error) {
    console.error('[nfse] owner notice failed', (error as Error)?.name);
    return false;
  }
}
