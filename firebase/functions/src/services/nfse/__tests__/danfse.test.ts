jest.mock('../../firestore.service', () => jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock);
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { validateXML } from 'xmllint-wasm';
import { read, resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
import { danfsePdfPath, ensureDanfse, situationOf } from '../danfse.service';
import { dateTimeText, parseNfseXml, taxIdText } from '../danfse/parse';
import { qrCodeUrl, renderDanfse } from '../danfse/render';
import { NfseServiceError } from '../errors';
import { dpsInput, FIXTURE_KEY, nfseXml } from './danfse-fixture';

// Synthetic notas only (no real data).

const CITIES = { '4200000': 'Cidade Exemplo' };

async function validNfse(xml: string) {
  const dir = join(__dirname, 'fixtures', 'xsd', 'v20261020');
  const files = readdirSync(dir).filter((f) => f.endsWith('.xsd'));
  const schema = 'NFSe_v1.01.xsd';
  return validateXML({
    xml: [{ fileName: 'nfse.xml', contents: xml }],
    schema: [{ fileName: schema, contents: readFileSync(join(dir, schema), 'utf8') }],
    preload: files.filter((f) => f !== schema).map((f) => ({ fileName: f, contents: readFileSync(join(dir, f), 'utf8') })),
  });
}

/** Text drawn in an uncompressed pdfkit PDF (hex strings of the standard fonts). */
function pdfText(pdf: Buffer): string {
  const raw = pdf.toString('latin1');
  const hex = [...raw.matchAll(/<([0-9a-fA-F]+)>/g)].map((m) => Buffer.from(m[1], 'hex').toString('latin1'));
  return hex.join('');
}

function pageCount(pdf: Buffer): number {
  return (pdf.toString('latin1').match(/\/Type \/Page\b/g) ?? []).length;
}

describe('the synthetic NFS-e fixture', () => {
  it('is valid against the official NFS-e XSD', async () => {
    const result = await validNfse(nfseXml());
    expect(result.errors.map((e) => e.rawMessage)).toEqual([]);
    expect(result.valid).toBe(true);
  });
});

describe('parseNfseXml', () => {
  it('reads every field of the Simples nota as printed', () => {
    const data = parseNfseXml(nfseXml(), CITIES);
    expect(data.accessKey).toBe(FIXTURE_KEY); // id without the "NFS" prefix
    expect(data.accessKey).toHaveLength(50);
    expect(data.testEnvironment).toBe(true);
    expect(data.header).toEqual({ city: 'Cidade Exemplo / SC', generator: 'Sefin Nacional NFS-e', environment: 'Homologação' });
    expect(data.identification).toEqual({
      number: '29',
      competence: '05/11/2026',
      issuedAt: '05/11/2026 10:00:03',
      dpsNumber: '7',
      dpsSeries: '10',
      dpsIssuedAt: '05/11/2026 09:59:55',
      emitter: 'Prestador',
      situation: 'NFS-e Gerada',
      purpose: 'NFS-e regular',
    });
    // The DPS sends only CNPJ, IM and regime: name and address come from "emit".
    expect(data.provider).toMatchObject({
      taxId: '00.000.000/0001-91',
      municipalRegistration: '12345',
      name: 'OFICINA EXEMPLO LTDA',
      city: 'Cidade Exemplo / SC',
      cityCodeAndPostalCode: '4200000 / 88.000-001',
      address: 'Avenida Teste, 100, Industrial',
      email: 'oficina@example.com',
      simplesNacional: 'Optante - ME/EPP',
      simplesRegime: 'Regime de apuração dos tributos federais e municipal pelo Simples Nacional',
    });
    expect(data.taker).toEqual({
      taxId: '00.000.000/0002-72',
      municipalRegistration: '-',
      phone: '-',
      name: 'REVENDA EXEMPLO LTDA',
      city: 'Cidade Exemplo / SC',
      cityCodeAndPostalCode: '4200000 / 88.000-000',
      address: 'Rua Exemplo, 10, Sala 2, Centro',
      email: 'nota@example.com',
    });
    expect(data.recipient).toBe('taker');
    expect(data.intermediary).toBeNull();
    expect(data.service).toMatchObject({
      codes: '14.01.01 / 001',
      place: 'Cidade Exemplo / SC / BR',
      description: 'CONSERTO/PINTURA DE CAPÔ - TROCA DE ÓLEO',
    });
    expect(data.service.codeDescription).toMatch(/^Lubrificação, limpeza/);
    expect(data.municipalTax).toMatchObject({ taxation: 'Operação Tributável', withholding: 'Não Retido', base: 'R$ 270,00', hasBenefitRow: false });
    expect(data.totals).toMatchObject({ serviceValue: 'R$ 270,00', netValue: 'R$ 270,00', withholdings: '-', ibsCbsTotal: '-' });
    expect(data.complementaryInfo).toBe(
      'Inf. Cont.: OS 182 · Emitida pelo PraticOS (praticos.app) | Totais Aproximados dos Tributos cfe. Lei nº 12.741/2012: Simples Nacional: 6,00%',
    );
  });

  it('MEI: no Simples regime and the taxes line still printed (note 10)', () => {
    const xml = nfseXml(dpsInput({ emitter: { taxId: '00000000000191', cityCode: '4200000', regime: 'mei' } as never, simplesTaxRate: undefined }));
    const data = parseNfseXml(xml, CITIES);
    expect(data.provider.simplesNacional).toBe('Optante - MEI');
    expect(data.provider.simplesRegime).toBe('-');
    expect(data.complementaryInfo).toMatch(/Totais Aproximados dos Tributos cfe\. Lei nº 12\.741\/2012: Federais: -; Estaduais: -; Municipais: -$/);
  });

  it('production nota: no "sem validade" and the environment says Produção', () => {
    const data = parseNfseXml(nfseXml(dpsInput(), { tpAmb: '1' }), CITIES);
    expect(data.testEnvironment).toBe(false);
    expect(data.header.environment).toBe('Produção');
  });

  it('nota without a taker: taker and recipient "not identified"', () => {
    const xml = nfseXml().replace(/<toma>.*?<\/toma>/, '');
    const data = parseNfseXml(xml, CITIES);
    expect(data.taker).toBeNull();
    expect(data.recipient).toBeNull();
  });

  it('PIS/COFINS withheld: social contributions add up, own debit is zero (v1.02 rule)', () => {
    const xml = nfseXml().replace(
      /<tribFed>.*?<\/tribFed>|(<\/tribMun>)/,
      (m, close) =>
        (close ?? '') +
        '<tribFed><piscofins><CST>01</CST><vBCPisCofins>270.00</vBCPisCofins><pAliqPis>0.65</pAliqPis><pAliqCofins>3.00</pAliqCofins><vPis>1.76</vPis><vCofins>8.10</vCofins><tpRetPisCofins>1</tpRetPisCofins></piscofins><vRetCSLL>2.70</vRetCSLL></tribFed>',
    );
    const data = parseNfseXml(xml, CITIES);
    expect(data.federalTax).toMatchObject({
      socialContributions: 'R$ 12,56',
      pis: 'R$ 0,00',
      cofins: 'R$ 0,00',
      contributionsDescription: 'PIS/COFINS Retido',
      showPisCofinsRow: true,
    });
  });

  it('competence after 2026: the PIS/COFINS row is not printed (note 6)', () => {
    const xml = nfseXml().replace(/<dCompet>2026-11-05<\/dCompet>/, '<dCompet>2027-01-04</dCompet>');
    expect(parseNfseXml(xml, CITIES).federalTax.showPisCofinsRow).toBe(false);
  });

  it('unknown city code shows only the UF; foreign or missing data becomes "-"', () => {
    // The emitter city comes from xLocEmi; another city with no name shows only the UF.
    const xml = nfseXml().replace(/(<toma>.*?<cMun>)4200000/, '$14205407');
    const data = parseNfseXml(xml, {});
    expect(data.provider.city).toBe('Cidade Exemplo / SC');
    expect(data.taker!.city).toBe('SC');
    expect(data.service.nbs).toBe('-');
  });

  it('refuses something that is not an NFS-e', () => {
    expect(() => parseNfseXml('<DPS/>')).toThrow(/infNFSe/);
  });

  it('formats documents and dates', () => {
    expect(taxIdText('12345678909')).toBe('123.456.789-09');
    expect(taxIdText('00000000000191')).toBe('00.000.000/0001-91');
    expect(dateTimeText('2026-11-05T14:30:00-03:00')).toBe('05/11/2026 14:30:00');
    expect(dateTimeText('2026-11-05')).toBe('05/11/2026');
  });
});

describe('renderDanfse', () => {
  const data = parseNfseXml(nfseXml(), CITIES);

  it('QR code points to the national public lookup with the access key', () => {
    expect(qrCodeUrl(FIXTURE_KEY)).toBe(`https://www.nfse.gov.br/ConsultaPublica/?tpc=1&chave=${FIXTURE_KEY}`);
  });

  it('one A4 page with the header, the key and the values', async () => {
    const pdf = await renderDanfse(data, 'normal', { compress: false });
    expect(pdf.subarray(0, 5).toString()).toBe('%PDF-');
    expect(pageCount(pdf)).toBe(1);
    expect(pdf.toString('latin1')).toMatch(/\/MediaBox \[0 0 595\.27\d* 841\.8\d*\]/);
    const text = pdfText(pdf);
    for (const piece of ['DANFSe v2.0', 'Documento Auxiliar da NFS-e', FIXTURE_KEY, 'OFICINA EXEMPLO LTDA', 'REVENDA EXEMPLO LTDA', 'R$ 270,00', 'O DESTINATÁRIO É O PRÓPRIO TOMADOR/ADQUIRENTE DA OPERAÇÃO']) {
      expect(text).toContain(piece);
    }
    expect(text).toContain('NFS-e SEM VALIDADE JURÍDICA');
    expect(text).not.toContain('CANCELADA');
  });

  it('production nota has no "sem validade"; canceled and replaced get the watermark', async () => {
    const production = { ...data, testEnvironment: false };
    expect(pdfText(await renderDanfse(production, 'normal', { compress: false }))).not.toContain('SEM VALIDADE');
    expect(pdfText(await renderDanfse(production, 'canceled', { compress: false }))).toContain('CANCELADA');
    expect(pdfText(await renderDanfse(production, 'replaced', { compress: false }))).toContain('SUBSTITUÍDA');
  });

  it('a very long description still fits in one page (ends with "...")', async () => {
    const long = { ...data, service: { ...data.service, description: 'TROCA DE PEÇA '.repeat(400) } };
    const pdf = await renderDanfse(long, 'normal', { compress: false });
    expect(pageCount(pdf)).toBe(1);
    expect(pdfText(pdf)).toContain('...');
  });

  it('compressed by default', async () => {
    const pdf = await renderDanfse(data);
    expect(pageCount(pdf)).toBe(1);
    expect(pdf.toString('latin1')).toContain('/FlateDecode');
  });
});

describe('ensureDanfse', () => {
  let files: Record<string, string | Buffer>;
  let cityLookups: string[];
  const deps = () => ({
    readFile: async (path: string) => String(files[path]),
    saveFile: async (path: string, contents: Buffer) => {
      files[path] = contents;
    },
    cityName: async (code: string) => {
      cityLookups.push(code);
      return null;
    },
    now: () => new Date('2026-11-05T13:00:00Z'),
  });

  beforeEach(() => {
    resetFakeDb();
    files = { 'tenants/c1/invoices/i1/nfse.xml': nfseXml() };
    cityLookups = [];
    seed('companies/c1/fiscalEmitters/e1', { cityCode: '4200000', cityName: 'Cidade Exemplo' });
    seed('companies/c1/invoices/i1', {
      provider: 'direct',
      status: 'authorized',
      emitter: { id: 'e1' },
      xmlPath: 'tenants/c1/invoices/i1/nfse.xml',
    });
  });

  it('makes the PDF once, from the stored XML, with the emitter city name', async () => {
    const path = await ensureDanfse('c1', 'i1', deps());
    expect(path).toBe(danfsePdfPath('c1', 'i1'));
    expect(path).toBe('tenants/c1/invoices/i1/danfse.pdf');
    expect((files[path] as Buffer).subarray(0, 5).toString()).toBe('%PDF-');
    expect(read('companies/c1/invoices/i1')).toMatchObject({ pdfPath: path, pdfSituation: 'normal' });
    expect(cityLookups).toEqual([]); // known from the emitter, no lookup

    delete files[path];
    expect(await ensureDanfse('c1', 'i1', deps())).toBe(path);
    expect(files[path]).toBeUndefined(); // already made: not again
  });

  it('a canceled nota gets a new PDF with the watermark', async () => {
    await ensureDanfse('c1', 'i1', deps());
    seed('companies/c1/invoices/i1', { ...read('companies/c1/invoices/i1'), status: 'canceled' });
    await ensureDanfse('c1', 'i1', deps());
    expect(read('companies/c1/invoices/i1')!.pdfSituation).toBe('canceled');
  });

  it('looks up the cities it does not know', async () => {
    seed('companies/c1/fiscalEmitters/e1', {});
    await ensureDanfse('c1', 'i1', deps());
    expect(cityLookups).toEqual(['4200000']);
  });

  it('no PDF for notas that were not issued or are from the Asaas', async () => {
    seed('companies/c1/invoices/i2', { provider: 'direct', status: 'creating' });
    seed('companies/c1/invoices/i3', { provider: 'asaas', status: 'authorized', xmlPath: 'x' });
    for (const id of ['i2', 'i3']) {
      await expect(ensureDanfse('c1', id, deps())).rejects.toMatchObject({ code: 'PDF_NOT_AVAILABLE' });
    }
    await expect(ensureDanfse('c1', 'nope', deps())).rejects.toBeInstanceOf(NfseServiceError);
  });

  it('watermark by status', () => {
    expect(situationOf({ status: 'authorized' })).toBe('normal');
    expect(situationOf({ status: 'cancellationDenied' })).toBe('normal');
    expect(situationOf({ status: 'canceled' })).toBe('canceled');
    expect(situationOf({ status: 'error' })).toBeNull();
  });
});
