import { Response } from 'express';
import { AuthenticatedRequest } from '../../models/types';

const mockApiKeyGet = jest.fn();
const mockUserGet = jest.fn();
const mockCompanyGet = jest.fn();

jest.mock('../../services/firestore.service', () => ({
  db: {
    collection: (name: string) => {
      if (name === 'apiKeys') {
        return {
          where: () => ({
            limit: () => ({ get: mockApiKeyGet }),
          }),
        };
      }
      if (name === 'users') {
        return {
          doc: () => ({ get: mockUserGet }),
        };
      }
      if (name === 'companies') {
        return {
          doc: () => ({ get: mockCompanyGet }),
        };
      }
      return {};
    },
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

function docSnapshot(data: Record<string, unknown> | null) {
  return {
    exists: !!data,
    data: () => data,
  };
}

const validToken = {
  key: 'mcp_abc',
  companyId: 'comp1',
  userId: 'user1',
  permissions: ['read:all', 'write:all'],
  active: true,
  type: 'mcp',
};

const validUser = {
  name: 'John Doe',
  companies: [
    {
      company: { id: 'comp1', name: 'Company 1' },
      role: 'admin',
    },
  ],
};

const validCompany = {
  name: 'Company 1',
};

describe('mcpAuth', () => {
  beforeEach(() => jest.clearAllMocks());

  it('preenche req.auth quando o token é válido', async () => {
    mockApiKeyGet.mockResolvedValue(snapshot(validToken));
    mockUserGet.mockResolvedValue(docSnapshot(validUser));
    mockCompanyGet.mockResolvedValue(docSnapshot(validCompany));

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

  it('preenche req.userContext quando o token é válido', async () => {
    mockApiKeyGet.mockResolvedValue(snapshot(validToken));
    mockUserGet.mockResolvedValue(docSnapshot(validUser));
    mockCompanyGet.mockResolvedValue(docSnapshot(validCompany));

    const req = { params: { token: 'mcp_abc' } } as unknown as AuthenticatedRequest;
    const next = jest.fn();

    await mcpAuth(req, buildRes(), next);

    expect(next).toHaveBeenCalled();
    expect(req.userContext).toBeDefined();
    expect(req.userContext?.userId).toBe('user1');
    expect(req.userContext?.userName).toBe('John Doe');
    expect(req.userContext?.companyId).toBe('comp1');
    expect(req.userContext?.companyName).toBe('Company 1');
    expect(req.userContext?.role).toBeDefined();
  });

  it('responde 401 quando o token não existe', async () => {
    mockApiKeyGet.mockResolvedValue(snapshot(null));
    const req = { params: { token: 'mcp_nope' } } as unknown as AuthenticatedRequest;
    const res = buildRes();
    const next = jest.fn();

    await mcpAuth(req, res, next);

    expect(next).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(401);
  });

  it('responde 401 quando o token está expirado', async () => {
    mockApiKeyGet.mockResolvedValue(
      snapshot({
        ...validToken,
        expiresAt: { toDate: () => new Date('2020-01-01') },
      }),
    );
    mockUserGet.mockResolvedValue(docSnapshot(validUser));
    mockCompanyGet.mockResolvedValue(docSnapshot(validCompany));

    const req = { params: { token: 'mcp_abc' } } as unknown as AuthenticatedRequest;
    const res = buildRes();
    const next = jest.fn();

    await mcpAuth(req, res, next);

    expect(next).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(401);
  });

  it('responde 401 quando o token está inativo', async () => {
    mockApiKeyGet.mockResolvedValue(snapshot({ ...validToken, active: false }));
    const req = { params: { token: 'mcp_abc' } } as unknown as AuthenticatedRequest;
    const res = buildRes();
    const next = jest.fn();

    await mcpAuth(req, res, next);

    expect(next).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(401);
  });

  it('responde 401 quando o token não é do tipo mcp', async () => {
    mockApiKeyGet.mockResolvedValue(snapshot({ ...validToken, type: 'integration' }));
    const req = { params: { token: 'mcp_abc' } } as unknown as AuthenticatedRequest;
    const res = buildRes();
    const next = jest.fn();

    await mcpAuth(req, res, next);

    expect(next).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(401);
  });

  it('responde 401 quando a empresa não existe', async () => {
    mockApiKeyGet.mockResolvedValue(snapshot(validToken));
    mockUserGet.mockResolvedValue(docSnapshot(validUser));
    mockCompanyGet.mockResolvedValue(docSnapshot(null));

    const req = { params: { token: 'mcp_abc' } } as unknown as AuthenticatedRequest;
    const res = buildRes();
    const next = jest.fn();

    await mcpAuth(req, res, next);

    expect(next).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(401);
  });

  it('responde 401 quando o usuário não tem acesso à empresa', async () => {
    mockApiKeyGet.mockResolvedValue(snapshot(validToken));
    mockUserGet.mockResolvedValue(
      docSnapshot({
        name: 'John Doe',
        companies: [
          {
            company: { id: 'other-company', name: 'Other Company' },
            role: 'admin',
          },
        ],
      }),
    );
    mockCompanyGet.mockResolvedValue(docSnapshot(validCompany));

    const req = { params: { token: 'mcp_abc' } } as unknown as AuthenticatedRequest;
    const res = buildRes();
    const next = jest.fn();

    await mcpAuth(req, res, next);

    expect(next).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(401);
  });
});
