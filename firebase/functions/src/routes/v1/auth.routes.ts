/**
 * Auth Routes
 * Token generation and validation endpoints
 */

import { Router, Request, Response } from 'express';
import { db, Timestamp } from '../../services/firestore.service';
import { ApiKeyData } from '../../models/types';
import { v4 as uuidv4 } from 'uuid';

const router: Router = Router();

/**
 * POST /api/v1/auth/token
 * Generate access token from API Key + Secret
 */
router.post('/token', async (req: Request, res: Response) => {
  try {
    const { apiKey, apiSecret } = req.body;

    if (!apiKey || !apiSecret) {
      res.status(400).json({
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: 'apiKey and apiSecret are required',
        },
      });
      return;
    }

    // Look up API key
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
          message: 'Invalid API key',
        },
      });
      return;
    }

    const keyData = keySnapshot.docs[0].data() as ApiKeyData;

    // Verify secret
    if (keyData.secret !== apiSecret) {
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
    if (keyData.expiresAt && keyData.expiresAt.toDate() < new Date()) {
      res.status(401).json({
        success: false,
        error: {
          code: 'TOKEN_EXPIRED',
          message: 'API key has expired',
        },
      });
      return;
    }

    // Generate access token (valid for 1 hour)
    const accessToken = `at_${uuidv4().replace(/-/g, '')}`;
    const expiresAt = new Date();
    expiresAt.setHours(expiresAt.getHours() + 1);

    // Store token
    await db.collection('accessTokens').doc(accessToken).set({
      token: accessToken,
      apiKeyId: keySnapshot.docs[0].id,
      companyId: keyData.companyId,
      permissions: keyData.permissions,
      createdAt: Timestamp.now(),
      expiresAt: Timestamp.fromDate(expiresAt),
    });

    res.json({
      success: true,
      data: {
        accessToken,
        expiresIn: 3600, // 1 hour in seconds
        companyId: keyData.companyId,
      },
    });
  } catch (error) {
    console.error('Token generation error:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to generate token',
      },
    });
  }
});

/**
 * GET /api/v1/auth/verify
 * Verify access token and return context
 */
router.get('/verify', async (req: Request, res: Response) => {
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

    // Look up token
    const tokenDoc = await db.collection('accessTokens').doc(token).get();

    if (!tokenDoc.exists) {
      res.status(401).json({
        success: false,
        error: {
          code: 'INVALID_TOKEN',
          message: 'Invalid access token',
        },
      });
      return;
    }

    const tokenData = tokenDoc.data();

    // Check expiration
    if (tokenData?.expiresAt && tokenData.expiresAt.toDate() < new Date()) {
      res.status(401).json({
        success: false,
        error: {
          code: 'TOKEN_EXPIRED',
          message: 'Token has expired',
        },
      });
      return;
    }

    res.json({
      success: true,
      data: {
        companyId: tokenData?.companyId,
        permissions: tokenData?.permissions || [],
        expiresAt: tokenData?.expiresAt?.toDate().toISOString(),
      },
    });
  } catch (error) {
    console.error('Token verification error:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to verify token',
      },
    });
  }
});

export default router;
