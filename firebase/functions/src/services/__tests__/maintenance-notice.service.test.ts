jest.mock('../firestore.service', () =>
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  require('../../__tests__/helpers/fake-firestore').fakeFirestoreModule(),
);
jest.mock('../notification.service', () => ({ notifyMaintenanceDue: jest.fn(), notifyCourtesyEnding: jest.fn() }));

import * as firestoreService from '../firestore.service';
import { FakeFirestore } from '../../__tests__/helpers/fake-firestore';
import {
  maintenanceMessage,
  maintenanceToday,
  sendMaintenanceNotices,
} from '../maintenance-notice.service';

const fake = (firestoreService as unknown as { __fake: FakeFirestore }).__fake;

// 09:00 in Brazil on 2026-11-02.
const NOW = new Date('2026-11-02T12:00:00.000Z');

const device = (day: string, extra: Record<string, unknown> = {}) => ({
  name: 'Split 12000',
  nextMaintenanceDate: day,
  nextMaintenanceCustomer: { id: 'cu1', name: 'Padaria Central' },
  ...extra,
});

describe('maintenanceToday', () => {
  it('uses the day in Brazil, not in UTC', () => {
    expect(maintenanceToday(new Date('2026-11-03T02:00:00.000Z'))).toBe('2026-11-02');
  });
});

describe('maintenanceMessage', () => {
  const due = (name: string, customer?: string) => ({
    deviceId: name,
    device: name,
    customer,
    day: '2026-11-09',
  });

  it('names the device, the customer and the day', () => {
    expect(maintenanceMessage([due('Split', 'Padaria')], 'BR')).toEqual({
      title: 'Manutenção chegando',
      body: 'Split · Padaria · 09/11/2026',
      count: 1,
    });
  });

  it('leaves out a missing customer', () => {
    expect(maintenanceMessage([due('Split')], 'BR').body).toBe('Split · 09/11/2026');
  });

  it('sums up several, in the language of the company', () => {
    const list = [due('A', 'X'), due('B', 'Y'), due('C', 'Z')];
    expect(maintenanceMessage(list, 'BR').title).toBe('3 manutenções chegando');
    expect(maintenanceMessage(list, 'BR').body).toBe('A · X · 09/11/2026 e mais 2');
    expect(maintenanceMessage(list, 'MX').title).toBe('3 mantenimientos próximos');
    expect(maintenanceMessage(list, 'US').body).toBe('A · X · 11/09/2026 and 2 more');
  });
});

describe('sendMaintenanceNotices', () => {
  let notify: jest.Mock;

  beforeEach(() => {
    fake.reset();
    notify = jest.fn().mockResolvedValue(undefined);
    jest.spyOn(console, 'log').mockImplementation(() => undefined);
    fake.seed('companies/c1', { country: 'BR' });
  });
  afterEach(() => jest.restoreAllMocks());

  it('tells from today to 7 days ahead, nothing outside it', async () => {
    fake.seed('companies/c1/devices/today', device('2026-11-02'));
    fake.seed('companies/c1/devices/week', device('2026-11-09'));
    fake.seed('companies/c1/devices/late', device('2026-11-01'));
    fake.seed('companies/c1/devices/far', device('2026-11-10'));
    fake.seed('companies/c1/devices/none', { name: 'Sem data' });

    await expect(sendMaintenanceNotices(NOW, { notify })).resolves.toEqual({ sent: 1, errors: 0 });

    expect(notify).toHaveBeenCalledTimes(1);
    expect(notify.mock.calls[0][1].count).toBe(2);
    expect(fake.docs.get('companies/c1/devices/today')?.nextMaintenanceNoticeFor).toBe('2026-11-02');
    expect(fake.docs.get('companies/c1/devices/far')?.nextMaintenanceNoticeFor).toBeUndefined();
  });

  it('tells each date once, and again when the date changes', async () => {
    fake.seed('companies/c1/devices/d1', device('2026-11-05'));

    await sendMaintenanceNotices(NOW, { notify });
    await expect(sendMaintenanceNotices(NOW, { notify })).resolves.toEqual({ sent: 0, errors: 0 });
    expect(notify).toHaveBeenCalledTimes(1);

    fake.seed('companies/c1/devices/d1', device('2026-11-07', { nextMaintenanceNoticeFor: '2026-11-05' }));
    await sendMaintenanceNotices(NOW, { notify });
    expect(notify).toHaveBeenCalledTimes(2);
  });

  it('leaves out a device under an active contract, not an ended one', async () => {
    fake.seed('companies/c1/devices/d1', device('2026-11-05'));
    fake.seed('companies/c1/devices/d2', device('2026-11-05'));
    fake.seed('companies/c1/orders/o1', { isContract: true, deviceIds: ['d1'], contract: { active: true } });
    fake.seed('companies/c1/orders/o2', { isContract: true, deviceIds: ['d2'], contract: { active: false } });

    await sendMaintenanceNotices(NOW, { notify });

    expect(notify.mock.calls[0][1].count).toBe(1);
    expect(fake.docs.get('companies/c1/devices/d1')?.nextMaintenanceNoticeFor).toBeUndefined();
    expect(fake.docs.get('companies/c1/devices/d2')?.nextMaintenanceNoticeFor).toBe('2026-11-05');
  });

  it('sends nothing when every device is under contract', async () => {
    fake.seed('companies/c1/devices/d1', device('2026-11-05'));
    fake.seed('companies/c1/orders/o1', { isContract: true, deviceIds: ['d1'], contract: { active: true } });

    await expect(sendMaintenanceNotices(NOW, { notify })).resolves.toEqual({ sent: 0, errors: 0 });
    expect(notify).not.toHaveBeenCalled();
  });

  it('calls who was on the most recent order of the device', async () => {
    fake.seed('companies/c1/devices/d1', device('2026-11-05'));
    fake.seed('companies/c1/orders/old', {
      deviceIds: ['d1'],
      createdAt: '2026-01-01T10:00:00.000Z',
      assignedTo: { id: 'old', name: 'Antigo' },
    });
    fake.seed('companies/c1/orders/new', {
      deviceIds: ['d1'],
      createdAt: '2026-05-01T10:00:00.000Z',
      assignedTo: { id: 'tec1', name: 'Bruno' },
    });

    await sendMaintenanceNotices(NOW, { notify });

    expect(notify.mock.calls[0][2]).toEqual([{ id: 'tec1', name: 'Bruno' }]);
  });

  it('keeps each company apart', async () => {
    fake.seed('companies/c2', { country: 'US' });
    fake.seed('companies/c1/devices/d1', device('2026-11-05'));
    fake.seed('companies/c2/devices/d2', device('2026-11-05'));

    await expect(sendMaintenanceNotices(NOW, { notify })).resolves.toEqual({ sent: 2, errors: 0 });

    const titles = Object.fromEntries(notify.mock.calls.map(([id, message]) => [id, message.title]));
    expect(titles).toEqual({ c1: 'Manutenção chegando', c2: 'Maintenance coming up' });
  });

  it('ignores legacy devices and companies that are gone', async () => {
    fake.seed('devices/legacy', device('2026-11-05'));
    fake.seed('companies/gone/devices/d1', device('2026-11-05'));

    await expect(sendMaintenanceNotices(NOW, { notify })).resolves.toEqual({ sent: 0, errors: 0 });
    expect(notify).not.toHaveBeenCalled();
  });

  it('retries a company that failed on the next run', async () => {
    jest.spyOn(console, 'error').mockImplementation(() => undefined);
    fake.seed('companies/c1/devices/d1', device('2026-11-05'));
    notify.mockRejectedValueOnce(new Error('boom'));

    await expect(sendMaintenanceNotices(NOW, { notify })).resolves.toEqual({ sent: 0, errors: 1 });
    expect(fake.docs.get('companies/c1/devices/d1')?.nextMaintenanceNoticeFor).toBeUndefined();

    await expect(sendMaintenanceNotices(NOW, { notify })).resolves.toEqual({ sent: 1, errors: 0 });
  });
});
