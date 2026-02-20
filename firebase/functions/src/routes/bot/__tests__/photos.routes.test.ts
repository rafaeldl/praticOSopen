import request from 'supertest';
import { buildApp } from './helpers';

// ---- Mocks ----------------------------------------------------------------

jest.mock('../../../services/order.service');
jest.mock('../../../services/photo-upload.service');
jest.mock('../../../middleware/auth.middleware', () => ({
  requireLinked: (_req: any, _res: any, next: any) => next(),
}));
jest.mock('../../../middleware/company.middleware', () => ({
  getUserAggr: () => ({ id: 'user1', name: 'Test User' }),
  getCompanyAggr: () => ({ id: 'comp1', name: 'Test Co' }),
}));
jest.mock('../../../utils/validation.utils', () => {
  const actual = jest.requireActual('../../../utils/validation.utils');
  return {
    ...actual,
    validateInput: (_schema: any, data: any) => ({ success: true, data }),
  };
});

import * as orderService from '../../../services/order.service';
import * as photoService from '../../../services/photo-upload.service';

const mockOrderService = orderService as jest.Mocked<typeof orderService>;
const mockPhotoService = photoService as jest.Mocked<typeof photoService>;

// ---- Import router after mocks --------------------------------------------
import router from '../photos.routes';

// ---- Fixtures --------------------------------------------------------------

const fakeOrder = {
  id: 'ord1',
  number: 1,
  status: 'approved',
  photos: [
    { id: 'ph1', url: 'http://photo1.jpg', storagePath: 'tenants/comp1/ph1', createdAt: '2026-01-01', createdBy: { id: 'user1', name: 'Test User' } },
  ],
  company: { id: 'comp1', name: 'Test Co' },
};

// ---- Tests -----------------------------------------------------------------

describe('Bot Photos Routes', () => {
  beforeEach(() => jest.clearAllMocks());

  // ----- POST /:number/photos -----------------------------------------------

  describe('POST /:number/photos (base64)', () => {
    it('does NOT return formatContext', async () => {
      mockOrderService.getOrderByNumber
        .mockResolvedValueOnce(fakeOrder as any)   // existence check
        .mockResolvedValueOnce(fakeOrder as any);   // updated order
      mockPhotoService.uploadPhotoFromBase64.mockResolvedValue({
        id: 'ph2', url: 'http://photo2.jpg', storagePath: 'tenants/comp1/ph2',
      } as any);
      mockOrderService.addPhotoToOrder.mockResolvedValue(undefined as any);

      const app = buildApp(router);
      const res = await request(app)
        .post('/1/photos')
        .send({ base64: 'abc123', filename: 'test.jpg' });

      expect(res.status).toBe(200);
      expect(res.body.data.formatContext).toBeUndefined();
    });

    it('does NOT return message', async () => {
      mockOrderService.getOrderByNumber
        .mockResolvedValueOnce(fakeOrder as any)
        .mockResolvedValueOnce(fakeOrder as any);
      mockPhotoService.uploadPhotoFromBase64.mockResolvedValue({
        id: 'ph2', url: 'http://photo2.jpg', storagePath: 'tenants/comp1/ph2',
      } as any);
      mockOrderService.addPhotoToOrder.mockResolvedValue(undefined as any);

      const app = buildApp(router);
      const res = await request(app)
        .post('/1/photos')
        .send({ base64: 'abc123', filename: 'test.jpg' });

      expect(res.body.data.message).toBeUndefined();
    });

    it('returns photoId and photoCount', async () => {
      mockOrderService.getOrderByNumber
        .mockResolvedValueOnce(fakeOrder as any)
        .mockResolvedValueOnce(fakeOrder as any);
      mockPhotoService.uploadPhotoFromBase64.mockResolvedValue({
        id: 'ph2', url: 'http://photo2.jpg', storagePath: 'tenants/comp1/ph2',
      } as any);
      mockOrderService.addPhotoToOrder.mockResolvedValue(undefined as any);

      const app = buildApp(router);
      const res = await request(app)
        .post('/1/photos')
        .send({ base64: 'abc123', filename: 'test.jpg' });

      expect(res.body.data.photoId).toBe('ph2');
      expect(res.body.data.photoCount).toBeDefined();
    });
  });

  // ----- GET /:number/photos ------------------------------------------------

  describe('GET /:number/photos', () => {
    it('does NOT return formatContext', async () => {
      mockOrderService.getOrderByNumber.mockResolvedValue(fakeOrder as any);

      const app = buildApp(router);
      const res = await request(app).get('/1/photos');

      expect(res.status).toBe(200);
      expect(res.body.data.formatContext).toBeUndefined();
    });
  });

  // ----- DELETE /:number/photos/:photoId ------------------------------------

  describe('DELETE /:number/photos/:photoId', () => {
    it('does NOT return formatContext', async () => {
      mockOrderService.getOrderByNumber.mockResolvedValue(fakeOrder as any);
      mockPhotoService.deletePhoto.mockResolvedValue(undefined as any);
      mockOrderService.removePhotoFromOrder.mockResolvedValue(undefined as any);

      const app = buildApp(router);
      const res = await request(app).delete('/1/photos/ph1');

      expect(res.status).toBe(200);
      expect(res.body.data.formatContext).toBeUndefined();
    });
  });
});
