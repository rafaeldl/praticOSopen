/**
 * Catalog Service
 * Business logic for services and products catalog
 */

import {
  getTenantCollection,
  paginatedQuery,
  getDocument,
  createDocument,
  searchByPrefix,
  Timestamp,
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
 * Search services by name prefix
 */
export async function searchServices(
  companyId: string,
  query: string,
  limit = 10
): Promise<Service[]> {
  const collection = getTenantCollection(companyId, 'services');
  const normalizedQuery = normalizeSearchQuery(query);
  return searchByPrefix<Service>(collection, 'nameLower', normalizedQuery, limit);
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
    nameLower: input.name.toLowerCase(),
    value: input.value,
    photo: null,
    company,
    createdBy,
    createdAt: Timestamp.now(),
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
 * Search products by name prefix
 */
export async function searchProducts(
  companyId: string,
  query: string,
  limit = 10
): Promise<Product[]> {
  const collection = getTenantCollection(companyId, 'products');
  const normalizedQuery = normalizeSearchQuery(query);
  return searchByPrefix<Product>(collection, 'nameLower', normalizedQuery, limit);
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
    nameLower: input.name.toLowerCase(),
    value: input.value,
    photo: null,
    company,
    createdBy,
    createdAt: Timestamp.now(),
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
