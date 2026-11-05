/**
 * IBS/CBS group of the DPS (`infDPS/IBSCBS`), required for Simples and MEI
 * from competence 01/01/2027 (Anexo VI v1.04.01, row 373; spec §5.9).
 *
 * The codes come from the government's correlation table (ibscbs-table.ts):
 * the NBS of the service picks cIndOp and cClassTrib; without NBS, the item of
 * the national code (cTribNac 140101 → item 14.01) does, with the pair most
 * of its NBS give.
 * The first option is the usual one (for 14.01, 050101: service done at the
 * emitter's shop; 050102 is "somewhere else"). CST is the first 3 digits of
 * cClassTrib. Nothing is computed here: the government's calculator does the
 * amounts and refuses a wrong code (E0858-E0860, E0901, E0958), which comes
 * back as a normal refusal.
 *
 * Package differences, both validated against the official XSD:
 * - 20260209 (production): finNFSe inside IBSCBS, cIndOp required,
 *   CST/cClassTrib inside trib/gIBSCBS.
 * - 20261020 (Produção Restrita): finNFSe already at infDPS level, cIndOp
 *   optional, CST/cClassTrib directly in trib.
 *
 * Not sent yet: regApIBSCBSSN and cAtvSN (NT 009 §2.4). They are in the
 * annex but in no published XSD; sending them today breaks the schema.
 */

import { el } from './common';
import { IBSCBS_TABLE } from './ibscbs-table';
import type { DpsInput, DpsLayout, DpsLayoutId } from './types';

/** "Demais serviços, em operações onerosas" and "tributação integral": the generic pair. */
export const FALLBACK_OPERATION = '100301';
export const FULL_TAXATION_CLASS = '000001';

export interface IbsCbsCodes {
  /** cIndOp (6 digits). */
  operation: string;
  /** cClassTrib (6 digits). */
  classification: string;
  /** CST (3 digits), the start of cClassTrib. */
  situation: string;
  /** Where the codes came from, for logs and tests. */
  source: 'input' | 'nbs' | 'item' | 'fallback';
}

const onlyDigits = (value: string | null | undefined) => String(value ?? '').replace(/\D/g, '');

/**
 * Item of the correlation table: 140101 → "14.01" (LC 116 list); the new
 * items of IBS/CBS only (99.xx) keep the subitem: 990401 → "99.04.01".
 */
export function itemOf(nationalCode: string): string {
  const d = onlyDigits(nationalCode);
  if (d.length < 4) return '';
  if (d.startsWith('99') && d.length >= 6) return `${d.slice(0, 2)}.${d.slice(2, 4)}.${d.slice(4, 6)}`;
  return `${d.slice(0, 2)}.${d.slice(2, 4)}`;
}

interface Options {
  ops: string[];
  classes: string[];
}

const BY_NBS = new Map<string, Options>();
const BY_ITEM = new Map<string, Options[]>();
for (const [item, nbs, , ops, classes] of IBSCBS_TABLE) {
  const options = { ops: ops.split(' '), classes: classes.split(' ') };
  BY_NBS.set(`${item}|${nbs}`, options);
  if (!BY_NBS.has(nbs)) BY_NBS.set(nbs, options);
  BY_ITEM.set(item, [...(BY_ITEM.get(item) ?? []), options]);
}

const preferredClass = (classes: string[]) => (classes.includes(FULL_TAXATION_CLASS) ? FULL_TAXATION_CLASS : classes[0]);

/** The pair most NBS of the item give (14.01: 050101/000001 in 23 of 25); ties go to the first. */
function itemOptions(item: string): { operation: string; classification: string } | null {
  const all = BY_ITEM.get(item);
  if (!all?.length) return null;
  const count = new Map<string, number>();
  for (const o of all) {
    const key = `${o.ops[0]}|${preferredClass(o.classes)}`;
    count.set(key, (count.get(key) ?? 0) + 1);
  }
  const [best] = [...count.entries()].reduce((a, b) => (b[1] > a[1] ? b : a));
  const [operation, classification] = best.split('|');
  return { operation, classification };
}

export function resolveIbsCbs(input: DpsInput): IbsCbsCodes {
  const s = input.service;
  const done = (operation: string, classification: string, source: IbsCbsCodes['source']): IbsCbsCodes => ({
    operation,
    classification,
    situation: classification.slice(0, 3),
    source,
  });

  const item = itemOf(s.nationalCode);
  const nbs = onlyDigits(s.nbs);
  const fromNbs = nbs ? BY_NBS.get(`${item}|${nbs}`) ?? BY_NBS.get(nbs) : undefined;
  const fromItem = itemOptions(item);

  let operation = fromNbs?.ops[0] ?? fromItem?.operation;
  let classification = fromNbs ? preferredClass(fromNbs.classes) : fromItem?.classification;
  let source: IbsCbsCodes['source'] = fromNbs ? 'nbs' : fromItem ? 'item' : 'fallback';

  const ownOperation = onlyDigits(s.operationIndicator);
  const ownClass = onlyDigits(s.taxClassification);
  if (/^\d{6}$/.test(ownOperation)) [operation, source] = [ownOperation, 'input'];
  if (/^\d{6}$/.test(ownClass)) [classification, source] = [ownClass, 'input'];

  return done(operation ?? FALLBACK_OPERATION, classification ?? FULL_TAXATION_CLASS, source);
}

export type IbsCbsPackage = 'v20260209' | 'v20261020';

/** `<IBSCBS>` for the package; indDest 0: the recipient of the service is the tomador. */
export function ibsCbsXml(input: DpsInput, pkg: IbsCbsPackage): string {
  const c = resolveIbsCbs(input);
  if (pkg === 'v20260209') {
    return (
      `<IBSCBS>${el('finNFSe', 0)}${el('cIndOp', c.operation)}${el('indDest', 0)}` +
      `<valores><trib><gIBSCBS>${el('CST', c.situation)}${el('cClassTrib', c.classification)}</gIBSCBS></trib></valores></IBSCBS>`
    );
  }
  return (
    `<IBSCBS>${el('cIndOp', c.operation)}${el('indDest', 0)}` +
    `<valores><trib>${el('CST', c.situation)}${el('cClassTrib', c.classification)}</trib></valores></IBSCBS>`
  );
}

/** A package's layout plus the IBSCBS group, the last child of infDPS. */
export function withIbsCbs(base: DpsLayout, pkg: IbsCbsPackage, id: DpsLayoutId): DpsLayout {
  const tail = '</infDPS></DPS>';
  return {
    id,
    buildDps(input, dpsId) {
      const xml = base.buildDps(input, dpsId);
      if (!xml.endsWith(tail)) throw new Error(`Layout ${base.id} did not end with ${tail}`);
      return xml.slice(0, -tail.length) + ibsCbsXml(input, pkg) + tail;
    },
  };
}
