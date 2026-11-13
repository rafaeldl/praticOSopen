/**
 * Notice to the Free companies that already exist (decision of 2026-11-13):
 * the new Free has 10 work orders a month, starting on
 * `config/paidPlans.limitsStartAt`. Nothing is sent until the owner of the
 * product writes that date; then a daily job, in the 15 days before it, sends
 * once per company a push to owners and admins and an e-mail to the owner.
 * The app (Início) and the web (Início) show the same notice in that window.
 *
 * Only companies in use are told: Free in force and work orders this month
 * or the month before. The others see the banner when they come back.
 *
 * companies/{cid}/settings/freeLimitsNotice { startsAt, push, email } records
 * what went out, by channel: a failed channel is retried the next day, the
 * other is not sent twice. A new date is a new notice.
 *
 * Logs carry ids and counts only: never the address nor the content.
 */

import { getRootCollection, db } from './firestore.service';
import { notifyFreeLimitsStarting } from './notification.service';
import { effectivePlan, getPaidPlansConfig, ordersUsage } from './plan-limits.service';
import { freeLimitsNoticeDue } from './paid-plans-config';
import { planRow } from './subscription-plans';
import { companyLanguage } from './courtesy-notice.service';
import { sendWithResend, type OutgoingEmail } from './nfse/invoice-email.service';
import type { Subscription } from '../models/types';

export const FREE_LIMITS_EMAIL_FROM = 'PraticOS <avisos@praticos.app>';

export interface FreeLimitsMessage {
  title: string;
  body: string;
  subject: string;
  text: string;
  html: string;
}

const DATE_LOCALE = { pt: 'pt-BR', es: 'es', en: 'en-US' } as const;

/** Day and month in the company's language, São Paulo time ("15/12", "December 15"). */
export function startDay(startsAt: Date, language: 'pt' | 'es' | 'en'): string {
  const options: Intl.DateTimeFormatOptions =
    language === 'en'
      ? { month: 'long', day: 'numeric', timeZone: 'America/Sao_Paulo' }
      : { day: '2-digit', month: '2-digit', timeZone: 'America/Sao_Paulo' };
  return new Intl.DateTimeFormat(DATE_LOCALE[language], options).format(startsAt);
}

const escapeHtml = (text: string) =>
  text.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);

/** Push and e-mail text, in the company's language. Never mentions AI (internal ceilings). */
export function freeLimitsMessage(startsAt: Date, country: string | undefined, companyName = ''): FreeLimitsMessage {
  const free = planRow('free').ordersPerMonth;
  const language = companyLanguage(country);
  const day = startDay(startsAt, language);
  let title: string;
  let body: string;
  let subject: string;
  let lines: string[];
  if (language === 'pt') {
    title = `O plano Free muda em ${day}`;
    body = `A partir de ${day}, o Free tem ${free} OS por mês. Se precisar de mais, escolha um plano no app.`;
    subject = `O plano Free do PraticOS muda em ${day}`;
    lines = [
      companyName ? `Olá, ${companyName}.` : 'Olá.',
      `A partir de ${day}, o plano Free do PraticOS passa a ter ${free} OS por mês.`,
      'Tudo o que você já cadastrou continua aí, e as OS abertas não travam.',
      'Se você abre mais OS por mês, escolha um plano no app, na tela Plano (botão do perfil, no topo do Início).',
      'Dúvidas? É só responder este e-mail.',
    ];
  } else if (language === 'es') {
    title = `El plan Free cambia el ${day}`;
    body = `Desde el ${day}, el Free incluye ${free} órdenes por mes. Si necesitas más, elige un plan en la app.`;
    subject = `El plan Free de PraticOS cambia el ${day}`;
    lines = [
      companyName ? `Hola, ${companyName}.` : 'Hola.',
      `Desde el ${day}, el plan Free de PraticOS incluye ${free} órdenes por mes.`,
      'Todo lo que ya registraste sigue ahí, y las órdenes abiertas no se bloquean.',
      'Si abres más órdenes por mes, elige un plan en la app, en la pantalla Plan.',
      '¿Dudas? Responde este correo.',
    ];
  } else {
    title = `The Free plan changes on ${day}`;
    body = `From ${day}, Free includes ${free} work orders a month. If you need more, choose a plan in the app.`;
    subject = `The PraticOS Free plan changes on ${day}`;
    lines = [
      companyName ? `Hi, ${companyName}.` : 'Hi.',
      `From ${day}, the PraticOS Free plan includes ${free} work orders a month.`,
      'Everything you saved stays there, and open work orders never lock.',
      'If you open more work orders a month, choose a plan in the app, on the Plan screen.',
      'Questions? Just reply to this e-mail.',
    ];
  }
  return {
    title,
    body,
    subject,
    text: lines.join('\n\n'),
    html: lines.map((line) => `<p>${escapeHtml(line)}</p>`).join('\n'),
  };
}

export interface FreeLimitsNoticeDeps {
  push: (companyId: string, message: FreeLimitsMessage, startsAt: string) => Promise<void>;
  email: (email: OutgoingEmail) => Promise<unknown>;
}

const defaultDeps: FreeLimitsNoticeDeps = {
  push: (companyId, message, startsAt) => notifyFreeLimitsStarting(companyId, { title: message.title, body: message.body, startsAt }),
  email: (email) => sendWithResend(email),
};

interface NoticeRecord {
  startsAt?: string;
  push?: boolean;
  email?: boolean;
}

const CONCURRENCY = 5;
const EMAIL_PATTERN = /^[^\s@<>"',;]+@[^\s@<>"',;]+\.[^\s@<>"',;]+$/;

async function ownerEmail(company: FirebaseFirestore.DocumentSnapshot): Promise<string | null> {
  const owner = company.get('owner') as { id?: string; email?: string } | undefined;
  let email = owner?.email;
  if (!email && owner?.id) email = (await db.collection('users').doc(owner.id).get()).get('email') as string | undefined;
  return email && EMAIL_PATTERN.test(email) ? email : null;
}

/** A failure on one company is logged and retried on the next run. */
export async function sendFreeLimitsNotices(
  now: Date,
  deps: FreeLimitsNoticeDeps = defaultDeps,
): Promise<{ checked: number; sent: number; errors: number }> {
  const config = await getPaidPlansConfig(now.getTime());
  // Before the window (or with no date) nothing is read: the job costs one read.
  if (!freeLimitsNoticeDue(config, true, now)) return { checked: 0, sent: 0, errors: 0 };
  const startsAt = config.limitsStartAt!.toISOString();

  const snapshot = await getRootCollection('companies').select('subscription', 'country', 'name', 'owner').get();
  const due = snapshot.docs.filter((doc) => {
    const subscription = doc.get('subscription') as Subscription | undefined;
    const json = subscription as unknown as Record<string, unknown> | undefined;
    if (effectivePlan(json, now) !== 'free') return false;
    const { thisMonth, lastMonth } = ordersUsage(subscription?.usage, now);
    return thisMonth + lastMonth > 0;
  });

  let sent = 0;
  let errors = 0;
  let next = 0;
  const worker = async (): Promise<void> => {
    while (next < due.length) {
      const doc = due[next++];
      try {
        const ref = doc.ref.collection('settings').doc('freeLimitsNotice');
        const stored = ((await ref.get()).data() ?? {}) as NoticeRecord;
        const last: NoticeRecord = stored.startsAt === startsAt ? stored : {};
        if (last.push && last.email) continue;
        const message = freeLimitsMessage(config.limitsStartAt!, doc.get('country') as string | undefined, (doc.get('name') as string | undefined) ?? '');
        const record: NoticeRecord = { startsAt, push: last.push === true, email: last.email === true };
        let failed = false;
        if (!record.push) {
          try {
            await deps.push(doc.id, message, startsAt);
            record.push = true;
          } catch {
            failed = true;
          }
        }
        if (!record.email) {
          const to = await ownerEmail(doc);
          if (!to) {
            record.email = true; // no address: nothing to retry
          } else {
            try {
              await deps.email({
                from: FREE_LIMITS_EMAIL_FROM,
                to,
                replyTo: 'praticos@rafsoft.com.br',
                subject: message.subject,
                text: message.text,
                html: message.html,
                attachments: [],
                idempotencyKey: `free-limits-${doc.id}-${startsAt}`,
              });
              record.email = true;
            } catch {
              failed = true;
            }
          }
        }
        await ref.set(record);
        if (failed) errors++;
        else sent++;
      } catch (error) {
        errors++;
        console.error('[Subscription] Free limits notice failed', {
          companyId: doc.id,
          error: error instanceof Error ? error.message : 'unknown',
        });
      }
    }
  };
  await Promise.all(Array.from({ length: Math.min(CONCURRENCY, due.length) }, worker));

  console.log(`[Subscription] Free limits notices: checked=${due.length} sent=${sent} errors=${errors}`);
  return { checked: due.length, sent, errors };
}
