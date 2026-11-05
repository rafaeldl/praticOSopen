jest.mock('../../firestore.service', () => jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock);
jest.mock('../../notification.service', () => ({ notifyCertificateExpiring: jest.fn() }));

import { read, resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
import { NfseServiceError } from '../errors';
import { updateEmitter, updateNfseSettings } from '../emitter-settings.service';
import { certificateMessage, dueCertificateNotice, sendCertificateNotices } from '../certificate-expiry-notice.service';

const SERVICE = { nationalCode: '140101', name: 'Revisão', issRate: 2.5 };

function seedCompany(enabled = true) {
  seed('companies/c1', { country: 'BR' });
  seed('companies/c1/settings/payments', { nfseDirectEnabled: enabled });
  seed('companies/c1/fiscalEmitters/e1', {
    taxId: '00000000000191',
    legalName: 'OFICINA EXEMPLO LTDA',
    regime: 'simples',
    municipalRegistration: '123',
    certificate: { holderName: 'OFICINA EXEMPLO LTDA', notAfter: '2026-12-01T00:00:00.000Z', status: 'active' },
  });
}

beforeEach(() => {
  resetFakeDb();
  seedCompany();
});

describe('updateEmitter', () => {
  it('saves only the fields given and clears an empty registration', async () => {
    const saved = await updateEmitter('c1', 'e1', { service: SERVICE });
    expect(saved.service).toMatchObject({ nationalCode: '140101', name: 'Revisão', issRate: 2.5, municipalCode: null });
    expect(saved.municipalRegistration).toBe('123');

    await updateEmitter('c1', 'e1', { municipalRegistration: '  ' });
    expect(read('companies/c1/fiscalEmitters/e1')?.municipalRegistration).toBeNull();
  });

  it('saves the description style', async () => {
    await updateEmitter('c1', 'e1', { descriptionStyle: { uppercase: true, separator: ' - ' } });
    expect(read('companies/c1/fiscalEmitters/e1')?.descriptionStyle).toEqual({ uppercase: true, separator: ' - ' });
  });

  it('refuses an unknown emitter and a company without the flag', async () => {
    await expect(updateEmitter('c1', 'nope', { service: SERVICE })).rejects.toMatchObject({ code: 'EMITTER_NOT_FOUND' });
    resetFakeDb();
    seedCompany(false);
    await expect(updateEmitter('c1', 'e1', { service: SERVICE })).rejects.toBeInstanceOf(NfseServiceError);
  });
});

describe('updateNfseSettings', () => {
  it('sets the default emitter and the auto issue', async () => {
    const saved = await updateNfseSettings('c1', { defaultEmitterId: 'e1', autoIssue: 'selectedCustomers' });
    expect(saved).toEqual({ defaultEmitterId: 'e1', autoIssue: 'selectedCustomers' });
    expect(read('companies/c1/settings/nfse')).toMatchObject({ defaultEmitterId: 'e1', autoIssue: 'selectedCustomers' });
  });

  it('refuses a default that is not an emitter of the company', async () => {
    await expect(updateNfseSettings('c1', { defaultEmitterId: 'other' })).rejects.toMatchObject({ code: 'EMITTER_NOT_FOUND' });
  });
});

describe('certificate expiry notices', () => {
  const end = '2026-12-01T00:00:00.000Z';

  it('is due at 30 and at 7 days, once each', () => {
    expect(dueCertificateNotice(end, new Date('2026-10-20T00:00:00Z'))).toBeNull();
    expect(dueCertificateNotice(end, new Date('2026-11-05T00:00:00Z'))).toEqual({ step: 30, daysLeft: 26 });
    expect(dueCertificateNotice(end, new Date('2026-11-05T00:00:00Z'), { notAfter: end, days: 30 })).toBeNull();
    expect(dueCertificateNotice(end, new Date('2026-11-26T00:00:00Z'), { notAfter: end, days: 30 })).toEqual({ step: 7, daysLeft: 5 });
    expect(dueCertificateNotice(end, new Date('2026-11-27T00:00:00Z'), { notAfter: end, days: 7 })).toBeNull();
    expect(dueCertificateNotice(end, new Date('2026-12-02T00:00:00Z'))).toBeNull();
  });

  it('starts over with a new certificate', () => {
    expect(dueCertificateNotice(end, new Date('2026-11-05T00:00:00Z'), { notAfter: '2025-12-01T00:00:00.000Z', days: 7 })).toEqual({ step: 30, daysLeft: 26 });
  });

  it('writes the sentence in the company language', () => {
    expect(certificateMessage('OFICINA EXEMPLO', 7, 'e1', 'BR').body).toBe('O certificado da OFICINA EXEMPLO vence em 7 dias. Peça um novo ao contador.');
    expect(certificateMessage('OFICINA EXEMPLO', 1, 'e1', 'US').body).toContain('1 day');
  });

  it('tells the company once and records it', async () => {
    const notify = jest.fn().mockResolvedValue(undefined);
    const now = new Date('2026-11-25T12:00:00Z');
    expect(await sendCertificateNotices('c1', now, { notify })).toEqual({ sent: 1, errors: 0 });
    expect(notify).toHaveBeenCalledWith('c1', expect.objectContaining({ days: 6, emitterId: 'e1' }));
    expect(read('companies/c1/private/nfse/emitters/e1')?.expiryNotice).toEqual({ notAfter: end, days: 7 });
    expect(await sendCertificateNotices('c1', now, { notify })).toEqual({ sent: 0, errors: 0 });
  });

  it('keeps going when one notice fails', async () => {
    const notify = jest.fn().mockRejectedValue(new Error('down'));
    expect(await sendCertificateNotices('c1', new Date('2026-11-25T12:00:00Z'), { notify })).toEqual({ sent: 0, errors: 1 });
    expect(read('companies/c1/private/nfse/emitters/e1')).toBeUndefined();
  });
});
