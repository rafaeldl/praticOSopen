/**
 * Bot Comments Routes
 * Endpoints for order comments/notes via Bot
 */

import { Router, Response } from 'express';
import { AuthenticatedRequest } from '../../models/types';
import { requireLinked } from '../../middleware/auth.middleware';
import { getUserAggr } from '../../middleware/company.middleware';
import * as orderService from '../../services/order.service';
import * as commentService from '../../services/comment.service';
import { timestampToDate } from '../../utils/date.utils';

const router: Router = Router();

/**
 * POST /bot/orders/:number/comments
 * Add a comment/note to an order
 */
router.post('/:number/comments', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
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
        error: { code: 'VALIDATION_ERROR', message: 'Invalid order number' },
      });
      return;
    }

    const { text, isInternal = true } = req.body;

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

    // Get order by number
    const order = await orderService.getOrderByNumber(companyId, orderNumber);
    if (!order) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: `Order #${orderNumber} not found` },
      });
      return;
    }

    const userAggr = getUserAggr(req);

    const comment = await commentService.addComment(
      companyId,
      order.id,
      text.trim(),
      'internal',
      {
        name: userAggr.name,
        userId: userAggr.id,
      },
      'bot',
      isInternal
    );

    res.status(201).json({
      success: true,
      data: {
        id: comment.id,
        text: comment.text,
        authorType: comment.authorType,
        authorName: comment.author.name,
        isInternal: comment.isInternal,
        createdAt: timestampToDate(comment.createdAt)?.toISOString() || comment.createdAt,
      },
    });
  } catch (error) {
    console.error('Bot add comment error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to add comment' },
    });
  }
});

/**
 * GET /bot/orders/:number/comments
 * List comments for an order
 */
router.get('/:number/comments', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
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
        error: { code: 'VALIDATION_ERROR', message: 'Invalid order number' },
      });
      return;
    }

    // Get order by number
    const order = await orderService.getOrderByNumber(companyId, orderNumber);
    if (!order) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: `Order #${orderNumber} not found` },
      });
      return;
    }

    // Bot users are team members, include internal comments
    const comments = await commentService.getComments(companyId, order.id, true);

    res.json({
      success: true,
      data: {
        comments: comments.map((c) => ({
          id: c.id,
          text: c.text,
          authorType: c.authorType,
          authorName: c.author.name,
          isInternal: c.isInternal,
          source: c.source,
          createdAt: timestampToDate(c.createdAt)?.toISOString() || c.createdAt,
        })),
        count: comments.length,
      },
    });
  } catch (error) {
    console.error('Bot list comments error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to list comments' },
    });
  }
});

export default router;
