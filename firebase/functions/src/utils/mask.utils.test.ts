import { maskSerial, maskName, maskPhone } from './mask.utils';

describe('maskSerial', () => {
  describe('guards (null/edge cases)', () => {
    test('null returns null', () => {
      expect(maskSerial(null)).toBeNull();
    });

    test('undefined returns null', () => {
      expect(maskSerial(undefined)).toBeNull();
    });

    test('empty string returns null', () => {
      expect(maskSerial('')).toBeNull();
    });

    test('whitespace-only returns null', () => {
      expect(maskSerial('   ')).toBeNull();
    });

    test('non-string returns null', () => {
      expect(maskSerial(123 as any)).toBeNull();
    });
  });

  describe('short serials (≤6 chars)', () => {
    test('1 char returns as-is', () => {
      expect(maskSerial('A')).toBe('A');
    });

    test('2 chars masks first', () => {
      expect(maskSerial('AB')).toBe('*B');
    });

    test('3 chars masks all except last', () => {
      expect(maskSerial('AB3')).toBe('**3');
    });

    test('4 chars masks all except last', () => {
      expect(maskSerial('AB34')).toBe('***4');
    });

    test('6 chars masks all except last', () => {
      expect(maskSerial('ABC123')).toBe('*****3');
    });
  });

  describe('normal serials (>6 chars)', () => {
    test('8 chars: visible=2, start=1, end=1', () => {
      expect(maskSerial('ABCDEFGH')).toBe('A******H');
    });

    test('10 chars: visible=3, start=2, end=1', () => {
      expect(maskSerial('1234567890')).toBe('12*******0');
    });

    test('14 chars: visible=4, start=2, end=2', () => {
      expect(maskSerial('ABCDEFGHIJ1234')).toBe('AB**********34');
    });

    test('15 chars: visible=5, start=3, end=2', () => {
      expect(maskSerial('SN123456789XYZ0')).toBe('SN1**********Z0');
    });

    test('19 chars: visible=6, start=3, end=3', () => {
      expect(maskSerial('IMEI359876543210987')).toBe('IME*************987');
    });
  });

  describe('length preservation', () => {
    const serials = [
      'A',
      'AB',
      'AB3',
      'ABC123',
      'ABCDEFGH',
      '1234567890',
      'ABCDEFGHIJ1234',
      'IMEI359876543210987',
    ];

    test.each(serials)('"%s" preserves length', (serial) => {
      const result = maskSerial(serial);
      expect(result).not.toBeNull();
      expect(result!.length).toBe(serial.length);
    });
  });

  describe('whitespace handling', () => {
    test('trims before masking', () => {
      expect(maskSerial('  ABC123  ')).toBe('*****3');
    });

    test('trims long serial before masking', () => {
      expect(maskSerial(' ABCDEFGH ')).toBe('A******H');
    });
  });
});

describe('maskName', () => {
  test('null returns null', () => {
    expect(maskName(null)).toBeNull();
  });

  test('undefined returns null', () => {
    expect(maskName(undefined)).toBeNull();
  });

  test('empty string returns null', () => {
    expect(maskName('')).toBeNull();
  });

  test('single name returns as-is', () => {
    expect(maskName('Maria')).toBe('Maria');
  });

  test('full name masks last name', () => {
    expect(maskName('Rafael Duarte Lima')).toBe('Rafael L****');
  });

  test('two-part name masks last name', () => {
    expect(maskName('João Silva')).toBe('João S****');
  });
});

describe('maskPhone', () => {
  test('null returns null', () => {
    expect(maskPhone(null)).toBeNull();
  });

  test('undefined returns null', () => {
    expect(maskPhone(undefined)).toBeNull();
  });

  test('short number returns null', () => {
    expect(maskPhone('123')).toBeNull();
  });

  test('masks phone with country code +55', () => {
    expect(maskPhone('+5548988264694')).toBe('(48) *****-4694');
  });

  test('masks phone with country code 55 (no +)', () => {
    expect(maskPhone('5548988264694')).toBe('(48) *****-4694');
  });

  test('masks 11-digit phone (DDD + 9 digits)', () => {
    expect(maskPhone('48988264694')).toBe('(48) *****-4694');
  });

  test('masks 10-digit phone (DDD + 8 digits)', () => {
    expect(maskPhone('4832214694')).toBe('(48) *****-4694');
  });
});
