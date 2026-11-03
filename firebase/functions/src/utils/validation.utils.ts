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

/** ISO date-time with zone (what GET returns in `updatedAt`, `dueDate`...). */
const isoDateTime = z.string().datetime({ offset: true });

/** The `version` the server gave (order-version.ts), sent back as is; an ISO instant with a zone still works. */
export const orderVersionSchema = z.string().min(1).max(64);
/** Money sent by a client: never negative, cents. */
const moneySchema = z.number().min(0).max(1_000_000_000);
/** The app decodes quantity as an int: a fraction would break old versions. */
const quantitySchema = z.number().int().min(1).max(100_000);
const ORDER_STATUSES = ['quote', 'approved', 'progress', 'done', 'canceled'] as const;
export const paymentMethodSchema = z.enum(['pix', 'cash', 'card', 'other']);

export const receiptFileSchema = z.object({
  url: z.string().url().max(2048),
  storagePath: z.string().max(512),
  fileName: z.string().max(256).optional(),
  contentType: z.string().max(100),
});

/**
 * Client-generated transaction id (a uuid): letters, digits and dashes, so it
 * never looks like an Asaas (`asaas_…`), legacy or receipt share id.
 */
const clientTransactionIdSchema = z.string().regex(/^[A-Za-z0-9-]{8,64}$/, 'Invalid clientTransactionId');

/** Client-generated order id (a uuid), same format as clientTransactionId. */
const clientOrderIdSchema = z.string().regex(/^[A-Za-z0-9-]{8,64}$/, 'Invalid clientOrderId');

export const createOrderSchema = z.object({
  clientOrderId: clientOrderIdSchema.optional(),
  customerId: idSchema,
  deviceId: idSchema.optional(),
  deviceIds: z.array(idSchema).max(50).optional(),
  services: z.array(z.object({
    serviceId: idSchema,
    value: moneySchema.nullable().optional(),
    description: z.string().max(500).optional(),
  })).max(200).optional(),
  products: z.array(z.object({
    productId: idSchema,
    quantity: quantitySchema,
    value: moneySchema.nullable().optional(),
    total: moneySchema.nullable().optional(),
    description: z.string().max(500).optional(),
  })).max(200).optional(),
  dueDate: z.string().datetime().optional(),
  scheduledDate: z.string().datetime().optional(),
  status: z.enum(ORDER_STATUSES).default('quote'),
});

/** PATCH /:id. null clears a date or the assignee. */
export const updateOrderSchema = z.object({
  status: z.enum(ORDER_STATUSES).optional(),
  dueDate: isoDateTime.nullable().optional(),
  scheduledDate: isoDateTime.nullable().optional(),
  assignedTo: idSchema.nullable().optional(),
  expectedUpdatedAt: orderVersionSchema.optional(),
});

export const addOrderServiceSchema = z.object({
  serviceId: idSchema,
  value: moneySchema.nullable().optional(),
  description: z.string().max(500).optional(),
  deviceId: idSchema.optional(),
});

export const addOrderProductSchema = z.object({
  productId: idSchema,
  quantity: quantitySchema,
  value: moneySchema.nullable().optional(),
  total: moneySchema.nullable().optional(),
  description: z.string().max(500).optional(),
  deviceId: idSchema.optional(),
});

/** POST /:id/items: a service or product from the catalog, or without catalog (description required). */
export const addOrderItemSchema = z.object({
  kind: z.enum(['service', 'product']),
  /** Absent: an item without catalog, which needs a description. */
  catalogId: idSchema.optional(),
  description: z.string().max(500).optional(),
  value: moneySchema.nullable().optional(),
  quantity: quantitySchema.optional(),
  total: moneySchema.nullable().optional(),
  deviceId: idSchema.nullable().optional(),
  expectedUpdatedAt: orderVersionSchema.optional(),
}).refine((item) => item.kind === 'product' || (item.quantity === undefined && item.total === undefined), {
  message: 'A service has no quantity or line total',
  path: ['kind'],
}).refine((item) => item.catalogId !== undefined || !!item.description?.trim(), {
  message: 'An item without catalogId needs a description',
  path: ['description'],
});

/** PATCH /:id/items/:itemId: only what changes. */
export const updateOrderItemSchema = z.object({
  description: z.string().max(500).optional(),
  value: moneySchema.nullable().optional(),
  quantity: quantitySchema.optional(),
  total: moneySchema.nullable().optional(),
  deviceId: idSchema.nullable().optional(),
  expectedUpdatedAt: orderVersionSchema.optional(),
}).refine((patch) => ['description', 'value', 'quantity', 'total', 'deviceId'].some((key) => key in patch), {
  message: 'Nothing to change',
});

/** POST /:id/payments: money received. A discount has its own route. */
export const receivePaymentSchema = z.object({
  clientTransactionId: clientTransactionIdSchema.optional(),
  /** Refuses a payment over a newer version (409 ORDER_CHANGED), unless it repeats clientTransactionId. */
  expectedUpdatedAt: orderVersionSchema.optional(),
  amount: z.number().min(0.01, 'Amount must be greater than 0').max(1_000_000_000),
  description: z.string().max(500).optional(),
  type: z.literal('payment').optional(),
  paidAt: z.string().min(10).max(40).optional(),
  paymentMethod: paymentMethodSchema.optional(),
  receiptFile: receiptFileSchema.optional(),
});

/** POST /:id/discounts */
export const discountSchema = z.object({
  clientTransactionId: clientTransactionIdSchema.optional(),
  expectedUpdatedAt: orderVersionSchema.optional(),
  amount: z.number().min(0.01, 'Amount must be greater than 0').max(1_000_000_000),
  description: z.string().max(500).optional(),
});

/** POST /:id/payments/mark-paid */
export const markPaidSchema = z.object({
  description: z.string().max(500).optional(),
  paidAt: z.string().min(10).max(40).optional(),
  paymentMethod: paymentMethodSchema.optional(),
});

/** POST /:id/hold */
export const orderHoldSchema = z.object({
  reason: z.enum(['part', 'customer', 'authorization', 'other']),
  note: z.string().max(500).optional(),
});

/** GET /orders query string. */
export const listOrdersQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).max(10_000).optional(),
  cursor: z.string().regex(/^[A-Za-z0-9_-]{1,128}$/).optional(),
  status: z.string().max(200).optional()
    .transform((value) => (value ? value.split(',').map((s) => s.trim()).filter(Boolean) : undefined))
    .pipe(z.array(z.enum(ORDER_STATUSES)).min(1).max(5).optional()),
  sort: z.enum(['createdAt', 'updatedAt', 'dueDate', 'scheduledDate', 'number']).default('createdAt'),
  direction: z.enum(['asc', 'desc']).optional(),
  customerId: idSchema.optional(),
  deviceId: idSchema.optional(),
  assignedTo: idSchema.optional(),
  /** One order by its number (search); the other filters are ignored. */
  number: z.coerce.number().int().min(1).max(1_000_000_000).optional(),
  startDate: z.string().datetime({ offset: true }).optional(),
  endDate: z.string().datetime({ offset: true }).optional(),
}).refine((q) => q.sort === 'createdAt' || (!q.startDate && !q.endDate), {
  message: 'startDate/endDate filter createdAt: sort by createdAt',
  path: ['sort'],
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
  email: z.string().email().optional(),
  phone: z.string().min(1).max(50).optional(),
}).refine((data) => data.email || data.phone, {
  message: 'Either email or phone is required',
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
  // Existing order ID: if provided, update instead of create (upsert)
  id: idSchema.optional(),

  // Customer: ID required
  customerId: idSchema,

  // Device: optional but only by ID
  deviceId: idSchema.optional(),

  // Multiple devices: optional array of device IDs
  deviceIds: z.array(idSchema).optional(),

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
  scheduledDate: z.string().optional(),
  status: z.enum(['quote', 'approved', 'progress']).default('quote'),
});

/**
 * Schema for updating an order via bot (generic PATCH)
 * All fields optional, but at least one must be provided
 */
export const updateBotOrderSchema = z.object({
  status: z.enum(['quote', 'approved', 'progress', 'done', 'canceled']).optional(),
  dueDate: z.string().optional().nullable(),
  scheduledDate: z.string().optional().nullable(),
  assignedTo: idSchema.optional().nullable(),
}).refine(data => Object.values(data).some(v => v !== undefined), {
  message: 'At least one field must be provided',
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
  deviceId: idSchema.optional(),
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
  deviceId: idSchema.optional(),
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

/**
 * Schema for adding a device to an existing order
 * REQUIRES existing device ID
 */
export const addDeviceToOrderSchema = z.object({
  deviceId: idSchema,
});

// ============================================================================
// Photo Upload Schema
// ============================================================================

/**
 * Schema for uploading photo from base64 (legacy)
 */
export const uploadPhotoBase64Schema = z.object({
  base64: z.string().min(1, 'Base64 data is required'),
  filename: z.string().min(1, 'Filename is required').max(255),
  description: z.string().max(500).optional(),
});

/**
 * Schema for uploading photo from base64 or URL
 */
export const uploadPhotoSchema = z
  .object({
    base64: z.string().min(1).optional(),
    url: z.string().url('Invalid URL format').optional(),
    filename: z.string().max(255).optional(),
    mimeType: z.string().optional(),
    description: z.string().max(500).optional(),
  })
  .refine((data) => Boolean(data.base64 || data.url), {
    message: 'Either base64 or url must be provided',
  });

// ============================================================================
// Form/Checklist Schemas
// ============================================================================

/**
 * Schema for adding a form to an order
 */
export const addFormToOrderSchema = z.object({
  templateId: idSchema,
  deviceId: idSchema.optional(),
});

/**
 * Schema for saving a form item response
 */
export const saveFormItemResponseSchema = z.object({
  value: z.unknown(),
});

/**
 * Schema for updating form status
 */
export const updateFormStatusSchema = z.object({
  status: z.enum(['pending', 'in_progress', 'completed']),
});

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Validate and parse input with Zod schema
 */
export function validateInput<T>(
  schema: z.ZodType<T, z.ZodTypeDef, unknown>,
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
