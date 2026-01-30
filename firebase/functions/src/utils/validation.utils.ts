/**
 * Validation Utilities
 * Helper functions for input validation and sanitization
 */

import { z } from 'zod';

// ============================================================================
// Common Validation Schemas
// ============================================================================

export const phoneSchema = z.string().regex(
  /^\+?[1-9]\d{6,14}$/,
  'Invalid phone number format'
);

export const emailSchema = z.string().email('Invalid email format');

export const idSchema = z.string().min(1, 'ID is required');

export const paginationSchema = z.object({
  limit: z.coerce.number().min(1).max(100).default(20),
  offset: z.coerce.number().min(0).default(0),
});

export const dateRangeSchema = z.object({
  startDate: z.string().datetime().optional(),
  endDate: z.string().datetime().optional(),
});

// ============================================================================
// Entity Validation Schemas
// ============================================================================

export const createCustomerSchema = z.object({
  name: z.string().min(1, 'Name is required').max(200),
  phone: z.string().optional(),
  email: emailSchema.optional(),
  address: z.string().max(500).optional(),
});

export const updateCustomerSchema = z.object({
  name: z.string().min(1).max(200).optional(),
  phone: z.string().optional(),
  email: emailSchema.optional(),
  address: z.string().max(500).optional(),
});

export const createDeviceSchema = z.object({
  name: z.string().min(1, 'Name is required').max(200),
  serial: z.string().max(100).optional(),
  manufacturer: z.string().max(100).optional(),
  category: z.string().max(100).optional(),
  description: z.string().max(1000).optional(),
});

/**
 * Schema for creating device via bot (serial is required)
 */
export const createBotDeviceSchema = z.object({
  name: z.string().min(1, 'Name is required').max(200),
  serial: z.string().min(1, 'Serial is required').max(100),
  manufacturer: z.string().max(100).optional(),
  category: z.string().max(100).optional(),
  description: z.string().max(1000).optional(),
});

export const updateDeviceSchema = z.object({
  name: z.string().min(1).max(200).optional(),
  serial: z.string().max(100).optional(),
  manufacturer: z.string().max(100).optional(),
  category: z.string().max(100).optional(),
  description: z.string().max(1000).optional(),
});

export const createServiceSchema = z.object({
  name: z.string().min(1, 'Name is required').max(200),
  value: z.number().min(0),
});

export const updateServiceSchema = z.object({
  name: z.string().min(1).max(200).optional(),
  value: z.number().min(0).optional(),
});

export const createProductSchema = z.object({
  name: z.string().min(1, 'Name is required').max(200),
  value: z.number().min(0),
});

export const updateProductSchema = z.object({
  name: z.string().min(1).max(200).optional(),
  value: z.number().min(0).optional(),
});

export const createOrderSchema = z.object({
  customerId: idSchema,
  deviceId: idSchema.optional(),
  services: z.array(z.object({
    serviceId: idSchema,
    value: z.number().min(0).optional(),
    description: z.string().max(500).optional(),
  })).optional(),
  products: z.array(z.object({
    productId: idSchema,
    quantity: z.number().min(1),
    value: z.number().min(0).optional(),
    description: z.string().max(500).optional(),
  })).optional(),
  dueDate: z.string().datetime().optional(),
  status: z.enum(['quote', 'approved', 'progress', 'done', 'canceled']).default('quote'),
});

export const updateOrderSchema = z.object({
  status: z.enum(['quote', 'approved', 'progress', 'done', 'canceled']).optional(),
  dueDate: z.string().datetime().optional(),
  assignedTo: idSchema.optional(),
});

export const addOrderServiceSchema = z.object({
  serviceId: idSchema,
  value: z.number().min(0).optional(),
  description: z.string().max(500).optional(),
});

export const addOrderProductSchema = z.object({
  productId: idSchema,
  quantity: z.number().min(1),
  value: z.number().min(0).optional(),
  description: z.string().max(500).optional(),
});

export const addPaymentSchema = z.object({
  amount: z.number().min(0.01, 'Amount must be greater than 0'),
  description: z.string().max(500).optional(),
  type: z.enum(['payment', 'discount']).default('payment'),
});

// ============================================================================
// Bot Validation Schemas
// ============================================================================

export const linkWhatsAppSchema = z.object({
  token: z.string().min(1, 'Token is required'),
  whatsappNumber: z.string().regex(
    /^\+[1-9]\d{6,14}$/,
    'WhatsApp number must be in E.164 format (e.g., +5511999999999)'
  ),
});

export const createInviteSchema = z.object({
  collaboratorName: z.string().min(1, 'Name is required').max(100),
  role: z.enum(['technician', 'consultant', 'supervisor', 'manager']),
});

export const acceptInviteSchema = z.object({
  inviteCode: z.string().min(1, 'Invite code is required'),
  whatsappNumber: z.string().regex(
    /^\+[1-9]\d{6,14}$/,
    'WhatsApp number must be in E.164 format'
  ),
  name: z.string().max(100).optional(),
});

export const searchQuerySchema = z.object({
  q: z.string().min(1, 'Search query is required').max(100),
});

export const optionalSearchQuerySchema = z.object({
  q: z.string().max(100).optional(),
});

// Helper schema: accepts string or array of strings (max 5 items)
const stringOrArraySchema = z.union([
  z.string().max(100),
  z.array(z.string().max(100)).max(5),
]);

export const unifiedSearchSchema = z.object({
  customer: stringOrArraySchema.optional(),
  customerPhone: z.string().max(20).optional(),
  device: stringOrArraySchema.optional(),
  deviceSerial: z.string().max(100).optional(),
  service: stringOrArraySchema.optional(),
  product: stringOrArraySchema.optional(),
  limit: z.coerce.number().min(1).max(10).default(5),
});

// ============================================================================
// Bot Order Management Schemas
// ============================================================================

/**
 * Schema for creating a complete order via bot
 * REQUIRES existing entity IDs - does NOT accept names
 * Value is optional - falls back to catalog value if not provided
 */
export const createFullOrderSchema = z.object({
  // Customer: ID required
  customerId: idSchema,

  // Device: optional but only by ID
  deviceId: idSchema.optional(),

  // Services: by ID only, value optional (falls back to catalog)
  services: z.array(z.object({
    serviceId: idSchema,
    value: z.number().min(0).optional(),
    description: z.string().max(500).optional(),
  })).optional(),

  // Products: by ID only, value optional (falls back to catalog)
  products: z.array(z.object({
    productId: idSchema,
    value: z.number().min(0).optional(),
    quantity: z.number().min(1).default(1),
    description: z.string().max(500).optional(),
  })).optional(),

  dueDate: z.string().optional(),
  status: z.enum(['quote', 'approved', 'progress']).default('quote'),
});

/**
 * Schema for adding a service to an existing order
 * REQUIRES existing service ID - does NOT accept names
 * Value is optional - falls back to catalog value if not provided
 */
export const addServiceToOrderSchema = z.object({
  serviceId: idSchema,
  value: z.number().min(0).optional(),
  description: z.string().max(500).optional(),
});

/**
 * Schema for adding a product to an existing order
 * REQUIRES existing product ID - does NOT accept names
 * Value is optional - falls back to catalog value if not provided
 */
export const addProductToOrderSchema = z.object({
  productId: idSchema,
  value: z.number().min(0).optional(),
  quantity: z.number().min(1).default(1),
  description: z.string().max(500).optional(),
});

/**
 * Schema for updating order device
 * REQUIRES existing device ID - does NOT accept names
 */
export const updateOrderDeviceSchema = z.object({
  deviceId: idSchema,
});

/**
 * Schema for updating order customer
 * REQUIRES existing customer ID - does NOT accept names
 */
export const updateOrderCustomerSchema = z.object({
  customerId: idSchema,
});

// ============================================================================
// Photo Upload Schema
// ============================================================================

/**
 * Schema for uploading photo from base64
 */
export const uploadPhotoBase64Schema = z.object({
  base64: z.string().min(1, 'Base64 data is required'),
  filename: z.string().min(1, 'Filename is required').max(255),
  description: z.string().max(500).optional(),
});

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Validate and parse input with Zod schema
 */
export function validateInput<T>(
  schema: z.ZodType<T>,
  data: unknown
): { success: true; data: T } | { success: false; errors: string[] } {
  const result = schema.safeParse(data);

  if (result.success) {
    return { success: true, data: result.data };
  }

  const errors = result.error.errors.map(
    (err) => `${err.path.join('.')}: ${err.message}`
  );

  return { success: false, errors };
}

/**
 * Sanitize string input (remove HTML tags, trim whitespace)
 */
export function sanitizeString(input: string): string {
  return input
    .replace(/<[^>]*>/g, '')
    .replace(/[<>&'"]/g, (char) => {
      const entities: Record<string, string> = {
        '<': '&lt;',
        '>': '&gt;',
        '&': '&amp;',
        "'": '&#39;',
        '"': '&quot;',
      };
      return entities[char] || char;
    })
    .trim();
}

/**
 * Check if string is a valid Firestore document ID
 */
export function isValidDocumentId(id: string): boolean {
  return /^[a-zA-Z0-9_-]{1,1500}$/.test(id);
}

/**
 * Normalize search query for Firestore
 */
export function normalizeSearchQuery(query: string): string {
  return query.toLowerCase().trim();
}
