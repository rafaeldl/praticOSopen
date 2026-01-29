/**
 * Catalog Service
 * Business logic for services and products catalog
 */

import {
  getTenantCollection,
  paginatedQuery,
  getDocument,
  createDocument,
  findByField,
  QueryFilter,
} from './firestore.service';
import {
  Service,
  ServiceAggr,
  Product,
  ProductAggr,
  UserAggr,
  CompanyAggr,
} from '../models/types';
import { normalizeSearchQuery } from '../utils/validation.utils';
import { generateKeywords } from '../utils/search.utils';

// ============================================================================
// Service Operations
// ============================================================================

export interface CatalogQueryParams {
  name?: string;
  minValue?: number;
  maxValue?: number;
  limit?: number;
  offset?: number;
}

/**
 * List services with filtering and pagination
 */
export async function listServices(
  companyId: string,
  params: CatalogQueryParams
): Promise<{ data: Service[]; total: number; hasMore: boolean }> {
  const collection = getTenantCollection(companyId, 'services');
  const filters: QueryFilter[] = [];

  if (params.minValue !== undefined) {
    filters.push({ field: 'value', operator: '>=', value: params.minValue });
  }

  if (params.maxValue !== undefined) {
    filters.push({ field: 'value', operator: '<=', value: params.maxValue });
  }

  const result = await paginatedQuery<Service>(collection, {
    limit: params.limit,
    offset: params.offset,
    orderBy: 'name',
    orderDirection: 'asc',
    filters,
  });

  // Apply name filter in memory if provided
  if (params.name) {
    const nameLower = normalizeSearchQuery(params.name);
    result.data = result.data.filter((s) =>
      s.name?.toLowerCase().includes(nameLower)
    );
  }

  return result;
}

/**
 * Get a single service by ID
 */
export async function getService(
  companyId: string,
  serviceId: string
): Promise<Service | null> {
  const collection = getTenantCollection(companyId, 'services');
  return getDocument<Service>(collection, serviceId);
}

/**
 * Search services by keyword
 * Uses array-contains query on keywords field for better search flexibility
 */
export async function searchServices(
  companyId: string,
  query: string,
  limit = 10
): Promise<Service[]> {
  const collection = getTenantCollection(companyId, 'services');
  const normalizedQuery = normalizeSearchQuery(query);
  // Use first keyword for array-contains query
  const keyword = normalizedQuery.split(/\s+/)[0];
  if (!keyword) return [];

  const snapshot = await collection
    .where('keywords', 'array-contains', keyword)
    .limit(limit)
    .get();

  return snapshot.docs.map((doc) => ({
    ...doc.data(),
    id: doc.id,
  })) as Service[];
}

export interface CreateServiceInput {
  name: string;
  value: number;
}

/**
 * Create a new service
 */
export async function createService(
  companyId: string,
  input: CreateServiceInput,
  createdBy: UserAggr,
  company: CompanyAggr
): Promise<{ id: string; name: string }> {
  const collection = getTenantCollection(companyId, 'services');

  const serviceData = {
    name: input.name,
    nameLower: input.name.toLowerCase(), // For exact match lookups
    keywords: generateKeywords(input.name), // For array-contains search
    value: input.value,
    photo: null,
    company,
    createdBy,
    createdAt: new Date().toISOString(),
  };

  const id = await createDocument(collection, serviceData);

  return { id, name: input.name };
}

/**
 * Convert Service to ServiceAggr
 */
export function toServiceAggr(service: Service): ServiceAggr {
  return {
    id: service.id,
    name: service.name,
    value: service.value,
    photo: service.photo,
  };
}

// ============================================================================
// Product Operations
// ============================================================================

/**
 * List products with filtering and pagination
 */
export async function listProducts(
  companyId: string,
  params: CatalogQueryParams
): Promise<{ data: Product[]; total: number; hasMore: boolean }> {
  const collection = getTenantCollection(companyId, 'products');
  const filters: QueryFilter[] = [];

  if (params.minValue !== undefined) {
    filters.push({ field: 'value', operator: '>=', value: params.minValue });
  }

  if (params.maxValue !== undefined) {
    filters.push({ field: 'value', operator: '<=', value: params.maxValue });
  }

  const result = await paginatedQuery<Product>(collection, {
    limit: params.limit,
    offset: params.offset,
    orderBy: 'name',
    orderDirection: 'asc',
    filters,
  });

  // Apply name filter in memory if provided
  if (params.name) {
    const nameLower = normalizeSearchQuery(params.name);
    result.data = result.data.filter((p) =>
      p.name?.toLowerCase().includes(nameLower)
    );
  }

  return result;
}

/**
 * Get a single product by ID
 */
export async function getProduct(
  companyId: string,
  productId: string
): Promise<Product | null> {
  const collection = getTenantCollection(companyId, 'products');
  return getDocument<Product>(collection, productId);
}

/**
 * Search products by keyword
 * Uses array-contains query on keywords field for better search flexibility
 */
export async function searchProducts(
  companyId: string,
  query: string,
  limit = 10
): Promise<Product[]> {
  const collection = getTenantCollection(companyId, 'products');
  const normalizedQuery = normalizeSearchQuery(query);
  // Use first keyword for array-contains query
  const keyword = normalizedQuery.split(/\s+/)[0];
  if (!keyword) return [];

  const snapshot = await collection
    .where('keywords', 'array-contains', keyword)
    .limit(limit)
    .get();

  return snapshot.docs.map((doc) => ({
    ...doc.data(),
    id: doc.id,
  })) as Product[];
}

export interface CreateProductInput {
  name: string;
  value: number;
}

/**
 * Create a new product
 */
export async function createProduct(
  companyId: string,
  input: CreateProductInput,
  createdBy: UserAggr,
  company: CompanyAggr
): Promise<{ id: string; name: string }> {
  const collection = getTenantCollection(companyId, 'products');

  const productData = {
    name: input.name,
    nameLower: input.name.toLowerCase(), // For exact match lookups
    keywords: generateKeywords(input.name), // For array-contains search
    value: input.value,
    photo: null,
    company,
    createdBy,
    createdAt: new Date().toISOString(),
  };

  const id = await createDocument(collection, productData);

  return { id, name: input.name };
}

/**
 * Convert Product to ProductAggr
 */
export function toProductAggr(product: Product): ProductAggr {
  return {
    id: product.id,
    name: product.name,
    value: product.value,
    photo: product.photo,
  };
}

// ============================================================================
// Get or Create Operations (for bot integration)
// ============================================================================

export interface ServiceInput {
  serviceId?: string;
  serviceName?: string;
  value: number;
  description?: string;
}

/**
 * Get or create service (for bot order management)
 * Finds by ID, or by exact name match, or creates new
 */
export async function getOrCreateService(
  companyId: string,
  input: ServiceInput,
  createdBy: UserAggr,
  company: CompanyAggr
): Promise<{ service: ServiceAggr; created: boolean }> {
  // If ID is provided, try to get it first
  if (input.serviceId) {
    const existing = await getService(companyId, input.serviceId);
    if (existing) {
      return {
        service: toServiceAggr(existing),
        created: false,
      };
    }
  }

  // If name is provided, try to find by exact name match
  if (input.serviceName) {
    const collection = getTenantCollection(companyId, 'services');
    const byName = await findByField<Service>(collection, 'nameLower', input.serviceName.toLowerCase());
    if (byName) {
      return {
        service: toServiceAggr(byName),
        created: false,
      };
    }

    // Create new service
    const result = await createService(
      companyId,
      { name: input.serviceName, value: input.value },
      createdBy,
      company
    );

    return {
      service: {
        id: result.id,
        name: result.name,
        value: input.value,
        photo: undefined,
      },
      created: true,
    };
  }

  throw new Error('Either serviceId or serviceName is required');
}

export interface ProductInput {
  productId?: string;
  productName?: string;
  value: number;
  quantity?: number;
  description?: string;
}

/**
 * Get or create product (for bot order management)
 * Finds by ID, or by exact name match, or creates new
 */
export async function getOrCreateProduct(
  companyId: string,
  input: ProductInput,
  createdBy: UserAggr,
  company: CompanyAggr
): Promise<{ product: ProductAggr; created: boolean }> {
  // If ID is provided, try to get it first
  if (input.productId) {
    const existing = await getProduct(companyId, input.productId);
    if (existing) {
      return {
        product: toProductAggr(existing),
        created: false,
      };
    }
  }

  // If name is provided, try to find by exact name match
  if (input.productName) {
    const collection = getTenantCollection(companyId, 'products');
    const byName = await findByField<Product>(collection, 'nameLower', input.productName.toLowerCase());
    if (byName) {
      return {
        product: toProductAggr(byName),
        created: false,
      };
    }

    // Create new product
    const result = await createProduct(
      companyId,
      { name: input.productName, value: input.value },
      createdBy,
      company
    );

    return {
      product: {
        id: result.id,
        name: result.name,
        value: input.value,
        photo: undefined,
      },
      created: true,
    };
  }

  throw new Error('Either productId or productName is required');
}
