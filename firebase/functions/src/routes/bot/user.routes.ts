/**
 * Bot User Routes
 * Endpoints for bot to update user preferences
 */

import { Router, Response } from 'express';
import { AuthenticatedRequest } from '../../models/types';
import * as channelLinkService from '../../services/channel-link.service';
import { db } from '../../services/firestore.service';

const router: Router = Router();

/**
 * PATCH /api/bot/user/language
 * Update user's preferred language and optionally company country
 *
 * Headers: X-WhatsApp-Number (required)
 * Body: { "preferredLanguage": "pt-BR", "country": "BR" }
 */
router.patch('/language', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const whatsappNumber = req.headers['x-whatsapp-number'] as string;
    const { preferredLanguage, country } = req.body;

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

    if (!preferredLanguage || typeof preferredLanguage !== 'string') {
      res.status(400).json({
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: 'preferredLanguage is required and must be a string (BCP47 code)',
        },
      });
      return;
    }

    // Resolve userId from WhatsApp link
    const link = await channelLinkService.getWhatsAppLink(whatsappNumber);

    if (!link) {
      res.status(404).json({
        success: false,
        error: {
          code: 'NOT_LINKED',
          message: 'WhatsApp number is not linked to any account',
        },
      });
      return;
    }

    // Update preferredLanguage on user doc
    await db.collection('users').doc(link.userId).update({
      preferredLanguage,
    });

    console.log(`[USER] Updated preferredLanguage for user=${link.userId}: ${preferredLanguage}`);

    // Update company country if provided (affects formatContext for all company users)
    if (country && typeof country === 'string' && link.companyId) {
      const validCountries = ['BR', 'US', 'PT', 'ES', 'FR', 'DE', 'IT', 'MX', 'AR', 'CO', 'CL', 'GB', 'CA', 'AU', 'PE', 'UY'];
      const upperCountry = country.toUpperCase();
      if (validCountries.includes(upperCountry)) {
        await db.collection('companies').doc(link.companyId).update({
          country: upperCountry,
        });
        console.log(`[USER] Updated company country for company=${link.companyId}: ${upperCountry}`);
      }
    }

    res.json({
      success: true,
    });
  } catch (error) {
    console.error('Update language error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to update language' },
    });
  }
});

export default router;
