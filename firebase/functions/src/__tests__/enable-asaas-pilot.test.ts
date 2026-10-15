import { parseArgs, resolveTarget, buildUpdate, nfseEnableBlocker } from '../../scripts/enable-asaas-pilot';
import { ASAAS_WEBHOOK_EVENTS } from '../services/asaas/webhook-events';

describe('enable-asaas-pilot', () => {
  it('parses multiple companies and flags', () => {
    const args = parseArgs(['--company', 'a', '--company', 'b', '--disable', '--project', 'p', '--yes']);
    expect(args).toEqual({ companyIds: ['a', 'b'], dryRun: false, disable: true, yes: true, nfse: false, project: 'p' });
  });

  it('requires a company and values', () => {
    expect(() => parseArgs([])).toThrow();
    expect(() => parseArgs(['--company'])).toThrow();
    expect(() => parseArgs(['--company', '--dry-run'])).toThrow();
  });

  it('rejects unknown arguments', () => {
    expect(() => parseArgs(['--company', 'a', '--disble'])).toThrow(/unknown argument/);
    expect(() => parseArgs(['--company', 'a', '--dryrun'])).toThrow(/unknown argument/);
    expect(() => parseArgs(['--company', 'a', 'extra'])).toThrow(/unknown argument/);
  });

  it('refuses production without --project', () => {
    expect(() => resolveTarget(parseArgs(['--company', 'a']), {})).toThrow(/production/);
  });

  it('production is dry-run unless --yes', () => {
    expect(resolveTarget(parseArgs(['--company', 'a', '--project', 'praticos']), {}).write).toBe(false);
    expect(resolveTarget(parseArgs(['--company', 'a', '--project', 'praticos', '--yes']), {}).write).toBe(true);
    expect(resolveTarget(parseArgs(['--company', 'a', '--project', 'praticos', '--yes', '--dry-run']), {}).write).toBe(false);
  });

  it('emulator writes by default and honors --dry-run', () => {
    const env = { FIRESTORE_EMULATOR_HOST: 'localhost:8080' };
    expect(resolveTarget(parseArgs(['--company', 'a']), env)).toMatchObject({ emulator: true, write: true });
    expect(resolveTarget(parseArgs(['--company', 'a', '--dry-run']), env).write).toBe(false);
  });

  it('only sets asaasConnected when the doc is new', () => {
    expect(buildUpdate(false, false)).toEqual({ asaasEnabled: true, asaasConnected: false });
    expect(buildUpdate(true, false)).toEqual({ asaasEnabled: true });
    expect(buildUpdate(true, true)).toEqual({ asaasEnabled: false });
  });

  it('--nfse toggles only nfseEnabled', () => {
    expect(parseArgs(['--company', 'a', '--nfse']).nfse).toBe(true);
    expect(buildUpdate(true, false, true)).toEqual({ nfseEnabled: true });
    expect(buildUpdate(true, true, true)).toEqual({ nfseEnabled: false });
    expect(buildUpdate(false, false, true)).toEqual({ asaasEnabled: false, asaasConnected: false, nfseEnabled: true });
  });

  it('--nfse refuses a connection without the INVOICE_* events (NFSE_RECONNECT_NEEDED)', () => {
    const enable = { nfse: true, disable: false };
    expect(nfseEnableBlocker(enable, { status: 'active' } as any)).toMatch(/^NFSE_RECONNECT_NEEDED/);
    expect(nfseEnableBlocker(enable, { webhookEvents: ['PAYMENT_RECEIVED'] })).toMatch(/^NFSE_RECONNECT_NEEDED/);
    expect(nfseEnableBlocker(enable, { webhookEvents: ASAAS_WEBHOOK_EVENTS })).toBeNull();
    // Not connected yet (records the events at connect), disabling, or the Asaas flag: allowed.
    expect(nfseEnableBlocker(enable, undefined)).toBeNull();
    expect(nfseEnableBlocker({ nfse: true, disable: true }, {})).toBeNull();
    expect(nfseEnableBlocker({ nfse: false, disable: false }, {})).toBeNull();
  });
});
