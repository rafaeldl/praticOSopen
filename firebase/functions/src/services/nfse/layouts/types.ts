/**
 * What a DPS needs, independent of the layout package. Built by the issue
 * service from the emitter, the recipient and the orders; turned into XML by
 * one module per package (v20260209 in production, v20261020 in the test
 * environment, and from 2027 the same packages with IBS/CBS). Spec §5.2, §5.9.
 */

import type { FiscalAddress, FiscalRegime } from '../../../models/nfse-direct.types';

export type NfseEnvironment = 'production' | 'test';
export type DpsLayoutId = 'v20260209' | 'v20261020' | 'v2027_20260209' | 'v2027_20261020';

export const NFSE_NAMESPACE = 'http://www.sped.fazenda.gov.br/nfse';

export interface DpsInput {
  environment: NfseEnvironment;
  /** dhEmi (already in Brasília, with the 5 s margin) and dCompet. */
  issuedAt: string;
  competenceDate: string;
  /** "PraticOS-{version}", at most 20 characters. */
  appVersion: string;
  series: string;
  number: number;
  emitter: {
    taxId: string;
    cityCode: string;
    /** Only when the national registry has it (E0116 × E0120). */
    municipalRegistration?: string | null;
    regime: FiscalRegime;
    /** regApTribSN of the Simples (1, 2 or 3). */
    simplesOption?: number | null;
  };
  recipient?: {
    taxId: string;
    legalName: string;
    /** Sent only when complete (CEP, street, number, district, city). */
    address?: FiscalAddress | null;
    email?: string | null;
  } | null;
  service: {
    nationalCode: string;
    municipalCode?: string | null;
    nbs?: string | null;
    description: string;
    /** Where the service was provided; defaults to the emitter's city. */
    cityCode?: string | null;
    /** 2027 layout: cIndOp and cClassTrib, when not the ones the correlation table gives. */
    operationIndicator?: string | null;
    taxClassification?: string | null;
  };
  value: number;
  /** pTotTribSN of the Simples (approximate % of taxes). Ignored for MEI. */
  simplesTaxRate?: number | null;
  /** xInfComp ("OS 182 · Emitida pelo PraticOS (praticos.app)"). */
  complementaryInfo?: string | null;
}

export interface DpsLayout {
  id: DpsLayoutId;
  /** The unsigned `<DPS>` element. */
  buildDps(input: DpsInput, dpsId: string): string;
}
