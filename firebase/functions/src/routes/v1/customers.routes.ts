/**
 * Customers Routes
 * CRUD endpoints for customer management
 */

import { Router, Response } from 'express';
import { AuthenticatedRequest, toDate } from '../../models/types';
import { getUserAggr, getCompanyAggr } from '../../middleware/company.middleware';
import * as customerService from '../../services/customer.service';
import {
  validateInput,
  createCustomerSchema,
  updateCustomerSchema,
  paginationSchema,
} from '../../utils/validation.utils';

const router: Router = Router();

/**
 * GET /api/v1/customers
 * List customers with optional filtering
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

    const result = await customerService.listCustomers(companyId, {
      phone: req.query.phone as string,
      email: req.query.email as string,
      name: req.query.name as string,
      limit: pagination.limit,
      offset: pagination.offset,
    });

    res.json({
      success: true,
      data: result.data.map((c) => ({
        id: c.id,
        name: c.name,
        phone: c.phone,
        email: c.email,
      })),
      pagination: {
        total: result.total,
        limit: pagination.limit,
        offset: pagination.offset,
        hasMore: result.hasMore,
      },
    });
  } catch (error) {
    console.error('List customers error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to list customers' },
    });
  }
});

/**
 * GET /api/v1/customers/:id
 * Get a single customer by ID
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

    const customer = await customerService.getCustomer(companyId, String(req.params.id));

    if (!customer) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Customer not found' },
      });
      return;
    }

    res.json({
      success: true,
      data: {
        id: customer.id,
        name: customer.name,
        phone: customer.phone,
        email: customer.email,
        address: customer.address,
        createdAt: toDate(customer.createdAt)?.toISOString(),
      },
    });
  } catch (error) {
    console.error('Get customer error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get customer' },
    });
  }
});

/**
 * POST /api/v1/customers
 * Create a new customer
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
    const validation = validateInput(createCustomerSchema, req.body);
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

    const result = await customerService.createCustomer(
      companyId,
      validation.data,
      createdBy,
      company
    );

    res.status(201).json({
      success: true,
      data: {
        id: result.id,
        name: result.customer.name,
      },
    });
  } catch (error) {
    console.error('Create customer error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to create customer' },
    });
  }
});

/**
 * PATCH /api/v1/customers/:id
 * Update an existing customer
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
    const validation = validateInput(updateCustomerSchema, req.body);
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

    const updated = await customerService.updateCustomer(
      companyId,
      String(req.params.id),
      validation.data,
      updatedBy
    );

    if (!updated) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Customer not found' },
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
    console.error('Update customer error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to update customer' },
    });
  }
});

export default router;
