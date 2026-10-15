/**
 * Production wiring of [OrderAssistDeps]: Firestore lookups scoped to the
 * company, the quota service and the LLM router (Gemini or Claude per company).
 */

import { getTenantCollection } from '../firestore.service';
import { searchCustomers } from '../customer.service';
import { findDeviceBySerial, searchDevices } from '../device.service';
import { getAiSettings, getAiUsage, releaseAiRequest, reserveAiRequest } from './ai-quota.service';
import { ClaudeClient } from './claude.client';
import { VertexGeminiClient } from './gemini.client';
import { LlmRouter } from './llm.client';
import type { CatalogEntry, OrderAssistDeps } from './order-assist.service';

const CATALOG_LIMIT = 300;

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
    findCustomers: async (companyId, name) =>
      (await searchCustomers(companyId, name, 5)).map((c) => ({ id: c.id, name: c.name, phone: c.phone ?? undefined })),
    findDeviceBySerial: async (companyId, serial) => {
      const d = await findDeviceBySerial(companyId, serial);
      return d ? { id: d.id, name: d.name, serial: d.serial ?? undefined, manufacturer: d.manufacturer } : null;
    },
    findDevices: async (companyId, name) =>
      (await searchDevices(companyId, name, 5)).map((d) => ({
        id: d.id,
        name: d.name,
        serial: d.serial ?? undefined,
        manufacturer: d.manufacturer,
      })),
  };
}
