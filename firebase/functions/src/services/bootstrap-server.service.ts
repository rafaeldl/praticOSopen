/**
 * Bootstrap Server Service
 * Server-side implementation of bootstrap logic for creating initial company data
 *
 * Port of: lib/services/bootstrap_service.dart
 *
 * Creates:
 * - Services (from segment bootstrap data)
 * - Products (from segment bootstrap data)
 * - Devices (from segment bootstrap data)
 * - Sample customer
 * - Form templates (synced from segment)
 */

import {
  db,
} from './firestore.service';
import {
  UserAggr,
  CompanyAggr,
  OrderStatus,
} from '../models/types';
import { createOrder } from './order.service';
import { addFormToOrder, listFormTemplates } from './forms.service';
import { companyZone, dayIn, nextDay } from '../utils/company-zone';

// ============================================================================
// Types
// ============================================================================

export interface BootstrapParams {
  companyId: string;
  segmentId: string;
  subspecialties: string[];
  userAggr: UserAggr;
  companyAggr: CompanyAggr;
  locale?: string;
  /**
   * Copy the segment checklists too (default). The first access copies them
   * before, with or without samples, and passes false.
   */
  syncForms?: boolean;
  /** Clock of the sample orders (tests). */
  now?: Date;
}

export interface BootstrapResult {
  createdServices: string[];
  createdProducts: string[];
  createdDevices: string[];
  createdCustomers: string[];
  skippedServices: string[];
  skippedProducts: string[];
  skippedDevices: string[];
  skippedCustomers: string[];
  createdOrders: string[];
}

interface BootstrapData {
  services?: Array<{
    name: string | Record<string, string>;
    value?: number;
  }>;
  products?: Array<{
    name: string | Record<string, string>;
    value?: number;
  }>;
  devices?: Array<{
    name: string | Record<string, string>;
    manufacturer?: string | Record<string, string>;
    category?: string | Record<string, string>;
  }>;
  customer?: {
    name: string | Record<string, string>;
    phone?: string;
    email?: string;
    address?: string | Record<string, string>;
  };
}

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Extract localized string from a value that can be:
 * - String: returns directly
 * - Map with translations: { 'pt-BR': '...', 'en-US': '...' } -> extracts locale
 */
function getLocalizedString(
  value: string | Record<string, string> | undefined | null,
  locale: string
): string | null {
  if (!value) return null;

  if (typeof value === 'string') return value;

  if (typeof value === 'object') {
    // Try exact locale
    if (value[locale]) return value[locale];

    // Try language only (pt from pt-BR)
    const langCode = locale.split('-')[0];
    const fallbackKey = Object.keys(value).find((key) =>
      key.startsWith(langCode)
    );
    if (fallbackKey && value[fallbackKey]) return value[fallbackKey];

    // Fallback to pt-BR
    if (value['pt-BR']) return value['pt-BR'];

    // Last resort: first available
    const firstKey = Object.keys(value)[0];
    if (firstKey) return value[firstKey];
  }

  return null;
}

/**
 * Get locale code from country or full locale
 * BR, PT, pt-BR, pt-PT -> pt
 * US, en-US -> en
 * ES, es-ES -> es
 */
function getLocaleFromCountry(countryOrLocale?: string): string {
  if (!countryOrLocale) return 'pt';
  const input = countryOrLocale.toUpperCase();

  // Check if it's a locale format (pt-BR, en-US, es-ES)
  if (input.includes('-')) {
    const parts = input.split('-');
    const languageCode = parts[0].toLowerCase();
    if (languageCode === 'pt') return 'pt';
    if (languageCode === 'en') return 'en';
    if (languageCode === 'es') return 'es';
    return 'pt';
  }

  // Otherwise, treat as country code
  if (input === 'BR' || input === 'PT') return 'pt';
  if (input === 'US') return 'en';
  if (input === 'ES') return 'es';
  return 'pt'; // default fallback
}

// ============================================================================
// Bootstrap Data Fetching
// ============================================================================

/**
 * Fetch bootstrap data for a specific segment/subspecialty
 */
async function getBootstrapData(
  segmentId: string,
  subspecialtyId: string
): Promise<BootstrapData | null> {
  try {
    const doc = await db
      .collection('segments')
      .doc(segmentId)
      .collection('bootstrap')
      .doc(subspecialtyId)
      .get();

    if (!doc.exists) return null;
    return doc.data() as BootstrapData;
  } catch {
    return null;
  }
}

/**
 * Merge bootstrap data from multiple subspecialties
 */
async function mergeBootstrapData(
  segmentId: string,
  subspecialties: string[]
): Promise<BootstrapData> {
  const servicesSet: NonNullable<BootstrapData['services']> = [];
  const productsSet: NonNullable<BootstrapData['products']> = [];
  const devicesSet: NonNullable<BootstrapData['devices']> = [];
  let customer: BootstrapData['customer'] | undefined;

  const seenServiceNames = new Set<string>();
  const seenProductNames = new Set<string>();

  // If no subspecialties, use _default
  const keys = subspecialties.length === 0 ? ['_default'] : subspecialties;

  for (const subspecialtyId of keys) {
    const data = await getBootstrapData(segmentId, subspecialtyId);
    if (!data) continue;

    // Merge services (avoid duplicates by name)
    const services = data.services || [];
    for (const service of services) {
      const name = getLocalizedString(service.name, 'pt-BR');
      if (name && !seenServiceNames.has(name)) {
        seenServiceNames.add(name);
        servicesSet.push(service);
      }
    }

    // Merge products (avoid duplicates by name)
    const products = data.products || [];
    for (const product of products) {
      const name = getLocalizedString(product.name, 'pt-BR');
      if (name && !seenProductNames.has(name)) {
        seenProductNames.add(name);
        productsSet.push(product);
      }
    }

    // Merge devices (include all)
    const devices = data.devices || [];
    for (const device of devices) {
      devicesSet.push(device);
    }

    // Customer: use first found
    if (!customer && data.customer) {
      customer = data.customer;
    }
  }

  return {
    services: servicesSet,
    products: productsSet,
    devices: devicesSet,
    customer,
  };
}

/**
 * Get existing names from a collection
 */
async function getExistingNames(
  companyId: string,
  collection: string
): Promise<Set<string>> {
  const snapshot = await db
    .collection('companies')
    .doc(companyId)
    .collection(collection)
    .get();

  const names = new Set<string>();
  snapshot.docs.forEach((doc) => {
    const name = doc.data().name;
    if (name) names.add(name);
  });

  return names;
}

// ============================================================================
// Form Sync
// ============================================================================

/**
 * Check if form should be included based on subspecialties
 */
function shouldIncludeForm(
  formSubspecialties: string[],
  selectedSubspecialties: string[]
): boolean {
  if (formSubspecialties.length === 0) {
    return true;
  }
  if (selectedSubspecialties.length === 0) {
    return false;
  }
  return formSubspecialties.some((subspecialty) =>
    selectedSubspecialties.includes(subspecialty)
  );
}

/**
 * Localize form data based on locale
 */
function localizeFormData(
  data: Record<string, unknown>,
  localeCode: string
): Record<string, unknown> {
  const localized = { ...data };

  // Localize title
  if (data.titleI18n && typeof data.titleI18n === 'object') {
    const titleI18n = data.titleI18n as Record<string, string>;
    localized.title = titleI18n[localeCode] ||
      titleI18n['pt'] ||
      data.title;
    delete localized.titleI18n;
  }

  // Localize description
  if (data.descriptionI18n && typeof data.descriptionI18n === 'object') {
    const descI18n = data.descriptionI18n as Record<string, string>;
    localized.description = descI18n[localeCode] ||
      descI18n['pt'] ||
      data.description;
    delete localized.descriptionI18n;
  }

  // Localize items
  if (Array.isArray(data.items)) {
    const items = data.items.map((item) => {
      const localizedItem = { ...item };

      // Localize item label
      if (item.labelI18n && typeof item.labelI18n === 'object') {
        const labelI18n = item.labelI18n as Record<string, string>;
        localizedItem.label = labelI18n[localeCode] ||
          labelI18n['pt'] ||
          item.label;
        delete localizedItem.labelI18n;
      }

      // Localize item options
      if (item.optionsI18n && typeof item.optionsI18n === 'object') {
        const optionsI18n = item.optionsI18n as Record<string, string[]>;
        localizedItem.options = optionsI18n[localeCode] ||
          optionsI18n['pt'] ||
          item.options;
        delete localizedItem.optionsI18n;
      }

      return localizedItem;
    });

    localized.items = items;
  }

  return localized;
}

/**
 * Sync form templates from segment to company
 */
export async function syncCompanyFormsFromSegment(params: {
  companyId: string;
  segmentId: string;
  subspecialties: string[];
  userAggr: UserAggr;
  locale?: string;
}): Promise<void> {
  const { companyId, segmentId, subspecialties, userAggr, locale } = params;

  const segmentSnapshot = await db
    .collection('segments')
    .doc(segmentId)
    .collection('forms')
    .get();

  if (segmentSnapshot.empty) return;

  const companyFormsRef = db
    .collection('companies')
    .doc(companyId)
    .collection('forms');

  const existingSnapshot = await companyFormsRef.get();
  const existingIds = new Set(existingSnapshot.docs.map((doc) => doc.id));

  // Get locale code from company country or locale
  const localeCode = getLocaleFromCountry(locale);

  for (const doc of segmentSnapshot.docs) {
    const data = doc.data();
    const isActive = data.isActive !== false;
    if (!isActive) continue;

    const formSubspecialties = Array.isArray(data.subspecialties)
      ? (data.subspecialties as string[])
      : [];

    if (!shouldIncludeForm(formSubspecialties, subspecialties)) {
      continue;
    }

    // Localize form data based on company locale and remove i18n fields
    const localizedData = localizeFormData(data, localeCode);

    const formData: Record<string, unknown> = {
      ...localizedData,
      updatedAt: new Date().toISOString(),
      updatedBy: userAggr,
    };

    if (!existingIds.has(doc.id)) {
      formData.createdAt = new Date().toISOString();
      formData.createdBy = userAggr;
    }

    await companyFormsRef.doc(doc.id).set(formData, { merge: true });
  }
}

// ============================================================================
// Main Bootstrap Function
// ============================================================================

/**
 * Execute bootstrap for a company
 */
export async function executeServerBootstrap(
  params: BootstrapParams
): Promise<BootstrapResult> {
  const {
    companyId,
    segmentId,
    subspecialties,
    userAggr,
    companyAggr,
    locale = 'pt-BR',
    syncForms = true,
    now: clock = new Date(),
  } = params;

  console.log(`[BOOTSTRAP] Starting for company ${companyId}, segment ${segmentId}`);

  const result: BootstrapResult = {
    createdServices: [],
    createdProducts: [],
    createdDevices: [],
    createdCustomers: [],
    skippedServices: [],
    skippedProducts: [],
    skippedDevices: [],
    skippedCustomers: [],
    createdOrders: [],
  };

  // 1. Merge bootstrap data from subspecialties
  const mergedData = await mergeBootstrapData(segmentId, subspecialties);

  // 2. Get existing items
  const existingServices = await getExistingNames(companyId, 'services');
  const existingProducts = await getExistingNames(companyId, 'products');
  const existingDevices = await getExistingNames(companyId, 'devices');
  const existingCustomers = await getExistingNames(companyId, 'customers');

  const now = new Date().toISOString();

  // 3. Create services
  const services = mergedData.services || [];
  for (const serviceData of services) {
    const name = getLocalizedString(serviceData.name, locale);
    if (!name) continue;

    if (existingServices.has(name)) {
      result.skippedServices.push(name);
      continue;
    }

    const serviceRef = db
      .collection('companies')
      .doc(companyId)
      .collection('services')
      .doc();

    await serviceRef.set({
      id: serviceRef.id,
      name,
      value: serviceData.value || null,
      company: companyAggr,
      createdAt: now,
      createdBy: userAggr,
      updatedAt: now,
      updatedBy: userAggr,
    });

    result.createdServices.push(name);
  }

  // 4. Create products
  const products = mergedData.products || [];
  for (const productData of products) {
    const name = getLocalizedString(productData.name, locale);
    if (!name) continue;

    if (existingProducts.has(name)) {
      result.skippedProducts.push(name);
      continue;
    }

    const productRef = db
      .collection('companies')
      .doc(companyId)
      .collection('products')
      .doc();

    await productRef.set({
      id: productRef.id,
      name,
      value: productData.value || null,
      company: companyAggr,
      createdAt: now,
      createdBy: userAggr,
      updatedAt: now,
      updatedBy: userAggr,
    });

    result.createdProducts.push(name);
  }

  // 5. Create devices
  const devices = mergedData.devices || [];
  for (const deviceData of devices) {
    const name = getLocalizedString(deviceData.name, locale);
    if (!name) continue;

    if (existingDevices.has(name)) {
      result.skippedDevices.push(name);
      continue;
    }

    const deviceRef = db
      .collection('companies')
      .doc(companyId)
      .collection('devices')
      .doc();

    await deviceRef.set({
      id: deviceRef.id,
      name,
      manufacturer: getLocalizedString(deviceData.manufacturer, locale) || null,
      category: getLocalizedString(deviceData.category, locale) || null,
      company: companyAggr,
      createdAt: now,
      createdBy: userAggr,
      updatedAt: now,
      updatedBy: userAggr,
    });

    result.createdDevices.push(name);
  }

  // 6. Create sample customer
  const customerData = mergedData.customer;
  if (customerData) {
    const customerName = getLocalizedString(customerData.name, locale);
    if (customerName) {
      // Check if example customer already exists
      const hasExampleCustomer = Array.from(existingCustomers).some(
        (name) =>
          name.includes('(Exemplo)') ||
          name.includes('(Example)') ||
          name.includes('(Ejemplo)')
      );

      if (hasExampleCustomer) {
        result.skippedCustomers.push(customerName);
      } else {
        const customerRef = db
          .collection('companies')
          .doc(companyId)
          .collection('customers')
          .doc();

        await customerRef.set({
          id: customerRef.id,
          name: customerName,
          phone: customerData.phone || null,
          email: customerData.email || null,
          address: getLocalizedString(customerData.address, locale) || null,
          company: companyAggr,
          createdAt: now,
          createdBy: userAggr,
          updatedAt: now,
          updatedBy: userAggr,
        });

        result.createdCustomers.push(customerName);
      }
    }
  }

  // 7. Sync form templates from segment (before the orders: the first one gets a checklist)
  if (syncForms) {
    try {
      await syncCompanyFormsFromSegment({
        companyId,
        segmentId,
        subspecialties,
        userAggr,
        locale,
      });
      console.log(`[BOOTSTRAP] Form templates synced`);
    } catch (error) {
      console.error('[BOOTSTRAP] Error syncing form templates:', error);
      // Non-fatal error
    }
  }

  // 8. Sample orders, as the app's BootstrapService (only when the company has none)
  try {
    result.createdOrders = await createSampleOrders({ companyId, userAggr, companyAggr, now: clock });
  } catch (error) {
    console.error('[BOOTSTRAP] Error creating sample orders:', error instanceof Error ? error.message : 'unknown');
    // Non-fatal error
  }

  console.log(`[BOOTSTRAP] Completed: ${JSON.stringify({
    services: result.createdServices.length,
    products: result.createdProducts.length,
    devices: result.createdDevices.length,
    customers: result.createdCustomers.length,
    orders: result.createdOrders.length,
  })}`);

  return result;
}

// ============================================================================
// Sample orders (lib/services/bootstrap_service.dart, _createSampleOrders)
// ============================================================================

/** Status of the i-th sample order: a quote, an approved one, one in progress and a finished one. */
export const SAMPLE_ORDER_STATUSES: readonly OrderStatus[] = ['quote', 'approved', 'progress', 'done'];

/**
 * Due date of the i-th sample order, as BootstrapService.sampleOrderDueDate:
 * the coming days (tomorrow, then every other day) at 09:00, so the first look
 * shows upcoming work in the Agenda instead of late orders. Wall time of the
 * company's zone, without a zone, the way the app stores dates.
 */
export function sampleOrderDueDate(index: number, now: Date, country?: string | null): string {
  let day = dayIn(now, companyZone(country));
  for (let i = 0; i < 1 + index * 2; i++) day = nextDay(day);
  return `${day}T09:00:00.000`;
}

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Four orders with different statuses over the customers, devices and services
 * of the company (the samples just created). Nothing when the company already
 * has an order or lacks one of the three. Fixed ids: a repeated call never
 * creates them twice. The first one gets the first active checklist.
 */
export async function createSampleOrders(params: {
  companyId: string;
  userAggr: UserAggr;
  companyAggr: CompanyAggr;
  now?: Date;
}): Promise<string[]> {
  const { companyId, userAggr, companyAggr, now = new Date() } = params;
  const company = db.collection('companies').doc(companyId);
  const existing = await company.collection('orders').limit(1).get();
  if (!existing.empty) return [];

  const [customers, devices, services] = await Promise.all(
    ['customers', 'devices', 'services'].map((name) => company.collection(name).limit(10).get()),
  );
  if (customers.empty || devices.empty || services.empty) return [];

  const created: string[] = [];
  for (let i = 0; i < SAMPLE_ORDER_STATUSES.length; i++) {
    const customerDoc = customers.docs[i % customers.docs.length];
    const deviceDoc = devices.docs[i % devices.docs.length];
    const serviceDoc = services.docs[i % services.docs.length];
    const customer = customerDoc.data();
    const device = deviceDoc.data();
    const service = serviceDoc.data();
    const status = SAMPLE_ORDER_STATUSES[i];
    const dueDate = sampleOrderDueDate(i, now, companyAggr.country);
    const order = await createOrder(
      companyId,
      {
        clientOrderId: `sample-order-${i + 1}`,
        customerId: customerDoc.id,
        customer: { id: customerDoc.id, name: customer.name ?? '', phone: customer.phone ?? null, email: customer.email ?? null },
        deviceId: deviceDoc.id,
        device: { id: deviceDoc.id, name: device.name ?? '', serial: device.serial ?? null, category: device.category ?? null },
        services: [{ serviceId: serviceDoc.id, value: typeof service.value === 'number' ? service.value : null }],
        status,
        dueDate,
        scheduledDate: status === 'done' ? undefined : dueDate,
      },
      userAggr,
      companyAggr,
    );
    // Created some days ago, as the app does, so the list is not all "today".
    await company.collection('orders').doc(order.id).update({
      createdAt: new Date(now.getTime() - (11 - i * 2) * DAY_MS).toISOString(),
      updatedAt: new Date(now.getTime() - (10 - i * 2) * DAY_MS).toISOString(),
    });
    created.push(order.id);

    if (i === 0) {
      try {
        const [template] = await listFormTemplates(companyId);
        if (template) await addFormToOrder(companyId, order.id, template.id, userAggr);
      } catch (error) {
        console.error('[BOOTSTRAP] Could not add a checklist to the sample order:', error instanceof Error ? error.message : 'unknown');
      }
    }
  }
  return created;
}
