/**
 * Services and products for the web app (/v1/app/services, /v1/app/products).
 *
 * Without `viewPrices` the price never leaves the server: the field is left
 * out of the row, not sent as null (the app reads the whole document and hides
 * it on screen; the web reads only this projection). Writing a price needs
 * `editPrices`, checked in the route.
 *
 * Fixes of the app that live here (fatia 05): editing never rewrites
 * createdAt/createdBy (C10), the company is the session's, deleting also
 * removes the photo (C8), and a stale version is refused instead of saved over.
 */
import { db, getTenantCollection, storage } from './firestore.service';
import type { CompanyAggr, Order, UserAggr } from '../models/types';
import { generateSearchKeywords } from '../utils/search.utils';
import { orderVersion, versionMatches } from './order-version';
import { OrderRuleError } from './order-errors';
import { deletePhotoFileIn, recordPhotoFolder, validPhotoIn, type PhotoInput } from './record-photo';

export type { PhotoInput };
import { scopedOrders, newestFirst, type OrderScope } from './app-directory.service';

type Json = Record<string, unknown>;
export type CatalogKind = 'service' | 'product';
export const CATALOG_COLLECTION: Record<CatalogKind, 'services' | 'products'> = { service: 'services', product: 'products' };
/** Upper bound of one list read. The biggest catalog has a few hundred items. */
export const CATALOG_LIMIT = 5000;
/** Orders looked at for "Mais usados" (same window as the app). */
const RECENT_ORDERS = 50;
const MOST_USED = 5;

export interface CatalogRow {
  id: string;
  name: string;
  /** Only with viewPrices. */
  value?: number | null;
  photo: string | null;
  customData: Json | null;
  version: string | null;
}

const text = (value: unknown): string => (typeof value === 'string' ? value : '');
const money = (value: unknown): number | null => (typeof value === 'number' && Number.isFinite(value) ? value : null);
/** Prices are kept in the currency unit, rounded to the cent (never read as cents). */
/** Cents of a value, without the binary drift of `x * 100` (1.005 * 100 is 100.4999…). */
const toCents = (value: number): number => Math.round(Number((value * 100).toFixed(6)));
export const roundCents = (value: number): number => toCents(value) / 100;
const cents = (value: number | null): number | null => (value === null ? null : toCents(value));

function toRow(id: string, data: Json, showPrices: boolean): CatalogRow {
  return {
    id,
    name: text(data.name),
    ...(showPrices ? { value: money(data.value) } : {}),
    photo: typeof data.photo === 'string' && data.photo ? data.photo : null,
    customData: data.customData && typeof data.customData === 'object' ? (data.customData as Json) : null,
    version: orderVersion(data.updatedAt),
  };
}

const collectionOf = (companyId: string, kind: CatalogKind) => getTenantCollection(companyId, CATALOG_COLLECTION[kind]);

export async function catalogList(companyId: string, kind: CatalogKind, showPrices: boolean): Promise<{ items: CatalogRow[]; truncated: boolean }> {
  const snapshot = await collectionOf(companyId, kind).limit(CATALOG_LIMIT + 1).get();
  const items = snapshot.docs.slice(0, CATALOG_LIMIT).map((doc) => toRow(doc.id, doc.data() as Json, showPrices));
  return { items, truncated: snapshot.docs.length > CATALOG_LIMIT };
}

export async function catalogItem(companyId: string, kind: CatalogKind, id: string, showPrices: boolean): Promise<CatalogRow | null> {
  const snapshot = await collectionOf(companyId, kind).doc(id).get();
  return snapshot.exists ? toRow(snapshot.id, snapshot.data() as Json, showPrices) : null;
}

/**
 * Ids of this kind most used in the last 50 orders the person reads (consultant:
 * the ones they created), counted per line. Unlike the app, the kinds never
 * mix before the top is taken (catalog.list.most-used). Ties: most recent use,
 * as in the app. Only ids still in the catalog (`known`).
 */
export async function mostUsed(companyId: string, kind: CatalogKind, scope: OrderScope, known: Set<string>): Promise<string[]> {
  const orders = (await scopedOrders(companyId, scope, (base) => [base.orderBy('createdAt', 'desc').limit(RECENT_ORDERS)]))
    .sort(newestFirst)
    .slice(0, RECENT_ORDERS);
  // Map keeps the first time each id was seen: newest order first, so a tie goes to the most recent use (mostUsedItemKeys).
  const counts = new Map<string, number>();
  for (const order of orders as (Order & Json)[]) {
    const lines = (kind === 'service' ? order.services : order.products) as Json[] | undefined;
    for (const line of lines ?? []) {
      const id = ((line?.[kind] as Json | undefined)?.id ?? null) as string | null;
      if (id && known.has(id)) counts.set(id, (counts.get(id) ?? 0) + 1);
    }
  }
  return [...counts.entries()]
    .sort((a, b) => b[1] - a[1]) // stable: equal counts keep the order of first use
    .slice(0, MOST_USED)
    .map(([id]) => id);
}

export interface CatalogInput {
  name?: string;
  value?: number | null;
  customData?: Json | null;
  photo?: PhotoInput | null;
}

/** Folder the Storage rules give to one item (the app writes photo.jpg there). */
export const photoFolder = (companyId: string, kind: CatalogKind, id: string) => recordPhotoFolder(companyId, CATALOG_COLLECTION[kind], id);

/** The photo must be a file in the item's own folder, and its URL that same file. */
export function validPhoto(companyId: string, kind: CatalogKind, id: string, photo: PhotoInput): boolean {
  return validPhotoIn(photoFolder(companyId, kind, id), photo);
}

/**
 * Deletes only the file the document pointed to, inside the item's folder. A
 * photo the app uploaded meanwhile (same folder) is never taken along (review M2).
 */
const deletePhotoFile = (companyId: string, kind: CatalogKind, id: string, storedUrl: unknown) =>
  deletePhotoFileIn(photoFolder(companyId, kind, id), storedUrl, 'catalog');

async function deletePhotos(companyId: string, kind: CatalogKind, id: string): Promise<void> {
  try {
    await storage.bucket().deleteFiles({ prefix: photoFolder(companyId, kind, id) });
  } catch (error) {
    // The item is gone either way; a leftover file is only logged.
    console.warn('catalog: photo not deleted', (error as Error)?.name);
  }
}

function fields(input: CatalogInput): Json {
  const out: Json = {};
  if (input.name !== undefined) {
    out.name = input.name;
    out.nameLower = input.name.toLowerCase();
    out.keywords = generateSearchKeywords(input.name);
  }
  if (input.value !== undefined) out.value = input.value === null ? null : roundCents(input.value);
  if (input.customData !== undefined) out.customData = input.customData && Object.keys(input.customData).length ? input.customData : null;
  if (input.photo !== undefined) out.photo = input.photo ? input.photo.url : null;
  return out;
}

export async function createItem(
  companyId: string,
  kind: CatalogKind,
  input: CatalogInput & { name: string },
  createdBy: UserAggr,
  company: CompanyAggr,
  id?: string,
): Promise<{ id: string; created: boolean; version: string }> {
  const collection = collectionOf(companyId, kind);
  const ref = id ? collection.doc(id) : collection.doc();
  const now = new Date().toISOString();
  // The photo is set afterwards, once the item has an id (its Storage folder).
  try {
    await ref.create({ value: null, customData: null, ...fields({ ...input, photo: undefined }), photo: null, company, createdBy, createdAt: now, updatedBy: createdBy, updatedAt: now });
    return { id: ref.id, created: true, version: now };
  } catch (error) {
    // Same id again (an import repeated after a network failure): already there.
    if (id && (error as { code?: number }).code === 6) return { id: ref.id, created: false, version: now };
    throw error;
  }
}

/**
 * `version`: what the person saw. Another save since then (web or app) refuses
 * with 409 CATALOG_ITEM_CHANGED and writes nothing. Returns the new version, or
 * false when the item does not exist.
 */
export async function updateItem(
  companyId: string,
  kind: CatalogKind,
  id: string,
  input: CatalogInput,
  updatedBy: UserAggr,
  version?: string,
  /** Removing the photo: the URL the person saw. The app changes the photo without touching updatedAt. */
  photoSeen?: string,
): Promise<string | false> {
  const ref = collectionOf(companyId, kind).doc(id);
  let removed: unknown = null;
  const result = await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    if (!snapshot.exists) return false as const;
    const current = snapshot.data() ?? {};
    if (version !== undefined && !versionMatches(current.updatedAt, version)) {
      throw new OrderRuleError('CATALOG_ITEM_CHANGED', 409, 'The item changed since it was read');
    }
    if (input.photo === null && (current.photo ?? null) !== (photoSeen ?? null)) {
      throw new OrderRuleError('CATALOG_ITEM_CHANGED', 409, 'The photo changed since it was read');
    }
    removed = input.photo === null ? current.photo : null;
    const updatedAt = new Date().toISOString();
    tx.update(ref, { ...fields(input), updatedBy, updatedAt });
    return updatedAt;
  });
  if (result && removed) await deletePhotoFile(companyId, kind, id, removed);
  return result;
}

/**
 * Lines of an import already saved under this importId with other content (an
 * id reused for a different file): their positions. Same content is a repeat.
 */
export async function importConflicts(companyId: string, kind: CatalogKind, importId: string, items: { name: string; value?: number | null }[]): Promise<number[]> {
  const collection = collectionOf(companyId, kind);
  const snapshots = await db.getAll(...items.map((_, index) => collection.doc(`${importId}-${index}`)));
  const out: number[] = [];
  snapshots.forEach((snapshot, index) => {
    if (!snapshot.exists) return;
    const data = snapshot.data() ?? {};
    const item = items[index] as { name: string; value?: number | null };
    const sameValue = item.value === undefined || cents(money(data.value)) === cents(item.value === null ? null : roundCents(item.value));
    if (data.name !== item.name || !sameValue) out.push(index);
  });
  return out;
}

/** Deletes the item and its photo. Orders keep their embedded copy, as in the app. */
export async function deleteItem(companyId: string, kind: CatalogKind, id: string): Promise<boolean> {
  const ref = collectionOf(companyId, kind).doc(id);
  const snapshot = await ref.get();
  if (!snapshot.exists) return false;
  await ref.delete();
  await deletePhotos(companyId, kind, id);
  return true;
}

export interface PriceChange {
  id: string;
  /** The price the person saw (null: without price). */
  from: number | null;
  to: number;
}

/**
 * Price of many items in one transaction (desk extra). Each change says the
 * price the person saw: an item already at `to` is left alone (the same request
 * repeated after the answer was lost), one at `from` changes, and any other
 * value means someone changed it since: 409 with those ids and nothing written.
 * Compared in cents.
 */
export async function applyPrices(
  companyId: string,
  kind: CatalogKind,
  changes: PriceChange[],
  updatedBy: UserAggr,
  batchId?: string,
): Promise<{ updated: number; unchanged: number }> {
  const collection = collectionOf(companyId, kind);
  return db.runTransaction(async (tx) => {
    // One read for the whole batch (up to 500): shorter transaction, fewer retries.
    const snapshots = await tx.getAll(...changes.map((change) => collection.doc(change.id)));
    const conflicts: string[] = [];
    const writes: { ref: FirebaseFirestore.DocumentReference; value: number }[] = [];
    let unchanged = 0;
    changes.forEach((change, index) => {
      const snapshot = snapshots[index];
      if (!snapshot?.exists) return void conflicts.push(change.id);
      const current = cents(money(snapshot.data()?.value));
      const to = roundCents(change.to);
      if (current === cents(to)) unchanged++;
      else if (current === cents(change.from === null ? null : roundCents(change.from))) writes.push({ ref: snapshot.ref, value: to });
      else conflicts.push(change.id);
    });
    if (conflicts.length) {
      throw new OrderRuleError('CATALOG_ITEM_CHANGED', 409, 'Some prices changed since they were read', { ids: conflicts });
    }
    const updatedAt = new Date().toISOString();
    for (const write of writes) tx.update(write.ref, { value: write.value, updatedBy, updatedAt, ...(batchId ? { priceBatchId: batchId } : {}) });
    return { updated: writes.length, unchanged };
  });
}
