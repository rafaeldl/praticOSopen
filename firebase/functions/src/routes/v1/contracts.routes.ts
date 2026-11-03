/**
 * Recurring contracts (app and web). Mounted at /v1/app/contracts behind
 * bearerAuth + resolveCompanyContext. docs/CONTRACTS_SERVER_JOB.md.
 */

import { Router, Response } from 'express';
import { AuthenticatedRequest } from '../../models/types';
import { requireAppPermission, roleHasPermission } from '../../middleware/app-permission.middleware';
import { generateDueOrders } from '../../services/contract.service';

const router: Router = Router();

/**
 * POST /v1/app/contracts/generate-due
 * Generates the due orders of the company now, like the app does when it
 * opens: needs `createOrder` (the manager can't); consultant and technician
 * generate only from the contracts they created. Safe to repeat: an order
 * that already exists for a due date is not created again.
 */
router.post('/generate-due', requireAppPermission('createOrder'), async (req: AuthenticatedRequest, res: Response) => {
  const companyId = req.userContext?.companyId;
  if (!companyId) {
    res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Company context required' } });
    return;
  }
  try {
    // Same scope as TenantOrderRepository.creatorScope (orderCreatorFilterFor).
    const seesAll = roleHasPermission(req.userContext?.role, 'viewAllOrders', undefined);
    const result = await generateDueOrders(companyId, {
      now: new Date(),
      createdById: seesAll ? null : req.userContext?.userId,
    });
    res.json({
      success: true,
      data: {
        contractsOn: result.contractsOn,
        generated: result.generated,
        alreadyGenerated: result.alreadyGenerated,
        errors: result.errors,
        orders: result.results
          .filter((item) => item.outcome === 'generated')
          .map(({ templateId, orderId }) => ({ templateId, orderId })),
      },
    });
  } catch (error) {
    console.error('Generate due contracts error:', error instanceof Error ? error.message : 'unknown');
    res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message: 'Failed to generate due orders' } });
  }
});

export default router;
