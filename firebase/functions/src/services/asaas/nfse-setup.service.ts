/**
 * NFS-e setup of a company (docs/NFSE_ASAAS.md): the fiscal info kept in
 * Asaas (GET/POST /v3/fiscalInfo) and the default service of the notas kept
 * in companies/{cid}/settings/nfse. City credentials (digital certificate,
 * password, token) are sent in the Asaas panel, never through PraticOS.
 */

import { UserAggr } from '../../models/types';
import {
  AsaasFiscalInfo,
  AsaasMunicipalOptions,
  AsaasMunicipalService,
  AsaasSaveFiscalInfoInput,
  InvoiceTaxes,
  NfseAutoIssue,
  NfseServiceSettings,
} from '../../models/asaas.types';
import { getAsaasCredentialProvider } from './credential-provider';
import { AsaasServiceError } from './errors';
import { paymentSettingsRef } from './connection.service';
import {
  accountStampOf,
  assertNfseEnabled,
  getNfseServiceSettings,
  isSameAccount,
  nfseSettingsRef,
  DEFAULT_DESCRIPTION_TEMPLATE,
} from './invoice.service';

/** What is still missing before notas can be issued. */
export type NfseMissingItem = 'fiscalInfo' | 'cityAccess' | 'service';

export interface NfseSetupStatus {
  ready: boolean;
  missing: NfseMissingItem[];
  fiscalInfo: AsaasFiscalInfo | null;
  /** City rules (null when Asaas could not tell, e.g. no fiscal info yet). */
  municipalOptions: AsaasMunicipalOptions | null;
  service: NfseServiceSettings | null;
}

/** Whether the city access the municipality requires was sent in the Asaas panel. */
export function hasCityAccess(info: AsaasFiscalInfo | null, options: AsaasMunicipalOptions | null): boolean {
  if (!info) return false;
  switch (options?.authenticationType) {
    case 'CERTIFICATE':
      return info.certificateSent === true;
    case 'TOKEN':
      return info.accessTokenSent === true;
    case 'USER_AND_PASSWORD':
      return info.passwordSent === true;
    default:
      return true;
  }
}

export function missingItems(
  info: AsaasFiscalInfo | null,
  options: AsaasMunicipalOptions | null,
  service: NfseServiceSettings | null,
): NfseMissingItem[] {
  const missing: NfseMissingItem[] = [];
  if (!info) missing.push('fiscalInfo');
  else if (!hasCityAccess(info, options)) missing.push('cityAccess');
  if (!service) missing.push('service');
  return missing;
}

async function storeReady(companyId: string, ready: boolean): Promise<void> {
  await paymentSettingsRef(companyId).set({ nfseReady: ready }, { merge: true });
}

export async function getNfseSetup(companyId: string): Promise<NfseSetupStatus> {
  const { connection } = await assertNfseEnabled(companyId);
  const client = await getAsaasCredentialProvider().getClient(companyId);
  const [fiscalInfo, saved] = await Promise.all([client.getFiscalInfo(), getNfseServiceSettings(companyId)]);
  // A service saved on another Asaas account (or before the account stamp) is set up again.
  const service = saved && isSameAccount(saved, connection) ? saved : null;
  // Municipal options depend on the account address; tolerate failures here.
  const municipalOptions = await client.getMunicipalOptions().catch(() => null);
  const missing = missingItems(fiscalInfo, municipalOptions, service);
  const ready = missing.length === 0;
  await storeReady(companyId, ready);
  return { ready, missing, fiscalInfo, municipalOptions, service };
}

export async function saveFiscalInfo(companyId: string, input: AsaasSaveFiscalInfoInput): Promise<NfseSetupStatus> {
  await assertNfseEnabled(companyId);
  const client = await getAsaasCredentialProvider().getClient(companyId);
  await client.saveFiscalInfo(input);
  console.log(`[NFS-e] Fiscal info saved for company ${companyId}`);
  return getNfseSetup(companyId);
}

export async function searchMunicipalServices(companyId: string, description?: string): Promise<AsaasMunicipalService[]> {
  await assertNfseEnabled(companyId);
  const client = await getAsaasCredentialProvider().getClient(companyId);
  return client.listMunicipalServices(description?.trim() || undefined);
}

export interface SaveServiceInput {
  municipalServiceId?: string | null;
  municipalServiceCode?: string | null;
  municipalServiceName: string;
  taxes: InvoiceTaxes;
  descriptionTemplate?: string;
  /** Absent: keeps the saved choice ('manual' when none). */
  autoIssue?: NfseAutoIssue;
}

export async function saveNfseService(
  companyId: string,
  input: SaveServiceInput,
  user: UserAggr,
): Promise<NfseSetupStatus> {
  const { connection } = await assertNfseEnabled(companyId);
  const id = input.municipalServiceId?.trim() || null;
  const code = input.municipalServiceCode?.trim() || null;
  if (!id && !code) {
    throw new AsaasServiceError('INVALID_FISCAL_INFO', 'Pick a municipal service or type its code');
  }
  const settings: NfseServiceSettings = {
    municipalServiceId: id,
    municipalServiceCode: id ? null : code,
    municipalServiceName: input.municipalServiceName.trim(),
    taxes: input.taxes,
    descriptionTemplate: input.descriptionTemplate?.trim() || DEFAULT_DESCRIPTION_TEMPLATE,
    autoIssue: input.autoIssue ?? (await getNfseServiceSettings(companyId))?.autoIssue ?? 'manual',
    ...accountStampOf(connection),
    updatedAt: new Date().toISOString(),
    updatedBy: { id: user.id, name: user.name },
  };
  await nfseSettingsRef(companyId).set(settings);
  return getNfseSetup(companyId);
}
