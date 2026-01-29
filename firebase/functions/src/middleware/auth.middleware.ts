/**
 * Authentication Middleware
 * Handles API Key, Bot, and Bearer token authentication
 */

import { Response, NextFunction } from 'express';
import { AuthenticatedRequest, ApiKeyData, ChannelLink, RoleType, toDate } from '../models/types';
import { db, auth } from '../services/firestore.service';

// Environment variables
const BOT_API_KEY = process.env.BOT_API_KEY || 'bot_praticos_dev_key';

// ============================================================================
// API Key Authentication (for external integrations)
// ============================================================================

/**
 * Middleware to authenticate requests using API Key + Secret
 * Headers: X-API-Key, X-API-Secret
 */
export async function apiKeyAuth(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const apiKey = req.headers['x-api-key'] as string;
    const apiSecret = req.headers['x-api-secret'] as string;

    if (!apiKey) {
      res.status(401).json({
        success: false,
        error: {
          code: 'UNAUTHORIZED',
          message: 'API Key is required',
        },
      });
      return;
    }

    // Look up API key in Firestore
    const keySnapshot = await db
      .collection('apiKeys')
      .where('key', '==', apiKey)
      .where('active', '==', true)
      .limit(1)
      .get();

    if (keySnapshot.empty) {
      res.status(401).json({
        success: false,
        error: {
          code: 'INVALID_API_KEY',
          message: 'Invalid or inactive API key',
        },
      });
      return;
    }

    const keyData = keySnapshot.docs[0].data() as ApiKeyData;

    // Verify secret if provided in key data
    if (keyData.secret && keyData.secret !== apiSecret) {
      res.status(401).json({
        success: false,
        error: {
          code: 'INVALID_API_KEY',
          message: 'Invalid API secret',
        },
      });
      return;
    }

    // Check expiration
    const expiresAt = toDate(keyData.expiresAt);
    if (expiresAt && expiresAt < new Date()) {
      res.status(401).json({
        success: false,
        error: {
          code: 'TOKEN_EXPIRED',
          message: 'API key has expired',
        },
      });
      return;
    }

    // Set auth context
    req.auth = {
      type: 'apiKey',
      companyId: keyData.companyId,
      permissions: keyData.permissions || [],
    };

    next();
  } catch (error) {
    console.error('API Key auth error:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Authentication failed',
      },
    });
  }
}

// ============================================================================
// Bot Authentication (for Clawdbot)
// ============================================================================

/**
 * Middleware to authenticate bot requests
 * Headers: X-API-Key (bot key), X-WhatsApp-Number (user identifier)
 */
export async function botAuth(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const apiKey = req.headers['x-api-key'] as string;
    const whatsappNumber = req.headers['x-whatsapp-number'] as string;

    // Validate bot API key
    if (!apiKey || apiKey !== BOT_API_KEY) {
      res.status(401).json({
        success: false,
        error: {
          code: 'INVALID_API_KEY',
          message: 'Invalid bot API key',
        },
      });
      return;
    }

    // Set basic auth context
    req.auth = {
      type: 'bot',
      companyId: '', // Will be resolved from WhatsApp link if available
    };

    // If WhatsApp number provided, try to resolve user context
    if (whatsappNumber) {
      const normalizedNumber = normalizeWhatsAppNumber(whatsappNumber);
      const link = await getWhatsAppLink(normalizedNumber);

      if (link) {
        req.auth.companyId = link.companyId;
        req.auth.userId = link.userId;
        req.userContext = {
          userId: link.userId,
          userName: link.userName || '',
          companyId: link.companyId,
          companyName: link.companyName || '',
          role: link.role,
          permissions: getRolePermissions(link.role),
        };
      }
    }

    next();
  } catch (error) {
    console.error('Bot auth error:', error);
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
 * Middleware to require linked WhatsApp account
 * Must be used after botAuth
 */
export async function requireLinked(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  if (!req.userContext) {
    res.status(403).json({
      success: false,
      error: {
        code: 'NOT_LINKED',
        message: 'WhatsApp account is not linked. Please link your account first.',
      },
    });
    return;
  }
  next();
}

// ============================================================================
// Bearer Token Authentication (for Flutter app)
// ============================================================================

/**
 * Middleware to authenticate requests using Firebase ID token
 * Header: Authorization: Bearer {token}
 */
export async function bearerAuth(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({
        success: false,
        error: {
          code: 'UNAUTHORIZED',
          message: 'Bearer token is required',
        },
      });
      return;
    }

    const token = authHeader.split(' ')[1];

    // Verify Firebase ID token
    const decodedToken = await auth.verifyIdToken(token);
    const userId = decodedToken.uid;

    // Get user's company and role
    const userDoc = await db.collection('users').doc(userId).get();

    if (!userDoc.exists) {
      res.status(401).json({
        success: false,
        error: {
          code: 'UNAUTHORIZED',
          message: 'User not found',
        },
      });
      return;
    }

    const userData = userDoc.data();
    const companies = userData?.companies || [];

    // Use first company or get from header
    const requestedCompanyId = req.headers['x-company-id'] as string;
    let activeCompany = companies[0];

    if (requestedCompanyId) {
      activeCompany = companies.find(
        (c: { company: { id: string } }) => c.company.id === requestedCompanyId
      );
    }

    if (!activeCompany) {
      res.status(403).json({
        success: false,
        error: {
          code: 'FORBIDDEN',
          message: 'No company access',
        },
      });
      return;
    }

    // Set auth context
    req.auth = {
      type: 'bearer',
      companyId: activeCompany.company.id,
      userId: userId,
      permissions: getRolePermissions(activeCompany.role),
    };

    req.userContext = {
      userId: userId,
      userName: userData?.name || '',
      companyId: activeCompany.company.id,
      companyName: activeCompany.company.name || '',
      role: activeCompany.role,
      permissions: getRolePermissions(activeCompany.role),
    };

    next();
  } catch (error) {
    console.error('Bearer auth error:', error);

    if ((error as { code?: string }).code === 'auth/id-token-expired') {
      res.status(401).json({
        success: false,
        error: {
          code: 'TOKEN_EXPIRED',
          message: 'Token has expired',
        },
      });
      return;
    }

    res.status(401).json({
      success: false,
      error: {
        code: 'UNAUTHORIZED',
        message: 'Invalid token',
      },
    });
  }
}

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Normalize WhatsApp number to E.164 format
 */
function normalizeWhatsAppNumber(number: string): string {
  // Remove all non-digit characters except leading +
  let normalized = number.replace(/[^\d+]/g, '');

  // Ensure it starts with +
  if (!normalized.startsWith('+')) {
    normalized = '+' + normalized;
  }

  return normalized;
}

/**
 * Get WhatsApp link from Firestore
 */
async function getWhatsAppLink(number: string): Promise<ChannelLink | null> {
  const doc = await db.collection('links').doc('whatsapp').collection('numbers').doc(number).get();

  if (!doc.exists) return null;
  return doc.data() as ChannelLink;
}

/**
 * Get permissions for a role
 */
export function getRolePermissions(role: RoleType): string[] {
  const permissions: Record<RoleType, string[]> = {
    owner: [
      'read:all',
      'write:all',
      'delete:all',
      'manage:company',
      'manage:members',
      'view:financial',
    ],
    admin: [
      'read:all',
      'write:all',
      'delete:all',
      'manage:members',
      'view:financial',
    ],
    supervisor: [
      'read:all',
      'write:orders',
      'write:customers',
      'write:devices',
    ],
    manager: [
      'read:all',
      'write:orders',
      'write:customers',
      'write:devices',
      'view:financial',
    ],
    consultant: [
      'read:own',
      'write:orders',
      'write:customers',
      'write:devices',
    ],
    technician: [
      'read:assigned',
      'write:orders:status',
    ],
  };

  return permissions[role] || [];
}

/**
 * Check if user has a specific permission
 */
export function hasPermission(userContext: { permissions?: string[] }, permission: string): boolean {
  const permissions = userContext.permissions || [];

  // Check for exact match
  if (permissions.includes(permission)) return true;

  // Check for wildcard permissions
  const [action] = permission.split(':');
  if (permissions.includes(`${action}:all`)) return true;
  if (permissions.includes('*:all')) return true;

  return false;
}

/**
 * Middleware to require specific permission
 */
export function requirePermission(permission: string) {
  return (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
    if (!req.userContext || !hasPermission(req.userContext, permission)) {
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
