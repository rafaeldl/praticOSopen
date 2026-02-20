/**
 * Bot Analytics Routes
 * Endpoints for financial analytics via Bot
 */

import { Router, Response } from 'express';
import { AuthenticatedRequest } from '../../models/types';
import * as analyticsService from '../../services/analytics.service';
import { PeriodType, startOfMonth, endOfDay, startOfDay, parseLocalDate } from '../../utils/date.utils';
import {
  getPeriodLabel,
  formatCurrentMonthLabel,
  formatDateRangeLabel,
  getFormatContext,
} from '../../utils/format.utils';

const router: Router = Router();

/**
 * GET /api/bot/analytics/financial
 * Get financial summary for a period
 *
 * Query params (all optional):
 * - startDate: ISO date string (YYYY-MM-DD) - Start of custom range
 * - endDate: ISO date string (YYYY-MM-DD) - End of custom range
 * - period: today|week|month|year (legacy, still supported)
 *
 * If no params provided, defaults to current month
 */
router.get('/financial', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.auth?.companyId;

    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Contexto da empresa não encontrado para este número.' },
      });
      return;
    }

    const startDateParam = req.query.startDate as string | undefined;
    const endDateParam = req.query.endDate as string | undefined;
    const periodParam = req.query.period as string | undefined;

    let summary;
    let periodLabel: string;

    if (startDateParam && endDateParam) {
      // Custom date range - use parseLocalDate to avoid UTC conversion issues
      const startDate = startOfDay(parseLocalDate(startDateParam));
      const endDate = endOfDay(parseLocalDate(endDateParam));

      // Validate dates
      if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
        res.status(400).json({
          success: false,
          error: {
            code: 'INVALID_DATE',
            message: 'Data inválida. Use o formato YYYY-MM-DD.',
          },
        });
        return;
      }

      if (startDate > endDate) {
        res.status(400).json({
          success: false,
          error: {
            code: 'INVALID_DATE_RANGE',
            message: 'A data inicial deve ser anterior ou igual à data final.',
          },
        });
        return;
      }

      summary = await analyticsService.getAnalyticsSummary(
        companyId,
        'custom',
        startDateParam,
        endDateParam
      );
      periodLabel = formatDateRangeLabel(startDate, endDate);
    } else if (periodParam) {
      // Legacy period support
      const validPeriods = ['today', 'week', 'month', 'year'];
      if (!validPeriods.includes(periodParam)) {
        res.status(400).json({
          success: false,
          error: {
            code: 'INVALID_PERIOD',
            message: 'Período inválido. Use: today, week, month ou year.',
          },
        });
        return;
      }

      const period = periodParam as PeriodType;
      summary = await analyticsService.getAnalyticsSummary(companyId, period);
      periodLabel = getPeriodLabel(period);
    } else {
      // Default: current month
      const now = new Date();
      const monthStart = startOfMonth(now);
      const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0);

      summary = await analyticsService.getAnalyticsSummary(
        companyId,
        'custom',
        monthStart.toISOString().split('T')[0],
        monthEnd.toISOString().split('T')[0]
      );
      periodLabel = formatCurrentMonthLabel();
    }

    res.json({
      success: true,
      data: {
        summary: {
          period: {
            ...summary.period,
            label: periodLabel,
          },
          ordersTotal: summary.orders.total,
          ordersByStatus: summary.orders.byStatus,
          revenue: summary.revenue,
          topCustomers: summary.topCustomers,
          topServices: summary.topServices,
        },
        formatContext: getFormatContext(req.auth?.companyCountry),
      },
    });
  } catch (error) {
    console.error('Bot Analytics error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Erro ao buscar dados financeiros.' },
    });
  }
});

export default router;
