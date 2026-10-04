import request from 'supertest';
import express, { Request, Response, NextFunction } from 'express';

jest.mock('../../../services/invite.service');

import * as inviteService from '../../../services/invite.service';
import router from '../invite.routes';

const mockService = inviteService as jest.Mocked<typeof inviteService>;

function buildApp(email?: string) {
  const app = express();
  app.use(express.json());
  app.use((req: Request, _res: Response, next: NextFunction) => {
    const r = req as any;
    r.auth = { type: 'bearer', companyId: 'comp1', userId: 'user1', email };
    r.userContext = { userId: 'user1', userName: 'User', companyId: 'comp1', role: 'technician' };
    next();
  });
  app.use('/', router);
  return app;
}

describe('invite.routes accept', () => {
  beforeEach(() => jest.clearAllMocks());

  it('passes the verified caller email to the service', async () => {
    mockService.acceptInvite.mockResolvedValue({
      success: true,
      companyId: 'c9',
      companyName: 'Company 9',
      role: 'technician',
    });

    const res = await request(buildApp('user@example.com')).post('/INV_ABC/accept');

    expect(res.status).toBe(200);
    expect(mockService.acceptInvite).toHaveBeenCalledWith(
      'INV_ABC',
      'user1',
      'User',
      'user@example.com',
    );
    expect(res.body.data.companyId).toBe('c9');
  });

  it('responds 400 INVALID_INVITE for failures', async () => {
    mockService.acceptInvite.mockResolvedValue({
      success: false,
      error: 'Invite has expired',
    });

    const res = await request(buildApp('user@example.com')).post('/INV_ABC/accept');

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_INVITE');
  });
});
