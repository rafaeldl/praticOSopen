/**
 * User Link Routes
 * Endpoints for Flutter app to generate WhatsApp linking tokens
 * Requires Firebase Auth (bearerAuth middleware)
 */

import { Router, Response } from 'express';
import { AuthenticatedRequest } from '../../models/types';
import * as channelLinkService from '../../services/channel-link.service';

const router: Router = Router();

// Bot WhatsApp number (read from env or default)
const BOT_WHATSAPP_NUMBER = process.env.BOT_WHATSAPP_NUMBER || '+5548988794742';

/**
 * POST /user/link/whatsapp/token
 * Generate a magic link token for WhatsApp linking
 * Requires: Firebase Auth (user logged in via bearerAuth)
 */
router.post('/whatsapp/token', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userContext = req.userContext;

    if (!userContext) {
      res.status(401).json({
        success: false,
        error: {
          code: 'UNAUTHORIZED',
          message: 'User context not found',
        },
      });
      return;
    }

    const { userId, companyId, role, userName, companyName } = userContext;

    // Generate token using existing channel-link service
    const token = await channelLinkService.generateLinkToken(
      userId,
      companyId,
      role,
      userName,
      companyName
    );

    // Generate WhatsApp deep link
    const link = channelLinkService.generateWhatsAppLink(BOT_WHATSAPP_NUMBER, token);

    res.json({
      success: true,
      data: {
        token,
        link,
        botNumber: BOT_WHATSAPP_NUMBER,
        expiresIn: 900, // 15 minutes in seconds
      },
    });
  } catch (error) {
    console.error('Error generating WhatsApp link token:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to generate WhatsApp link token',
      },
    });
  }
});

/**
 * GET /user/link/whatsapp/status
 * Check if current user has WhatsApp linked
 * Requires: Firebase Auth (user logged in via bearerAuth)
 */
router.get('/whatsapp/status', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userContext = req.userContext;

    if (!userContext) {
      res.status(401).json({
        success: false,
        error: {
          code: 'UNAUTHORIZED',
          message: 'User context not found',
        },
      });
      return;
    }

    const { userId } = userContext;

    // Get all links for the user
    const links = await channelLinkService.getUserLinks(userId);
    const whatsappLink = links.find((l) => l.channel === 'whatsapp');

    res.json({
      success: true,
      data: {
        linked: !!whatsappLink,
        number: whatsappLink?.identifier,
        linkedAt: whatsappLink?.linkedAt,
      },
    });
  } catch (error) {
    console.error('Error checking WhatsApp link status:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to check WhatsApp link status',
      },
    });
  }
});

/**
 * DELETE /user/link/whatsapp
 * Unlink WhatsApp from current user
 * Requires: Firebase Auth (user logged in via bearerAuth)
 */
router.delete('/whatsapp', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userContext = req.userContext;

    if (!userContext) {
      res.status(401).json({
        success: false,
        error: {
          code: 'UNAUTHORIZED',
          message: 'User context not found',
        },
      });
      return;
    }

    const { userId } = userContext;

    // Get user's WhatsApp link
    const links = await channelLinkService.getUserLinks(userId);
    const whatsappLink = links.find((l) => l.channel === 'whatsapp');

    if (!whatsappLink) {
      res.status(404).json({
        success: false,
        error: {
          code: 'NOT_FOUND',
          message: 'WhatsApp not linked to this user',
        },
      });
      return;
    }

    // Unlink the WhatsApp number
    const success = await channelLinkService.unlinkWhatsApp(whatsappLink.identifier);

    if (success) {
      res.json({
        success: true,
        data: {
          unlinked: true,
        },
      });
    } else {
      res.status(500).json({
        success: false,
        error: {
          code: 'INTERNAL_ERROR',
          message: 'Failed to unlink WhatsApp',
        },
      });
    }
  } catch (error) {
    console.error('Error unlinking WhatsApp:', error);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to unlink WhatsApp',
      },
    });
  }
});

export default router;
