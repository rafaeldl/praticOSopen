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
import { getTenantCollection, deleteDocument } from '../../services/firestore.service';

const router: Router = Router();

// ============================================================================
// GET Routes - List and Get Entities
// ============================================================================

/**
 * GET /bot/entities/customers
 * List customers with optional search
 * Query: ?q=termo&limit=20
 */
router.get('/entities/customers', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    const query = (req.query.q as string)?.trim() || '';
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);

    let customers;
    if (query) {
      customers = await customerService.searchCustomers(companyId, query, limit);
    } else {
      const result = await customerService.listCustomers(companyId, { limit });
      customers = result.data;
    }

    res.json({
      success: true,
      data: customers.map((c) => ({
        id: c.id,
        name: c.name,
        phone: c.phone,
        email: c.email,
      })),
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
 * GET /bot/entities/customers/:id
 * Get customer by ID
 */
router.get('/entities/customers/:id', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    const customer = await customerService.getCustomer(companyId, req.params.id as string);
    if (!customer) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Cliente não encontrado' },
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
 * GET /bot/entities/devices
 * List devices with optional search
 * Query: ?q=termo&limit=20
 */
router.get('/entities/devices', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    const query = (req.query.q as string)?.trim() || '';
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);

    let devices;
    if (query) {
      devices = await deviceService.searchDevices(companyId, query, limit);
    } else {
      const result = await deviceService.listDevices(companyId, { limit });
      devices = result.data;
    }

    res.json({
      success: true,
      data: devices.map((d) => ({
        id: d.id,
        name: d.name,
        serial: d.serial,
        manufacturer: d.manufacturer,
      })),
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
 * GET /bot/entities/devices/:id
 * Get device by ID
 */
router.get('/entities/devices/:id', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    const device = await deviceService.getDevice(companyId, req.params.id as string);
    if (!device) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Dispositivo não encontrado' },
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
 * GET /bot/entities/services
 * List services with optional search
 * Query: ?q=termo&limit=20
 */
router.get('/entities/services', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    const query = (req.query.q as string)?.trim() || '';
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);

    let services;
    if (query) {
      services = await catalogService.searchServices(companyId, query, limit);
    } else {
      const result = await catalogService.listServices(companyId, { limit });
      services = result.data;
    }

    res.json({
      success: true,
      data: services.map((s) => ({
        id: s.id,
        name: s.name,
        value: s.value,
      })),
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
 * GET /bot/entities/services/:id
 * Get service by ID
 */
router.get('/entities/services/:id', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    const service = await catalogService.getService(companyId, req.params.id as string);
    if (!service) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Serviço não encontrado' },
      });
      return;
    }

    res.json({
      success: true,
      data: {
        id: service.id,
        name: service.name,
        value: service.value,
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
 * GET /bot/entities/products
 * List products with optional search
 * Query: ?q=termo&limit=20
 */
router.get('/entities/products', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    const query = (req.query.q as string)?.trim() || '';
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);

    let products;
    if (query) {
      products = await catalogService.searchProducts(companyId, query, limit);
    } else {
      const result = await catalogService.listProducts(companyId, { limit });
      products = result.data;
    }

    res.json({
      success: true,
      data: products.map((p) => ({
        id: p.id,
        name: p.name,
        value: p.value,
      })),
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
 * GET /bot/entities/products/:id
 * Get product by ID
 */
router.get('/entities/products/:id', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    const product = await catalogService.getProduct(companyId, req.params.id as string);
    if (!product) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Produto não encontrado' },
      });
      return;
    }

    res.json({
      success: true,
      data: {
        id: product.id,
        name: product.name,
        value: product.value,
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

// ============================================================================
// POST Routes - Create Entities
// ============================================================================

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

    const customerId = req.params.id as string as string;
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

    const deviceId = req.params.id as string as string;
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

    const serviceId = req.params.id as string as string;
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

    const productId = req.params.id as string as string;
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

// ============================================================================
// DELETE Routes - Delete Entities
// ============================================================================

/**
 * DELETE /bot/entities/customers/:id
 * Delete a customer
 */
router.delete('/entities/customers/:id', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
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
    const customer = await customerService.getCustomer(companyId, customerId);
    if (!customer) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Cliente não encontrado' },
      });
      return;
    }

    const collection = getTenantCollection(companyId, 'customers');
    await deleteDocument(collection, customerId);

    res.json({
      success: true,
      message: `Cliente "${customer.name}" excluído com sucesso`,
    });
  } catch (error) {
    console.error('Delete customer error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to delete customer' },
    });
  }
});

/**
 * DELETE /bot/entities/devices/:id
 * Delete a device
 */
router.delete('/entities/devices/:id', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
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
    const device = await deviceService.getDevice(companyId, deviceId);
    if (!device) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Dispositivo não encontrado' },
      });
      return;
    }

    const collection = getTenantCollection(companyId, 'devices');
    await deleteDocument(collection, deviceId);

    res.json({
      success: true,
      message: `Dispositivo "${device.name}" excluído com sucesso`,
    });
  } catch (error) {
    console.error('Delete device error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to delete device' },
    });
  }
});

/**
 * DELETE /bot/entities/services/:id
 * Delete a service
 */
router.delete('/entities/services/:id', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
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
    const service = await catalogService.getService(companyId, serviceId);
    if (!service) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Serviço não encontrado' },
      });
      return;
    }

    const collection = getTenantCollection(companyId, 'services');
    await deleteDocument(collection, serviceId);

    res.json({
      success: true,
      message: `Serviço "${service.name}" excluído com sucesso`,
    });
  } catch (error) {
    console.error('Delete service error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to delete service' },
    });
  }
});

/**
 * DELETE /bot/entities/products/:id
 * Delete a product
 */
router.delete('/entities/products/:id', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
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
    const product = await catalogService.getProduct(companyId, productId);
    if (!product) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Produto não encontrado' },
      });
      return;
    }

    const collection = getTenantCollection(companyId, 'products');
    await deleteDocument(collection, productId);

    res.json({
      success: true,
      message: `Produto "${product.name}" excluído com sucesso`,
    });
  } catch (error) {
    console.error('Delete product error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to delete product' },
    });
  }
});

export default router;
