const mockSendEachForMulticast = jest.fn();

jest.mock('firebase-admin/messaging', () => ({
  getMessaging: () => ({ sendEachForMulticast: mockSendEachForMulticast }),
}));
jest.mock('../firestore.service', () => jest.requireActual('../../__tests__/helpers/fake-firestore').firestoreServiceMock);

import { fakeDb, list, resetFakeDb, seed } from '../../__tests__/helpers/fake-firestore';
import { notifyAsaasPaymentReceived } from '../notification.service';

describe('notification.service - notifyAsaasPaymentReceived', () => {
  beforeEach(() => {
    resetFakeDb();
    jest.clearAllMocks();
    jest.spyOn(console, 'log').mockImplementation(() => undefined);
    mockSendEachForMulticast.mockResolvedValue({ successCount: 3, failureCount: 0, responses: [] });

    seed('companies/c1', {
      name: 'Oficina',
      owner: { id: 'owner1', name: 'Dono' },
      users: [
        { user: { id: 'owner1', name: 'Dono' }, role: 'admin' },
        { user: { id: 'adm1', name: 'Admin' }, role: 'admin' },
        { user: { id: 'mgr1', name: 'Gerente' }, role: 'manager' },
        { user: { id: 'sup1', name: 'Supervisor' }, role: 'supervisor' },
        { user: { id: 'tec1', name: 'Técnico' }, role: 'technician' },
      ],
    });
    seed('companies/c1/orders/o1', {
      number: 42,
      assignedTo: { id: 'tec1', name: 'Técnico' },
      createdBy: { id: 'tec1', name: 'Técnico' },
    });
    for (const id of ['owner1', 'adm1', 'mgr1', 'sup1', 'tec1']) {
      seed(`users/${id}`, { fcmTokens: [{ token: `fcm_${id}` }] });
    }
  });
  afterEach(() => jest.restoreAllMocks());

  it('notifica só dono, admin e gerente com OS e valor', async () => {
    await notifyAsaasPaymentReceived('c1', 'o1', 150);

    const notifications = list('companies/c1/notifications').map((n) => n.data);
    expect(notifications.map((n) => n.recipientId).sort()).toEqual(['adm1', 'mgr1', 'owner1']);
    expect(notifications[0].type).toBe('payment_received');
    expect(notifications[0].orderId).toBe('o1');
    expect(notifications[0].body).toMatch(/OS #42/);
    expect(notifications[0].body).toMatch(/R\$\s?150,00/);

    expect(mockSendEachForMulticast).toHaveBeenCalledTimes(1);
    const message = mockSendEachForMulticast.mock.calls[0][0];
    expect(message.tokens.sort()).toEqual(['fcm_adm1', 'fcm_mgr1', 'fcm_owner1']);
    expect(message.notification.title).toBe('Pagamento recebido');
  });

  it('não lança quando a empresa não existe', async () => {
    fakeDb.reset();
    await expect(notifyAsaasPaymentReceived('c1', 'o1', 10)).resolves.toBeUndefined();
    expect(mockSendEachForMulticast).not.toHaveBeenCalled();
  });
});
