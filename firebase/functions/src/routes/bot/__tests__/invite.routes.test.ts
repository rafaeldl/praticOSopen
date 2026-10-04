import request from 'supertest';
import express, { Request, Response, NextFunction } from 'express';

jest.mock('../../../services/invite.service');
jest.mock('../../../services/channel-link.service');

import * as inviteService from '../../../services/invite.service';
import router from '../invite.routes';

const mockService = inviteService as jest.Mocked<typeof inviteService>;

function buildApp(role: string) {
  const app = express();
  app.use(express.json());
  app.use((req: Request, _res: Response, next: NextFunction) => {
    const r = req as any;
    r.auth = { type: 'bot', companyId: 'comp1', userId: 'user1' };
    r.userContext = { userId: 'user1', userName: 'User', companyId: 'comp1', companyName: 'Co', role };
    next();
  });
  app.use('/', router);
  return app;
}

const body = (role: string) => ({ collaboratorName: 'New', role, phone: '+5548999999999' });

describe('bot invite.routes', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockService.createInviteWithWhatsAppLink.mockResolvedValue({
      code: 'INV_X',
      link: 'https://wa.me/x',
      expiresAt: new Date('2030-01-01T00:00:00.000Z'),
    });
  });

  describe('create', () => {
    it.each([
      ['owner', 'manager'],
      ['admin', 'manager'],
      ['admin', 'supervisor'],
      ['manager', 'supervisor'],
      ['manager', 'consultant'],
      ['manager', 'technician'],
      ['supervisor', 'technician'],
    ])('allows %s to invite %s', async (role, inviteRole) => {
      const res = await request(buildApp(role)).post('/create').send(body(inviteRole));
      expect(res.status).toBe(201);
      expect(mockService.createInviteWithWhatsAppLink).toHaveBeenCalled();
    });

    it.each([
      ['manager', 'manager'],
      ['supervisor', 'consultant'],
      ['supervisor', 'supervisor'],
      ['supervisor', 'manager'],
      ['consultant', 'technician'],
      ['technician', 'technician'],
    ])('does not allow %s to invite %s', async (role, inviteRole) => {
      const res = await request(buildApp(role)).post('/create').send(body(inviteRole));
      expect(res.status).toBe(403);
      expect(mockService.createInviteWithWhatsAppLink).not.toHaveBeenCalled();
    });
  });

  describe('accept', () => {
    it('responds 409 ALREADY_MEMBER for existing members', async () => {
      mockService.acceptInviteViaWhatsApp.mockResolvedValue({
        success: false,
        code: 'ALREADY_MEMBER',
        error: 'User is already a member of this company',
      });

      const res = await request(buildApp('technician'))
        .post('/accept')
        .send({ inviteCode: 'INV_ABC', whatsappNumber: '+5548999999999' });

      expect(res.status).toBe(409);
      expect(res.body.error.code).toBe('ALREADY_MEMBER');
    });

    it('keeps 400 INVALID_INVITE for other failures', async () => {
      mockService.acceptInviteViaWhatsApp.mockResolvedValue({ success: false, error: 'Invite has expired' });

      const res = await request(buildApp('technician'))
        .post('/accept')
        .send({ inviteCode: 'INV_ABC', whatsappNumber: '+5548999999999' });

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('INVALID_INVITE');
    });
  });
});
