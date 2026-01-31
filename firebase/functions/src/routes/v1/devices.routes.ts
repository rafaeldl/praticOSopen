/**
 * Devices Routes
 * CRUD endpoints for device management
 */

import { Router, Response } from 'express';
import { AuthenticatedRequest } from '../../models/types';
import { getUserAggr, getCompanyAggr } from '../../middleware/company.middleware';
import * as deviceService from '../../services/device.service';
import {
  validateInput,
  createDeviceSchema,
  updateDeviceSchema,
  paginationSchema,
} from '../../utils/validation.utils';

const router: Router = Router();

/**
 * GET /api/v1/devices
 * List devices with optional filtering
 */
router.get('/', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.auth?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    // Validate pagination params
    const paginationResult = validateInput(paginationSchema, req.query);
    const pagination = paginationResult.success ? paginationResult.data : { limit: 20, offset: 0 };

    const result = await deviceService.listDevices(companyId, {
      serial: req.query.serial as string,
      name: req.query.name as string,
      category: req.query.category as string,
      manufacturer: req.query.manufacturer as string,
      limit: pagination.limit,
      offset: pagination.offset,
    });

    res.json({
      success: true,
      data: result.data.map((d) => ({
        id: d.id,
        name: d.name,
        serial: d.serial,
        manufacturer: d.manufacturer,
      })),
      pagination: {
        total: result.total,
        limit: pagination.limit,
        offset: pagination.offset,
        hasMore: result.hasMore,
      },
    });
  } catch (error) {
    console.error('List devices error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to list devices' },
    });
  }
});

/**
 * GET /api/v1/devices/:id
 * Get a single device by ID
 */
router.get('/:id', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.auth?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    const device = await deviceService.getDevice(companyId, String(req.params.id));

    if (!device) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Device not found' },
      });
      return;
    }

    res.json({
      success: true,
      data: {
        id: device.id,
        name: device.name,
        serial: device.serial,
        manufacturer: device.manufacturer,
        category: device.category,
        description: device.description,
      },
    });
  } catch (error) {
    console.error('Get device error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get device' },
    });
  }
});

/**
 * POST /api/v1/devices
 * Create a new device
 */
router.post('/', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.auth?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    // Validate input
    const validation = validateInput(createDeviceSchema, req.body);
    if (!validation.success) {
      res.status(400).json({
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: validation.errors.join(', '),
        },
      });
      return;
    }

    const createdBy = getUserAggr(req);
    const company = getCompanyAggr(req);

    const result = await deviceService.createDevice(
      companyId,
      validation.data,
      createdBy,
      company
    );

    res.status(201).json({
      success: true,
      data: {
        id: result.id,
        name: result.device.name,
      },
    });
  } catch (error) {
    console.error('Create device error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to create device' },
    });
  }
});

/**
 * PATCH /api/v1/devices/:id
 * Update an existing device
 */
router.patch('/:id', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.auth?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    // Validate input
    const validation = validateInput(updateDeviceSchema, req.body);
    if (!validation.success) {
      res.status(400).json({
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: validation.errors.join(', '),
        },
      });
      return;
    }

    const updatedBy = getUserAggr(req);

    const updated = await deviceService.updateDevice(
      companyId,
      String(req.params.id),
      validation.data,
      updatedBy
    );

    if (!updated) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Device not found' },
      });
      return;
    }

    res.json({
      success: true,
      data: {
        id: req.params.id,
        updated: true,
      },
    });
  } catch (error) {
    console.error('Update device error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to update device' },
    });
  }
});

export default router;
