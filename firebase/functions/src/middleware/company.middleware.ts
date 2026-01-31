/**
 * Company Context Middleware
 * Resolves and injects company context into requests
 */

import { Response, NextFunction } from 'express';
import { AuthenticatedRequest, UserAggr, CompanyAggr } from '../models/types';
import { db } from '../services/firestore.service';
import { getRolePermissions } from './auth.middleware';

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
      // Get user info
      const userDoc = await db.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        res.status(404).json({
          success: false,
          error: {
            code: 'NOT_FOUND',
            message: 'User not found',
          },
        });
        return;
      }

      const userData = userDoc.data();

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

      // Find user's role in this company
      const companies = userData?.companies || [];
      const companyRole = companies.find(
        (c: { company: CompanyAggr }) => c.company.id === companyId
      );

      if (!companyRole) {
        res.status(403).json({
          success: false,
          error: {
            code: 'FORBIDDEN',
            message: 'User does not have access to this company',
          },
        });
        return;
      }

      req.userContext = {
        userId: userId,
        userName: userData?.name || '',
        companyId: companyId,
        companyName: companyData?.name || '',
        role: companyRole.role,
        permissions: getRolePermissions(companyRole.role),
      };

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
