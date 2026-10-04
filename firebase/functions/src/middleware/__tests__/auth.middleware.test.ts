import { Response } from 'express';
import { AuthenticatedRequest } from '../../models/types';

const mockVerifyIdToken = jest.fn();
const mockUserGet = jest.fn();

jest.mock('../../services/firestore.service', () => ({
  auth: { verifyIdToken: (token: string) => mockVerifyIdToken(token) },
  db: {
    collection: (name: string) => {
      if (name === 'users') return { doc: () => ({ get: mockUserGet }) };
      throw new Error(`unexpected collection ${name}`);
    },
  },
}));

jest.mock('../../services/membership.service', () => ({
  verifyUserMemberships: jest.fn(),
}));

import { bearerAuth, getRolePermissions } from '../auth.middleware';
import { verifyUserMemberships } from '../../services/membership.service';

const mockVerify = verifyUserMemberships as jest.MockedFunction<typeof verifyUserMemberships>;

function buildRes() {
  const res: Partial<Response> = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res as Response;
}

function buildReq(headers: Record<string, string> = {}) {
  return {
    headers: { authorization: 'Bearer tok', ...headers },
  } as unknown as AuthenticatedRequest;
}

const userCompanies = [
  { company: { id: 'c1', name: 'Company 1' }, role: 'admin' },
  { company: { id: 'c2', name: 'Company 2' }, role: 'admin' },
];

describe('bearerAuth', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    jest.spyOn(console, 'log').mockImplementation(() => undefined);
    jest.spyOn(console, 'warn').mockImplementation(() => undefined);
    jest.spyOn(console, 'error').mockImplementation(() => undefined);
    mockVerifyIdToken.mockResolvedValue({ uid: 'u1', email: 'User@Example.com' });
    mockUserGet.mockResolvedValue({
      exists: true,
      data: () => ({ name: 'User', companies: userCompanies }),
    });
  });
  afterEach(() => jest.restoreAllMocks());

  it('requires a bearer token', async () => {
    const res = buildRes();
    const next = jest.fn();

    await bearerAuth({ headers: {} } as AuthenticatedRequest, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(next).not.toHaveBeenCalled();
  });

  it('uses the first verified company and its server-side role', async () => {
    mockVerify.mockResolvedValue([
      { companyId: 'c2', role: 'technician' },
    ]);
    const req = buildReq();
    const next = jest.fn();

    await bearerAuth(req, buildRes(), next);

    expect(mockVerify).toHaveBeenCalledWith('u1', userCompanies);
    expect(next).toHaveBeenCalled();
    expect(req.auth).toEqual({
      type: 'bearer',
      companyId: 'c2',
      userId: 'u1',
      email: 'User@Example.com',
      permissions: getRolePermissions('technician'),
    });
    expect(req.userContext).toEqual({
      userId: 'u1',
      userName: 'User',
      companyId: 'c2',
      companyName: 'Company 2',
      role: 'technician',
      permissions: getRolePermissions('technician'),
    });
  });

  it('selects the company from the X-Company-Id header when verified', async () => {
    mockVerify.mockResolvedValue([
      { companyId: 'c1', role: 'admin' },
      { companyId: 'c2', role: 'manager' },
    ]);
    const req = buildReq({ 'x-company-id': 'c2' });

    await bearerAuth(req, buildRes(), jest.fn());

    expect(req.userContext?.companyId).toBe('c2');
    expect(req.userContext?.role).toBe('manager');
  });

  it('responds 403 when the requested company is not verified', async () => {
    mockVerify.mockResolvedValue([{ companyId: 'c1', role: 'admin' }]);
    const res = buildRes();
    const next = jest.fn();

    await bearerAuth(buildReq({ 'x-company-id': 'c2' }), res, next);

    expect(next).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(403);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      error: { code: 'FORBIDDEN', message: 'No company access' },
    });
  });

  it('responds 403 when no company entry is verified', async () => {
    mockVerify.mockResolvedValue([]);
    const res = buildRes();
    const next = jest.fn();

    await bearerAuth(buildReq(), res, next);

    expect(next).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(403);
  });

  it('responds 401 when the user document does not exist', async () => {
    mockUserGet.mockResolvedValue({ exists: false, data: () => undefined });
    const res = buildRes();

    await bearerAuth(buildReq(), res, jest.fn());

    expect(res.status).toHaveBeenCalledWith(401);
    expect(mockVerify).not.toHaveBeenCalled();
  });

  it('responds 401 with TOKEN_EXPIRED for expired tokens', async () => {
    mockVerifyIdToken.mockRejectedValue({ code: 'auth/id-token-expired' });
    const res = buildRes();

    await bearerAuth(buildReq(), res, jest.fn());

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      error: { code: 'TOKEN_EXPIRED', message: 'Token has expired' },
    });
  });
});
