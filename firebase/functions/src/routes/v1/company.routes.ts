/**
 * Company Routes
 * Endpoints for company and member management
 */

import { Router, Response } from 'express';
import { z } from 'zod';
import { AuthenticatedRequest, RoleType } from '../../models/types';
import { getUserAggr } from '../../middleware/company.middleware';
import { requirePermission } from '../../middleware/auth.middleware';
import * as companyService from '../../services/company.service';
import { validateInput } from '../../utils/validation.utils';

const router: Router = Router();

// Validation schemas
const updateCompanySchema = z.object({
  name: z.string().min(1).max(200).optional(),
  phone: z.string().max(50).optional(),
  email: z.string().email().optional(),
  address: z.string().max(500).optional(),
  logo: z.string().url().optional(),
});

const updateMemberRoleSchema = z.object({
  role: z.enum(['admin', 'supervisor', 'manager', 'consultant', 'technician']),
});

/**
 * GET /api/v1/company
 * Get current company details
 */
router.get('/', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.auth?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    const company = await companyService.getCompany(companyId);

    if (!company) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Company not found' },
      });
      return;
    }

    res.json({
      success: true,
      data: {
        id: company.id,
        name: company.name,
        segment: company.segment,
        country: company.country,
        phone: company.phone,
        email: company.email,
        address: company.address,
        logo: company.logo,
      },
    });
  } catch (error) {
    console.error('Get company error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get company' },
    });
  }
});

/**
 * PATCH /api/v1/company
 * Update company details (admin only)
 */
router.patch(
  '/',
  requirePermission('manage:company'),
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const companyId = req.auth?.companyId;
      if (!companyId) {
        res.status(401).json({
          success: false,
          error: { code: 'UNAUTHORIZED', message: 'Company context required' },
        });
        return;
      }

      // Validate input
      const validation = validateInput(updateCompanySchema, req.body);
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

      const updatedBy = getUserAggr(req);

      const updated = await companyService.updateCompany(
        companyId,
        validation.data,
        updatedBy
      );

      if (!updated) {
        res.status(404).json({
          success: false,
          error: { code: 'NOT_FOUND', message: 'Company not found' },
        });
        return;
      }

      res.json({
        success: true,
        data: {
          id: companyId,
          updated: true,
        },
      });
    } catch (error) {
      console.error('Update company error:', error);
      res.status(500).json({
        success: false,
        error: { code: 'INTERNAL_ERROR', message: 'Failed to update company' },
      });
    }
  }
);

/**
 * GET /api/v1/company/members
 * List company members
 */
router.get('/members', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.auth?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    const members = await companyService.listCompanyMembers(companyId);

    res.json({
      success: true,
      data: {
        members,
      },
    });
  } catch (error) {
    console.error('List members error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to list members' },
    });
  }
});

/**
 * PATCH /api/v1/company/members/:userId
 * Update member role (admin only)
 */
router.patch(
  '/members/:userId',
  requirePermission('manage:members'),
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const companyId = req.auth?.companyId;
      if (!companyId) {
        res.status(401).json({
          success: false,
          error: { code: 'UNAUTHORIZED', message: 'Company context required' },
        });
        return;
      }

      // Validate input
      const validation = validateInput(updateMemberRoleSchema, req.body);
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

      const updatedBy = getUserAggr(req);

      const updated = await companyService.updateMemberRole(
        companyId,
        String(req.params.userId),
        validation.data.role as RoleType,
        updatedBy
      );

      if (!updated) {
        res.status(404).json({
          success: false,
          error: { code: 'NOT_FOUND', message: 'Member not found' },
        });
        return;
      }

      res.json({
        success: true,
        data: {
          userId: req.params.userId,
          newRole: validation.data.role,
          updated: true,
        },
      });
    } catch (error) {
      console.error('Update member role error:', error);

      if ((error as Error).message === 'Cannot change owner role') {
        res.status(403).json({
          success: false,
          error: { code: 'FORBIDDEN', message: 'Cannot change owner role' },
        });
        return;
      }

      res.status(500).json({
        success: false,
        error: { code: 'INTERNAL_ERROR', message: 'Failed to update member role' },
      });
    }
  }
);

/**
 * DELETE /api/v1/company/members/:userId
 * Remove member from company (admin only)
 */
router.delete(
  '/members/:userId',
  requirePermission('manage:members'),
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const companyId = req.auth?.companyId;
      if (!companyId) {
        res.status(401).json({
          success: false,
          error: { code: 'UNAUTHORIZED', message: 'Company context required' },
        });
        return;
      }

      const removedBy = getUserAggr(req);

      const removed = await companyService.removeMember(
        companyId,
        String(req.params.userId),
        removedBy
      );

      if (!removed) {
        res.status(404).json({
          success: false,
          error: { code: 'NOT_FOUND', message: 'Member not found' },
        });
        return;
      }

      res.json({
        success: true,
        data: {
          success: true,
          message: 'Member removed successfully',
        },
      });
    } catch (error) {
      console.error('Remove member error:', error);

      if ((error as Error).message === 'Cannot remove owner') {
        res.status(403).json({
          success: false,
          error: { code: 'FORBIDDEN', message: 'Cannot remove owner' },
        });
        return;
      }

      res.status(500).json({
        success: false,
        error: { code: 'INTERNAL_ERROR', message: 'Failed to remove member' },
      });
    }
  }
);

export default router;
