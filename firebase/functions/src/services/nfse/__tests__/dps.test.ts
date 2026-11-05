import { openCertificate } from '../certificate';
import { brasiliaTimestamps, buildCancelEvent, buildDps, dpsId, LAYOUTS, layoutFor } from '../dps';
import { plainText } from '../layouts/common';
import type { DpsInput, DpsLayoutId } from '../layouts/types';
import { leafOf, signXml, verifyXmlSignature } from '../signature';
import { testPki } from './test-certificates';
import { packageOf, validateAgainstXsd } from './xsd';

// Synthetic data only.
const base = (overrides: Partial<DpsInput> = {}): DpsInput => ({
  environment: 'test',
  issuedAt: '2026-11-05T09:59:55-03:00',
  competenceDate: '2026-11-05',
  appVersion: 'PraticOS-1.104.0',
  series: '10',
  number: 1,
  emitter: { taxId: '00000000000191', cityCode: '4200000', municipalRegistration: '12345', regime: 'simples', simplesOption: 1 },
  recipient: {
    taxId: '00000000000272',
    legalName: 'REVENDA EXEMPLO LTDA',
    address: { postalCode: '88000000', street: 'Rua Exemplo', number: '10', complement: 'Sala 2', district: 'Centro', cityCode: '4200000', state: 'SC' },
    email: 'nota@example.com',
  },
  service: { nationalCode: '140101', municipalCode: '001', description: 'CONSERTO/PINTURA DE CAPÔ - TROCA DE ÓLEO' },
  value: 270,
  simplesTaxRate: 6,
  complementaryInfo: 'OS 182 · Emitida pelo PraticOS (praticos.app)',
  ...overrides,
});

const now = new Date('2026-11-05T12:00:00Z');
const pki = testPki();
const cert = openCertificate(pki.pfx(), 'senha-teste', { now, trustedRoots: [pki.rootPem] });

describe('dpsId', () => {
  it('pads city, document type, series and number', () => {
    expect(dpsId('4200000', '00000000000191', '10', 29)).toBe('DPS' + '4200000' + '2' + '00000000000191' + '00010' + '000000000000029');
    expect(dpsId('4200000', '12345678909', '1', 1)).toBe('DPS' + '4200000' + '1' + '00012345678909' + '00001' + '000000000000001');
    expect(dpsId('4200000', '00000000000191', '10', 29)).toHaveLength(45);
  });

  it('refuses malformed parts', () => {
    expect(() => dpsId('42', '00000000000191', '10', 1)).toThrow();
    expect(() => dpsId('4200000', '00000000000191', '123456', 1)).toThrow();
    expect(() => dpsId('4200000', '00000000000191', '10', 0)).toThrow();
  });
});

describe('brasiliaTimestamps', () => {
  it('is in UTC-3 and 5 seconds behind', () => {
    expect(brasiliaTimestamps(new Date('2026-11-05T13:00:00Z'))).toEqual({
      issuedAt: '2026-11-05T09:59:55-03:00',
      competenceDate: '2026-11-05',
    });
  });

  it('never goes back to the day before (competence would change)', () => {
    expect(brasiliaTimestamps(new Date('2026-11-06T03:00:02Z'))).toEqual({
      issuedAt: '2026-11-06T00:00:00-03:00',
      competenceDate: '2026-11-06',
    });
  });
});

describe('layoutFor', () => {
  const dec = '2026-12-31';
  const jan = '2027-01-01';

  it('2026: production uses 20260209 and tests 20261020, unless configured', () => {
    expect(layoutFor('production', null, dec).id).toBe('v20260209');
    expect(layoutFor('test', null, dec).id).toBe('v20261020');
    expect(layoutFor('production', { production: 'v20261020' }, dec).id).toBe('v20261020');
    expect(layoutFor('production', { production: 'v9999' }, dec).id).toBe('v20260209');
    expect(layoutFor('production', { production: 'constructor' }, dec).id).toBe('v20260209');
    expect(layoutFor('production', { production: [{ layout: 'toString' }] }, jan).id).toBe('v2027_20260209');
  });

  it('from 01/01/2027 the same packages carry IBS/CBS', () => {
    expect(layoutFor('production', null, jan).id).toBe('v2027_20260209');
    expect(layoutFor('test', null, jan).id).toBe('v2027_20261020');
    expect(layoutFor('test', null, '2027-06-15').id).toBe('v2027_20261020');
  });

  it('config turns IBS/CBS on earlier (to try it in Produção Restrita) or holds it back', () => {
    expect(layoutFor('test', { test: 'v2027_20261020' }, dec).id).toBe('v2027_20261020');
    expect(layoutFor('production', { production: 'v20260209' }, jan).id).toBe('v20260209');
  });

  it('a schedule picks the last step already in force, ignoring unknown or malformed steps', () => {
    const schedule = [
      { layout: 'v20260209' },
      { from: '2026-12-15', layout: 'v2027_20260209' },
      { from: '2026-12-20', layout: 'v9999' },
      { from: '15/12/2026', layout: 'v20261020' },
    ];
    expect(layoutFor('production', { production: schedule }, '2026-12-14').id).toBe('v20260209');
    expect(layoutFor('production', { production: schedule }, '2026-12-15').id).toBe('v2027_20260209');
    expect(layoutFor('production', { production: schedule }, '2026-12-25').id).toBe('v2027_20260209');
    // Nothing usable: back to the defaults.
    expect(layoutFor('production', { production: [{ from: '2030-01-01', layout: 'v2027_20260209' }] }, dec).id).toBe('v20260209');
  });
});

describe.each(Object.keys(LAYOUTS) as DpsLayoutId[])('DPS %s', (layoutId) => {
  const layout = LAYOUTS[layoutId];
  const environment = packageOf(layoutId) === 'v20260209' ? 'production' : 'test';

  async function signedAndValid(input: DpsInput) {
    const { id, xml } = buildDps(input, layout);
    const signed = signXml(xml, cert.keyPem, leafOf(cert.chainPem), 'infDPS', 'DPS');
    expect(verifyXmlSignature(signed, cert.certPem)).toBe(true);
    const check = await validateAgainstXsd(signed, layoutId, 'DPS_v1.01.xsd');
    expect(check.errors).toEqual([]);
    return { id, xml, signed };
  }

  it('Simples: regApTribSN, tribFed and pTotTribSN; valid and signed', async () => {
    const { xml, id } = await signedAndValid(base({ environment }));
    expect(id).toBe(dpsId('4200000', '00000000000191', '10', 1));
    expect(xml).toContain('<opSimpNac>3</opSimpNac><regApTribSN>1</regApTribSN>');
    expect(xml).toContain('<tribFed><piscofins><CST>08</CST></piscofins></tribFed>');
    expect(xml).toContain('<pTotTribSN>6.00</pTotTribSN>');
    expect(xml).toContain('<vServ>270.00</vServ>');
    expect(xml).toContain('<tpRetISSQN>1</tpRetISSQN>');
    expect(xml).not.toContain('pAliq');
    // Emitter's name and address are never sent (E0121, E0128).
    expect(xml).toMatch(/<prest><CNPJ>00000000000191<\/CNPJ><IM>12345<\/IM><regTrib>/);
    expect(xml).toContain('<xInfComp>OS 182 · Emitida pelo PraticOS (praticos.app)</xInfComp>');
    expect(xml).toContain(`<tpAmb>${environment === 'production' ? 1 : 2}</tpAmb>`);
  });

  it('MEI: no regApTribSN, no tribFed, indTotTrib 0', async () => {
    const { xml } = await signedAndValid(
      base({ environment, emitter: { taxId: '00000000000191', cityCode: '4200000', regime: 'mei' }, service: { nationalCode: '140101', description: 'Revisão' } }),
    );
    expect(xml).toContain('<regTrib><opSimpNac>2</opSimpNac><regEspTrib>0</regEspTrib></regTrib>');
    expect(xml).not.toContain('regApTribSN');
    expect(xml).not.toContain('tribFed');
    expect(xml).toContain('<indTotTrib>0</indTotTrib>');
    expect(xml).not.toContain('<IM>');
    expect(xml).not.toContain('cTribMun');
  });

  it('recipient with CPF and without a complete address: no <end>', async () => {
    const { xml } = await signedAndValid(
      base({
        environment,
        recipient: { taxId: '123.456.789-09', legalName: 'Fulano de Tal', address: { postalCode: '88000000', street: 'Rua A' }, email: 'not an email' },
      }),
    );
    expect(xml).toContain('<toma><CPF>12345678909</CPF><xNome>Fulano de Tal</xNome></toma>');
  });

  it('several orders: one line per order, odd characters cleaned', async () => {
    const { xml } = await signedAndValid(
      base({ environment, service: { nationalCode: '140101', description: 'OS 182: Troca de óleo – 5W30\nOS 190: Alinhamento 🚗 “dianteiro”' } }),
    );
    expect(xml).toContain('<xDescServ>OS 182: Troca de óleo - 5W30\nOS 190: Alinhamento &quot;dianteiro&quot;</xDescServ>');
  });

  it('escapes XML characters', async () => {
    const { xml } = await signedAndValid(base({ environment, recipient: { ...base().recipient!, legalName: 'A & B <LTDA>' } }));
    expect(xml).toContain('<xNome>A &amp; B &lt;LTDA&gt;</xNome>');
  });

  it('cancellation event is valid and signed', async () => {
    const accessKey = `42000002200000000000191${'2'.repeat(27)}`;
    const { id, xml } = buildCancelEvent({
      environment,
      appVersion: 'PraticOS-1.104.0',
      accessKey,
      authorTaxId: '00000000000191',
      reason: 'serviceNotProvided',
      issuedAt: '2026-11-05T09:59:55-03:00',
    });
    expect(id).toBe(`PRE${accessKey}101101`);
    expect(xml).toContain('<cMotivo>2</cMotivo><xMotivo>Serviço não prestado</xMotivo>');
    const signed = signXml(xml, cert.keyPem, leafOf(cert.chainPem), 'infPedReg', 'pedRegEvento');
    expect(verifyXmlSignature(signed, cert.certPem)).toBe(true);
    expect((await validateAgainstXsd(signed, layoutId, 'pedRegEvento_v1.01.xsd')).errors).toEqual([]);
  });
});

describe('signature', () => {
  it('a changed document no longer verifies', () => {
    const { xml } = buildDps(base(), LAYOUTS.v20261020);
    const signed = signXml(xml, cert.keyPem, cert.certPem, 'infDPS', 'DPS');
    expect(verifyXmlSignature(signed.replace('<vServ>270.00</vServ>', '<vServ>27.00</vServ>'), cert.certPem)).toBe(false);
  });
});

describe('plainText', () => {
  it('keeps Latin-1, collapses spaces and cuts', () => {
    expect(plainText('  Conserto\t de   capô  ', 100)).toBe('Conserto de capô');
    expect(plainText('abcdef', 3)).toBe('abc');
    expect(plainText(null, 3)).toBe('');
  });
});
