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

export const createProductSchema = z.object({
  name: z.string().min(1, 'Name is required').max(200),
  value: z.number().min(0),
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

export const quickOrderSchema = z.object({
  customerName: z.string().min(1, 'Customer name is required').max(200),
  customerPhone: z.string().optional(),
  deviceName: z.string().min(1, 'Device name is required').max(200),
  deviceSerial: z.string().max(100).optional(),
  problem: z.string().min(1, 'Problem description is required').max(1000),
  estimatedValue: z.number().min(0).optional(),
  dueDate: z.string().datetime().optional(),
});

export const searchQuerySchema = z.object({
  q: z.string().min(1, 'Search query is required').max(100),
});

// ============================================================================
// Bot Order Management Schemas
// ============================================================================

/**
 * Schema for creating a complete order via bot
 * Allows referencing existing entities by ID or creating new ones by name
 */
export const createFullOrderSchema = z.object({
  // Customer: either ID or name (will create/find)
  customerId: idSchema.optional(),
  customerName: z.string().min(1).max(200).optional(),
  customerPhone: z.string().optional(),

  // Device: either ID or name (will create/find)
  deviceId: idSchema.optional(),
  deviceName: z.string().max(200).optional(),
  deviceSerial: z.string().max(100).optional(),

  // Services: either by ID or by name (will create/find)
  services: z.array(z.object({
    serviceId: idSchema.optional(),
    serviceName: z.string().max(200).optional(),
    value: z.number().min(0),
    description: z.string().max(500).optional(),
  }).refine(
    data => data.serviceId || data.serviceName,
    { message: 'Either serviceId or serviceName is required for each service' }
  )).optional(),

  // Products: either by ID or by name (will create/find)
  products: z.array(z.object({
    productId: idSchema.optional(),
    productName: z.string().max(200).optional(),
    value: z.number().min(0),
    quantity: z.number().min(1).default(1),
    description: z.string().max(500).optional(),
  }).refine(
    data => data.productId || data.productName,
    { message: 'Either productId or productName is required for each product' }
  )).optional(),

  dueDate: z.string().optional(),
  status: z.enum(['quote', 'approved', 'progress']).default('quote'),
}).refine(
  data => data.customerId || data.customerName,
  { message: 'Either customerId or customerName is required' }
);

/**
 * Schema for adding a service to an existing order
 */
export const addServiceToOrderSchema = z.object({
  serviceId: idSchema.optional(),
  serviceName: z.string().max(200).optional(),
  value: z.number().min(0),
  description: z.string().max(500).optional(),
}).refine(
  data => data.serviceId || data.serviceName,
  { message: 'Either serviceId or serviceName is required' }
);

/**
 * Schema for adding a product to an existing order
 */
export const addProductToOrderSchema = z.object({
  productId: idSchema.optional(),
  productName: z.string().max(200).optional(),
  value: z.number().min(0),
  quantity: z.number().min(1).default(1),
  description: z.string().max(500).optional(),
}).refine(
  data => data.productId || data.productName,
  { message: 'Either productId or productName is required' }
);

/**
 * Schema for updating order device
 */
export const updateOrderDeviceSchema = z.object({
  deviceId: idSchema.optional(),
  deviceName: z.string().max(200).optional(),
  deviceSerial: z.string().max(100).optional(),
}).refine(
  data => data.deviceId || data.deviceName,
  { message: 'Either deviceId or deviceName is required' }
);

/**
 * Schema for updating order customer
 */
export const updateOrderCustomerSchema = z.object({
  customerId: idSchema.optional(),
  customerName: z.string().max(200).optional(),
  customerPhone: z.string().optional(),
}).refine(
  data => data.customerId || data.customerName,
  { message: 'Either customerId or customerName is required' }
);

// ============================================================================
// Photo Upload Schemas
// ============================================================================

/**
 * Schema for uploading photo from URL
 */
export const uploadPhotoUrlSchema = z.object({
  url: z.string().url('Invalid URL format'),
  description: z.string().max(500).optional(),
});

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
