import { Response } from 'express';
import { AuthenticatedRequest } from '../../models/types';

const mockUserGet = jest.fn();
const mockCompanyGet = jest.fn();

jest.mock('../../services/firestore.service', () => ({
  db: {
    collection: (name: string) => {
      if (name === 'users') return { doc: () => ({ get: mockUserGet }) };
      if (name === 'companies') return { doc: () => ({ get: mockCompanyGet }) };
      return {};
    },
  },
}));

jest.mock('../../services/membership.service', () => ({
  verifyMembership: jest.fn(),
}));

import { resolveCompanyContext } from '../company.middleware';
import { getRolePermissions } from '../auth.middleware';
import { verifyMembership } from '../../services/membership.service';

const mockVerifyMembership = verifyMembership as jest.MockedFunction<typeof verifyMembership>;

function buildRes() {
  const res: Partial<Response> = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res as Response;
}

function docSnapshot(data: Record<string, unknown> | null) {
  return { exists: !!data, data: () => data };
}

const bearerReq = () =>
  ({
    auth: { type: 'bearer', companyId: 'comp1', userId: 'user1', permissions: [] },
  }) as unknown as AuthenticatedRequest;

const validUser = {
  name: 'John Doe',
  // Role written by the client; the effective role comes from server data
  companies: [{ company: { id: 'comp1', name: 'Company 1' }, role: 'admin' }],
};

describe('resolveCompanyContext', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    jest.spyOn(console, 'warn').mockImplementation(() => undefined);
    mockVerifyMembership.mockResolvedValue({ companyId: 'comp1', role: 'user' });
  });
  afterEach(() => jest.restoreAllMocks());

  it('segue direto quando userContext já existe', async () => {
    const req = { userContext: { userId: 'u' } } as unknown as AuthenticatedRequest;
    const next = jest.fn();

    await resolveCompanyContext(req, buildRes(), next);

    expect(next).toHaveBeenCalled();
    expect(mockUserGet).not.toHaveBeenCalled();
  });

  it('responde 401 sem auth', async () => {
    const res = buildRes();
    const next = jest.fn();

    await resolveCompanyContext({} as AuthenticatedRequest, res, next);

    expect(next).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(401);
  });

  it('monta contexto mínimo para apiKey', async () => {
    mockCompanyGet.mockResolvedValue(docSnapshot({ name: 'Company 1' }));
    const req = {
      auth: { type: 'apiKey', companyId: 'comp1', permissions: ['read:all'] },
    } as unknown as AuthenticatedRequest;
    const next = jest.fn();

    await resolveCompanyContext(req, buildRes(), next);

    expect(next).toHaveBeenCalled();
    expect(req.userContext).toEqual({
      userId: 'api_key_user',
      userName: 'API Integration',
      companyId: 'comp1',
      companyName: 'Company 1',
      role: 'admin',
      permissions: ['read:all'],
    });
  });

  describe('bearer', () => {
    it('monta userContext com o papel verificado no servidor (normalizado)', async () => {
      mockUserGet.mockResolvedValue(docSnapshot(validUser));
      mockCompanyGet.mockResolvedValue(docSnapshot({ name: 'Company 1' }));
      const req = bearerReq();
      const next = jest.fn();

      await resolveCompanyContext(req, buildRes(), next);

      expect(next).toHaveBeenCalled();
      expect(mockVerifyMembership).toHaveBeenCalledWith('user1', 'comp1', 'admin');
      expect(req.userContext).toEqual({
        userId: 'user1',
        userName: 'John Doe',
        companyId: 'comp1',
        companyName: 'Company 1',
        role: 'technician',
        permissions: getRolePermissions('technician'),
      });
    });

    it('usa strings vazias quando faltam nomes', async () => {
      mockUserGet.mockResolvedValue(
        docSnapshot({ companies: [{ company: { id: 'comp1' }, role: 'admin' }] }),
      );
      mockCompanyGet.mockResolvedValue(docSnapshot({}));
      const req = bearerReq();

      await resolveCompanyContext(req, buildRes(), jest.fn());

      expect(req.userContext?.userName).toBe('');
      expect(req.userContext?.companyName).toBe('');
    });

    it('responde 404 quando o usuário não existe, sem buscar a empresa', async () => {
      mockUserGet.mockResolvedValue(docSnapshot(null));
      const res = buildRes();
      const next = jest.fn();

      await resolveCompanyContext(bearerReq(), res, next);

      expect(next).not.toHaveBeenCalled();
      expect(mockCompanyGet).not.toHaveBeenCalled();
      expect(res.status).toHaveBeenCalledWith(404);
      expect(res.json).toHaveBeenCalledWith({
        success: false,
        error: { code: 'NOT_FOUND', message: 'User not found' },
      });
    });

    it('responde 404 quando a empresa não existe', async () => {
      mockUserGet.mockResolvedValue(docSnapshot(validUser));
      mockCompanyGet.mockResolvedValue(docSnapshot(null));
      const res = buildRes();
      const next = jest.fn();

      await resolveCompanyContext(bearerReq(), res, next);

      expect(next).not.toHaveBeenCalled();
      expect(res.status).toHaveBeenCalledWith(404);
      expect(res.json).toHaveBeenCalledWith({
        success: false,
        error: { code: 'NOT_FOUND', message: 'Company not found' },
      });
    });

    it('responde 403 quando o usuário não pertence à empresa', async () => {
      mockUserGet.mockResolvedValue(
        docSnapshot({ name: 'John', companies: [{ company: { id: 'other' }, role: 'admin' }] }),
      );
      mockCompanyGet.mockResolvedValue(docSnapshot({ name: 'Company 1' }));
      const res = buildRes();
      const next = jest.fn();

      await resolveCompanyContext(bearerReq(), res, next);

      expect(next).not.toHaveBeenCalled();
      expect(mockVerifyMembership).not.toHaveBeenCalled();
      expect(res.status).toHaveBeenCalledWith(403);
      expect(res.json).toHaveBeenCalledWith({
        success: false,
        error: { code: 'FORBIDDEN', message: 'User does not have access to this company' },
      });
    });

    it('responde 403 quando o vínculo não é confirmado no servidor', async () => {
      mockUserGet.mockResolvedValue(docSnapshot(validUser));
      mockCompanyGet.mockResolvedValue(docSnapshot({ name: 'Company 1' }));
      mockVerifyMembership.mockResolvedValue(null);
      const res = buildRes();
      const next = jest.fn();

      await resolveCompanyContext(bearerReq(), res, next);

      expect(next).not.toHaveBeenCalled();
      expect(res.status).toHaveBeenCalledWith(403);
      expect(res.json).toHaveBeenCalledWith({
        success: false,
        error: { code: 'FORBIDDEN', message: 'User does not have access to this company' },
      });
    });

    it('responde 403 quando o usuário não tem lista de empresas', async () => {
      mockUserGet.mockResolvedValue(docSnapshot({ name: 'John' }));
      mockCompanyGet.mockResolvedValue(docSnapshot({ name: 'Company 1' }));
      const res = buildRes();

      await resolveCompanyContext(bearerReq(), res, jest.fn());

      expect(res.status).toHaveBeenCalledWith(403);
    });

    it('responde 500 quando o Firestore falha', async () => {
      mockUserGet.mockRejectedValue(new Error('boom'));
      const res = buildRes();
      const spy = jest.spyOn(console, 'error').mockImplementation(() => undefined);

      await resolveCompanyContext(bearerReq(), res, jest.fn());

      expect(res.status).toHaveBeenCalledWith(500);
      spy.mockRestore();
    });
  });

  it('responde 401 para bearer sem userId', async () => {
    const req = {
      auth: { type: 'bearer', companyId: 'comp1', permissions: [] },
    } as unknown as AuthenticatedRequest;
    const res = buildRes();

    await resolveCompanyContext(req, res, jest.fn());

    expect(res.status).toHaveBeenCalledWith(401);
  });
});
