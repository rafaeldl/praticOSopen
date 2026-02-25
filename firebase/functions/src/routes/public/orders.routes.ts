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
import { maskName, maskPhone, maskSerial } from '../../utils/mask.utils';

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
          devices: (() => {
            const list = order.devices?.length
              ? order.devices
              : (order.device ? [order.device] : []);
            return list.map((d) => ({
              id: d.id,
              name: d.name,
              serial: maskSerial(d.serial),
            }));
          })(),
          services: order.services?.map((s) => ({
            name: s.service.name,
            value: s.value,
            description: s.description,
            deviceId: s.deviceId || null,
          })),
          products: order.products?.map((p) => ({
            name: p.product.name,
            value: p.value,
            quantity: p.quantity,
            description: p.description,
            deviceId: p.deviceId || null,
          })),
          status: order.status,
          total: order.total,
          discount: order.discount,
          paidAmount: order.paidAmount,
          remainingBalance,
          dueDate: timestampToDate(order.dueDate)?.toISOString(),
          createdAt: timestampToDate(order.createdAt)?.toISOString(),
          photos: order.photos?.map((p) => ({
            // IDs removed for LGPD compliance
            url: p.url,
            description: p.description,
          })),
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
          email: company.email,
          address: company.address,
          country: company.country,
        } : null,
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
router.get('/:token/comments', shareTokenAuth, async (req: AuthenticatedRequest, res: Response) => {
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
