/**
 * Products Routes
 * CRUD endpoints for product catalog management
 */

import { Router, Response } from 'express';
import { AuthenticatedRequest } from '../../models/types';
import { getUserAggr, getCompanyAggr } from '../../middleware/company.middleware';
import * as catalogService from '../../services/catalog.service';
import {
  validateInput,
  createProductSchema,
  paginationSchema,
} from '../../utils/validation.utils';

const router: Router = Router();

/**
 * GET /api/v1/products
 * List products with optional filtering
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

    const result = await catalogService.listProducts(companyId, {
      name: req.query.name as string,
      minValue,
      maxValue,
      limit: pagination.limit,
      offset: pagination.offset,
    });

    res.json({
      success: true,
      data: result.data.map((p) => ({
        id: p.id,
        name: p.name,
        value: p.value,
      })),
      pagination: {
        total: result.total,
        limit: pagination.limit,
        offset: pagination.offset,
        hasMore: result.hasMore,
      },
    });
  } catch (error) {
    console.error('List products error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to list products' },
    });
  }
});

/**
 * GET /api/v1/products/:id
 * Get a single product by ID
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

    const product = await catalogService.getProduct(companyId, String(req.params.id));

    if (!product) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Product not found' },
      });
      return;
    }

    res.json({
      success: true,
      data: {
        id: product.id,
        name: product.name,
        value: product.value,
        photo: product.photo,
      },
    });
  } catch (error) {
    console.error('Get product error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get product' },
    });
  }
});

/**
 * POST /api/v1/products
 * Create a new product
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
    const validation = validateInput(createProductSchema, req.body);
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

    const result = await catalogService.createProduct(
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
    console.error('Create product error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to create product' },
    });
  }
});

export default router;
