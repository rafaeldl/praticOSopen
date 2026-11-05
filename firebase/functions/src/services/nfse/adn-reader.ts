/**
 * Reads the emitter's mailbox on the ADN (issue #569, spec §5.6):
 * `GET {adn}/contribuintes/DFe/{NSU}?cnpjConsulta={cnpj}&lote=true`, up to 50
 * documents per page, each a gzip+base64 XML. The mailbox has the notas the
 * CNPJ issued, the ones issued against it (received) and their events.
 *
 * The answer's casing is not documented; this reads `LoteDFe`/`loteDFe` and
 * `NSU`/`Nsu`, like the spike that paged real notas. Whether a page starts at
 * the NSU asked for or after it is not documented either, so the caller asks
 * from the last NSU it kept and drops what it already has (`nsu <= last`).
 *
 * Nothing here is logged: the XMLs carry customer data.
 */

import { DOMParser } from '@xmldom/xmldom';
import { gunzipBase64, type SefinClient } from './sefin-client';
import type { FiscalAddress, FiscalRegime } from '../../models/nfse-direct.types';

export const DFE_PAGE_SIZE = 50;

export type DfeKind = 'nfse' | 'event' | 'other';

export interface DfeDocument {
  nsu: number;
  kind: DfeKind;
  /** Access key without the "NFS" prefix, when the page gives it. */
  accessKey: string | null;
  xml: string;
}

export interface DfePage {
  documents: DfeDocument[];
  /** The mailbox has nothing after these documents. */
  done: boolean;
}

const pick = (item: Record<string, unknown>, ...names: string[]) => {
  for (const name of names) if (item[name] !== undefined && item[name] !== null) return item[name];
  return undefined;
};

function kindOf(type: unknown, xml: string): DfeKind {
  const t = String(type ?? '').toUpperCase();
  if (t === 'NFSE' || /<NFSe[\s>]/.test(xml)) return 'nfse';
  if (t === 'EVENTO' || /<evento[\s>]/.test(xml)) return 'event';
  return 'other';
}

/** Turns one page answer into documents (pure, for tests). */
export function parseDfePage(data: Record<string, unknown> | null): DfePage {
  if (!data) return { documents: [], done: true };
  const list = (pick(data, 'LoteDFe', 'loteDFe', 'lotedfe') ?? []) as Array<Record<string, unknown>>;
  const documents: DfeDocument[] = [];
  for (const item of Array.isArray(list) ? list : []) {
    if (!item || typeof item !== 'object') continue;
    const nsu = Number(pick(item, 'NSU', 'Nsu', 'nsu'));
    const b64 = pick(item, 'ArquivoXml', 'arquivoXml');
    if (!Number.isFinite(nsu) || typeof b64 !== 'string' || !b64) continue;
    let xml: string;
    try {
      xml = gunzipBase64(b64);
    } catch {
      continue;
    }
    const key = pick(item, 'ChaveAcesso', 'chaveAcesso');
    documents.push({
      nsu,
      kind: kindOf(pick(item, 'TipoDocumento', 'tipoDocumento'), xml),
      accessKey: typeof key === 'string' && key ? key.replace(/^NFS/, '') : null,
      xml,
    });
  }
  documents.sort((a, b) => a.nsu - b.nsu);
  return { documents, done: documents.length < DFE_PAGE_SIZE };
}

/** One page of the mailbox from [nsu]. An empty mailbox answers 404 (null): done. */
export async function fetchDfePage(client: SefinClient, taxId: string, nsu: number): Promise<DfePage> {
  const data = await client.adn(`contribuintes/DFe/${Math.max(0, Math.floor(nsu))}?cnpjConsulta=${encodeURIComponent(taxId)}&lote=true`);
  return parseDfePage(data);
}

// ----------------------------------------------------------------------------
// XML of the nota and of its events
// ----------------------------------------------------------------------------

type Node = Element | null;

function child(node: Node, name: string): Node {
  if (!node) return null;
  for (let c = node.firstChild; c; c = c.nextSibling) {
    if (c.nodeType === 1 && (c as Element).localName === name) return c as Element;
  }
  return null;
}

const at = (node: Node, path: string): Node => path.split('/').reduce<Node>((n, part) => child(n, part), node);

function text(node: Node, path: string): string | null {
  const value = at(node, path)?.textContent?.trim();
  return value ? value : null;
}

function root(xml: string, name: string): Element | null {
  try {
    const doc = new DOMParser().parseFromString(xml, 'text/xml');
    const el = doc?.documentElement as unknown as Element | null;
    return el && el.localName === name ? el : null;
  } catch {
    return null;
  }
}

/** The person or company of the nota (emitente or tomador). */
export interface NfseParty {
  /** CNPJ or CPF, digits (letters kept for the alphanumeric CNPJ). */
  taxId: string;
  name: string | null;
  municipalRegistration: string | null;
  address: FiscalAddress | null;
  email: string | null;
  phone: string | null;
}

/** What the import keeps of a nota (issued by the CNPJ or received by it). */
export interface ParsedNfse {
  accessKey: string;
  number: string | null;
  /** cStat: 100 normal; anything else is read from the events. */
  statusCode: string | null;
  /** dhProc, ISO with offset. */
  processedAt: string | null;
  /** dCompet, YYYY-MM-DD. */
  competenceDate: string | null;
  /** Who made it: "EmissorWeb_1.6.0", "SefinNacional_1.6", "PraticOS-1.104.0"... */
  appVersion: string | null;
  cityName: string | null;
  emitter: NfseParty;
  recipient: NfseParty | null;
  regime: FiscalRegime | null;
  /** regApTribSN (Simples only). */
  simplesOption: number | null;
  simplesTaxRate: number | null;
  /** Id of the DPS without the "DPS" prefix (city + type + document + series + number). */
  dpsId: string | null;
  series: string | null;
  dpsNumber: number | null;
  service: {
    nationalCode: string | null;
    municipalCode: string | null;
    nbs: string | null;
    /** xTribNac: the government's name of the code. */
    name: string | null;
    description: string;
    issRate: number | null;
  };
  complementaryInfo: string | null;
  value: number;
}

const taxIdOf = (node: Node) => {
  const raw = text(node, 'CNPJ') ?? text(node, 'CPF');
  return raw ? raw.replace(/[^0-9A-Za-z]/g, '').toUpperCase() : '';
};

function addressOf(node: Node): FiscalAddress | null {
  const end = child(node, 'end') ?? child(node, 'enderNac');
  if (!end) return null;
  const nac = child(end, 'endNac') ?? end;
  const address: FiscalAddress = {
    postalCode: text(nac, 'CEP'),
    street: text(end, 'xLgr'),
    number: text(end, 'nro'),
    complement: text(end, 'xCpl'),
    district: text(end, 'xBairro'),
    cityCode: text(nac, 'cMun'),
    cityName: null,
    state: text(end, 'UF'),
  };
  return Object.values(address).some((v) => v) ? address : null;
}

function partyOf(node: Node): NfseParty | null {
  if (!node) return null;
  const taxId = taxIdOf(node);
  if (!taxId) return null;
  return {
    taxId,
    name: text(node, 'xNome'),
    municipalRegistration: text(node, 'IM'),
    address: addressOf(node),
    email: text(node, 'email')?.toLowerCase() ?? null,
    phone: text(node, 'fone'),
  };
}

const num = (value: string | null) => {
  const n = Number((value ?? '').replace(',', '.'));
  return value !== null && Number.isFinite(n) ? n : null;
};

/** Reads one NFS-e XML; null when it is not one. */
export function parseNfse(xml: string): ParsedNfse | null {
  const nfse = root(xml, 'NFSe');
  const inf = child(nfse, 'infNFSe');
  if (!inf) return null;
  const accessKey = (inf.getAttribute('Id') ?? '').replace(/^NFS/, '');
  const dps = child(child(inf, 'DPS'), 'infDPS');
  const emitter = partyOf(child(inf, 'emit')) ?? partyOf(child(dps, 'prest'));
  if (!accessKey || !emitter) return null;
  // The emitter's IM and contact come from `emit`; the regime from the DPS.
  const prest = child(dps, 'prest');
  const op = text(prest, 'regTrib/opSimpNac');
  const regime: FiscalRegime | null = op === '2' ? 'mei' : op === '3' ? 'simples' : null;
  const serv = child(dps, 'serv');
  const valores = child(dps, 'valores');
  return {
    accessKey,
    number: text(inf, 'nNFSe'),
    statusCode: text(inf, 'cStat'),
    processedAt: text(inf, 'dhProc'),
    competenceDate: text(dps, 'dCompet') ?? text(dps, 'dhEmi')?.slice(0, 10) ?? null,
    appVersion: text(dps, 'verAplic') ?? text(inf, 'verAplic'),
    cityName: text(inf, 'xLocEmi'),
    emitter: { ...emitter, municipalRegistration: emitter.municipalRegistration ?? text(prest, 'IM') },
    recipient: partyOf(child(dps, 'toma')),
    regime,
    simplesOption: num(text(prest, 'regTrib/regApTribSN')),
    simplesTaxRate: num(text(valores, 'trib/totTrib/pTotTribSN')),
    dpsId: dps?.getAttribute('Id')?.replace(/^DPS/, '') || null,
    series: text(dps, 'serie'),
    dpsNumber: num(text(dps, 'nDPS')),
    service: {
      nationalCode: text(serv, 'cServ/cTribNac'),
      municipalCode: text(serv, 'cServ/cTribMun'),
      nbs: text(serv, 'cServ/cNBS'),
      name: text(inf, 'xTribNac'),
      description: text(serv, 'cServ/xDescServ') ?? '',
      issRate: num(text(valores, 'trib/tribMun/pAliq')),
    },
    complementaryInfo: text(serv, 'infoCompl/xInfComp'),
    value: num(text(valores, 'vServPrest/vServ')) ?? num(text(child(inf, 'valores'), 'vLiq')) ?? 0,
  };
}

export interface ParsedEvent {
  accessKey: string;
  /** e101101 (cancel), e105102 (cancel by substitution) or another code. */
  code: string;
  /** The event cancels the nota. */
  cancels: boolean;
  processedAt: string | null;
}

/** Reads one event XML; null when it is not one. */
export function parseEvent(xml: string): ParsedEvent | null {
  const inf = child(root(xml, 'evento'), 'infEvento');
  const req = child(child(inf, 'pedRegEvento'), 'infPedReg');
  const accessKey = text(req, 'chNFSe')?.replace(/^NFS/, '');
  if (!accessKey) return null;
  let code = '';
  for (let c = req?.firstChild; c; c = c.nextSibling) {
    if (c.nodeType === 1 && /^e\d{6}$/.test((c as Element).localName)) code = (c as Element).localName;
  }
  return { accessKey, code, cancels: code === 'e101101' || code === 'e105102', processedAt: text(inf, 'dhProc') };
}
