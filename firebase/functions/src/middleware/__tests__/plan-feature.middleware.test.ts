import { ensurePlanFeature, requirePlanFeature, type PlanFeatureDeps } from '../plan-limit.middleware';
import type { PlanFeatureCheck } from '../../services/plan-features.service';

const denied: PlanFeatureCheck = { allowed: false, feature: 'teamRoles', plan: 'starter', requiredPlan: 'pro' };
const allowed: PlanFeatureCheck = { ...denied, allowed: true, plan: 'pro' };

function response() {
  const res: any = { status: jest.fn(() => res), json: jest.fn(() => res) };
  return res;
}

async function run(feature: Parameters<typeof requirePlanFeature>[0], deps: PlanFeatureDeps, body: unknown = {}) {
  const req: any = { userContext: { companyId: 'c1' }, body };
  const res = response();
  const next = jest.fn();
  await requirePlanFeature(feature, deps)(req, res, next);
  return { res, next };
}

describe('requirePlanFeature', () => {
  it('not in the plan: 402 PLAN_FEATURE with the plan that has it', async () => {
    const check = jest.fn(async () => denied);
    const { res, next } = await run('teamRoles', { check });
    expect(check).toHaveBeenCalledWith('c1', 'teamRoles');
    expect(next).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(402);
    expect(res.json.mock.calls[0][0].error).toMatchObject({ code: 'PLAN_FEATURE', feature: 'teamRoles', plan: 'starter', requiredPlan: 'pro' });
  });

  it('in the plan: next()', async () => {
    const { res, next } = await run('teamRoles', { check: async () => allowed });
    expect(next).toHaveBeenCalledTimes(1);
    expect(res.status).not.toHaveBeenCalled();
  });

  it('feature from the request: an admin invite checks nothing', async () => {
    const check = jest.fn(async () => denied);
    const byRole = (req: any) => (req.body.role === 'admin' ? null : ('teamRoles' as const));
    expect((await run(byRole, { check }, { role: 'admin' })).next).toHaveBeenCalled();
    expect(check).not.toHaveBeenCalled();
    expect((await run(byRole, { check }, { role: 'technician' })).res.status).toHaveBeenCalledWith(402);
  });

  it('a failing check is a 500, never a pass', async () => {
    const { res, next } = await run('contracts', { check: async () => { throw new Error('x'); } });
    expect(next).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(500);
  });
});

describe('ensurePlanFeature', () => {
  it('sends the 402 and returns false when the plan does not have it', async () => {
    const res = response();
    await expect(ensurePlanFeature(res, 'c1', 'mcp', { check: async () => ({ ...denied, feature: 'mcp', requiredPlan: 'business' }) })).resolves.toBe(false);
    expect(res.status).toHaveBeenCalledWith(402);
    await expect(ensurePlanFeature(response(), 'c1', 'mcp', { check: async () => allowed })).resolves.toBe(true);
  });
});
