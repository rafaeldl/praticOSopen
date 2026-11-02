const mockSendEachForMulticast = jest.fn();

jest.mock('firebase-admin/messaging', () => ({
  getMessaging: () => ({ sendEachForMulticast: mockSendEachForMulticast }),
}));
jest.mock('../firestore.service', () => jest.requireActual('../../__tests__/helpers/fake-firestore').firestoreServiceMock);

import { list, resetFakeDb, seed } from '../../__tests__/helpers/fake-firestore';
import { notifyMaintenanceDue } from '../notification.service';

const MESSAGE = { title: 'Manutenção chegando', body: 'Split · Padaria · 09/11/2026', count: 1 };

describe('notification.service - notifyMaintenanceDue', () => {
  beforeEach(() => {
    resetFakeDb();
    jest.clearAllMocks();
    jest.spyOn(console, 'log').mockImplementation(() => undefined);
    mockSendEachForMulticast.mockResolvedValue({ successCount: 1, failureCount: 0, responses: [] });
    seed('companies/c1', {
      owner: { id: 'owner1', name: 'Dono' },
      users: [
        { user: { id: 'owner1', name: 'Dono' }, role: 'owner' },
        { user: { id: 'sup1', name: 'Supervisor' }, role: 'supervisor' },
        { user: { id: 'mgr1', name: 'Gerente' }, role: 'manager' },
        { user: { id: 'tec1', name: 'Bruno' }, role: 'technician' },
        { user: { id: 'tec2', name: 'Carla' }, role: 'technician' },
      ],
    });
    for (const id of ['owner1', 'sup1', 'mgr1', 'tec1', 'tec2', 'gone']) {
      seed(`users/${id}`, { fcmTokens: [{ token: `fcm_${id}` }] });
    }
  });
  afterEach(() => jest.restoreAllMocks());

  it('reaches who manages devices and the technician of the last order', async () => {
    await notifyMaintenanceDue('c1', MESSAGE, [{ id: 'tec1', name: 'Bruno' }]);

    const saved = list('companies/c1/notifications').map((n) => n.data);
    expect(saved.map((n) => n.recipientId).sort()).toEqual(['owner1', 'sup1', 'tec1']);
    expect(saved[0].type).toBe('maintenance_due');
    const push = mockSendEachForMulticast.mock.calls[0][0];
    expect(push.tokens.sort()).toEqual(['fcm_owner1', 'fcm_sup1', 'fcm_tec1']);
    expect(push.notification).toEqual({ title: MESSAGE.title, body: MESSAGE.body });
  });

  it('does not reach someone who left the team, nor anyone twice', async () => {
    await notifyMaintenanceDue('c1', MESSAGE, [
      { id: 'gone', name: 'Saiu' },
      { id: 'owner1', name: 'Dono' },
    ]);

    const saved = list('companies/c1/notifications').map((n) => n.data.recipientId);
    expect(saved.sort()).toEqual(['owner1', 'sup1']);
  });

  it('throws when the push fails, so the job tries again', async () => {
    jest.spyOn(console, 'error').mockImplementation(() => undefined);
    mockSendEachForMulticast.mockRejectedValue(new Error('fcm down'));

    await expect(notifyMaintenanceDue('c1', MESSAGE, [])).rejects.toThrow('not delivered');
  });
});
