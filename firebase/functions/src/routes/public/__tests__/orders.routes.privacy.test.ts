import express from 'express';
import request from 'supertest';

// ---- Mocks ----------------------------------------------------------------

// Permissions of the link used by each test (the real permission check runs).
let mockPermissions: string[] = ['view', 'approve', 'comment'];

jest.mock('../../../middleware/share-token.middleware', () => {
  const actual = jest.requireActual('../../../middleware/share-token.middleware');
  return {
    ...actual,
    shareTokenAuth: (req: any, _res: any, next: any) => {
      req.shareTokenAuth = {
        type: 'shareToken',
        token: req.params.token,
        companyId: 'comp1',
        orderId: 'ord1',
        permissions: mockPermissions,
        customer: { id: 'cust1', name: 'Alice Souza', phone: '+5511999998888' },
      };
      next();
    },
  };
});

const mockOrderUpdate = jest.fn().mockResolvedValue(undefined);

jest.mock('../../../services/firestore.service', () => ({
  db: {
    collection: jest.fn(() => ({
      doc: jest.fn(() => ({
        get: jest.fn().mockResolvedValue({
          exists: true,
          data: () => ({
            name: 'Test Shop',
            country: 'BR',
            phone: '+5511900000000',
            email: 'contact@shop.test',
          }),
        }),
      })),
    })),
  },
  getTenantCollection: jest.fn(() => ({
    doc: jest.fn(() => ({ update: mockOrderUpdate })),
  })),
}));

jest.mock('../../../services/share-token.service', () => ({}));
jest.mock('../../../services/notification.service', () => ({
  notifyOrderRated: jest.fn().mockResolvedValue(undefined),
}));
jest.mock('../../../services/comment.service', () => ({
  getCustomerVisibleComments: jest.fn().mockResolvedValue([]),
  addComment: jest.fn().mockResolvedValue({}),
}));
jest.mock('../../../services/forms.service', () => ({
  listOrderForms: jest.fn(),
}));
jest.mock('../../../services/order.service', () => ({
  getOrder: jest.fn(),
  calculateRemainingBalance: jest.fn(() => 0),
}));
jest.mock('../../../services/asaas/charge.service', () => ({
  getOpenOrLatestPaidCharge: jest.fn().mockResolvedValue(null),
}));
jest.mock('../../../services/asaas/connection.service', () => ({
  getPaymentSettings: jest.fn().mockResolvedValue({ asaasConnected: false }),
}));

import * as orderService from '../../../services/order.service';
import * as formsService from '../../../services/forms.service';
import * as commentService from '../../../services/comment.service';
import router, { buildPublicDevices, toPublicForms } from '../orders.routes';

const mockGetOrder = orderService.getOrder as jest.Mock;
const mockListForms = formsService.listOrderForms as jest.Mock;
const mockGetComments = commentService.getCustomerVisibleComments as jest.Mock;

// ---- Fixtures --------------------------------------------------------------

const fakeOrder = {
  id: 'ord1',
  number: 7,
  status: 'done',
  customer: { id: 'cust1', name: 'Alice Souza' },
  devices: [
    { id: 'devFirestoreA', name: 'Car A', serial: 'ABC1D23' },
    { id: 'devFirestoreB', name: 'Car B', serial: 'XYZ9K87' },
  ],
  services: [
    { service: { id: 'srv1', name: 'Oil change' }, value: 100, deviceId: 'devFirestoreB' },
    { service: { id: 'srv2', name: 'Alignment' }, value: 50, deviceId: 'devDeleted' },
  ],
  products: [
    { product: { id: 'prd1', name: 'Filter' }, value: 25, quantity: 1, deviceId: 'devFirestoreA' },
  ],
  total: 175,
  createdAt: '2026-10-01T10:00:00.000Z',
};

const completedForm = {
  id: 'formInstance1',
  formDefinitionId: 'formTemplate1',
  title: 'Intake inspection',
  status: 'completed',
  deviceId: 'devFirestoreA',
  completedAt: '2026-10-02T10:00:00.000Z',
  items: [
    { id: 'i1', label: 'Tires ok?', type: 'boolean', required: true, allowPhotos: true },
    { id: 'i2', label: 'Fuel', type: 'select', options: ['1/4', '1/2'], required: false, allowPhotos: false },
    { id: 'i3', label: 'Scratches', type: 'photo_only', required: false, allowPhotos: true },
    { id: 'i4', label: 'Notes', type: 'text', required: false, allowPhotos: false },
    { id: 'i5', label: 'Damage', type: 'checklist', options: ['Door', 'Hood'], required: false, allowPhotos: true },
  ],
  notes: {
    i3: {
      text: 'Dent on the rear left door',
      ai: true,
      photos: [
        { url: 'https://storage.test/scratches.jpg', text: 'Scratch near the handle', ai: true },
        { url: 'https://storage.test/removed.jpg', text: 'Removed photo note', ai: false },
      ],
    },
    i4: { text: '   ', ai: false },
    i5: {
      options: [
        { option: 'Door', text: 'Near the handle', ai: false },
        { option: 'Hood', text: 'Unmarked option note', ai: false },
      ],
    },
  },
  aiFilled: ['i2'],
  responses: [
    { itemId: 'i1', value: true, photoUrls: [] },
    { itemId: 'i2', value: '1/2', photoUrls: [] },
    { itemId: 'i3', value: null, photoUrls: ['https://storage.test/scratches.jpg'] },
    { itemId: 'i4', value: '', photoUrls: [] },
    { itemId: 'i5', value: ['Door'], photoUrls: [] },
  ],
};

const inProgressForm = {
  ...completedForm,
  id: 'formInstance2',
  title: 'Exit checklist',
  status: 'in_progress',
};

function buildApp() {
  const app = express();
  app.use(express.json());
  app.use('/public/orders', router);
  return app;
}

beforeEach(() => {
  jest.clearAllMocks();
  mockPermissions = ['view', 'approve', 'comment'];
  mockGetOrder.mockResolvedValue(fakeOrder);
  mockListForms.mockResolvedValue([completedForm, inProgressForm]);
  mockGetComments.mockResolvedValue([]);
});

// ---- GET /:token -----------------------------------------------------------

describe('GET /public/orders/:token — privacy', () => {
  it('does not send the company e-mail', async () => {
    const res = await request(buildApp()).get('/public/orders/tok1');

    expect(res.status).toBe(200);
    expect(res.body.data.company).not.toHaveProperty('email');
    expect(res.body.data.company.phone).toBe('+5511900000000');
    expect(JSON.stringify(res.body)).not.toContain('contact@shop.test');
  });

  it('replaces device ids with opaque keys, also on items', async () => {
    const res = await request(buildApp()).get('/public/orders/tok1');
    const { order } = res.body.data;

    expect(order.devices.map((d: any) => d.id)).toEqual(['d1', 'd2']);
    expect(order.services[0].deviceId).toBe('d2');
    expect(order.services[1].deviceId).toBeNull(); // device no longer on the order
    expect(order.products[0].deviceId).toBe('d1');
    expect(JSON.stringify(res.body)).not.toContain('devFirestore');
  });

  it('keys a single legacy device too', async () => {
    mockGetOrder.mockResolvedValue({
      ...fakeOrder,
      devices: undefined,
      device: { id: 'devLegacy', name: 'Phone', serial: '123456789' },
      services: [{ service: { name: 'Screen' }, value: 10, deviceId: 'devLegacy' }],
      products: [],
    });

    const res = await request(buildApp()).get('/public/orders/tok1');

    expect(res.body.data.order.devices).toEqual([
      expect.objectContaining({ id: 'd1', name: 'Phone' }),
    ]);
    expect(res.body.data.order.services[0].deviceId).toBe('d1');
    expect(JSON.stringify(res.body)).not.toContain('devLegacy');
  });

  it('sends only completed checklists, reduced to question, answer, photos and notes', async () => {
    const res = await request(buildApp()).get('/public/orders/tok1');

    const empty = { note: null, optionNotes: [], photoNotes: [] };
    expect(res.body.data.order.forms).toEqual([
      {
        title: 'Intake inspection',
        deviceId: 'd1',
        items: [
          { label: 'Tires ok?', value: true, photos: [], ...empty },
          { label: 'Fuel', value: '1/2', photos: [], ...empty },
          {
            label: 'Scratches',
            value: null,
            photos: ['https://storage.test/scratches.jpg'],
            note: 'Dent on the rear left door',
            optionNotes: [],
            photoNotes: [{ url: 'https://storage.test/scratches.jpg', text: 'Scratch near the handle' }],
          },
          {
            label: 'Damage',
            value: ['Door'],
            photos: [],
            note: null,
            optionNotes: [{ option: 'Door', text: 'Near the handle' }],
            photoNotes: [],
          },
        ],
      },
    ]);
    const raw = JSON.stringify(res.body);
    // Notes of removed photos and unmarked options, the AI mark and the
    // AI-filled list never leave.
    for (const leak of ['Removed photo note', 'Unmarked option note', '"ai"', 'aiFilled', 'removed.jpg']) {
      expect(raw).not.toContain(leak);
    }
    for (const leak of ['formInstance', 'formTemplate', 'Exit checklist', 'completedAt', '"i1"']) {
      expect(raw).not.toContain(leak);
    }
  });

  it('still loads the page when the checklists fail to load', async () => {
    mockListForms.mockRejectedValue(new Error('boom'));
    jest.spyOn(console, 'error').mockImplementation(() => undefined);

    const res = await request(buildApp()).get('/public/orders/tok1');

    expect(res.status).toBe(200);
    expect(res.body.data.order.forms).toEqual([]);
  });
});

// ---- Permissions -----------------------------------------------------------

describe('public link routes require the link permission', () => {
  it('GET /:token/comments needs view', async () => {
    mockPermissions = [];
    const denied = await request(buildApp()).get('/public/orders/tok1/comments');
    expect(denied.status).toBe(403);
    expect(mockGetComments).not.toHaveBeenCalled();

    mockPermissions = ['view'];
    const allowed = await request(buildApp()).get('/public/orders/tok1/comments');
    expect(allowed.status).toBe(200);
  });

  it('POST /:token/rating needs view', async () => {
    mockPermissions = [];
    const denied = await request(buildApp())
      .post('/public/orders/tok1/rating')
      .send({ score: 5 });
    expect(denied.status).toBe(403);
    expect(mockOrderUpdate).not.toHaveBeenCalled();

    mockPermissions = ['view'];
    const allowed = await request(buildApp())
      .post('/public/orders/tok1/rating')
      .send({ score: 5 });
    expect(allowed.status).toBe(201);
    expect(mockOrderUpdate).toHaveBeenCalled();
  });
});

// ---- Helpers ---------------------------------------------------------------

describe('buildPublicDevices / toPublicForms', () => {
  it('maps unknown or missing device ids to null', () => {
    const { keyOf } = buildPublicDevices({ devices: [{ id: 'a', name: 'A' }] });
    expect(keyOf('a')).toBe('d1');
    expect(keyOf('b')).toBeNull();
    expect(keyOf(undefined)).toBeNull();
  });

  it('drops answers that are not plain values and checklists left empty', () => {
    const forms = toPublicForms([
      {
        ...completedForm,
        notes: undefined,
        responses: [{ itemId: 'i1', value: { internal: 'x' }, photoUrls: [] }],
      } as any,
    ], () => null);
    expect(forms).toEqual([]);
  });

  it('keeps a question with only a note, and ignores notes that are not text', () => {
    const forms = toPublicForms([
      {
        ...completedForm,
        responses: [],
        notes: {
          i1: { text: 'Spare tire missing' },
          i2: { text: 42, options: 'x', photos: [{ url: 1, text: 'y' }] },
        },
      } as any,
    ], () => null);
    expect(forms[0].items).toEqual([
      { label: 'Tires ok?', value: null, photos: [], note: 'Spare tire missing', optionNotes: [], photoNotes: [] },
    ]);
  });
});
