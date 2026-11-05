import { explainRefusal, refusalLog } from '../refusals';
import { govErrors, gzipBase64, SefinClient, SefinUnavailableError, type HttpRequest, type HttpResponse } from '../sefin-client';

// Recorded shapes of the government's answers (synthetic values).
const NFSE_XML =
  '<NFSe xmlns="http://www.sped.fazenda.gov.br/nfse"><infNFSe Id="NFS42000002200000000000191222222222222222222222222222"><nNFSe>29</nNFSe></infNFSe></NFSe>';
const KEY = `42000002200000000000191${'2'.repeat(27)}`;

function clientWith(answer: (req: HttpRequest) => HttpResponse | Promise<HttpResponse>) {
  const calls: HttpRequest[] = [];
  const client = new SefinClient({
    environment: 'test',
    keyPem: 'KEY',
    chainPem: 'CHAIN',
    transport: async (req) => {
      calls.push(req);
      return answer(req);
    },
  });
  return { client, calls };
}

const json = (status: number, body: unknown): HttpResponse => ({ status, body: JSON.stringify(body) });

describe('SefinClient.issue', () => {
  it('sends the DPS gzip+base64 with the certificate and reads the nota', async () => {
    const { client, calls } = clientWith(() =>
      json(201, { tipoAmbiente: 2, idDps: 'DPS1', chaveAcesso: KEY, nfseXmlGZipB64: gzipBase64(NFSE_XML), alertas: null }),
    );
    const result = await client.issue('<DPS/>');
    expect(result).toEqual({ kind: 'issued', accessKey: KEY, nfseXml: NFSE_XML, number: '29', alerts: [] });
    expect(calls[0]).toMatchObject({ method: 'POST', url: 'https://sefin.producaorestrita.nfse.gov.br/SefinNacional/nfse', keyPem: 'KEY', chainPem: 'CHAIN' });
    expect(calls[0].body).toEqual({ dpsXmlGZipB64: gzipBase64('<DPS/>') });
  });

  it('a refusal with E-codes is an answer', async () => {
    const { client } = clientWith(() => json(400, { erros: [{ Codigo: 'E0312', Descricao: 'Código não administrado', Complemento: 'x' }] }));
    expect(await client.issue('<DPS/>')).toEqual({
      kind: 'refused',
      status: 400,
      errors: [{ code: 'E0312', text: 'Código não administrado — x' }],
    });
  });

  it.each([
    ['timeout', () => Promise.reject(new Error('timeout'))],
    ['5xx', () => json(503, { erros: [{ codigo: 'X', descricao: 'fora' }] })],
    ['HTML', () => ({ status: 502, body: '<html>bad gateway</html>' })],
    ['200 without the nota', () => json(200, {})],
  ])('%s is "no clear answer"', async (_label, answer) => {
    const { client } = clientWith(answer as () => HttpResponse);
    await expect(client.issue('<DPS/>')).rejects.toBeInstanceOf(SefinUnavailableError);
  });
});

describe('SefinClient lookups', () => {
  it('GET /dps: 404 is "never became a nota", 200 gives the key', async () => {
    const { client } = clientWith((req) => (req.url.endsWith('/dps/A') ? json(200, { chaveAcesso: `NFS${KEY}` }) : json(404, {})));
    expect(await client.accessKeyOfDps('A')).toBe(KEY);
    expect(await client.accessKeyOfDps('B')).toBeNull();
  });

  it('GET /dps with another status cannot say "does not exist"', async () => {
    const { client } = clientWith(() => json(500, {}));
    await expect(client.accessKeyOfDps('A')).rejects.toBeInstanceOf(SefinUnavailableError);
  });

  it('cancellation event: registered or refused', async () => {
    const { client, calls } = clientWith(() => json(201, { eventoXmlGZipB64: gzipBase64('<evento/>') }));
    expect(await client.registerEvent(KEY, '<pedRegEvento/>')).toEqual({ kind: 'registered', eventXml: '<evento/>' });
    expect(calls[0].url).toBe(`https://sefin.producaorestrita.nfse.gov.br/SefinNacional/nfse/${KEY}/eventos`);
    const refused = clientWith(() => json(400, { erro: { codigo: 'E0840', descricao: 'Prazo de cancelamento encerrado' } }));
    expect(await refused.client.registerEvent(KEY, '<x/>')).toMatchObject({ kind: 'refused', errors: [{ code: 'E0840' }] });
  });

  it('ADN goes to the ADN host', async () => {
    const { client, calls } = clientWith(() => json(200, { ok: true }));
    expect(await client.adn('parametrizacao/4200000/convenio')).toEqual({ ok: true });
    expect(calls[0].url).toBe('https://adn.producaorestrita.nfse.gov.br/parametrizacao/4200000/convenio');
  });
});

describe('govErrors', () => {
  it('accepts erros, erro (single object) and both casings', () => {
    expect(govErrors({ erro: { codigo: 'E1', mensagem: 'a' } })).toEqual([{ code: 'E1', text: 'a' }]);
    expect(govErrors({ Erros: [{ Codigo: 'E2', Descricao: 'b' }] })).toEqual([{ code: 'E2', text: 'b' }]);
    expect(govErrors({})).toEqual([]);
  });
});

describe('explainRefusal', () => {
  it('groups known codes so the sheet knows what to open', () => {
    expect(explainRefusal([{ code: 'E0240', text: 'CEP' }]).group).toBe('customerData');
    expect(explainRefusal([{ code: 'E0116', text: 'IM' }]).group).toBe('emitterSetup');
    expect(explainRefusal([{ code: 'E0718', text: 'cert' }]).group).toBe('certificate');
  });

  it('prefers the first code it knows', () => {
    const refusal = explainRefusal([{ code: 'E9999', text: 'novo' }, { code: 'E0312', text: 'serviço' }]);
    expect(refusal.code).toBe('E0312');
    expect(refusal.message.pt).toMatch(/serviço/);
    expect(refusal.message.en).toBeTruthy();
    expect(refusal.message.es).toBeTruthy();
  });

  it('unknown codes show the government text, cut to 200', () => {
    const refusal = explainRefusal([{ code: 'E9999', text: 'x'.repeat(300) }]);
    expect(refusal.group).toBe('other');
    expect(refusal.govText).toHaveLength(200);
    expect(refusal.message.pt.startsWith('O governo recusou a nota: ')).toBe(true);
  });

  it('403 without a code is the certificate', () => {
    expect(explainRefusal([], 403).group).toBe('certificate');
  });

  it('log line has codes and texts only', () => {
    expect(refusalLog([{ code: 'E0312', text: 'a' }, { code: null, text: null }])).toBe('E0312: a | ?: ');
  });
});
