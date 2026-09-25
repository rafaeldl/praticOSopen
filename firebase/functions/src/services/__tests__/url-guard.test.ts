const mockLookup = jest.fn();

jest.mock('dns', () => ({
  promises: {
    lookup: (...args: unknown[]) => mockLookup(...args),
  },
}));

import { assertPublicHttpUrl, isBlockedIp, BlockedUrlError } from '../url-guard';

describe('url-guard - isBlockedIp', () => {
  it.each([
    '127.0.0.1',
    '127.1.2.3',
    '10.0.0.1',
    '172.16.0.1',
    '172.31.255.255',
    '192.168.1.1',
    '169.254.169.254',
    '100.64.0.1',
    '0.0.0.0',
    '224.0.0.1',
    '255.255.255.255',
    '::1',
    '::',
    'fe80::1',
    'fc00::1',
    'fd00:ec2::254',
    'ff02::1',
    '::ffff:127.0.0.1',
    '::ffff:7f00:1',
    '::ffff:a9fe:a9fe',
    '[::1]',
    'not-an-ip',
  ])('bloqueia %s', (ip) => {
    expect(isBlockedIp(ip)).toBe(true);
  });

  it.each(['8.8.8.8', '1.1.1.1', '172.32.0.1', '142.250.78.14', '2606:4700:4700::1111', '::ffff:8.8.8.8'])(
    'permite %s',
    (ip) => {
      expect(isBlockedIp(ip)).toBe(false);
    },
  );
});

describe('url-guard - assertPublicHttpUrl', () => {
  beforeEach(() => {
    mockLookup.mockReset();
  });

  it('permite host público resolvido para IP público', async () => {
    mockLookup.mockResolvedValue([{ address: '93.184.216.34', family: 4 }]);
    const url = await assertPublicHttpUrl('https://example.com/img.jpg');
    expect(url.hostname).toBe('example.com');
    expect(mockLookup).toHaveBeenCalledWith('example.com', { all: true, verbatim: true });
  });

  it.each([
    'http://127.0.0.1/',
    'http://169.254.169.254/computeMetadata/v1/',
    'http://10.1.2.3:8080/x',
    'http://[::1]/',
    'http://[::ffff:127.0.0.1]/',
    'http://[fd00:ec2::254]/',
    'http://2130706433/', // 127.0.0.1 em decimal
    'http://0x7f.1/', // 127.0.0.1 em hex abreviado
  ])('rejeita IP literal não público: %s', async (url) => {
    await expect(assertPublicHttpUrl(url)).rejects.toThrow(BlockedUrlError);
    expect(mockLookup).not.toHaveBeenCalled();
  });

  it.each([
    'http://localhost/',
    'http://metadata.google.internal/computeMetadata/v1/',
    'http://metadata/',
    'http://foo.localhost/',
    'http://METADATA.GOOGLE.INTERNAL./',
  ])('rejeita hostname bloqueado: %s', async (url) => {
    await expect(assertPublicHttpUrl(url)).rejects.toThrow(BlockedUrlError);
    expect(mockLookup).not.toHaveBeenCalled();
  });

  it('rejeita host que resolve para IP privado', async () => {
    mockLookup.mockResolvedValue([{ address: '10.0.0.5', family: 4 }]);
    await expect(assertPublicHttpUrl('https://evil.example.com/')).rejects.toThrow(
      'URL host resolves to a non-public address',
    );
  });

  it('rejeita host quando qualquer um dos endereços resolvidos é privado', async () => {
    mockLookup.mockResolvedValue([
      { address: '93.184.216.34', family: 4 },
      { address: '::1', family: 6 },
    ]);
    await expect(assertPublicHttpUrl('https://mixed.example.com/')).rejects.toThrow(BlockedUrlError);
  });

  it('rejeita host que não resolve', async () => {
    mockLookup.mockRejectedValue(new Error('ENOTFOUND'));
    await expect(assertPublicHttpUrl('https://nope.invalid/')).rejects.toThrow('Could not resolve host');
  });

  it('rejeita URL com credenciais embutidas', async () => {
    await expect(assertPublicHttpUrl('https://user:pass@example.com/')).rejects.toThrow(BlockedUrlError);
  });

  it('rejeita protocolo não http(s)', async () => {
    await expect(assertPublicHttpUrl('file:///etc/passwd')).rejects.toThrow('Invalid protocol: file:');
  });
});
