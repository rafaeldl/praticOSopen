/**
 * Bot Registration Routes
 * Endpoints for WhatsApp self-registration flow
 *
 * Flow:
 * 1. POST /bot/registration/start - Start registration, get segments list
 * 2. POST /bot/registration/update - Update registration data (company name, segment, etc.)
 * 3. POST /bot/registration/complete - Complete registration (create user, company, link)
 * 4. DELETE /bot/registration - Cancel active registration
 * 5. GET /bot/registration/status - Get current registration status
 * 6. GET /bot/registration/segments - Get available segments (for reference)
 */

import { Router, Response } from 'express';
import { AuthenticatedRequest } from '../../models/types';
import * as registrationService from '../../services/registration.service';

const router: Router = Router();

// ============================================================================
// Routes
// ============================================================================

/**
 * POST /api/bot/registration/start
 * Start a new registration
 *
 * Body: { locale?: string }
 * Returns: { token, segments[] }
 */
router.post('/start', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const whatsappNumber = req.headers['x-whatsapp-number'] as string;

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

    const { locale } = req.body || {};

    const result = await registrationService.startRegistration(
      whatsappNumber,
      locale
    );

    if (!result.success) {
      const statusCode = result.code === 'ALREADY_LINKED' ? 409
        : result.code === 'RATE_LIMIT_EXCEEDED' ? 429
        : 400;

      res.status(statusCode).json({
        success: false,
        error: {
          code: result.code,
          message: result.error,
        },
      });
      return;
    }

    // Format segments for bot consumption
    const formattedSegments = result.segments.map((segment, index) => ({
      index: index + 1,
      id: segment.id,
      name: segment.name,
      icon: segment.icon || '',
      nameI18n: segment.nameI18n,
      hasSubspecialties: segment.subspecialties && segment.subspecialties.length > 0,
      subspecialtiesCount: segment.subspecialties?.length || 0,
    }));

    res.status(201).json({
      success: true,
      data: {
        token: result.token,
        state: 'awaiting_company_name',
        segments: formattedSegments,
        message: 'Registration started. Please provide your company name.',
      },
    });
  } catch (error) {
    console.error('Start registration error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to start registration' },
    });
  }
});

/**
 * POST /api/bot/registration/update
 * Update registration data
 *
 * Body: { companyName?, segmentId?, subspecialties?, includeBootstrap?, locale? }
 * Returns: { registration, nextStep, options? }
 */
router.post('/update', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const whatsappNumber = req.headers['x-whatsapp-number'] as string;

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

    // Get active registration for this phone
    const registration = await registrationService.getActiveByPhone(whatsappNumber);

    if (!registration) {
      res.status(404).json({
        success: false,
        error: {
          code: 'NOT_FOUND',
          message: 'No active registration found. Start a new registration first.',
        },
      });
      return;
    }

    const { companyName, segmentId, subspecialties, includeBootstrap, locale } = req.body;

    // Build updates based on current state
    const dataUpdates: Partial<registrationService.RegistrationData> = {};
    let newState: registrationService.RegistrationState | undefined;

    // Process updates based on current state
    switch (registration.state) {
      case 'awaiting_company_name':
        if (!companyName || typeof companyName !== 'string' || companyName.trim().length < 2) {
          res.status(400).json({
            success: false,
            error: {
              code: 'VALIDATION_ERROR',
              message: 'Company name is required (minimum 2 characters)',
            },
          });
          return;
        }
        dataUpdates.companyName = companyName.trim();
        newState = 'awaiting_segment';
        break;

      case 'awaiting_segment':
        if (!segmentId) {
          res.status(400).json({
            success: false,
            error: {
              code: 'VALIDATION_ERROR',
              message: 'Segment ID is required',
            },
          });
          return;
        }

        // Validate segment exists
        const segment = await registrationService.getSegmentById(segmentId);
        if (!segment || !segment.active) {
          res.status(400).json({
            success: false,
            error: {
              code: 'INVALID_SEGMENT',
              message: 'Invalid segment ID',
            },
          });
          return;
        }

        dataUpdates.segmentId = segmentId;

        // Check if segment has subspecialties
        if (segment.subspecialties && segment.subspecialties.length > 0) {
          newState = 'awaiting_subspecialties';
        } else {
          dataUpdates.subspecialties = [];
          newState = 'awaiting_bootstrap';
        }
        break;

      case 'awaiting_subspecialties':
        // subspecialties can be empty array (user skipped)
        dataUpdates.subspecialties = Array.isArray(subspecialties) ? subspecialties : [];
        newState = 'awaiting_bootstrap';
        break;

      case 'awaiting_bootstrap':
        dataUpdates.includeBootstrap = includeBootstrap === true;
        newState = 'awaiting_confirm';
        break;

      default:
        res.status(400).json({
          success: false,
          error: {
            code: 'INVALID_STATE',
            message: `Cannot update registration in state: ${registration.state}`,
          },
        });
        return;
    }

    // Also accept locale at any point
    if (locale) {
      dataUpdates.locale = locale;
    }

    // Update registration
    const updated = await registrationService.updateRegistration(registration.token, {
      state: newState,
      data: dataUpdates,
    });

    if (!('token' in updated)) {
      res.status(400).json({
        success: false,
        error: {
          code: updated.code,
          message: updated.error,
        },
      });
      return;
    }

    // Build response based on new state
    const response: Record<string, unknown> = {
      token: updated.token,
      state: updated.state,
      data: updated.data,
    };

    // Add next step information
    switch (updated.state) {
      case 'awaiting_segment': {
        const segments = await registrationService.getActiveSegments();
        response.nextStep = 'Select a segment for your business';
        response.segments = segments.map((s, index) => ({
          index: index + 1,
          id: s.id,
          name: s.name,
          icon: s.icon || '',
          nameI18n: s.nameI18n,
          hasSubspecialties: s.subspecialties && s.subspecialties.length > 0,
        }));
        break;
      }

      case 'awaiting_subspecialties': {
        const currentSegment = await registrationService.getSegmentById(updated.data.segmentId!);
        if (currentSegment?.subspecialties) {
          response.nextStep = 'Select your specialties (optional)';
          response.subspecialties = currentSegment.subspecialties.map((s, index) => ({
            index: index + 1,
            id: s.id,
            name: s.name,
            nameI18n: s.nameI18n,
          }));
        }
        break;
      }

      case 'awaiting_bootstrap':
        response.nextStep = 'Would you like to include sample data (services, products)?';
        response.options = [
          { value: true, label: 'Yes, include sample data' },
          { value: false, label: 'No, start with empty catalog' },
        ];
        break;

      case 'awaiting_confirm': {
        response.nextStep = 'Please confirm your registration';

        // Build summary
        const segmentInfo = updated.data.segmentId
          ? await registrationService.getSegmentById(updated.data.segmentId)
          : null;

        response.summary = {
          companyName: updated.data.companyName,
          segment: segmentInfo ? {
            id: segmentInfo.id,
            name: segmentInfo.name,
            nameI18n: segmentInfo.nameI18n,
          } : null,
          subspecialties: updated.data.subspecialties || [],
          includeBootstrap: updated.data.includeBootstrap,
        };
        break;
      }
    }

    res.json({
      success: true,
      data: response,
    });
  } catch (error) {
    console.error('Update registration error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to update registration' },
    });
  }
});

/**
 * POST /api/bot/registration/complete
 * Complete registration and create all entities
 *
 * Returns: { userId, userName, companyId, companyName, bootstrapResult? }
 */
router.post('/complete', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const whatsappNumber = req.headers['x-whatsapp-number'] as string;

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

    // Get active registration for this phone
    const registration = await registrationService.getActiveByPhone(whatsappNumber);

    if (!registration) {
      res.status(404).json({
        success: false,
        error: {
          code: 'NOT_FOUND',
          message: 'No active registration found',
        },
      });
      return;
    }

    if (registration.state !== 'awaiting_confirm') {
      res.status(400).json({
        success: false,
        error: {
          code: 'INVALID_STATE',
          message: 'Registration is not ready for completion. Please complete all steps first.',
        },
      });
      return;
    }

    const result = await registrationService.completeRegistration(registration.token);

    if (!result.success) {
      res.status(400).json({
        success: false,
        error: {
          code: result.code,
          message: result.error,
        },
      });
      return;
    }

    res.json({
      success: true,
      data: {
        userId: result.userId,
        userName: result.userName,
        companyId: result.companyId,
        companyName: result.companyName,
        bootstrapResult: result.bootstrapResult,
        message: 'Registration completed successfully! Welcome to PraticOS.',
      },
    });
  } catch (error) {
    console.error('Complete registration error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to complete registration' },
    });
  }
});

/**
 * DELETE /api/bot/registration
 * Cancel active registration
 */
router.delete('/', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const whatsappNumber = req.headers['x-whatsapp-number'] as string;

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

    const cancelled = await registrationService.cancelRegistrationByPhone(whatsappNumber);

    if (!cancelled) {
      res.status(404).json({
        success: false,
        error: {
          code: 'NOT_FOUND',
          message: 'No active registration found to cancel',
        },
      });
      return;
    }

    res.json({
      success: true,
      data: {
        message: 'Registration cancelled successfully',
      },
    });
  } catch (error) {
    console.error('Cancel registration error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to cancel registration' },
    });
  }
});

/**
 * GET /api/bot/registration/status
 * Get current registration status for a phone number
 */
router.get('/status', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const whatsappNumber = req.headers['x-whatsapp-number'] as string;

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

    const registration = await registrationService.getActiveByPhone(whatsappNumber);

    if (!registration) {
      res.json({
        success: true,
        data: {
          hasActiveRegistration: false,
        },
      });
      return;
    }

    res.json({
      success: true,
      data: {
        hasActiveRegistration: true,
        token: registration.token,
        state: registration.state,
        data: registration.data,
        expiresAt: registration.expiresAt,
      },
    });
  } catch (error) {
    console.error('Get registration status error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get registration status' },
    });
  }
});

/**
 * GET /api/bot/registration/segments
 * Get all available segments with subspecialties
 */
router.get('/segments', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const locale = (req.query.locale as string) || 'pt-BR';
    const segments = await registrationService.getActiveSegments();

    const formattedSegments = segments.map((segment, index) => {
      const name = registrationService.getLocalizedName(segment, locale);

      const subspecialties = segment.subspecialties?.map((sub, subIndex) => ({
        index: subIndex + 1,
        id: sub.id,
        name: registrationService.getLocalizedName(sub, locale),
      })) || [];

      return {
        index: index + 1,
        id: segment.id,
        name,
        icon: segment.icon || '',
        subspecialties,
      };
    });

    res.json({
      success: true,
      data: {
        segments: formattedSegments,
      },
    });
  } catch (error) {
    console.error('Get segments error:', error);
    res.status(500).json({
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to get segments' },
    });
  }
});

export default router;
