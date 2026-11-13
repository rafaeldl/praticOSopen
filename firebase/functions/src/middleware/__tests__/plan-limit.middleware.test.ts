/**
 * requirePlanCapacity with the switch off reads nothing (no Firestore, no
 * Storage), so routes that mount it work without credentials.
 */

import { requirePlanCapacity, type PlanLimitDeps } from '../plan-limit.middleware';

jest.mock('../../services/plan-limits.service', () => ({
  checkCompanyPlanLimit: jest.fn(() => {
    throw new Error('must not be called while the switch is off');
  }),
  isPaidPlansEnabledFor: jest.fn(async () => false),
  planLimitError: jest.requireActual('../../services/plan-limits.service').planLimitError,
}));

function run(deps: PlanLimitDeps, adding?: () => number) {
  const req: any = { userContext: { companyId: 'c1' } };
  const res: any = { status: jest.fn(() => res), json: jest.fn(() => res) };
  const next = jest.fn();
  return requirePlanCapacity('photo', adding, deps)(req, res, next).then(() => ({ res, next }));
}

const full = {
  allowed: false,
  resource: 'photo' as const,
  limit: 30,
  usage: 30,
  adding: 1,
  plan: 'free' as const,
  level: 'over' as const,
  grace: false,
  contactUs: false,
};

describe('requirePlanCapacity', () => {
  it('the switch is asked for the company of the request (config/paidPlans.companyIds)', async () => {
    const enabled = jest.fn(() => false);
    await run({ enabled, check: jest.fn() });
    expect(enabled).toHaveBeenCalledWith('c1');
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

  it('default deps with config/paidPlans off: next() and nothing is counted', async () => {
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

});
