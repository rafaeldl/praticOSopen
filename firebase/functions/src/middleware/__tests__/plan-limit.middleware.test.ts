/**
 * requirePlanCapacity with the switch off reads nothing (no Firestore, no
 * Storage), so routes that mount it work without credentials.
 */

import { planLimitsDeployed, requirePlanCapacity, type PlanLimitDeps } from '../plan-limit.middleware';

jest.mock('../../services/plan-limits.service', () => ({
  checkCompanyPlanLimit: jest.fn(() => {
    throw new Error('must not be called while the switch is off');
  }),
  planLimitError: jest.requireActual('../../services/plan-limits.service').planLimitError,
}));

function run(deps: PlanLimitDeps, adding?: () => number) {
  const req: any = { userContext: { companyId: 'c1' } };
  const res: any = { status: jest.fn(() => res), json: jest.fn(() => res) };
  const next = jest.fn();
  return requirePlanCapacity('photo', adding, deps)(req, res, next).then(() => ({ res, next }));
}

const full = { allowed: false, resource: 'photo' as const, limit: 30, usage: 30, adding: 1, plan: 'free' as const };

describe('requirePlanCapacity', () => {
  afterEach(() => {
    delete process.env.PLAN_LIMITS_ENABLED;
  });

  it('switch off: next() without counting or reading', async () => {
    const check = jest.fn();
    const adding = jest.fn(() => 1);
    const { next, res } = await run({ enabled: () => false, check }, adding);
    expect(next).toHaveBeenCalledTimes(1);
    expect(check).not.toHaveBeenCalled();
    expect(adding).not.toHaveBeenCalled();
    expect(res.status).not.toHaveBeenCalled();
  });

  it('default deps with PLAN_LIMITS_ENABLED unset: next() and the service is never called', async () => {
    const req: any = { userContext: { companyId: 'c1' } };
    const next = jest.fn();
    await requirePlanCapacity('collaborator')(req, {} as any, next);
    expect(next).toHaveBeenCalledTimes(1);
  });

  it('switch on, at the limit: 402 PLAN_LIMIT', async () => {
    const { next, res } = await run({ enabled: () => true, check: async () => full });
    expect(next).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(402);
    expect(res.json.mock.calls[0][0].error).toMatchObject({ code: 'PLAN_LIMIT', resource: 'photo', limit: 30 });
  });

  it('switch on, with room: next()', async () => {
    const { next } = await run({ enabled: () => true, check: async () => ({ ...full, allowed: true }) });
    expect(next).toHaveBeenCalledTimes(1);
  });

  it('PLAN_LIMITS_ENABLED must be exactly "true"', () => {
    expect(planLimitsDeployed({})).toBe(false);
    expect(planLimitsDeployed({ PLAN_LIMITS_ENABLED: '1' })).toBe(false);
    expect(planLimitsDeployed({ PLAN_LIMITS_ENABLED: 'true' })).toBe(true);
  });
});
