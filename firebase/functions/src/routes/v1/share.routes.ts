/**
 * Share Routes
 * Authenticated endpoints for generating share links
 */

import { Router, Response } from 'express';
import { AuthenticatedRequest, ShareTokenPermission, Order } from '../../models/types';
import { getUserAggr } from '../../middleware/company.middleware';
import * as shareTokenService from '../../services/share-token.service';
import * as orderService from '../../services/order.service';

const router: Router = Router();

/**
 * POST /v1/orders/:orderId/share
 * Generate a share link for an order
 */
router.post('/:orderId/share', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.auth?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    const orderId = String(req.params.orderId);
    const { permissions = ['view', 'approve', 'comment'], expiresInDays = 7 } = req.body;

    // Validate permissions
    const validPermissions: ShareTokenPermission[] = ['view', 'approve', 'comment'];
    const requestedPermissions = permissions.filter(
      (p: string) => validPermissions.includes(p as ShareTokenPermission)
    ) as ShareTokenPermission[];

    if (requestedPermissions.length === 0) {
      requestedPermissions.push('view');
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

    // Verify order has a customer
    if (!order.customer) {
      res.status(400).json({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: 'Order must have a customer to generate share link' },
      });
      return;
    }

    const createdBy = getUserAggr(req);

    // Generate share token
    const shareToken = await shareTokenService.generateShareToken(
      orderId,
      companyId,
      order.customer,
      requestedPermissions,
      createdBy,
      expiresInDays
    );

    // Build share URL
    const baseUrl = process.env.SHARE_BASE_URL || 'https://praticos.web.app';
    const shareUrl = `${baseUrl}/q/${shareToken.token}`;

    res.status(201).json({
      success: true,
      data: {
        token: shareToken.token,
        url: shareUrl,
        permissions: shareToken.permissions,
        expiresAt: shareToken.expiresAt,
        customer: {
          name: order.customer.name,
          phone: order.customer.phone,
        },
      },
    });
  } catch (error) {
    console.error('Generate share link error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to generate share link' },
    });
  }
});

/**
 * GET /v1/orders/:orderId/share
 * List share tokens for an order
 */
router.get('/:orderId/share', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.auth?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    const orderId = String(req.params.orderId);

    // Get all tokens for this order
    const tokens = await shareTokenService.getTokensForOrder(orderId, companyId);

    const baseUrl = process.env.SHARE_BASE_URL || 'https://praticos.web.app';

    res.json({
      success: true,
      data: tokens.map((t) => ({
        token: t.token,
        url: `${baseUrl}/q/${t.token}`,
        permissions: t.permissions,
        createdAt: t.createdAt,
        expiresAt: t.expiresAt,
        viewCount: t.viewCount,
        lastViewedAt: t.lastViewedAt,
        approvedAt: t.approvedAt,
        rejectedAt: t.rejectedAt,
        rejectionReason: t.rejectionReason,
        isExpired: new Date(t.expiresAt) < new Date(),
      })),
    });
  } catch (error) {
    console.error('List share tokens error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to list share tokens' },
    });
  }
});

/**
 * DELETE /v1/orders/:orderId/share/:token
 * Revoke a share token
 */
router.delete('/:orderId/share/:token', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.auth?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    const token = String(req.params.token);

    // Verify token exists and belongs to this company
    const shareToken = await shareTokenService.getShareToken(token);
    if (!shareToken || shareToken.companyId !== companyId) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Share token not found' },
      });
      return;
    }

    await shareTokenService.revokeShareToken(token);

    res.json({
      success: true,
      data: { message: 'Share token revoked' },
    });
  } catch (error) {
    console.error('Revoke share token error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to revoke share token' },
    });
  }
});

export default router;
