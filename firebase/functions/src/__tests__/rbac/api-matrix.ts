/**
 * Role × route matrix for the app's HTTP API (/v1/app/*, Firebase ID token).
 *
 * Each case is one request made by a member of company c1 (or of company
 * `nofin`, which has `useFinancial: false`) and the roles that SHOULD be
 * allowed according to lib/models/permission.dart (golden copy in
 * app-permissions.json) and firebase/firestore.rules. Every other role must
 * get 403.
 *
 * `gap` documents a known difference: the server does not do what the app
 * and the rules say. Then `current` lists the roles the server allows today,
 * and rbac-api.test.ts asserts that current behavior. When someone fixes the
 * route, the test fails on purpose: delete `gap` and `current` from the case.
 *
 * The suite is rbac-api.test.ts (see the same pattern in firestore-matrix.ts).
 */

export const API_ROLES = ['owner', 'admin', 'supervisor', 'manager', 'consultant', 'technician'] as const;
export type ApiRole = (typeof API_ROLES)[number];

const MEMBERS: ApiRole[] = [...API_ROLES];
const ADMINS: ApiRole[] = ['owner', 'admin'];
const FINANCIAL: ApiRole[] = ['owner', 'admin', 'manager'];
const SEE_ALL_ORDERS: ApiRole[] = ['owner', 'admin', 'manager', 'supervisor'];
/** Roles with `write:orders` on the server (getRolePermissions). */
const SERVER_WRITE_ORDERS: ApiRole[] = ['owner', 'admin', 'supervisor', 'manager', 'consultant'];

export type CompanyKey = 'c1' | 'nofin';

export interface ApiCase {
  id: string;
  area: string;
  title: string;
  method: 'get' | 'post' | 'patch' | 'put' | 'delete';
  /** Full path as mounted in index.ts. `o1` is an order created by someone else (not assigned). */
  path: string;
  body?: Record<string, unknown>;
  /** Company of the request (X-Company-ID). Default 'c1'. 'nofin' has useFinancial: false. */
  company?: CompanyKey;
  /** Roles that SHOULD be allowed (permission.dart + firestore.rules). */
  allow: ApiRole[];
  /** PermissionType from permission.dart behind this action (checked against app-permissions.json). */
  permission?: string;
  /** Known difference between the server and the app/rules, in pt-BR, with the vulnerable code. */
  gap?: string;
  /** Roles the server allows TODAY (only with `gap`). */
  current?: ApiRole[];
}

const O = '/v1/app/orders';
const CU = '/v1/app/customers';
const NF = '/v1/app/nfse';

const receipt = { receiptId: 'r1', paidAt: '2026-10-20', allocations: [{ orderId: 'o1', amount: 10 }] };

export const API_CASES: ApiCase[] = [
  // ─── OS ────────────────────────────────────────────────────────────────
  {
    id: 'orders.list', area: 'OS', title: 'listar todas as OS (com total)',
    method: 'get', path: O,
    allow: SEE_ALL_ORDERS, permission: 'viewAllOrders',
    current: MEMBERS,
    gap: 'Consultor e técnico listam todas as OS da empresa, com total (orders.routes.ts:29, sem checar papel).',
  },
  {
    id: 'orders.get.others', area: 'OS', title: 'abrir OS de outra pessoa (com valores)',
    method: 'get', path: `${O}/o1`,
    allow: SEE_ALL_ORDERS, permission: 'viewAllOrders',
    current: MEMBERS,
    gap: 'Consultor e técnico abrem OS de outra pessoa com valores, desconto e pago (orders.routes.ts:87).',
  },
  {
    id: 'orders.create', area: 'OS', title: 'criar OS',
    method: 'post', path: O, body: { customerId: 'cust1' },
    allow: ['owner', 'admin', 'supervisor', 'consultant', 'technician'], permission: 'createOrder',
    current: MEMBERS,
    gap: 'O gerente cria OS pela API, e as regras e o app não deixam (orders.routes.ts:142).',
  },
  {
    id: 'orders.update.others', area: 'OS', title: 'mudar situação/responsável de OS de outra pessoa',
    method: 'patch', path: `${O}/o1`, body: { status: 'progress', assignedTo: 'tech1' },
    allow: SEE_ALL_ORDERS,
    current: MEMBERS,
    gap: 'Consultor e técnico mudam situação e responsável de OS que não podem abrir (orders.routes.ts:228).',
  },
  {
    id: 'orders.services.price', area: 'OS', title: 'pôr serviço com valor na OS',
    method: 'post', path: `${O}/o1/services`, body: { serviceId: 's1', value: 999 },
    allow: FINANCIAL, permission: 'editPrices',
    current: MEMBERS,
    gap: 'Qualquer membro muda o valor dos serviços da OS, sem editPrices (orders.routes.ts:304).',
  },
  {
    id: 'orders.products.price', area: 'OS', title: 'pôr produto com valor na OS',
    method: 'post', path: `${O}/o1/products`, body: { productId: 'p1', quantity: 1, value: 999 },
    allow: FINANCIAL, permission: 'editPrices',
    current: MEMBERS,
    gap: 'Qualquer membro muda o valor dos produtos da OS, sem editPrices (orders.routes.ts:367).',
  },
  {
    id: 'orders.payment', area: 'OS', title: 'lançar pagamento na OS',
    method: 'post', path: `${O}/o1/payments`, body: { amount: 10 },
    allow: FINANCIAL, permission: 'chargeOrder',
    current: MEMBERS,
    gap: 'Qualquer membro lança pagamento na OS, sem chargeOrder (orders.routes.ts:431).',
  },
  {
    id: 'orders.discount', area: 'OS', title: 'dar desconto na OS',
    method: 'post', path: `${O}/o1/payments`, body: { amount: 10, type: 'discount' },
    allow: FINANCIAL, permission: 'chargeOrder',
    current: MEMBERS,
    gap: 'Qualquer membro dá desconto na OS, sem chargeOrder (orders.routes.ts:431).',
  },

  // ─── Link do cliente ───────────────────────────────────────────────────
  {
    id: 'share.create.others', area: 'Link do cliente', title: 'criar link de OS de outra pessoa',
    method: 'post', path: `${O}/o1/share`, body: { permissions: ['view', 'approve'] },
    allow: SEE_ALL_ORDERS,
    current: MEMBERS,
    gap: 'Consultor e técnico criam link (com aprovar) de OS que não podem abrir e veem os valores na página pública (share.routes.ts:18).',
  },
  {
    id: 'share.list.others', area: 'Link do cliente', title: 'listar links de OS de outra pessoa',
    method: 'get', path: `${O}/o1/share`,
    allow: SEE_ALL_ORDERS,
    current: MEMBERS,
    gap: 'Consultor e técnico listam os links (tokens) de qualquer OS (share.routes.ts:110).',
  },
  {
    id: 'share.revoke.others', area: 'Link do cliente', title: 'revogar link de OS de outra pessoa',
    method: 'delete', path: `${O}/o1/share/t1`,
    allow: SEE_ALL_ORDERS,
    current: MEMBERS,
    gap: 'Consultor e técnico revogam o link de qualquer OS (share.routes.ts:157).',
  },

  // ─── Cobrança ──────────────────────────────────────────────────────────
  {
    id: 'orders.charge.create', area: 'Cobrança', title: 'gerar cobrança Asaas da OS',
    method: 'post', path: `${O}/o1/charges`, body: { value: 10, mode: 'single' },
    allow: FINANCIAL, permission: 'chargeOrder',
  },
  {
    id: 'orders.charge.cancel', area: 'Cobrança', title: 'cancelar cobrança Asaas da OS',
    method: 'delete', path: `${O}/o1/charges/ch1`,
    allow: FINANCIAL, permission: 'chargeOrder',
  },
  {
    id: 'customers.charge.create', area: 'Cobrança', title: 'gerar cobrança de várias OS do cliente',
    method: 'post', path: `${CU}/cust1/charges`, body: { orderIds: ['o1'], value: 10 },
    allow: FINANCIAL, permission: 'chargeOrder',
  },
  {
    id: 'customers.charge.cancel', area: 'Cobrança', title: 'cancelar cobrança de várias OS',
    method: 'delete', path: `${CU}/cust1/charges/ch1`,
    allow: FINANCIAL, permission: 'chargeOrder',
  },
  {
    // The consultant receives on the orders they handle (customer-receipt.service,
    // firestore.rules receipts.create); not tied to a single app permission.
    id: 'customers.receipt', area: 'Financeiro', title: 'registrar recebimento do cliente',
    method: 'post', path: `${CU}/cust1/receipts`, body: receipt,
    allow: ['owner', 'admin', 'manager', 'consultant'],
  },
  {
    id: 'customers.openOrders', area: 'Financeiro', title: 'ver OS em aberto do cliente para receber',
    method: 'get', path: `${CU}/cust1/open-orders`,
    allow: ['owner', 'admin', 'manager', 'consultant'],
  },
  {
    id: 'nfse.invoice.preview', area: 'Cobrança', title: 'prévia da nota fiscal',
    method: 'post', path: `${NF}/invoices/preview`, body: { orderIds: ['o1'] },
    allow: FINANCIAL, permission: 'chargeOrder',
  },
  {
    id: 'nfse.invoice.create', area: 'Cobrança', title: 'emitir nota fiscal',
    method: 'post', path: `${NF}/invoices`, body: { orderIds: ['o1'] },
    allow: FINANCIAL, permission: 'chargeOrder',
  },
  {
    id: 'nfse.invoice.cancel', area: 'Cobrança', title: 'cancelar nota fiscal',
    method: 'post', path: `${NF}/invoices/inv1/cancel`, body: {},
    allow: FINANCIAL, permission: 'chargeOrder',
  },

  // ─── Empresa sem valores (useFinancial: false) ─────────────────────────
  {
    id: 'nofin.orders.charge', area: 'Sem valores', title: 'gerar cobrança da OS com valores desligados',
    method: 'post', path: `${O}/o1/charges`, body: { value: 10, mode: 'single' }, company: 'nofin',
    allow: [],
    current: FINANCIAL,
    gap: 'Com "Valores e cobrança" desligado a API ainda gera cobrança Asaas (charges.routes.ts:48, não lê useFinancial).',
  },
  {
    id: 'nofin.customers.charge', area: 'Sem valores', title: 'gerar cobrança do cliente com valores desligados',
    method: 'post', path: `${CU}/cust1/charges`, body: { orderIds: ['o1'], value: 10 }, company: 'nofin',
    allow: [],
    current: FINANCIAL,
    gap: 'Com valores desligados a API ainda gera cobrança de várias OS (customer-payments.routes.ts:125).',
  },
  {
    id: 'nofin.nfse.invoice', area: 'Sem valores', title: 'emitir nota com valores desligados',
    method: 'post', path: `${NF}/invoices`, body: { orderIds: ['o1'] }, company: 'nofin',
    allow: [],
    current: FINANCIAL,
    gap: 'Com valores desligados a API ainda emite nota fiscal (nfse.routes.ts:178).',
  },
  {
    id: 'nofin.orders.payment', area: 'Sem valores', title: 'lançar pagamento com valores desligados',
    method: 'post', path: `${O}/o1/payments`, body: { amount: 10 }, company: 'nofin',
    allow: [],
    current: MEMBERS,
    gap: 'Com valores desligados qualquer membro lança pagamento na OS (orders.routes.ts:431).',
  },
  {
    id: 'nofin.customers.receipt', area: 'Sem valores', title: 'registrar recebimento com valores desligados',
    method: 'post', path: `${CU}/cust1/receipts`, body: receipt, company: 'nofin',
    allow: [],
  },

  // ─── Cadastros ─────────────────────────────────────────────────────────
  {
    id: 'customers.create', area: 'Cadastros', title: 'cadastrar cliente',
    method: 'post', path: CU, body: { name: 'Novo' },
    allow: ['owner', 'admin', 'supervisor', 'consultant'], permission: 'manageCustomers',
    current: MEMBERS,
    gap: 'Gerente e técnico cadastram cliente pela API (customers.routes.ts:119, sem checar papel).',
  },
  {
    id: 'customers.update', area: 'Cadastros', title: 'editar cliente',
    method: 'patch', path: `${CU}/cust1`, body: { name: 'Outro' },
    allow: ['owner', 'admin', 'supervisor', 'consultant'], permission: 'manageCustomers',
    current: MEMBERS,
    gap: 'Gerente e técnico editam cliente pela API (customers.routes.ts:173).',
  },
  {
    id: 'devices.create', area: 'Cadastros', title: 'cadastrar aparelho/veículo',
    method: 'post', path: '/v1/app/devices', body: { name: 'Uno' },
    allow: ['owner', 'admin', 'supervisor'], permission: 'manageDevices',
    current: MEMBERS,
    gap: 'Gerente, consultor e técnico cadastram aparelho/veículo pela API (devices.routes.ts:120).',
  },
  {
    id: 'devices.update', area: 'Cadastros', title: 'editar aparelho/veículo',
    method: 'patch', path: '/v1/app/devices/d1', body: { name: 'Uno 2' },
    allow: ['owner', 'admin', 'supervisor'], permission: 'manageDevices',
    current: MEMBERS,
    gap: 'Gerente, consultor e técnico editam aparelho/veículo pela API (devices.routes.ts:174).',
  },

  // ─── Equipe ────────────────────────────────────────────────────────────
  {
    id: 'invites.create', area: 'Equipe', title: 'convidar colaborador',
    method: 'post', path: '/v1/app/invites', body: { email: 'x@example.com', role: 'technician' },
    allow: ADMINS, permission: 'manageUsers',
  },
  {
    id: 'invites.list', area: 'Equipe', title: 'ver convites da empresa',
    method: 'get', path: '/v1/app/invites',
    allow: ADMINS, permission: 'manageUsers',
  },

  // ─── Integrações e configuração ────────────────────────────────────────
  {
    id: 'integrations.list', area: 'Integrações', title: 'ver chaves de integração (MCP)',
    method: 'get', path: '/v1/app/integrations/tokens',
    allow: ADMINS, permission: 'manageSettings',
  },
  {
    id: 'integrations.create', area: 'Integrações', title: 'criar chave de integração (MCP)',
    method: 'post', path: '/v1/app/integrations/tokens', body: { name: 'Claude' },
    allow: ADMINS, permission: 'manageSettings',
  },
  {
    id: 'integrations.revoke', area: 'Integrações', title: 'revogar chave de integração',
    method: 'delete', path: '/v1/app/integrations/tokens/k1',
    allow: ADMINS, permission: 'manageSettings',
  },
  {
    id: 'asaas.settings', area: 'Integrações', title: 'ver conexão com o Asaas',
    method: 'get', path: '/v1/app/payments/asaas/settings',
    allow: ADMINS, permission: 'manageSettings',
  },
  {
    id: 'asaas.connect', area: 'Integrações', title: 'ligar o Asaas',
    method: 'post', path: '/v1/app/payments/asaas/connect', body: { apiKey: 'test_key' },
    allow: ADMINS, permission: 'manageSettings',
  },
  {
    id: 'asaas.disconnect', area: 'Integrações', title: 'desligar o Asaas',
    method: 'delete', path: '/v1/app/payments/asaas/connect',
    allow: ADMINS, permission: 'manageSettings',
  },
  {
    id: 'nfse.setup.read', area: 'Integrações', title: 'ver configuração da nota fiscal',
    method: 'get', path: `${NF}/setup`,
    allow: ADMINS, permission: 'manageSettings',
  },
  {
    id: 'nfse.setup.fiscalInfo', area: 'Integrações', title: 'salvar dados fiscais',
    method: 'post', path: `${NF}/setup/fiscal-info`, body: { email: 'fiscal@example.com', simplesNacional: true },
    allow: ADMINS, permission: 'manageSettings',
  },
  {
    id: 'nfse.setup.municipal', area: 'Integrações', title: 'buscar serviço municipal',
    method: 'get', path: `${NF}/setup/municipal-services?q=manut`,
    allow: ADMINS, permission: 'manageSettings',
  },
  {
    id: 'nfse.setup.service', area: 'Integrações', title: 'salvar serviço da nota',
    method: 'put', path: `${NF}/setup/service`,
    body: {
      municipalServiceCode: '14.01', municipalServiceName: 'Manutenção',
      taxes: { retainIss: false, iss: 2, pis: 0, cofins: 0, csll: 0, inss: 0, ir: 0 },
    },
    allow: ADMINS, permission: 'manageSettings',
  },

  // ─── Assistente de IA ──────────────────────────────────────────────────
  {
    id: 'ai.status', area: 'IA', title: 'ver se a IA está ligada',
    method: 'get', path: '/v1/app/ai/status',
    allow: MEMBERS, permission: 'editOrder',
    current: SERVER_WRITE_ORDERS,
    gap: 'O técnico não usa a IA na OS (403), mas tem createOrder/editOrder no app (ai.routes.ts:35, write:orders).',
  },
  {
    id: 'ai.orderAssist', area: 'IA', title: 'preencher a OS com a IA',
    method: 'post', path: '/v1/app/ai/order-assist', body: { text: 'polimento' },
    allow: MEMBERS, permission: 'editOrder',
    current: SERVER_WRITE_ORDERS,
    gap: 'O técnico não usa a IA na OS (403), mas tem createOrder/editOrder no app (ai.routes.ts:53, write:orders).',
  },
];
