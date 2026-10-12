import request from 'supertest';
import express from 'express';
import { createAccountRouter, VerifiedIdToken } from '../account.routes';
import type { AccountDeletionDeps } from '../../../services/account-deletion.service';

const NOW = Date.UTC(2026, 9, 11, 12, 0, 0);
const NOW_SEC = NOW / 1000;

function fakeDeps(overrides: Partial<AccountDeletionDeps> = {}): AccountDeletionDeps {
  return {
    getUserCompanyIds: jest.fn().mockResolvedValue(['c1']),
    getCompany: jest.fn().mockResolvedValue({ exists: true, ownerId: 'u1' }),
    hasOtherMembers: jest.fn().mockResolvedValue(false),
    deleteStoragePrefix: jest.fn().mockResolvedValue(undefined),
    deleteCompanyTree: jest.fn().mockResolvedValue(undefined),
    leaveCompany: jest.fn().mockResolvedValue(undefined),
    deleteUserChannelLinks: jest.fn().mockResolvedValue(undefined),
    deleteUserTree: jest.fn().mockResolvedValue(undefined),
    deleteAuthUser: jest.fn().mockResolvedValue(true),
    ...overrides,
  };
}

function buildApp(deps: AccountDeletionDeps, token: Partial<VerifiedIdToken> | Error = {}) {
  const app = express();
  app.use(express.json());
  app.use(
    '/v1/app/account',
    createAccountRouter({
      verifyIdToken: jest.fn(async () => {
        if (token instanceof Error) throw token;
        return { uid: 'u1', auth_time: NOW_SEC - 30, ...token };
      }),
      depsFactory: () => deps,
      now: () => NOW,
    }),
  );
  return app;
}

beforeEach(() => {
  jest.spyOn(console, 'log').mockImplementation(() => undefined);
  jest.spyOn(console, 'warn').mockImplementation(() => undefined);
  jest.spyOn(console, 'error').mockImplementation(() => undefined);
});

afterEach(() => jest.restoreAllMocks());

describe('DELETE /v1/app/account', () => {
  it('deletes the account of the token uid (body is ignored)', async () => {
    const deps = fakeDeps();
    const res = await request(buildApp(deps))
      .delete('/v1/app/account')
      .set('Authorization', 'Bearer t')
      .send({ uid: 'someone-else' });

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ success: true, data: { deletedCompanies: 1, leftCompanies: 0 } });
    expect(deps.getUserCompanyIds).toHaveBeenCalledWith('u1');
    expect(deps.deleteAuthUser).toHaveBeenCalledWith('u1');
  });

  it('does not need X-Company-Id', async () => {
    const res = await request(buildApp(fakeDeps())).delete('/v1/app/account').set('Authorization', 'Bearer t');
    expect(res.status).toBe(200);
  });

  it('no bearer token → 401 UNAUTHORIZED', async () => {
    const deps = fakeDeps();
    const res = await request(buildApp(deps)).delete('/v1/app/account');
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('UNAUTHORIZED');
    expect(deps.getUserCompanyIds).not.toHaveBeenCalled();
  });

  it('invalid token → 401 UNAUTHORIZED', async () => {
    const res = await request(buildApp(fakeDeps(), new Error('bad')))
      .delete('/v1/app/account')
      .set('Authorization', 'Bearer t');
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('UNAUTHORIZED');
  });

  it('old sign-in → 401 REQUIRES_RECENT_LOGIN, nothing deleted', async () => {
    const deps = fakeDeps();
    const res = await request(buildApp(deps, { auth_time: NOW_SEC - 6 * 60 }))
      .delete('/v1/app/account')
      .set('Authorization', 'Bearer t');
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('REQUIRES_RECENT_LOGIN');
    expect(deps.getUserCompanyIds).not.toHaveBeenCalled();
    expect(deps.deleteAuthUser).not.toHaveBeenCalled();
  });

  it('owner with other members → 409 COMPANY_HAS_MEMBERS with the pt message', async () => {
    const deps = fakeDeps({ hasOtherMembers: jest.fn().mockResolvedValue(true) });
    const res = await request(buildApp(deps)).delete('/v1/app/account').set('Authorization', 'Bearer t');
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('COMPANY_HAS_MEMBERS');
    expect(res.body.error.message).toContain('proprietário de uma empresa com outros membros');
    expect(deps.deleteCompanyTree).not.toHaveBeenCalled();
  });

  it('unexpected failure → 500 INTERNAL_ERROR', async () => {
    const deps = fakeDeps({ deleteCompanyTree: jest.fn().mockRejectedValue(new Error('boom')) });
    const res = await request(buildApp(deps)).delete('/v1/app/account').set('Authorization', 'Bearer t');
    expect(res.status).toBe(500);
    expect(res.body.error.code).toBe('INTERNAL_ERROR');
  });
});
