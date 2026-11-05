/**
 * What the owner edits about the NFS-e direct (issue #565, spec §4.1 and §4.7):
 * the emitter's lines (municipal registration, default service, description
 * style) and settings/nfse (default emitter, "Emitir sozinha quando concluir
 * a OS"). The emitter and settings/nfse are written only by the server, so the
 * app saves through these functions. Owner and admin only (checked by the route).
 */

import { db } from '../firestore.service';
import type {
  FiscalDescriptionStyle,
  FiscalEmitter,
  FiscalEmitterService,
  NfseDirectAutoIssue,
} from '../../models/nfse-direct.types';
import { NfseServiceError } from './errors';
import { assertDirectEnabled } from './issue.service';

const companyRef = (companyId: string) => db.collection('companies').doc(companyId);
const emitterRef = (companyId: string, emitterId: string) => companyRef(companyId).collection('fiscalEmitters').doc(emitterId);

/** Separators the description style may use (the app offers the same list). */
export const DESCRIPTION_SEPARATORS = [', ', ' - ', ' / ', '; '] as const;

export interface EmitterUpdate {
  /** Empty string or null removes it. */
  municipalRegistration?: string | null;
  service?: FiscalEmitterService | null;
  descriptionStyle?: FiscalDescriptionStyle | null;
}

export interface NfseSettingsUpdate {
  defaultEmitterId?: string;
  autoIssue?: NfseDirectAutoIssue;
}

/** Saves the fields given; the others stay. Returns the emitter as saved. */
export async function updateEmitter(companyId: string, emitterId: string, update: EmitterUpdate): Promise<FiscalEmitter> {
  await assertDirectEnabled(companyId);
  const ref = emitterRef(companyId, emitterId);
  const snap = await ref.get();
  if (!snap.exists) throw new NfseServiceError('EMITTER_NOT_FOUND', 'Emitter not found');

  const changes: Record<string, unknown> = { updatedAt: new Date().toISOString() };
  if ('municipalRegistration' in update) {
    const value = update.municipalRegistration?.trim();
    changes.municipalRegistration = value ? value : null;
  }
  if ('service' in update) {
    const service = update.service;
    changes.service = service
      ? {
          nationalCode: service.nationalCode,
          municipalCode: service.municipalCode?.trim() || null,
          nbs: service.nbs?.trim() || null,
          name: service.name.trim(),
          issRate: service.issRate,
          simplesTaxRate: service.simplesTaxRate ?? null,
        }
      : null;
  }
  if ('descriptionStyle' in update) changes.descriptionStyle = update.descriptionStyle ?? null;

  await ref.set(changes, { merge: true });
  const saved = await ref.get();
  return { ...(saved.data() as FiscalEmitter), id: emitterId };
}

/** Saves settings/nfse; the default emitter must be one of the company's. */
export async function updateNfseSettings(companyId: string, update: NfseSettingsUpdate): Promise<NfseSettingsUpdate> {
  await assertDirectEnabled(companyId);
  const changes: Record<string, unknown> = { updatedAt: new Date().toISOString() };
  if (update.defaultEmitterId !== undefined) {
    const emitter = await emitterRef(companyId, update.defaultEmitterId).get();
    if (!emitter.exists) throw new NfseServiceError('EMITTER_NOT_FOUND', 'Emitter not found');
    changes.defaultEmitterId = update.defaultEmitterId;
  }
  if (update.autoIssue !== undefined) changes.autoIssue = update.autoIssue;
  const ref = companyRef(companyId).collection('settings').doc('nfse');
  await ref.set(changes, { merge: true });
  const saved = (await ref.get()).data() ?? {};
  return { defaultEmitterId: saved.defaultEmitterId, autoIssue: saved.autoIssue };
}
