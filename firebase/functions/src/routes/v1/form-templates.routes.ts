/**
 * Form templates (checklists) for the web. Mounted at /v1/app/forms/templates.
 * Same plan rule as FormTemplateStore: creating or importing always counts;
 * editing counts only when it turns an inactive template on
 * (docs/PLAN_LIMITS_SERVER.md). Path: companies/{companyId}/forms/{formId}.
 */

import { Router, Response } from 'express';
import { z } from 'zod';
import { AuthenticatedRequest } from '../../models/types';
import { getUserAggr } from '../../middleware/company.middleware';
import { requireAppPermission } from '../../middleware/app-permission.middleware';
import { requirePlanCapacity } from '../../middleware/plan-limit.middleware';
import { db, getRootCollection, getTenantCollection } from '../../services/firestore.service';
import { validateInput } from '../../utils/validation.utils';

const router: Router = Router();

const itemsSchema = z.array(z.record(z.unknown())).max(200);
const createSchema = z.object({
  title: z.string().trim().min(1).max(200),
  description: z.string().max(2000).optional(),
  isActive: z.boolean().optional(),
  items: itemsSchema.optional(),
});
const updateSchema = z
  .object({
    title: z.string().trim().min(1).max(200).optional(),
    description: z.string().max(2000).nullable().optional(),
    isActive: z.boolean().optional(),
    items: itemsSchema.optional(),
  })
  .refine((data) => Object.keys(data).length > 0, { message: 'Nothing to update' });
const importSchema = z.object({
  segmentId: z.string().min(1).max(100),
  formId: z.string().min(1).max(200),
});

const templates = (companyId: string) => getTenantCollection(companyId, 'forms');
const companyOf = (req: AuthenticatedRequest) => req.userContext?.companyId as string;

function badRequest(res: Response, errors: string[]): void {
  res.status(400).json({ success: false, error: { code: 'VALIDATION_ERROR', message: errors.join(', ') } });
}

function failed(res: Response, message: string, error: unknown): void {
  console.error(`${message}:`, error instanceof Error ? error.message : 'unknown');
  res.status(500).json({ success: false, error: { code: 'INTERNAL_ERROR', message } });
}

async function companyAggr(companyId: string) {
  const snap = await getRootCollection('companies').doc(companyId).get();
  return { id: companyId, name: snap.get('name') ?? null };
}

/** Turning an inactive template on counts one more active template. */
async function activating(req: AuthenticatedRequest): Promise<number> {
  if (req.body?.isActive !== true) return 0;
  const snap = await templates(companyOf(req)).doc(String(req.params.id)).get();
  return snap.exists && snap.get('isActive') === false ? 1 : 0;
}

/** POST /v1/app/forms/templates — like saveTemplate: counts even when saved inactive. */
router.post('/', requireAppPermission('manageForms'), requirePlanCapacity('formTemplate'), async (req: AuthenticatedRequest, res: Response) => {
  const validation = validateInput(createSchema, req.body);
  if (!validation.success) return badRequest(res, validation.errors);
  try {
    const companyId = companyOf(req);
    const now = new Date().toISOString();
    const ref = templates(companyId).doc();
    const data = {
      title: validation.data.title,
      description: validation.data.description ?? null,
      isActive: validation.data.isActive ?? true,
      items: validation.data.items ?? [],
      company: await companyAggr(companyId),
      createdAt: now,
      createdBy: getUserAggr(req),
      updatedAt: now,
      updatedBy: getUserAggr(req),
    };
    await ref.set(data);
    res.status(201).json({ success: true, data: { id: ref.id, ...data } });
  } catch (error) {
    failed(res, 'Failed to create form template', error);
  }
});

/** POST /v1/app/forms/templates/import — copy of a segment template, like importGlobalTemplate. */
router.post('/import', requireAppPermission('manageForms'), requirePlanCapacity('formTemplate'), async (req: AuthenticatedRequest, res: Response) => {
  const validation = validateInput(importSchema, req.body);
  if (!validation.success) return badRequest(res, validation.errors);
  try {
    const companyId = companyOf(req);
    const source = await db
      .collection('segments')
      .doc(validation.data.segmentId)
      .collection('forms')
      .doc(validation.data.formId)
      .get();
    if (!source.exists) {
      res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Form template not found' } });
      return;
    }
    const global = source.data() as Record<string, unknown>;
    const now = new Date().toISOString();
    const ref = templates(companyId).doc();
    // The app copies title, description, isActive and items only.
    const data = {
      title: global.title ?? '',
      description: global.description ?? null,
      isActive: global.isActive ?? true,
      items: Array.isArray(global.items) ? global.items : [],
      company: await companyAggr(companyId),
      createdAt: now,
      createdBy: getUserAggr(req),
      updatedAt: now,
      updatedBy: getUserAggr(req),
    };
    await ref.set(data);
    res.status(201).json({ success: true, data: { id: ref.id, ...data } });
  } catch (error) {
    failed(res, 'Failed to import form template', error);
  }
});

/** PATCH /v1/app/forms/templates/:id */
router.patch('/:id', requireAppPermission('manageForms'), requirePlanCapacity('formTemplate', activating), async (req: AuthenticatedRequest, res: Response) => {
  const validation = validateInput(updateSchema, req.body);
  if (!validation.success) return badRequest(res, validation.errors);
  try {
    const ref = templates(companyOf(req)).doc(String(req.params.id));
    if (!(await ref.get()).exists) {
      res.status(404).json({ success: false, error: { code: 'NOT_FOUND', message: 'Form template not found' } });
      return;
    }
    await ref.update({ ...validation.data, updatedAt: new Date().toISOString(), updatedBy: getUserAggr(req) });
    res.json({ success: true, data: { id: ref.id } });
  } catch (error) {
    failed(res, 'Failed to update form template', error);
  }
});

/** DELETE /v1/app/forms/templates/:id */
router.delete('/:id', requireAppPermission('manageForms'), async (req: AuthenticatedRequest, res: Response) => {
  try {
    await templates(companyOf(req)).doc(String(req.params.id)).delete();
    res.json({ success: true });
  } catch (error) {
    failed(res, 'Failed to delete form template', error);
  }
});

export default router;
