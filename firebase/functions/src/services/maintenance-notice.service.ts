/**
 * Next maintenance of a device (docs/DEVICE_NEXT_MAINTENANCE.md): a daily job
 * tells the company about the maintenances of the coming 7 days, on the phone
 * and on the bell, without depending on anyone opening the app. It only warns:
 * it creates no order.
 *
 * `nextMaintenanceDate` is a day (`YYYY-MM-DD`), compared as text.
 * `nextMaintenanceNoticeFor` records the day already told, so each date is
 * told once, a run that failed tries again the next day, and a new date is
 * told again. A device under an active contract is left out: the contract
 * already handles it.
 */

import { db } from './firestore.service';
import { companyLanguage } from './courtesy-notice.service';
import { notifyMaintenanceDue } from './notification.service';
import type { UserAggr } from '../models/types';

export const MAINTENANCE_LEAD_DAYS = 7;

const TIME_ZONE = 'America/Sao_Paulo';
const CONCURRENCY = 5;

export interface MaintenanceDue {
  deviceId: string;
  device: string;
  customer?: string;
  day: string;
}

export interface MaintenanceMessage {
  title: string;
  body: string;
  count: number;
}

/** Calendar day of [now] in Brazil, `YYYY-MM-DD`. */
export function maintenanceToday(now: Date): string {
  return new Intl.DateTimeFormat('sv-SE', { timeZone: TIME_ZONE }).format(now);
}

function addDays(day: string, days: number): string {
  const date = new Date(`${day}T12:00:00.000Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

function formatDay(day: string, locale: string): string {
  return new Intl.DateTimeFormat(locale, {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    timeZone: 'UTC',
  }).format(new Date(`${day}T12:00:00.000Z`));
}

/** Text of the push, in the company's language. [due] comes soonest first. */
export function maintenanceMessage(due: MaintenanceDue[], country: string | undefined): MaintenanceMessage {
  const language = companyLanguage(country);
  const locale = { pt: 'pt-BR', es: 'es-ES', en: 'en-US' }[language];
  const first = due[0];
  const line = [first.device, first.customer, formatDay(first.day, locale)]
    .filter((part) => part?.trim())
    .join(' · ');
  const more = due.length - 1;
  const texts = {
    pt: {
      one: 'Manutenção chegando',
      many: `${due.length} manutenções chegando`,
      more: `${line} e mais ${more}`,
    },
    es: {
      one: 'Mantenimiento próximo',
      many: `${due.length} mantenimientos próximos`,
      more: `${line} y ${more} más`,
    },
    en: {
      one: 'Maintenance coming up',
      many: `${due.length} maintenance visits coming up`,
      more: `${line} and ${more} more`,
    },
  }[language];
  return {
    title: more === 0 ? texts.one : texts.many,
    body: more === 0 ? line : texts.more,
    count: due.length,
  };
}

async function hasActiveContract(companyId: string, deviceId: string): Promise<boolean> {
  const contracts = await db
    .collection('companies')
    .doc(companyId)
    .collection('orders')
    .where('isContract', '==', true)
    .where('deviceIds', 'array-contains', deviceId)
    .get();
  return contracts.docs.some((doc) => doc.get('contract.active') === true);
}

/** Who was on the device's most recent order, if anyone. */
async function lastTechnician(companyId: string, deviceId: string): Promise<UserAggr | null> {
  const orders = await db
    .collection('companies')
    .doc(companyId)
    .collection('orders')
    .where('deviceIds', 'array-contains', deviceId)
    .get();
  const created = (value: unknown): string => (typeof value === 'string' ? value : '');
  const last = orders.docs
    .map((doc) => doc.data())
    .filter((order) => order.isContract !== true)
    .sort((a, b) => created(b.createdAt).localeCompare(created(a.createdAt)))[0];
  return (last?.assignedTo as UserAggr | undefined) ?? null;
}

export interface MaintenanceNoticeDeps {
  notify: (companyId: string, message: MaintenanceMessage, technicians: UserAggr[]) => Promise<void>;
}

const defaultDeps: MaintenanceNoticeDeps = { notify: notifyMaintenanceDue };

/** One push per company. A failure on one is logged and retried the next day. */
export async function sendMaintenanceNotices(
  now: Date,
  deps: MaintenanceNoticeDeps = defaultDeps,
): Promise<{ sent: number; errors: number }> {
  const today = maintenanceToday(now);
  const until = addDays(today, MAINTENANCE_LEAD_DAYS);
  const snapshot = await db
    .collectionGroup('devices')
    .where('nextMaintenanceDate', '>=', today)
    .where('nextMaintenanceDate', '<=', until)
    .get();

  const byCompany = new Map<string, MaintenanceDue[]>();
  for (const doc of snapshot.docs) {
    const [root, companyId, , deviceId, ...rest] = doc.ref.path.split('/');
    // Legacy /devices documents have no company in the path.
    if (root !== 'companies' || !deviceId || rest.length > 0) continue;
    const day = doc.get('nextMaintenanceDate') as string;
    if (doc.get('nextMaintenanceNoticeFor') === day) continue;
    const due: MaintenanceDue = {
      deviceId,
      device: (doc.get('name') as string | undefined) ?? '',
      customer: doc.get('nextMaintenanceCustomer.name') as string | undefined,
      day,
    };
    byCompany.set(companyId, [...(byCompany.get(companyId) ?? []), due]);
  }

  const companies = [...byCompany.entries()];
  let sent = 0;
  let errors = 0;
  let next = 0;
  const worker = async (): Promise<void> => {
    while (next < companies.length) {
      const [companyId, candidates] = companies[next++];
      try {
        const company = await db.collection('companies').doc(companyId).get();
        if (!company.exists) continue;
        const contracts = await Promise.all(candidates.map((d) => hasActiveContract(companyId, d.deviceId)));
        const due = candidates
          .filter((_, index) => !contracts[index])
          .sort((a, b) => a.day.localeCompare(b.day));
        if (due.length === 0) continue;

        const assigned = await Promise.all(due.map((d) => lastTechnician(companyId, d.deviceId)));
        const technicians = assigned.filter((user): user is UserAggr => user !== null);
        await deps.notify(companyId, maintenanceMessage(due, company.get('country') as string | undefined), technicians);

        const devices = db.collection('companies').doc(companyId).collection('devices');
        await Promise.all(due.map((d) => devices.doc(d.deviceId).update({ nextMaintenanceNoticeFor: d.day })));
        sent++;
      } catch (error) {
        errors++;
        console.error('[Maintenance] Notice failed', {
          companyId,
          error: error instanceof Error ? error.message : 'unknown',
        });
      }
    }
  };
  await Promise.all(Array.from({ length: Math.min(CONCURRENCY, companies.length) }, worker));

  console.log(`[Maintenance] Notices: companies=${companies.length} sent=${sent} errors=${errors}`);
  return { sent, errors };
}
