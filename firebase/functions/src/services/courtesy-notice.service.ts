/**
 * End of the launch courtesy (docs/SUBSCRIPTION.md): a daily job tells owners
 * and admins 15 and 3 days before `expiresAt`, with what the company used.
 * The push does not open anything: the banner on Início carries the paywall.
 *
 * companies/{cid}/settings/courtesyNotice { expiresAt, days } records the last
 * push. It stays out of `subscription`: the Firestore rules reject a client
 * save that drops a field from that map, and app versions up to 1.55 rewrite it.
 */

import { getRootCollection } from './firestore.service';
import { AI_REQUESTS_PER_MONTH, getAiUsage } from './ai/ai-quota.service';
import { notifyCourtesyEnding } from './notification.service';
import { CourtesyNoticeRecord, dueCourtesyNotice } from './subscription-plans';
import type { Subscription } from '../models/types';

export interface CourtesyMessage {
  title: string;
  body: string;
  days: number;
}

/** Text of the push, in the company's language (Brazil and default: pt). */
export function courtesyMessage(days: number, aiUsed: number, country: string | undefined): CourtesyMessage {
  const free = AI_REQUESTS_PER_MONTH.free;
  if (country === 'US') {
    return {
      days,
      title: `Your Pro courtesy ends in ${days} days`,
      body: aiUsed > 0
        ? `You used the assistant ${aiUsed} times this month. Free includes ${free}. Choose a plan in the app.`
        : 'After that the app goes back to Free. Choose a plan in the app.',
    };
  }
  if (country && country !== 'BR') {
    return {
      days,
      title: `Tu cortesía Pro termina en ${days} días`,
      body: aiUsed > 0
        ? `Usaste el asistente ${aiUsed} veces este mes. El plan Free incluye ${free}. Elige un plan en la app.`
        : 'Después, la app vuelve al plan Free. Elige un plan en la app.',
    };
  }
  return {
    days,
    title: `Sua cortesia do Pro acaba em ${days} dias`,
    body: aiUsed > 0
      ? `Você usou o assistente ${aiUsed} vezes neste mês. No Free são ${free}. Escolha seu plano no app.`
      : 'Depois disso, o app volta para o plano Free. Escolha seu plano no app.',
  };
}

const CONCURRENCY = 5;

export interface CourtesyNoticeDeps {
  aiUsed: (companyId: string) => Promise<number>;
  notify: (companyId: string, message: CourtesyMessage) => Promise<void>;
}

const defaultDeps: CourtesyNoticeDeps = {
  aiUsed: async (companyId) => (await getAiUsage(companyId, null)).used,
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

  let sent = 0;
  let errors = 0;
  let next = 0;
  const worker = async (): Promise<void> => {
    while (next < due.length) {
      const { doc, subscription } = due[next++];
      try {
        const record = doc.ref.collection('settings').doc('courtesyNotice');
        const last = (await record.get()).data() as CourtesyNoticeRecord | undefined;
        const days = dueCourtesyNotice(subscription, now, last);
        if (days === null) continue;
        const aiUsed = await deps.aiUsed(doc.id);
        await deps.notify(doc.id, courtesyMessage(days, aiUsed, doc.get('country') as string | undefined));
        await record.set({ expiresAt: subscription!.expiresAt as string, days });
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
