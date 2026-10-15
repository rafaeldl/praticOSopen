/**
 * Production wiring of [OrderAssistDeps]: Firestore lookups scoped to the
 * company, the quota service and the LLM router (Gemini or Claude per company).
 */

import { getTenantCollection } from '../firestore.service';
import { findCustomerByPhone, searchCustomers } from '../customer.service';
import { findDeviceBySerial, searchDevices } from '../device.service';
import { getAiSettings, getAiUsage, releaseAiRequest, reserveAiRequest } from './ai-quota.service';
import { ClaudeClient } from './claude.client';
import { VertexGeminiClient } from './gemini.client';
import { LlmRouter } from './llm.client';
import { plateLookups } from './fuzzy-match';
import type { CatalogEntry, CustomerHit, DeviceHit, OrderAssistDeps } from './order-assist.service';

const CATALOG_LIMIT = 300;
/**
 * Customers/vehicles compared in memory for "Juliene" → Juliana. Almost every
 * company fits; above this, exact phone/plate/word lookups still find them.
 */
const PEOPLE_LIMIT = 2000;

function text(value: unknown): string | undefined {
  return typeof value === 'string' && value.trim() ? value : undefined;
}

/** Unique by id, keeping the first. */
function uniq<T extends { id: string }>(lists: (T | null | undefined)[][]): T[] {
  const seen = new Map<string, T>();
  for (const list of lists) for (const e of list) if (e && !seen.has(e.id)) seen.set(e.id, e);
  return [...seen.values()];
}

async function loadCustomers(companyId: string): Promise<CustomerHit[]> {
  const snap = await getTenantCollection(companyId, 'customers').select('name', 'phone').limit(PEOPLE_LIMIT).get();
  return snap.docs.flatMap((doc) => {
    const name = text(doc.get('name'));
    return name ? [{ id: doc.id, name, phone: text(doc.get('phone')) }] : [];
  });
}

async function loadDevices(companyId: string): Promise<DeviceHit[]> {
  const snap = await getTenantCollection(companyId, 'devices')
    .select('name', 'serial', 'manufacturer')
    .limit(PEOPLE_LIMIT)
    .get();
  return snap.docs.flatMap((doc) => {
    const name = text(doc.get('name'));
    return name
      ? [{ id: doc.id, name, serial: text(doc.get('serial')), manufacturer: text(doc.get('manufacturer')) }]
      : [];
  });
}

async function loadEntries(companyId: string, collection: 'services' | 'products'): Promise<CatalogEntry[]> {
  const snap = await getTenantCollection(companyId, collection).orderBy('name').limit(CATALOG_LIMIT).get();
  return snap.docs.flatMap((doc) => {
    const data = doc.data() as { name?: unknown; value?: unknown };
    if (typeof data.name !== 'string' || !data.name.trim()) return [];
    return [{ id: doc.id, name: data.name, value: typeof data.value === 'number' ? data.value : null }];
  });
}

let llm: LlmRouter | undefined;
let gemini: VertexGeminiClient | undefined;
let claude: ClaudeClient | undefined;

export function defaultOrderAssistDeps(): OrderAssistDeps {
  llm ??= new LlmRouter({
    gemini: () => (gemini ??= new VertexGeminiClient()),
    claude: () => (claude ??= new ClaudeClient()),
  });
  return {
    llm,
    getSettings: getAiSettings,
    getUsage: getAiUsage,
    reserve: (companyId, settings) => reserveAiRequest(companyId, settings),
    release: releaseAiRequest,
    loadCatalog: async (companyId) => {
      const [services, products] = await Promise.all([
        loadEntries(companyId, 'services'),
        loadEntries(companyId, 'products'),
      ]);
      return { services, products };
    },
    findCustomers: async (companyId, guess) => {
      const [all, byPhone, byName] = await Promise.all([
        loadCustomers(companyId),
        guess.phone ? findCustomerByPhone(companyId, guess.phone) : null,
        guess.name ? searchCustomers(companyId, guess.name, 5) : [],
      ]);
      const hit = (c: { id: string; name: string; phone?: string | null }): CustomerHit => ({
        id: c.id,
        name: c.name,
        phone: c.phone ?? undefined,
      });
      return uniq([all, byPhone ? [hit(byPhone)] : [], byName.map(hit)]);
    },
    findDevices: async (companyId, guess) => {
      const hit = (d: { id: string; name: string; serial?: string | null; manufacturer?: string }): DeviceHit => ({
        id: d.id,
        name: d.name,
        serial: d.serial ?? undefined,
        manufacturer: d.manufacturer,
      });
      const [all, byPlate, byName] = await Promise.all([
        loadDevices(companyId),
        guess.serial ? Promise.all(plateLookups(guess.serial).map((v) => findDeviceBySerial(companyId, v))) : [],
        guess.name ? searchDevices(companyId, guess.name, 5) : [],
      ]);
      return uniq([all, byPlate.flatMap((d) => (d ? [hit(d)] : [])), byName.map(hit)]);
    },
  };
}
