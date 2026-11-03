/**
 * Order photos for the web (app and web). Mounted with the other order
 * routers at /v1/app/orders. Counts against the plan's photos per month
 * (docs/PLAN_LIMITS_SERVER.md).
 */

import { Router, Response } from 'express';
import { AuthenticatedRequest, OrderPhoto } from '../../models/types';
import { getUserAggr } from '../../middleware/company.middleware';
import { requireAppPermission, requireOrderAccess } from '../../middleware/app-permission.middleware';
import { requirePlanCapacity } from '../../middleware/plan-limit.middleware';
import * as orderService from '../../services/order.service';
import * as photoService from '../../services/photo-upload.service';
import { uploadPhotoSchema, validateInput } from '../../utils/validation.utils';

const router: Router = Router();

/**
 * POST /v1/app/orders/:id/photos
 * Body: { base64 | url, filename?, mimeType?, description? }
 */
router.post(
  '/:id/photos',
  requireAppPermission('attachPhotos'),
  requireOrderAccess(),
  requirePlanCapacity('photo'),
  async (req: AuthenticatedRequest, res: Response) => {
    const companyId = req.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Company context required' } });
      return;
    }
    const validation = validateInput(uploadPhotoSchema, req.body);
    if (!validation.success) {
      res.status(400).json({ success: false, error: { code: 'VALIDATION_ERROR', message: validation.errors.join(', ') } });
      return;
    }
    try {
      const orderId = String(req.params.id);
      const order = await orderService.getOrder(companyId, orderId);
      if (!order) {
        res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Order not found' } });
        return;
      }
      const createdBy = getUserAggr(req);
      const { base64, url, filename, mimeType, description } = validation.data;
      const photo: OrderPhoto = url
        ? await photoService.uploadPhotoFromUrl(companyId, orderId, { url, filename, mimeType, description }, createdBy)
        : await photoService.uploadPhotoFromBase64(
            companyId,
            orderId,
            { base64: base64 as string, filename: filename || 'photo.jpg', description },
            createdBy,
          );
      await orderService.addPhotoToOrder(companyId, orderId, photo);
      res.status(201).json({ success: true, data: { photo } });
    } catch (error) {
      console.error('Upload order photo error:', error instanceof Error ? error.message : 'unknown');
      res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: 'Failed to upload photo' } });
    }
  },
);

export default router;
