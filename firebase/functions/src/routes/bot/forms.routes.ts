/**
 * Bot Forms Routes
 * Endpoints for dynamic forms/checklists management via WhatsApp
 */

import { Router, Response } from 'express';
import Busboy from 'busboy';
import { AuthenticatedRequest } from '../../models/types';
import { requireLinked } from '../../middleware/auth.middleware';
import { getUserAggr } from '../../middleware/company.middleware';
import * as formsService from '../../services/forms.service';
import {
  validateInput,
  addFormToOrderSchema,
  saveFormItemResponseSchema,
  updateFormStatusSchema,
} from '../../utils/validation.utils';
const router: Router = Router();

// ============================================================================
// Form Templates
// ============================================================================

/**
 * GET /bot/forms/templates
 * List available form templates for the company
 */
router.get('/templates', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.userContext?.companyId;

    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    const templates = await formsService.listFormTemplates(companyId);

    res.json({
      success: true,
      data: {
        templates: templates.map((t) => ({
          id: t.id,
          title: t.title,
          description: t.description,
          itemCount: t.items?.length || 0,
          titleI18n: t.titleI18n,
          descriptionI18n: t.descriptionI18n,
        })),
        count: templates.length,

      },
    });
  } catch (error) {
    console.error('List form templates error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to list form templates' },
    });
  }
});

// ============================================================================
// Order Forms - List and Get
// ============================================================================

/**
 * GET /bot/orders/:number/forms
 * List all forms attached to an order
 */
router.get('/:number/forms', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.userContext?.companyId;

    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    const numberParam = Array.isArray(req.params.number) ? req.params.number[0] : req.params.number;
    const orderNumber = parseInt(numberParam, 10);

    if (isNaN(orderNumber)) {
      res.status(400).json({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: 'Invalid order number' },
      });
      return;
    }

    // Get order to verify it exists
    const order = await formsService.getOrderByNumber(companyId, orderNumber);
    if (!order) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: `Order #${orderNumber} not found` },
      });
      return;
    }

    const forms = await formsService.listOrderForms(companyId, order.id);

    // Format forms for bot display
    const formattedForms = forms.map((form) => {
      const progress = formsService.calculateFormProgress(form);
      return {
        id: form.id,
        title: form.title,
        status: form.status,
        statusEmoji: formsService.getStatusEmoji(form.status),
        statusLabel: formsService.formatFormStatus(form.status),
        progress,
        titleI18n: form.titleI18n,
      };
    });

    res.json({
      success: true,
      data: {
        forms: formattedForms,
        count: forms.length,
        orderNumber,

      },
    });
  } catch (error) {
    console.error('List order forms error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to list order forms' },
    });
  }
});

/**
 * GET /bot/orders/:number/forms/:formId
 * Get detailed form with items and responses
 */
router.get('/:number/forms/:formId', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.userContext?.companyId;

    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    const numberParam = Array.isArray(req.params.number) ? req.params.number[0] : req.params.number;
    const orderNumber = parseInt(numberParam, 10);
    const formIdParam = Array.isArray(req.params.formId) ? req.params.formId[0] : req.params.formId;

    if (isNaN(orderNumber)) {
      res.status(400).json({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: 'Invalid order number' },
      });
      return;
    }

    // Get order to verify it exists
    const order = await formsService.getOrderByNumber(companyId, orderNumber);
    if (!order) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: `Order #${orderNumber} not found` },
      });
      return;
    }

    const form = await formsService.getOrderForm(companyId, order.id, formIdParam);
    if (!form) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: `Form not found in order #${orderNumber}` },
      });
      return;
    }

    const progress = formsService.calculateFormProgress(form);
    const missingRequired = formsService.getMissingRequiredItems(form);

    // Build items with responses
    const items = form.items.map((item, index) => {
      const response = form.responses.find((r) => r.itemId === item.id);
      return {
        index: index + 1,
        id: item.id,
        label: item.label,
        type: item.type,
        options: item.options,
        required: item.required,
        allowPhotos: item.allowPhotos,
        labelI18n: item.labelI18n,
        optionsI18n: item.optionsI18n,
        response: response ? {
          value: response.value,
          photoUrls: response.photoUrls,
          photoCount: response.photoUrls.length,
        } : null,
        isFilled: !!response && (
          (response.value !== null && response.value !== undefined && response.value !== '') ||
          response.photoUrls.length > 0
        ),
      };
    });

    res.json({
      success: true,
      data: {
        id: form.id,
        title: form.title,
        status: form.status,
        statusLabel: formsService.formatFormStatus(form.status),
        progress,
        items,
        missingRequired: missingRequired.map((i) => ({
          id: i.id,
          label: i.label,
        })),
        titleI18n: form.titleI18n,
        orderNumber,

      },
    });
  } catch (error) {
    console.error('Get order form error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get form details' },
    });
  }
});

// ============================================================================
// Order Forms - Create
// ============================================================================

/**
 * POST /bot/orders/:number/forms
 * Add a form to an order from a template
 */
router.post('/:number/forms', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.userContext?.companyId;

    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    const createdBy = getUserAggr(req);

    const numberParam = Array.isArray(req.params.number) ? req.params.number[0] : req.params.number;
    const orderNumber = parseInt(numberParam, 10);

    if (isNaN(orderNumber)) {
      res.status(400).json({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: 'Invalid order number' },
      });
      return;
    }

    // Validate input
    const validation = validateInput(addFormToOrderSchema, req.body);
    if (!validation.success) {
      res.status(400).json({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: validation.errors.join(', ') },
      });
      return;
    }

    // Get order to verify it exists
    const order = await formsService.getOrderByNumber(companyId, orderNumber);
    if (!order) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: `Order #${orderNumber} not found` },
      });
      return;
    }

    const form = await formsService.addFormToOrder(
      companyId,
      order.id,
      validation.data.templateId,
      createdBy
    );

    res.json({
      success: true,
      data: {
        id: form.id,
        title: form.title,
        status: form.status,
        itemCount: form.items.length,
        orderNumber,

      },
    });
  } catch (error) {
    console.error('Add form to order error:', error);
    const errorMessage = error instanceof Error ? error.message : 'Failed to add form to order';
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: errorMessage },
    });
  }
});

// ============================================================================
// Form Items - Save Response
// ============================================================================

/**
 * POST /bot/orders/:number/forms/:formId/items/:itemId
 * Save a response to a form item
 */
router.post('/:number/forms/:formId/items/:itemId', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.userContext?.companyId;

    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    const updatedBy = getUserAggr(req);

    const numberParam = Array.isArray(req.params.number) ? req.params.number[0] : req.params.number;
    const orderNumber = parseInt(numberParam, 10);
    const formIdParam = Array.isArray(req.params.formId) ? req.params.formId[0] : req.params.formId;
    const itemIdParam = Array.isArray(req.params.itemId) ? req.params.itemId[0] : req.params.itemId;

    if (isNaN(orderNumber)) {
      res.status(400).json({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: 'Invalid order number' },
      });
      return;
    }

    // Validate input
    const validation = validateInput(saveFormItemResponseSchema, req.body);
    if (!validation.success) {
      res.status(400).json({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: validation.errors.join(', ') },
      });
      return;
    }

    // Get order to verify it exists
    const order = await formsService.getOrderByNumber(companyId, orderNumber);
    if (!order) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: `Order #${orderNumber} not found` },
      });
      return;
    }

    const updatedForm = await formsService.saveItemResponse(
      companyId,
      order.id,
      formIdParam,
      itemIdParam,
      validation.data.value,
      updatedBy
    );

    const progress = formsService.calculateFormProgress(updatedForm);

    res.json({
      success: true,
      data: {
        formId: updatedForm.id,
        itemId: itemIdParam,
        status: updatedForm.status,
        progress,

      },
    });
  } catch (error) {
    console.error('Save form item response error:', error);
    const errorMessage = error instanceof Error ? error.message : 'Failed to save response';
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: errorMessage },
    });
  }
});

// ============================================================================
// Form Items - Upload Photo
// ============================================================================

/**
 * POST /bot/orders/:number/forms/:formId/items/:itemId/photos
 * Upload a photo to a form item (multipart/form-data)
 */
router.post('/:number/forms/:formId/items/:itemId/photos', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  const companyId = req.userContext?.companyId;

  if (!companyId) {
    res.status(401).json({
      success: false,
      error: { code: 'UNAUTHORIZED', message: 'Company context required' },
    });
    return;
  }

  const createdBy = getUserAggr(req);

  const numberParam = Array.isArray(req.params.number) ? req.params.number[0] : req.params.number;
  const orderNumber = parseInt(numberParam, 10);
  const formIdParam = Array.isArray(req.params.formId) ? req.params.formId[0] : req.params.formId;
  const itemIdParam = Array.isArray(req.params.itemId) ? req.params.itemId[0] : req.params.itemId;

  if (isNaN(orderNumber)) {
    res.status(400).json({
      success: false,
      error: { code: 'VALIDATION_ERROR', message: 'Invalid order number' },
    });
    return;
  }

  // Get order to verify it exists
  const order = await formsService.getOrderByNumber(companyId, orderNumber);
  if (!order) {
    res.status(404).json({
      success: false,
      error: { code: 'NOT_FOUND', message: `Order #${orderNumber} not found` },
    });
    return;
  }

  // Parse multipart form
  const busboy = Busboy({
    headers: req.headers,
    limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit
  });

  let fileBuffer: Buffer | null = null;
  let filename = 'photo.jpg';
  let mimeType = 'image/jpeg';
  let uploadError: Error | null = null;

  busboy.on('file', (_fieldname, file, info) => {
    filename = info.filename || 'photo.jpg';
    mimeType = info.mimeType || 'image/jpeg';

    const chunks: Buffer[] = [];
    file.on('data', (chunk) => chunks.push(chunk));
    file.on('end', () => {
      fileBuffer = Buffer.concat(chunks);
    });
    file.on('error', (err) => {
      uploadError = err;
    });
  });

  busboy.on('finish', async () => {
    try {
      if (uploadError) {
        res.status(500).json({
          success: false,
          error: { code: 'UPLOAD_ERROR', message: 'Failed to process file upload' },
        });
        return;
      }

      if (!fileBuffer) {
        res.status(400).json({
          success: false,
          error: { code: 'VALIDATION_ERROR', message: 'No file uploaded' },
        });
        return;
      }

      // Validate MIME type
      const allowedTypes = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
      if (!allowedTypes.includes(mimeType)) {
        res.status(400).json({
          success: false,
          error: { code: 'VALIDATION_ERROR', message: 'Invalid file type. Allowed: jpeg, png, webp, gif' },
        });
        return;
      }

      const result = await formsService.uploadItemPhoto(
        companyId,
        order.id,
        formIdParam,
        itemIdParam,
        fileBuffer,
        filename,
        mimeType,
        createdBy
      );

      // Get updated form for progress
      const updatedForm = await formsService.getOrderForm(companyId, order.id, formIdParam);
      const progress = updatedForm ? formsService.calculateFormProgress(updatedForm) : null;

      // Get photo count for this item
      const itemResponse = updatedForm?.responses.find((r) => r.itemId === itemIdParam);
      const photoCount = itemResponse?.photoUrls.length || 1;

      res.json({
        success: true,
        data: {
          url: result.url,
          storagePath: result.storagePath,
          itemId: itemIdParam,
          photoCount,
          progress,
  
        },
      });
    } catch (error) {
      console.error('Upload form item photo error:', error);
      const errorMessage = error instanceof Error ? error.message : 'Failed to upload photo';
      res.status(500).json({
        success: false,
        error: { code: 'INTERNAL_ERROR', message: errorMessage },
      });
    }
  });

  busboy.on('error', (err) => {
    console.error('Busboy error:', err);
    res.status(500).json({
      success: false,
      error: { code: 'UPLOAD_ERROR', message: 'Failed to process multipart upload' },
    });
  });

  // Firebase Functions consumes body via express.json(), use rawBody instead
  const rawBody = (req as unknown as { rawBody?: Buffer }).rawBody;
  if (rawBody) {
    busboy.end(rawBody);
  } else {
    req.pipe(busboy);
  }
});

// ============================================================================
// Form Status
// ============================================================================

/**
 * PATCH /bot/orders/:number/forms/:formId/status
 * Update form status (complete, reset, etc.)
 */
router.patch('/:number/forms/:formId/status', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.userContext?.companyId;

    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    const updatedBy = getUserAggr(req);

    const numberParam = Array.isArray(req.params.number) ? req.params.number[0] : req.params.number;
    const orderNumber = parseInt(numberParam, 10);
    const formIdParam = Array.isArray(req.params.formId) ? req.params.formId[0] : req.params.formId;

    if (isNaN(orderNumber)) {
      res.status(400).json({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: 'Invalid order number' },
      });
      return;
    }

    // Validate input
    const validation = validateInput(updateFormStatusSchema, req.body);
    if (!validation.success) {
      res.status(400).json({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: validation.errors.join(', ') },
      });
      return;
    }

    // Get order to verify it exists
    const order = await formsService.getOrderByNumber(companyId, orderNumber);
    if (!order) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: `Order #${orderNumber} not found` },
      });
      return;
    }

    const updatedForm = await formsService.updateFormStatus(
      companyId,
      order.id,
      formIdParam,
      validation.data.status,
      updatedBy
    );

    const statusLabel = formsService.formatFormStatus(updatedForm.status);
    const statusEmoji = formsService.getStatusEmoji(updatedForm.status);

    res.json({
      success: true,
      data: {
        formId: updatedForm.id,
        title: updatedForm.title,
        status: updatedForm.status,
        statusLabel,
        statusEmoji,

      },
    });
  } catch (error) {
    console.error('Update form status error:', error);
    const errorMessage = error instanceof Error ? error.message : 'Failed to update form status';
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: errorMessage },
    });
  }
});

export default router;
