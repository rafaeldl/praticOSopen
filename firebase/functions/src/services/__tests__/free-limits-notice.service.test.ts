jest.mock('../firestore.service', () =>
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  require('../../__tests__/helpers/fake-firestore').fakeFirestoreModule(),
);
jest.mock('../notification.service', () => ({ notifyFreeLimitsStarting: jest.fn() }));
jest.mock('../nfse/invoice-email.service', () => ({ sendWithResend: jest.fn() }));

import * as firestoreService from '../firestore.service';
import { FakeFirestore } from '../../__tests__/helpers/fake-firestore';
import { freeLimitsMessage, sendFreeLimitsNotices } from '../free-limits-notice.service';
import { resetPaidPlansCache } from '../plan-limits.service';

const fake = (firestoreService as unknown as { __fake: FakeFirestore }).__fake;

const START = '2026-12-15T03:00:00.000Z';
const NOW = new Date('2026-12-01T13:00:00.000Z'); // 14 days before
const ACTIVE = { ordersMonth: '2026-12', ordersThisMonth: 3, ordersLastMonth: 25 };

function deps() {
  return { push: jest.fn().mockResolvedValue(undefined), email: jest.fn().mockResolvedValue({ id: 'e1' }) };
}

function seedFree(id: string, extra: Record<string, unknown> = {}) {
  fake.seed(`companies/${id}`, {
    name: `Oficina ${id}`,
    country: 'BR',
    owner: { id: `u-${id}`, name: 'Dono', email: `${id}@example.com` },
    subscription: { plan: 'free', status: 'active', usage: ACTIVE },
    ...extra,
  });
}

describe('freeLimitsMessage', () => {
  it('says the day (São Paulo) and the 10 work orders of Free, never the assistant', () => {
    const message = freeLimitsMessage(new Date(START), 'BR', 'Oficina X');
    expect(message.title).toBe('O plano Free muda em 15/12');
    expect(message.body).toContain('10 OS por mês');
    expect(message.text).toContain('Olá, Oficina X.');
    expect(`${message.body} ${message.text}`).not.toMatch(/IA|assistente/);
  });

  it('follows the company country', () => {
    expect(freeLimitsMessage(new Date(START), 'MX').title).toBe('El plan Free cambia el 15/12');
    expect(freeLimitsMessage(new Date(START), 'US').title).toBe('The Free plan changes on December 15');
  });

  it('escapes the company name in the html', () => {
    expect(freeLimitsMessage(new Date(START), 'BR', '<b>A&B</b>').html).toContain('&lt;b&gt;A&amp;B&lt;/b&gt;');
  });
});

describe('sendFreeLimitsNotices', () => {
  beforeEach(() => {
    fake.reset();
    resetPaidPlansCache();
  });

  it('sends nothing until the date is written in config/paidPlans', async () => {
    seedFree('c1');
    const d = deps();
    await expect(sendFreeLimitsNotices(NOW, d)).resolves.toEqual({ checked: 0, sent: 0, errors: 0 });
    fake.seed('config/paidPlans', { enabled: false });
    resetPaidPlansCache();
    await expect(sendFreeLimitsNotices(NOW, d)).resolves.toEqual({ checked: 0, sent: 0, errors: 0 });
    expect(d.push).not.toHaveBeenCalled();
    expect(d.email).not.toHaveBeenCalled();
  });

  it('sends nothing more than 15 days before, nor once the limits started', async () => {
    fake.seed('config/paidPlans', { limitsStartAt: START });
    seedFree('c1');
    const d = deps();
    await sendFreeLimitsNotices(new Date('2026-11-29T00:00:00.000Z'), d);
    await sendFreeLimitsNotices(new Date('2026-12-16T00:00:00.000Z'), d);
    expect(d.push).not.toHaveBeenCalled();
  });

  it('in the window: push and e-mail once to the Free companies in use', async () => {
    fake.seed('config/paidPlans', { limitsStartAt: START });
    seedFree('c1');
    seedFree('idle', { subscription: { plan: 'free', usage: { ordersMonth: '2026-12', ordersThisMonth: 0, ordersLastMonth: 0 } } });
    seedFree('pro', { subscription: { plan: 'pro', status: 'active', tableVersion: '2', usage: ACTIVE } });
    seedFree('expired', { subscription: { plan: 'pro', source: 'grace', expiresAt: '2026-11-30T00:00:00.000Z', usage: ACTIVE } });
    const d = deps();

    await expect(sendFreeLimitsNotices(NOW, d)).resolves.toEqual({ checked: 2, sent: 2, errors: 0 });
    expect(d.push.mock.calls.map((call) => call[0]).sort()).toEqual(['c1', 'expired']);
    expect(d.email).toHaveBeenCalledTimes(2);
    const email = d.email.mock.calls.find((call) => call[0].to === 'c1@example.com')![0];
    expect(email).toMatchObject({ subject: 'O plano Free do PraticOS muda em 15/12', idempotencyKey: `free-limits-c1-${START}` });
    expect(fake.read('companies/c1/settings/freeLimitsNotice')).toEqual({ startsAt: START, push: true, email: true });

    await expect(sendFreeLimitsNotices(NOW, d)).resolves.toEqual({ checked: 2, sent: 0, errors: 0 });
    expect(d.push).toHaveBeenCalledTimes(2);
  });

  it('a failed e-mail is retried the next day without a second push', async () => {
    fake.seed('config/paidPlans', { limitsStartAt: START });
    seedFree('c1');
    const d = deps();
    d.email.mockRejectedValueOnce(new Error('down'));

    await expect(sendFreeLimitsNotices(NOW, d)).resolves.toMatchObject({ sent: 0, errors: 1 });
    await expect(sendFreeLimitsNotices(NOW, d)).resolves.toMatchObject({ sent: 1, errors: 0 });
    expect(d.push).toHaveBeenCalledTimes(1);
    expect(d.email).toHaveBeenCalledTimes(2);
  });

  it('reads the owner e-mail from users/{id} when the company has none; no address sends no e-mail', async () => {
    fake.seed('config/paidPlans', { limitsStartAt: START });
    seedFree('c1', { owner: { id: 'u1', name: 'Dono' } });
    fake.seed('users/u1', { email: 'dono@example.com' });
    seedFree('c2', { owner: { id: 'u2', name: 'Sem e-mail' } });
    const d = deps();

    await sendFreeLimitsNotices(NOW, d);

    expect(d.email.mock.calls.map((call) => call[0].to)).toEqual(['dono@example.com']);
    expect(fake.read('companies/c2/settings/freeLimitsNotice')).toMatchObject({ push: true, email: true });
  });

  it('a new date is a new notice', async () => {
    fake.seed('config/paidPlans', { limitsStartAt: START });
    seedFree('c1');
    const d = deps();
    await sendFreeLimitsNotices(NOW, d);
    fake.seed('config/paidPlans', { limitsStartAt: '2026-12-10T03:00:00.000Z' });
    resetPaidPlansCache();
    await sendFreeLimitsNotices(NOW, d);
    expect(d.push).toHaveBeenCalledTimes(2);
  });
});
