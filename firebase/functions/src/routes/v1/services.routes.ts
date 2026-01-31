/**
 * Services Routes
 * CRUD endpoints for service catalog management
 */

import { Router, Response } from 'express';
import { AuthenticatedRequest } from '../../models/types';
import { getUserAggr, getCompanyAggr } from '../../middleware/company.middleware';
import * as catalogService from '../../services/catalog.service';
import {
  validateInput,
  createServiceSchema,
  paginationSchema,
} from '../../utils/validation.utils';

const router: Router = Router();

/**
 * GET /api/v1/services
 * List services with optional filtering
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

    const minValue = req.query.minValue ? parseFloat(req.query.minValue as string) : undefined;
    const maxValue = req.query.maxValue ? parseFloat(req.query.maxValue as string) : undefined;

    const result = await catalogService.listServices(companyId, {
      name: req.query.name as string,
      minValue,
      maxValue,
      limit: pagination.limit,
      offset: pagination.offset,
    });

    res.json({
      success: true,
      data: result.data.map((s) => ({
        id: s.id,
        name: s.name,
        value: s.value,
      })),
      pagination: {
        total: result.total,
        limit: pagination.limit,
        offset: pagination.offset,
        hasMore: result.hasMore,
      },
    });
  } catch (error) {
    console.error('List services error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to list services' },
    });
  }
});

/**
 * GET /api/v1/services/:id
 * Get a single service by ID
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

    const service = await catalogService.getService(companyId, String(req.params.id));

    if (!service) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Service not found' },
      });
      return;
    }

    res.json({
      success: true,
      data: {
        id: service.id,
        name: service.name,
        value: service.value,
        photo: service.photo,
      },
    });
  } catch (error) {
    console.error('Get service error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get service' },
    });
  }
});

/**
 * POST /api/v1/services
 * Create a new service
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
    const validation = validateInput(createServiceSchema, req.body);
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

    const result = await catalogService.createService(
      companyId,
      validation.data,
      createdBy,
      company
    );

    res.status(201).json({
      success: true,
      data: {
        id: result.id,
        name: result.name,
      },
    });
  } catch (error) {
    console.error('Create service error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to create service' },
    });
  }
});

export default router;
