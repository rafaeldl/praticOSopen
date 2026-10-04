import { randomBytes } from 'node:crypto';
import {
  decryptSecret,
  encryptSecret,
  hashToken,
  readMasterKeyFromEnv,
  safeEqualHex,
} from '../crypto';

const MASTER_KEY = randomBytes(32).toString('base64');

describe('asaas crypto', () => {
  it('criptografa e decripta (ida e volta)', () => {
    const enc = encryptSecret('$aact_hmlg_secret', MASTER_KEY);
    expect(enc.ciphertext).not.toContain('aact');
    expect(decryptSecret(enc, MASTER_KEY)).toBe('$aact_hmlg_secret');
  });

  it('usa IV diferente a cada chamada', () => {
    const a = encryptSecret('same', MASTER_KEY);
    const b = encryptSecret('same', MASTER_KEY);
    expect(a.iv).not.toBe(b.iv);
    expect(a.ciphertext).not.toBe(b.ciphertext);
  });

  it('falha com tag adulterada', () => {
    const enc = encryptSecret('$aact_hmlg_secret', MASTER_KEY);
    const tag = Buffer.from(enc.tag, 'base64');
    tag[0] = tag[0] ^ 0xff;
    expect(() => decryptSecret({ ...enc, tag: tag.toString('base64') }, MASTER_KEY)).toThrow();
  });

  it('falha com ciphertext adulterado', () => {
    const enc = encryptSecret('$aact_hmlg_secret', MASTER_KEY);
    const data = Buffer.from(enc.ciphertext, 'base64');
    data[0] = data[0] ^ 0xff;
    expect(() => decryptSecret({ ...enc, ciphertext: data.toString('base64') }, MASTER_KEY)).toThrow();
  });

  it('falha com outra chave mestra', () => {
    const enc = encryptSecret('x', MASTER_KEY);
    expect(() => decryptSecret(enc, randomBytes(32).toString('base64'))).toThrow();
  });

  it('rejeita chave mestra que não tem 32 bytes', () => {
    expect(() => encryptSecret('x', randomBytes(16).toString('base64'))).toThrow(/32 bytes/);
  });

  it('hashToken gera sha256 hex e safeEqualHex compara', () => {
    const hash = hashToken('token-1');
    expect(hash).toMatch(/^[0-9a-f]{64}$/);
    expect(safeEqualHex(hash, hashToken('token-1'))).toBe(true);
    expect(safeEqualHex(hash, hashToken('token-2'))).toBe(false);
    expect(safeEqualHex(hash, 'abc')).toBe(false);
    expect(safeEqualHex('', '')).toBe(false);
  });

  it('safeEqualHex rejeita entradas que não são 64 caracteres hex', () => {
    const hash = hashToken('token-1');
    // Buffer.from(hex) stops at the first invalid char: never treat a prefix as a match
    expect(safeEqualHex(hash, hash.slice(0, 62) + 'zz')).toBe(false);
    expect(safeEqualHex(hash.slice(0, 62) + 'zz', hash.slice(0, 62) + 'zz')).toBe(false);
    expect(safeEqualHex('zz' + hash.slice(2), 'zz' + hash.slice(2))).toBe(false);
    expect(safeEqualHex(hash + '00', hash + '00')).toBe(false);
    expect(safeEqualHex(hash.slice(0, 62), hash.slice(0, 62))).toBe(false);
    expect(safeEqualHex(hash + 'g', hash)).toBe(false);
    expect(safeEqualHex(undefined as unknown as string, hash)).toBe(false);
  });

  it('safeEqualHex ignora maiúsculas/minúsculas (hex)', () => {
    const hash = hashToken('token-1');
    expect(safeEqualHex(hash.toUpperCase(), hash)).toBe(true);
  });

  it('readMasterKeyFromEnv exige a variável', () => {
    const previous = process.env.ASAAS_CREDENTIALS_KEY;
    delete process.env.ASAAS_CREDENTIALS_KEY;
    expect(() => readMasterKeyFromEnv()).toThrow(/not configured/);
    process.env.ASAAS_CREDENTIALS_KEY = MASTER_KEY;
    expect(readMasterKeyFromEnv()).toBe(MASTER_KEY);
    if (previous === undefined) delete process.env.ASAAS_CREDENTIALS_KEY;
    else process.env.ASAAS_CREDENTIALS_KEY = previous;
  });
});
