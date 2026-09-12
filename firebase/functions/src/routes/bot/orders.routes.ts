/**
 * Bot Orders Routes
 * Endpoints for order management via Bot
 */

import { Router, Response } from 'express';
import { AuthenticatedRequest, OrderStatus } from '../../models/types';
import * as orderService from '../../services/order.service';
import { getUserAggr } from '../../middleware/company.middleware';
import { buildOrderDetail } from '../../utils/bot-response.utils';

const router: Router = Router();

// Valid status transitions
const validTransitions: Record<string, string[]> = {
  quote: ['approved', 'canceled'],
  approved: ['progress', 'done', 'canceled'],
  progress: ['done', 'canceled'],
  done: [],
  canceled: [],
};

// Default stays at 10: the WhatsApp bot never sends `limit` and its token budget
// was sized for 10 orders. MCP clients always send an explicit limit.
const LIST_DEFAULT_LIMIT = 10;
const LIST_MAX_LIMIT = 50;
// paginatedQuery reads `offset` docs to find the cursor, so it must be bounded too
const LIST_MAX_OFFSET = 1000;

/**
 * Parse a query param as a bounded integer. Anything that is not a plain
 * integer >= min (non-numeric, decimal, repeated param) falls back to `fallback`.
 */
function parseBoundedInt(value: unknown, fallback: number, min: number, max: number): number {
  if (typeof value !== 'string' || !/^\d+$/.test(value)) return fallback;
  const parsed = Number(value);
  if (parsed < min) return fallback;
  return Math.min(parsed, max);
}

/**
 * GET /api/bot/orders/list?status=&limit=&offset=
 * List orders for the bot with formatted output.
 * limit: 1-50 (default 10); offset: 0-1000 (default 0). Invalid values use the default.
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
    const limit = parseBoundedInt(req.query.limit, LIST_DEFAULT_LIMIT, 1, LIST_MAX_LIMIT);
    const offset = parseBoundedInt(req.query.offset, 0, 0, LIST_MAX_OFFSET);

    const result = await orderService.listOrders(companyId, {
      status,
      limit,
      offset,
    });

    // Allowlist: only fields the bot needs — saves ~75% tokens vs spreading everything
    // Bot should use GET /bot/orders/{NUM}/details for full order data + photos
    const lightOrders = result.data.map(order => ({
      number: order.number,
      status: order.status,
      customer: order.customer ? { name: order.customer.name } : null,
      device: order.device ? { name: order.device.name, serial: order.device.serial } : null,
      total: order.total,
      dueDate: order.dueDate,
      scheduledDate: order.scheduledDate,
      createdAt: order.createdAt,
      photosCount: order.photos?.length || 0,
      deviceCount: order.devices?.length || (order.device ? 1 : 0),
    }));

    res.json({
      success: true,
      data: {
        count: result.total,
        orders: lightOrders,
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

    const freshOrder = await orderService.getOrderByNumber(companyId, orderNumber);
    const detail = await buildOrderDetail(freshOrder!, companyId, req.auth?.companyCountry, updatedBy);
    res.json({ success: true, data: { ...detail, previousStatus: currentStatus, newStatus } });
  } catch (error) {
    console.error('Bot Update order status error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Erro ao atualizar status da OS.' },
    });
  }
});

export default router;
