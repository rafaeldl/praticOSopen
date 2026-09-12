import { Response } from 'express';
import { AuthenticatedRequest } from '../../models/types';

const mockGet = jest.fn();
jest.mock('../../services/firestore.service', () => ({
  db: {
    collection: () => ({
      where: () => ({
        where: () => ({
          limit: () => ({ get: mockGet }),
        }),
      }),
    }),
  },
}));

import { mcpAuth } from '../auth';

function buildRes() {
  const res: Partial<Response> = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res as Response;
}

function snapshot(data: Record<string, unknown> | null) {
  if (!data) return { empty: true, docs: [] };
  return { empty: false, docs: [{ id: 'tok1', data: () => data }] };
}

const validToken = {
  key: 'mcp_abc',
  companyId: 'comp1',
  userId: 'user1',
  permissions: ['read:all', 'write:all'],
  active: true,
  type: 'mcp',
};

describe('mcpAuth', () => {
  beforeEach(() => jest.clearAllMocks());

  it('preenche req.auth quando o token é válido', async () => {
    mockGet.mockResolvedValue(snapshot(validToken));
    const req = { params: { token: 'mcp_abc' } } as unknown as AuthenticatedRequest;
    const next = jest.fn();

    await mcpAuth(req, buildRes(), next);

    expect(next).toHaveBeenCalled();
    expect(req.auth).toEqual({
      type: 'mcp',
      companyId: 'comp1',
      userId: 'user1',
      permissions: ['read:all', 'write:all'],
    });
  });

  it('responde 401 quando o token não existe', async () => {
    mockGet.mockResolvedValue(snapshot(null));
    const req = { params: { token: 'mcp_nope' } } as unknown as AuthenticatedRequest;
    const res = buildRes();
    const next = jest.fn();

    await mcpAuth(req, res, next);

    expect(next).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(401);
  });

  it('responde 401 quando o token está expirado', async () => {
    mockGet.mockResolvedValue(
      snapshot({ ...validToken, expiresAt: new Date('2020-01-01') }),
    );
    const req = { params: { token: 'mcp_abc' } } as unknown as AuthenticatedRequest;
    const res = buildRes();
    const next = jest.fn();

    await mcpAuth(req, res, next);

    expect(next).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(401);
  });
});
