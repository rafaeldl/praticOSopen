/**
 * Customer Service
 * Business logic for customer operations
 */

import {
  getTenantCollection,
  paginatedQuery,
  getDocument,
  createDocument,
  updateDocument,
  findByField,
  QueryFilter,
} from './firestore.service';
import {
  Customer,
  CustomerAggr,
  UserAggr,
  CompanyAggr,
} from '../models/types';
import { normalizeSearchQuery } from '../utils/validation.utils';
import { generateKeywords } from '../utils/search.utils';

// ============================================================================
// Query Operations
// ============================================================================

export interface CustomerQueryParams {
  phone?: string;
  email?: string;
  name?: string;
  limit?: number;
  offset?: number;
}

/**
 * List customers with filtering and pagination
 */
export async function listCustomers(
  companyId: string,
  params: CustomerQueryParams
): Promise<{ data: Customer[]; total: number; hasMore: boolean }> {
  const collection = getTenantCollection(companyId, 'customers');
  const filters: QueryFilter[] = [];

  if (params.phone) {
    filters.push({ field: 'phone', operator: '==', value: params.phone });
  }

  if (params.email) {
    filters.push({ field: 'email', operator: '==', value: params.email });
  }

  // Note: Name search requires additional indexing or search by prefix
  // For now, we'll filter in memory for exact matches
  const result = await paginatedQuery<Customer>(collection, {
    limit: params.limit,
    offset: params.offset,
    orderBy: 'createdAt',
    orderDirection: 'desc',
    filters,
  });

  // Apply name filter in memory if provided
  if (params.name) {
    const nameLower = normalizeSearchQuery(params.name);
    result.data = result.data.filter((c) =>
      c.name?.toLowerCase().includes(nameLower)
    );
  }

  return result;
}

/**
 * Get a single customer by ID
 */
export async function getCustomer(
  companyId: string,
  customerId: string
): Promise<Customer | null> {
  const collection = getTenantCollection(companyId, 'customers');
  return getDocument<Customer>(collection, customerId);
}

/**
 * Find customer by phone number
 */
export async function findCustomerByPhone(
  companyId: string,
  phone: string
): Promise<Customer | null> {
  const collection = getTenantCollection(companyId, 'customers');
  return findByField<Customer>(collection, 'phone', phone);
}

/**
 * Search customers by keyword
 * Uses array-contains query on keywords field for better search flexibility
 * If query is empty, returns all customers (limited)
 */
export async function searchCustomers(
  companyId: string,
  query: string,
  limit = 10
): Promise<Customer[]> {
  const collection = getTenantCollection(companyId, 'customers');
  const normalizedQuery = normalizeSearchQuery(query);
  // Use first keyword for array-contains query
  const keyword = normalizedQuery.split(/\s+/)[0];

  // If no keyword, list all customers
  if (!keyword) {
    const snapshot = await collection
      .orderBy('createdAt', 'desc')
      .limit(limit)
      .get();

    return snapshot.docs.map((doc) => ({
      ...doc.data(),
      id: doc.id,
    })) as Customer[];
  }

  const snapshot = await collection
    .where('keywords', 'array-contains', keyword)
    .limit(limit)
    .get();

  return snapshot.docs.map((doc) => ({
    ...doc.data(),
    id: doc.id,
  })) as Customer[];
}

// ============================================================================
// Write Operations
// ============================================================================

export interface CreateCustomerInput {
  name: string;
  phone?: string;
  email?: string;
  address?: string;
}

/**
 * Create a new customer
 */
export async function createCustomer(
  companyId: string,
  input: CreateCustomerInput,
  createdBy: UserAggr,
  company: CompanyAggr
): Promise<{ id: string; customer: CustomerAggr }> {
  const collection = getTenantCollection(companyId, 'customers');

  const customerData = {
    name: input.name,
    nameLower: input.name.toLowerCase(), // For exact match lookups
    keywords: generateKeywords(input.name), // For array-contains search
    phone: input.phone || null,
    email: input.email || null,
    address: input.address || null,
    company,
    createdBy,
    createdAt: new Date().toISOString(),
  };

  const id = await createDocument(collection, customerData);

  return {
    id,
    customer: {
      id,
      name: input.name,
      phone: input.phone,
      email: input.email,
    },
  };
}

export interface UpdateCustomerInput {
  name?: string;
  phone?: string;
  email?: string;
  address?: string;
}

/**
 * Update an existing customer
 */
export async function updateCustomer(
  companyId: string,
  customerId: string,
  input: UpdateCustomerInput,
  updatedBy: UserAggr
): Promise<boolean> {
  const collection = getTenantCollection(companyId, 'customers');

  // Check if customer exists
  const existing = await getDocument<Customer>(collection, customerId);
  if (!existing) return false;

  const updateData: Record<string, unknown> = {
    updatedBy,
    updatedAt: new Date().toISOString(),
  };

  if (input.name !== undefined) {
    updateData.name = input.name;
    updateData.nameLower = input.name.toLowerCase();
    updateData.keywords = generateKeywords(input.name);
  }
  if (input.phone !== undefined) updateData.phone = input.phone;
  if (input.email !== undefined) updateData.email = input.email;
  if (input.address !== undefined) updateData.address = input.address;

  await updateDocument(collection, customerId, updateData);
  return true;
}

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * Get or create customer (for quick order creation)
 */
export async function getOrCreateCustomer(
  companyId: string,
  name: string,
  phone: string | undefined,
  createdBy: UserAggr,
  company: CompanyAggr
): Promise<{ customer: CustomerAggr; created: boolean }> {
  // Try to find by phone first
  if (phone) {
    const existing = await findCustomerByPhone(companyId, phone);
    if (existing) {
      return {
        customer: {
          id: existing.id,
          name: existing.name,
          phone: existing.phone ?? null,
          email: existing.email ?? null,
        },
        created: false,
      };
    }
  }

  // Try to find by exact name match
  const collection = getTenantCollection(companyId, 'customers');
  const byName = await findByField<Customer>(collection, 'nameLower', name.toLowerCase());
  if (byName) {
    return {
      customer: {
        id: byName.id,
        name: byName.name,
        phone: byName.phone ?? null,
        email: byName.email ?? null,
      },
      created: false,
    };
  }

  // Create new customer
  const result = await createCustomer(
    companyId,
    { name, phone },
    createdBy,
    company
  );

  return {
    customer: result.customer,
    created: true,
  };
}

/**
 * Convert Customer to CustomerAggr
 */
export function toCustomerAggr(customer: Customer): CustomerAggr {
  return {
    id: customer.id,
    name: customer.name,
    phone: customer.phone ?? null,
    email: customer.email ?? null,
  };
}
