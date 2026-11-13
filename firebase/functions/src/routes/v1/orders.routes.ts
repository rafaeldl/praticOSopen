/**
 * Orders Routes (/v1/orders with an API key, /v1/app/orders with a Firebase
 * ID token). The web app writes money, status and items here, so there is a
 * single version of the rules (docs/WEB_API.md):
 *
 * - every write that reads the order runs in a Firestore transaction and the
 *   permission is checked again on the fresh order (`guard`);
 * - totals are computed here from the items; a client never sends one;
 * - `expectedUpdatedAt` (optional) refuses a write over a newer save (409);
 * - responses carry no money for who lacks `viewPrices` (order-projection.ts).
 *
 * The Flutter app does not call these routes (only `share` and `charges`,
 * mounted next to them), so they can change without breaking installed apps.
 */

import { ensurePlanCapacity } from '../../middleware/plan-limit.middleware';
import { Router, Request, Response } from 'express';
import { AuthenticatedRequest, Order, OrderStatus } from '../../models/types';
import { getUserAggr, getCompanyAggr } from '../../middleware/company.middleware';
import {
  can,
  canChangeOrderHold,
  canChangeOrderStage,
  canChangeOrderStatus,
  canCreateOrderWithStatus,
  canDeleteOrder,
  canEditOrderMainFields,
  canGiveDiscount,
  canReceiveOnOrder,
  canRemoveOrderHold,
  canSeeOrder,
  companyUsesFinancial,
  forbidden,
  requireOrderAccess,
} from '../../middleware/app-permission.middleware';
import * as orderService from '../../services/order.service';
import * as customerService from '../../services/customer.service';
import * as deviceService from '../../services/device.service';
import * as financeService from '../../services/order-finance.service';
import * as catalogService from '../../services/catalog.service';
import { deleteOrder } from '../../services/order-delete.service';
import { removeOrderHold, setOrderHold } from '../../services/order-hold.service';
import { setOrderStage } from '../../services/order-stage.service';
import { memberAggr } from '../../services/membership.service';
import { projectOrder, projectOrderSummary } from '../../services/order-projection';
import { forbiddenOrder, OrderRuleError } from '../../services/order-errors';
import { toHttpError } from '../../services/asaas/errors';
import {
  validateInput,
  createOrderSchema,
  updateOrderSchema,
  addOrderServiceSchema,
  addOrderProductSchema,
  addOrderItemSchema,
  updateOrderItemSchema,
  receivePaymentSchema,
  discountSchema,
  markPaidSchema,
  orderHoldSchema,
  orderStageSchema,
  receiptFileSchema,
  listOrdersQuerySchema,
  orderVersionSchema,
} from '../../utils/validation.utils';
import { z } from 'zod';

const router: Router = Router();

// ============================================================================
// Helpers
// ============================================================================

type Handler = (req: AuthenticatedRequest, res: Response, companyId: string) => Promise<void>;

/** Company from the auth context, errors in the API format. */
function route(fallback: string, handler: Handler) {
  return async (req: Request, res: Response): Promise<void> => {
    const authReq = req as AuthenticatedRequest;
    const companyId = authReq.auth?.companyId ?? authReq.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Company context required' } });
      return;
    }
    try {
      await handler(authReq, res, companyId);
    } catch (error) {
      sendOrderError(res, error, fallback);
    }
  };
}

export function sendOrderError(res: Response, error: unknown, fallback: string): void {
  if (error instanceof OrderRuleError) {
    res.status(error.httpStatus).json({ success: false, error: { code: error.code, message: error.message, ...error.details } });
    return;
  }
  const http = toHttpError(error, fallback);
  if (http.status === 500) console.error(`${fallback}:`, (error as Error)?.name, (error as Error)?.message);
  res.status(http.status).json(http.body);
}

function param(req: Request, name: string): string {
  const raw = req.params[name];
  return String(Array.isArray(raw) ? raw[0] : raw);
}

function notFound(res: Response, message = 'Order not found'): void {
  res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message } });
}

function validationError(res: Response, errors: string[]): void {
  res.status(400).json({ success: false, error: { code: 'VALIDATION_ERROR', message: errors.join(', ') } });
}

/** Body, or the query string for DELETE (some proxies drop a DELETE body). */
function expectedUpdatedAtOf(req: Request): string | undefined {
  const raw = (req.body as { expectedUpdatedAt?: unknown } | undefined)?.expectedUpdatedAt ?? req.query.expectedUpdatedAt;
  if (raw === undefined) return undefined;
  const parsed = orderVersionSchema.safeParse(raw);
  if (!parsed.success) throw new OrderRuleError('VALIDATION_ERROR', 400, 'expectedUpdatedAt must be the version of the order');
  return parsed.data;
}

const showPricesOf = (req: AuthenticatedRequest, res: Response) => can(req, res, 'viewPrices');

/** Guard: the user sees the order (same as firestore.rules read). */
const seeGuard = (req: AuthenticatedRequest) => (order: Order) => {
  if (!canSeeOrder(req, order)) throw forbiddenOrder();
};

/** Guard: items and main fields (supervisor and technician only on quotes). */
const mainFieldsGuard = (req: AuthenticatedRequest) => (order: Order) => {
  if (!canEditOrderMainFields(req, order)) throw forbiddenOrder();
};

/** Guard: register money received ("Receber"). */
async function receiveGuard(req: AuthenticatedRequest, res: Response) {
  const useFinancial = await companyUsesFinancial(req, res);
  return (order: Order) => {
    if (!canReceiveOnOrder(req, order, useFinancial)) throw forbiddenOrder('Not allowed to receive on this order');
  };
}

/**
 * Guard of the proof of a payment (pay.order.attach-proof): who receives on the
 * order, on an order that takes money (not a quote nor canceled), as the app.
 */
async function proofGuard(req: AuthenticatedRequest, res: Response) {
  const receive = await receiveGuard(req, res);
  return (order: Order) => {
    receive(order);
    if (order.status === 'quote' || order.status === 'canceled') throw new OrderRuleError('ORDER_STATUS', 409, 'This order does not take payments');
  };
}

/** The app attaches a proof only with attachPhotos (payment_management_screen). */
const PROOF_PERMISSION = "Permission 'attachPhotos' is required";

/** Guard: discounts and money of others (financial access) on an order the user sees. */
async function financialGuard(req: AuthenticatedRequest, res: Response) {
  const allowed = canGiveDiscount(req, await companyUsesFinancial(req, res));
  return (order: Order) => {
    if (!allowed || !canSeeOrder(req, order)) throw forbiddenOrder('Financial access is required');
  };
}

async function sendOrder(req: AuthenticatedRequest, res: Response, order: Order, extra: Record<string, unknown> = {}, status = 200) {
  res.status(status).json({ success: true, data: { ...extra, order: projectOrder(order, await showPricesOf(req, res)) } });
}

// ============================================================================
// Read
// ============================================================================

/**
 * GET /orders
 * Every order for who has `viewAllOrders`; consultant and technician get the
 * ones they created (same as firestore.rules). Cursor pagination.
 */
router.get('/', route('Failed to list orders', async (req, res, companyId) => {
  const seesAll = await can(req, res, 'viewAllOrders');
  const seesOwn = (await can(req, res, 'viewOwnOrders')) || (await can(req, res, 'viewAssignedOrders'));
  if (!seesAll && !seesOwn) return forbidden(res, 'Not allowed to list orders');

  const validation = validateInput(listOrdersQuerySchema, req.query);
  if (!validation.success) return validationError(res, validation.errors);
  const query = validation.data;

  const showPrices = await showPricesOf(req, res);
  // Search by number (the list did not load it): only the field's own index, then who may see each one.
  if (query.number !== undefined) {
    const found = (await orderService.findOrdersByNumber(companyId, query.number)).filter((order) => canSeeOrder(req, order));
    res.json({ success: true, data: found.map((o) => projectOrderSummary(o, showPrices)), pagination: { limit: query.limit, hasMore: false, nextCursor: null } });
    return;
  }
  // The technician asking for their own assigned orders gets them whoever created them
  // (firestore.rules isOrderAssignee; indexes assignedTo.id + status/createdAt).
  const userId = req.userContext?.userId;
  const technician = !seesAll && !!userId && req.userContext?.role === 'technician';
  const assignedToSelf = technician && query.assignedTo === userId;
  // Without an owner filter, the technician gets what they created and what was given to them (Todas, Paradas…).
  const createdOrAssigned = technician && query.assignedTo === undefined;
  const result = await orderService.listOrders(companyId, {
    status: query.status as OrderStatus[] | undefined,
    customerId: query.customerId,
    deviceId: query.deviceId,
    assignedTo: query.assignedTo,
    createdById: seesAll || assignedToSelf || createdOrAssigned ? undefined : userId,
    createdOrAssignedTo: createdOrAssigned ? userId : undefined,
    startDate: query.startDate,
    endDate: query.endDate,
    limit: query.limit,
    offset: query.offset,
    cursor: query.cursor,
    sort: query.sort,
    direction: query.direction,
  });

  res.json({
    success: true,
    data: result.data.map((o) => projectOrderSummary(o, showPrices)),
    pagination: {
      limit: query.limit,
      ...(query.offset !== undefined ? { offset: query.offset } : {}),
      ...(result.total !== undefined ? { total: result.total } : {}),
      hasMore: result.hasMore,
      nextCursor: result.nextCursor ?? null,
    },
  });
}));

/** GET /orders/:id */
router.get('/:id', requireOrderAccess(), route('Failed to get order', async (req, res, companyId) => {
  const order = await orderService.getOrder(companyId, param(req, 'id'));
  if (!order) return notFound(res);
  res.json({ success: true, data: projectOrder(order, await showPricesOf(req, res)) });
}));

// ============================================================================
// Create, update, delete
// ============================================================================

/** POST /orders */
router.post('/', route('Failed to create order', async (req, res, companyId) => {
  if (!(await can(req, res, 'createOrder'))) return forbidden(res, "Permission 'createOrder' is required");

  const validation = validateInput(createOrderSchema, req.body);
  if (!validation.success) return validationError(res, validation.errors);

  if (!canCreateOrderWithStatus(req, validation.data.status ?? 'quote')) {
    return forbidden(res, 'Status not allowed on a new order');
  }
  const ownPrice = [...(validation.data.services ?? []), ...(validation.data.products ?? [])]
    .some((item) => item.value !== undefined || ('total' in item && item.total !== undefined));
  if (ownPrice && !(await can(req, res, 'editPrices'))) return forbidden(res, "Permission 'editPrices' is required");
  // Orders of the month (soft limit, #723): only a new order; one already open is never stopped.
  if (!(await ensurePlanCapacity(res, companyId, 'order'))) return;

  const { customerId, deviceId, deviceIds, ...orderData } = validation.data;
  const customer = await customerService.getCustomer(companyId, customerId);
  if (!customer) return notFound(res, 'Customer not found');

  const ids = [...new Set([...(deviceId ? [deviceId] : []), ...(deviceIds ?? [])])];
  const devices = [];
  for (const id of ids) {
    const device = await deviceService.getDevice(companyId, id);
    if (!device) return notFound(res, 'Device not found');
    devices.push(deviceService.toDeviceAggr(device));
  }

  const result = await orderService.createOrder(
    companyId,
    {
      ...orderData,
      customerId,
      customer: customerService.toCustomerAggr(customer),
      deviceId: devices[0]?.id,
      device: devices[0],
      devices,
    },
    getUserAggr(req),
    getCompanyAggr(req),
  );

  res.status(result.existing ? 200 : 201).json({ success: true, data: { id: result.id, number: result.number, status: result.status } });
}));

/**
 * PATCH /orders/:id
 * Status (flow per role), dates (main fields: supervisor and technician only
 * on quotes), assignee (`assignOrder`, name taken from the member).
 */
router.patch('/:id', requireOrderAccess(), route('Failed to update order', async (req, res, companyId) => {
  if (!(await can(req, res, 'editOrder'))) return forbidden(res, "Permission 'editOrder' is required");
  const validation = validateInput(updateOrderSchema, req.body);
  if (!validation.success) return validationError(res, validation.errors);
  const { status, dueDate, scheduledDate, assignedTo, expectedUpdatedAt } = validation.data;

  let assignee: { id: string; name: string } | null | undefined;
  if (assignedTo !== undefined) {
    if (!(await can(req, res, 'assignOrder'))) return forbidden(res, "Permission 'assignOrder' is required");
    assignee = assignedTo === null ? null : await memberAggr(companyId, assignedTo);
    if (assignee === null && assignedTo !== null) {
      throw new OrderRuleError('INVALID_ASSIGNEE', 400, 'The assignee is not a member of the company');
    }
  }

  const updated = await orderService.updateOrder(
    companyId,
    param(req, 'id'),
    { status, dueDate, scheduledDate, assignedTo: assignee },
    getUserAggr(req),
    {
      expectedUpdatedAt,
      guard: (order) => {
        if (!canSeeOrder(req, order)) throw forbiddenOrder();
        if (status !== undefined && !canChangeOrderStatus(req, order, status)) throw forbiddenOrder('Status change not allowed');
        if ((dueDate !== undefined || scheduledDate !== undefined) && !canEditOrderMainFields(req, order)) {
          throw forbiddenOrder('Dates of this order cannot be changed');
        }
      },
    },
  );
  if (!updated) return notFound(res);
  await sendOrder(req, res, updated, { id: updated.id, updated: true });
}));

/**
 * DELETE /orders/:id
 * Same rule as firestore.rules (contract order-delete.json); see order-delete.service.
 */
router.delete('/:id', requireOrderAccess(), route('Failed to delete order', async (req, res, companyId) => {
  const id = param(req, 'id');
  const deleted = await deleteOrder(companyId, id, (order) => {
    if (!canDeleteOrder(req, order)) throw forbiddenOrder('Not allowed to delete this order');
  });
  if (!deleted) return notFound(res);
  res.json({ success: true, data: { id, deleted: true } });
}));

// ============================================================================
// Items
// ============================================================================

/** POST /orders/:id/items: a service or product of the catalog. */
router.post('/:id/items', requireOrderAccess(), route('Failed to add item', async (req, res, companyId) => {
  if (!(await can(req, res, 'editOrder'))) return forbidden(res, "Permission 'editOrder' is required");
  const validation = validateInput(addOrderItemSchema, req.body);
  if (!validation.success) return validationError(res, validation.errors);
  const item = validation.data;
  if ((item.value !== undefined || item.total !== undefined) && !(await can(req, res, 'editPrices'))) {
    return forbidden(res, "Permission 'editPrices' is required");
  }
  // Without catalogId: an item without catalog (description, own value or none).
  let catalog = null;
  if (item.catalogId) {
    catalog = item.kind === 'service'
      ? await catalogService.getService(companyId, item.catalogId)
      : await catalogService.getProduct(companyId, item.catalogId);
    if (!catalog) return notFound(res, 'Catalog item not found');
  }

  const result = await orderService.addOrderItem(
    companyId,
    param(req, 'id'),
    { kind: item.kind, catalog, value: item.value, quantity: item.quantity, total: item.total, description: item.description, deviceId: item.deviceId },
    getUserAggr(req),
    { guard: mainFieldsGuard(req), expectedUpdatedAt: item.expectedUpdatedAt },
  );
  if (!result) return notFound(res);
  await sendOrder(req, res, result.order, { itemId: result.itemId }, 201);
}));

/**
 * PATCH /orders/:id/items/:itemId. Only the description: who sees the order
 * (supervisor and technician keep notes after approval). Anything else: main
 * fields. Own value or line total: `editPrices`.
 */
router.patch('/:id/items/:itemId', requireOrderAccess(), route('Failed to update item', async (req, res, companyId) => {
  if (!(await can(req, res, 'editOrder'))) return forbidden(res, "Permission 'editOrder' is required");
  const validation = validateInput(updateOrderItemSchema, req.body);
  if (!validation.success) return validationError(res, validation.errors);
  const { expectedUpdatedAt, ...patch } = validation.data;
  if ((patch.value !== undefined || patch.total !== undefined) && !(await can(req, res, 'editPrices'))) {
    return forbidden(res, "Permission 'editPrices' is required");
  }
  const onlyNotes = Object.keys(patch).every((key) => key === 'description');
  const result = await orderService.updateOrderItem(companyId, param(req, 'id'), param(req, 'itemId'), patch, getUserAggr(req), {
    guard: onlyNotes ? seeGuard(req) : mainFieldsGuard(req),
    expectedUpdatedAt,
  });
  if (!result) return notFound(res);
  await sendOrder(req, res, result.order, { itemId: result.itemId });
}));

/** DELETE /orders/:id/items/:itemId */
router.delete('/:id/items/:itemId', requireOrderAccess(), route('Failed to remove item', async (req, res, companyId) => {
  if (!(await can(req, res, 'editOrder'))) return forbidden(res, "Permission 'editOrder' is required");
  const result = await orderService.removeOrderItem(companyId, param(req, 'id'), param(req, 'itemId'), getUserAggr(req), {
    guard: mainFieldsGuard(req),
    expectedUpdatedAt: expectedUpdatedAtOf(req),
  });
  if (!result) return notFound(res);
  await sendOrder(req, res, result.order, { itemId: result.itemId });
}));

/**
 * POST /orders/:id/services (bot, MCP and integrations): same rules as
 * POST /:id/items, answer kept as `{success, newTotal}`.
 */
router.post('/:id/services', requireOrderAccess(), route('Failed to add service', async (req, res, companyId) => {
  if (!(await can(req, res, 'editOrder'))) return forbidden(res, "Permission 'editOrder' is required");
  const validation = validateInput(addOrderServiceSchema, req.body);
  if (!validation.success) return validationError(res, validation.errors);
  if (validation.data.value !== undefined && !(await can(req, res, 'editPrices'))) {
    return forbidden(res, "Permission 'editPrices' is required");
  }
  const result = await orderService.addOrderService(
    companyId, param(req, 'id'), validation.data.serviceId, validation.data.value, validation.data.description, getUserAggr(req),
    { deviceId: validation.data.deviceId, guard: mainFieldsGuard(req) },
  );
  if (!result.success) return notFound(res, 'Order or service not found');
  const showPrices = await showPricesOf(req, res);
  res.json({ success: true, data: { success: true, ...(showPrices ? { newTotal: result.newTotal } : {}), itemId: result.itemId } });
}));

/** POST /orders/:id/products (bot, MCP and integrations). */
router.post('/:id/products', requireOrderAccess(), route('Failed to add product', async (req, res, companyId) => {
  if (!(await can(req, res, 'editOrder'))) return forbidden(res, "Permission 'editOrder' is required");
  const validation = validateInput(addOrderProductSchema, req.body);
  if (!validation.success) return validationError(res, validation.errors);
  const data = validation.data;
  if ((data.value !== undefined || data.total !== undefined) && !(await can(req, res, 'editPrices'))) {
    return forbidden(res, "Permission 'editPrices' is required");
  }
  const result = await orderService.addOrderProduct(
    companyId, param(req, 'id'), data.productId, data.quantity, data.value, data.description, getUserAggr(req),
    { total: data.total, deviceId: data.deviceId, guard: mainFieldsGuard(req) },
  );
  if (!result.success) return notFound(res, 'Order or product not found');
  const showPrices = await showPricesOf(req, res);
  res.json({ success: true, data: { success: true, ...(showPrices ? { newTotal: result.newTotal } : {}), itemId: result.itemId } });
}));

// ============================================================================
// Money
// ============================================================================

/**
 * POST /orders/:id/payments: money received, with when, how and the proof.
 * Who: canReceiveOnOrder (financial access, or the consultant on their own order).
 */
router.post('/:id/payments', requireOrderAccess(), route('Failed to add payment', async (req, res, companyId) => {
  const validation = validateInput(receivePaymentSchema, req.body);
  if (!validation.success) {
    const discount = (req.body as { type?: unknown } | undefined)?.type === 'discount';
    return validationError(res, discount ? ['type: a discount goes to POST /:id/discounts'] : validation.errors);
  }
  const data = validation.data;
  if (data.receiptFile && !(await can(req, res, 'attachPhotos'))) return forbidden(res, PROOF_PERMISSION);
  const guard = await receiveGuard(req, res);
  const result = await orderService.addPayment(companyId, param(req, 'id'), data.amount, 'payment', data.description, getUserAggr(req), {
    guard, paidAt: data.paidAt, paymentMethod: data.paymentMethod, receiptFile: data.receiptFile,
    clientTransactionId: data.clientTransactionId, expectedUpdatedAt: data.expectedUpdatedAt,
  });
  if (!result) return notFound(res);
  const { order, ...summary } = result;
  await sendOrder(req, res, order, summary);
}));

/** POST /orders/:id/payments/mark-paid: books what is left and marks it paid. */
router.post('/:id/payments/mark-paid', requireOrderAccess(), route('Failed to mark as paid', async (req, res, companyId) => {
  const validation = validateInput(markPaidSchema, req.body ?? {});
  if (!validation.success) return validationError(res, validation.errors);
  const result = await financeService.markOrderPaid(companyId, param(req, 'id'), validation.data, getUserAggr(req), {
    guard: await receiveGuard(req, res),
  });
  if (!result) return notFound(res);
  await sendOrder(req, res, result.order, { transactionId: result.transactionId });
}));

/**
 * POST /orders/:id/payments/reset: removes every manual payment and discount
 * (Asaas payments stay). It also removes discounts, so financial access.
 */
router.post('/:id/payments/reset', requireOrderAccess(), route('Failed to reset payments', async (req, res, companyId) => {
  const result = await financeService.resetOrderPayments(companyId, param(req, 'id'), getUserAggr(req), {
    guard: await financialGuard(req, res),
  });
  if (!result) return notFound(res);
  await sendOrder(req, res, result.order);
}));

/** DELETE /orders/:id/payments/:transactionId (not Asaas, not a share of a receipt). */
router.delete('/:id/payments/:transactionId', requireOrderAccess(), route('Failed to remove payment', async (req, res, companyId) => {
  const result = await financeService.removeOrderTransaction(
    companyId, param(req, 'id'), param(req, 'transactionId'), 'payment', getUserAggr(req), { guard: await receiveGuard(req, res) },
  );
  if (!result) return notFound(res);
  await sendOrder(req, res, result.order);
}));

/** PUT /orders/:id/payments/:transactionId/receipt: attaches (or replaces) the proof. */
router.put('/:id/payments/:transactionId/receipt', requireOrderAccess(), route('Failed to attach receipt', async (req, res, companyId) => {
  if (!(await can(req, res, 'attachPhotos'))) return forbidden(res, PROOF_PERMISSION);
  const validation = validateInput(z.object({ receiptFile: receiptFileSchema }), req.body);
  if (!validation.success) return validationError(res, validation.errors);
  const result = await financeService.setTransactionReceipt(
    companyId, param(req, 'id'), param(req, 'transactionId'), validation.data.receiptFile, getUserAggr(req),
    { guard: await proofGuard(req, res) },
  );
  if (!result) return notFound(res);
  await sendOrder(req, res, result.order);
}));

/** DELETE /orders/:id/payments/:transactionId/receipt */
router.delete('/:id/payments/:transactionId/receipt', requireOrderAccess(), route('Failed to remove receipt', async (req, res, companyId) => {
  if (!(await can(req, res, 'attachPhotos'))) return forbidden(res, PROOF_PERMISSION);
  const result = await financeService.setTransactionReceipt(
    companyId, param(req, 'id'), param(req, 'transactionId'), null, getUserAggr(req), { guard: await proofGuard(req, res) },
  );
  if (!result) return notFound(res);
  await sendOrder(req, res, result.order);
}));

/** POST /orders/:id/discounts: financial access only, never above what is left. */
router.post('/:id/discounts', requireOrderAccess(), route('Failed to add discount', async (req, res, companyId) => {
  const validation = validateInput(discountSchema, req.body);
  if (!validation.success) return validationError(res, validation.errors);
  const result = await orderService.addPayment(
    companyId, param(req, 'id'), validation.data.amount, 'discount', validation.data.description, getUserAggr(req),
    { guard: await financialGuard(req, res), clientTransactionId: validation.data.clientTransactionId, expectedUpdatedAt: validation.data.expectedUpdatedAt },
  );
  if (!result) return notFound(res);
  const { order, ...summary } = result;
  await sendOrder(req, res, order, summary);
}));

/** DELETE /orders/:id/discounts: every discount (also one set without a transaction). */
router.delete('/:id/discounts', requireOrderAccess(), route('Failed to remove discounts', async (req, res, companyId) => {
  const result = await financeService.removeOrderDiscounts(companyId, param(req, 'id'), getUserAggr(req), {
    guard: await financialGuard(req, res),
  });
  if (!result) return notFound(res);
  await sendOrder(req, res, result.order);
}));

/** DELETE /orders/:id/discounts/:transactionId */
router.delete('/:id/discounts/:transactionId', requireOrderAccess(), route('Failed to remove discount', async (req, res, companyId) => {
  const result = await financeService.removeOrderTransaction(
    companyId, param(req, 'id'), param(req, 'transactionId'), 'discount', getUserAggr(req), { guard: await financialGuard(req, res) },
  );
  if (!result) return notFound(res);
  await sendOrder(req, res, result.order);
}));

// ============================================================================
// On hold ("parada")
// ============================================================================

/** POST /orders/:id/hold: marks (or changes the reason). Not the consultant; only approved/progress. */
router.post('/:id/hold', requireOrderAccess(), route('Failed to mark on hold', async (req, res, companyId) => {
  const validation = validateInput(orderHoldSchema, req.body);
  if (!validation.success) return validationError(res, validation.errors);
  const order = await setOrderHold(companyId, param(req, 'id'), validation.data, getUserAggr(req), {
    guard: (fresh) => {
      if (!canChangeOrderHold(req, fresh)) throw forbiddenOrder('Not allowed to mark this order on hold');
    },
  });
  if (!order) return notFound(res);
  await sendOrder(req, res, order);
}));

/** DELETE /orders/:id/hold: resumes; without a mark it changes nothing. */
router.delete('/:id/hold', requireOrderAccess(), route('Failed to resume', async (req, res, companyId) => {
  const order = await removeOrderHold(companyId, param(req, 'id'), getUserAggr(req), {
    guard: (fresh) => {
      if (!canRemoveOrderHold(req, fresh)) throw forbiddenOrder('Not allowed to resume this order');
    },
  });
  if (!order) return notFound(res);
  await sendOrder(req, res, order);
}));

// ============================================================================
// Work stage (docs/WORK_STAGES.md)
// ============================================================================

/** PUT /orders/:id/stage: moves to a stage or reorders it. An approved order starts (`progress`). */
router.put('/:id/stage', requireOrderAccess(), route('Failed to set the stage', async (req, res, companyId) => {
  const validation = validateInput(orderStageSchema, req.body);
  if (!validation.success) return validationError(res, validation.errors);
  const order = await setOrderStage(companyId, param(req, 'id'), validation.data, getUserAggr(req), {
    guard: (fresh) => {
      if (!canChangeOrderStage(req, fresh)) throw forbiddenOrder('Not allowed to change the stage of this order');
    },
    canStart: (fresh) => canChangeOrderStatus(req, fresh, 'progress'),
  });
  if (!order) return notFound(res);
  await sendOrder(req, res, order);
}));

export default router;
