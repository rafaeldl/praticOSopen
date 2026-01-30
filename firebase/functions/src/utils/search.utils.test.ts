import { removeAccents, generateKeywords } from './search.utils';

describe('removeAccents', () => {
  test('removes common Portuguese accents', () => {
    expect(removeAccents('João')).toBe('Joao');
    expect(removeAccents('José')).toBe('Jose');
    expect(removeAccents('Açúcar')).toBe('Acucar');
    expect(removeAccents('Ação')).toBe('Acao');
    expect(removeAccents('Café')).toBe('Cafe');
  });

  test('removes Spanish accents', () => {
    expect(removeAccents('Señor')).toBe('Senor');
    expect(removeAccents('Niño')).toBe('Nino');
    expect(removeAccents('Español')).toBe('Espanol');
  });

  test('preserves case', () => {
    expect(removeAccents('JOÃO')).toBe('JOAO');
    expect(removeAccents('JoÃo')).toBe('JoAo');
  });

  test('preserves non-accented characters', () => {
    expect(removeAccents('abc')).toBe('abc');
    expect(removeAccents('123')).toBe('123');
    expect(removeAccents('test')).toBe('test');
  });
});

describe('generateKeywords', () => {
  test('removes accents and special characters', () => {
    expect(generateKeywords('João Da Silva&*-')).toEqual(['joao', 'da', 'silva']);
  });

  test('handles names with accents', () => {
    expect(generateKeywords('Maria José')).toEqual(['maria', 'jose']);
  });

  test('removes special characters', () => {
    expect(generateKeywords('Açúcar & Café!')).toEqual(['acucar', 'cafe']);
  });

  test('handles null input', () => {
    expect(generateKeywords(null)).toEqual([]);
  });

  test('handles undefined input', () => {
    expect(generateKeywords(undefined)).toEqual([]);
  });

  test('handles empty string', () => {
    expect(generateKeywords('')).toEqual([]);
  });

  test('preserves numbers', () => {
    expect(generateKeywords('123 ABC')).toEqual(['123', 'abc']);
  });

  test('handles multiple spaces', () => {
    expect(generateKeywords('João    Maria')).toEqual(['joao', 'maria']);
  });

  test('handles leading and trailing spaces', () => {
    expect(generateKeywords('  João Silva  ')).toEqual(['joao', 'silva']);
  });

  test('handles only special characters', () => {
    expect(generateKeywords('&*@#$%')).toEqual([]);
  });

  test('handles real world examples - Brazilian names', () => {
    expect(generateKeywords('José da Silva Júnior')).toEqual([
      'jose',
      'da',
      'silva',
      'junior',
    ]);
    expect(generateKeywords('Maria Conceição dos Santos')).toEqual([
      'maria',
      'conceicao',
      'dos',
      'santos',
    ]);
  });

  test('handles real world examples - Company names', () => {
    expect(generateKeywords('Oficina do João - ME')).toEqual([
      'oficina',
      'do',
      'joao',
      'me',
    ]);
    expect(generateKeywords('Auto Peças São Paulo Ltda.')).toEqual([
      'auto',
      'pecas',
      'sao',
      'paulo',
      'ltda',
    ]);
  });

  test('handles real world examples - Product/Service names', () => {
    expect(generateKeywords('Troca de Óleo 5W30')).toEqual([
      'troca',
      'de',
      'oleo',
      '5w30',
    ]);
  });

  test('handles uppercase input', () => {
    expect(generateKeywords('JOÃO DA SILVA')).toEqual(['joao', 'da', 'silva']);
  });

  test('handles mixed case input', () => {
    expect(generateKeywords('JoÃo Da SiLvA')).toEqual(['joao', 'da', 'silva']);
  });
});
