/**
 * Bot Link Routes
 * Endpoints for linking/unlinking WhatsApp accounts
 */

import { Router, Response } from 'express';
import { AuthenticatedRequest } from '../../models/types';
import { requireLinked } from '../../middleware/auth.middleware';
import * as channelLinkService from '../../services/channel-link.service';
import * as registrationService from '../../services/registration.service';
import * as inviteService from '../../services/invite.service';
import { db } from '../../services/firestore.service';

const router: Router = Router();

// ============================================================================
// Helper Functions
// ============================================================================

interface CustomField {
  key: string;
  type: string;
  labels?: Record<string, string>;
}

// ============================================================================
// Routes
// ============================================================================

/**
 * POST /api/bot/link
 * Link WhatsApp number to user via magic link token
 *
 * Accepts multiple body formats for flexibility:
 * - {"token": "LT_xxx", "whatsappNumber": "+55..."}
 * - {"linkToken": "LT_xxx"} (whatsappNumber from header)
 * - {"inviteCode": "LT_xxx"} (whatsappNumber from header)
 */
router.post('/', async (req: AuthenticatedRequest, res: Response) => {
  try {
    // Accept multiple field names for token
    const token = req.body.token || req.body.linkToken || req.body.inviteCode;
    // Accept whatsappNumber from body or header
    const whatsappNumber = req.body.whatsappNumber || req.headers['x-whatsapp-number'] as string;

    console.log(`[LINK] POST /bot/link - token=${token ? token.substring(0, 10) + '...' : 'missing'}, whatsappNumber=${whatsappNumber || 'missing'}`);

    // Validate token
    if (!token) {
      console.log('[LINK] Validation failed: token is required');
      res.status(400).json({
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Token is required (use "token", "linkToken", or "inviteCode" field)',
        },
      });
      return;
    }

    // Validate whatsappNumber
    if (!whatsappNumber) {
      console.log('[LINK] Validation failed: whatsappNumber is required');
      res.status(400).json({
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: 'WhatsApp number is required (in body or X-WhatsApp-Number header)',
        },
      });
      return;
    }

    // Validate E.164 format
    const e164Regex = /^\+[1-9]\d{6,14}$/;
    if (!e164Regex.test(whatsappNumber)) {
      console.log(`[LINK] Validation failed: invalid E.164 format: ${whatsappNumber}`);
      res.status(400).json({
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: 'WhatsApp number must be in E.164 format (e.g., +5511999999999)',
        },
      });
      return;
    }

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

    console.log(`[LINK] WhatsApp linked successfully: ${whatsappNumber} -> user=${tokenData.userId}, company=${tokenData.companyId}`);

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
      // Check for pending registration (non-blocking - if it fails, just return null)
      let pendingRegistration = null;
      try {
        const reg = await registrationService.getActiveByPhone(whatsappNumber);
        if (reg) {
          pendingRegistration = {
            token: reg.token,
            state: reg.state,
            data: reg.data,
            expiresAt: reg.expiresAt,
          };
        }
      } catch (error) {
        console.warn('[LINK] Failed to check pending registration:', error);
        // Continue without pending registration info
      }

      // Check for pending invites by phone (non-blocking)
      let pendingInvites = null;
      try {
        const invites = await inviteService.findPendingInvitesByPhone(whatsappNumber);
        if (invites.length > 0) {
          pendingInvites = invites.map(inv => ({
            token: inv.token,
            companyName: inv.company.name,
            role: inv.role,
            invitedByName: inv.invitedBy?.name || '',
            name: inv.name || '',
          }));
        }
      } catch (error) {
        console.warn('[LINK] Failed to check pending invites:', error);
      }

      res.json({
        success: true,
        data: {
          linked: false,
          pendingRegistration,
          pendingInvites,
        },
      });
      return;
    }

    // Fetch company data to get segment information
    const companyDoc = await db.collection('companies').doc(link.companyId).get();
    const company = companyDoc.data();
    const segmentId = company?.segment || 'other';

    // Fetch segment document for labels and name
    const segmentDoc = await db.collection('segments').doc(segmentId).get();
    const segmentData = segmentDoc.data();
    const segmentName = segmentData?.name || segmentId;

    // Extract labels from customFields
    const segmentLabels: Record<string, string> = {};
    const customFields = (segmentData?.customFields || []) as CustomField[];
    for (const field of customFields) {
      if (field.type === 'label' && field.labels?.['pt-BR']) {
        segmentLabels[field.key] = field.labels['pt-BR'];
      }
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
        segment: {
          id: segmentId,
          name: segmentName,
          labels: segmentLabels,
        },
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
    const err = error as Error;
    console.error('Dev link error:', err.message, err.stack);
    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message: 'Failed to link WhatsApp',
        details: err.message,
      },
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
