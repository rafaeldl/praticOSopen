import {
  graceExpiry,
  parseArgs,
  planGrace,
  resolveTarget,
  summarize,
} from '../../scripts/grant-grace-period';
import { PLAN_LIMITS } from '../services/subscription-plans';

const NOW = new Date('2026-10-07T12:00:00.000Z');
const EXPIRES = new Date('2026-12-06T12:00:00.000Z');
const USAGE = { photosThisMonth: 12, formTemplatesActive: 2, usersActive: 3, usageResetAt: '2026-11-01T00:00:00.000Z' };

describe('grant-grace-period', () => {
  it('defaults to dry-run with 60 days', () => {
    expect(parseArgs([])).toEqual({ apply: false, days: 60, project: undefined });
    expect(parseArgs(['--dry-run'])).toEqual({ apply: false, days: 60, project: undefined });
  });

  it('parses --apply, --days and --project', () => {
    expect(parseArgs(['--apply', '--days=30', '--project=praticos'])).toEqual({ apply: true, days: 30, project: 'praticos' });
  });

  it('rejects unknown arguments, invalid days and conflicting modes', () => {
    expect(() => parseArgs(['--aply'])).toThrow(/unknown argument/);
    expect(() => parseArgs(['--days=0'])).toThrow(/--days/);
    expect(() => parseArgs(['--days=abc'])).toThrow(/--days/);
    expect(() => parseArgs(['--days=400'])).toThrow(/--days/);
    expect(() => parseArgs(['--project='])).toThrow(/--project/);
    expect(() => parseArgs(['--apply', '--dry-run'])).toThrow(/mutually exclusive/);
  });

  it('refuses production without --project and writes only with --apply', () => {
    expect(() => resolveTarget(parseArgs([]), {})).toThrow(/production/);
    expect(resolveTarget(parseArgs(['--project=praticos']), {})).toEqual({ projectId: 'praticos', emulator: false, write: false });
    expect(resolveTarget(parseArgs(['--project=praticos', '--apply']), {}).write).toBe(true);
  });

  it('on the emulator writes only with --apply', () => {
    const env = { FIRESTORE_EMULATOR_HOST: 'localhost:8080' };
    expect(resolveTarget(parseArgs([]), env)).toMatchObject({ emulator: true, write: false, projectId: 'praticos-app' });
    expect(resolveTarget(parseArgs(['--apply']), env).write).toBe(true);
  });

  it('computes the grace end', () => {
    expect(graceExpiry(NOW, 60).toISOString()).toBe('2026-12-06T12:00:00.000Z');
  });

  it('grants the full grace subscription when the company has none', () => {
    for (const existing of [undefined, null]) {
      const plan = planGrace(existing, EXPIRES, NOW);
      expect(plan.action).toBe('grant');
      if (plan.action !== 'grant') return;
      expect(plan.update.updatedAt).toBe(NOW.toISOString());
      expect(plan.update.subscription).toMatchObject({
        plan: 'pro',
        status: 'active',
        source: 'grace',
        store: null,
        expiresAt: EXPIRES.toISOString(),
        limits: PLAN_LIMITS.pro,
        updatedAt: NOW.toISOString(),
        usage: { photosThisMonth: 0, formTemplatesActive: 0, usersActive: 1 },
      });
    }
  });

  it('writes only plan fields (dotted paths) and keeps usage of an existing subscription', () => {
    const plan = planGrace({ plan: 'free', status: 'active', limits: PLAN_LIMITS.free, usage: USAGE }, EXPIRES, NOW);

    expect(plan).toEqual({
      action: 'grant',
      update: {
        'subscription.plan': 'pro',
        'subscription.status': 'active',
        'subscription.source': 'grace',
        'subscription.store': null,
        'subscription.expiresAt': EXPIRES.toISOString(),
        'subscription.limits': PLAN_LIMITS.pro,
        'subscription.updatedAt': NOW.toISOString(),
        updatedAt: NOW.toISOString(),
      },
    });
  });

  it('grants grace to a usage-only subscription (no plan) with dotted paths, keeping usage', () => {
    const plan = planGrace({ usage: { formTemplates: 1 } }, EXPIRES, NOW);

    expect(plan).toEqual({
      action: 'grant',
      update: {
        'subscription.plan': 'pro',
        'subscription.status': 'active',
        'subscription.source': 'grace',
        'subscription.store': null,
        'subscription.expiresAt': EXPIRES.toISOString(),
        'subscription.limits': PLAN_LIMITS.pro,
        'subscription.updatedAt': NOW.toISOString(),
        updatedAt: NOW.toISOString(),
      },
    });
  });

  it('adds usage when the existing subscription has none', () => {
    const plan = planGrace({ plan: 'free', status: 'active' }, EXPIRES, NOW);

    expect(plan.action).toBe('grant');
    if (plan.action !== 'grant') return;
    expect(plan.update['subscription.usage']).toMatchObject({ photosThisMonth: 0, usersActive: 1 });
  });

  it('skips companies with an active paid store subscription', () => {
    expect(
      planGrace({ plan: 'business', status: 'active', source: 'store', expiresAt: '2026-11-07T12:00:00Z', usage: USAGE }, EXPIRES, NOW),
    ).toEqual({ action: 'skip_paid' });
  });

  it('grants grace over an expired store subscription', () => {
    expect(
      planGrace({ plan: 'free', status: 'expired', source: 'store', expiresAt: null, usage: USAGE }, EXPIRES, NOW).action,
    ).toBe('grant');
  });

  it('does not extend an existing grace period', () => {
    expect(
      planGrace({ plan: 'pro', status: 'active', source: 'grace', expiresAt: '2026-11-01T00:00:00.000Z', usage: USAGE }, EXPIRES, NOW),
    ).toEqual({ action: 'skip_grace' });
  });

  it('summarizes only aggregate counts', () => {
    expect(
      summarize([
        { action: 'grant', update: {} },
        { action: 'grant', update: {} },
        { action: 'skip_paid' },
        { action: 'skip_grace' },
      ]),
    ).toEqual({ total: 4, grant: 2, skipPaid: 1, skipGrace: 1 });
  });
});
