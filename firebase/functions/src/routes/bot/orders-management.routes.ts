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
 * - PATCH /bot/orders/:number - Update order fields (status, dueDate, scheduledDate, assignedTo)
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
import * as shareTokenService from '../../services/share-token.service';
import {
  validateInput,
  createFullOrderSchema,
  updateBotOrderSchema,
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
  formatDeviceUpdated,
  formatCustomerUpdated,
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

    // Get customer by ID (required)
    const customer = await customerService.getCustomer(companyId, data.customerId);
    if (!customer) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Customer not found', customerId: data.customerId },
      });
      return;
    }
    const customerAggr = customerService.toCustomerAggr(customer);

    // Get device by ID (optional)
    let deviceAggr;
    if (data.deviceId) {
      const device = await deviceService.getDevice(companyId, data.deviceId);
      if (!device) {
        res.status(404).json({
          success: false,
          error: { code: 'NOT_FOUND', message: 'Device not found', deviceId: data.deviceId },
        });
        return;
      }
      deviceAggr = deviceService.toDeviceAggr(device);
    }

    // Process services (IDs required)
    const orderServices = [];
    if (data.services && data.services.length > 0) {
      for (const s of data.services) {
        const service = await catalogService.getService(companyId, s.serviceId);
        if (!service) {
          res.status(404).json({
            success: false,
            error: { code: 'NOT_FOUND', message: 'Service not found', serviceId: s.serviceId },
          });
          return;
        }
        orderServices.push({
          serviceId: service.id!,
          value: s.value,
          description: s.description,
        });
      }
    }

    // Process products (IDs required)
    const orderProducts: Array<{ productId: string; quantity: number; value?: number; description?: string }> = [];
    if (data.products && data.products.length > 0) {
      for (const p of data.products) {
        const product = await catalogService.getProduct(companyId, p.productId);
        if (!product) {
          res.status(404).json({
            success: false,
            error: { code: 'NOT_FOUND', message: 'Product not found', productId: p.productId },
          });
          return;
        }
        orderProducts.push({
          productId: product.id!,
          quantity: p.quantity || 1,
          value: p.value,
          description: p.description,
        });
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
        scheduledDate: data.scheduledDate,
        status: data.status as OrderStatus,
      },
      createdBy,
      company
    );

    // Get the created order to format the response
    const order = await orderService.getOrderByNumber(companyId, orderResult.number);

    const message = order ? formatOrderCreated(order, {}) : `OS #${orderResult.number} criada!`;

    res.status(201).json({
      success: true,
      data: {
        orderId: orderResult.id,
        orderNumber: orderResult.number,
        status: orderResult.status,
        total: order?.total || 0,
        customer: order?.customer || null,
        device: order?.device || null,
        message,
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

    // Check if order exists
    const order = await orderService.getOrderByNumber(companyId, orderNumber);
    if (!order) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: `OS #${orderNumber} não encontrada` },
      });
      return;
    }

    // Get service by ID (required)
    const service = await catalogService.getService(companyId, data.serviceId);
    if (!service) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Service not found', serviceId: data.serviceId },
      });
      return;
    }

    // Calculate value with fallback to catalog (value 0 is valid for gifts/courtesy)
    const serviceValue = data.value !== undefined ? data.value : (service.value ?? 0);

    // Add service to order
    const result = await orderService.addServiceToOrderByNumber(
      companyId,
      orderNumber,
      {
        id: service.id!,
        name: service.name || '',
        value: serviceValue,
        photo: service.photo,
      },
      serviceValue,
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
      service.name || 'Serviço',
      serviceValue,
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

    // Check if order exists
    const order = await orderService.getOrderByNumber(companyId, orderNumber);
    if (!order) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: `OS #${orderNumber} não encontrada` },
      });
      return;
    }

    // Get product by ID (required)
    const product = await catalogService.getProduct(companyId, data.productId);
    if (!product) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Product not found', productId: data.productId },
      });
      return;
    }

    // Calculate value with fallback to catalog (value 0 is valid for gifts/courtesy)
    const productValue = data.value !== undefined ? data.value : (product.value ?? 0);

    // Add product to order
    const result = await orderService.addProductToOrderByNumber(
      companyId,
      orderNumber,
      {
        id: product.id!,
        name: product.name || '',
        value: productValue,
        photo: product.photo,
      },
      data.quantity || 1,
      productValue,
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
      product.name || 'Produto',
      productValue,
      data.quantity || 1,
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
 * PATCH /api/bot/orders/:number
 * Update order fields (status, dueDate, scheduledDate, assignedTo)
 */
router.patch('/:number', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
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
    const validation = validateInput(updateBotOrderSchema, req.body);
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
    const updatedBy = getUserAggr(req);

    // Find order by number
    const order = await orderService.getOrderByNumber(companyId, orderNumber);
    if (!order) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: `OS #${orderNumber} não encontrada` },
      });
      return;
    }

    // Build update input
    const updateInput: orderService.UpdateOrderInput = {};

    if (data.status !== undefined) {
      updateInput.status = data.status as OrderStatus;
    }
    if (data.dueDate !== undefined) {
      updateInput.dueDate = data.dueDate ?? undefined;
    }
    if (data.scheduledDate !== undefined) {
      updateInput.scheduledDate = data.scheduledDate;
    }
    if (data.assignedTo !== undefined) {
      updateInput.assignedTo = data.assignedTo ? { id: data.assignedTo, name: '' } : null;
    }

    const updated = await orderService.updateOrder(
      companyId,
      order.id,
      updateInput,
      updatedBy
    );

    if (!updated) {
      res.status(500).json({
        success: false,
        error: { code: 'UPDATE_FAILED', message: 'Falha ao atualizar OS' },
      });
      return;
    }

    // Build response with updated fields
    const updatedFields: Record<string, unknown> = {};
    if (data.status !== undefined) updatedFields.status = data.status;
    if (data.dueDate !== undefined) updatedFields.dueDate = data.dueDate;
    if (data.scheduledDate !== undefined) updatedFields.scheduledDate = data.scheduledDate;
    if (data.assignedTo !== undefined) updatedFields.assignedTo = data.assignedTo;

    res.json({
      success: true,
      data: {
        orderNumber,
        updated: updatedFields,
        message: `OS #${orderNumber} atualizada`,
      },
    });
  } catch (error) {
    console.error('Update order error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Erro ao atualizar OS' },
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

    // Get device by ID (required)
    const device = await deviceService.getDevice(companyId, data.deviceId);
    if (!device) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Device not found', deviceId: data.deviceId },
      });
      return;
    }
    const deviceAggr = deviceService.toDeviceAggr(device);

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

    // Get customer by ID (required)
    const customer = await customerService.getCustomer(companyId, data.customerId);
    if (!customer) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Customer not found', customerId: data.customerId },
      });
      return;
    }
    const customerAggr = customerService.toCustomerAggr(customer);

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

    // Optimize payload: replace photos array with photosCount + mainPhotoUrl
    // AI formats the card via os-card.md template (sends photo as cover image)
    const photosCount = order.photos?.length || 0;
    const mainPhotoUrl = photosCount > 0
      ? `/bot/orders/${orderNumber}/photos/${order.photos![0].id}`
      : null;

    // Fetch active share token from tokens collection
    const tokens = await shareTokenService.getTokensForOrder(order.id, companyId);
    const activeToken = tokens.find(t => new Date(t.expiresAt) > new Date());
    const baseUrl = process.env.SHARE_BASE_URL || 'https://praticos.web.app';
    const shareUrl = activeToken ? `${baseUrl}/q/${activeToken.token}` : null;

    // Allowlist: only fields the bot card needs (saves ~45% tokens)
    const orderData = {
      number: order.number,
      status: order.status,
      customer: order.customer ? { name: order.customer.name, phone: order.customer.phone } : null,
      device: order.device ? { name: order.device.name, serial: order.device.serial } : null,
      services: order.services?.map(s => ({
        name: s.service?.name || s.description,
        value: s.value,
      })),
      products: order.products?.map(p => ({
        name: p.product?.name || p.description,
        quantity: p.quantity,
        value: p.value,
      })),
      total: order.total,
      discount: order.discount,
      paidAmount: order.paidAmount,
      dueDate: order.dueDate,
      scheduledDate: order.scheduledDate,
      createdAt: order.createdAt,
      rating: order.rating,
      photosCount,
      mainPhotoUrl,
      shareUrl,
    };

    res.json({
      success: true,
      data: {
        order: orderData,
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
