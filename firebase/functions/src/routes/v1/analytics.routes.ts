/**
 * Analytics Routes
 * Dashboard and reporting endpoints
 */

import { Router, Response } from 'express';
import { z } from 'zod';
import { AuthenticatedRequest } from '../../models/types';
import * as analyticsService from '../../services/analytics.service';
import { validateInput } from '../../utils/validation.utils';
import { PeriodType } from '../../utils/date.utils';

const router: Router = Router();

// Validation schemas
const summaryQuerySchema = z.object({
  period: z.enum(['today', 'week', 'month', 'year', 'custom']).default('today'),
  startDate: z.string().datetime().optional(),
  endDate: z.string().datetime().optional(),
});

/**
 * GET /api/v1/analytics/summary
 * Get analytics summary for a period
 */
router.get('/summary', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.auth?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    // Validate query params
    const validation = validateInput(summaryQuerySchema, req.query);
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

    const { period, startDate, endDate } = validation.data;

    // Validate custom period has dates
    if (period === 'custom' && (!startDate || !endDate)) {
      res.status(400).json({
        success: false,
        error: {
          code: 'VALIDATION_ERROR',
          message: 'Custom period requires startDate and endDate',
        },
      });
      return;
    }

    const summary = await analyticsService.getAnalyticsSummary(
      companyId,
      period as PeriodType,
      startDate,
      endDate
    );

    res.json({
      success: true,
      data: summary,
    });
  } catch (error) {
    console.error('Get analytics summary error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get analytics summary' },
    });
  }
});

/**
 * GET /api/v1/analytics/pending
 * Get all pending items (approvals, due today, unpaid, overdue)
 */
router.get('/pending', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.auth?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    const pending = await analyticsService.getPendingItems(companyId);

    res.json({
      success: true,
      data: pending,
    });
  } catch (error) {
    console.error('Get pending items error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get pending items' },
    });
  }
});

export default router;
