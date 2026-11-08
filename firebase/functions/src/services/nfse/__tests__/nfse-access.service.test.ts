jest.mock('../../firestore.service', () => jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock);

import { read, resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
import {
  handleCompanyWrittenNfseAccess,
  isBrazilianCompany,
  nfseAccessUpdate,
  planGivesNfse,
  reconcileNfseAccess,
  syncNfseAccess,
} from '../nfse-access.service';
import { parseArgs, resolveProject } from '../../../../scripts/nfse-plan-access';

const NOW = new Date('2026-11-08T12:00:00.000Z');
const FUTURE = '2026-12-08T12:00:00.000Z';
const PAST = '2026-11-01T12:00:00.000Z';

const store = (plan = 'pro', expiresAt: string | null = FUTURE) => ({ plan, status: 'active', source: 'store', expiresAt });
const grace = (expiresAt = FUTURE) => ({ plan: 'pro', status: 'active', source: 'grace', expiresAt });
const PAYMENTS = 'companies/c1/settings/payments';

beforeEach(() => resetFakeDb());

describe('planGivesNfse', () => {
  it('gives the nota to the paid plans, the old paid plan and the courtesy', () => {
    for (const plan of ['starter', 'pro', 'business']) {
      expect(planGivesNfse({ country: 'BR', subscription: store(plan) }, NOW)).toBe(true);
    }
    expect(planGivesNfse({ country: 'BR', subscription: { plan: 'pro' } }, NOW)).toBe(true);
    expect(planGivesNfse({ country: 'BR', subscription: grace() }, NOW)).toBe(true);
  });

  it('gives nothing to Free, to an ended plan or courtesy, or to no company', () => {
    expect(planGivesNfse({ country: 'BR', subscription: store('free', null) }, NOW)).toBe(false);
    expect(planGivesNfse({ country: 'BR' }, NOW)).toBe(false);
    expect(planGivesNfse({ country: 'BR', subscription: store('pro', PAST) }, NOW)).toBe(false);
    expect(planGivesNfse({ country: 'BR', subscription: grace(PAST) }, NOW)).toBe(false);
    expect(planGivesNfse(null, NOW)).toBe(false);
  });

  it('is only for Brazil (no country counts as Brazil)', () => {
    expect(isBrazilianCompany(undefined)).toBe(true);
    expect(isBrazilianCompany('')).toBe(true);
    expect(isBrazilianCompany('br')).toBe(true);
    expect(isBrazilianCompany('PT')).toBe(false);
    expect(planGivesNfse({ subscription: store() }, NOW)).toBe(true);
    expect(planGivesNfse({ country: 'US', subscription: store() }, NOW)).toBe(false);
  });
});

describe('nfseAccessUpdate', () => {
  it('turns on with the plan source and off only what the plan turned on', () => {
    expect(nfseAccessUpdate(null, true, NOW)).toEqual({
      nfseDirectEnabled: true,
      nfseDirectSource: 'plan',
      nfseDirectUpdatedAt: NOW.toISOString(),
    });
    expect(nfseAccessUpdate({ nfseDirectEnabled: true, nfseDirectSource: 'plan' }, false, NOW)).toMatchObject({
      nfseDirectEnabled: false,
      nfseDirectSource: 'plan',
    });
    expect(nfseAccessUpdate({ nfseDirectEnabled: true, nfseDirectSource: 'plan' }, true, NOW)).toBeNull();
    expect(nfseAccessUpdate({ nfseDirectEnabled: false }, false, NOW)).toBeNull();
  });

  it('never touches a key set by hand', () => {
    // The pilot: on, no source.
    expect(nfseAccessUpdate({ nfseDirectEnabled: true }, false, NOW)).toBeNull();
    expect(nfseAccessUpdate({ nfseDirectEnabled: true, nfseDirectSource: 'manual' }, false, NOW)).toBeNull();
    // Turned off by hand: the plan does not turn it back on.
    expect(nfseAccessUpdate({ nfseDirectEnabled: false, nfseDirectSource: 'manual' }, true, NOW)).toBeNull();
  });
});

describe('syncNfseAccess', () => {
  it('keeps the other payment settings', async () => {
    seed('companies/c1', { country: 'BR', subscription: grace() });
    seed(PAYMENTS, { asaasEnabled: true, nfseEnabled: false });
    expect(await syncNfseAccess('c1', { now: NOW })).toBe('enabled');
    expect(read(PAYMENTS)).toMatchObject({ asaasEnabled: true, nfseEnabled: false, nfseDirectEnabled: true, nfseDirectSource: 'plan' });
  });

  it('writes nothing on a dry run or for a missing company', async () => {
    seed('companies/c1', { country: 'BR', subscription: store() });
    expect(await syncNfseAccess('c1', { now: NOW, dryRun: true })).toBe('enabled');
    expect(read(PAYMENTS)).toBeUndefined();
    expect(await syncNfseAccess('nope', { now: NOW })).toBe('company_not_found');
  });
});

describe('handleCompanyWrittenNfseAccess (trigger)', () => {
  it('turns the nota on when a company gets a paid plan or the courtesy', async () => {
    const before = { country: 'BR', subscription: store('free', null) };
    const after = { country: 'BR', subscription: store('starter') };
    expect(await handleCompanyWrittenNfseAccess('c1', before, after, NOW)).toBe('enabled');
    expect(read(PAYMENTS)?.nfseDirectEnabled).toBe(true);

    expect(await handleCompanyWrittenNfseAccess('c2', undefined, { subscription: grace() }, NOW)).toBe('enabled');
    expect(read('companies/c2/settings/payments')?.nfseDirectEnabled).toBe(true);
  });

  it('turns it off when the plan ends, but not a key set by hand', async () => {
    seed(PAYMENTS, { nfseDirectEnabled: true, nfseDirectSource: 'plan' });
    const before = { country: 'BR', subscription: store('pro') };
    const after = { country: 'BR', subscription: { ...store('free', null), status: 'expired' } };
    expect(await handleCompanyWrittenNfseAccess('c1', before, after, NOW)).toBe('disabled');
    expect(read(PAYMENTS)?.nfseDirectEnabled).toBe(false);

    seed(PAYMENTS, { nfseDirectEnabled: true });
    expect(await handleCompanyWrittenNfseAccess('c1', before, after, NOW)).toBe('manual');
    expect(read(PAYMENTS)?.nfseDirectEnabled).toBe(true);
  });

  it('ignores writes that do not change plan or country, and deletes', async () => {
    const company = { country: 'BR', subscription: { ...store(), usage: { photosThisMonth: 1 } } };
    const counted = { ...company, subscription: { ...company.subscription, usage: { photosThisMonth: 2 } }, updatedAt: 'x' };
    expect(await handleCompanyWrittenNfseAccess('c1', company, counted, NOW)).toBe('skipped');
    expect(await handleCompanyWrittenNfseAccess('c1', company, undefined, NOW)).toBe('skipped');
    expect(read(PAYMENTS)).toBeUndefined();
  });

  it('follows a change of country', async () => {
    seed(PAYMENTS, { nfseDirectEnabled: true, nfseDirectSource: 'plan' });
    const before = { country: 'BR', subscription: store() };
    expect(await handleCompanyWrittenNfseAccess('c1', before, { ...before, country: 'PT' }, NOW)).toBe('disabled');
  });
});

describe('reconcileNfseAccess (daily job and initial load)', () => {
  beforeEach(() => {
    seed('companies/paid', { country: 'BR', subscription: store('business') });
    seed('companies/foreign', { country: 'US', subscription: store('pro') });
    seed('companies/ended', { country: 'BR', subscription: grace(PAST) });
    seed('companies/ended/settings/payments', { nfseDirectEnabled: true, nfseDirectSource: 'plan' });
    seed('companies/pilot', { country: 'BR', subscription: store('free', null) });
    seed('companies/pilot/settings/payments', { nfseDirectEnabled: true });
    seed('companies/free', { country: 'BR', subscription: store('free', null) });
    seed('companies/on', { country: 'BR', subscription: store('pro') });
    seed('companies/on/settings/payments', { nfseDirectEnabled: true, nfseDirectSource: 'plan' });
  });

  it('lists the changes without writing on a dry run', async () => {
    const result = await reconcileNfseAccess(NOW, { dryRun: true });
    expect(result).toEqual({ enabled: ['paid'], disabled: ['ended'], manual: 1, checked: 5, errors: 0 });
    expect(read('companies/paid/settings/payments')).toBeUndefined();
    expect(read('companies/ended/settings/payments')?.nfseDirectEnabled).toBe(true);
  });

  it('turns on the paid, off the ended, and keeps the pilot', async () => {
    await reconcileNfseAccess(NOW);
    expect(read('companies/paid/settings/payments')?.nfseDirectEnabled).toBe(true);
    expect(read('companies/ended/settings/payments')?.nfseDirectEnabled).toBe(false);
    expect(read('companies/pilot/settings/payments')).toEqual({ nfseDirectEnabled: true });
    expect(read('companies/foreign/settings/payments')).toBeUndefined();
    expect(read('companies/free/settings/payments')).toBeUndefined();
  });
});

describe('nfse-plan-access script', () => {
  it('needs --project outside the emulator', () => {
    expect(parseArgs(['--project', 'p', '--dry-run'])).toEqual({ project: 'p', dryRun: true });
    expect(() => resolveProject(parseArgs([]), {})).toThrow('--project');
    expect(resolveProject(parseArgs([]), { FIRESTORE_EMULATOR_HOST: 'localhost:8080' }).emulator).toBe(true);
    expect(() => parseArgs(['--project'])).toThrow('requires a value');
    expect(() => parseArgs(['--all'])).toThrow('unknown argument');
  });
});
