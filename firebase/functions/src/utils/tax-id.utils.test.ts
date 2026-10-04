import { isValidCnpj, isValidCpf, isValidTaxId, normalizeTaxId } from './tax-id.utils';

describe('tax-id.utils', () => {
  it('normalizeTaxId removes mask, uppercases and keeps [0-9A-Z]', () => {
    expect(normalizeTaxId('529.982.247-25')).toBe('52998224725');
    expect(normalizeTaxId(' 12.abc.345/01de-35 ')).toBe('12ABC34501DE35');
    expect(normalizeTaxId(undefined)).toBe('');
    expect(normalizeTaxId(null)).toBe('');
  });

  it('validates CPF (numeric only)', () => {
    expect(isValidCpf('529.982.247-25')).toBe(true);
    expect(isValidCpf('52998224724')).toBe(false);
    expect(isValidCpf('11111111111')).toBe(false);
    expect(isValidCpf('123')).toBe(false);
    expect(isValidCpf('5299822472A')).toBe(false);
  });

  it('validates numeric CNPJ', () => {
    expect(isValidCnpj('11.222.333/0001-81')).toBe(true);
    expect(isValidCnpj('11222333000180')).toBe(false);
    expect(isValidCnpj('00000000000000')).toBe(false);
  });

  it('validates alphanumeric CNPJ (Receita example 12ABC34501DE35)', () => {
    expect(isValidCnpj('12ABC34501DE35')).toBe(true);
    expect(isValidCnpj('12.abc.345/01de-35')).toBe(true);
    expect(isValidCnpj('12ABC34501DE36')).toBe(false);
    // check digits must be numeric
    expect(isValidCnpj('12ABC34501DE3A')).toBe(false);
  });

  it('isValidTaxId picks by length', () => {
    expect(isValidTaxId('52998224725')).toBe(true);
    expect(isValidTaxId('11222333000181')).toBe(true);
    expect(isValidTaxId('12ABC34501DE35')).toBe(true);
    expect(isValidTaxId('5299822472')).toBe(false);
    expect(isValidTaxId('')).toBe(false);
  });
});
