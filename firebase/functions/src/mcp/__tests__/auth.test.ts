import { Response } from 'express';
import { AuthenticatedRequest } from '../../models/types';

const mockApiKeyGet = jest.fn();
const mockApiKeyUpdate = jest.fn();
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

import { LAST_USED_WRITE_INTERVAL_MS, mcpAuth, resetLastUsedThrottle } from '../auth';

function buildRes() {
  const res: Partial<Response> = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res as Response;
}

function snapshot(data: Record<string, unknown> | null) {
  if (!data) return { empty: true, docs: [] };
  return {
    empty: false,
    docs: [{ id: 'tok1', data: () => data, ref: { update: mockApiKeyUpdate } }],
  };
}

const flushPromises = () => new Promise((resolve) => setImmediate(resolve));

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
  beforeEach(() => {
    jest.clearAllMocks();
    resetLastUsedThrottle();
    mockApiKeyUpdate.mockResolvedValue(undefined);
  });

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
    expect(mockApiKeyUpdate).not.toHaveBeenCalled();
  });

  describe('lastUsedAt', () => {
    const authenticate = async (token: Record<string, unknown> = validToken) => {
      mockApiKeyGet.mockResolvedValue(snapshot(token));
      mockUserGet.mockResolvedValue(docSnapshot(validUser));
      mockCompanyGet.mockResolvedValue(docSnapshot(validCompany));
      const req = { params: { token: 'mcp_abc' } } as unknown as AuthenticatedRequest;
      const res = buildRes();
      const next = jest.fn();
      await mcpAuth(req, res, next);
      return { res, next };
    };

    const hoursAgo = (hours: number) => ({
      toDate: () => new Date(Date.now() - hours * 60 * 60 * 1000),
    });

    afterEach(() => jest.useRealTimers());

    it('grava lastUsedAt no primeiro uso', async () => {
      const { next } = await authenticate();

      expect(next).toHaveBeenCalled();
      expect(mockApiKeyUpdate).toHaveBeenCalledTimes(1);
      expect(mockApiKeyUpdate).toHaveBeenCalledWith({ lastUsedAt: expect.any(Date) });
    });

    it('não grava quando o último uso gravado tem menos de uma hora', async () => {
      await authenticate({ ...validToken, lastUsedAt: hoursAgo(0.5) });

      expect(mockApiKeyUpdate).not.toHaveBeenCalled();
    });

    it('grava quando o último uso gravado tem mais de uma hora', async () => {
      await authenticate({ ...validToken, lastUsedAt: hoursAgo(2) });

      expect(mockApiKeyUpdate).toHaveBeenCalledTimes(1);
    });

    it('grava no máximo uma vez por hora por token na mesma instância', async () => {
      jest.useFakeTimers({ now: new Date('2026-09-15T10:00:00Z') });

      // The stored doc still says "never used": only the in-memory guard holds.
      await authenticate();
      await authenticate();
      jest.setSystemTime(Date.now() + LAST_USED_WRITE_INTERVAL_MS - 1000);
      await authenticate();

      expect(mockApiKeyUpdate).toHaveBeenCalledTimes(1);

      jest.setSystemTime(Date.now() + 1000);
      await authenticate();

      expect(mockApiKeyUpdate).toHaveBeenCalledTimes(2);
    });

    it('não espera a escrita para seguir', async () => {
      mockApiKeyUpdate.mockReturnValue(new Promise(() => undefined));

      const { next } = await authenticate();

      expect(mockApiKeyUpdate).toHaveBeenCalled();
      expect(next).toHaveBeenCalled();
    });

    it('uma escrita rejeitada não derruba a autenticação nem vaza o token no log', async () => {
      const spy = jest.spyOn(console, 'error').mockImplementation(() => undefined);
      mockApiKeyUpdate.mockRejectedValue(new Error('unavailable'));

      const { res, next } = await authenticate();
      await flushPromises();

      expect(next).toHaveBeenCalled();
      expect(res.status).not.toHaveBeenCalled();
      expect(spy).toHaveBeenCalled();
      expect(JSON.stringify(spy.mock.calls)).not.toContain('mcp_abc');
      spy.mockRestore();
    });

    it('uma exceção síncrona na escrita não derruba a autenticação', async () => {
      const spy = jest.spyOn(console, 'error').mockImplementation(() => undefined);
      mockApiKeyUpdate.mockImplementation(() => {
        throw new Error('boom');
      });

      const { res, next } = await authenticate();

      expect(next).toHaveBeenCalled();
      expect(res.status).not.toHaveBeenCalled();
      spy.mockRestore();
    });
  });
});
