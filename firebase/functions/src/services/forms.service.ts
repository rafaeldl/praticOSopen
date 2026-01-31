/**
 * Forms Service
 * Business logic for dynamic forms/checklists in orders
 */

import {
  db,
  getTenantCollection,
  getDocument,
  storage,
} from './firestore.service';
import {
  FormDefinition,
  FormItemDefinition,
  OrderForm,
  FormResponse,
  FormStatus,
  UserAggr,
  Order,
} from '../models/types';
import * as orderService from './order.service';

// ============================================================================
// Form Templates
// ============================================================================

/**
 * List form templates for a company
 */
export async function listFormTemplates(
  companyId: string,
  options: { activeOnly?: boolean } = {}
): Promise<FormDefinition[]> {
  const { activeOnly = true } = options;

  const formsCollection = getTenantCollection(companyId, 'forms');
  const snapshot = await formsCollection.get();

  let templates = snapshot.docs.map((doc) => ({
    ...doc.data(),
    id: doc.id,
  })) as FormDefinition[];

  // Filter active only in memory (avoids needing composite index)
  if (activeOnly) {
    templates = templates.filter((t) => t.isActive !== false);
  }

  // Sort by title
  templates.sort((a, b) => (a.title || '').localeCompare(b.title || ''));

  return templates;
}

/**
 * Get a form template by ID
 */
export async function getFormTemplate(
  companyId: string,
  templateId: string
): Promise<FormDefinition | null> {
  const formsCollection = getTenantCollection(companyId, 'forms');
  return getDocument<FormDefinition>(formsCollection, templateId);
}

// ============================================================================
// Order Forms
// ============================================================================

/**
 * List forms attached to an order
 */
export async function listOrderForms(
  companyId: string,
  orderId: string
): Promise<OrderForm[]> {
  const formsCollection = db
    .collection('companies')
    .doc(companyId)
    .collection('orders')
    .doc(orderId)
    .collection('forms');

  const snapshot = await formsCollection.orderBy('title', 'asc').get();

  return snapshot.docs.map((doc) => ({
    ...doc.data(),
    id: doc.id,
  })) as OrderForm[];
}

/**
 * Get a specific form from an order
 */
export async function getOrderForm(
  companyId: string,
  orderId: string,
  formId: string
): Promise<OrderForm | null> {
  const formRef = db
    .collection('companies')
    .doc(companyId)
    .collection('orders')
    .doc(orderId)
    .collection('forms')
    .doc(formId);

  const doc = await formRef.get();
  if (!doc.exists) return null;

  return { ...doc.data(), id: doc.id } as OrderForm;
}

/**
 * Add a form to an order from a template
 */
export async function addFormToOrder(
  companyId: string,
  orderId: string,
  templateId: string,
  createdBy: UserAggr
): Promise<OrderForm> {
  // Get the template
  const template = await getFormTemplate(companyId, templateId);
  if (!template) {
    throw new Error(`Form template ${templateId} not found`);
  }

  // Create the form instance (only include defined fields)
  const formData: Record<string, unknown> = {
    formDefinitionId: templateId,
    title: template.title,
    status: 'pending' as FormStatus,
    items: template.items || [],
    responses: [],
    updatedAt: new Date().toISOString(),
  };

  // Only add optional fields if they exist
  if (template.titleI18n) {
    formData.titleI18n = template.titleI18n;
  }

  const formsCollection = db
    .collection('companies')
    .doc(companyId)
    .collection('orders')
    .doc(orderId)
    .collection('forms');

  const docRef = await formsCollection.add({
    ...formData,
    createdAt: new Date().toISOString(),
    createdBy: {
      id: createdBy.id,
      name: createdBy.name,
    },
  });

  return {
    id: docRef.id,
    formDefinitionId: templateId,
    title: template.title,
    status: 'pending' as FormStatus,
    items: template.items || [],
    responses: [],
    titleI18n: template.titleI18n,
  } as OrderForm;
}

/**
 * Save a response to a form item
 */
export async function saveItemResponse(
  companyId: string,
  orderId: string,
  formId: string,
  itemId: string,
  value: unknown,
  updatedBy: UserAggr
): Promise<OrderForm> {
  const form = await getOrderForm(companyId, orderId, formId);
  if (!form) {
    throw new Error(`Form ${formId} not found in order`);
  }

  // Validate item exists
  const item = form.items.find((i) => i.id === itemId);
  if (!item) {
    throw new Error(`Item ${itemId} not found in form`);
  }

  // Validate value type
  const validatedValue = validateItemValue(item, value);

  // Update or add response
  const existingIndex = form.responses.findIndex((r) => r.itemId === itemId);
  const existingResponse = existingIndex >= 0 ? form.responses[existingIndex] : null;

  const newResponse: FormResponse = {
    itemId,
    value: validatedValue,
    photoUrls: existingResponse?.photoUrls || [],
  };

  let updatedResponses: FormResponse[];
  if (existingIndex >= 0) {
    updatedResponses = [...form.responses];
    updatedResponses[existingIndex] = newResponse;
  } else {
    updatedResponses = [...form.responses, newResponse];
  }

  // Determine new status
  let newStatus: FormStatus = form.status;
  if (form.status === 'pending') {
    newStatus = 'in_progress';
  }

  const formRef = db
    .collection('companies')
    .doc(companyId)
    .collection('orders')
    .doc(orderId)
    .collection('forms')
    .doc(formId);

  const updateData: Partial<OrderForm> & { updatedBy: UserAggr } = {
    responses: updatedResponses,
    status: newStatus,
    updatedAt: new Date().toISOString(),
    updatedBy: {
      id: updatedBy.id,
      name: updatedBy.name,
    },
  };

  if (form.status === 'pending') {
    (updateData as Record<string, unknown>).startedAt = new Date().toISOString();
  }

  await formRef.update(updateData);

  return {
    ...form,
    responses: updatedResponses,
    status: newStatus,
  };
}

/**
 * Upload a photo to a form item
 */
export async function uploadItemPhoto(
  companyId: string,
  orderId: string,
  formId: string,
  itemId: string,
  buffer: Buffer,
  filename: string,
  mimeType: string,
  createdBy: UserAggr
): Promise<{ url: string; storagePath: string }> {
  const form = await getOrderForm(companyId, orderId, formId);
  if (!form) {
    throw new Error(`Form ${formId} not found in order`);
  }

  // Validate item exists and allows photos
  const item = form.items.find((i) => i.id === itemId);
  if (!item) {
    throw new Error(`Item ${itemId} not found in form`);
  }
  if (!item.allowPhotos && item.type !== 'photo_only') {
    throw new Error(`Item ${itemId} does not allow photos`);
  }

  // Generate photo ID
  const timestamp = Date.now();
  const extension = getExtensionFromMimeType(mimeType);
  const photoId = `${itemId}_${timestamp}`;
  const storagePath = `tenants/${companyId}/orders/${orderId}/forms/${formId}/${photoId}.${extension}`;

  // Upload to Storage
  const bucket = storage.bucket();
  const file = bucket.file(storagePath);

  await file.save(buffer, {
    contentType: mimeType,
    metadata: {
      metadata: {
        uploadedBy: createdBy.id,
        orderId,
        formId,
        itemId,
      },
    },
  });

  await file.makePublic();

  const url = `https://storage.googleapis.com/${bucket.name}/${storagePath}`;

  // Update form response with new photo
  const existingIndex = form.responses.findIndex((r) => r.itemId === itemId);
  const existingResponse = existingIndex >= 0 ? form.responses[existingIndex] : null;

  const newResponse: FormResponse = {
    itemId,
    value: existingResponse?.value ?? null,
    photoUrls: [...(existingResponse?.photoUrls || []), url],
  };

  let updatedResponses: FormResponse[];
  if (existingIndex >= 0) {
    updatedResponses = [...form.responses];
    updatedResponses[existingIndex] = newResponse;
  } else {
    updatedResponses = [...form.responses, newResponse];
  }

  // Update status if pending
  let newStatus: FormStatus = form.status;
  if (form.status === 'pending') {
    newStatus = 'in_progress';
  }

  const formRef = db
    .collection('companies')
    .doc(companyId)
    .collection('orders')
    .doc(orderId)
    .collection('forms')
    .doc(formId);

  const updateData: Partial<OrderForm> & { updatedBy: UserAggr } = {
    responses: updatedResponses,
    status: newStatus,
    updatedAt: new Date().toISOString(),
    updatedBy: {
      id: createdBy.id,
      name: createdBy.name,
    },
  };

  if (form.status === 'pending') {
    (updateData as Record<string, unknown>).startedAt = new Date().toISOString();
  }

  await formRef.update(updateData);

  return { url, storagePath };
}

/**
 * Update form status
 */
export async function updateFormStatus(
  companyId: string,
  orderId: string,
  formId: string,
  status: FormStatus,
  updatedBy: UserAggr
): Promise<OrderForm> {
  const form = await getOrderForm(companyId, orderId, formId);
  if (!form) {
    throw new Error(`Form ${formId} not found in order`);
  }

  // Validate status transition
  if (status === 'completed') {
    // Check all required items have responses
    const missingRequired = getMissingRequiredItems(form);
    if (missingRequired.length > 0) {
      const missingLabels = missingRequired.map((i) => i.label).join(', ');
      throw new Error(`Cannot complete form. Missing required items: ${missingLabels}`);
    }
  }

  const formRef = db
    .collection('companies')
    .doc(companyId)
    .collection('orders')
    .doc(orderId)
    .collection('forms')
    .doc(formId);

  const updateData: Partial<OrderForm> & { updatedBy: UserAggr } = {
    status,
    updatedAt: new Date().toISOString(),
    updatedBy: {
      id: updatedBy.id,
      name: updatedBy.name,
    },
  };

  if (status === 'completed') {
    (updateData as Record<string, unknown>).completedAt = new Date().toISOString();
  }

  await formRef.update(updateData);

  return {
    ...form,
    status,
  };
}

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Get order by number (wrapper for order service)
 */
export async function getOrderByNumber(
  companyId: string,
  orderNumber: number
): Promise<Order | null> {
  return orderService.getOrderByNumber(companyId, orderNumber);
}

/**
 * Calculate form progress
 */
export function calculateFormProgress(form: OrderForm): { filled: number; total: number; percentage: number } {
  const total = form.items.length;
  const filled = form.responses.filter((r) => {
    // A response is considered filled if it has a value or photos
    return r.value !== null && r.value !== undefined && r.value !== '' || r.photoUrls.length > 0;
  }).length;
  const percentage = total > 0 ? Math.round((filled / total) * 100) : 0;

  return { filled, total, percentage };
}

/**
 * Get missing required items
 */
export function getMissingRequiredItems(form: OrderForm): FormItemDefinition[] {
  return form.items.filter((item) => {
    if (!item.required) return false;

    const response = form.responses.find((r) => r.itemId === item.id);
    if (!response) return true;

    // photo_only requires at least one photo
    if (item.type === 'photo_only') {
      return response.photoUrls.length === 0;
    }

    // Other types require a value
    return response.value === null || response.value === undefined || response.value === '';
  });
}

/**
 * Validate item value based on type
 */
function validateItemValue(item: FormItemDefinition, value: unknown): unknown {
  switch (item.type) {
    case 'text':
      if (value !== null && typeof value !== 'string') {
        throw new Error(`Item ${item.id} requires a text value`);
      }
      return value;

    case 'number':
      if (value !== null) {
        const num = typeof value === 'string' ? parseFloat(value) : value;
        if (typeof num !== 'number' || isNaN(num)) {
          throw new Error(`Item ${item.id} requires a numeric value`);
        }
        return num;
      }
      return value;

    case 'boolean':
      if (value !== null) {
        // Accept various boolean representations
        if (typeof value === 'boolean') return value;
        if (typeof value === 'string') {
          const lower = value.toLowerCase();
          if (['true', 'yes', 'sim', 's', '1'].includes(lower)) return true;
          if (['false', 'no', 'nao', 'não', 'n', '0'].includes(lower)) return false;
        }
        if (typeof value === 'number') return value !== 0;
        throw new Error(`Item ${item.id} requires a boolean value (sim/nao, true/false)`);
      }
      return value;

    case 'select':
      if (value !== null && item.options) {
        // Accept index (1-based for user convenience) or exact option
        if (typeof value === 'number') {
          const index = value - 1;
          if (index >= 0 && index < item.options.length) {
            return item.options[index];
          }
          throw new Error(`Invalid option index. Choose 1-${item.options.length}`);
        }
        if (typeof value === 'string') {
          // Check if it's a number string
          const parsed = parseInt(value, 10);
          if (!isNaN(parsed) && parsed >= 1 && parsed <= item.options.length) {
            return item.options[parsed - 1];
          }
          // Check if it's an exact match
          if (item.options.includes(value)) {
            return value;
          }
          // Check case-insensitive match
          const lower = value.toLowerCase();
          const match = item.options.find((o) => o.toLowerCase() === lower);
          if (match) return match;

          throw new Error(`Invalid option. Choose from: ${item.options.join(', ')}`);
        }
      }
      return value;

    case 'checklist':
      if (value !== null && item.options) {
        // Accept array of indices (1-based), comma-separated string, or array of values
        let selections: unknown[] = [];

        if (Array.isArray(value)) {
          selections = value;
        } else if (typeof value === 'string') {
          // Parse comma-separated values
          selections = value.split(',').map((s) => s.trim());
        } else if (typeof value === 'number') {
          selections = [value];
        }

        const validSelections: string[] = [];
        for (const sel of selections) {
          if (typeof sel === 'number') {
            const index = sel - 1;
            if (index >= 0 && index < item.options.length) {
              validSelections.push(item.options[index]);
            }
          } else if (typeof sel === 'string') {
            const parsed = parseInt(sel, 10);
            if (!isNaN(parsed) && parsed >= 1 && parsed <= item.options.length) {
              validSelections.push(item.options[parsed - 1]);
            } else if (item.options.includes(sel)) {
              validSelections.push(sel);
            } else {
              const lower = sel.toLowerCase();
              const match = item.options.find((o) => o.toLowerCase() === lower);
              if (match) validSelections.push(match);
            }
          }
        }

        return validSelections;
      }
      return value;

    case 'photo_only':
      // photo_only items don't require a value, only photos
      return null;

    default:
      return value;
  }
}

/**
 * Get file extension from MIME type
 */
function getExtensionFromMimeType(mimeType: string): string {
  const extensions: Record<string, string> = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
    'image/gif': 'gif',
  };
  return extensions[mimeType] || 'jpg';
}

/**
 * Format status for display
 */
export function formatFormStatus(status: FormStatus): string {
  const statusMap: Record<FormStatus, string> = {
    pending: 'Pendente',
    in_progress: 'Em andamento',
    completed: 'Concluído',
  };
  return statusMap[status] || status;
}

/**
 * Get status emoji
 */
export function getStatusEmoji(status: FormStatus): string {
  const emojiMap: Record<FormStatus, string> = {
    pending: '⏳',
    in_progress: '🔄',
    completed: '✅',
  };
  return emojiMap[status] || '📋';
}
