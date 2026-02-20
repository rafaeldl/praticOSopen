import request from 'supertest';
import { buildApp } from './helpers';

// ---- Mocks ----------------------------------------------------------------

jest.mock('../../../services/forms.service');
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

import * as formsService from '../../../services/forms.service';

const mockFormsService = formsService as jest.Mocked<typeof formsService>;

// ---- Import router after mocks --------------------------------------------
import router from '../forms.routes';

// ---- Fixtures --------------------------------------------------------------

const fakeOrder = { id: 'ord1', number: 1, status: 'approved' };

const fakeTemplate = {
  id: 'tmpl1',
  title: 'Checklist A',
  description: 'A test checklist',
  items: [{ id: 'i1', label: 'Item 1', type: 'text', required: true, allowPhotos: false }],
  titleI18n: { en: 'Checklist A' },
  descriptionI18n: { en: 'A test checklist' },
};

const fakeForm = {
  id: 'form1',
  formDefinitionId: 'tmpl1',
  title: 'Checklist A',
  status: 'pending',
  items: [{ id: 'i1', label: 'Item 1', type: 'text', required: true, allowPhotos: false }],
  responses: [],
  titleI18n: { en: 'Checklist A' },
};

// ---- Tests -----------------------------------------------------------------

describe('Bot Forms Routes', () => {
  beforeEach(() => jest.clearAllMocks());

  // ----- GET /templates -----------------------------------------------------

  describe('GET /templates', () => {
    it('does NOT return formatContext', async () => {
      mockFormsService.listFormTemplates.mockResolvedValue([fakeTemplate] as any);

      const app = buildApp(router);
      const res = await request(app).get('/templates');

      expect(res.status).toBe(200);
      expect(res.body.data.formatContext).toBeUndefined();
    });
  });

  // ----- GET /:number/forms -------------------------------------------------

  describe('GET /:number/forms', () => {
    it('does NOT return formatContext or formattedList', async () => {
      mockFormsService.getOrderByNumber.mockResolvedValue(fakeOrder as any);
      mockFormsService.listOrderForms.mockResolvedValue([fakeForm] as any);
      mockFormsService.calculateFormProgress.mockReturnValue({ total: 1, completed: 0, percent: 0 } as any);
      mockFormsService.getStatusEmoji.mockReturnValue('⏳');
      mockFormsService.formatFormStatus.mockReturnValue('Pending');

      const app = buildApp(router);
      const res = await request(app).get('/1/forms');

      expect(res.status).toBe(200);
      expect(res.body.data.formatContext).toBeUndefined();
      expect(res.body.data.formattedList).toBeUndefined();
    });

    it('returns forms array and count', async () => {
      mockFormsService.getOrderByNumber.mockResolvedValue(fakeOrder as any);
      mockFormsService.listOrderForms.mockResolvedValue([fakeForm] as any);
      mockFormsService.calculateFormProgress.mockReturnValue({ total: 1, completed: 0, percent: 0 } as any);
      mockFormsService.getStatusEmoji.mockReturnValue('⏳');
      mockFormsService.formatFormStatus.mockReturnValue('Pending');

      const app = buildApp(router);
      const res = await request(app).get('/1/forms');

      expect(Array.isArray(res.body.data.forms)).toBe(true);
      expect(typeof res.body.data.count).toBe('number');
    });
  });

  // ----- POST /:number/forms ------------------------------------------------

  describe('POST /:number/forms', () => {
    it('does NOT return message', async () => {
      mockFormsService.getOrderByNumber.mockResolvedValue(fakeOrder as any);
      mockFormsService.addFormToOrder.mockResolvedValue(fakeForm as any);

      const app = buildApp(router);
      const res = await request(app)
        .post('/1/forms')
        .send({ templateId: 'tmpl1' });

      expect(res.status).toBe(200);
      expect(res.body.data.message).toBeUndefined();
    });

    it('returns orderNumber', async () => {
      mockFormsService.getOrderByNumber.mockResolvedValue(fakeOrder as any);
      mockFormsService.addFormToOrder.mockResolvedValue(fakeForm as any);

      const app = buildApp(router);
      const res = await request(app)
        .post('/1/forms')
        .send({ templateId: 'tmpl1' });

      expect(res.body.data.orderNumber).toBe(1);
    });
  });
});
