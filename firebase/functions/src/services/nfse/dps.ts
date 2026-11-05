/**
 * DPS (Declaração de Prestação de Serviço): id, dates and the layout module
 * chosen per environment by `config/nfse.layoutByEnvironment` (spec §5.2), so
 * a new package is switched on without releasing the app.
 */

import { escapeXml, el, plainText } from './layouts/common';
import { NFSE_NAMESPACE, type DpsInput, type DpsLayout, type DpsLayoutId, type NfseEnvironment } from './layouts/types';
import { layoutV20260209 } from './layouts/v20260209';
import { layoutV20261020 } from './layouts/v20261020';

export const LAYOUTS: Record<DpsLayoutId, DpsLayout> = {
  v20260209: layoutV20260209,
  v20261020: layoutV20261020,
};

/** What each environment applies today; config/nfse.layoutByEnvironment overrides it. */
export const DEFAULT_LAYOUT_BY_ENVIRONMENT: Record<NfseEnvironment, DpsLayoutId> = {
  production: 'v20260209',
  test: 'v20261020',
};

export function layoutFor(environment: NfseEnvironment, configured?: Partial<Record<NfseEnvironment, string>> | null): DpsLayout {
  const id = configured?.[environment];
  if (id && id in LAYOUTS) return LAYOUTS[id as DpsLayoutId];
  return LAYOUTS[DEFAULT_LAYOUT_BY_ENVIRONMENT[environment]];
}

/**
 * DPS id: "DPS" + city (7) + 1 (CPF) or 2 (CNPJ) + document (14) + series (5) + number (15).
 * Deterministic, so a resend uses the same id and the government recognizes it.
 */
export function dpsId(cityCode: string, taxId: string, series: string, number: number): string {
  const doc = taxId.replace(/\D/g, '');
  if (!/^\d{7}$/.test(cityCode)) throw new Error('cityCode must have 7 digits');
  if (!/^\d{1,5}$/.test(series)) throw new Error('series must have 1 to 5 digits');
  if (!Number.isInteger(number) || number < 1 || number > 999_999_999_999_999) throw new Error('invalid DPS number');
  return `DPS${cityCode}${doc.length === 14 ? '2' : '1'}${doc.padStart(14, '0')}${series.padStart(5, '0')}${String(number).padStart(15, '0')}`;
}

/** Seconds dhEmi stays behind our clock: the government's clock runs up to ~1 s behind (E0008). */
export const DH_EMI_MARGIN_SECONDS = 5;

/**
 * dhEmi in Brasília (UTC-3, no daylight saving) with the margin, and the
 * competence date. The margin never moves the time to the day before.
 */
export function brasiliaTimestamps(now: Date): { issuedAt: string; competenceDate: string } {
  const local = new Date(now.getTime() - 3 * 3600 * 1000);
  const day = local.toISOString().slice(0, 10);
  let back = new Date(local.getTime() - DH_EMI_MARGIN_SECONDS * 1000);
  if (back.toISOString().slice(0, 10) !== day) back = new Date(`${day}T00:00:00.000Z`);
  return { issuedAt: `${back.toISOString().slice(0, 19)}-03:00`, competenceDate: day };
}

export function buildDps(input: DpsInput, layout: DpsLayout): { id: string; xml: string } {
  const id = dpsId(input.emitter.cityCode, input.emitter.taxId, input.series, input.number);
  return { id, xml: layout.buildDps(input, id) };
}

/** Cancellation reasons of event e101101 (cMotivo). */
export const CANCEL_MOTIVE = {
  issueError: { code: 1, text: 'Erro na emissão da nota fiscal' },
  serviceNotProvided: { code: 2, text: 'Serviço não prestado' },
} as const;

/** Chave de acesso: 8 digits + 1 (CPF) or 2 (CNPJ) + document (14) + 27 digits = 50. */
export const ACCESS_KEY = /^[0-9]{8}(1[0-9]{14}|2[0-9A-Z]{14})[0-9]{27}$/;

export interface CancelEventInput {
  environment: NfseEnvironment;
  appVersion: string;
  accessKey: string;
  authorTaxId: string;
  reason: keyof typeof CANCEL_MOTIVE;
  /** At least 15 characters (TSMotivo); a default per reason is used otherwise. */
  detail?: string | null;
  issuedAt: string;
}

/** pedRegEvento of cancellation (e101101). xDesc is the fixed text of the event (else E1235). */
export function buildCancelEvent(input: CancelEventInput): { id: string; xml: string } {
  if (!ACCESS_KEY.test(input.accessKey)) throw new Error('Malformed accessKey');
  const motive = CANCEL_MOTIVE[input.reason];
  let detail = plainText(input.detail, 255);
  if (detail.length < 15) detail = motive.text;
  const author = input.authorTaxId.replace(/\D/g, '');
  const id = `PRE${input.accessKey}101101`;
  const xml =
    `<pedRegEvento xmlns="${NFSE_NAMESPACE}" versao="1.01"><infPedReg Id="${id}">` +
    el('tpAmb', input.environment === 'production' ? 1 : 2) +
    el('verAplic', plainText(input.appVersion, 20)) +
    el('dhEvento', input.issuedAt) +
    el(author.length === 14 ? 'CNPJAutor' : 'CPFAutor', author) +
    el('chNFSe', input.accessKey) +
    `<e101101><xDesc>${escapeXml('Cancelamento de NFS-e')}</xDesc>${el('cMotivo', motive.code)}${el('xMotivo', detail)}</e101101>` +
    `</infPedReg></pedRegEvento>`;
  return { id, xml };
}
