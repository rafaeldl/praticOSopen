/**
 * Bot Entity Creation Routes
 * Endpoints for creating entities (customers, devices, services, products) via bot
 */

import { Router, Response } from 'express';
import { AuthenticatedRequest } from '../../models/types';
import { requireLinked } from '../../middleware/auth.middleware';
import { getUserAggr, getCompanyAggr } from '../../middleware/company.middleware';
import {
  validateInput,
  createCustomerSchema,
  createBotDeviceSchema,
  createServiceSchema,
  createProductSchema,
} from '../../utils/validation.utils';
import * as customerService from '../../services/customer.service';
import * as deviceService from '../../services/device.service';
import * as catalogService from '../../services/catalog.service';

const router: Router = Router();

/**
 * POST /bot/entities/customers
 * Create a new customer
 */
router.post('/entities/customers', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

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

    const userAggr = getUserAggr(req);
    const companyAggr = getCompanyAggr(req);

    const result = await customerService.createCustomer(
      companyId,
      validation.data,
      userAggr,
      companyAggr
    );

    res.status(201).json({
      success: true,
      data: {
        id: result.id,
        name: result.customer.name,
        phone: result.customer.phone,
      },
      message: `Cliente "${result.customer.name}" cadastrado`,
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
 * POST /bot/entities/devices
 * Create a new device
 */
router.post('/entities/devices', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    const validation = validateInput(createBotDeviceSchema, req.body);
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

    const userAggr = getUserAggr(req);
    const companyAggr = getCompanyAggr(req);

    const result = await deviceService.createDevice(
      companyId,
      validation.data,
      userAggr,
      companyAggr
    );

    res.status(201).json({
      success: true,
      data: {
        id: result.id,
        name: result.device.name,
        serial: result.device.serial,
      },
      message: `Device "${result.device.name}" cadastrado`,
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
 * POST /bot/entities/services
 * Create a new service
 */
router.post('/entities/services', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

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

    const userAggr = getUserAggr(req);
    const companyAggr = getCompanyAggr(req);

    const result = await catalogService.createService(
      companyId,
      validation.data,
      userAggr,
      companyAggr
    );

    res.status(201).json({
      success: true,
      data: {
        id: result.id,
        name: result.name,
        value: validation.data.value,
      },
      message: `Serviço "${result.name}" cadastrado`,
    });
  } catch (error) {
    console.error('Create service error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to create service' },
    });
  }
});

/**
 * POST /bot/entities/products
 * Create a new product
 */
router.post('/entities/products', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

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

    const userAggr = getUserAggr(req);
    const companyAggr = getCompanyAggr(req);

    const result = await catalogService.createProduct(
      companyId,
      validation.data,
      userAggr,
      companyAggr
    );

    res.status(201).json({
      success: true,
      data: {
        id: result.id,
        name: result.name,
        value: validation.data.value,
      },
      message: `Produto "${result.name}" cadastrado`,
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
