jest.mock('../../firestore.service', () =>
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  require('../../../__tests__/helpers/fake-firestore').fakeFirestoreModule(),
);

import * as firestoreService from '../../firestore.service';
import { FakeFirestore } from '../../../__tests__/helpers/fake-firestore';
import {
  AI_REQUESTS_PER_MONTH,
  getAiSettings,
  getAiUsage,
  monthKey,
  releaseAiRequest,
  reserveAiRequest,
  resetAiGlobalCache,
  resolveAiLimit,
  resolveAiSettings,
} from '../ai-quota.service';

const fake = (firestoreService as unknown as { __fake: FakeFirestore }).__fake;
const NOW = new Date('2026-10-11T12:00:00.000Z');
const ON = { enabled: true };

describe('ai quota', () => {
  beforeEach(() => {
    fake.reset();
    resetAiGlobalCache();
  });

  it('monthKey is the UTC calendar month', () => {
    expect(monthKey(NOW)).toBe('2026-10');
    expect(monthKey(new Date('2026-12-31T23:59:59Z'))).toBe('2026-12');
  });

  it('limit comes from the plan, missing/unknown plan is free, settings override', () => {
    expect(resolveAiLimit('pro', null)).toBe(3000);
    expect(resolveAiLimit(undefined, null)).toBe(AI_REQUESTS_PER_MONTH.free);
    expect(resolveAiLimit('gold', ON)).toBe(50);
    expect(resolveAiLimit('free', { enabled: true, monthlyLimit: 70 })).toBe(70);
    expect(resolveAiLimit('free', { enabled: true, monthlyLimit: -1 })).toBe(-1);
  });

  it('getAiSettings: no company doc and no global switch → off; only enabled === true turns it on', async () => {
    await expect(getAiSettings('c1')).resolves.toEqual({ enabled: false, monthlyLimit: undefined, provider: undefined, financeActions: false });
    fake.seed('companies/c1/settings/ai', { enabled: 'yes', monthlyLimit: 2.5 });
    await expect(getAiSettings('c1')).resolves.toMatchObject({ enabled: false, monthlyLimit: undefined });
    fake.seed('companies/c1/settings/ai', { enabled: true, monthlyLimit: 20 });
    await expect(getAiSettings('c1')).resolves.toMatchObject({ enabled: true, monthlyLimit: 20 });
  });

  it('getAiSettings: config/ai turns it on for every company, company fields win', async () => {
    fake.seed('config/ai', { enabledForAll: true, defaultProvider: 'claude' });
    await expect(getAiSettings('c1')).resolves.toEqual({ enabled: true, monthlyLimit: undefined, provider: 'claude', financeActions: false });
    fake.seed('companies/c2/settings/ai', { enabled: false });
    await expect(getAiSettings('c2')).resolves.toMatchObject({ enabled: false, provider: 'claude' });
    fake.seed('companies/c3/settings/ai', { provider: 'gemini', monthlyLimit: 5 });
    await expect(getAiSettings('c3')).resolves.toEqual({ enabled: true, monthlyLimit: 5, provider: 'gemini', financeActions: false });
  });

  it('resolveAiSettings: financeActions is off unless a switch turns it on, and the company wins', () => {
    expect(resolveAiSettings(undefined, undefined).financeActions).toBe(false);
    expect(resolveAiSettings(undefined, { financeActions: true }).financeActions).toBe(true);
    expect(resolveAiSettings({ financeActions: true }, undefined).financeActions).toBe(true);
    expect(resolveAiSettings({ financeActions: false }, { financeActions: true }).financeActions).toBe(false);
    expect(resolveAiSettings({ financeActions: 'yes' }, undefined).financeActions).toBe(false);
  });

  it('resolveAiSettings ignores invalid values', () => {
    expect(resolveAiSettings({ provider: 'gpt' }, { enabledForAll: 'yes', defaultProvider: 'x' })).toEqual({
      enabled: false,
      monthlyLimit: undefined,
      provider: undefined,
      financeActions: false,
    });
    expect(resolveAiSettings(undefined, { enabledForAll: true })).toMatchObject({ enabled: true, provider: undefined });
  });

  it('reads config/ai at most once a minute', async () => {
    fake.seed('config/ai', { enabledForAll: true });
    await expect(getAiSettings('c1')).resolves.toMatchObject({ enabled: true });
    fake.seed('config/ai', { enabledForAll: false });
    await expect(getAiSettings('c1')).resolves.toMatchObject({ enabled: true });
    resetAiGlobalCache();
    await expect(getAiSettings('c1')).resolves.toMatchObject({ enabled: false });
  });

  it('getAiUsage reads the month without counting', async () => {
    fake.seed('companies/c1', { subscription: { plan: 'pro' } });
    await expect(getAiUsage('c1', ON, NOW)).resolves.toEqual({ used: 0, limit: 3000 });
    fake.seed('companies/c1/aiUsage/2026-10', { count: 7 });
    await expect(getAiUsage('c1', ON, NOW)).resolves.toEqual({ used: 7, limit: 3000 });
    expect(fake.read('companies/c1/aiUsage/2026-10')?.count).toBe(7);
  });

  it('counts each request in the month counter', async () => {
    fake.seed('companies/c1', { subscription: { plan: 'starter' } });
    const first = await reserveAiRequest('c1', ON, NOW);
    const second = await reserveAiRequest('c1', ON, NOW);
    expect(first).toEqual({ ok: true, used: 1, limit: 1000, monthKey: '2026-10', dayKey: '2026-10-11' });
    expect(second.used).toBe(2);
    expect(fake.read('companies/c1/aiUsage/2026-10')).toMatchObject({ count: 2, limit: 1000, day: '2026-10-11', dayCount: 2 });
  });

  it('refuses at the limit without counting', async () => {
    fake.seed('companies/c1', {});
    fake.seed('companies/c1/aiUsage/2026-10', { count: 50 });
    const result = await reserveAiRequest('c1', ON, NOW);
    expect(result).toEqual({ ok: false, used: 50, limit: 50, monthKey: '2026-10', dayKey: '2026-10-11', period: 'month' });
    expect(fake.read('companies/c1/aiUsage/2026-10')?.count).toBe(50);
  });

  it('a new month starts from zero', async () => {
    fake.seed('companies/c1', {});
    fake.seed('companies/c1/aiUsage/2026-10', { count: 50 });
    const result = await reserveAiRequest('c1', ON, new Date('2026-11-01T00:00:01Z'));
    expect(result).toMatchObject({ ok: true, used: 1, monthKey: '2026-11' });
  });

  it('-1 is unlimited', async () => {
    fake.seed('companies/c1', {});
    fake.seed('companies/c1/aiUsage/2026-10', { count: 5000 });
    const result = await reserveAiRequest('c1', { enabled: true, monthlyLimit: -1 }, NOW);
    expect(result).toMatchObject({ ok: true, used: 5001, limit: -1 });
  });

  it('companies have separate counters (tenant isolation)', async () => {
    fake.seed('companies/c1', {});
    fake.seed('companies/c2', {});
    fake.seed('companies/c1/aiUsage/2026-10', { count: 50 });
    await expect(reserveAiRequest('c1', ON, NOW)).resolves.toMatchObject({ ok: false });
    await expect(reserveAiRequest('c2', ON, NOW)).resolves.toMatchObject({ ok: true, used: 1 });
    expect(fake.read('companies/c1/aiUsage/2026-10')?.count).toBe(50);
  });

  it('daily ceiling: Starter and Pro stop at 200 a day, the next day starts again', async () => {
    fake.seed('companies/c1', { subscription: { plan: 'pro' } });
    fake.seed('companies/c1/aiUsage/2026-10', { count: 500, day: '2026-10-11', dayCount: 200 });
    await expect(reserveAiRequest('c1', ON, NOW)).resolves.toEqual({
      ok: false, used: 200, limit: 200, monthKey: '2026-10', dayKey: '2026-10-11', period: 'day',
    });
    await expect(reserveAiRequest('c1', ON, new Date('2026-10-12T09:00:00Z'))).resolves.toMatchObject({ ok: true, used: 501 });
    expect(fake.read('companies/c1/aiUsage/2026-10')).toMatchObject({ day: '2026-10-12', dayCount: 1 });
  });

  it('daily ceiling: Business has none; a pilot override turns it off', async () => {
    fake.seed('companies/c1', { subscription: { plan: 'business' } });
    fake.seed('companies/c1/aiUsage/2026-10', { count: 500, day: '2026-10-11', dayCount: 900 });
    await expect(reserveAiRequest('c1', ON, NOW)).resolves.toMatchObject({ ok: true });
    fake.seed('companies/c1', { subscription: { plan: 'starter' } });
    await expect(reserveAiRequest('c1', { enabled: true, monthlyLimit: 5000 }, NOW)).resolves.toMatchObject({ ok: true });
  });

  it('daily ceiling: Free stops at 20 a day, under the 50 a month', async () => {
    fake.seed('companies/c1', {});
    fake.seed('companies/c1/aiUsage/2026-10', { count: 20, day: '2026-10-11', dayCount: 20 });
    await expect(reserveAiRequest('c1', ON, NOW)).resolves.toMatchObject({ ok: false, used: 20, limit: 20, period: 'day' });
    await expect(reserveAiRequest('c1', ON, new Date('2026-10-12T09:00:00Z'))).resolves.toMatchObject({ ok: true });
  });

  it('an expired plan is Free (effectivePlan), not the stored one', async () => {
    fake.seed('companies/c1', { subscription: { plan: 'pro', expiresAt: '2026-10-01T00:00:00.000Z' } });
    fake.seed('companies/c1/aiUsage/2026-10', { count: 50 });
    await expect(reserveAiRequest('c1', ON, NOW)).resolves.toMatchObject({ ok: false, limit: 50, period: 'month' });
    await expect(getAiUsage('c1', ON, NOW)).resolves.toEqual({ used: 50, limit: 50 });
  });

  it('release gives back the day too', async () => {
    fake.seed('companies/c1/aiUsage/2026-10', { count: 3, day: '2026-10-11', dayCount: 2 });
    await releaseAiRequest('c1', '2026-10', '2026-10-11');
    expect(fake.read('companies/c1/aiUsage/2026-10')).toMatchObject({ count: 2, dayCount: 1 });
    await releaseAiRequest('c1', '2026-10', '2026-10-10');
    expect(fake.read('companies/c1/aiUsage/2026-10')).toMatchObject({ count: 1, dayCount: 1 });
  });

  it('release gives one back and never goes below zero', async () => {
    fake.seed('companies/c1/aiUsage/2026-10', { count: 1 });
    await releaseAiRequest('c1', '2026-10');
    expect(fake.read('companies/c1/aiUsage/2026-10')?.count).toBe(0);
    await releaseAiRequest('c1', '2026-10');
    expect(fake.read('companies/c1/aiUsage/2026-10')?.count).toBe(0);
  });
});
