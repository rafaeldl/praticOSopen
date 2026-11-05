/**
 * Expiry notices of the A1 certificates (issue #565, spec §4.7 and §6 item 8):
 * 30 and 7 days before `certificate.notAfter`, a bell + push to the owner and
 * admins. Runs in the daily job of the nfseApi.
 *
 * companies/{cid}/private/nfse/emitters/{id}.expiryNotice { notAfter, days }
 * records the last notice, so each step goes once per certificate. A new
 * certificate has another `notAfter` and starts over.
 */

import { db } from '../firestore.service';
import { companyLanguage } from '../courtesy-notice.service';
import { notifyCertificateExpiring } from '../notification.service';
import type { FiscalEmitter } from '../../models/nfse-direct.types';

/** Days before the end of validity when the owner is told. */
export const CERTIFICATE_NOTICE_STEPS = [30, 7] as const;

const DAY = 24 * 60 * 60 * 1000;

export interface CertificateNotice {
  /** Which step (30 or 7). */
  step: number;
  /** Days left, rounded up. */
  daysLeft: number;
}

export interface ExpiryNoticeRecord {
  notAfter: string;
  days: number;
}

/** The step due now, or null (expired, far away, or already told). */
export function dueCertificateNotice(notAfter: string, now: Date, last?: ExpiryNoticeRecord | null): CertificateNotice | null {
  const end = Date.parse(notAfter);
  if (Number.isNaN(end) || end <= now.getTime()) return null;
  const daysLeft = Math.ceil((end - now.getTime()) / DAY);
  const steps = CERTIFICATE_NOTICE_STEPS.filter((step) => daysLeft <= step);
  if (steps.length === 0) return null;
  const step = Math.min(...steps);
  const told = last && last.notAfter === notAfter ? last.days : null;
  if (told !== null && told <= step) return null;
  return { step, daysLeft };
}

export interface CertificateMessage {
  title: string;
  body: string;
  days: number;
  emitterId: string;
}

/** Text of the notice, in the company's language. */
export function certificateMessage(legalName: string, daysLeft: number, emitterId: string, country: string | undefined): CertificateMessage {
  const language = companyLanguage(country);
  if (language === 'pt') {
    return {
      days: daysLeft,
      emitterId,
      title: 'Certificado digital vencendo',
      body: `O certificado da ${legalName} vence em ${daysLeft === 1 ? '1 dia' : `${daysLeft} dias`}. Peça um novo ao contador.`,
    };
  }
  if (language === 'es') {
    return {
      days: daysLeft,
      emitterId,
      title: 'Certificado digital por vencer',
      body: `El certificado de ${legalName} vence en ${daysLeft === 1 ? '1 día' : `${daysLeft} días`}. Pide uno nuevo a tu contador.`,
    };
  }
  return {
    days: daysLeft,
    emitterId,
    title: 'Digital certificate expiring',
    body: `The certificate of ${legalName} expires in ${daysLeft === 1 ? '1 day' : `${daysLeft} days`}. Ask your accountant for a new one.`,
  };
}

export interface CertificateNoticeDeps {
  notify: (companyId: string, message: CertificateMessage) => Promise<void>;
}

const defaultDeps: CertificateNoticeDeps = { notify: notifyCertificateExpiring };

/** Notices of one company. A failure on one emitter is logged and retried on the next run. */
export async function sendCertificateNotices(
  companyId: string,
  now: Date,
  deps: CertificateNoticeDeps = defaultDeps,
): Promise<{ sent: number; errors: number }> {
  const company = db.collection('companies').doc(companyId);
  const country = (await company.get()).data()?.country as string | undefined;
  const emitters = await company.collection('fiscalEmitters').where('certificate.status', '==', 'active').get();
  let sent = 0;
  let errors = 0;
  for (const doc of emitters.docs) {
    const emitter = doc.data() as FiscalEmitter;
    const notAfter = emitter.certificate?.notAfter;
    if (!notAfter) continue;
    try {
      const record = company.collection('private').doc('nfse').collection('emitters').doc(doc.id);
      const last = (await record.get()).data()?.expiryNotice as ExpiryNoticeRecord | undefined;
      const notice = dueCertificateNotice(notAfter, now, last);
      if (!notice) continue;
      await deps.notify(companyId, certificateMessage(emitter.legalName, notice.daysLeft, doc.id, country));
      await record.set({ expiryNotice: { notAfter, days: notice.step } }, { merge: true });
      sent++;
    } catch (error) {
      errors++;
      console.error('[nfse] certificate notice failed', { companyId, error: error instanceof Error ? error.message : 'unknown' });
    }
  }
  return { sent, errors };
}
