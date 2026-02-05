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
} from '../models/types';

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
async function syncCompanyFormsFromSegment(params: {
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

  // 7. Sync form templates from segment
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

  console.log(`[BOOTSTRAP] Completed: ${JSON.stringify({
    services: result.createdServices.length,
    products: result.createdProducts.length,
    devices: result.createdDevices.length,
    customers: result.createdCustomers.length,
  })}`);

  return result;
}
