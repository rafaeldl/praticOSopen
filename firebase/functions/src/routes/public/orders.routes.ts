/**
 * Public Orders Routes
 * Public endpoints for customer order tracking via magic link
 */

import { Router, Response } from 'express';
import { AuthenticatedRequest, Order, Company, OrderForm, DeviceAggr } from '../../models/types';
import { shareTokenAuth, requireSharePermission } from '../../middleware/share-token.middleware';
import { getTenantCollection, db } from '../../services/firestore.service';
import * as shareTokenService from '../../services/share-token.service';
import * as commentService from '../../services/comment.service';
import * as orderService from '../../services/order.service';
import * as formsService from '../../services/forms.service';
import * as notificationService from '../../services/notification.service';
import { timestampToDate } from '../../utils/date.utils';
import { maskName, maskPhone, maskSerial } from '../../utils/mask.utils';
import * as chargeService from '../../services/asaas/charge.service';
import * as connectionService from '../../services/asaas/connection.service';
import { OrderCharge, ChargeStatus } from '../../models/asaas.types';

const router: Router = Router();

/**
 * Fetch segment custom labels for the magic link page.
 * Returns a map like: { 'device._entity': { 'pt-BR': 'Veículo', ... }, ... }
 */
async function getSegmentLabels(segmentId?: string): Promise<Record<string, Record<string, string>> | null> {
  if (!segmentId) return null;
  try {
    const segmentDoc = await db.collection('segments').doc(segmentId).get();
    if (!segmentDoc.exists) return null;
    const data = segmentDoc.data();
    const customFields = data?.customFields as Array<{ key: string; type: string; labels: Record<string, string> }> | undefined;
    if (!customFields?.length) return null;

    const labels: Record<string, Record<string, string>> = {};
    for (const field of customFields) {
      if (field.type === 'label' && field.labels) {
        labels[field.key] = field.labels;
      }
    }
    return Object.keys(labels).length > 0 ? labels : null;
  } catch (error) {
    console.error('Failed to fetch segment labels:', error);
    return null;
  }
}

/**
 * Charge fields the customer may see on the magic link.
 * Never expose Asaas ids, audit fields or anything about the Asaas account.
 */
interface PublicOrderCharge {
  status: ChargeStatus;
  value: number;
  dueDate: string;
  mode: OrderCharge['mode'];
  installmentCount?: number;
  invoiceUrl: string;
}

const OPEN_CHARGE_STATUSES: ChargeStatus[] = ['pending', 'overdue'];

/**
 * Status shown to the customer. An open card installment plan with paid
 * installments was already charged on the card, so it is shown as 'paid'
 * (avoids a pay button pointing at an invoice that is already paid).
 */
function publicChargeStatus(charge: OrderCharge): ChargeStatus | null {
  if (charge.status === 'paid') return 'paid';
  if (!OPEN_CHARGE_STATUSES.includes(charge.status)) return null;
  if ((charge.paidAsaasPaymentIds?.length ?? 0) > 0) return 'paid';
  return charge.status;
}

function toPublicCharge(charge: OrderCharge | null, asaasConnected: boolean): PublicOrderCharge | null {
  if (!charge) return null;
  const status = publicChargeStatus(charge);
  if (!status) return null;
  // After Asaas is disconnected, payments of an open charge would never be
  // booked on the order, so the customer must not be offered to pay it.
  if (status !== 'paid' && !asaasConnected) return null;
  return {
    status,
    value: charge.value,
    dueDate: charge.dueDate,
    mode: charge.mode,
    ...(charge.mode === 'cardInstallments' && charge.installmentCount
      ? { installmentCount: charge.installmentCount }
      : {}),
    invoiceUrl: charge.invoiceUrl,
  };
}

/**
 * Load the open (or latest paid) Asaas charge for the magic link.
 * A failure here must not break the order page, so it degrades to null.
 */
async function getPublicCharge(companyId: string, orderId: string): Promise<PublicOrderCharge | null> {
  try {
    const [charge, settings] = await Promise.all([
      chargeService.getOpenOrLatestPaidCharge(companyId, orderId),
      connectionService.getPaymentSettings(companyId),
    ]);
    return toPublicCharge(charge, settings.asaasConnected === true);
  } catch (error) {
    console.error('Failed to load order charge:', error instanceof Error ? error.message : 'unknown error');
    return null;
  }
}

/**
 * Whether the magic link may show prices, totals, payments and charges.
 * Only an explicit `useFinancial: false` hides them (absent = show, as before).
 */
export function companyShowsValues(company: Pick<Company, 'useFinancial'> | null | undefined): boolean {
  return company?.useFinancial !== false;
}

/**
 * Devices of the order with an opaque key ("d1", "d2", ...) instead of the
 * Firestore id. The page only needs the key to group items by device, so the
 * same key replaces `deviceId` on services, products and forms.
 */
export function buildPublicDevices(order: Pick<Order, 'device' | 'devices'>): {
  devices: Array<{ id: string; name?: string; serial?: string | null }>;
  keyOf: (deviceId?: string | null) => string | null;
} {
  const list: DeviceAggr[] = order.devices?.length
    ? order.devices
    : (order.device ? [order.device] : []);
  const keys = new Map<string, string>();
  const devices = list.map((d, index) => {
    const key = `d${index + 1}`;
    if (d.id && !keys.has(d.id)) keys.set(d.id, key);
    return { id: key, name: d.name, serial: maskSerial(d.serial) };
  });
  return {
    devices,
    keyOf: (deviceId) => (deviceId ? keys.get(deviceId) ?? null : null),
  };
}

export interface PublicFormItem {
  label: string;
  value: string | number | boolean | string[] | null;
  photos: string[];
}

export interface PublicForm {
  title: string;
  deviceId: string | null;
  items: PublicFormItem[];
}

function publicAnswer(value: unknown): PublicFormItem['value'] {
  if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') return value;
  if (Array.isArray(value)) return value.filter((v): v is string => typeof v === 'string');
  return null;
}

/**
 * Completed checklists, reduced to question, answer and photos.
 * Template ids, item ids, status, dates and who filled them never leave.
 * Unanswered questions without photos are left out.
 */
export function toPublicForms(
  forms: OrderForm[],
  keyOf: (deviceId?: string | null) => string | null,
): PublicForm[] {
  return forms
    .filter((f) => f.status === 'completed')
    .map((f) => {
      const responses = f.responses ?? [];
      const items = (f.items ?? []).flatMap((item) => {
        const response = responses.find((r) => r.itemId === item.id);
        const value = publicAnswer(response?.value);
        const photos = (response?.photoUrls ?? []).filter((u) => typeof u === 'string' && u.length > 0);
        const answered = value !== null && value !== '' && !(Array.isArray(value) && value.length === 0);
        if (!answered && photos.length === 0) return [];
        return [{ label: item.label, value: answered ? value : null, photos }];
      });
      return { title: f.title, deviceId: keyOf(f.deviceId), items };
    })
    .filter((f) => f.items.length > 0);
}

/**
 * Load the order checklists for the magic link.
 * A failure here must not break the order page, so it degrades to [].
 */
async function getOrderFormsSafe(companyId: string, orderId: string): Promise<OrderForm[]> {
  try {
    return await formsService.listOrderForms(companyId, orderId);
  } catch (error) {
    console.error('Failed to load order forms:', error instanceof Error ? error.message : 'unknown error');
    return [];
  }
}

/**
 * GET /public/orders/:token
 * View order details via share token
 */
router.get('/:token', shareTokenAuth, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { companyId, orderId, customer } = req.shareTokenAuth!;

    // Get order
    const order = await orderService.getOrder(companyId, orderId) as Order | null;
    if (!order) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Order not found' },
      });
      return;
    }

    // Get company info for display
    const companyDoc = await db.collection('companies').doc(companyId).get();
    const company = companyDoc.exists ? companyDoc.data() as Company : null;

    // With "Valores e cobrança" off the page becomes a service report:
    // no prices, totals, payments or charges leave the server.
    const showValues = companyShowsValues(company);

    // Get customer-visible comments
    const [comments, charge, forms] = await Promise.all([
      commentService.getCustomerVisibleComments(companyId, orderId),
      showValues ? getPublicCharge(companyId, orderId) : Promise.resolve(null),
      getOrderFormsSafe(companyId, orderId),
    ]);

    const { devices, keyOf } = buildPublicDevices(order);

    const values = showValues ? {
      total: order.total,
      discount: order.discount,
      paidAmount: order.paidAmount,
      remainingBalance: orderService.calculateRemainingBalance(order),
    } : {};

    // Prepare masked customer data (LGPD compliance)
    const maskedCustomer = {
      name: maskName(order.customer?.name || customer.name),
      phone: maskPhone(order.customer?.phone || customer.phone),
    };

    res.json({
      success: true,
      data: {
        order: {
          // IDs removed for LGPD compliance
          number: order.number,
          customer: maskedCustomer,
          device: order.device ? {
            name: order.device.name,
            serial: maskSerial(order.device.serial),
            // Other internal device fields removed
          } : null,
          devices,
          services: order.services?.map((s) => ({
            name: s.service?.name ?? s.description ?? '',
            ...(showValues ? { value: s.value } : {}),
            description: s.description,
            deviceId: keyOf(s.deviceId),
          })),
          products: order.products?.map((p) => ({
            name: p.product?.name ?? p.description ?? '',
            ...(showValues ? { value: p.value } : {}),
            quantity: p.quantity,
            description: p.description,
            deviceId: keyOf(p.deviceId),
          })),
          status: order.status,
          ...values,
          dueDate: timestampToDate(order.dueDate)?.toISOString(),
          createdAt: timestampToDate(order.createdAt)?.toISOString(),
          photos: order.photos?.map((p) => ({
            // IDs removed for LGPD compliance
            url: p.url,
            description: p.description,
          })),
          forms: toPublicForms(forms, keyOf),
          rating: order.rating ? {
            score: order.rating.score,
            comment: order.rating.comment,
            createdAt: timestampToDate(order.rating.createdAt)?.toISOString(),
            customerName: maskName(order.rating.customerName),
          } : null,
        },
        company: company ? {
          name: company.name,
          logo: company.logo,
          phone: company.phone,
          address: company.address,
          country: company.country,
          segment: company.segment || null,
          termsOfService: company.termsOfService || null,
        } : null,
        segmentLabels: await getSegmentLabels(company?.segment),
        comments: comments.map((c) => ({
          // IDs removed for LGPD compliance
          text: c.text,
          authorType: c.authorType,
          authorName: c.authorType === 'customer'
            ? maskName(c.author.name)
            : c.author.name, // Team member names are public/visible
          createdAt: timestampToDate(c.createdAt)?.toISOString(),
        })),
        permissions: req.shareTokenAuth!.permissions,
        customer: maskedCustomer,
        charge,
        // Additive: older pages ignore it and render missing values as before.
        showValues,
      },
    });
  } catch (error) {
    console.error('Get public order error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get order' },
    });
  }
});

/**
 * POST /public/orders/:token/approve
 * Approve a quote
 */
router.post(
  '/:token/approve',
  shareTokenAuth,
  requireSharePermission('approve'),
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const { companyId, orderId, token, customer } = req.shareTokenAuth!;

      // Get order
      const order = await orderService.getOrder(companyId, orderId) as Order | null;
      if (!order) {
        res.status(404).json({
          success: false,
          error: { code: 'NOT_FOUND', message: 'Order not found' },
        });
        return;
      }

      // Verify order is in quote status
      if (order.status !== 'quote') {
        res.status(400).json({
          success: false,
          error: { code: 'INVALID_STATUS', message: 'Order is not in quote status' },
        });
        return;
      }

      // Check if company has terms of service
      const companyDoc = await db.collection('companies').doc(companyId).get();
      const company = companyDoc.exists ? companyDoc.data() as Company : null;
      const hasTerms = !!(company?.termsOfService);
      const now = new Date().toISOString();

      // Update order status to approved
      await getTenantCollection(companyId, 'orders').doc(orderId).update({
        status: 'approved',
        updatedAt: now,
      });

      // Mark token as approved (with terms acceptance timestamp if applicable)
      await shareTokenService.markTokenApproved(token, hasTerms ? now : undefined);

      // Add approval comment
      await commentService.addComment(
        companyId,
        orderId,
        'Orçamento aprovado pelo cliente via link de acompanhamento.',
        'customer',
        {
          name: customer.name,
          phone: customer.phone || undefined,
          email: customer.email || undefined,
        },
        'magicLink',
        false,
        token
      );

      // Send push notification to team
      await notificationService.notifyOrderApproved(order, companyId, customer.name);

      res.json({
        success: true,
        data: {
          message: 'Quote approved successfully',
          newStatus: 'approved',
        },
      });
    } catch (error) {
      console.error('Approve quote error:', error);
      res.status(500).json({
        success: false,
        error: { code: 'INTERNAL_ERROR', message: 'Failed to approve quote' },
      });
    }
  }
);

/**
 * POST /public/orders/:token/reject
 * Reject a quote
 */
router.post(
  '/:token/reject',
  shareTokenAuth,
  requireSharePermission('approve'),
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const { companyId, orderId, token, customer } = req.shareTokenAuth!;
      const { reason } = req.body;

      // Get order
      const order = await orderService.getOrder(companyId, orderId) as Order | null;
      if (!order) {
        res.status(404).json({
          success: false,
          error: { code: 'NOT_FOUND', message: 'Order not found' },
        });
        return;
      }

      // Verify order is in quote status
      if (order.status !== 'quote') {
        res.status(400).json({
          success: false,
          error: { code: 'INVALID_STATUS', message: 'Order is not in quote status' },
        });
        return;
      }

      // Update order status to canceled
      await getTenantCollection(companyId, 'orders').doc(orderId).update({
        status: 'canceled',
        updatedAt: new Date().toISOString(),
      });

      // Mark token as rejected
      await shareTokenService.markTokenRejected(token, reason);

      // Add rejection comment
      const commentText = reason
        ? `Orçamento rejeitado pelo cliente via link de acompanhamento. Motivo: ${reason}`
        : 'Orçamento rejeitado pelo cliente via link de acompanhamento.';

      await commentService.addComment(
        companyId,
        orderId,
        commentText,
        'customer',
        {
          name: customer.name,
          phone: customer.phone || undefined,
          email: customer.email || undefined,
        },
        'magicLink',
        false,
        token
      );

      // Send push notification to team
      await notificationService.notifyOrderRejected(order, companyId, customer.name, reason);

      res.json({
        success: true,
        data: {
          message: 'Quote rejected',
          newStatus: 'canceled',
        },
      });
    } catch (error) {
      console.error('Reject quote error:', error);
      res.status(500).json({
        success: false,
        error: { code: 'INTERNAL_ERROR', message: 'Failed to reject quote' },
      });
    }
  }
);

/**
 * POST /public/orders/:token/comments
 * Add a comment
 */
router.post(
  '/:token/comments',
  shareTokenAuth,
  requireSharePermission('comment'),
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const { companyId, orderId, token, customer } = req.shareTokenAuth!;
      const { text } = req.body;

      if (!text || typeof text !== 'string' || text.trim().length === 0) {
        res.status(400).json({
          success: false,
          error: { code: 'VALIDATION_ERROR', message: 'Comment text is required' },
        });
        return;
      }

      if (text.length > 2000) {
        res.status(400).json({
          success: false,
          error: { code: 'VALIDATION_ERROR', message: 'Comment text too long (max 2000 characters)' },
        });
        return;
      }

      // Verify order exists
      const order = await orderService.getOrder(companyId, orderId) as Order | null;
      if (!order) {
        res.status(404).json({
          success: false,
          error: { code: 'NOT_FOUND', message: 'Order not found' },
        });
        return;
      }

      const comment = await commentService.addComment(
        companyId,
        orderId,
        text.trim(),
        'customer',
        {
          name: customer.name,
          phone: customer.phone || undefined,
          email: customer.email || undefined,
        },
        'magicLink',
        false,
        token
      );

      // Send push notification to team
      await notificationService.notifyNewComment(order, comment, companyId);

      res.status(201).json({
        success: true,
        data: {
          // ID removed for LGPD compliance
          text: comment.text,
          authorType: comment.authorType,
          authorName: maskName(comment.author.name),
          createdAt: timestampToDate(comment.createdAt)?.toISOString(),
        },
      });
    } catch (error) {
      console.error('Add comment error:', error);
      res.status(500).json({
        success: false,
        error: { code: 'INTERNAL_ERROR', message: 'Failed to add comment' },
      });
    }
  }
);

/**
 * GET /public/orders/:token/comments
 * Get comments for order
 */
router.get('/:token/comments', shareTokenAuth, requireSharePermission('view'), async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { companyId, orderId } = req.shareTokenAuth!;

    // Get customer-visible comments only
    const comments = await commentService.getCustomerVisibleComments(companyId, orderId);

    res.json({
      success: true,
      data: comments.map((c) => ({
        // ID removed for LGPD compliance
        text: c.text,
        authorType: c.authorType,
        authorName: c.authorType === 'customer'
          ? maskName(c.author.name)
          : c.author.name, // Team member names are public/visible
        createdAt: timestampToDate(c.createdAt)?.toISOString(),
      })),
    });
  } catch (error) {
    console.error('Get comments error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get comments' },
    });
  }
});

/**
 * POST /public/orders/:token/rating
 * Submit a rating for a completed order
 */
router.post(
  '/:token/rating',
  shareTokenAuth,
  requireSharePermission('view'),
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const { companyId, orderId, customer } = req.shareTokenAuth!;
      const { score, comment } = req.body;

      // Validate score (1-5)
      if (typeof score !== 'number' || score < 1 || score > 5 || !Number.isInteger(score)) {
        res.status(400).json({
          success: false,
          error: { code: 'VALIDATION_ERROR', message: 'Score must be an integer between 1 and 5' },
        });
        return;
      }

      // Validate comment (optional, max 500 chars)
      if (comment !== undefined && comment !== null) {
        if (typeof comment !== 'string') {
          res.status(400).json({
            success: false,
            error: { code: 'VALIDATION_ERROR', message: 'Comment must be a string' },
          });
          return;
        }
        if (comment.length > 500) {
          res.status(400).json({
            success: false,
            error: { code: 'VALIDATION_ERROR', message: 'Comment too long (max 500 characters)' },
          });
          return;
        }
      }

      // Get order
      const order = await orderService.getOrder(companyId, orderId) as Order | null;
      if (!order) {
        res.status(404).json({
          success: false,
          error: { code: 'NOT_FOUND', message: 'Order not found' },
        });
        return;
      }

      // Verify order is completed (done)
      if (order.status !== 'done') {
        res.status(400).json({
          success: false,
          error: { code: 'INVALID_STATUS', message: 'Only completed orders can be rated' },
        });
        return;
      }

      // Verify order has not been rated yet
      if (order.rating?.score) {
        res.status(400).json({
          success: false,
          error: { code: 'ALREADY_RATED', message: 'This order has already been rated' },
        });
        return;
      }

      const now = new Date().toISOString();

      // Build rating object
      const rating = {
        score,
        comment: comment?.trim() || null,
        createdAt: now,
        customerName: customer.name,
      };

      // Update order with rating
      await getTenantCollection(companyId, 'orders').doc(orderId).update({
        rating,
        updatedAt: now,
      });

      // Add audit comment
      const stars = '⭐'.repeat(score);
      const ratingCommentText = comment?.trim()
        ? `Avaliação do cliente: ${stars} (${score}/5)\n\n"${comment.trim()}"`
        : `Avaliação do cliente: ${stars} (${score}/5)`;

      await commentService.addComment(
        companyId,
        orderId,
        ratingCommentText,
        'customer',
        {
          name: customer.name,
          phone: customer.phone || undefined,
          email: customer.email || undefined,
        },
        'magicLink',
        false
      );

      // Send push notification to team
      await notificationService.notifyOrderRated(order, companyId, customer.name, score);

      res.status(201).json({
        success: true,
        data: {
          message: 'Rating submitted successfully',
          rating: {
            score: rating.score,
            comment: rating.comment,
            createdAt: rating.createdAt,
            customerName: maskName(rating.customerName),
          },
        },
      });
    } catch (error) {
      console.error('Submit rating error:', error);
      res.status(500).json({
        success: false,
        error: { code: 'INTERNAL_ERROR', message: 'Failed to submit rating' },
      });
    }
  }
);

export default router;
