/**
 * HTTP client of the national system (Sefin and ADN) with mTLS: the emitter's
 * key and chain (PEM, from the vault) go into an https.Agent made for one
 * call and dropped afterwards. Response parsing follows PyNFSeNacional
 * (`erros`/`erro`, upper/lower-case fields).
 *
 * The transport is injectable: tests never reach the government.
 */

import https from 'node:https';
import { gunzipSync, gzipSync } from 'node:zlib';
import type { NfseEnvironment } from './layouts/types';

export const SEFIN_URL: Record<NfseEnvironment, string> = {
  production: 'https://sefin.nfse.gov.br/SefinNacional',
  test: 'https://sefin.producaorestrita.nfse.gov.br/SefinNacional',
};

export const ADN_URL: Record<NfseEnvironment, string> = {
  production: 'https://adn.nfse.gov.br',
  test: 'https://adn.producaorestrita.nfse.gov.br',
};

export interface HttpResponse {
  status: number;
  body: string;
}

export interface HttpRequest {
  method: 'GET' | 'POST' | 'HEAD';
  url: string;
  body?: unknown;
  keyPem: string;
  chainPem: string;
  timeoutMs: number;
}

export type Transport = (request: HttpRequest) => Promise<HttpResponse>;

/** Thrown when there is no clear answer (timeout, network, 5xx): the request may have arrived. */
export class SefinUnavailableError extends Error {
  constructor(readonly status: number | null, message: string) {
    super(message);
    this.name = 'SefinUnavailableError';
  }
}

export const httpsTransport: Transport = (request) =>
  new Promise((resolve, reject) => {
    const agent = new https.Agent({ key: request.keyPem, cert: request.chainPem, keepAlive: false });
    const payload = request.body === undefined ? undefined : JSON.stringify(request.body);
    const req = https.request(
      new URL(request.url),
      {
        method: request.method,
        agent,
        timeout: request.timeoutMs,
        headers: {
          Accept: 'application/json',
          ...(payload ? { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(payload) } : {}),
        },
      },
      (res) => {
        const chunks: Buffer[] = [];
        res.on('data', (chunk: Buffer) => chunks.push(chunk));
        res.on('end', () => {
          agent.destroy();
          resolve({ status: res.statusCode ?? 0, body: Buffer.concat(chunks).toString('utf8') });
        });
      },
    );
    req.on('timeout', () => req.destroy(new Error('timeout')));
    req.on('error', (error) => {
      agent.destroy();
      reject(error);
    });
    if (payload) req.write(payload);
    req.end();
  });

export interface GovMessage {
  code: string | null;
  text: string | null;
}

/** All error messages of a response, whatever the casing the government used. */
export function govErrors(data: Record<string, unknown>): GovMessage[] {
  let raw = (data.erros ?? data.Erros ?? data.erro ?? data.Erro ?? []) as unknown;
  if (raw && !Array.isArray(raw)) raw = [raw];
  return (raw as Array<Record<string, unknown>>)
    .filter((e) => e && typeof e === 'object')
    .map((e) => {
      const text = [e.descricao ?? e.Descricao ?? e.mensagem ?? e.Mensagem, e.complemento ?? e.Complemento]
        .filter((part) => typeof part === 'string' && part.trim())
        .join(' — ');
      const code = e.codigo ?? e.Codigo;
      return { code: typeof code === 'string' ? code : null, text: text || null };
    });
}

export const gzipBase64 = (xml: string) => gzipSync(Buffer.from(xml, 'utf8')).toString('base64');
export const gunzipBase64 = (b64: string) => gunzipSync(Buffer.from(b64, 'base64')).toString('utf8');

export function xmlTag(xml: string, name: string): string | null {
  const match = xml.match(new RegExp(`<${name}[^>]*>([^<]*)</${name}>`));
  return match ? match[1].trim() || null : null;
}

export type IssueResult =
  | { kind: 'issued'; accessKey: string; nfseXml: string; number: string | null; alerts: string[] }
  | { kind: 'refused'; errors: GovMessage[]; status: number };

export type EventResult =
  | { kind: 'registered'; eventXml: string }
  | { kind: 'refused'; errors: GovMessage[]; status: number };

function parseJson(response: HttpResponse): Record<string, unknown> | null {
  try {
    const data = JSON.parse(response.body);
    return data && typeof data === 'object' ? (data as Record<string, unknown>) : null;
  } catch {
    return null;
  }
}

function unavailable(status: number | null, context: string): SefinUnavailableError {
  return new SefinUnavailableError(status, `${context} (${status ?? 'no answer'})`);
}

export interface SefinClientOptions {
  environment: NfseEnvironment;
  keyPem: string;
  chainPem: string;
  transport?: Transport;
  timeoutMs?: number;
}

export class SefinClient {
  private readonly transport: Transport;
  private readonly timeoutMs: number;

  constructor(private readonly options: SefinClientOptions) {
    this.transport = options.transport ?? httpsTransport;
    this.timeoutMs = options.timeoutMs ?? 30_000;
  }

  private async call(method: HttpRequest['method'], url: string, body?: unknown): Promise<HttpResponse> {
    try {
      return await this.transport({
        method,
        url,
        body,
        keyPem: this.options.keyPem,
        chainPem: this.options.chainPem,
        timeoutMs: this.timeoutMs,
      });
    } catch (error) {
      throw unavailable(null, `${method} ${new URL(url).pathname} failed: ${(error as Error)?.message ?? 'error'}`);
    }
  }

  private sefin(path: string) {
    return `${SEFIN_URL[this.options.environment]}/${path}`;
  }

  /** POST /nfse. A refusal (E-codes) is an answer; anything unclear throws SefinUnavailableError. */
  async issue(signedDps: string): Promise<IssueResult> {
    const response = await this.call('POST', this.sefin('nfse'), { dpsXmlGZipB64: gzipBase64(signedDps) });
    const data = parseJson(response);
    if (!data) throw unavailable(response.status, 'POST /nfse answered without JSON');
    const errors = govErrors(data);
    if (errors.length > 0 && response.status < 500) return { kind: 'refused', errors, status: response.status };
    const b64 = data.nfseXmlGZipB64;
    if (typeof b64 !== 'string' || !b64) throw unavailable(response.status, 'POST /nfse answered without the nota');
    const nfseXml = gunzipBase64(b64);
    const accessKey = (typeof data.chaveAcesso === 'string' && data.chaveAcesso) || xmlTag(nfseXml, 'chNFSe');
    if (!accessKey) throw unavailable(response.status, 'POST /nfse answered without the access key');
    const alerts = ((data.alertas ?? data.Alertas ?? []) as Array<Record<string, unknown>>)
      .map((a) => String(a?.descricao ?? a?.Descricao ?? a?.mensagem ?? ''))
      .filter(Boolean);
    return { kind: 'issued', accessKey: accessKey.replace(/^NFS/, ''), nfseXml, number: xmlTag(nfseXml, 'nNFSe'), alerts };
  }

  /** GET /dps/{id}: the access key when this DPS already became a nota; null when it did not (404). */
  async accessKeyOfDps(id: string): Promise<string | null> {
    const response = await this.call('GET', this.sefin(`dps/${id}`));
    if (response.status === 404) return null;
    if (response.status !== 200) throw unavailable(response.status, 'GET /dps failed');
    const key = parseJson(response)?.chaveAcesso;
    if (typeof key !== 'string' || !key) throw unavailable(response.status, 'GET /dps answered without the access key');
    return key.replace(/^NFS/, '');
  }

  /** GET /nfse/{key}: the nota's XML; null when the key does not exist. */
  async nfseXml(accessKey: string): Promise<string | null> {
    const response = await this.call('GET', this.sefin(`nfse/${accessKey}`));
    if (response.status === 404) return null;
    if (response.status !== 200) throw unavailable(response.status, 'GET /nfse failed');
    const b64 = parseJson(response)?.nfseXmlGZipB64;
    if (typeof b64 !== 'string' || !b64) throw unavailable(response.status, 'GET /nfse answered without the nota');
    return gunzipBase64(b64);
  }

  /** POST /nfse/{key}/eventos (cancellation). */
  async registerEvent(accessKey: string, signedEvent: string): Promise<EventResult> {
    const response = await this.call('POST', this.sefin(`nfse/${accessKey}/eventos`), {
      pedidoRegistroEventoXmlGZipB64: gzipBase64(signedEvent),
    });
    const data = parseJson(response);
    if (!data) throw unavailable(response.status, 'POST /eventos answered without JSON');
    const errors = govErrors(data);
    if (errors.length > 0 && response.status < 500) return { kind: 'refused', errors, status: response.status };
    const b64 = data.eventoXmlGZipB64;
    if (typeof b64 !== 'string' || !b64) throw unavailable(response.status, 'POST /eventos answered without the event');
    return { kind: 'registered', eventXml: gunzipBase64(b64) };
  }

  /** GET on the ADN (registry, city parameters, DF-e mailbox). Returns the parsed JSON, or null on 404. */
  async adn(path: string): Promise<Record<string, unknown> | null> {
    const response = await this.call('GET', `${ADN_URL[this.options.environment]}/${path}`);
    if (response.status === 404) return null;
    if (response.status !== 200) throw unavailable(response.status, `GET ADN ${path.split('?')[0]} failed`);
    const data = parseJson(response);
    if (!data) throw unavailable(response.status, 'ADN answered without JSON');
    return data;
  }
}
