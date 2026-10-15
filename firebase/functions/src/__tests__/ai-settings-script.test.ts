import { buildCompanyUpdate, buildGlobalUpdate, parseArgs, resolveTarget } from '../../scripts/ai-settings';

describe('ai-settings script', () => {
  it('parses a company switch with provider and limit', () => {
    expect(parseArgs(['on', '--company', 'a', '--provider', 'claude', '--limit', '50', '--project', 'p', '--yes'])).toEqual({
      action: 'on',
      companyIds: ['a'],
      all: false,
      provider: 'claude',
      limit: 50,
      project: 'p',
      dryRun: false,
      yes: true,
    });
  });

  it('refuses unsafe or ambiguous arguments', () => {
    expect(() => parseArgs([])).toThrow('unknown action');
    expect(() => parseArgs(['on'])).toThrow('--company');
    expect(() => parseArgs(['on', '--all', '--company', 'a'])).toThrow('not both');
    expect(() => parseArgs(['follow', '--all'])).toThrow('per company');
    expect(() => parseArgs(['on', '--all', '--limit', '5'])).toThrow('per company');
    expect(() => parseArgs(['off', '--company', 'a', '--provider', 'claude'])).toThrow('only go with on');
    expect(() => parseArgs(['on', '--company', 'a', '--provider', 'gpt'])).toThrow('unknown provider');
    expect(() => parseArgs(['on', '--company', 'a', '--limit', '2.5'])).toThrow('--limit');
    expect(() => parseArgs(['on', '--company'])).toThrow('requires a value');
    expect(parseArgs(['show']).companyIds).toEqual([]);
  });

  it('production needs --project, and --yes to write', () => {
    const args = parseArgs(['on', '--all']);
    expect(() => resolveTarget(args, {})).toThrow('refusing');
    expect(resolveTarget({ ...args, project: 'praticos' }, {}).write).toBe(false);
    expect(resolveTarget({ ...args, project: 'praticos', yes: true }, {}).write).toBe(true);
    expect(resolveTarget(args, { FIRESTORE_EMULATOR_HOST: 'localhost:8080' })).toMatchObject({ emulator: true, write: true });
  });

  it('builds the merges', () => {
    expect(buildGlobalUpdate(parseArgs(['on', '--all', '--provider', 'claude']))).toEqual({
      enabledForAll: true,
      defaultProvider: 'claude',
    });
    expect(buildGlobalUpdate(parseArgs(['off', '--all']))).toEqual({ enabledForAll: false });
    expect(buildCompanyUpdate(parseArgs(['on', '--company', 'a', '--limit', '-1']))).toEqual({ enabled: true, monthlyLimit: -1 });
    expect(buildCompanyUpdate(parseArgs(['off', '--company', 'a']))).toEqual({ enabled: false });
    expect(buildCompanyUpdate(parseArgs(['follow', '--company', 'a']))).toEqual({ enabled: null, provider: null });
  });
});
