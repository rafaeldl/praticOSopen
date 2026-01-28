/**
 * Bot Quick Routes
 * Fast order creation endpoint for conversational UI
 */

import { Router, Response } from 'express';
import { AuthenticatedRequest } from '../../models/types';
import { requireLinked } from '../../middleware/auth.middleware';
import { getUserAggr, getCompanyAggr } from '../../middleware/company.middleware';
import * as orderService from '../../services/order.service';
import * as customerService from '../../services/customer.service';
import * as deviceService from '../../services/device.service';
import { validateInput, quickOrderSchema } from '../../utils/validation.utils';

const router: Router = Router();

/**
 * POST /api/bot/orders/quick
 * Quick order creation (creates customer/device if needed)
 */
router.post('/quick', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
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
    const validation = validateInput(quickOrderSchema, req.body);
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

    const {
      customerName,
      customerPhone,
      deviceName,
      deviceSerial,
      problem,
      estimatedValue,
      dueDate,
    } = validation.data;

    const createdBy = getUserAggr(req);
    const company = getCompanyAggr(req);

    // Get or create customer
    const customerResult = await customerService.getOrCreateCustomer(
      companyId,
      customerName,
      customerPhone,
      createdBy,
      company
    );

    // Get or create device
    const deviceResult = await deviceService.getOrCreateDevice(
      companyId,
      deviceName,
      deviceSerial,
      createdBy,
      company
    );

    // Create order
    const orderResult = await orderService.createOrder(
      companyId,
      {
        customerId: customerResult.customer.id,
        customer: customerResult.customer,
        deviceId: deviceResult.device.id,
        device: deviceResult.device,
        services: estimatedValue ? [{
          serviceId: 'manual',
          value: estimatedValue,
          description: problem,
        }] : [],
        dueDate,
        status: 'quote',
      },
      createdBy,
      company
    );

    res.status(201).json({
      success: true,
      data: {
        orderId: orderResult.id,
        orderNumber: orderResult.number,
        status: orderResult.status,
        customerCreated: customerResult.created,
        deviceCreated: deviceResult.created,
      },
    });
  } catch (error) {
    console.error('Quick order error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to create order' },
    });
  }
});

export default router;
