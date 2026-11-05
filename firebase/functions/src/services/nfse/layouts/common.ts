/**
 * Pieces shared by the DPS layout modules. Rules learned in the spike and in
 * PyNFSeNacional (docs/conhecimento-fiscal.md), each one tied to the code the
 * government answers when it is broken:
 *
 * - prest: only CNPJ, IM (when the registry has it) and regTrib. Name and
 *   address of the emitter are refused (E0121, E0128): the government takes them.
 * - MEI (opSimpNac 2): no regApTribSN (E0162), no tribFed (E0676), indTotTrib 0.
 * - Simples ME/EPP (opSimpNac 3): regApTribSN, tribFed PIS/COFINS CST 08, pTotTribSN (E0712).
 * - No ISS retention (tpRetISSQN 1) and no pAliq (the city's agreement sets it, E0617).
 * - Texts follow TSString: Latin-1 only, no leading/trailing space, no line break.
 */

import type { FiscalAddress } from '../../../models/nfse-direct.types';
import type { DpsInput } from './types';

export function escapeXml(text: string): string {
  return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

const REPLACEMENTS: Record<string, string> = {
  '–': '-', '—': '-', '‘': "'", '’': "'", '“': '"', '”': '"', '…': '...', '•': '-',
};

/** A TSString value: Latin-1 only, single spaces, trimmed, cut to [max]. */
export function plainText(value: string | null | undefined, max: number): string {
  const text = String(value ?? '')
    .normalize('NFC')
    .replace(/[–—‘’“”…•]/g, (c) => REPLACEMENTS[c] ?? '')
    .replace(/[^ -ÿ]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  return text.length > max ? text.slice(0, max).trimEnd() : text;
}

/** A TSStringComQuebraDeLinha value (the description keeps one line per order). */
export function multilineText(value: string | null | undefined, max: number): string {
  const lines = String(value ?? '')
    .split(/\r?\n/)
    .map((line) => plainText(line, max))
    .filter((line) => line.length > 0);
  const text = lines.join('\n');
  return text.length > max ? text.slice(0, max).trimEnd() : text;
}

/** `<tag>value</tag>`, or nothing when the value is empty. */
export function el(tag: string, value: string | number | null | undefined): string {
  if (value === undefined || value === null || value === '') return '';
  return `<${tag}>${typeof value === 'number' ? value : escapeXml(value)}</${tag}>`;
}

export function money(value: number): string {
  return (Math.round(value * 100) / 100).toFixed(2);
}

const digits = (value: string | null | undefined) => String(value ?? '').replace(/\D/g, '');

export function isCompleteAddress(address: FiscalAddress | null | undefined): address is FiscalAddress {
  if (!address) return false;
  return (
    digits(address.postalCode).length === 8 &&
    digits(address.cityCode).length === 7 &&
    plainText(address.street, 255).length > 0 &&
    plainText(address.number, 60).length > 0 &&
    plainText(address.district, 60).length > 0
  );
}

export function prestXml(input: DpsInput): string {
  const { emitter } = input;
  const mei = emitter.regime === 'mei';
  const opSimpNac = mei ? 2 : 3;
  const regApTribSN = mei ? '' : el('regApTribSN', emitter.simplesOption ?? 1);
  return (
    `<prest>${el(emitter.taxId.length === 14 ? 'CNPJ' : 'CPF', emitter.taxId)}` +
    `${el('IM', plainText(emitter.municipalRegistration, 15))}` +
    `<regTrib>${el('opSimpNac', opSimpNac)}${regApTribSN}${el('regEspTrib', 0)}</regTrib></prest>`
  );
}

export function tomaXml(input: DpsInput): string {
  const r = input.recipient;
  if (!r) return '';
  const taxId = digits(r.taxId);
  let end = '';
  if (isCompleteAddress(r.address)) {
    const a = r.address;
    end =
      `<end><endNac>${el('cMun', digits(a.cityCode))}${el('CEP', digits(a.postalCode))}</endNac>` +
      `${el('xLgr', plainText(a.street, 255))}${el('nro', plainText(a.number, 60))}` +
      `${el('xCpl', plainText(a.complement, 156))}${el('xBairro', plainText(a.district, 60))}</end>`;
  }
  const email = plainText(r.email, 80);
  return (
    `<toma>${el(taxId.length === 14 ? 'CNPJ' : 'CPF', taxId)}${el('xNome', plainText(r.legalName, 300))}` +
    `${end}${el('email', /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) ? email : '')}</toma>`
  );
}

export function locPrestXml(input: DpsInput): string {
  return `<locPrest>${el('cLocPrestacao', input.service.cityCode || input.emitter.cityCode)}</locPrest>`;
}

export function infoComplXml(input: DpsInput): string {
  const text = plainText(input.complementaryInfo, 2000);
  return text ? `<infoCompl>${el('xInfComp', text)}</infoCompl>` : '';
}

export function valoresXml(input: DpsInput): string {
  const mei = input.emitter.regime === 'mei';
  const tribFed = mei ? '' : `<tribFed><piscofins>${el('CST', '08')}</piscofins></tribFed>`;
  const totTrib = mei
    ? el('indTotTrib', 0)
    : el('pTotTribSN', money(Math.min(Math.max(input.simplesTaxRate ?? 0, 0), 99.99)));
  return (
    `<valores><vServPrest>${el('vServ', money(input.value))}</vServPrest><trib>` +
    `<tribMun>${el('tribISSQN', 1)}${el('tpRetISSQN', 1)}</tribMun>${tribFed}<totTrib>${totTrib}</totTrib>` +
    `</trib></valores>`
  );
}

/** Head of infDPS up to tpEmit (same in every package so far). */
export function headXml(input: DpsInput): string {
  return (
    el('tpAmb', input.environment === 'production' ? 1 : 2) +
    el('dhEmi', input.issuedAt) +
    el('verAplic', plainText(input.appVersion, 20)) +
    el('serie', input.series) +
    el('nDPS', String(input.number)) +
    el('dCompet', input.competenceDate) +
    el('tpEmit', 1)
  );
}

export function descriptionText(input: DpsInput): string {
  return multilineText(input.service.description, 2000);
}
