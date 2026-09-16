/**
 * Company Context Middleware
 * Resolves and injects company context into requests
 */

import { Response, NextFunction } from 'express';
import { AuthenticatedRequest, UserAggr, CompanyAggr } from '../models/types';
import { db } from '../services/firestore.service';
import { resolveUserContext, UserContextFailure } from '../services/user-context.service';
import { getRolePermissions } from './auth.middleware';

const BEARER_FAILURES: Record<
  UserContextFailure,
  { status: number; code: string; message: string }
> = {
  user_not_found: { status: 404, code: 'NOT_FOUND', message: 'User not found' },
  company_not_found: { status: 404, code: 'NOT_FOUND', message: 'Company not found' },
  no_access: {
    status: 403,
    code: 'FORBIDDEN',
    message: 'User does not have access to this company',
  },
};

/**
 * Middleware to resolve full company context
 * Must be used after authentication middleware
 */
export async function resolveCompanyContext(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    // If userContext is already set (from bot auth with linked account), proceed
    if (req.userContext) {
      next();
      return;
    }

    // If no auth context, return error
    if (!req.auth || !req.auth.companyId) {
      res.status(401).json({
        success: false,
        error: {
          code: 'UNAUTHORIZED',
          message: 'Company context is required',
        },
      });
      return;
    }

    const { companyId, userId, type } = req.auth;

    // For API key auth, create a minimal context
    if (type === 'apiKey') {
      // Get company info
      const companyDoc = await db.collection('companies').doc(companyId).get();

      if (!companyDoc.exists) {
        res.status(404).json({
          success: false,
          error: {
            code: 'NOT_FOUND',
            message: 'Company not found',
          },
        });
        return;
      }

      const companyData = companyDoc.data();

      req.userContext = {
        userId: 'api_key_user',
        userName: 'API Integration',
        companyId: companyId,
        companyName: companyData?.name || '',
        role: 'admin', // API keys have admin-level access
        permissions: req.auth.permissions || getRolePermissions('admin'),
      };

      next();
      return;
    }

    // For bearer auth, resolve user and company
    if (type === 'bearer' && userId) {
      const result = await resolveUserContext(userId, companyId);

      if (!result.ok) {
        const { status, code, message } = BEARER_FAILURES[result.reason];
        res.status(status).json({
          success: false,
          error: { code, message },
        });
        return;
      }

      req.userContext = result.context;

      next();
      return;
    }

    // No valid context could be resolved
    res.status(401).json({
      success: false,
      error: {
        code: 'UNAUTHORIZED',
        message: 'Unable to resolve company context',
      },
    });
  } catch (error) {
    console.error('Company context error:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to resolve company context',
      },
    });
  }
}

/**
 * Get UserAggr for audit fields
 */
export function getUserAggr(req: AuthenticatedRequest): UserAggr {
  if (req.userContext) {
    return {
      id: req.userContext.userId,
      name: req.userContext.userName,
    };
  }

  return {
    id: 'system',
    name: 'System',
  };
}

/**
 * Get CompanyAggr for company field
 */
export function getCompanyAggr(req: AuthenticatedRequest): CompanyAggr {
  if (req.userContext) {
    return {
      id: req.userContext.companyId,
      name: req.userContext.companyName,
    };
  }

  if (req.auth) {
    return {
      id: req.auth.companyId,
      name: '',
    };
  }

  throw new Error('No company context available');
}
