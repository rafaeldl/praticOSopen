import request from 'supertest';
import express, { Response } from 'express';

const validateShareToken = jest.fn();
const incrementViewCount = jest.fn();
jest.mock('../../services/share-token.service', () => ({
  validateShareToken: (...args: unknown[]) => validateShareToken(...args),
  incrementViewCount: (...args: unknown[]) => incrementViewCount(...args),
}));

import { shareTokenAuth, countsAsVisit } from '../share-token.middleware';
import { AuthenticatedRequest } from '../../models/types';

function buildApp() {
  const app = express();
  app.get('/:token', shareTokenAuth, (req: AuthenticatedRequest, res: Response) => {
    res.json({ orderId: req.shareTokenAuth?.orderId });
  });
  return app;
}

describe('shareTokenAuth view count', () => {
  beforeEach(() => {
    validateShareToken.mockReset().mockResolvedValue({
      token: 'ST_1', companyId: 'c1', orderId: 'o1',
      permissions: ['view', 'approve', 'comment'], customer: { id: 'cu1', name: 'Ana' },
    });
    incrementViewCount.mockReset().mockResolvedValue(undefined);
  });

  it('counts the customer opening the link', async () => {
    const res = await request(buildApp()).get('/ST_1');
    expect(res.status).toBe(200);
    expect(incrementViewCount).toHaveBeenCalledWith('ST_1');
  });

  it('does not count the team preview (?preview=1), but still serves the order', async () => {
    const res = await request(buildApp()).get('/ST_1?preview=1');
    expect(res.status).toBe(200);
    expect(res.body.orderId).toBe('o1');
    expect(incrementViewCount).not.toHaveBeenCalled();
  });

  it('preview flag does not let an invalid token through', async () => {
    validateShareToken.mockResolvedValue(null);
    const res = await request(buildApp()).get('/ST_bad?preview=1');
    expect(res.status).toBe(401);
    expect(incrementViewCount).not.toHaveBeenCalled();
  });

  it('only the exact preview=1 skips the count', () => {
    expect(countsAsVisit({ query: { preview: '1' } } as any)).toBe(false);
    expect(countsAsVisit({ query: { preview: 'true' } } as any)).toBe(true);
    expect(countsAsVisit({ query: {} } as any)).toBe(true);
  });
});
