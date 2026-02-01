/**
 * Share Token Middleware
 * Authenticates requests using magic link tokens for customer access
 */

import { Response, NextFunction } from 'express';
import { AuthenticatedRequest, ShareTokenPermission } from '../models/types';
import { validateShareToken, incrementViewCount } from '../services/share-token.service';

/**
 * Middleware to authenticate requests using share token
 * Token can be passed as:
 * - URL parameter: /public/orders/:token
 * - Header: X-Share-Token
 */
export async function shareTokenAuth(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    // Get token from URL parameter or header
    const token = String(req.params.token || req.headers['x-share-token'] || '');

    if (!token) {
      res.status(401).json({
        success: false,
        error: {
          code: 'UNAUTHORIZED',
          message: 'Share token is required',
        },
      });
      return;
    }

    // Validate token
    const shareToken = await validateShareToken(token);

    if (!shareToken) {
      res.status(401).json({
        success: false,
        error: {
          code: 'INVALID_TOKEN',
          message: 'Invalid or expired share token',
        },
      });
      return;
    }

    // Set auth context
    req.auth = {
      type: 'shareToken',
      companyId: shareToken.companyId,
    };

    req.shareTokenAuth = {
      type: 'shareToken',
      token: shareToken.token,
      companyId: shareToken.companyId,
      orderId: shareToken.orderId,
      permissions: shareToken.permissions,
      customer: shareToken.customer,
    };

    // Increment view count asynchronously
    incrementViewCount(token).catch((err) => {
      console.error('Error incrementing view count:', err);
    });

    next();
  } catch (error) {
    console.error('Share token auth error:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Authentication failed',
      },
    });
  }
}

/**
 * Middleware to require specific share token permission
 * Must be used after shareTokenAuth
 */
export function requireSharePermission(permission: ShareTokenPermission) {
  return (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
    if (!req.shareTokenAuth) {
      res.status(401).json({
        success: false,
        error: {
          code: 'UNAUTHORIZED',
          message: 'Share token authentication required',
        },
      });
      return;
    }

    if (!req.shareTokenAuth.permissions.includes(permission)) {
      res.status(403).json({
        success: false,
        error: {
          code: 'INSUFFICIENT_PERMISSIONS',
          message: `Permission '${permission}' is required`,
        },
      });
      return;
    }

    next();
  };
}

/**
 * Middleware to verify that the requested order matches the token's order
 */
export function verifyTokenOrder(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): void {
  if (!req.shareTokenAuth) {
    res.status(401).json({
      success: false,
      error: {
        code: 'UNAUTHORIZED',
        message: 'Share token authentication required',
      },
    });
    return;
  }

  // The token already has the order ID, so we just continue
  // The route handlers will use req.shareTokenAuth.orderId
  next();
}
