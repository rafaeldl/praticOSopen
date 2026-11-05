jest.mock('../../firestore.service', () => jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock);
jest.mock('../../notification.service', () => ({ notifyOwnerOfInvoiceAction: jest.fn(async () => undefined) }));

import { resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
import { notifyOwnerOfInvoiceAction } from '../../notification.service';
import { NfseServiceError } from '../errors';
import { assertMayIssue, invoiceActionMessage, noticeOwnerIfTeamMember } from '../issue-permissions.service';
import { DEFAULT_DAILY_ISSUE_LIMIT, reserveDailySlot } from '../issue.service';

const notify = notifyOwnerOfInvoiceAction as jest.Mock;

async function codeOf(promise: Promise<unknown>) {
  try {
    await promise;
  } catch (error) {
    return (error as NfseServiceError).code;
  }
  return undefined;
}

beforeEach(() => {
  resetFakeDb();
  notify.mockClear();
  seed('companies/c1', { owner: { id: 'owner1', name: 'Dona' }, country: 'BR' });
});

describe('assertMayIssue', () => {
  it('owner, admin and manager issue; the others do not', async () => {
    for (const role of ['owner', 'admin', 'manager']) expect(await codeOf(assertMayIssue('c1', role))).toBeUndefined();
    for (const role of ['supervisor', 'consultant', 'technician', undefined]) {
      expect(await codeOf(assertMayIssue('c1', role))).toBe('FORBIDDEN');
    }
  });

  it('the owner can turn the manager off, and only the manager', async () => {
    seed('companies/c1/settings/nfse', { managerCanIssue: false });
    expect(await codeOf(assertMayIssue('c1', 'manager'))).toBe('FORBIDDEN');
    expect(await codeOf(assertMayIssue('c1', 'admin'))).toBeUndefined();
    expect(await codeOf(assertMayIssue('c1', 'owner'))).toBeUndefined();
  });
});

describe('noticeOwnerIfTeamMember', () => {
  it('tells the owner when someone else issues, with who, to whom and the value', async () => {
    expect(
      await noticeOwnerIfTeamMember('c1', { action: 'issued', invoiceId: 'nf1', by: { id: 'u2', name: 'Gerente' }, value: 150, customerName: 'Loja Centro' }),
    ).toBe(true);
    expect(notify).toHaveBeenCalledWith('c1', expect.objectContaining({ invoiceId: 'nf1', action: 'issued', title: 'Nota fiscal emitida' }));
    const body = notify.mock.calls[0][1].body as string;
    expect(body).toContain('Gerente emitiu uma nota fiscal para Loja Centro');
    expect(body).toMatch(/R\$\s?150,00/);
  });

  it('says nothing when the owner did it', async () => {
    expect(await noticeOwnerIfTeamMember('c1', { action: 'canceled', invoiceId: 'nf1', by: { id: 'owner1', name: 'Dona' } })).toBe(false);
    expect(notify).not.toHaveBeenCalled();
  });

  it('a failed notice never fails the nota', async () => {
    notify.mockRejectedValueOnce(new Error('push down'));
    const spy = jest.spyOn(console, 'error').mockImplementation(() => undefined);
    expect(await noticeOwnerIfTeamMember('c1', { action: 'issued', invoiceId: 'nf1', by: { id: 'u2', name: 'G' } })).toBe(false);
    spy.mockRestore();
  });

  it('cancel text in the three languages', () => {
    const notice = { action: 'canceled' as const, invoiceId: 'nf1', by: { id: 'u2', name: 'Ana' } };
    expect(invoiceActionMessage(notice, 'BR').body).toBe('Ana cancelou uma nota fiscal.');
    expect(invoiceActionMessage(notice, 'AR').title).toBe('Factura cancelada');
    expect(invoiceActionMessage(notice, 'US').body).toBe('Ana canceled an invoice.');
  });
});

describe('reserveDailySlot (daily ceiling per emitter)', () => {
  it('counts per day and stops at the ceiling', () => {
    expect(reserveDailySlot(undefined, '2026-11-05')).toBe(1);
    expect(reserveDailySlot({ issuedOn: '2026-11-05', issuedToday: 3 }, '2026-11-05')).toBe(4);
    // A new day starts over.
    expect(reserveDailySlot({ issuedOn: '2026-11-04', issuedToday: DEFAULT_DAILY_ISSUE_LIMIT }, '2026-11-05')).toBe(1);
    expect(() => reserveDailySlot({ issuedOn: '2026-11-05', issuedToday: DEFAULT_DAILY_ISSUE_LIMIT }, '2026-11-05')).toThrow(
      expect.objectContaining({ code: 'DAILY_LIMIT_REACHED' }),
    );
  });

  it('honors a ceiling set by hand for the emitter, capped', () => {
    expect(() => reserveDailySlot({ issuedOn: '2026-11-05', issuedToday: 5, dailyIssueLimit: 5 }, '2026-11-05')).toThrow();
    expect(reserveDailySlot({ issuedOn: '2026-11-05', issuedToday: 500, dailyIssueLimit: 5000 }, '2026-11-05')).toBe(501);
  });
});
