/**
 * Bot Orders Management Routes
 * Complete order management via WhatsApp Bot
 *
 * Endpoints:
 * - POST /bot/orders/full - Create complete order with services/products
 * - POST /bot/orders/:number/services - Add service to order
 * - POST /bot/orders/:number/products - Add product to order
 * - DELETE /bot/orders/:number/services/:index - Remove service from order
 * - DELETE /bot/orders/:number/products/:index - Remove product from order
 * - PATCH /bot/orders/:number/device - Update order device
 * - PATCH /bot/orders/:number/customer - Update order customer
 * - GET /bot/orders/:number/details - Get full order details
 */

import { Router, Response } from 'express';
import { AuthenticatedRequest, OrderStatus } from '../../models/types';
import { requireLinked } from '../../middleware/auth.middleware';
import { getUserAggr, getCompanyAggr } from '../../middleware/company.middleware';
import * as orderService from '../../services/order.service';
import * as customerService from '../../services/customer.service';
import * as deviceService from '../../services/device.service';
import * as catalogService from '../../services/catalog.service';
import {
  validateInput,
  createFullOrderSchema,
  addServiceToOrderSchema,
  addProductToOrderSchema,
  updateOrderDeviceSchema,
  updateOrderCustomerSchema,
} from '../../utils/validation.utils';
import {
  formatOrderCreated,
  formatServiceAdded,
  formatProductAdded,
  formatServiceRemoved,
  formatProductRemoved,
  formatOrderFullDetails,
  formatDeviceUpdated,
  formatCustomerUpdated,
  CreatedEntities,
} from '../../utils/format.utils';

const router: Router = Router();

/**
 * POST /api/bot/orders/full
 * Create a complete order with customer, device, services, and products
 */
router.post('/full', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    // Validate input
    const validation = validateInput(createFullOrderSchema, req.body);
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

    const data = validation.data;
    const createdBy = getUserAggr(req);
    const company = getCompanyAggr(req);

    const created: CreatedEntities = {
      services: [],
      products: [],
    };

    // Get or create customer
    let customerAggr;
    if (data.customerId) {
      const customer = await customerService.getCustomer(companyId, data.customerId);
      if (!customer) {
        res.status(404).json({
          success: false,
          error: { code: 'NOT_FOUND', message: 'Cliente não encontrado' },
        });
        return;
      }
      customerAggr = customerService.toCustomerAggr(customer);
      created.customer = false;
    } else {
      const result = await customerService.getOrCreateCustomer(
        companyId,
        data.customerName!,
        data.customerPhone,
        createdBy,
        company
      );
      customerAggr = result.customer;
      created.customer = result.created;
    }

    // Get or create device (optional)
    let deviceAggr;
    if (data.deviceId) {
      const device = await deviceService.getDevice(companyId, data.deviceId);
      if (!device) {
        res.status(404).json({
          success: false,
          error: { code: 'NOT_FOUND', message: 'Dispositivo não encontrado' },
        });
        return;
      }
      deviceAggr = deviceService.toDeviceAggr(device);
      created.device = false;
    } else if (data.deviceName) {
      const result = await deviceService.getOrCreateDevice(
        companyId,
        data.deviceName,
        data.deviceSerial,
        createdBy,
        company
      );
      deviceAggr = result.device;
      created.device = result.created;
    }

    // Process services
    const orderServices = [];
    if (data.services && data.services.length > 0) {
      for (const s of data.services) {
        const result = await catalogService.getOrCreateService(
          companyId,
          { serviceId: s.serviceId, serviceName: s.serviceName, value: s.value, description: s.description },
          createdBy,
          company
        );
        orderServices.push({
          serviceId: result.service.id!,
          value: s.value,
          description: s.description,
        });
        if (result.created && s.serviceName) {
          created.services!.push(s.serviceName);
        }
      }
    }

    // Process products
    const orderProducts: Array<{ productId: string; quantity: number; value?: number; description?: string }> = [];
    if (data.products && data.products.length > 0) {
      for (const p of data.products) {
        const result = await catalogService.getOrCreateProduct(
          companyId,
          { productId: p.productId, productName: p.productName, value: p.value, quantity: p.quantity || 1, description: p.description },
          createdBy,
          company
        );
        orderProducts.push({
          productId: result.product.id!,
          quantity: p.quantity || 1,
          value: p.value,
          description: p.description,
        });
        if (result.created && p.productName) {
          created.products!.push(p.productName);
        }
      }
    }

    // Create order
    const orderResult = await orderService.createOrder(
      companyId,
      {
        customerId: customerAggr.id!,
        customer: customerAggr,
        deviceId: deviceAggr?.id,
        device: deviceAggr,
        services: orderServices,
        products: orderProducts,
        dueDate: data.dueDate,
        status: data.status as OrderStatus,
      },
      createdBy,
      company
    );

    // Get the created order to format the response
    const order = await orderService.getOrderByNumber(companyId, orderResult.number);

    const message = order ? formatOrderCreated(order, created) : `OS #${orderResult.number} criada!`;

    res.status(201).json({
      success: true,
      data: {
        orderId: orderResult.id,
        orderNumber: orderResult.number,
        status: orderResult.status,
        total: order?.total || 0,
        message,
        created,
      },
    });
  } catch (error) {
    console.error('Create full order error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Erro ao criar OS' },
    });
  }
});

/**
 * POST /api/bot/orders/:number/services
 * Add a service to an existing order
 */
router.post('/:number/services', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
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
        error: { code: 'INVALID_NUMBER', message: 'Número da OS inválido' },
      });
      return;
    }

    // Validate input
    const validation = validateInput(addServiceToOrderSchema, req.body);
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

    const data = validation.data;
    const createdBy = getUserAggr(req);
    const company = getCompanyAggr(req);

    // Check if order exists
    const order = await orderService.getOrderByNumber(companyId, orderNumber);
    if (!order) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: `OS #${orderNumber} não encontrada` },
      });
      return;
    }

    // Get or create service
    const serviceResult = await catalogService.getOrCreateService(
      companyId,
      { serviceId: data.serviceId, serviceName: data.serviceName, value: data.value, description: data.description },
      createdBy,
      company
    );

    // Add service to order
    const result = await orderService.addServiceToOrderByNumber(
      companyId,
      orderNumber,
      {
        id: serviceResult.service.id!,
        name: serviceResult.service.name || '',
        value: serviceResult.service.value || data.value,
        photo: serviceResult.service.photo,
      },
      data.value,
      data.description,
      createdBy
    );

    if (!result.success) {
      res.status(500).json({
        success: false,
        error: { code: 'UPDATE_FAILED', message: 'Falha ao adicionar serviço' },
      });
      return;
    }

    const message = formatServiceAdded(
      orderNumber,
      serviceResult.service.name || data.serviceName || 'Serviço',
      data.value,
      result.newTotal
    );

    res.json({
      success: true,
      data: {
        message,
        serviceCreated: serviceResult.created,
        newTotal: result.newTotal,
      },
    });
  } catch (error) {
    console.error('Add service to order error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Erro ao adicionar serviço' },
    });
  }
});

/**
 * POST /api/bot/orders/:number/products
 * Add a product to an existing order
 */
router.post('/:number/products', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
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
        error: { code: 'INVALID_NUMBER', message: 'Número da OS inválido' },
      });
      return;
    }

    // Validate input
    const validation = validateInput(addProductToOrderSchema, req.body);
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

    const data = validation.data;
    const createdBy = getUserAggr(req);
    const company = getCompanyAggr(req);

    // Check if order exists
    const order = await orderService.getOrderByNumber(companyId, orderNumber);
    if (!order) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: `OS #${orderNumber} não encontrada` },
      });
      return;
    }

    // Get or create product
    const productResult = await catalogService.getOrCreateProduct(
      companyId,
      { productId: data.productId, productName: data.productName, value: data.value, quantity: data.quantity || 1, description: data.description },
      createdBy,
      company
    );

    // Add product to order
    const result = await orderService.addProductToOrderByNumber(
      companyId,
      orderNumber,
      {
        id: productResult.product.id!,
        name: productResult.product.name || '',
        value: productResult.product.value || data.value,
        photo: productResult.product.photo,
      },
      data.quantity || 1,
      data.value,
      data.description,
      createdBy
    );

    if (!result.success) {
      res.status(500).json({
        success: false,
        error: { code: 'UPDATE_FAILED', message: 'Falha ao adicionar produto' },
      });
      return;
    }

    const message = formatProductAdded(
      orderNumber,
      productResult.product.name || data.productName || 'Produto',
      data.value,
      data.quantity || 1,
      result.newTotal
    );

    res.json({
      success: true,
      data: {
        message,
        productCreated: productResult.created,
        newTotal: result.newTotal,
      },
    });
  } catch (error) {
    console.error('Add product to order error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Erro ao adicionar produto' },
    });
  }
});

/**
 * DELETE /api/bot/orders/:number/services/:index
 * Remove a service from an order by index
 */
router.delete('/:number/services/:index', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
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
    const indexParam = Array.isArray(req.params.index) ? req.params.index[0] : req.params.index;
    const orderNumber = parseInt(numberParam, 10);
    const serviceIndex = parseInt(indexParam, 10);

    if (isNaN(orderNumber)) {
      res.status(400).json({
        success: false,
        error: { code: 'INVALID_NUMBER', message: 'Número da OS inválido' },
      });
      return;
    }

    if (isNaN(serviceIndex) || serviceIndex < 0) {
      res.status(400).json({
        success: false,
        error: { code: 'INVALID_INDEX', message: 'Índice do serviço inválido' },
      });
      return;
    }

    const createdBy = getUserAggr(req);

    const result = await orderService.removeServiceFromOrder(
      companyId,
      orderNumber,
      serviceIndex,
      createdBy
    );

    if (!result.success) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: `OS #${orderNumber} não encontrada ou índice inválido` },
      });
      return;
    }

    const message = formatServiceRemoved(
      orderNumber,
      result.removedService?.service?.name || result.removedService?.description || 'Serviço',
      result.newTotal
    );

    res.json({
      success: true,
      data: {
        message,
        newTotal: result.newTotal,
      },
    });
  } catch (error) {
    console.error('Remove service from order error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Erro ao remover serviço' },
    });
  }
});

/**
 * DELETE /api/bot/orders/:number/products/:index
 * Remove a product from an order by index
 */
router.delete('/:number/products/:index', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
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
    const indexParam = Array.isArray(req.params.index) ? req.params.index[0] : req.params.index;
    const orderNumber = parseInt(numberParam, 10);
    const productIndex = parseInt(indexParam, 10);

    if (isNaN(orderNumber)) {
      res.status(400).json({
        success: false,
        error: { code: 'INVALID_NUMBER', message: 'Número da OS inválido' },
      });
      return;
    }

    if (isNaN(productIndex) || productIndex < 0) {
      res.status(400).json({
        success: false,
        error: { code: 'INVALID_INDEX', message: 'Índice do produto inválido' },
      });
      return;
    }

    const createdBy = getUserAggr(req);

    const result = await orderService.removeProductFromOrder(
      companyId,
      orderNumber,
      productIndex,
      createdBy
    );

    if (!result.success) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: `OS #${orderNumber} não encontrada ou índice inválido` },
      });
      return;
    }

    const message = formatProductRemoved(
      orderNumber,
      result.removedProduct?.product?.name || result.removedProduct?.description || 'Produto',
      result.newTotal
    );

    res.json({
      success: true,
      data: {
        message,
        newTotal: result.newTotal,
      },
    });
  } catch (error) {
    console.error('Remove product from order error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Erro ao remover produto' },
    });
  }
});

/**
 * PATCH /api/bot/orders/:number/device
 * Update order device
 */
router.patch('/:number/device', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
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
        error: { code: 'INVALID_NUMBER', message: 'Número da OS inválido' },
      });
      return;
    }

    // Validate input
    const validation = validateInput(updateOrderDeviceSchema, req.body);
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

    const data = validation.data;
    const createdBy = getUserAggr(req);
    const company = getCompanyAggr(req);

    // Get or create device
    let deviceAggr;
    let deviceCreated = false;
    if (data.deviceId) {
      const device = await deviceService.getDevice(companyId, data.deviceId);
      if (!device) {
        res.status(404).json({
          success: false,
          error: { code: 'NOT_FOUND', message: 'Dispositivo não encontrado' },
        });
        return;
      }
      deviceAggr = deviceService.toDeviceAggr(device);
    } else {
      const result = await deviceService.getOrCreateDevice(
        companyId,
        data.deviceName!,
        data.deviceSerial,
        createdBy,
        company
      );
      deviceAggr = result.device;
      deviceCreated = result.created;
    }

    // Update order device
    const result = await orderService.updateOrderDevice(
      companyId,
      orderNumber,
      deviceAggr,
      createdBy
    );

    if (!result.success) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: `OS #${orderNumber} não encontrada` },
      });
      return;
    }

    const message = formatDeviceUpdated(orderNumber, deviceAggr.name || 'Dispositivo');

    res.json({
      success: true,
      data: {
        message,
        deviceCreated,
        device: deviceAggr,
      },
    });
  } catch (error) {
    console.error('Update order device error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Erro ao atualizar dispositivo' },
    });
  }
});

/**
 * PATCH /api/bot/orders/:number/customer
 * Update order customer
 */
router.patch('/:number/customer', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
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
        error: { code: 'INVALID_NUMBER', message: 'Número da OS inválido' },
      });
      return;
    }

    // Validate input
    const validation = validateInput(updateOrderCustomerSchema, req.body);
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

    const data = validation.data;
    const createdBy = getUserAggr(req);
    const company = getCompanyAggr(req);

    // Get or create customer
    let customerAggr;
    let customerCreated = false;
    if (data.customerId) {
      const customer = await customerService.getCustomer(companyId, data.customerId);
      if (!customer) {
        res.status(404).json({
          success: false,
          error: { code: 'NOT_FOUND', message: 'Cliente não encontrado' },
        });
        return;
      }
      customerAggr = customerService.toCustomerAggr(customer);
    } else {
      const result = await customerService.getOrCreateCustomer(
        companyId,
        data.customerName!,
        data.customerPhone,
        createdBy,
        company
      );
      customerAggr = result.customer;
      customerCreated = result.created;
    }

    // Update order customer
    const result = await orderService.updateOrderCustomer(
      companyId,
      orderNumber,
      customerAggr,
      createdBy
    );

    if (!result.success) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: `OS #${orderNumber} não encontrada` },
      });
      return;
    }

    const message = formatCustomerUpdated(orderNumber, customerAggr.name || 'Cliente');

    res.json({
      success: true,
      data: {
        message,
        customerCreated,
        customer: customerAggr,
      },
    });
  } catch (error) {
    console.error('Update order customer error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Erro ao atualizar cliente' },
    });
  }
});

/**
 * GET /api/bot/orders/:number/details
 * Get full order details with services and products
 */
router.get('/:number/details', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.auth?.companyId;
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
        error: { code: 'INVALID_NUMBER', message: 'Número da OS inválido' },
      });
      return;
    }

    const order = await orderService.getOrderByNumber(companyId, orderNumber);

    if (!order) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: `OS #${orderNumber} não encontrada` },
      });
      return;
    }

    const message = formatOrderFullDetails(order);

    res.json({
      success: true,
      data: {
        order,
        message,
      },
    });
  } catch (error) {
    console.error('Get order details error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Erro ao buscar detalhes da OS' },
    });
  }
});

export default router;
