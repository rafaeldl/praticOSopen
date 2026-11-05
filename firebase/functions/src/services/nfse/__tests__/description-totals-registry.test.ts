import { complementaryInfo, describeOrdersForNota, serviceText } from '../description';
import { cityUsesNationalIssuer, issRateOf, lookupCnc, lookupCnpj, portalServiceCode } from '../registry.service';
import { SefinClient, type HttpResponse } from '../sefin-client';
import { emitterTotals, meiWarning } from '../totals';

describe('description (§4.4)', () => {
  it('drops the detail words the catalog name already has', () => {
    expect(serviceText({ service: { id: 's', name: 'Conserto/Pintura de Capô' }, description: 'Capo' })).toBe('Conserto/Pintura de Capô');
    expect(serviceText({ service: { id: 's', name: 'Alinhamento' }, description: 'alinhamento dianteiro' })).toBe('Alinhamento - dianteiro');
    expect(serviceText({ service: { id: 's', name: '' }, description: 'Só o detalhe' })).toBe('Só o detalhe');
  });

  it('applies the emitter style: uppercase and separator', () => {
    const orders = [{ number: 1, services: [{ service: { id: 'a', name: 'Troca de óleo' }, value: 50 }, { service: { id: 'b', name: 'Filtro' }, value: 20 }] }];
    expect(describeOrdersForNota(orders, { uppercase: true, separator: ' - ' })).toBe('TROCA DE ÓLEO - FILTRO');
    expect(describeOrdersForNota(orders, null)).toBe('Troca de óleo, Filtro');
  });

  it('complementary info always names the orders and the app', () => {
    expect(complementaryInfo([182])).toBe('OS 182 · Emitida pelo PraticOS (praticos.app)');
    expect(complementaryInfo([182, 190])).toBe('OS 182, 190 · Emitida pelo PraticOS (praticos.app)');
    expect(complementaryInfo([])).toBe('Emitida pelo PraticOS (praticos.app)');
  });
});

describe('totals (§5.7)', () => {
  const invoices = [
    { status: 'authorized', value: 100, effectiveDate: '2026-11-02' },
    { status: 'authorized', value: 50.1, effectiveDate: '2026-03-10' },
    { status: 'canceled', value: 999, effectiveDate: '2026-11-03' },
    { status: 'error', value: 999, effectiveDate: '2026-11-03' },
    { status: 'cancellationDenied', value: 10, effectiveDate: '2026-11-04' },
    { status: 'authorized', value: 999, effectiveDate: '2025-12-31' },
  ];

  it('year and month minus canceled, in cents', () => {
    expect(emitterTotals(invoices, '2026-11-05')).toEqual({ year: 2026, yearValue: 160.1, month: 11, monthValue: 110 });
  });

  it('MEI warns at 80% and over the limit; Simples never', () => {
    const totals = { year: 2026, yearValue: 60000, month: 11, monthValue: 0 };
    expect(meiWarning('mei', totals, 4000, '2026-11-05', 81000)).toBe('none');
    expect(meiWarning('mei', totals, 4800, '2026-11-05', 81000)).toBe('near');
    expect(meiWarning('mei', totals, 21001, '2026-11-05', 81000)).toBe('over');
    expect(meiWarning('simples', totals, 999999, '2026-11-05')).toBe('none');
    // Totals of last year do not count in January.
    expect(meiWarning('mei', { ...totals, year: 2025 }, 100, '2026-01-02')).toBe('none');
  });
});

describe('registry lookups (recorded shapes, synthetic values)', () => {
  const client = (body: unknown, status = 200) =>
    new SefinClient({
      environment: 'production',
      keyPem: 'k',
      chainPem: 'c',
      transport: async (): Promise<HttpResponse> => ({ status, body: JSON.stringify(body) }),
    });

  it('CNC: municipal registration and enabled to issue', async () => {
    const answer = {
      ListaCadastroMunicipal: [
        { InfCad: { Inscricao: '00000000000191', InscricaoMunicipal: '12345', RazaoSocial: 'OFICINA EXEMPLO LTDA', SituacaoEmissaoNFSe: 'HABILITADO' } },
      ],
      StatusProcessamento: 'DOCUMENTOS_LOCALIZADOS',
    };
    expect(await lookupCnc(client(answer), '4200000', '00000000000191')).toEqual({
      municipalRegistration: '12345',
      enabledInCity: true,
      legalName: 'OFICINA EXEMPLO LTDA',
    });
    const off = { ListaCadastroMunicipal: [{ InfCad: { Inscricao: '00000000000191', InscricaoMunicipal: '', SituacaoEmissaoNFSe: 'NAO_HABILITADO' } }] };
    expect(await lookupCnc(client(off), '4200000', '00000000000191')).toMatchObject({ municipalRegistration: null, enabledInCity: false });
    expect(await lookupCnc(client({ StatusProcessamento: 'NENHUM_DOCUMENTO_LOCALIZADO' }), '4200000', '00000000000191')).toBeNull();
  });

  it('city agreement and ISS rate on the date', async () => {
    expect(await cityUsesNationalIssuer(client({ parametrosConvenio: { aderenteEmissorNacional: 1 } }), '4200000')).toBe(true);
    expect(await cityUsesNationalIssuer(client({ parametrosConvenio: { aderenteEmissorNacional: 0 } }), '4200000')).toBe(false);
    expect(portalServiceCode('140101', '1')).toBe('14.01.01.001');
    expect(portalServiceCode('140101')).toBe('14.01.01.000');
    const history = {
      aliquotas: {
        '14.01.01.000': [
          { Aliq: 3, DtIni: '2024-01-01T00:00:00', DtFim: '2025-08-26T00:00:00' },
          { Aliq: 5, DtIni: '2025-08-27T00:00:00', DtFim: null },
        ],
      },
    };
    expect(await issRateOf(client(history), '4200000', '140101', null, '2026-11-05')).toBe(5);
    expect(await issRateOf(client(history), '4200000', '140101', null, '2025-01-01')).toBe(3);
  });

  it('public CNPJ API fills legal name, regime and city', async () => {
    const fetchImpl = jest.fn(async () => ({
      status: 200,
      ok: true,
      json: async () => ({
        razao_social: 'OFICINA EXEMPLO LTDA', nome_fantasia: 'Oficina', opcao_pelo_simples: true, opcao_pelo_mei: false,
        codigo_municipio_ibge: 4200000, municipio: 'CIDADE EXEMPLO', cep: '88000-000', descricao_tipo_de_logradouro: 'RUA',
        logradouro: 'EXEMPLO', numero: '10', complemento: '', bairro: 'CENTRO', uf: 'SC', email: 'CONTATO@EXAMPLE.COM',
      }),
    })) as unknown as typeof fetch;
    expect(await lookupCnpj('00.000.000/0001-91', fetchImpl)).toMatchObject({
      taxId: '00000000000191', legalName: 'OFICINA EXEMPLO LTDA', regime: 'simples', cityCode: '4200000',
      address: { postalCode: '88000000', street: 'RUA EXEMPLO', number: '10', complement: null, district: 'CENTRO', state: 'SC' },
      email: 'contato@example.com',
    });
    expect(await lookupCnpj('123', fetchImpl)).toBeNull();
  });
});
