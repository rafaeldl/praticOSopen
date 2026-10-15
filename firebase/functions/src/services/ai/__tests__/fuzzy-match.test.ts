import { matchCustomer, matchDevice, nameScore, phoneKey, plateKey, plateLookups, soundKey } from '../fuzzy-match';

describe('nameScore', () => {
  it.each([
    ['Luis', 'Luiz Carlos'],
    ['Thiago', 'Tiago Silva'],
    ['Raphael', 'Rafael'],
    ['Sousa', 'Souza'],
    ['Kelly', 'Keli'],
    ['Joao', 'João Pedro'],
    ['Juliana', 'Juliana Souza'],
  ])('treats "%s" as the same as "%s"', (said, registered) => {
    expect(nameScore(said, registered)).toBeGreaterThanOrEqual(0.97);
  });

  it('finds close but not sure spellings', () => {
    const score = nameScore('Juliene', 'Juliana');
    expect(score).toBeGreaterThanOrEqual(0.8);
    expect(score).toBeLessThan(0.97);
  });

  it('keeps different names apart', () => {
    expect(nameScore('Pedro', 'Juliana')).toBeLessThan(0.8);
    expect(nameScore('Juliana Souza', 'Juliana Lima')).toBeLessThan(0.8);
  });

  it('sounds alike in Portuguese', () => {
    expect(soundKey('Thiago')).toBe(soundKey('Tiago'));
    expect(soundKey('Luiz')).toBe(soundKey('Luis'));
    expect(soundKey('Gisele')).toBe(soundKey('Jisele'));
  });
});

describe('matchCustomer', () => {
  const customers = [
    { id: '1', name: 'Juliana Souza', phone: '(48) 99999-1111' },
    { id: '2', name: 'Juliana Lima' },
    { id: '3', name: 'Júlio Felipetto', phone: '48 3249-1528' },
    { id: '4', name: 'Mario Andrade' },
  ];

  it('uses the phone first, in any format', () => {
    expect(matchCustomer({ name: 'Juliana', phone: '+55 48 99999 1111' }, customers).match?.id).toBe('1');
    expect(phoneKey('(48) 99999-1111')).toBe(phoneKey('99991111'));
  });

  it('picks the only sure name and lists the others', () => {
    const r = matchCustomer({ name: 'Julio' }, customers);
    expect(r.match?.id).toBe('3');
    expect(r.alternatives.map((c) => c.id)).toEqual(expect.arrayContaining(['1', '2']));
  });

  it('asks when two customers share the spoken name', () => {
    const r = matchCustomer({ name: 'Juliana' }, customers);
    expect(r.match).toBeNull();
    expect(r.alternatives.map((c) => c.id).slice(0, 2)).toEqual(['1', '2']);
  });

  it('asks on a close spelling instead of guessing', () => {
    const r = matchCustomer({ name: 'Juliene' }, customers);
    expect(r.match).toBeNull();
    expect(r.alternatives[0].name).toMatch(/Juliana/);
  });

  it('the exact full name wins', () => {
    expect(matchCustomer({ name: 'juliana souza' }, customers).match?.id).toBe('1');
  });

  it('finds nobody for a new name', () => {
    expect(matchCustomer({ name: 'Pedro', phone: '48 2222-2222' }, customers)).toEqual({ match: null, alternatives: [] });
  });
});

describe('plateKey', () => {
  it('is the same for old, dashed and Mercosul plates', () => {
    expect(plateKey('abc-1234')).toBe('ABC1234');
    expect(plateKey('ABC1C34')).toBe('ABC1234');
    expect(plateKey('BRA2E19')).toBe(plateKey('BRA2419'));
  });

  it('fixes digit/letter slips from a photo', () => {
    expect(plateKey('A8C1234')).toBe('ABC1234');
    expect(plateKey('ABC12B4')).toBe('ABC1284');
  });

  it('keeps serial numbers as they are', () => {
    expect(plateKey('SN-998877AB')).toBe('SN998877AB');
  });

  it('lists the stored forms of a plate', () => {
    expect(plateLookups('abc1234')).toEqual(expect.arrayContaining(['ABC1234', 'ABC-1234', 'ABC1C34']));
  });
});

describe('matchDevice', () => {
  const devices = [
    { id: 'a', name: 'Corsa', manufacturer: 'Chevrolet', serial: 'MMM0099' },
    { id: 'b', name: 'Gol', manufacturer: 'Volkswagen', serial: 'BRA2E19' },
    { id: 'c', name: 'Corsa Classic', serial: 'ABC-1234' },
    { id: 'd', name: 'Onix', manufacturer: 'GM' },
  ];

  it('finds the plate however it was said', () => {
    expect(matchDevice({ serial: 'abc 1234' }, devices).match?.id).toBe('c');
    expect(matchDevice({ serial: 'BRA2419' }, devices).match?.id).toBe('b');
  });

  it('knows brand nicknames', () => {
    expect(matchDevice({ name: 'GM Corsa' }, devices).match?.id).toBe('a');
    expect(matchDevice({ name: 'Chevrolet Corsa' }, devices).match?.id).toBe('a');
    expect(matchDevice({ name: 'Onix 2020', manufacturer: 'chevrolet' }, devices).match?.id).toBe('d');
  });

  it('never matches another brand', () => {
    const r = matchDevice({ name: 'Corsa', manufacturer: 'Fiat' }, devices);
    expect(r.match).toBeNull();
    expect(r.alternatives.map((d) => d.id)).toEqual(['c']);
  });

  it('a new plate is a new vehicle, with same-name ones only listed', () => {
    const r = matchDevice({ name: 'Gol', serial: 'XYZ9999' }, devices);
    expect(r.match).toBeNull();
    expect(r.alternatives.map((d) => d.id)).toEqual(['b']);
  });

  it('forgives a typo in the model', () => {
    expect(matchDevice({ name: 'Corssa' }, devices).match?.id).toBe('a');
  });
});
