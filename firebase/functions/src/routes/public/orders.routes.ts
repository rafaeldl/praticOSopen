/**
 * Public Orders Routes
 * Public endpoints for customer order tracking via magic link
 */

import { Router, Response } from 'express';
import { AuthenticatedRequest, Order, Company } from '../../models/types';
import { shareTokenAuth, requireSharePermission } from '../../middleware/share-token.middleware';
import { getTenantCollection, db } from '../../services/firestore.service';
import * as shareTokenService from '../../services/share-token.service';
import * as commentService from '../../services/comment.service';
import * as orderService from '../../services/order.service';
import * as notificationService from '../../services/notification.service';
import { timestampToDate } from '../../utils/date.utils';

const router: Router = Router();

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

    // Get customer-visible comments
    const comments = await commentService.getCustomerVisibleComments(companyId, orderId);

    const remainingBalance = orderService.calculateRemainingBalance(order);

    res.json({
      success: true,
      data: {
        order: {
          id: order.id,
          number: order.number,
          customer: order.customer,
          device: order.device,
          services: order.services?.map((s) => ({
            name: s.service.name,
            value: s.value,
            description: s.description,
          })),
          products: order.products?.map((p) => ({
            name: p.product.name,
            value: p.value,
            quantity: p.quantity,
            description: p.description,
          })),
          status: order.status,
          total: order.total,
          discount: order.discount,
          paidAmount: order.paidAmount,
          remainingBalance,
          dueDate: timestampToDate(order.dueDate)?.toISOString(),
          createdAt: timestampToDate(order.createdAt)?.toISOString(),
          photos: order.photos?.map((p) => ({
            id: p.id,
            url: p.url,
            description: p.description,
          })),
        },
        company: company ? {
          name: company.name,
          logo: company.logo,
          phone: company.phone,
          email: company.email,
          address: company.address,
        } : null,
        comments: comments.map((c) => ({
          id: c.id,
          text: c.text,
          authorType: c.authorType,
          authorName: c.author.name,
          createdAt: c.createdAt,
        })),
        permissions: req.shareTokenAuth!.permissions,
        customer,
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

      // Update order status to approved
      await getTenantCollection(companyId, 'orders').doc(orderId).update({
        status: 'approved',
        updatedAt: new Date().toISOString(),
      });

      // Mark token as approved
      await shareTokenService.markTokenApproved(token);

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
          id: comment.id,
          text: comment.text,
          authorType: comment.authorType,
          authorName: comment.author.name,
          createdAt: comment.createdAt,
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
router.get('/:token/comments', shareTokenAuth, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { companyId, orderId } = req.shareTokenAuth!;

    // Get customer-visible comments only
    const comments = await commentService.getCustomerVisibleComments(companyId, orderId);

    res.json({
      success: true,
      data: comments.map((c) => ({
        id: c.id,
        text: c.text,
        authorType: c.authorType,
        authorName: c.author.name,
        createdAt: c.createdAt,
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

export default router;
