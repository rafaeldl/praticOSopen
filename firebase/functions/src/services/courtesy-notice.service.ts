/**
 * End of the launch courtesy (docs/SUBSCRIPTION.md): a daily job tells owners
 * and admins 15 and 3 days before `expiresAt`; with the plan limits on
 * (config/paidPlans), also the work orders of the month against Free. With
 * them off Free has no order limit, so no number is said. The assistant is not mentioned: its ceilings are
 * internal and the customer never sees a counter (#726).
 * The push does not open anything: the banner on Início carries the paywall.
 *
 * companies/{cid}/settings/courtesyNotice { expiresAt, days } records the last
 * push. It stays out of `subscription`: the Firestore rules reject a client
 * save that drops a field from that map, and app versions up to 1.55 rewrite it.
 */

import { getRootCollection } from './firestore.service';
import { notifyCourtesyEnding } from './notification.service';
import { CourtesyNoticeRecord, dueCourtesyNotice, planRow } from './subscription-plans';
import { isPaidPlansEnabled, ordersUsage } from './plan-limits.service';
import type { Subscription } from '../models/types';

export interface CourtesyMessage {
  title: string;
  body: string;
  days: number;
}

const PORTUGUESE = ['BR', 'PT', 'AO', 'MZ'];
const SPANISH = ['ES', 'MX', 'AR', 'CL', 'CO', 'PE', 'UY', 'PY', 'BO', 'EC', 'VE', 'CR', 'PA', 'DO', 'GT', 'HN', 'SV', 'NI'];

/** Language of a company's pushes (no country: pt; unknown: en). */
export function companyLanguage(country: string | undefined): 'pt' | 'es' | 'en' {
  if (!country || PORTUGUESE.includes(country)) return 'pt';
  return SPANISH.includes(country) ? 'es' : 'en';
}

/**
 * Text of the push, in the company's language. `orders` is the work orders
 * of the month; 0 (or limits off, see sendCourtesyNotices) says only that
 * the app goes back to Free.
 */
export function courtesyMessage(days: number, orders: number, country: string | undefined): CourtesyMessage {
  const free = planRow('free').ordersPerMonth;
  const language = companyLanguage(country);
  if (language === 'pt') {
    return {
      days,
      title: `Sua cortesia do Pro acaba em ${days === 1 ? '1 dia' : `${days} dias`}`,
      body: orders > 0
        ? `Neste mês você abriu ${orders} OS. No Free são ${free} por mês. Escolha seu plano no app.`
        : 'Depois disso, o app volta para o plano Free. Escolha seu plano no app.',
    };
  }
  if (language === 'es') {
    return {
      days,
      title: `Tu cortesía Pro termina en ${days === 1 ? '1 día' : `${days} días`}`,
      body: orders > 0
        ? `Abriste ${orders === 1 ? '1 orden' : `${orders} órdenes`} este mes. El plan Free incluye ${free} por mes. Elige un plan en la app.`
        : 'Después, la app vuelve al plan Free. Elige un plan en la app.',
    };
  }
  return {
    days,
    title: `Your Pro courtesy ends in ${days === 1 ? '1 day' : `${days} days`}`,
    body: orders > 0
      ? `You opened ${orders === 1 ? '1 work order' : `${orders} work orders`} this month. Free includes ${free} a month. Choose a plan in the app.`
      : 'After that the app goes back to Free. Choose a plan in the app.',
  };
}

const CONCURRENCY = 5;

export interface CourtesyNoticeDeps {
  notify: (companyId: string, message: CourtesyMessage) => Promise<void>;
}

const defaultDeps: CourtesyNoticeDeps = {
  notify: notifyCourtesyEnding,
};

/** A failure on one company is logged and retried on the next run. */
export async function sendCourtesyNotices(
  now: Date,
  deps: CourtesyNoticeDeps = defaultDeps,
): Promise<{ sent: number; errors: number }> {
  const snapshot = await getRootCollection('companies').where('subscription.source', '==', 'grace').get();
  const due = snapshot.docs.flatMap((doc) => {
    const subscription = doc.get('subscription') as Subscription | undefined;
    return dueCourtesyNotice(subscription, now) === null ? [] : [{ doc, subscription }];
  });

  // Free only has an order limit with the switch on: off, no number is said.
  const limitsOn = due.length > 0 && (await isPaidPlansEnabled());
  let sent = 0;
  let errors = 0;
  let next = 0;
  const worker = async (): Promise<void> => {
    while (next < due.length) {
      const { doc, subscription } = due[next++];
      try {
        const record = doc.ref.collection('settings').doc('courtesyNotice');
        const last = (await record.get()).data() as CourtesyNoticeRecord | undefined;
        const notice = dueCourtesyNotice(subscription, now, last);
        if (notice === null) continue;
        const orders = limitsOn ? ordersUsage(subscription?.usage, now).thisMonth : 0;
        await deps.notify(doc.id, courtesyMessage(notice.daysLeft, orders, doc.get('country') as string | undefined));
        await record.set({ expiresAt: subscription!.expiresAt as string, days: notice.step });
        sent++;
      } catch (error) {
        errors++;
        console.error('[Subscription] Courtesy notice failed', {
          companyId: doc.id,
          error: error instanceof Error ? error.message : 'unknown',
        });
      }
    }
  };
  await Promise.all(Array.from({ length: Math.min(CONCURRENCY, due.length) }, worker));

  console.log(`[Subscription] Courtesy notices: checked=${due.length} sent=${sent} errors=${errors}`);
  return { sent, errors };
}
