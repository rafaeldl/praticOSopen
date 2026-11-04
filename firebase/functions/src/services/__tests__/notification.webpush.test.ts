// Browser notifications (Web Push through FCM): tokens the web app saves with
// platform 'web' get a webpush message that opens the right screen of /app; the
// message to the phones stays exactly what it was.
const mockSendEachForMulticast = jest.fn();

jest.mock('firebase-admin/messaging', () => ({
  getMessaging: () => ({ sendEachForMulticast: mockSendEachForMulticast }),
}));
jest.mock('../firestore.service', () => jest.requireActual('../../__tests__/helpers/fake-firestore').firestoreServiceMock);

import { resetFakeDb, seed } from '../../__tests__/helpers/fake-firestore';
import { notifyCourtesyEnding, notifyMaintenanceDue, notifyOrderApproved, webPushLink } from '../notification.service';
import type { Order } from '../../models/types';

const ORDER = {
  id: 'o1',
  number: 42,
  createdBy: { id: 'owner1', name: 'Dono' },
} as unknown as Order;

/** What the phones got before Web Push existed, for the approval of order 42. */
const NATIVE_MESSAGE = {
  tokens: ['fcm_ios', 'fcm_android', 'fcm_old'],
  notification: { title: 'Orçamento Aprovado! ✅', body: 'Ana aprovou o orçamento da OS #42' },
  data: { type: 'order_approved', orderId: 'o1', orderNumber: '42', companyId: 'c1' },
  android: { priority: 'high', notification: { sound: 'default', channelId: 'orders_channel' } },
  apns: { payload: { aps: { sound: 'default', badge: 1 } } },
};

describe('notification.service - Web Push', () => {
  beforeEach(() => {
    resetFakeDb();
    jest.clearAllMocks();
    jest.spyOn(console, 'log').mockImplementation(() => undefined);
    mockSendEachForMulticast.mockResolvedValue({ successCount: 1, failureCount: 0, responses: [] });
    seed('companies/c1', { owner: { id: 'owner1', name: 'Dono' }, users: [{ user: { id: 'owner1', name: 'Dono' }, role: 'owner' }] });
  });
  afterEach(() => jest.restoreAllMocks());

  it('sends the phones the same message as before, without the browser tokens', async () => {
    seed('users/owner1', {
      fcmTokens: [
        { token: 'fcm_ios', platform: 'ios', deviceId: 'd1' },
        { token: 'fcm_android', platform: 'android', deviceId: 'd2' },
        { token: 'fcm_old' },
        { token: 'fcm_web', platform: 'web', deviceId: 'web-1' },
      ],
    });

    await notifyOrderApproved(ORDER, 'c1', 'Ana');

    expect(mockSendEachForMulticast).toHaveBeenCalledTimes(2);
    const [native, web] = mockSendEachForMulticast.mock.calls.map((call) => call[0]);
    expect(native).toEqual(NATIVE_MESSAGE);
    expect(web).toEqual({
      tokens: ['fcm_web'],
      notification: NATIVE_MESSAGE.notification,
      data: NATIVE_MESSAGE.data,
      webpush: {
        notification: { icon: 'https://praticos.app/logo.png' },
        fcmOptions: { link: 'https://praticos.app/app/?order=o1&company=c1' },
      },
    });
  });

  it('sends nothing for the browser when nobody has one', async () => {
    seed('users/owner1', { fcmTokens: [{ token: 'fcm_ios', platform: 'ios' }] });

    await notifyOrderApproved(ORDER, 'c1', 'Ana');

    expect(mockSendEachForMulticast).toHaveBeenCalledTimes(1);
    expect(mockSendEachForMulticast.mock.calls[0][0]).toEqual({ ...NATIVE_MESSAGE, tokens: ['fcm_ios'] });
  });

  it('sends only the browser message when the person uses only the web', async () => {
    seed('users/owner1', { fcmTokens: [{ token: 'fcm_web', platform: 'web' }] });

    await notifyOrderApproved(ORDER, 'c1', 'Ana');

    expect(mockSendEachForMulticast).toHaveBeenCalledTimes(1);
    const message = mockSendEachForMulticast.mock.calls[0][0];
    expect(message.tokens).toEqual(['fcm_web']);
    expect(message.android).toBeUndefined();
    expect(message.apns).toBeUndefined();
  });

  it('a notice without an order opens the start of the web app', async () => {
    seed('users/owner1', { fcmTokens: [{ token: 'fcm_web', platform: 'web' }] });

    await notifyMaintenanceDue('c1', { title: 'Manutenção chegando', body: 'Split', count: 1 }, []);

    expect(mockSendEachForMulticast.mock.calls[0][0].webpush.fcmOptions.link).toBe('https://praticos.app/app/');
  });

  it('counts a failure of the browser message as a failed push', async () => {
    jest.spyOn(console, 'error').mockImplementation(() => undefined);
    seed('users/owner1', { fcmTokens: [{ token: 'fcm_ios', platform: 'ios' }, { token: 'fcm_web', platform: 'web' }] });
    mockSendEachForMulticast.mockResolvedValueOnce({ successCount: 1, failureCount: 0, responses: [] }).mockRejectedValueOnce(new Error('fcm down'));

    // The courtesy notice throws when the push failed, so the daily job retries.
    await expect(notifyCourtesyEnding('c1', { title: 'Cortesia', body: 'Acaba em 3 dias', days: 3 })).rejects.toThrow('not delivered');
    expect(mockSendEachForMulticast).toHaveBeenCalledTimes(2);
  });
});

describe('webPushLink', () => {
  it('opens the order in its company', () => {
    expect(webPushLink({ orderId: 'o 1', companyId: 'c1' })).toBe('https://praticos.app/app/?order=o%201&company=c1');
  });

  it('opens the start without an order', () => {
    expect(webPushLink({ type: 'courtesy_ending', companyId: 'c1' })).toBe('https://praticos.app/app/');
    expect(webPushLink(undefined)).toBe('https://praticos.app/app/');
  });
});
