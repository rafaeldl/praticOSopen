/**
 * Bot Unified Search Routes
 * Single endpoint to search multiple entities at once
 */

import { Router, Response } from 'express';
import { AuthenticatedRequest } from '../../models/types';
import { requireLinked } from '../../middleware/auth.middleware';
import * as customerService from '../../services/customer.service';
import * as deviceService from '../../services/device.service';
import * as catalogService from '../../services/catalog.service';
import { validateInput, unifiedSearchSchema } from '../../utils/validation.utils';
import { normalizePhone } from '../../utils/format.utils';

const router: Router = Router();

// ============================================================================
// Types
// ============================================================================

interface CustomerResult {
  exact: { id: string; name: string; phone?: string } | null;
  suggestions: Array<{ id: string; name: string; phone?: string }>;
  available: Array<{ id: string; name: string; phone?: string }> | null;
}

interface DeviceResult {
  exact: { id: string; name: string; serial?: string } | null;
  suggestions: Array<{ id: string; name: string; serial?: string }>;
  available: Array<{ id: string; name: string; serial?: string }> | null;
}

interface CatalogResult {
  results: Array<{ id: string; name: string; value?: number }>;
  available: Array<{ id: string; name: string; value?: number }> | null;
}

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Normalize search input: string or array to array
 */
function normalizeSearchInput(input: string | string[] | undefined): string[] {
  if (!input) return [];
  if (Array.isArray(input)) return input;
  return [input];
}

/**
 * Deduplicate results by ID
 */
function deduplicateById<T extends { id: string }>(items: T[]): T[] {
  const seen = new Set<string>();
  return items.filter((item) => {
    if (seen.has(item.id)) return false;
    seen.add(item.id);
    return true;
  });
}

/**
 * Search customer by phone (exact match)
 */
async function searchCustomerByPhone(
  companyId: string,
  phone: string
): Promise<{ exact: CustomerResult['exact']; suggestions: CustomerResult['suggestions'] }> {
  const byPhone = await customerService.findCustomerByPhone(companyId, normalizePhone(phone));
  if (byPhone) {
    return {
      exact: {
        id: byPhone.id,
        name: byPhone.name,
        phone: byPhone.phone ?? undefined,
      },
      suggestions: [],
    };
  }
  return { exact: null, suggestions: [] };
}

/**
 * Search customer by name (fuzzy match)
 */
async function searchCustomerByName(
  companyId: string,
  query: string,
  limit: number
): Promise<{ exact: CustomerResult['exact']; suggestions: CustomerResult['suggestions'] }> {
  const byName = await customerService.searchCustomers(companyId, query, limit);
  const suggestions = byName.map((c) => ({
    id: c.id,
    name: c.name,
    phone: c.phone ?? undefined,
  }));

  return { exact: null, suggestions };
}

/**
 * Search device by serial (exact match)
 */
async function searchDeviceBySerial(
  companyId: string,
  serial: string
): Promise<{ exact: DeviceResult['exact']; suggestions: DeviceResult['suggestions'] }> {
  const bySerial = await deviceService.findDeviceBySerial(companyId, serial);
  if (bySerial) {
    return {
      exact: {
        id: bySerial.id,
        name: bySerial.name,
        serial: bySerial.serial ?? undefined,
      },
      suggestions: [],
    };
  }
  return { exact: null, suggestions: [] };
}

/**
 * Search device by name (fuzzy match)
 */
async function searchDeviceByName(
  companyId: string,
  query: string,
  limit: number
): Promise<{ exact: DeviceResult['exact']; suggestions: DeviceResult['suggestions'] }> {
  const byName = await deviceService.searchDevices(companyId, query, limit);
  const suggestions = byName.map((d) => ({
    id: d.id,
    name: d.name,
    serial: d.serial ?? undefined,
  }));

  return { exact: null, suggestions };
}

/**
 * Get list of available customers (fallback when search returns empty)
 */
async function getAvailableCustomers(
  companyId: string,
  limit: number
): Promise<CustomerResult['available']> {
  const all = await customerService.searchCustomers(companyId, '', limit);
  return all.map((c) => ({
    id: c.id,
    name: c.name,
    phone: c.phone ?? undefined,
  }));
}

/**
 * Get list of available devices (fallback when search returns empty)
 */
async function getAvailableDevices(
  companyId: string,
  limit: number
): Promise<DeviceResult['available']> {
  const all = await deviceService.searchDevices(companyId, '', limit);
  return all.map((d) => ({
    id: d.id,
    name: d.name,
    serial: d.serial ?? undefined,
  }));
}

/**
 * Get list of available services (fallback when search returns empty)
 */
async function getAvailableServices(
  companyId: string,
  limit: number
): Promise<CatalogResult['available']> {
  const result = await catalogService.listServices(companyId, { limit });
  return result.data.map((s) => ({
    id: s.id,
    name: s.name,
    value: s.value,
  }));
}

/**
 * Get list of available products (fallback when search returns empty)
 */
async function getAvailableProducts(
  companyId: string,
  limit: number
): Promise<CatalogResult['available']> {
  const result = await catalogService.listProducts(companyId, { limit });
  return result.data.map((p) => ({
    id: p.id,
    name: p.name,
    value: p.value,
  }));
}

// ============================================================================
// Routes
// ============================================================================

/**
 * POST /api/bot/search/unified
 * Search multiple entities in one request
 *
 * Body: {
 *   customer?: string,       // Search customer by name
 *   customerPhone?: string,  // Search customer by phone (exact match)
 *   device?: string,         // Search device by name
 *   deviceSerial?: string,   // Search device by serial (exact match)
 *   service?: string,        // Search service by name
 *   product?: string,        // Search product by name
 *   limit?: number           // Max results per entity (default 5, max 10)
 * }
 *
 * Response: {
 *   success: true,
 *   data: {
 *     customer?: { exact, suggestions, available },
 *     device?: { exact, suggestions, available },
 *     service?: { results, available },
 *     product?: { results, available }
 *   }
 * }
 */
router.post('/unified', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    // Normalize common bot field name variations before validation
    const body = { ...req.body };
    if (body.query && !body.customer && !body.device && !body.service && !body.product) {
      body.customer = body.query;
      delete body.query;
    }
    if (body.q && !body.customer && !body.device && !body.service && !body.product) {
      body.customer = body.q;
      delete body.q;
    }

    // Validate input
    const validation = validateInput(unifiedSearchSchema, body);
    if (!validation.success) {
      res.status(400).json({
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: validation.errors.join(', '),
        },
      });
      return;
    }

    const data = validation.data;
    const limit = data.limit ?? 5;
    const fallbackLimit = 10;

    // Normalize inputs to arrays
    const customerTerms = normalizeSearchInput(data.customer);
    const deviceTerms = normalizeSearchInput(data.device);
    const serviceTerms = normalizeSearchInput(data.service);
    const productTerms = normalizeSearchInput(data.product);

    // Customer search: phone takes priority, then multiple name terms
    let customerResult: { exact: CustomerResult['exact']; suggestions: CustomerResult['suggestions'] } | null = null;
    if (data.customerPhone) {
      customerResult = await searchCustomerByPhone(companyId, data.customerPhone);
    } else if (customerTerms.length > 0) {
      // Search for each term in parallel and combine results
      const results = await Promise.all(
        customerTerms.map((term) => searchCustomerByName(companyId, term, limit))
      );
      const allSuggestions = results.flatMap((r) => r.suggestions);
      customerResult = {
        exact: null,
        suggestions: deduplicateById(allSuggestions).slice(0, limit),
      };
    }

    // Device search: serial takes priority, then multiple name terms
    let deviceResult: { exact: DeviceResult['exact']; suggestions: DeviceResult['suggestions'] } | null = null;
    if (data.deviceSerial) {
      deviceResult = await searchDeviceBySerial(companyId, data.deviceSerial);
    } else if (deviceTerms.length > 0) {
      const results = await Promise.all(
        deviceTerms.map((term) => searchDeviceByName(companyId, term, limit))
      );
      const allSuggestions = results.flatMap((r) => r.suggestions);
      deviceResult = {
        exact: null,
        suggestions: deduplicateById(allSuggestions).slice(0, limit),
      };
    }

    // Service search: multiple terms
    let serviceResult: Array<{ id: string; name: string; value?: number }> | null = null;
    if (serviceTerms.length > 0) {
      const results = await Promise.all(
        serviceTerms.map((term) => catalogService.searchServices(companyId, term, limit))
      );
      const allResults = results.flatMap((r) => r.map((s) => ({
        id: s.id,
        name: s.name,
        value: s.value,
      })));
      serviceResult = deduplicateById(allResults).slice(0, limit);
    }

    // Product search: multiple terms
    let productResult: Array<{ id: string; name: string; value?: number }> | null = null;
    if (productTerms.length > 0) {
      const results = await Promise.all(
        productTerms.map((term) => catalogService.searchProducts(companyId, term, limit))
      );
      const allResults = results.flatMap((r) => r.map((p) => ({
        id: p.id,
        name: p.name,
        value: p.value,
      })));
      productResult = deduplicateById(allResults).slice(0, limit);
    }

    // Build response object
    const response: {
      customer?: CustomerResult;
      device?: DeviceResult;
      service?: CatalogResult;
      product?: CatalogResult;
    } = {};

    // Process customer results
    if (customerTerms.length > 0 || data.customerPhone !== undefined) {
      const needsFallback = customerResult && !customerResult.exact && customerResult.suggestions.length === 0;
      response.customer = {
        exact: customerResult?.exact ?? null,
        suggestions: customerResult?.suggestions ?? [],
        available: needsFallback ? await getAvailableCustomers(companyId, fallbackLimit) : null,
      };
    }

    // Process device results
    if (deviceTerms.length > 0 || data.deviceSerial !== undefined) {
      const needsFallback = deviceResult && !deviceResult.exact && deviceResult.suggestions.length === 0;
      response.device = {
        exact: deviceResult?.exact ?? null,
        suggestions: deviceResult?.suggestions ?? [],
        available: needsFallback ? await getAvailableDevices(companyId, fallbackLimit) : null,
      };
    }

    // Process service results
    if (serviceTerms.length > 0) {
      const results = serviceResult ?? [];
      const needsFallback = results.length === 0;
      response.service = {
        results,
        available: needsFallback ? await getAvailableServices(companyId, fallbackLimit) : null,
      };
    }

    // Process product results
    if (productTerms.length > 0) {
      const results = productResult ?? [];
      const needsFallback = results.length === 0;
      response.product = {
        results,
        available: needsFallback ? await getAvailableProducts(companyId, fallbackLimit) : null,
      };
    }

    res.json({
      success: true,
      data: response,
    });
  } catch (error) {
    console.error('Unified search error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to perform unified search' },
    });
  }
});

export default router;
