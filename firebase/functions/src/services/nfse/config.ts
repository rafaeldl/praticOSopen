/**
 * Server configuration of the direct engine: `config/nfse` (server-only, no
 * client rule). Read on each call, so a change applies without a deploy.
 *
 *   environment          'production' (default) | 'test' (Produção Restrita)
 *   layoutByEnvironment  { production: 'v20260209', test: 'v20261020' }
 *   meiAnnualLimit       81000
 */

import { db } from '../firestore.service';
import type { DpsLayoutId, NfseEnvironment } from './layouts/types';
import { DEFAULT_MEI_ANNUAL_LIMIT } from './totals';

export interface NfseServerConfig {
  environment: NfseEnvironment;
  layoutByEnvironment: Partial<Record<NfseEnvironment, DpsLayoutId>>;
  meiAnnualLimit: number;
  /** verAplic, at most 20 characters. */
  appVersion: string;
}

export const NFSE_APP_VERSION = `PraticOS-${(process.env.APP_VERSION || '1').slice(0, 11)}`;

export async function getNfseServerConfig(): Promise<NfseServerConfig> {
  const data = (await db.collection('config').doc('nfse').get()).data() ?? {};
  const limit = Number(data.meiAnnualLimit);
  return {
    environment: data.environment === 'test' ? 'test' : 'production',
    layoutByEnvironment: (data.layoutByEnvironment ?? {}) as NfseServerConfig['layoutByEnvironment'],
    meiAnnualLimit: Number.isFinite(limit) && limit > 0 ? limit : DEFAULT_MEI_ANNUAL_LIMIT,
    appVersion: NFSE_APP_VERSION,
  };
}
