/**
 * Reads the NFS-e XML returned by the government and turns it into the text
 * of each DANFSe field (NT 008/2026, item 2.4.5). Only what is in the XML is
 * printed (item 2.1); a missing field becomes "-" (note 12).
 */

import { DOMParser } from '@xmldom/xmldom';
import {
  AMB_GER,
  C_STAT,
  FIN_NFSE,
  OP_SIMP_NAC,
  REG_AP_TRIB_SN,
  REG_ESP_TRIB,
  TP_AMB,
  TP_BM,
  TP_EMIT,
  TP_IMUNIDADE,
  TP_RET_ISSQN,
  TP_RET_PIS_COFINS,
  TP_SUSP,
  TRIB_ISSQN,
  UF_BY_IBGE_PREFIX,
  describe,
} from './labels';

export const EMPTY = '-';

/** Names of cities the XML gives only as an IBGE code (prestador, tomador...). */
export type CityNames = Record<string, string>;

export interface DanfseParty {
  taxId: string;
  municipalRegistration: string;
  phone: string;
  name: string;
  city: string;
  cityCodeAndPostalCode: string;
  address: string;
  email: string;
}

export interface DanfseData {
  accessKey: string;
  testEnvironment: boolean;
  header: { city: string | null; generator: string; environment: string };
  identification: {
    number: string;
    competence: string;
    issuedAt: string;
    dpsNumber: string;
    dpsSeries: string;
    dpsIssuedAt: string;
    emitter: string;
    situation: string;
    purpose: string;
  };
  provider: DanfseParty & { simplesNacional: string; simplesRegime: string };
  /** null: "não identificado na NFS-e". */
  taker: DanfseParty | null;
  /** 'taker': the recipient is the taker itself; null: not identified. */
  recipient: DanfseParty | 'taker' | null;
  intermediary: DanfseParty | null;
  service: { codes: string; nbs: string; place: string; codeDescription: string; description: string };
  /** null: operation not subject to ISSQN. */
  municipalTax: {
    taxation: string;
    incidence: string;
    specialRegime: string;
    immunity: string;
    suspension: string;
    suspensionProcess: string;
    /** false: the benefit row has no data at all and may be dropped (note 5). */
    hasBenefitRow: boolean;
    benefit: string;
    benefitCalc: string;
    deductions: string;
    unconditionalDiscount: string;
    base: string;
    rate: string;
    withholding: string;
    issqn: string;
  } | null;
  federalTax: {
    irrf: string;
    socialSecurity: string;
    socialContributions: string;
    /** PIS/COFINS row: only for competence up to 2026 (note 6). */
    showPisCofinsRow: boolean;
    pis: string;
    cofins: string;
    contributionsDescription: string;
  };
  ibsCbs: {
    cstClass: string;
    incidence: string;
    exclusions: string;
    base: string;
    rateReductions: string;
    ibsRates: string;
    ibsMunEffective: string;
    ibsMunValue: string;
    ibsUfEffective: string;
    ibsUfValue: string;
    ibsTotal: string;
    cbsRate: string;
    cbsEffective: string;
    cbsTotal: string;
  };
  totals: {
    serviceValue: string;
    unconditionalDiscount: string;
    conditionalDiscount: string;
    withholdings: string;
    netValue: string;
    ibsCbsTotal: string;
    netPlusIbsCbs: string;
  };
  complementaryInfo: string;
}

// ----------------------------------------------------------------------------
// XML helpers (namespace-agnostic, by local name)
// ----------------------------------------------------------------------------

type Node = Element | null;

function child(node: Node, name: string): Node {
  if (!node) return null;
  for (let c = node.firstChild; c; c = c.nextSibling) {
    if (c.nodeType === 1 && (c as Element).localName === name) return c as Element;
  }
  return null;
}

function at(node: Node, path: string): Node {
  return path.split('/').reduce<Node>((n, part) => child(n, part), node);
}

function text(node: Node, path: string): string | null {
  const found = at(node, path);
  const value = found?.textContent?.trim();
  return value ? value : null;
}

// ----------------------------------------------------------------------------
// Formatting (pt-BR, as printed in the national DANFSe)
// ----------------------------------------------------------------------------

const MONEY = new Intl.NumberFormat('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

function num(value: string | null): number | null {
  if (value == null) return null;
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

export function moneyText(value: number | null): string {
  return value == null ? EMPTY : `R$ ${MONEY.format(value)}`;
}

function percentText(value: string | null): string {
  const n = num(value);
  return n == null ? EMPTY : `${MONEY.format(n)}%`;
}

/** "2026-11-05T14:30:00-03:00" → "05/11/2026 14:30:00" (time as written). */
export function dateTimeText(value: string | null): string {
  const m = value?.match(/^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2})(?::(\d{2}))?)?/);
  if (!m) return value ?? EMPTY;
  const date = `${m[3]}/${m[2]}/${m[1]}`;
  return m[4] ? `${date} ${m[4]}:${m[5]}:${m[6] ?? '00'}` : date;
}

export function taxIdText(value: string | null): string {
  if (!value) return EMPTY;
  const d = value.replace(/\D/g, '');
  if (d.length === 14) return d.replace(/^(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})$/, '$1.$2.$3/$4-$5');
  if (d.length === 11) return d.replace(/^(\d{3})(\d{3})(\d{3})(\d{2})$/, '$1.$2.$3-$4');
  return value;
}

function postalCodeText(value: string | null): string | null {
  if (!value) return null;
  const d = value.replace(/\D/g, '');
  return d.length === 8 ? d.replace(/^(\d{2})(\d{3})(\d{3})$/, '$1.$2-$3') : value;
}

export function ufOf(cityCode: string | null): string | null {
  return cityCode ? UF_BY_IBGE_PREFIX[cityCode.slice(0, 2)] ?? null : null;
}

function joinParts(parts: Array<string | null | undefined>, separator: string): string | null {
  const kept = parts.filter((p): p is string => !!p);
  return kept.length ? kept.join(separator) : null;
}

function or(value: string | null | undefined): string {
  return value ? value : EMPTY;
}

// ----------------------------------------------------------------------------
// Parties
// ----------------------------------------------------------------------------

function party(node: Node, cities: CityNames, fallback?: Node): DanfseParty | null {
  if (!node && !fallback) return null;
  const pick = (path: string) => text(node, path) ?? text(fallback ?? null, path);
  const end = at(node, 'end') ?? at(fallback ?? null, 'enderNac') ?? at(fallback ?? null, 'end');
  const nac = at(end, 'endNac');
  const ext = at(end, 'endExt');
  // NFS-e "emit" keeps the address flat (enderNac with cMun/UF/CEP).
  const cityCode = text(nac, 'cMun') ?? text(end, 'cMun');
  const uf = text(end, 'UF') ?? ufOf(cityCode);
  const cityName = cityCode ? cities[cityCode] ?? null : text(ext, 'xCidade');
  const postal = postalCodeText(text(nac, 'CEP') ?? text(end, 'CEP')) ?? text(ext, 'cEndPost');
  const taxId = pick('CNPJ') ?? pick('CPF') ?? pick('NIF');
  return {
    taxId: taxIdText(taxId),
    municipalRegistration: or(pick('IM')),
    phone: or(pick('fone')),
    name: or(pick('xNome')),
    city: or(joinParts([cityName, ext ? text(ext, 'cPais') : uf], ' / ')),
    cityCodeAndPostalCode: or(joinParts([cityCode, postal], ' / ')),
    address: or(joinParts([text(end, 'xLgr'), text(end, 'nro'), text(end, 'xCpl'), text(end, 'xBairro')], ', ')),
    email: or(pick('email')),
  };
}

// ----------------------------------------------------------------------------
// Main
// ----------------------------------------------------------------------------

export function parseNfseXml(xml: string, cities: CityNames = {}): DanfseData {
  const doc = new DOMParser().parseFromString(xml, 'text/xml');
  const root = doc.documentElement;
  const inf = root?.localName === 'infNFSe' ? root : child(root, 'infNFSe');
  if (!inf) throw new Error('Not an NFS-e XML (no infNFSe)');
  const dps = at(inf, 'DPS/infDPS');
  const emit = child(inf, 'emit');
  const values = child(inf, 'valores');
  const dpsValues = at(dps, 'valores');
  const trib = at(dpsValues, 'trib');
  const tribMun = at(trib, 'tribMun');
  const tribFed = at(trib, 'tribFed');
  const pisCofins = at(tribFed, 'piscofins');
  const ibsCbs = at(inf, 'IBSCBS');
  const dpsIbsCbs = at(dps, 'IBSCBS');
  const serv = at(dps, 'serv');

  const accessKey = (inf.getAttribute('Id') ?? '').replace(/^NFS/, '');
  const tpAmb = text(dps, 'tpAmb');
  const emitCity = text(emit, 'enderNac/cMun');
  if (emitCity && !cities[emitCity] && text(inf, 'xLocEmi')) cities = { ...cities, [emitCity]: text(inf, 'xLocEmi')! };

  const prest = child(dps, 'prest');
  const regTrib = at(prest, 'regTrib');
  const tpEmit = text(dps, 'tpEmit');
  // When the provider is the emitter, its name and address come in "emit".
  const providerParty = party(prest, cities, tpEmit === '1' || !tpEmit ? emit : null)!;

  const taker = party(child(dps, 'toma'), cities);
  const destNode = at(dpsIbsCbs, 'dest');
  const recipient = destNode ? party(destNode, cities) : taker ? 'taker' : null;

  // Service
  const tribNac = text(serv, 'cServ/cTribNac');
  const tribMunCode = text(serv, 'cServ/cTribMun');
  const nbs = text(serv, 'cServ/cNBS');
  const placeCode = text(serv, 'locPrest/cLocPrestacao');
  const codes = joinParts(
    [tribNac ? tribNac.replace(/^(\d{2})(\d{2})(\d{2})$/, '$1.$2.$3') : null, tribMunCode],
    ' / ',
  );
  const service = {
    codes: or(codes),
    nbs: or(nbs ? nbs.replace(/^(\d)(\d{4})(\d{2})(\d{2})$/, '$1.$2.$3.$4') : null),
    place: or(
      joinParts([text(inf, 'xLocPrestacao'), ufOf(placeCode), placeCode ? 'BR' : text(serv, 'locPrest/cPaisPrestacao')], ' / '),
    ),
    codeDescription: or(text(inf, 'xTribMun') ?? text(inf, 'xTribNac')),
    description: or(text(serv, 'cServ/xDescServ')),
  };

  // Municipal tax (ISSQN)
  const incidenceCode = text(inf, 'cLocIncid');
  const benefitType = text(values, 'tpBM');
  const benefitCalc = num(text(values, 'vCalcBM')) ?? num(text(tribMun, 'BM/vRedBCBM'));
  const deductions = num(text(dpsValues, 'vDedRed/vDR')) ?? num(text(values, 'vCalcDR'));
  const unconditional = num(text(dpsValues, 'vDescCondIncond/vDescIncond'));
  const municipalTax = tribMun
    ? {
        taxation: or(describe(TRIB_ISSQN, text(tribMun, 'tribISSQN'))),
        incidence: or(joinParts([text(inf, 'xLocIncid'), ufOf(incidenceCode), text(tribMun, 'cPaisResult') ?? (incidenceCode ? 'BR' : null)], ' / ')),
        specialRegime: or(describe(REG_ESP_TRIB, text(regTrib, 'regEspTrib'))),
        immunity: or(describe(TP_IMUNIDADE, text(tribMun, 'tpImunidade'))),
        suspension: or(describe(TP_SUSP, text(tribMun, 'exigSusp/tpSusp'))),
        suspensionProcess: or(text(tribMun, 'exigSusp/nProcesso')),
        hasBenefitRow: benefitType != null || benefitCalc != null || deductions != null || unconditional != null,
        benefit: or(describe(TP_BM, benefitType)),
        benefitCalc: moneyText(benefitCalc),
        deductions: moneyText(deductions),
        unconditionalDiscount: moneyText(unconditional),
        base: moneyText(num(text(values, 'vBC'))),
        rate: percentText(text(values, 'pAliqAplic')),
        withholding: or(describe(TP_RET_ISSQN, text(tribMun, 'tpRetISSQN'))),
        issqn: moneyText(num(text(values, 'vISSQN'))),
      }
    : null;

  // Federal tax (except CBS)
  const tpRetPisCofins = text(pisCofins, 'tpRetPisCofins');
  const vPis = num(text(pisCofins, 'vPis'));
  const vCofins = num(text(pisCofins, 'vCofins'));
  const vRetCsll = num(text(tribFed, 'vRetCSLL'));
  const pisRetained = tpRetPisCofins === '1';
  const competence = text(dps, 'dCompet');
  const federalTax = {
    irrf: moneyText(num(text(tribFed, 'vRetIRRF'))),
    socialSecurity: moneyText(num(text(tribFed, 'vRetCP'))),
    socialContributions: moneyText(
      pisRetained ? (vRetCsll ?? 0) + (vPis ?? 0) + (vCofins ?? 0) : vRetCsll,
    ),
    showPisCofinsRow: !competence || Number(competence.slice(0, 4)) <= 2026,
    pis: pisRetained ? moneyText(0) : moneyText(vPis),
    cofins: pisRetained ? moneyText(0) : moneyText(vCofins),
    contributionsDescription: or(describe(TP_RET_PIS_COFINS, tpRetPisCofins)),
  };

  // IBS/CBS (reform; empty in notas before the 2027 layout)
  const ibsValues = at(ibsCbs, 'valores');
  const totCibs = at(ibsCbs, 'totCIBS');
  const gIbsCbs = at(dpsIbsCbs, 'valores/trib/gIBSCBS');
  const ibsTot = num(text(totCibs, 'gIBS/vIBSTot'));
  const cbsTot = num(text(totCibs, 'gCBS/vCBS'));
  const percents = (...values: Array<string | null>) => (values.some((v) => v != null) ? values.map((v) => percentText(v)).join(' / ') : EMPTY);
  const ibsIncidenceCode = text(ibsCbs, 'cLocalidadeIncid');
  const exclusionParts = [
    num(text(dpsValues, 'vDescCondIncond/vDescIncond')),
    num(text(ibsValues, 'vCalcReeRepRes')),
    num(text(values, 'vISSQN')),
    num(text(pisCofins, 'vPis')),
    num(text(pisCofins, 'vCofins')),
  ];
  const ibs = {
    cstClass: or(joinParts([text(gIbsCbs, 'CST'), text(gIbsCbs, 'cClassTrib')], ' / ')),
    incidence: or(joinParts([text(dpsIbsCbs, 'cIndOp'), ibsIncidenceCode, text(ibsCbs, 'xLocalidadeIncid'), ufOf(ibsIncidenceCode)], ' / ')),
    exclusions: ibsCbs ? moneyText(exclusionParts.reduce<number>((sum, v) => sum + (v ?? 0), 0)) : EMPTY,
    base: moneyText(num(text(ibsValues, 'vBC'))),
    rateReductions: percents(text(ibsValues, 'uf/pRedAliqUF'), text(ibsValues, 'mun/pRedAliqMun'), text(ibsValues, 'fed/pRedAliqCBS')),
    ibsRates: percents(text(ibsValues, 'uf/pIBSUF'), text(ibsValues, 'mun/pIBSMun')),
    ibsMunEffective: percentText(text(ibsValues, 'mun/pAliqEfetMun')),
    ibsMunValue: moneyText(num(text(totCibs, 'gIBS/gIBSMunTot/vIBSMun'))),
    ibsUfEffective: percentText(text(ibsValues, 'uf/pAliqEfetUF')),
    ibsUfValue: moneyText(num(text(totCibs, 'gIBS/gIBSUFTot/vIBSUF'))),
    ibsTotal: moneyText(ibsTot),
    cbsRate: percentText(text(ibsValues, 'fed/pCBS')),
    cbsEffective: percentText(text(ibsValues, 'fed/pAliqEfetCBS')),
    cbsTotal: moneyText(cbsTot),
  };

  const totals = {
    serviceValue: moneyText(num(text(dpsValues, 'vServPrest/vServ'))),
    unconditionalDiscount: moneyText(unconditional),
    conditionalDiscount: moneyText(num(text(dpsValues, 'vDescCondIncond/vDescCond'))),
    withholdings: moneyText(num(text(values, 'vTotalRet'))),
    netValue: moneyText(num(text(values, 'vLiq'))),
    ibsCbsTotal: ibsTot != null || cbsTot != null ? moneyText((ibsTot ?? 0) + (cbsTot ?? 0)) : EMPTY,
    netPlusIbsCbs: moneyText(num(text(totCibs, 'vTotNF'))),
  };

  return {
    accessKey,
    testEnvironment: tpAmb === '2',
    header: {
      city: joinParts([text(inf, 'xLocEmi'), text(emit, 'enderNac/UF') ?? ufOf(emitCity)], ' / '),
      generator: or(describe(AMB_GER, text(inf, 'ambGer'))),
      environment: or(describe(TP_AMB, tpAmb)),
    },
    identification: {
      number: or(text(inf, 'nNFSe')),
      competence: competence ? dateTimeText(competence) : EMPTY,
      issuedAt: dateTimeText(text(inf, 'dhProc')),
      dpsNumber: or(text(dps, 'nDPS')),
      dpsSeries: or(text(dps, 'serie')),
      dpsIssuedAt: dateTimeText(text(dps, 'dhEmi')),
      emitter: or(describe(TP_EMIT, tpEmit)),
      situation: or(describe(C_STAT, text(inf, 'cStat'))),
      purpose: or(describe(FIN_NFSE, text(dpsIbsCbs, 'finNFSe') ?? text(dps, 'finNFSe'))),
    },
    provider: {
      ...providerParty,
      simplesNacional: or(describe(OP_SIMP_NAC, text(regTrib, 'opSimpNac'))),
      simplesRegime: or(describe(REG_AP_TRIB_SN, text(regTrib, 'regApTribSN'))),
    },
    taker,
    recipient,
    intermediary: party(child(dps, 'interm'), cities),
    service,
    municipalTax,
    federalTax,
    ibsCbs: ibs,
    totals,
    complementaryInfo: complementaryInfo(inf, dps, serv, trib),
  };
}

/** Item 2.4.5, "Informações Complementares": fixed order, joined by pipes. */
function complementaryInfo(inf: Node, dps: Node, serv: Node, trib: Node): string {
  const parts: string[] = [];
  const add = (label: string, value: string | null) => {
    if (value) parts.push(`${label} ${value}`);
  };
  add('Inf. Cont.:', text(serv, 'infoCompl/xInfComp'));
  add('NFS-e Subst.:', text(dps, 'subst/chSubstda'));
  add('Doc. Ref.:', text(serv, 'infoCompl/docRef'));
  add('Cod. Obra:', text(serv, 'obra/cObra'));
  add('Insc. Imob.:', text(serv, 'obra/inscImobFisc') ?? text(dps, 'IBSCBS/imovel/inscImobFisc'));
  add('Cod. Evt.:', text(serv, 'atvEvento/idAtvEvt'));
  add('Doc. Tec.:', text(serv, 'infoCompl/idDocTec'));
  add('Núm. Ped.:', text(serv, 'infoCompl/xPed'));
  add('Item Ped.:', joinParts(itemsOf(at(serv, 'infoCompl/gItemPed')), ', '));
  add('Inf. A. T. Mun.:', text(inf, 'xOutInf'));
  parts.push(approximateTaxes(at(trib, 'totTrib')));
  return parts.join(' | ');
}

function itemsOf(node: Node): string[] {
  const items: string[] = [];
  for (let c = node?.firstChild; c; c = c.nextSibling) {
    if (c.nodeType === 1 && (c as Element).localName === 'xItemPed' && c.textContent) items.push(c.textContent.trim());
  }
  return items;
}

/** Note 10: mandatory line, in money or percent, as the XML has it. */
function approximateTaxes(totTrib: Node): string {
  const prefix = 'Totais Aproximados dos Tributos cfe. Lei nº 12.741/2012:';
  const money = at(totTrib, 'vTotTrib');
  const percent = at(totTrib, 'pTotTrib');
  if (money) {
    const v = (tag: string) => moneyText(num(text(money, tag)));
    return `${prefix} Federais: ${v('vTotTribFed')}; Estaduais: ${v('vTotTribEst')}; Municipais: ${v('vTotTribMun')}`;
  }
  if (percent) {
    const p = (tag: string) => percentText(text(percent, tag));
    return `${prefix} Federais: ${p('pTotTribFed')}; Estaduais: ${p('pTotTribEst')}; Municipais: ${p('pTotTribMun')}`;
  }
  const sn = text(totTrib, 'pTotTribSN');
  if (sn) return `${prefix} Simples Nacional: ${percentText(sn)}`;
  return `${prefix} Federais: ${EMPTY}; Estaduais: ${EMPTY}; Municipais: ${EMPTY}`;
}
