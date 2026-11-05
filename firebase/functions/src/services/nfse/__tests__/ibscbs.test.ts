import { openCertificate } from '../certificate';
import { buildDps, LAYOUTS } from '../dps';
import { FALLBACK_OPERATION, FULL_TAXATION_CLASS, itemOf, resolveIbsCbs } from '../layouts/ibscbs';
import { IBSCBS_TABLE } from '../layouts/ibscbs-table';
import type { DpsInput, DpsLayoutId } from '../layouts/types';
import { leafOf, signXml } from '../signature';
import { testPki } from './test-certificates';
import { packageOf, validateAgainstXsd } from './xsd';

// Synthetic data only.
const base = (overrides: Partial<DpsInput> = {}): DpsInput => ({
  environment: 'test',
  issuedAt: '2027-01-04T09:59:55-03:00',
  competenceDate: '2027-01-04',
  appVersion: 'PraticOS-1.110.0',
  series: '10',
  number: 7,
  emitter: { taxId: '00000000000191', cityCode: '4200000', municipalRegistration: '12345', regime: 'simples', simplesOption: 1 },
  recipient: { taxId: '00000000000272', legalName: 'REVENDA EXEMPLO LTDA', email: 'nota@example.com' },
  service: { nationalCode: '140101', nbs: '120011000', description: 'Revisão e troca de óleo' },
  value: 350,
  simplesTaxRate: 6,
  complementaryInfo: 'OS 200 · Emitida pelo PraticOS (praticos.app)',
  ...overrides,
});

const mei = (service: DpsInput['service']) =>
  base({ emitter: { taxId: '00000000000191', cityCode: '4200000', regime: 'mei' }, service, simplesTaxRate: null });

const pki = testPki();
const cert = openCertificate(pki.pfx(), 'senha-teste', { now: new Date('2026-11-05T12:00:00Z'), trustedRoots: [pki.rootPem] });

describe('correlation table (Anexo VIII)', () => {
  it('every row has valid codes', () => {
    expect(IBSCBS_TABLE.length).toBeGreaterThan(900);
    for (const [item, nbs, activity, ops, classes] of IBSCBS_TABLE) {
      expect(item).toMatch(/^(\d{2}\.\d{2}|99\.\d{2}\.\d{2})$/);
      expect(nbs).toMatch(/^\d{9}$/);
      expect(activity).toMatch(/^(\d{2})?$/);
      for (const op of ops.split(' ')) expect(op).toMatch(/^\d{6}$/);
      for (const c of classes.split(' ')) expect(c).toMatch(/^\d{6}$/);
    }
  });
});

describe('resolveIbsCbs', () => {
  it('item of the national code', () => {
    expect(itemOf('140101')).toBe('14.01');
    expect(itemOf('01.07.01')).toBe('01.07');
    expect(itemOf('990401')).toBe('99.04.01');
    expect(itemOf('')).toBe('');
  });

  it('by NBS: maintenance of a vehicle at the shop (050101), full taxation', () => {
    expect(resolveIbsCbs(base())).toEqual({ operation: '050101', classification: '000001', situation: '000', source: 'nbs' });
  });

  it('without NBS: the pair most NBS of the item give', () => {
    expect(resolveIbsCbs(base({ service: { nationalCode: '140101', description: 'x' } }))).toMatchObject({
      operation: '050101',
      classification: '000001',
      source: 'item',
    });
  });

  it('prefers full taxation when the NBS also lists special classes', () => {
    // 01.01 / 1.1502.90.00 lists 000001, 200043 (government) and 200044.
    expect(resolveIbsCbs(base({ service: { nationalCode: '010101', nbs: '115029000', description: 'x' } })).classification).toBe('000001');
  });

  it('keeps a reduced class when the NBS has no full taxation (CST from cClassTrib)', () => {
    const row = IBSCBS_TABLE.find(([, , , , classes]) => !classes.split(' ').includes(FULL_TAXATION_CLASS))!;
    const codes = resolveIbsCbs(base({ service: { nationalCode: row[0].replace(/\./g, '').padEnd(6, '1').slice(0, 6), nbs: row[1], description: 'x' } }));
    expect(codes.classification).toBe(row[4].split(' ')[0]);
    expect(codes.situation).toBe(row[4].slice(0, 3));
  });

  it('unknown service: the generic pair, and the government judges it', () => {
    expect(resolveIbsCbs(base({ service: { nationalCode: '999999', description: 'x' } }))).toEqual({
      operation: FALLBACK_OPERATION,
      classification: FULL_TAXATION_CLASS,
      situation: '000',
      source: 'fallback',
    });
  });

  it('own codes win (service done at the customer: 050102)', () => {
    expect(resolveIbsCbs(base({ service: { ...base().service, operationIndicator: '050102' } }))).toMatchObject({
      operation: '050102',
      classification: '000001',
      source: 'input',
    });
    expect(resolveIbsCbs(base({ service: { ...base().service, operationIndicator: '12' } })).operation).toBe('050101');
  });
});

describe.each(['v2027_20260209', 'v2027_20261020'] as DpsLayoutId[])('DPS %s', (layoutId) => {
  const layout = LAYOUTS[layoutId];
  const environment = packageOf(layoutId) === 'v20260209' ? 'production' : 'test';

  async function valid(input: DpsInput) {
    const { xml } = buildDps({ ...input, environment }, layout);
    const signed = signXml(xml, cert.keyPem, leafOf(cert.chainPem), 'infDPS', 'DPS');
    expect((await validateAgainstXsd(signed, layoutId, 'DPS_v1.01.xsd')).errors).toEqual([]);
    return xml;
  }

  it('Simples: IBSCBS is the last group of infDPS', async () => {
    const xml = await valid(base());
    expect(xml).toMatch(/<\/valores><IBSCBS>.*<\/IBSCBS><\/infDPS><\/DPS>$/);
    expect(xml).toContain('<cIndOp>050101</cIndOp><indDest>0</indDest>');
    if (environment === 'production') {
      expect(xml).toContain('<IBSCBS><finNFSe>0</finNFSe><cIndOp>');
      expect(xml).toContain('<trib><gIBSCBS><CST>000</CST><cClassTrib>000001</cClassTrib></gIBSCBS></trib>');
    } else {
      expect(xml.match(/<finNFSe>/g)).toHaveLength(1);
      expect(xml).toContain('<trib><CST>000</CST><cClassTrib>000001</cClassTrib></trib>');
    }
    // The Simples part of the DPS does not change.
    expect(xml).toContain('<opSimpNac>3</opSimpNac><regApTribSN>1</regApTribSN>');
    expect(xml).toContain('<pTotTribSN>6.00</pTotTribSN>');
    // Not in any published XSD yet (NT 009 §2.4).
    expect(xml).not.toContain('regApIBSCBSSN');
    expect(xml).not.toContain('cAtvSN');
  });

  it('MEI: same IBSCBS group, MEI rules kept', async () => {
    const xml = await valid(mei({ nationalCode: '140101', description: 'Revisão' }));
    expect(xml).toContain('<opSimpNac>2</opSimpNac>');
    expect(xml).toContain('<indTotTrib>0</indTotTrib>');
    expect(xml).toContain('<cIndOp>050101</cIndOp>');
  });

  it('unknown service and own codes are still valid in the schema', async () => {
    await valid(base({ service: { nationalCode: '999999', description: 'Serviço' } }));
    await valid(base({ service: { ...base().service, operationIndicator: '050102', taxClassification: '200043' } }));
  });

  it('every row of the table builds a valid DPS (sample)', async () => {
    const step = Math.ceil(IBSCBS_TABLE.length / 25);
    for (let i = 0; i < IBSCBS_TABLE.length; i += step) {
      const [item, nbs] = IBSCBS_TABLE[i];
      const nationalCode = item.replace(/\./g, '').padEnd(6, '1').slice(0, 6);
      await valid(base({ service: { nationalCode, nbs, description: 'Serviço' } }));
    }
  });
});

describe('packages without IBS/CBS', () => {
  it.each(['v20260209', 'v20261020'] as DpsLayoutId[])('%s does not send IBSCBS', (layoutId) => {
    expect(buildDps(base(), LAYOUTS[layoutId]).xml).not.toContain('IBSCBS');
  });
});
