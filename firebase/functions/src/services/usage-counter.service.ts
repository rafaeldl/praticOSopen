/**
 * Plan usage counters kept by the server (`subscription.usage` on the company
 * document), so the limits don't depend on what the app writes.
 *
 * - formTemplatesActive: active checklist templates in `forms` (`isActive
 *   != false`: a template without the field is active, as in FormDefinition).
 *   Recounted on writes to `companies/{cid}/forms/{id}`, only while
 *   `config/usageCounters.serverOnly` is on (the app writes it otherwise).
 * - usersActive: memberships plus pending, not expired invites, the same sum
 *   the app writes (CollaboratorStore). Recounted on every write to a
 *   membership or an invite token.
 * - photosThisMonth: incremented by the order triggers when photos are added
 *   to an order, only while `config/usageCounters.serverOnly` is on. With the
 *   flag off the app still increments it (admin only), and counting here too
 *   would count those photos twice.
 *
 * The flag also makes firestore.rules refuse client writes to `usage`
 * (usageUpdateAllowed). With it off only usersActive is recounted, and it
 * gives the same number the app writes.
 */
import { db, runTransaction } from './firestore.service';

export const USAGE_FLAG_PATH = 'config/usageCounters';

const companyRef = (companyId: string) => db.collection('companies').doc(companyId);

/** Whether the server alone keeps the counters (flag on). */
export async function usageCountersServerOnly(): Promise<boolean> {
  const snap = await db.doc(USAGE_FLAG_PATH).get();
  return snap.exists && snap.data()?.serverOnly === true;
}

/** Writes one counter when the company exists and the value changed. */
async function setCounter(companyId: string, field: 'formTemplatesActive' | 'usersActive', value: number) {
  const ref = companyRef(companyId);
  const snap = await ref.get();
  if (!snap.exists) return;
  if (snap.data()?.subscription?.usage?.[field] === value) return;
  await ref.update({ [`subscription.usage.${field}`]: value });
}

/**
 * Recounts formTemplatesActive, only while the flag is on: the app still
 * writes it with the flag off, and two writers would alternate values.
 * Returns null when skipped.
 */
export async function recountFormTemplates(companyId: string): Promise<number | null> {
  if (!(await usageCountersServerOnly())) return null;
  const forms = await companyRef(companyId).collection('forms').get();
  const active = forms.docs.filter((doc) => doc.data()?.isActive !== false).length;
  await setCounter(companyId, 'formTemplatesActive', active);
  return active;
}

function expiryOf(value: unknown): number | null {
  if (!value) return null;
  if (typeof value === 'string') {
    const time = Date.parse(value);
    return Number.isNaN(time) ? null : time;
  }
  if (typeof (value as { toDate?: unknown }).toDate === 'function') {
    return (value as { toDate: () => Date }).toDate().getTime();
  }
  return null;
}

export async function recountUsers(companyId: string, now: Date = new Date()): Promise<number> {
  const members = await companyRef(companyId).collection('memberships').get();
  const invites = await db
    .collection('links/invites/tokens')
    .where('company.id', '==', companyId)
    .where('status', '==', 'pending')
    .get();
  const pending = invites.docs.filter((doc) => {
    const expiry = expiryOf(doc.data()?.expiresAt);
    return expiry === null || expiry > now.getTime();
  }).length;
  const total = members.docs.length + pending;
  await setCounter(companyId, 'usersActive', total);
  return total;
}

function photoIds(order: Record<string, unknown> | undefined): string[] {
  const photos = order?.photos;
  if (!Array.isArray(photos)) return [];
  return photos
    .map((p) => (p && typeof p === 'object' ? (p as { id?: unknown; storagePath?: unknown; url?: unknown }) : null))
    .map((p) => String(p?.id ?? p?.storagePath ?? p?.url ?? ''))
    .filter((id) => id.length > 0);
}

/** Photos in `after` that were not in `before` (order created or updated). */
export function newPhotoCount(before: Record<string, unknown> | undefined, after: Record<string, unknown> | undefined): number {
  const seen = new Set(photoIds(before));
  return photoIds(after).filter((id) => !seen.has(id)).length;
}

/** Adds the order's new photos to photosThisMonth (flag on only). */
export async function countNewOrderPhotos(
  companyId: string,
  before: Record<string, unknown> | undefined,
  after: Record<string, unknown> | undefined,
): Promise<number> {
  const added = newPhotoCount(before, after);
  if (added === 0) return 0;
  if (!(await usageCountersServerOnly())) return 0;
  const ref = companyRef(companyId);
  await runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return;
    const current = Number(snap.data()?.subscription?.usage?.photosThisMonth) || 0;
    tx.update(ref, { 'subscription.usage.photosThisMonth': current + added });
  });
  return added;
}
