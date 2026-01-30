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
  updateCustomerSchema,
  updateDeviceSchema,
  updateServiceSchema,
  updateProductSchema,
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

// ============================================================================
// PATCH Routes - Update Entities
// ============================================================================

/**
 * PATCH /bot/entities/customers/:id
 * Update an existing customer
 */
router.patch('/entities/customers/:id', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    const customerId = req.params.id as string;
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

    const userAggr = getUserAggr(req);
    const updated = await customerService.updateCustomer(companyId, customerId, validation.data, userAggr);

    if (!updated) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Cliente não encontrado' },
      });
      return;
    }

    res.status(200).json({
      success: true,
      data: { id: customerId, ...validation.data },
      message: 'Cliente atualizado com sucesso',
    });
  } catch (error) {
    console.error('Update customer error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to update customer' },
    });
  }
});

/**
 * PATCH /bot/entities/devices/:id
 * Update an existing device
 */
router.patch('/entities/devices/:id', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    const deviceId = req.params.id as string;
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

    const userAggr = getUserAggr(req);
    const updated = await deviceService.updateDevice(companyId, deviceId, validation.data, userAggr);

    if (!updated) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Dispositivo não encontrado' },
      });
      return;
    }

    res.status(200).json({
      success: true,
      data: { id: deviceId, ...validation.data },
      message: 'Dispositivo atualizado com sucesso',
    });
  } catch (error) {
    console.error('Update device error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to update device' },
    });
  }
});

/**
 * PATCH /bot/entities/services/:id
 * Update an existing service
 */
router.patch('/entities/services/:id', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    const serviceId = req.params.id as string;
    const validation = validateInput(updateServiceSchema, req.body);
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
    const updated = await catalogService.updateService(companyId, serviceId, validation.data, userAggr);

    if (!updated) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Serviço não encontrado' },
      });
      return;
    }

    res.status(200).json({
      success: true,
      data: { id: serviceId, ...validation.data },
      message: 'Serviço atualizado com sucesso',
    });
  } catch (error) {
    console.error('Update service error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to update service' },
    });
  }
});

/**
 * PATCH /bot/entities/products/:id
 * Update an existing product
 */
router.patch('/entities/products/:id', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    const productId = req.params.id as string;
    const validation = validateInput(updateProductSchema, req.body);
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
    const updated = await catalogService.updateProduct(companyId, productId, validation.data, userAggr);

    if (!updated) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Produto não encontrado' },
      });
      return;
    }

    res.status(200).json({
      success: true,
      data: { id: productId, ...validation.data },
      message: 'Produto atualizado com sucesso',
    });
  } catch (error) {
    console.error('Update product error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to update product' },
    });
  }
});

export default router;
