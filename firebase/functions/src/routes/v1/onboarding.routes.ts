/**
 * First access on the web. Mounted at /v1/app/onboarding behind bearerAuth +
 * resolveCompanyContext: the browser creates the company (same batch as the
 * app), waits for the claim and then asks for the segment's data here.
 * docs/WEB_API.md, "Primeiro acesso".
 */

import { Router, Response } from 'express';
import { z } from 'zod';
import { AuthenticatedRequest } from '../../models/types';
import { requireAppPermission } from '../../middleware/app-permission.middleware';
import { ONBOARDING_LOCALES, OnboardingSeedError, seedOnboardingCompany } from '../../services/onboarding-seed.service';
import { validateInput } from '../../utils/validation.utils';

const router: Router = Router();

const seedSchema = z.object({
  withSamples: z.boolean(),
  locale: z.enum(ONBOARDING_LOCALES),
});

/**
 * POST /v1/app/onboarding/seed  {withSamples, locale}
 * Copies the segment checklists and, with samples, services, products, devices,
 * the sample customer and four sample orders, like the app's first access.
 * Only for who manages the company (the owner, right after creating it), once:
 * a transaction marks `onboardingSeededAt` first, and a company already marked
 * or created more than a day ago gets 409 and nothing is written.
 */
router.post('/seed', requireAppPermission('manageCompany'), async (req: AuthenticatedRequest, res: Response) => {
  const companyId = req.userContext?.companyId;
  const userId = req.userContext?.userId;
  if (!companyId || !userId) {
    res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Company context required' } });
    return;
  }
  const validation = validateInput(seedSchema, req.body);
  if (!validation.success) {
    res.status(400).json({ success: false, error: { code: 'VALIDATION_ERROR', message: validation.errors.join('; ') } });
    return;
  }
  try {
    const result = await seedOnboardingCompany({ companyId, userId, ...validation.data });
    res.json({ success: true, data: result });
  } catch (error) {
    if (error instanceof OnboardingSeedError) {
      const message = error.status === 409 ? 'The first access already prepared this company, or it is not new' : 'Company not ready for the first access';
      res.status(error.status).json({ success: false, error: { code: error.code, message } });
      return;
    }
    console.error('Onboarding seed error:', error instanceof Error ? error.message : 'unknown');
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: 'Failed to prepare the company' } });
  }
});

export default router;
