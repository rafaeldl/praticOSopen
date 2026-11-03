import { nextConfig, parseArgs, resolveProject } from '../../scripts/webapp-access';
import { hashEmail } from '../routes/v1/web-access.routes';

describe('webapp-access script', () => {
  it('parses e-mails, lowercased', () => {
    expect(parseArgs(['--email', 'A@B.test', '--email', 'c@d.test', '--project', 'p'])).toEqual({
      emails: ['a@b.test', 'c@d.test'],
      remove: false,
      show: false,
      dryRun: false,
      project: 'p',
    });
  });

  it('refuses ambiguous or broken arguments', () => {
    expect(() => parseArgs([])).toThrow('pick one');
    expect(() => parseArgs(['--email', 'a@b.test', '--open'])).toThrow('pick one');
    expect(() => parseArgs(['--open', '--close'])).toThrow('not both');
    expect(() => parseArgs(['--email', 'nope'])).toThrow('not an e-mail');
    expect(() => parseArgs(['--remove', '--show'])).toThrow('--remove goes with --email');
    expect(() => parseArgs(['--email'])).toThrow('requires a value');
    expect(() => parseArgs(['--what'])).toThrow('unknown argument');
  });

  it('never guesses a real project', () => {
    expect(() => resolveProject(parseArgs(['--show']), {})).toThrow('--project');
    expect(resolveProject(parseArgs(['--show', '--project', 'p']), {})).toEqual({ projectId: 'p', emulator: false });
    expect(resolveProject(parseArgs(['--show']), { FIRESTORE_EMULATOR_HOST: 'x', GCLOUD_PROJECT: 'demo-x' })).toEqual({
      projectId: 'demo-x',
      emulator: true,
    });
  });

  it('adds and removes hashes, never addresses, and keeps the switch', () => {
    const added = nextConfig(null, parseArgs(['--email', 'A@b.test']));
    expect(added).toEqual({ open: false, allowedEmailHashes: [hashEmail('a@b.test')] });
    expect(JSON.stringify(added)).not.toContain('@');
    const again = nextConfig(added, parseArgs(['--email', 'a@b.test']));
    expect(again.allowedEmailHashes).toHaveLength(1);
    expect(nextConfig({ ...added, open: true }, parseArgs(['--email', 'a@b.test', '--remove']))).toEqual({
      open: true,
      allowedEmailHashes: [],
    });
    expect(nextConfig(added, parseArgs(['--open'])).open).toBe(true);
  });
});
