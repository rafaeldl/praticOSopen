/**
 * Device Service
 * Business logic for device operations
 */

import {
  getTenantCollection,
  paginatedQuery,
  getDocument,
  createDocument,
  updateDocument,
  findByField,
  searchByPrefix,
  Timestamp,
  QueryFilter,
} from './firestore.service';
import {
  Device,
  DeviceAggr,
  UserAggr,
  CompanyAggr,
} from '../models/types';
import { normalizeSearchQuery } from '../utils/validation.utils';

// ============================================================================
// Query Operations
// ============================================================================

export interface DeviceQueryParams {
  serial?: string;
  name?: string;
  category?: string;
  manufacturer?: string;
  limit?: number;
  offset?: number;
}

/**
 * List devices with filtering and pagination
 */
export async function listDevices(
  companyId: string,
  params: DeviceQueryParams
): Promise<{ data: Device[]; total: number; hasMore: boolean }> {
  const collection = getTenantCollection(companyId, 'devices');
  const filters: QueryFilter[] = [];

  if (params.serial) {
    filters.push({ field: 'serial', operator: '==', value: params.serial });
  }

  if (params.category) {
    filters.push({ field: 'category', operator: '==', value: params.category });
  }

  if (params.manufacturer) {
    filters.push({ field: 'manufacturer', operator: '==', value: params.manufacturer });
  }

  const result = await paginatedQuery<Device>(collection, {
    limit: params.limit,
    offset: params.offset,
    orderBy: 'createdAt',
    orderDirection: 'desc',
    filters,
  });

  // Apply name filter in memory if provided
  if (params.name) {
    const nameLower = normalizeSearchQuery(params.name);
    result.data = result.data.filter((d) =>
      d.name?.toLowerCase().includes(nameLower)
    );
  }

  return result;
}

/**
 * Get a single device by ID
 */
export async function getDevice(
  companyId: string,
  deviceId: string
): Promise<Device | null> {
  const collection = getTenantCollection(companyId, 'devices');
  return getDocument<Device>(collection, deviceId);
}

/**
 * Find device by serial number
 */
export async function findDeviceBySerial(
  companyId: string,
  serial: string
): Promise<Device | null> {
  const collection = getTenantCollection(companyId, 'devices');
  return findByField<Device>(collection, 'serial', serial);
}

/**
 * Search devices by name prefix
 */
export async function searchDevices(
  companyId: string,
  query: string,
  limit = 10
): Promise<Device[]> {
  const collection = getTenantCollection(companyId, 'devices');
  const normalizedQuery = normalizeSearchQuery(query);
  return searchByPrefix<Device>(collection, 'nameLower', normalizedQuery, limit);
}

// ============================================================================
// Write Operations
// ============================================================================

export interface CreateDeviceInput {
  name: string;
  serial?: string;
  manufacturer?: string;
  category?: string;
  description?: string;
}

/**
 * Create a new device
 */
export async function createDevice(
  companyId: string,
  input: CreateDeviceInput,
  createdBy: UserAggr,
  company: CompanyAggr
): Promise<{ id: string; device: DeviceAggr }> {
  const collection = getTenantCollection(companyId, 'devices');

  const deviceData = {
    name: input.name,
    nameLower: input.name.toLowerCase(), // For search
    serial: input.serial || null,
    manufacturer: input.manufacturer || null,
    category: input.category || null,
    description: input.description || null,
    company,
    createdBy,
    createdAt: Timestamp.now(),
  };

  const id = await createDocument(collection, deviceData);

  return {
    id,
    device: {
      id,
      name: input.name,
      serial: input.serial,
    },
  };
}

export interface UpdateDeviceInput {
  name?: string;
  serial?: string;
  manufacturer?: string;
  category?: string;
  description?: string;
}

/**
 * Update an existing device
 */
export async function updateDevice(
  companyId: string,
  deviceId: string,
  input: UpdateDeviceInput,
  updatedBy: UserAggr
): Promise<boolean> {
  const collection = getTenantCollection(companyId, 'devices');

  // Check if device exists
  const existing = await getDocument<Device>(collection, deviceId);
  if (!existing) return false;

  const updateData: Record<string, unknown> = {
    updatedBy,
    updatedAt: Timestamp.now(),
  };

  if (input.name !== undefined) {
    updateData.name = input.name;
    updateData.nameLower = input.name.toLowerCase();
  }
  if (input.serial !== undefined) updateData.serial = input.serial;
  if (input.manufacturer !== undefined) updateData.manufacturer = input.manufacturer;
  if (input.category !== undefined) updateData.category = input.category;
  if (input.description !== undefined) updateData.description = input.description;

  await updateDocument(collection, deviceId, updateData);
  return true;
}

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * Get or create device (for quick order creation)
 */
export async function getOrCreateDevice(
  companyId: string,
  name: string,
  serial: string | undefined,
  createdBy: UserAggr,
  company: CompanyAggr
): Promise<{ device: DeviceAggr; created: boolean }> {
  // Try to find by serial first
  if (serial) {
    const existing = await findDeviceBySerial(companyId, serial);
    if (existing) {
      return {
        device: {
          id: existing.id,
          name: existing.name,
          serial: existing.serial ?? null,
          photo: existing.photo ?? null,
        },
        created: false,
      };
    }
  }

  // Try to find by exact name match
  const collection = getTenantCollection(companyId, 'devices');
  const byName = await findByField<Device>(collection, 'nameLower', name.toLowerCase());
  if (byName) {
    return {
      device: {
        id: byName.id,
        name: byName.name,
        serial: byName.serial ?? null,
        photo: byName.photo ?? null,
      },
      created: false,
    };
  }

  // Create new device
  const result = await createDevice(
    companyId,
    { name, serial },
    createdBy,
    company
  );

  return {
    device: result.device,
    created: true,
  };
}

/**
 * Convert Device to DeviceAggr
 */
export function toDeviceAggr(device: Device): DeviceAggr {
  return {
    id: device.id,
    name: device.name,
    serial: device.serial ?? null,
    photo: device.photo ?? null,
  };
}
