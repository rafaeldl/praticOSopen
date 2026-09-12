import { Router, Response } from 'express';
import { AuthenticatedRequest } from '../../models/types';
import {
  createIntegrationToken,
  listIntegrationTokens,
  revokeIntegrationToken,
} from '../../services/integration-token.service';

const router: Router = Router();

const MANAGER_ROLES = ['owner', 'admin'];

function ensureManager(req: AuthenticatedRequest, res: Response): boolean {
  const role = req.userContext?.role;
  if (!role || !MANAGER_ROLES.includes(role)) {
    res.status(403).json({
      success: false,
      error: {
        code: 'FORBIDDEN',
        message: 'Only owners and admins can manage integrations',
      },
    });
    return false;
  }
  return true;
}

router.get('/tokens', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (!ensureManager(req, res)) return;
    const companyId = req.userContext!.companyId;
    const data = await listIntegrationTokens(companyId);
    res.json({ success: true, data });
  } catch (error) {
    console.error('List integration tokens error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to list tokens' },
    });
  }
});

router.post('/tokens', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (!ensureManager(req, res)) return;

    const name = typeof req.body?.name === 'string' ? req.body.name.trim() : '';
    if (!name) {
      res.status(400).json({
        success: false,
        error: { code: 'VALIDATION_ERROR', message: 'name is required' },
      });
      return;
    }

    const companyId = req.userContext!.companyId;
    const userId = req.userContext!.userId;
    const data = await createIntegrationToken(companyId, userId, name);
    res.status(201).json({ success: true, data });
  } catch (error) {
    console.error('Create integration token error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to create token' },
    });
  }
});

router.delete('/tokens/:id', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (!ensureManager(req, res)) return;

    const companyId = req.userContext!.companyId;
    const id = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const ok = await revokeIntegrationToken(companyId, id);

    if (!ok) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Token not found' },
      });
      return;
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Revoke integration token error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to revoke token' },
    });
  }
});

export default router;
