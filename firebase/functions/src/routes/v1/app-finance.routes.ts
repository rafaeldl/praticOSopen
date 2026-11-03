/**
 * /v1/app/finance for the web app (docs/WEB_API.md, "Financeiro"). Only who has
 * `viewFinancialReports` (owner, admin, manager, with "Valores e cobrança" on):
 * everyone else gets 403 and no number at all.
 *
 * - GET /summary?month=YYYY-MM[&zone=]          Recebido, Vendido, A receber, Em andamento
 * - GET /report?from=YYYY-MM-DD&to=YYYY-MM-DD[&customer=][&payment=][&zone=]
 * - GET /receivable[?zone=]                     every order that still owes (Financeiro > Receber)
 *
 * `zone` is the browser's: it counts only when it is a zone of the company's
 * country (utils/company-zone.ts). Days are the company's, both ends included.
 */
import { Router, Request, Response } from 'express';
import type { AuthenticatedRequest } from '../../models/types';
import { can, forbidden } from '../../middleware/app-permission.middleware';
import { db } from '../../services/firestore.service';
import { financeReport, financeSummary, receivableOrders } from '../../services/app-finance.service';
import { companyZone, dayIn } from '../../utils/company-zone';
import { sendOrderError } from './orders.routes';

const router: Router = Router();

const DAY = /^(\d{4})-(\d{2})-(\d{2})$/;
const MONTH = /^(\d{4})-(\d{2})$/;
/** The app's custom period starts in 2020: about seven years, with room. */
const MAX_DAYS = 4000;

const validationError = (res: Response, message: string) =>
  res.status(400).json({ success: false, error: { code: 'VALIDATION_ERROR', message } });

function validDay(value: unknown): value is string {
  if (typeof value !== 'string') return false;
  const match = DAY.exec(value);
  if (!match) return false;
  const date = new Date(Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3])));
  return date.toISOString().slice(0, 10) === value && Number(match[1]) >= 2000;
}

function lastDayOf(month: string): string {
  const [y, m] = month.split('-').map(Number);
  return new Date(Date.UTC(y, m, 0)).toISOString().slice(0, 10);
}

const daysBetween = (from: string, to: string) => (Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86400000;

type Handler = (req: AuthenticatedRequest, res: Response, companyId: string, zone: string) => Promise<void>;

function route(fallback: string, handler: Handler) {
  return async (req: Request, res: Response): Promise<void> => {
    const authReq = req as AuthenticatedRequest;
    const companyId = authReq.auth?.companyId ?? authReq.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Company context required' } });
      return;
    }
    try {
      // Permission first: who cannot see money learns nothing, not even a validation message.
      if (!(await can(authReq, res, 'viewFinancialReports'))) return void forbidden(res, "Permission 'viewFinancialReports' is required");
      const company = (await db.collection('companies').doc(companyId).get()).data();
      const requested = typeof req.query.zone === 'string' ? req.query.zone.slice(0, 64) : null;
      await handler(authReq, res, companyId, companyZone(company?.country as string | undefined, requested));
    } catch (error) {
      sendOrderError(res, error, fallback);
    }
  };
}

router.get('/summary', route('Failed to read the financial summary', async (req, res, companyId, zone) => {
  const month = req.query.month === undefined ? dayIn(new Date(), zone).slice(0, 7) : req.query.month;
  const match = typeof month === 'string' ? MONTH.exec(month) : null;
  if (!match || Number(match[2]) < 1 || Number(match[2]) > 12 || Number(match[1]) < 2000) {
    return void validationError(res, 'month must be YYYY-MM');
  }
  const from = `${month}-01`;
  const data = await financeSummary(companyId, { from, to: lastDayOf(month as string), zone });
  res.json({ success: true, data: { month, zone, ...data } });
}));

router.get('/report', route('Failed to read the financial report', async (req, res, companyId, zone) => {
  const { from, to, customer, payment } = req.query;
  if (!validDay(from) || !validDay(to)) return void validationError(res, 'from and to must be YYYY-MM-DD');
  if (to < from) return void validationError(res, 'to must not be before from');
  if (daysBetween(from, to) > MAX_DAYS) return void validationError(res, 'period too long');
  if (payment !== undefined && payment !== 'paid' && payment !== 'unpaid') return void validationError(res, 'payment must be paid or unpaid');
  if (customer !== undefined && (typeof customer !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(customer))) {
    return void validationError(res, 'invalid customer');
  }
  const data = await financeReport(companyId, {
    from,
    to,
    zone,
    customer: (customer as string | undefined) ?? null,
    payment: (payment as 'paid' | 'unpaid' | undefined) ?? null,
  });
  res.json({ success: true, data: { zone, today: dayIn(new Date(), zone), ...data } });
}));

router.get('/receivable', route('Failed to read what is to receive', async (_req, res, companyId, zone) => {
  const data = await receivableOrders(companyId, zone);
  res.json({ success: true, data });
}));

export default router;
