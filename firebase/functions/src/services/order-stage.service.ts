/**
 * Work stages (`stage`): where an in-progress order is in the shop (Pintura,
 * Polimento), and its place in that column of the board. The company lists its
 * stages in `companies/{id}.workStages`; an empty or missing list turns it off.
 *
 * `status` stays `progress`: finance, filters, the invoice and the app read
 * nothing new. The stage is written only here (PUT /v1/app/orders/:id/stage),
 * and it goes away when the order leaves `progress`: in updateOrder for the
 * API and by the trigger for every other path (app, bot, MCP).
 */
import { db, FieldValue } from './firestore.service';
import { OrderWriteOptions, readOrderForWrite, statusUpdateFields } from './order.service';
import { OrderRuleError } from './order-errors';
import { internalComment } from './order-hold.service';
import type { Order, OrderStage, UserAggr, WorkStage } from '../models/types';

interface OrderStageSnapshot {
  status?: string | null;
  stage?: unknown;
}

export function stageNoLongerApplies(order: OrderStageSnapshot | undefined): boolean {
  return !!order?.stage && order.status !== 'progress';
}

/** The write does not loop: without `stage` the trigger has nothing to do. */
export async function clearOrderStage(companyId: string, orderId: string): Promise<void> {
  const ref = db.collection('companies').doc(companyId).collection('orders').doc(orderId);
  await db.runTransaction(async (tx) => {
    const data = (await tx.get(ref)).data();
    if (!stageNoLongerApplies(data)) return;
    tx.update(ref, { stage: FieldValue.delete() });
  });
}

/** The company's stages as stored, dropping entries without an id or a name. */
export function workStagesOf(company: { workStages?: unknown } | undefined): WorkStage[] {
  const list = Array.isArray(company?.workStages) ? (company!.workStages as Partial<WorkStage>[]) : [];
  return list
    .filter((stage) => typeof stage?.id === 'string' && stage.id && typeof stage.name === 'string' && stage.name.trim())
    .map((stage) => ({
      id: stage.id as string,
      name: (stage.name as string).trim(),
      ...(Array.isArray(stage.keywords) ? { keywords: stage.keywords.filter((word): word is string => typeof word === 'string') } : {}),
    }));
}

export interface SetOrderStageOptions extends OrderWriteOptions {
  /** An approved order starts the work here: who may move it to `progress` (403 otherwise). */
  canStart: (order: Order) => boolean;
}

/**
 * Puts the order in a stage, at `rank` (end of the column when absent). An
 * approved order goes to `progress` in the same write; any other status but
 * `progress` is refused (409). Changing the stage leaves an internal comment;
 * reordering inside the same stage does not.
 */
export async function setOrderStage(
  companyId: string,
  orderId: string,
  input: { stageId: string; rank?: number },
  actor: UserAggr,
  options: SetOrderStageOptions,
): Promise<Order | null> {
  const companyRef = db.collection('companies').doc(companyId);
  const ref = companyRef.collection('orders').doc(orderId);
  // Read apart: stages rarely change, and a read in the transaction would lock
  // the company document (order counters write it often).
  const stages = workStagesOf((await companyRef.get()).data());
  return db.runTransaction(async (tx) => {
    const order = await readOrderForWrite(tx, ref, options);
    if (!order) return null;
    const target = stages.find((stage) => stage.id === input.stageId);
    if (!target) throw new OrderRuleError('STAGE_UNKNOWN', 422, 'The company has no such work stage');
    if (order.status !== 'approved' && order.status !== 'progress') {
      throw new OrderRuleError('STAGE_NOT_ALLOWED', 409, 'Only approved or in-progress orders have a work stage');
    }
    if (order.status === 'approved' && !options.canStart(order)) {
      throw new OrderRuleError('INSUFFICIENT_PERMISSIONS', 403, 'Not allowed to start this order');
    }

    const now = new Date();
    const changed = order.stage?.id !== target.id || order.status !== 'progress';
    const stage: OrderStage = {
      id: target.id,
      rank: Number.isFinite(input.rank) ? (input.rank as number) : now.getTime(),
      since: !changed && order.stage?.since ? order.stage.since : now.toISOString(),
    };
    const update: Record<string, unknown> = {
      ...(order.status === 'approved' ? statusUpdateFields(order, 'progress') : {}),
      stage,
      updatedAt: now.toISOString(),
      updatedBy: actor,
    };
    tx.update(ref, update);
    if (changed) tx.set(ref.collection('comments').doc(), internalComment(`Etapa: ${target.name}`, actor));
    return { ...order, ...update } as Order;
  });
}
