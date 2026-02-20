/**
 * Bot Summary Routes
 * Formatted summary endpoints for WhatsApp messages
 */

import { Router, Response } from 'express';
import { AuthenticatedRequest } from '../../models/types';
import { requireLinked } from '../../middleware/auth.middleware';
import * as analyticsService from '../../services/analytics.service';
import { getFormatContext } from '../../utils/format.utils';

const router: Router = Router();

/**
 * GET /api/bot/summary/today
 * Get today's summary formatted for WhatsApp
 */
router.get('/today', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    const data = await analyticsService.getTodaySummary(companyId);

    res.json({
      success: true,
      data: {
        data,
        formatContext: getFormatContext(req.auth?.companyCountry),
      },
    });
  } catch (error) {
    console.error('Get today summary error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get summary' },
    });
  }
});

/**
 * GET /api/bot/summary/pending
 * Get pending items formatted for WhatsApp
 */
router.get('/pending', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    const data = await analyticsService.getPendingItems(companyId);

    res.json({
      success: true,
      data: {
        data,
        formatContext: getFormatContext(req.auth?.companyCountry),
      },
    });
  } catch (error) {
    console.error('Get pending summary error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get pending items' },
    });
  }
});

export default router;
