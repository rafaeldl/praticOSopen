import request from 'supertest';

jest.mock('../../../services/order.service');
jest.mock('../../../services/firestore.service', () => ({
  db: { collection: () => ({ doc: () => ({ get: async () => ({ data: () => ({}) }) }) }) },
}));

import * as orderService from '../../../services/order.service';
import router from '../orders.routes';
import summaryRouter from '../summary.routes';
import { buildApp } from './helpers';

const mocked = orderService as jest.Mocked<typeof orderService>;
const order = (createdBy: string) => ({ id: 'o1', number: 7, status: 'quote', createdBy: { id: createdBy } }) as never;

describe('bot routes follow the role of the linked user', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mocked.getOrderByNumber.mockResolvedValue(order('someone-else'));
    mocked.listOrders.mockResolvedValue({ data: [], total: 0, hasMore: false });
  });

  it.each(['technician', 'consultant'])('%s cannot open an order created by someone else', async (role) => {
    const res = await request(buildApp(router, { role })).get('/7');
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('INSUFFICIENT_PERMISSIONS');
  });

  it('opens the order the user created', async () => {
    mocked.getOrderByNumber.mockResolvedValue(order('user1'));
    const res = await request(buildApp(router, { role: 'technician' })).get('/7');
    expect(res.status).not.toBe(403);
  });

  it.each(['owner', 'admin', 'manager', 'supervisor'])('%s skips the order lookup in the check', async (role) => {
    const res = await request(buildApp(router, { role })).get('/7');
    expect(res.status).not.toBe(403);
  });

  it.each(['technician', 'consultant'])('%s cannot list every order', async (role) => {
    const res = await request(buildApp(router, { role })).get('/list');
    expect(res.status).toBe(403);
    expect(mocked.listOrders).not.toHaveBeenCalled();
  });

  it('admin lists orders', async () => {
    const res = await request(buildApp(router, { role: 'admin' })).get('/list');
    expect(res.status).toBe(200);
  });

  it('technician cannot read the company summary', async () => {
    const res = await request(buildApp(summaryRouter, { role: 'technician' })).get('/today');
    expect(res.status).toBe(403);
  });
});
