/**
 * /v1/app/devices for the web app (docs/WEB_API.md, "Clientes e aparelhos").
 * Mounted before the generic devices router; /v1/devices (API key) is unchanged.
 *
 * - GET /                         every device, with status and next maintenance
 * - GET /:id                      device, owner, orders the person reads, last service
 * - POST /, PATCH /:id            model or serial required; serial uppercase; status; segment fields
 * - DELETE /:id                   delete
 * - PUT /:id/next-maintenance     {date: 'YYYY-MM-DD' | null}
 */
import { Router, Request, Response } from 'express';
import { z } from 'zod';
import type { AuthenticatedRequest } from '../../models/types';
import { can, forbidden } from '../../middleware/app-permission.middleware';
import { getCompanyAggr, getUserAggr } from '../../middleware/company.middleware';
import * as directory from '../../services/app-directory.service';
import { validateInput } from '../../utils/validation.utils';
import { orderScopeOf } from './app-customers.routes';
import { sendOrderError } from './orders.routes';

const router: Router = Router();

type Handler = (req: AuthenticatedRequest, res: Response, companyId: string) => Promise<void>;

function route(fallback: string, handler: Handler) {
  return async (req: Request, res: Response): Promise<void> => {
    const authReq = req as AuthenticatedRequest;
    const companyId = authReq.auth?.companyId ?? authReq.userContext?.companyId;
    if (!companyId) {
      res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Company context required' } });
      return;
    }
    try {
      await handler(authReq, res, companyId);
    } catch (error) {
      sendOrderError(res, error, fallback);
    }
  };
}

const param = (req: Request, name: string) => String(req.params[name]);
const validationError = (res: Response, errors: string[]) =>
  res.status(400).json({ success: false, error: { code: 'VALIDATION_ERROR', message: errors.join(', ') } });
const notFound = (res: Response) => res.status(404).json({ success: false, error: { code: 'DEVICE_NOT_FOUND', message: 'Device not found' } });

const optionalText = (max: number) => z.string().trim().max(max).nullable().optional();
const deviceBody = {
  name: optionalText(200),
  serial: optionalText(100),
  manufacturer: optionalText(100),
  category: optionalText(100),
  description: optionalText(1000),
  status: z.enum(directory.DEVICE_STATUSES).nullable().optional(),
  customData: z
    .record(z.string().min(1).max(100), z.union([z.string().max(2000), z.number(), z.boolean(), z.null()]))
    .refine((value) => Object.keys(value).length <= 100, 'Too many custom fields')
    .nullable()
    .optional(),
};
const createSchema = z.object(deviceBody).refine((value) => !!value.name?.trim() || !!value.serial?.trim(), 'Model or serial is required');
const updateSchema = z.object(deviceBody);
const maintenanceSchema = z.object({ date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullable() });

router.get('/', route('Failed to list devices', async (req, res, companyId) => {
  if (!(await can(req, res, 'viewDevices'))) return forbidden(res, "Permission 'viewDevices' is required");
  const result = await directory.deviceDirectory(companyId);
  res.json({ success: true, data: result.devices, meta: { total: result.devices.length, truncated: result.truncated } });
}));

router.get('/:id', route('Failed to get device', async (req, res, companyId) => {
  if (!(await can(req, res, 'viewDevices'))) return forbidden(res, "Permission 'viewDevices' is required");
  const screen = await directory.deviceScreen(companyId, param(req, 'id'), await orderScopeOf(req, res), await can(req, res, 'viewPrices'));
  if (!screen) return void notFound(res);
  res.json({ success: true, data: screen });
}));

router.post('/', route('Failed to create device', async (req, res, companyId) => {
  if (!(await can(req, res, 'manageDevices'))) return forbidden(res, "Permission 'manageDevices' is required");
  const validation = validateInput(createSchema, req.body);
  if (!validation.success) return void validationError(res, validation.errors);
  const created = await directory.createDevice(companyId, validation.data, getUserAggr(req), getCompanyAggr(req));
  res.status(201).json({ success: true, data: created });
}));

router.patch('/:id', route('Failed to update device', async (req, res, companyId) => {
  if (!(await can(req, res, 'manageDevices'))) return forbidden(res, "Permission 'manageDevices' is required");
  const validation = validateInput(updateSchema, req.body);
  if (!validation.success) return void validationError(res, validation.errors);
  const result = await directory.updateDevice(companyId, param(req, 'id'), validation.data, getUserAggr(req));
  if (result === 'not_found') return void notFound(res);
  if (result === 'empty') return void validationError(res, ['Model or serial is required']);
  res.json({ success: true, data: { id: param(req, 'id'), updated: true } });
}));

router.delete('/:id', route('Failed to delete device', async (req, res, companyId) => {
  if (!(await can(req, res, 'manageDevices'))) return forbidden(res, "Permission 'manageDevices' is required");
  if (!(await directory.deleteDevice(companyId, param(req, 'id')))) return void notFound(res);
  res.json({ success: true, data: { id: param(req, 'id'), deleted: true } });
}));

router.put('/:id/next-maintenance', route('Failed to set next maintenance', async (req, res, companyId) => {
  if (!(await can(req, res, 'manageDevices'))) return forbidden(res, "Permission 'manageDevices' is required");
  const validation = validateInput(maintenanceSchema, req.body);
  if (!validation.success) return void validationError(res, validation.errors);
  const { date } = validation.data;
  // Only a day from today on (device.detail.maintenance-edit), and a real day.
  if (date !== null && (date < directory.todayInBrazil() || Number.isNaN(Date.parse(`${date}T12:00:00Z`)) || new Date(`${date}T12:00:00Z`).toISOString().slice(0, 10) !== date)) {
    return void validationError(res, ['date must be a day from today on']);
  }
  if (!(await directory.setNextMaintenance(companyId, param(req, 'id'), date))) return void notFound(res);
  res.json({ success: true, data: { id: param(req, 'id'), nextMaintenanceDate: date } });
}));

export default router;
