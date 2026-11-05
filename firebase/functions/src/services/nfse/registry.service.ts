/**
 * Lookups that fill an emitter from its CNPJ (spec §5.6, "Cadastro"):
 * national registry (CNC: municipal registration, enabled to issue), city
 * agreement (is the city on the national issuer), ISS rate of a service, and
 * the public CNPJ API (legal name, regime, city) for emitters and customers.
 * The ADN calls use the emitter's certificate (mTLS); BrasilAPI is public.
 */

import type { FiscalRegime } from '../../models/nfse-direct.types';
import type { SefinClient } from './sefin-client';

export interface CncInfo {
  municipalRegistration: string | null;
  /** SituacaoEmissaoNFSe === 'HABILITADO'. */
  enabledInCity: boolean;
  legalName: string | null;
}

export async function lookupCnc(client: SefinClient, cityCode: string, taxId: string): Promise<CncInfo | null> {
  const data = await client.adn(
    `cnc/consulta/cad?codMunicipio=${encodeURIComponent(cityCode)}&inscricaoFederal=${encodeURIComponent(taxId)}`,
  );
  const list = (data?.ListaCadastroMunicipal ?? []) as Array<Record<string, unknown>>;
  const inf = list.map((item) => item?.InfCad as Record<string, unknown> | undefined).find((item) => item?.Inscricao === taxId);
  if (!inf) return null;
  const im = typeof inf.InscricaoMunicipal === 'string' && inf.InscricaoMunicipal.trim() ? inf.InscricaoMunicipal.trim() : null;
  return {
    municipalRegistration: im,
    enabledInCity: inf.SituacaoEmissaoNFSe === 'HABILITADO',
    legalName: typeof inf.RazaoSocial === 'string' ? inf.RazaoSocial : null,
  };
}

/** The city is on the national issuer (aderenteEmissorNacional). */
export async function cityUsesNationalIssuer(client: SefinClient, cityCode: string): Promise<boolean> {
  const data = await client.adn(`parametrizacao/${encodeURIComponent(cityCode)}/convenio`);
  const params = data?.parametrosConvenio as Record<string, unknown> | undefined;
  return params?.aderenteEmissorNacional === 1;
}

/** "140101" + municipal "001" → "14.01.01.001" (the portal's format). */
export function portalServiceCode(nationalCode: string, municipalCode?: string | null): string {
  const n = nationalCode.replace(/\D/g, '').padStart(6, '0');
  const m = (municipalCode ?? '').replace(/\D/g, '').padStart(3, '0');
  return `${n.slice(0, 2)}.${n.slice(2, 4)}.${n.slice(4, 6)}.${m}`;
}

/** ISS rate (%) in force on [date] (YYYY-MM-DD) for the service, or null. */
export async function issRateOf(
  client: SefinClient,
  cityCode: string,
  nationalCode: string,
  municipalCode: string | null | undefined,
  date: string,
): Promise<number | null> {
  const code = portalServiceCode(nationalCode, municipalCode);
  const data = await client.adn(`parametrizacao/${encodeURIComponent(cityCode)}/${code}/historicoaliquotas`);
  const history = ((data?.aliquotas as Record<string, unknown> | undefined)?.[code] ?? []) as Array<Record<string, unknown>>;
  const inForce = history.find((row) => {
    const start = String(row.DtIni ?? '').slice(0, 10);
    const end = row.DtFim ? String(row.DtFim).slice(0, 10) : null;
    return start <= date && (end === null || date <= end);
  });
  const rate = Number(inForce?.Aliq);
  return Number.isFinite(rate) ? rate : null;
}

export interface CnpjInfo {
  taxId: string;
  legalName: string;
  tradeName: string | null;
  regime: FiscalRegime | null;
  cityCode: string | null;
  cityName: string | null;
  address: {
    postalCode: string | null;
    street: string | null;
    number: string | null;
    complement: string | null;
    district: string | null;
    state: string | null;
  };
  email: string | null;
}

/** BrasilAPI (public, no certificate). Null when the CNPJ does not exist. */
export async function lookupCnpj(taxId: string, fetchImpl: typeof fetch = fetch): Promise<CnpjInfo | null> {
  const cnpj = taxId.replace(/\D/g, '');
  if (cnpj.length !== 14) return null;
  const response = await fetchImpl(`https://brasilapi.com.br/api/cnpj/v1/${cnpj}`, {
    headers: { Accept: 'application/json', 'User-Agent': 'PraticOS' },
    signal: AbortSignal.timeout(10_000),
  });
  if (response.status === 404) return null;
  if (!response.ok) throw new Error(`CNPJ lookup failed (${response.status})`);
  const d = (await response.json()) as Record<string, unknown>;
  const str = (v: unknown) => (typeof v === 'string' && v.trim() ? v.trim() : null);
  const regime: FiscalRegime | null = d.opcao_pelo_mei === true ? 'mei' : d.opcao_pelo_simples === true ? 'simples' : null;
  const ibge = d.codigo_municipio_ibge;
  return {
    taxId: cnpj,
    legalName: str(d.razao_social) ?? '',
    tradeName: str(d.nome_fantasia),
    regime,
    cityCode: ibge ? String(ibge) : null,
    cityName: str(d.municipio),
    address: {
      postalCode: str(d.cep)?.replace(/\D/g, '') ?? null,
      street: [str(d.descricao_tipo_de_logradouro), str(d.logradouro)].filter(Boolean).join(' ') || null,
      number: str(d.numero),
      complement: str(d.complemento),
      district: str(d.bairro),
      state: str(d.uf),
    },
    email: str(d.email)?.toLowerCase() ?? null,
  };
}
