jest.mock('../firestore.service', () =>
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  require('../../__tests__/helpers/fake-firestore').fakeFirestoreModule(),
);
jest.mock('../notification.service', () => ({ notifyCourtesyEnding: jest.fn() }));

import * as firestoreService from '../firestore.service';
import { FakeFirestore } from '../../__tests__/helpers/fake-firestore';
import { courtesyMessage, sendCourtesyNotices } from '../courtesy-notice.service';
import { dueCourtesyNotice, PLAN_LIMITS } from '../subscription-plans';
import { resetPaidPlansCache } from '../plan-limits.service';
import type { Subscription } from '../../models/types';

const fake = (firestoreService as unknown as { __fake: FakeFirestore }).__fake;

const END = '2026-12-07T12:00:00.000Z';
const daysBefore = (days: number) => new Date(Date.parse(END) - days * 24 * 60 * 60 * 1000);

const grace = (overrides: Partial<Subscription> = {}): Subscription => ({
  plan: 'pro',
  status: 'active',
  source: 'grace',
  store: null,
  expiresAt: END,
  limits: PLAN_LIMITS.pro,
  usage: { photosThisMonth: 0, formTemplatesActive: 0, usersActive: 1, usageResetAt: '2026-12-01T00:00:00.000Z' },
  ...overrides,
});

describe('dueCourtesyNotice', () => {
  it('owes nothing before 15 days', () => {
    expect(dueCourtesyNotice(grace(), daysBefore(16))).toBeNull();
  });

  it('owes the 15-day notice, then nothing until 3 days', () => {
    expect(dueCourtesyNotice(grace(), daysBefore(15))).toEqual({ step: 15, daysLeft: 15 });
    const last = { expiresAt: END, days: 15 };
    expect(dueCourtesyNotice(grace(), daysBefore(14), last)).toBeNull();
    expect(dueCourtesyNotice(grace(), daysBefore(4), last)).toBeNull();
    expect(dueCourtesyNotice(grace(), daysBefore(3), last)).toEqual({ step: 3, daysLeft: 3 });
  });

  it('never repeats the 3-day notice', () => {
    expect(dueCourtesyNotice(grace(), daysBefore(2), { expiresAt: END, days: 3 })).toBeNull();
  });

  it('starts over when the date moves', () => {
    const moved = grace({ expiresAt: '2026-12-28T12:00:00.000Z' });
    const last = { expiresAt: END, days: 3 };
    expect(dueCourtesyNotice(moved, new Date('2026-12-13T12:00:00.000Z'), last)).toEqual({ step: 15, daysLeft: 15 });
  });

  it('tells the days really left when a notice goes out late', () => {
    expect(dueCourtesyNotice(grace(), daysBefore(13))).toEqual({ step: 15, daysLeft: 13 });
  });

  it('owes nothing outside a running courtesy', () => {
    expect(dueCourtesyNotice(grace({ source: 'store' }), daysBefore(3))).toBeNull();
    expect(dueCourtesyNotice(grace(), new Date('2026-12-08T12:00:00.000Z'))).toBeNull();
    expect(dueCourtesyNotice(undefined, daysBefore(3))).toBeNull();
  });
});

describe('courtesyMessage', () => {
  it('quotes the work orders of the month against Free', () => {
    expect(courtesyMessage(15, 23, 'BR').body).toBe('Neste mês você abriu 23 OS. No Free são 10 por mês. Escolha seu plano no app.');
  });

  it('never mentions the assistant: its ceilings are internal', () => {
    for (const orders of [0, 23]) {
      for (const country of ['BR', 'US', 'MX']) {
        expect(courtesyMessage(3, orders, country).body).not.toMatch(/assistente|assistant|asistente/);
      }
    }
    expect(courtesyMessage(3, 0, 'BR').body).toBe('Depois disso, o app volta para o plano Free. Escolha seu plano no app.');
  });

  it('speaks in the singular', () => {
    expect(courtesyMessage(1, 1, 'BR').title).toBe('Sua cortesia do Pro acaba em 1 dia');
    expect(courtesyMessage(1, 1, 'BR').body).toContain('abriu 1 OS');
    expect(courtesyMessage(1, 1, 'US').body).toContain('1 work order this month');
    expect(courtesyMessage(1, 1, 'MX').body).toContain('1 orden este mes');
    expect(courtesyMessage(1, 1, 'MX').title).toBe('Tu cortesía Pro termina en 1 día');
  });

  it('follows the company country, with pt as default', () => {
    expect(courtesyMessage(3, 0, 'PT').title).toBe('Sua cortesia do Pro acaba em 3 dias');
    expect(courtesyMessage(3, 0, 'DE').title).toBe('Your Pro courtesy ends in 3 days');
    expect(courtesyMessage(3, 0, undefined).title).toBe('Sua cortesia do Pro acaba em 3 dias');
    expect(courtesyMessage(3, 0, 'US').title).toBe('Your Pro courtesy ends in 3 days');
    expect(courtesyMessage(3, 0, 'MX').title).toBe('Tu cortesía Pro termina en 3 días');
  });
});

describe('sendCourtesyNotices', () => {
  beforeEach(() => {
    fake.reset();
    resetPaidPlansCache();
  });

  it('leaves the subscription map alone', async () => {
    fake.seed('companies/c1', { subscription: grace() });
    await sendCourtesyNotices(daysBefore(15), { notify: jest.fn() });
    const company = await firestoreService.db.collection('companies').doc('c1').get();
    expect(company.get('subscription')).toEqual(grace());
  });

  it('notifies due companies once and records it', async () => {
    fake.seed('companies/c1', { country: 'BR', subscription: grace() });
    fake.seed('companies/c2', { subscription: grace({ source: 'store' }) });
    const notify = jest.fn().mockResolvedValue(undefined);
    const deps = { notify };

    await expect(sendCourtesyNotices(daysBefore(15), deps)).resolves.toEqual({ sent: 1, errors: 0 });
    expect(notify).toHaveBeenCalledTimes(1);
    expect(notify.mock.calls[0][0]).toBe('c1');

    await expect(sendCourtesyNotices(daysBefore(15), deps)).resolves.toEqual({ sent: 0, errors: 0 });
    expect(notify).toHaveBeenCalledTimes(1);
  });

  it('limits on: quotes the work orders the server counted this month', async () => {
    const usage = { ...grace().usage, ordersMonth: '2026-11', ordersThisMonth: 23 };
    fake.seed('config/paidPlans', { enabled: true });
    fake.seed('companies/c1', { country: 'BR', subscription: grace({ usage }) });
    const notify = jest.fn().mockResolvedValue(undefined);

    await sendCourtesyNotices(daysBefore(15), { notify });

    expect(notify.mock.calls[0][1].body).toContain('abriu 23 OS');
  });

  it('limits off: Free has no order limit, so no number is said', async () => {
    const usage = { ...grace().usage, ordersMonth: '2026-11', ordersThisMonth: 23 };
    fake.seed('companies/c1', { country: 'BR', subscription: grace({ usage }) });
    const notify = jest.fn().mockResolvedValue(undefined);

    await sendCourtesyNotices(daysBefore(15), { notify });

    const body = notify.mock.calls[0][1].body as string;
    expect(body).toBe('Depois disso, o app volta para o plano Free. Escolha seu plano no app.');
    expect(body).not.toMatch(/\d/);
  });

  it('quotes the days really left and records the step', async () => {
    fake.seed('companies/c1', { subscription: grace() });
    const notify = jest.fn().mockResolvedValue(undefined);

    await sendCourtesyNotices(daysBefore(13), { notify });

    expect(notify.mock.calls[0][1].title).toBe('Sua cortesia do Pro acaba em 13 dias');
    await expect(sendCourtesyNotices(daysBefore(12), { notify })).resolves.toEqual({
      sent: 0,
      errors: 0,
    });
  });

  it('retries a company that failed on the next run', async () => {
    fake.seed('companies/c1', { subscription: grace() });
    const deps = { notify: jest.fn().mockRejectedValueOnce(new Error('boom')).mockResolvedValue(undefined) };

    await expect(sendCourtesyNotices(daysBefore(15), deps)).resolves.toEqual({ sent: 0, errors: 1 });
    await expect(sendCourtesyNotices(daysBefore(15), deps)).resolves.toEqual({ sent: 1, errors: 0 });
  });
});
