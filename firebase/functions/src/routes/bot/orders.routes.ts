/**
 * Bot Orders Routes
 * Endpoints for order management via Bot
 */

import { Router, Response } from 'express';
import { AuthenticatedRequest, OrderStatus } from '../../models/types';
import * as orderService from '../../services/order.service';
import { getFormatContext } from '../../utils/format.utils';
import { getUserAggr } from '../../middleware/company.middleware';

const router: Router = Router();

// Valid status transitions
const validTransitions: Record<string, string[]> = {
  quote: ['approved', 'canceled'],
  approved: ['progress', 'done', 'canceled'],
  progress: ['done', 'canceled'],
  done: [],
  canceled: [],
};

/**
 * GET /api/bot/orders/list
 * List orders for the bot with formatted output
 */
router.get('/list', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.auth?.companyId;

    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Contexto da empresa não encontrado para este número.' },
      });
      return;
    }

    const status = req.query.status as OrderStatus;

    const result = await orderService.listOrders(companyId, {
      status,
      limit: 10,
      offset: 0,
    });

    // Strip heavy fields (photos, transactions) to save tokens in list view
    // Bot should use GET /bot/orders/{NUM}/details for full order data + photo
    const lightOrders = result.data.map(({ photos, transactions, ...rest }) => ({
      ...rest,
      photosCount: photos?.length || 0,
    }));

    res.json({
      success: true,
      data: {
        count: result.total,
        orders: lightOrders,
        formatContext: getFormatContext(req.auth?.companyCountry),
      },
    });
  } catch (error) {
    console.error('Bot List orders error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Erro ao listar ordens para o bot' },
    });
  }
});

/**
 * GET /api/bot/orders/:number
 * Get order by number with formatted output for WhatsApp
 */
router.get('/:number', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.auth?.companyId;

    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Contexto da empresa não encontrado para este número.' },
      });
      return;
    }

    const numberParam = req.params.number;
    const orderNumber = parseInt(Array.isArray(numberParam) ? numberParam[0] : numberParam, 10);

    if (isNaN(orderNumber)) {
      res.status(400).json({
        success: false,
        error: { code: 'INVALID_NUMBER', message: 'Número da OS inválido.' },
      });
      return;
    }

    const order = await orderService.getOrderByNumber(companyId, orderNumber);

    if (!order) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: `OS #${orderNumber} não encontrada.` },
      });
      return;
    }

    res.json({
      success: true,
      data: {
        order,
        formatContext: getFormatContext(req.auth?.companyCountry),
      },
    });
  } catch (error) {
    console.error('Bot Get order by number error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Erro ao buscar OS.' },
    });
  }
});

/**
 * PATCH /api/bot/orders/:number/status
 * Update order status with validation
 */
router.patch('/:number/status', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.auth?.companyId;

    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Contexto da empresa não encontrado para este número.' },
      });
      return;
    }

    const numberParam = req.params.number;
    const orderNumber = parseInt(Array.isArray(numberParam) ? numberParam[0] : numberParam, 10);
    const { status: newStatus } = req.body;

    if (isNaN(orderNumber)) {
      res.status(400).json({
        success: false,
        error: { code: 'INVALID_NUMBER', message: 'Número da OS inválido.' },
      });
      return;
    }

    if (!newStatus || !['approved', 'progress', 'done', 'canceled'].includes(newStatus)) {
      res.status(400).json({
        success: false,
        error: {
          code: 'INVALID_STATUS',
          message: 'Status inválido. Use: approved, progress, done ou canceled.',
        },
      });
      return;
    }

    const order = await orderService.getOrderByNumber(companyId, orderNumber);

    if (!order) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: `OS #${orderNumber} não encontrada.` },
      });
      return;
    }

    // Validate transition
    const currentStatus = order.status;
    const allowedTransitions = validTransitions[currentStatus] || [];

    if (!allowedTransitions.includes(newStatus)) {
      res.status(400).json({
        success: false,
        error: {
          code: 'INVALID_TRANSITION',
          message: `Invalid transition: ${currentStatus} → ${newStatus}`,
          allowedTransitions: validTransitions[currentStatus] || [],
        },
      });
      return;
    }

    // Get user for audit
    const updatedBy = getUserAggr(req);

    // Update order
    const success = await orderService.updateOrder(
      companyId,
      order.id,
      { status: newStatus as OrderStatus },
      updatedBy
    );

    if (!success) {
      res.status(500).json({
        success: false,
        error: { code: 'UPDATE_FAILED', message: 'Falha ao atualizar OS.' },
      });
      return;
    }

    res.json({
      success: true,
      data: {
        orderNumber,
        previousStatus: currentStatus,
        newStatus,
        formatContext: getFormatContext(req.auth?.companyCountry),
      },
    });
  } catch (error) {
    console.error('Bot Update order status error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Erro ao atualizar status da OS.' },
    });
  }
});

export default router;
