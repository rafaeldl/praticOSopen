/**
 * Bot Photos Routes
 * Photo upload and management endpoints for orders
 */

import { Router, Response } from 'express';
import Busboy from 'busboy';
import { AuthenticatedRequest } from '../../models/types';
import { requireLinked } from '../../middleware/auth.middleware';
import { getUserAggr } from '../../middleware/company.middleware';
import * as orderService from '../../services/order.service';
import * as photoService from '../../services/photo-upload.service';
import { validateInput, uploadPhotoBase64Schema } from '../../utils/validation.utils';
import { formatPhotoAdded, formatPhotosList, formatPhotoDeleted } from '../../utils/format.utils';

const router: Router = Router();

/**
 * POST /bot/orders/:number/photos
 * Upload photo to order (base64 only)
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

    // Validate base64 input
    const validation = validateInput(uploadPhotoBase64Schema, req.body);
    if (!validation.success) {
      res.status(400).json({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: validation.errors.join(', ') },
      });
      return;
    }

    const photo = await photoService.uploadPhotoFromBase64(
      companyId,
      order.id,
      {
        base64: validation.data.base64,
        filename: validation.data.filename,
        description: validation.data.description,
      },
      createdBy
    );

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
 * POST /bot/orders/:number/photos/upload
 * Upload photo via multipart/form-data (RECOMMENDED - more efficient than base64)
 */
router.post('/:number/photos/upload', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
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

  // Parse multipart form
  const busboy = Busboy({
    headers: req.headers,
    limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit
  });

  let fileBuffer: Buffer | null = null;
  let filename = 'photo.jpg';
  let mimeType = 'image/jpeg';
  let description = '';
  let uploadError: Error | null = null;

  busboy.on('file', (fieldname, file, info) => {
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

  busboy.on('field', (fieldname, value) => {
    if (fieldname === 'description') {
      description = value;
    }
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

      const photo = await photoService.uploadPhotoFromBuffer(
        companyId,
        order.id,
        {
          buffer: fileBuffer,
          filename,
          mimeType,
          description,
        },
        createdBy
      );

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
      console.error('Upload photo from buffer error:', error);
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

/**
 * GET /bot/orders/:number/photos
 * List photos of an order (returns downloadUrl for direct API access)
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

    // Return download URLs pointing to our API (no signed URLs needed)
    const photosWithDownloadUrls = photos.map((p) => ({
      id: p.id,
      url: p.url,
      downloadUrl: `/bot/orders/${orderNumber}/photos/${p.id}`,
      description: p.description,
      createdAt: p.createdAt,
      createdBy: p.createdBy?.name || 'Unknown',
    }));

    res.json({
      success: true,
      data: {
        photos: photosWithDownloadUrls,
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
 * GET /bot/orders/:number/photos/:photoId
 * Download photo directly (streams the image binary)
 */
router.get('/:number/photos/:photoId', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
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
    const photo = photos.find((p) => p.id === photoIdParam);

    if (!photo) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: `Photo not found in order #${orderNumber}` },
      });
      return;
    }

    if (!photo.storagePath) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Photo storage path not available' },
      });
      return;
    }

    // Stream the photo directly from Storage
    const { stream, contentType } = await photoService.getPhotoStream(photo.storagePath);

    res.setHeader('Content-Type', contentType);
    res.setHeader('Content-Disposition', `inline; filename="${photo.id}.jpg"`);

    stream.pipe(res);
  } catch (error) {
    console.error('Download photo error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to download photo' },
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
