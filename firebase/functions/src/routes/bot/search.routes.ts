/**
 * Bot Search Routes
 * Smart search endpoints for conversational UI
 */

import { Router, Response } from 'express';
import { AuthenticatedRequest } from '../../models/types';
import { requireLinked } from '../../middleware/auth.middleware';
import * as customerService from '../../services/customer.service';
import * as deviceService from '../../services/device.service';
import * as vcardService from '../../services/vcard.service';
import { validateInput, searchQuerySchema } from '../../utils/validation.utils';
import { normalizePhone } from '../../utils/format.utils';

const router: Router = Router();

/**
 * GET /api/bot/customers/search
 * Smart search for customers
 */
router.get('/search', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    // Validate query
    const validation = validateInput(searchQuerySchema, req.query);
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

    const { q } = validation.data;

    // Check if query looks like a phone number
    const isPhoneQuery = /^\+?\d{7,}$/.test(q.replace(/\D/g, ''));

    let exact = null;
    let suggestions: Array<{ id: string; name: string; phone?: string }> = [];

    if (isPhoneQuery) {
      // Search by phone
      const normalizedPhone = normalizePhone(q);
      const byPhone = await customerService.findCustomerByPhone(companyId, normalizedPhone);

      if (byPhone) {
        exact = {
          id: byPhone.id,
          name: byPhone.name,
          phone: byPhone.phone,
        };
      }
    }

    // Also search by name
    const byName = await customerService.searchCustomers(companyId, q, 5);
    suggestions = byName.map((c) => ({
      id: c.id,
      name: c.name,
      phone: c.phone,
    }));

    // Remove exact match from suggestions if present
    if (exact) {
      suggestions = suggestions.filter((s) => s.id !== exact!.id);
    }

    res.json({
      success: true,
      data: {
        exact,
        suggestions,
      },
    });
  } catch (error) {
    console.error('Search customers error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to search customers' },
    });
  }
});

/**
 * GET /api/bot/customers/:id/vcard
 * Get vCard for a customer
 */
router.get('/:id/vcard', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    const customer = await customerService.getCustomer(companyId, String(req.params.id));

    if (!customer) {
      res.status(404).json({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Customer not found' },
      });
      return;
    }

    const vcard = vcardService.generateVCard(customer);

    res.json({
      success: true,
      data: {
        vcard,
        displayName: customer.name,
      },
    });
  } catch (error) {
    console.error('Get vCard error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to generate vCard' },
    });
  }
});

/**
 * GET /api/bot/devices/search
 * Smart search for devices
 */
router.get('/devices/search', requireLinked, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const companyId = req.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({
        success: false,
        error: { code: 'UNAUTHORIZED', message: 'Company context required' },
      });
      return;
    }

    // Validate query
    const validation = validateInput(searchQuerySchema, req.query);
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

    const { q } = validation.data;

    let exact = null;
    let suggestions: Array<{ id: string; name: string; serial?: string }> = [];

    // Try to find by serial first
    const bySerial = await deviceService.findDeviceBySerial(companyId, q);
    if (bySerial) {
      exact = {
        id: bySerial.id,
        name: bySerial.name,
        serial: bySerial.serial,
      };
    }

    // Also search by name
    const byName = await deviceService.searchDevices(companyId, q, 5);
    suggestions = byName.map((d) => ({
      id: d.id,
      name: d.name,
      serial: d.serial,
    }));

    // Remove exact match from suggestions if present
    if (exact) {
      suggestions = suggestions.filter((s) => s.id !== exact!.id);
    }

    res.json({
      success: true,
      data: {
        exact,
        suggestions,
      },
    });
  } catch (error) {
    console.error('Search devices error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to search devices' },
    });
  }
});

export default router;
