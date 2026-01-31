/**
 * Orders Routes
 * CRUD endpoints for order management
 */

import { Router, Response } from 'express';
import { AuthenticatedRequest, OrderStatus } from '../../models/types';
import { getUserAggr, getCompanyAggr } from '../../middleware/company.middleware';
import * as orderService from '../../services/order.service';
import * as customerService from '../../services/customer.service';
import * as deviceService from '../../services/device.service';
import {
  validateInput,
  createOrderSchema,
  updateOrderSchema,
  addOrderServiceSchema,
  addOrderProductSchema,
  addPaymentSchema,
  paginationSchema,
} from '../../utils/validation.utils';
import { timestampToDate } from '../../utils/date.utils';

const router: Router = Router();

/**
 * GET /api/v1/orders
 * List orders with optional filtering
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

    const result = await orderService.listOrders(companyId, {
      status: req.query.status as OrderStatus,
      customerId: req.query.customerId as string,
      deviceId: req.query.deviceId as string,
      assignedTo: req.query.assignedTo as string,
      startDate: req.query.startDate as string,
      endDate: req.query.endDate as string,
      limit: pagination.limit,
      offset: pagination.offset,
    });

    res.json({
      success: true,
      data: result.data.map((o) => ({
        id: o.id,
        number: o.number,
        customer: o.customer,
        device: o.device,
        status: o.status,
        total: o.total,
        dueDate: timestampToDate(o.dueDate)?.toISOString(),
        createdAt: timestampToDate(o.createdAt)?.toISOString(),
      })),
      pagination: {
        total: result.total,
        limit: pagination.limit,
        offset: pagination.offset,
        hasMore: result.hasMore,
      },
    });
  } catch (error) {
    console.error('List orders error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to list orders' },
    });
  }
});

/**
 * GET /api/v1/orders/:id
 * Get a single order by ID
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

    const order = await orderService.getOrder(companyId, String(req.params.id));

    if (!order) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Order not found' },
      });
      return;
    }

    const remainingBalance = orderService.calculateRemainingBalance(order);

    res.json({
      success: true,
      data: {
        id: order.id,
        number: order.number,
        customer: order.customer,
        device: order.device,
        services: order.services,
        products: order.products,
        status: order.status,
        total: order.total,
        discount: order.discount,
        paidAmount: order.paidAmount,
        remainingBalance,
        dueDate: timestampToDate(order.dueDate)?.toISOString(),
        createdAt: timestampToDate(order.createdAt)?.toISOString(),
        updatedAt: timestampToDate(order.updatedAt)?.toISOString(),
      },
    });
  } catch (error) {
    console.error('Get order error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get order' },
    });
  }
});

/**
 * POST /api/v1/orders
 * Create a new order
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
    const validation = validateInput(createOrderSchema, req.body);
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

    const { customerId, deviceId, ...orderData } = validation.data;

    // Get customer
    const customer = await customerService.getCustomer(companyId, customerId);
    if (!customer) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Customer not found' },
      });
      return;
    }

    // Get device if provided
    let device = null;
    if (deviceId) {
      device = await deviceService.getDevice(companyId, deviceId);
      if (!device) {
        res.status(404).json({
          success: false,
          error: { code: 'NOT_FOUND', message: 'Device not found' },
        });
        return;
      }
    }

    const createdBy = getUserAggr(req);
    const company = getCompanyAggr(req);

    const result = await orderService.createOrder(
      companyId,
      {
        ...orderData,
        customerId,
        customer: customerService.toCustomerAggr(customer),
        deviceId,
        device: device ? deviceService.toDeviceAggr(device) : undefined,
      },
      createdBy,
      company
    );

    res.status(201).json({
      success: true,
      data: {
        id: result.id,
        number: result.number,
        status: result.status,
      },
    });
  } catch (error) {
    console.error('Create order error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to create order' },
    });
  }
});

/**
 * PATCH /api/v1/orders/:id
 * Update an existing order
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
    const validation = validateInput(updateOrderSchema, req.body);
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

    // Transform assignedTo string to UserAggr if provided
    const updateInput: orderService.UpdateOrderInput = {
      status: validation.data.status,
      dueDate: validation.data.dueDate,
    };
    if (validation.data.assignedTo) {
      // Note: In a real implementation, we would look up the user to get the full UserAggr
      // For now, we create a minimal UserAggr from the ID
      updateInput.assignedTo = {
        id: validation.data.assignedTo,
        name: '', // Would be resolved from user document
      };
    }

    const updated = await orderService.updateOrder(
      companyId,
      String(req.params.id),
      updateInput,
      updatedBy
    );

    if (!updated) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Order not found' },
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
    console.error('Update order error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to update order' },
    });
  }
});

/**
 * POST /api/v1/orders/:id/services
 * Add a service to an order
 */
router.post('/:id/services', async (req: AuthenticatedRequest, res: Response) => {
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
    const validation = validateInput(addOrderServiceSchema, req.body);
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

    const result = await orderService.addOrderService(
      companyId,
      String(req.params.id),
      validation.data.serviceId,
      validation.data.value,
      validation.data.description,
      updatedBy
    );

    if (!result.success) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Order or service not found' },
      });
      return;
    }

    res.json({
      success: true,
      data: {
        success: true,
        newTotal: result.newTotal,
      },
    });
  } catch (error) {
    console.error('Add service error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to add service' },
    });
  }
});

/**
 * POST /api/v1/orders/:id/products
 * Add a product to an order
 */
router.post('/:id/products', async (req: AuthenticatedRequest, res: Response) => {
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
    const validation = validateInput(addOrderProductSchema, req.body);
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

    const result = await orderService.addOrderProduct(
      companyId,
      String(req.params.id),
      validation.data.productId,
      validation.data.quantity,
      validation.data.value,
      validation.data.description,
      updatedBy
    );

    if (!result.success) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Order or product not found' },
      });
      return;
    }

    res.json({
      success: true,
      data: {
        success: true,
        newTotal: result.newTotal,
      },
    });
  } catch (error) {
    console.error('Add product error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to add product' },
    });
  }
});

/**
 * POST /api/v1/orders/:id/payments
 * Add a payment or discount to an order
 */
router.post('/:id/payments', async (req: AuthenticatedRequest, res: Response) => {
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
    const validation = validateInput(addPaymentSchema, req.body);
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

    const result = await orderService.addPayment(
      companyId,
      String(req.params.id),
      validation.data.amount,
      validation.data.type || 'payment',
      validation.data.description,
      createdBy
    );

    if (!result) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Order not found' },
      });
      return;
    }

    res.json({
      success: true,
      data: result,
    });
  } catch (error) {
    console.error('Add payment error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to add payment' },
    });
  }
});

export default router;
