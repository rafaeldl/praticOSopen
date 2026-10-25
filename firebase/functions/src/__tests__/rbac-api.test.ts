/**
 * Role × route matrix for the app's HTTP API (cases in rbac/api-matrix.ts).
 *
 * The routers are mounted as in index.ts behind the REAL bearerAuth and
 * resolveCompanyContext, over the in-memory Firestore; only verifyIdToken
 * (token = uid) and the services that write or call Asaas/LLMs are faked, so
 * the role and company come from the same server-side data as in production.
 *
 * For each case and role: allowed → success, denied → 403. A case with `gap`
 * asserts what the server does TODAY (`current`); when the route is fixed the
 * test fails on purpose: remove `gap`/`current` from the case.
 */

import request from 'supertest';
import express, { Express, Request, Response, NextFunction } from 'express';

jest.mock('../services/firestore.service', () => ({
  ...jest.requireActual('./helpers/fake-firestore').firestoreServiceMock,
  // Test token = uid.
  auth: { verifyIdToken: async (token: string) => ({ uid: token }) },
}));

jest.mock('../services/order.service', () => ({
  ...jest.requireActual('../services/order.service'),
  listOrders: jest.fn(async () => ({ data: [], total: 0, hasMore: false })),
  getOrder: jest.fn(async (_c: string, id: string) => ({
    id, number: 1, status: 'approved', total: 100, discount: 0, paidAmount: 0,
    customer: { id: 'cust1', name: 'Ana', phone: '+5511999990000' },
    createdBy: { id: 'ghost', name: 'Ghost' },
  })),
  createOrder: jest.fn(async () => ({ id: 'new1', number: 2, status: 'quote' })),
  updateOrder: jest.fn(async () => true),
  addOrderService: jest.fn(async () => ({ success: true, newTotal: 999 })),
  addOrderProduct: jest.fn(async () => ({ success: true, newTotal: 999 })),
  addPayment: jest.fn(async () => ({ paidAmount: 10 })),
  updateOrderShareLink: jest.fn(async () => undefined),
}));

jest.mock('../services/customer.service', () => ({
  ...jest.requireActual('../services/customer.service'),
  getCustomer: jest.fn(async () => ({ id: 'cust1', name: 'Ana' })),
  createCustomer: jest.fn(async () => ({ id: 'cust2', customer: { name: 'Novo' } })),
  updateCustomer: jest.fn(async () => true),
}));

jest.mock('../services/device.service', () => ({
  ...jest.requireActual('../services/device.service'),
  createDevice: jest.fn(async () => ({ id: 'd2', device: { name: 'Uno' } })),
  updateDevice: jest.fn(async () => true),
}));

jest.mock('../services/share-token.service', () => ({
  generateShareToken: jest.fn(async () => ({ token: 't1', permissions: ['view'], expiresAt: '2030-01-01T00:00:00Z' })),
  getTokensForOrder: jest.fn(async () => []),
  getShareToken: jest.fn(async (token: string) => ({ token, companyId: 'c1', orderId: 'o1' })),
  revokeShareToken: jest.fn(async () => undefined),
}));

jest.mock('../services/asaas/charge.service', () => ({
  createOrderCharge: jest.fn(async () => ({ id: 'ch1' })),
  cancelOrderCharge: jest.fn(async () => ({ id: 'ch1' })),
}));

jest.mock('../services/asaas/customer-charge.service', () => ({
  ...jest.requireActual('../services/asaas/customer-charge.service'),
  createCustomerCharge: jest.fn(async () => ({ id: 'ch1' })),
  cancelCustomerCharge: jest.fn(async () => ({ id: 'ch1' })),
  publicCustomerCharge: jest.fn((charge: unknown) => charge),
}));

jest.mock('../services/customer-receipt.service', () => ({
  ...jest.requireActual('../services/customer-receipt.service'),
  registerCustomerReceipt: jest.fn(async () => ({ receiptId: 'r1' })),
  listCustomerOpenOrders: jest.fn(async () => []),
}));

jest.mock('../services/invite.service', () => ({
  ...jest.requireActual('../services/invite.service'),
  createInvite: jest.fn(async () => ({ token: 'inv1', expiresAt: '2030-01-01T00:00:00Z' })),
  listByCompany: jest.fn(async () => []),
}));

jest.mock('../services/integration-token.service', () => ({
  listIntegrationTokens: jest.fn(async () => []),
  createIntegrationToken: jest.fn(async () => ({ id: 'k1' })),
  revokeIntegrationToken: jest.fn(async () => true),
}));

jest.mock('../services/asaas/connection.service', () => ({
  ...jest.requireActual('../services/asaas/connection.service'),
  getPaymentSettings: jest.fn(async () => ({ connected: true })),
  connectAsaas: jest.fn(async () => ({ connected: true })),
  disconnectAsaas: jest.fn(async () => undefined),
}));

jest.mock('../services/asaas/invoice.service', () => ({
  ...jest.requireActual('../services/asaas/invoice.service'),
  previewInvoice: jest.fn(async () => ({ value: 10 })),
  createInvoice: jest.fn(async () => ({ id: 'inv1' })),
  cancelInvoice: jest.fn(async () => ({ id: 'inv1' })),
}));

jest.mock('../services/asaas/nfse-setup.service', () => ({
  getNfseSetup: jest.fn(async () => ({})),
  saveFiscalInfo: jest.fn(async () => ({})),
  searchMunicipalServices: jest.fn(async () => []),
  saveNfseService: jest.fn(async () => ({})),
}));

// No LLM call: fixed answer, quota always free.
jest.mock('../services/ai/order-assist.deps', () => ({
  defaultOrderAssistDeps: () => ({
    llm: { generateJson: async () => '{"operations":[{"action":"add","kind":"service","name":"Polimento"}]}' },
    getSettings: async () => ({ enabled: true }),
    getUsage: async () => ({ used: 0, limit: 10 }),
    reserve: async () => ({ ok: true, used: 1, limit: 10, monthKey: '2026-10' }),
    release: async () => undefined,
    loadCatalog: async () => ({ services: [{ id: 's1', name: 'Polimento', value: 450 }], products: [] }),
    findCustomers: async () => [],
    findDevices: async () => [],
  }),
}));

import { resetFakeDb, seed } from './helpers/fake-firestore';
import { apiKeyAuth, bearerAuth } from '../middleware/auth.middleware';
import { resolveCompanyContext } from '../middleware/company.middleware';
import ordersRoutes from '../routes/v1/orders.routes';
import shareRoutes from '../routes/v1/share.routes';
import chargesRoutes from '../routes/v1/charges.routes';
import customersRoutes from '../routes/v1/customers.routes';
import customerPaymentsRoutes from '../routes/v1/customer-payments.routes';
import devicesRoutes from '../routes/v1/devices.routes';
import appInviteRoutes from '../routes/v1/invite.routes';
import integrationsRoutes from '../routes/v1/integrations.routes';
import asaasConnectionRoutes from '../routes/v1/asaas-connection.routes';
import nfseRoutes from '../routes/v1/nfse.routes';
import aiRoutes from '../routes/v1/ai.routes';
import appPermissions from './rbac/app-permissions.json';
import { API_CASES, API_ROLES, type ApiCase, type ApiRole, type CompanyKey } from './rbac/api-matrix';

const UID: Record<ApiRole, string> = {
  owner: 'owner1', admin: 'admin1', supervisor: 'sup1', manager: 'mgr1', consultant: 'cons1', technician: 'tech1',
};
const COMPANIES: Record<CompanyKey, Record<string, unknown>> = {
  c1: { name: 'Company c1', owner: { id: 'owner1', name: 'Owner' } },
  nofin: { name: 'Sem valores', owner: { id: 'owner1', name: 'Owner' }, useFinancial: false },
};

function seedTenants() {
  resetFakeDb();
  const members = Object.fromEntries(API_ROLES.filter((r) => r !== 'owner').map((r) => [UID[r], r]));
  for (const [cid, data] of Object.entries(COMPANIES)) {
    seed(`companies/${cid}`, data);
    seed(`companies/${cid}/private/membership`, { members });
  }
  for (const role of API_ROLES) {
    seed(`users/${UID[role]}`, {
      name: role,
      companies: Object.keys(COMPANIES).map((cid) => ({ company: { id: cid, name: cid }, role })),
    });
  }
}

/** Same mounts, order and middleware as index.ts (rate limiters left out). */
function buildApp(): Express {
  const app = express();
  app.use(express.json());
  app.use('/v1/app/orders', bearerAuth, resolveCompanyContext, ordersRoutes, shareRoutes, chargesRoutes);
  app.use('/v1/app/customers', bearerAuth, resolveCompanyContext, customerPaymentsRoutes, customersRoutes);
  app.use('/v1/app/devices', bearerAuth, resolveCompanyContext, devicesRoutes);
  app.use('/v1/app/invites', bearerAuth, resolveCompanyContext, appInviteRoutes);
  app.use('/v1/app/integrations', bearerAuth, resolveCompanyContext, integrationsRoutes);
  app.use('/v1/app/payments/asaas', bearerAuth, resolveCompanyContext, asaasConnectionRoutes);
  app.use('/v1/app/nfse', bearerAuth, resolveCompanyContext, nfseRoutes);
  app.use('/v1/app/ai', bearerAuth, resolveCompanyContext, aiRoutes);
  return app;
}

function send(app: Express, c: ApiCase, role: ApiRole, company: CompanyKey = c.company ?? 'c1') {
  const req = request(app)[c.method](c.path)
    .set('Authorization', `Bearer ${UID[role]}`)
    .set('X-Company-ID', company);
  return c.body ? req.send(c.body) : req;
}

const expectedAllow = (c: ApiCase): ApiRole[] => (c.gap ? c.current ?? [] : c.allow);

let app: Express;
let logSpies: jest.SpyInstance[];

beforeAll(() => {
  app = buildApp();
  logSpies = (['log', 'warn', 'error'] as const).map((m) => jest.spyOn(console, m).mockImplementation(() => undefined));
});
afterAll(() => logSpies.forEach((s) => s.mockRestore()));
beforeEach(seedTenants);

describe('API RBAC matrix (offline checks)', () => {
  type AppRole = keyof typeof appPermissions.roles;
  const appRoleOf = (role: ApiRole): AppRole => (role === 'owner' ? 'admin' : role);
  const known = new Set(Object.values(appPermissions.roles).flat());

  it('case ids are unique', () => {
    const ids = API_CASES.map((c) => c.id);
    expect(ids.filter((id, i) => ids.indexOf(id) !== i)).toEqual([]);
  });

  it("'owner' keeps every power of 'admin'", () => {
    expect(API_CASES.filter((c) => c.allow.includes('admin') !== c.allow.includes('owner')).map((c) => c.id)).toEqual([]);
  });

  it('every gap says what the server allows today, and differs from what it should', () => {
    const bad = API_CASES.filter((c) => (c.gap ? !c.current || sameSet(c.current, c.allow) : !!c.current));
    expect(bad.map((c) => c.id)).toEqual([]);
  });

  for (const c of API_CASES.filter((x) => x.permission && x.company !== 'nofin')) {
    it(`${c.id}: allow follows ${c.permission} in permission.dart`, () => {
      expect(known.has(c.permission!)).toBe(true);
      const app = API_ROLES.filter((r) => (appPermissions.roles[appRoleOf(r)] as string[]).includes(c.permission!));
      expect([...c.allow].sort()).toEqual(app.sort());
    });
  }
});

describe('API RBAC matrix: positive control (admin of c1 succeeds on every route)', () => {
  it.each(API_CASES.map((c) => [c.id, c] as const))('%s', async (_id, c) => {
    const res = await send(app, c, 'admin', 'c1');
    // A broken harness (401/404/500) must not pass for a 403 in the matrix.
    expect({ id: c.id, result: res.status < 400 ? 'ok' : { status: res.status, body: res.body } })
      .toEqual({ id: c.id, result: 'ok' });
  });
});

describe('API RBAC matrix', () => {
  for (const c of API_CASES) {
    describe(`[${c.area}] ${c.title} (${c.method.toUpperCase()} ${c.path}${c.company === 'nofin' ? ', valores desligados' : ''})`, () => {
      it.each(API_ROLES.map((r) => [r]))('%s', async (role) => {
        const res = await send(app, c, role);
        const allowed = expectedAllow(c).includes(role);
        const got = res.status < 400 ? 'allowed' : res.status === 403 ? 'denied' : `error ${res.status}`;
        const want = allowed ? 'allowed' : 'denied';
        const hint = c.gap
          ? got !== want && (c.allow.includes(role) ? 'allowed' : 'denied') === got
            ? `GAP FECHADO? "${c.id}" agora segue o app para ${role}: tire gap/current do caso em rbac/api-matrix.ts (${c.gap})`
            : `gap: ${c.gap}`
          : '';
        expect({ case: c.id, role, result: got, hint: got === want ? '' : hint })
          .toEqual({ case: c.id, role, result: want, hint: '' });
      });
    });
  }
});

describe('Known auth gaps outside the matrix', () => {
  it('GAP bug 1: botAuth accepts the public fallback key when BOT_API_KEY is unset (auth.middleware.ts:16)', async () => {
    const saved = process.env.BOT_API_KEY;
    delete process.env.BOT_API_KEY;
    try {
      let botAuth!: typeof import('../middleware/auth.middleware').botAuth;
      let isolatedSeed!: typeof seed;
      jest.isolateModules(() => {
        // eslint-disable-next-line @typescript-eslint/no-require-imports
        botAuth = require('../middleware/auth.middleware').botAuth;
        // The isolated registry has its own fake db: seed that one.
        // eslint-disable-next-line @typescript-eslint/no-require-imports
        const isolatedDb = require('../services/firestore.service').db;
        isolatedSeed = (path, data) => isolatedDb.seed(path, data);
      });
      for (const [cid, data] of Object.entries(COMPANIES)) isolatedSeed(`companies/${cid}`, data);
      isolatedSeed('companies/c1/private/membership', { members: { admin1: 'admin' } });
      isolatedSeed('links/whatsapp/numbers/+5511999990000', {
        userId: 'admin1', companyId: 'c1', role: 'admin', userName: 'Admin', companyName: 'Company c1',
      });

      const bot = express();
      bot.use(botAuth, (req: Request, res: Response, _next: NextFunction) => {
        res.json({ role: (req as { userContext?: { role?: string } }).userContext?.role ?? null });
      });

      const wrong = await request(bot).get('/').set('X-API-Key', 'nope');
      expect(wrong.status).toBe(401); // control: the check runs

      const res = await request(bot).get('/')
        .set('X-API-Key', 'bot_praticos_dev_key')
        .set('X-WhatsApp-Number', '+55 11 99999-0000');
      // When fixed (fail closed without BOT_API_KEY), expect 401/500 here and drop "GAP" from the title.
      expect({ status: res.status, role: res.body.role, hint: 'GAP: chave padrão pública vira o usuário ligado ao número' })
        .toEqual({ status: 200, role: 'admin', hint: expect.any(String) });
    } finally {
      if (saved === undefined) delete process.env.BOT_API_KEY;
      else process.env.BOT_API_KEY = saved;
    }
  });

  it('GAP bug 4: apiKeyAuth accepts an MCP token as a full API key, as admin, without re-checking membership (auth.middleware.ts:47)', async () => {
    // Token minted by someone who is no longer in the company (no membership, no user doc).
    seed('apiKeys/k1', {
      key: 'mcp_abc', type: 'mcp', active: true, companyId: 'c1', userId: 'gone1', name: 'Claude',
      permissions: ['read:all', 'write:all'],
    });
    const api = express();
    api.use(express.json());
    api.use('/v1/customers', apiKeyAuth, resolveCompanyContext, customersRoutes);

    const unknown = await request(api).post('/v1/customers').set('X-API-Key', 'mcp_nope').send({ name: 'X' });
    expect(unknown.status).toBe(401); // control: the check runs

    const res = await request(api).post('/v1/customers').set('X-API-Key', 'mcp_abc').send({ name: 'X' });
    // When fixed (apiKeyAuth rejects type 'mcp'), expect 401 here and drop "GAP" from the title.
    expect({ status: res.status, hint: 'GAP: token MCP de quem saiu da empresa escreve em /v1/* como admin' })
      .toEqual({ status: 201, hint: expect.any(String) });
  });
});

function sameSet(a: ApiRole[], b: ApiRole[]) {
  return a.length === b.length && a.every((x) => b.includes(x));
}
