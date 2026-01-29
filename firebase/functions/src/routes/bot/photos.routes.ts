/**
 * Bot Photos Routes
 * Photo upload and management endpoints for orders
 */

import { Router, Response } from 'express';
import { AuthenticatedRequest } from '../../models/types';
import { requireLinked } from '../../middleware/auth.middleware';
import { getUserAggr } from '../../middleware/company.middleware';
import * as orderService from '../../services/order.service';
import * as photoService from '../../services/photo-upload.service';
import { validateInput, uploadPhotoUrlSchema, uploadPhotoBase64Schema } from '../../utils/validation.utils';
import { formatPhotoAdded, formatPhotosList, formatPhotoDeleted } from '../../utils/format.utils';

const router: Router = Router();

/**
 * POST /bot/orders/:number/photos
 * Upload photo to order (from URL or base64)
 */
router.post('/:number/photos', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
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

    // Get order first to verify it exists
    const order = await orderService.getOrderByNumber(companyId, orderNumber);
    if (!order) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: `Order #${orderNumber} not found` },
      });
      return;
    }

    let photo;

    // Determine if URL or base64 upload
    if (req.body.url) {
      // URL upload
      const validation = validateInput(uploadPhotoUrlSchema, req.body);
      if (!validation.success) {
        res.status(400).json({
          success: false,
          error: { code: 'VALIDATION_ERROR', message: validation.errors.join(', ') },
        });
        return;
      }

      photo = await photoService.uploadPhotoFromUrl(
        companyId,
        order.id,
        { url: validation.data.url, description: validation.data.description },
        createdBy
      );
    } else if (req.body.base64) {
      // Base64 upload
      const validation = validateInput(uploadPhotoBase64Schema, req.body);
      if (!validation.success) {
        res.status(400).json({
          success: false,
          error: { code: 'VALIDATION_ERROR', message: validation.errors.join(', ') },
        });
        return;
      }

      photo = await photoService.uploadPhotoFromBase64(
        companyId,
        order.id,
        {
          base64: validation.data.base64,
          filename: validation.data.filename,
          description: validation.data.description,
        },
        createdBy
      );
    } else {
      res.status(400).json({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: 'Either url or base64 is required' },
      });
      return;
    }

    // Add photo to order
    await orderService.addPhotoToOrder(companyId, order.id, photo);

    // Get updated order for photo count
    const updatedOrder = await orderService.getOrderByNumber(companyId, orderNumber);
    const photoCount = updatedOrder?.photos?.length || 1;

    res.json({
      success: true,
      data: {
        photoId: photo.id,
        url: photo.url,
        storagePath: photo.storagePath,
        message: formatPhotoAdded(orderNumber, photoCount),
      },
    });
  } catch (error) {
    console.error('Upload photo error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to upload photo' },
    });
  }
});

/**
 * GET /bot/orders/:number/photos
 * List photos of an order
 */
router.get('/:number/photos', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
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

    const order = await orderService.getOrderByNumber(companyId, orderNumber);
    if (!order) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: `Order #${orderNumber} not found` },
      });
      return;
    }

    const photos = order.photos || [];

    res.json({
      success: true,
      data: {
        photos: photos.map((p) => ({
          id: p.id,
          url: p.url,
          createdAt: p.createdAt,
          createdBy: p.createdBy?.name || 'Unknown',
        })),
        count: photos.length,
        message: formatPhotosList(orderNumber, photos),
      },
    });
  } catch (error) {
    console.error('List photos error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to list photos' },
    });
  }
});

/**
 * DELETE /bot/orders/:number/photos/:photoId
 * Delete a photo from order
 */
router.delete('/:number/photos/:photoId', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
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
    const photoIdParam = Array.isArray(req.params.photoId) ? req.params.photoId[0] : req.params.photoId;

    if (isNaN(orderNumber)) {
      res.status(400).json({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: 'Invalid order number' },
      });
      return;
    }

    const order = await orderService.getOrderByNumber(companyId, orderNumber);
    if (!order) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: `Order #${orderNumber} not found` },
      });
      return;
    }

    const photos = order.photos || [];
    const photoIndex = photos.findIndex((p) => p.id === photoIdParam);

    if (photoIndex === -1) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: `Photo not found in order #${orderNumber}` },
      });
      return;
    }

    const photoToDelete = photos[photoIndex];

    // Delete from storage
    if (photoToDelete.storagePath) {
      await photoService.deletePhoto(photoToDelete.storagePath);
    }

    // Remove from order
    await orderService.removePhotoFromOrder(companyId, order.id, photoIdParam);

    const remainingCount = photos.length - 1;

    res.json({
      success: true,
      data: {
        message: formatPhotoDeleted(orderNumber, remainingCount),
        remainingPhotos: remainingCount,
      },
    });
  } catch (error) {
    console.error('Delete photo error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to delete photo' },
    });
  }
});

export default router;
