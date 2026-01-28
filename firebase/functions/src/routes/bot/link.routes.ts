/**
 * Bot Link Routes
 * Endpoints for linking/unlinking WhatsApp accounts
 */

import { Router, Response } from 'express';
import { AuthenticatedRequest } from '../../models/types';
import { requireLinked } from '../../middleware/auth.middleware';
import * as channelLinkService from '../../services/channel-link.service';
import { validateInput, linkWhatsAppSchema } from '../../utils/validation.utils';

const router: Router = Router();

/**
 * POST /api/bot/link
 * Link WhatsApp number to user via magic link token
 */
router.post('/', async (req: AuthenticatedRequest, res: Response) => {
  try {
    // Validate input
    const validation = validateInput(linkWhatsAppSchema, req.body);
    if (!validation.success) {
      res.status(400).json({
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: validation.errors.join(', '),
        },
      });
      return;
    }

    const { token, whatsappNumber } = validation.data;

    // Check if already linked
    const existingLink = await channelLinkService.getWhatsAppLink(whatsappNumber);
    if (existingLink) {
      res.status(409).json({
        success: false,
        error: {
          code: 'ALREADY_LINKED',
          message: 'This WhatsApp number is already linked to an account',
        },
      });
      return;
    }

    // Validate and consume token
    const tokenData = await channelLinkService.consumeLinkToken(token);
    if (!tokenData) {
      res.status(401).json({
        success: false,
        error: {
          code: 'INVALID_TOKEN',
          message: 'Invalid or expired token',
        },
      });
      return;
    }

    // Link WhatsApp
    await channelLinkService.linkWhatsApp(
      whatsappNumber,
      tokenData.userId,
      tokenData.companyId,
      tokenData.role,
      tokenData.userName,
      tokenData.companyName
    );

    res.json({
      success: true,
      data: {
        success: true,
        userId: tokenData.userId,
        userName: tokenData.userName || '',
        companyId: tokenData.companyId,
        companyName: tokenData.companyName || '',
        role: tokenData.role,
      },
    });
  } catch (error) {
    console.error('Link WhatsApp error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to link WhatsApp' },
    });
  }
});

/**
 * GET /api/bot/link/context (also available as /api/bot/context)
 * Get context for linked WhatsApp number
 */
router.get('/context', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const whatsappNumber = req.headers['x-whatsapp-number'] as string;

    if (!whatsappNumber) {
      res.json({
        success: true,
        data: {
          linked: false,
        },
      });
      return;
    }

    const link = await channelLinkService.getWhatsAppLink(whatsappNumber);

    if (!link) {
      res.json({
        success: true,
        data: {
          linked: false,
        },
      });
      return;
    }

    res.json({
      success: true,
      data: {
        linked: true,
        userId: link.userId,
        userName: link.userName,
        companyId: link.companyId,
        companyName: link.companyName,
        role: link.role,
        permissions: [], // Would be resolved from role
      },
    });
  } catch (error) {
    console.error('Get context error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get context' },
    });
  }
});

/**
 * POST /api/bot/link/dev
 * [DEV ONLY] Link WhatsApp directly without token
 * Only works when FUNCTIONS_EMULATOR=true or NODE_ENV=development
 */
router.post('/dev', async (req: AuthenticatedRequest, res: Response) => {
  try {
    // Only allow in development/emulator
    const isDev = process.env.FUNCTIONS_EMULATOR === 'true' ||
                  process.env.NODE_ENV === 'development' ||
                  process.env.ALLOW_DEV_LINK === 'true';

    if (!isDev) {
      res.status(403).json({
        success: false,
        error: {
          code: 'FORBIDDEN',
          message: 'This endpoint is only available in development mode',
        },
      });
      return;
    }

    const { whatsappNumber, userId, companyId, role, userName, companyName } = req.body;

    // Validate required fields
    if (!whatsappNumber || !userId || !companyId) {
      res.status(400).json({
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: 'whatsappNumber, userId, and companyId are required',
        },
      });
      return;
    }

    // Check if already linked
    const existingLink = await channelLinkService.getWhatsAppLink(whatsappNumber);
    if (existingLink) {
      // Update existing link
      await channelLinkService.unlinkWhatsApp(whatsappNumber);
    }

    // Link WhatsApp
    await channelLinkService.linkWhatsApp(
      whatsappNumber,
      userId,
      companyId,
      role || 'owner',
      userName || 'Dev User',
      companyName || 'Dev Company'
    );

    res.json({
      success: true,
      data: {
        message: 'WhatsApp linked successfully (dev mode)',
        whatsappNumber,
        userId,
        companyId,
        role: role || 'owner',
      },
    });
  } catch (error) {
    console.error('Dev link error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to link WhatsApp' },
    });
  }
});

/**
 * DELETE /api/bot/link (also /api/bot/unlink)
 * Unlink WhatsApp number
 */
router.delete('/', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const whatsappNumber = req.headers['x-whatsapp-number'] as string;

    if (!whatsappNumber) {
      res.status(400).json({
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: 'X-WhatsApp-Number header is required',
        },
      });
      return;
    }

    const unlinked = await channelLinkService.unlinkWhatsApp(whatsappNumber);

    if (!unlinked) {
      res.status(404).json({
        success: false,
        error: {
          code: 'NOT_FOUND',
          message: 'WhatsApp number is not linked',
        },
      });
      return;
    }

    res.json({
      success: true,
      data: {
        success: true,
        message: 'WhatsApp unlinked successfully',
      },
    });
  } catch (error) {
    console.error('Unlink WhatsApp error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to unlink WhatsApp' },
    });
  }
});

export default router;
