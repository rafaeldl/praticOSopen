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
const RECEIVERS: ApiRole[] = ['owner', 'admin', 'manager', 'consultant'];
const ASSIGNERS: ApiRole[] = ['owner', 'admin', 'supervisor'];

export type CompanyKey = 'c1' | 'nofin';

export interface ApiCase {
  id: string;
  area: string;
  title: string;
  method: 'get' | 'post' | 'patch' | 'put' | 'delete';
  /**
   * Full path as mounted in index.ts. `o1` is an approved order created by
   * someone else (line `l1`, payment `t1`, discount `d1`), `quote_1` a quote
   * of someone else without money, `done_1` a done order; `r1` a receipt of
   * customer `cust1` registered by someone else (seeded in rbac-api.test.ts).
   */
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
const FI = '/v1/app/finance';

const receipt = { receiptId: 'r9', paidAt: '2026-10-20', allocations: [{ orderId: 'o1', amount: 10 }] };
const orderFile = { url: 'https://firebasestorage.googleapis.com/v0/b/praticos.appspot.com/o/tenants%2Fc1%2Forders%2Fo1%2Fpayments%2Ft1%2Ff.jpg?alt=media', storagePath: 'tenants/c1/orders/o1/payments/t1/f.jpg', contentType: 'image/jpeg' };
const receiptFile = { url: 'https://firebasestorage.googleapis.com/v0/b/praticos.appspot.com/o/tenants%2Fc1%2Freceipts%2Fr1%2Ff.pdf?alt=media', storagePath: 'tenants/c1/receipts/r1/f.pdf', contentType: 'application/pdf' };

export const API_CASES: ApiCase[] = [
  // ─── OS ────────────────────────────────────────────────────────────────
  {
    // Consultant and technician get the orders they created (orders.routes.test.ts checks the filter).
    id: 'orders.list', area: 'OS', title: 'listar OS (todas, ou as que criou)',
    method: 'get', path: O,
    allow: MEMBERS,
  },
  {
    id: 'orders.get.others', area: 'OS', title: 'abrir OS de outra pessoa (com valores)',
    method: 'get', path: `${O}/o1`,
    allow: SEE_ALL_ORDERS, permission: 'viewAllOrders',
  },
  {
    id: 'orders.create', area: 'OS', title: 'criar OS',
    method: 'post', path: O, body: { customerId: 'cust1' },
    allow: ['owner', 'admin', 'supervisor', 'consultant', 'technician'], permission: 'createOrder',
  },
  {
    id: 'orders.update.others', area: 'OS', title: 'mudar situação de OS de outra pessoa',
    method: 'patch', path: `${O}/o1`, body: { status: 'progress' },
    allow: SEE_ALL_ORDERS,
  },
  {
    id: 'orders.assign', area: 'OS', title: 'escolher o responsável da OS',
    method: 'patch', path: `${O}/o1`, body: { assignedTo: 'tech1' },
    allow: ASSIGNERS, permission: 'assignOrder',
  },
  {
    id: 'orders.dates.approved', area: 'OS', title: 'mudar a data de OS aprovada de outra pessoa',
    method: 'patch', path: `${O}/o1`, body: { scheduledDate: '2026-11-04T10:00:00.000Z' },
    allow: FINANCIAL,
  },
  {
    id: 'orders.delete.quote', area: 'OS', title: 'apagar orçamento de outra pessoa sem dinheiro',
    method: 'delete', path: `${O}/quote_1`,
    allow: SEE_ALL_ORDERS,
  },
  {
    id: 'orders.delete.approved', area: 'OS', title: 'apagar OS aprovada com dinheiro',
    method: 'delete', path: `${O}/o1`,
    allow: ADMINS,
  },
  {
    id: 'orders.hold.mark', area: 'OS', title: 'marcar OS como parada',
    method: 'post', path: `${O}/o1/hold`, body: { reason: 'part' },
    allow: SEE_ALL_ORDERS,
  },
  {
    id: 'orders.hold.resume', area: 'OS', title: 'retomar OS parada',
    method: 'delete', path: `${O}/o1/hold`,
    allow: SEE_ALL_ORDERS,
  },
  {
    id: 'orders.create.done', area: 'OS', title: 'criar OS já concluída',
    method: 'post', path: O, body: { customerId: 'cust1', status: 'done' },
    allow: ADMINS,
  },
  {
    id: 'orders.status.approveOthersQuote', area: 'OS', title: 'aprovar orçamento de outra pessoa',
    method: 'patch', path: `${O}/quote_1`, body: { status: 'approved' },
    allow: FINANCIAL,
  },
  {
    id: 'orders.status.cancelApproved', area: 'OS', title: 'cancelar OS aprovada',
    method: 'patch', path: `${O}/o1`, body: { status: 'canceled' },
    allow: FINANCIAL,
  },
  {
    id: 'orders.status.reopenDone', area: 'OS', title: 'reabrir OS concluída',
    method: 'patch', path: `${O}/done_1`, body: { status: 'progress' },
    allow: FINANCIAL,
  },
  {
    id: 'orders.services.approved', area: 'OS', title: 'pôr serviço em OS aprovada',
    method: 'post', path: `${O}/o1/services`, body: { serviceId: 's1' },
    allow: FINANCIAL,
  },
  {
    id: 'orders.products.approved', area: 'OS', title: 'pôr produto em OS aprovada',
    method: 'post', path: `${O}/o1/products`, body: { productId: 'p1', quantity: 1 },
    allow: FINANCIAL,
  },
  {
    id: 'orders.services.price', area: 'OS', title: 'pôr serviço com valor na OS',
    method: 'post', path: `${O}/o1/services`, body: { serviceId: 's1', value: 999 },
    allow: FINANCIAL, permission: 'editPrices',
  },
  {
    id: 'orders.products.price', area: 'OS', title: 'pôr produto com valor na OS',
    method: 'post', path: `${O}/o1/products`, body: { productId: 'p1', quantity: 1, value: 999 },
    allow: FINANCIAL, permission: 'editPrices',
  },
  {
    id: 'orders.items.add', area: 'OS', title: 'pôr item em OS aprovada',
    method: 'post', path: `${O}/o1/items`, body: { kind: 'service', catalogId: 's1' },
    allow: FINANCIAL,
  },
  {
    id: 'orders.items.price', area: 'OS', title: 'pôr item com valor próprio',
    method: 'post', path: `${O}/o1/items`, body: { kind: 'product', catalogId: 'p1', quantity: 1, value: 5 },
    allow: FINANCIAL, permission: 'editPrices',
  },
  {
    id: 'orders.items.note', area: 'OS', title: 'mudar a observação de item de OS aprovada',
    method: 'patch', path: `${O}/o1/items/l1`, body: { description: 'Com cera' },
    allow: SEE_ALL_ORDERS,
  },
  {
    id: 'orders.items.editPrice', area: 'OS', title: 'mudar o valor de um item',
    method: 'patch', path: `${O}/o1/items/l1`, body: { value: 90 },
    allow: FINANCIAL, permission: 'editPrices',
  },
  {
    id: 'orders.items.remove', area: 'OS', title: 'tirar item de OS aprovada',
    method: 'delete', path: `${O}/o1/items/l1`,
    allow: FINANCIAL,
  },
  {
    // Who receives: financial access, or the consultant on their own order (canReceiveOnOrder).
    id: 'orders.payment', area: 'OS', title: 'lançar pagamento na OS de outra pessoa',
    method: 'post', path: `${O}/o1/payments`, body: { amount: 10, paymentMethod: 'pix', receiptFile: orderFile },
    allow: FINANCIAL,
  },
  {
    id: 'orders.payment.remove', area: 'OS', title: 'tirar pagamento da OS',
    method: 'delete', path: `${O}/o1/payments/t1`,
    allow: FINANCIAL,
  },
  {
    id: 'orders.payment.markPaid', area: 'OS', title: 'marcar a OS como paga',
    method: 'post', path: `${O}/o1/payments/mark-paid`, body: {},
    allow: FINANCIAL,
  },
  {
    id: 'orders.payment.reset', area: 'OS', title: 'zerar pagamentos da OS',
    method: 'post', path: `${O}/o1/payments/reset`, body: {},
    allow: FINANCIAL, permission: 'viewFinancialReports',
  },
  {
    id: 'orders.payment.receipt', area: 'OS', title: 'anexar comprovante ao pagamento',
    method: 'put', path: `${O}/o1/payments/t1/receipt`, body: { receiptFile: orderFile },
    allow: FINANCIAL,
  },
  {
    id: 'orders.payment.receiptRemove', area: 'OS', title: 'tirar comprovante do pagamento',
    method: 'delete', path: `${O}/o1/payments/t1/receipt`,
    allow: FINANCIAL,
  },
  {
    id: 'orders.discount', area: 'OS', title: 'dar desconto na OS',
    method: 'post', path: `${O}/o1/discounts`, body: { amount: 10 },
    allow: FINANCIAL, permission: 'viewFinancialReports',
  },
  {
    id: 'orders.discount.remove', area: 'OS', title: 'tirar um desconto da OS',
    method: 'delete', path: `${O}/o1/discounts/d1`,
    allow: FINANCIAL, permission: 'viewFinancialReports',
  },
  {
    id: 'orders.discount.removeAll', area: 'OS', title: 'tirar todo o desconto da OS',
    method: 'delete', path: `${O}/o1/discounts`,
    allow: FINANCIAL, permission: 'viewFinancialReports',
  },

  // ─── Link do cliente ───────────────────────────────────────────────────
  {
    id: 'share.create.others', area: 'Link do cliente', title: 'criar link de OS de outra pessoa',
    method: 'post', path: `${O}/o1/share`, body: { permissions: ['view', 'approve'] },
    allow: SEE_ALL_ORDERS,
  },
  {
    id: 'share.list.others', area: 'Link do cliente', title: 'listar links de OS de outra pessoa',
    method: 'get', path: `${O}/o1/share`,
    allow: SEE_ALL_ORDERS,
  },
  {
    id: 'share.revoke.others', area: 'Link do cliente', title: 'revogar link de OS de outra pessoa',
    method: 'delete', path: `${O}/o1/share/t1`,
    allow: SEE_ALL_ORDERS,
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
    allow: RECEIVERS,
  },
  {
    // The consultant sees only the receipts they registered (orders.routes.test.ts).
    id: 'customers.receipts.list', area: 'Financeiro', title: 'ver recibos do cliente',
    method: 'get', path: `${CU}/cust1/receipts`,
    allow: RECEIVERS,
  },
  {
    id: 'customers.receipts.cancel', area: 'Financeiro', title: 'desfazer recibo de outra pessoa',
    method: 'post', path: `${CU}/cust1/receipts/r1/cancel`, body: {},
    allow: FINANCIAL,
  },
  {
    id: 'customers.receipts.file', area: 'Financeiro', title: 'anexar comprovante ao recibo de outra pessoa',
    method: 'put', path: `${CU}/cust1/receipts/r1/file`, body: { receiptFile },
    allow: FINANCIAL,
  },
  {
    id: 'customers.receipts.fileRemove', area: 'Financeiro', title: 'tirar comprovante do recibo de outra pessoa',
    method: 'delete', path: `${CU}/cust1/receipts/r1/file`,
    allow: FINANCIAL,
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
  },
  {
    id: 'nofin.customers.charge', area: 'Sem valores', title: 'gerar cobrança do cliente com valores desligados',
    method: 'post', path: `${CU}/cust1/charges`, body: { orderIds: ['o1'], value: 10 }, company: 'nofin',
    allow: [],
  },
  {
    id: 'nofin.nfse.invoice', area: 'Sem valores', title: 'emitir nota com valores desligados',
    method: 'post', path: `${NF}/invoices`, body: { orderIds: ['o1'] }, company: 'nofin',
    allow: [],
  },
  {
    id: 'nofin.orders.payment', area: 'Sem valores', title: 'lançar pagamento com valores desligados',
    method: 'post', path: `${O}/o1/payments`, body: { amount: 10 }, company: 'nofin',
    allow: [],
  },
  {
    id: 'nofin.customers.receipt', area: 'Sem valores', title: 'registrar recebimento com valores desligados',
    method: 'post', path: `${CU}/cust1/receipts`, body: receipt, company: 'nofin',
    allow: [],
  },
  {
    id: 'nofin.orders.discount', area: 'Sem valores', title: 'dar desconto com valores desligados',
    method: 'post', path: `${O}/o1/discounts`, body: { amount: 10 }, company: 'nofin',
    allow: [],
  },
  {
    id: 'nofin.orders.markPaid', area: 'Sem valores', title: 'marcar como paga com valores desligados',
    method: 'post', path: `${O}/o1/payments/mark-paid`, body: {}, company: 'nofin',
    allow: [],
  },
  {
    id: 'nofin.orders.price', area: 'Sem valores', title: 'pôr item com valor próprio com valores desligados',
    method: 'post', path: `${O}/o1/items`, body: { kind: 'service', catalogId: 's1', value: 5 }, company: 'nofin',
    allow: [],
  },
  {
    id: 'nofin.customers.receipts', area: 'Sem valores', title: 'ver recibos com valores desligados',
    method: 'get', path: `${CU}/cust1/receipts`, company: 'nofin',
    allow: [],
  },
  {
    id: 'nofin.finance.summary', area: 'Sem valores', title: 'ver o Financeiro com valores desligados',
    method: 'get', path: `${FI}/summary?month=2026-10`, company: 'nofin',
    allow: [],
  },
  {
    id: 'nofin.finance.report', area: 'Sem valores', title: 'ver o relatório com valores desligados',
    method: 'get', path: `${FI}/report?from=2026-10-01&to=2026-10-31`, company: 'nofin',
    allow: [],
  },

  // ─── Financeiro (web) ──────────────────────────────────────────────────
  {
    id: 'finance.summary', area: 'Financeiro', title: 'ver Recebido, Vendido, A receber e Em andamento',
    method: 'get', path: `${FI}/summary?month=2026-10`, allow: FINANCIAL, permission: 'viewFinancialReports',
  },
  {
    id: 'finance.report', area: 'Financeiro', title: 'ver o relatório do período',
    method: 'get', path: `${FI}/report?from=2026-10-01&to=2026-10-31`, allow: FINANCIAL, permission: 'viewFinancialReports',
  },
  {
    id: 'finance.receivable', area: 'Financeiro', title: 'ver o que falta receber',
    method: 'get', path: `${FI}/receivable`, allow: FINANCIAL, permission: 'viewFinancialReports',
  },

  // ─── Cadastros ─────────────────────────────────────────────────────────
  {
    id: 'customers.create', area: 'Cadastros', title: 'cadastrar cliente',
    method: 'post', path: CU, body: { name: 'Novo' },
    allow: ['owner', 'admin', 'supervisor', 'consultant'], permission: 'manageCustomers',
  },
  {
    id: 'customers.update', area: 'Cadastros', title: 'editar cliente',
    method: 'patch', path: `${CU}/cust1`, body: { name: 'Outro' },
    allow: ['owner', 'admin', 'supervisor', 'consultant'], permission: 'manageCustomers',
  },
  {
    id: 'devices.create', area: 'Cadastros', title: 'cadastrar aparelho/veículo',
    method: 'post', path: '/v1/app/devices', body: { name: 'Uno' },
    allow: ['owner', 'admin', 'supervisor'], permission: 'manageDevices',
  },
  {
    id: 'devices.update', area: 'Cadastros', title: 'editar aparelho/veículo',
    method: 'patch', path: '/v1/app/devices/d1', body: { name: 'Uno 2' },
    allow: ['owner', 'admin', 'supervisor'], permission: 'manageDevices',
  },
  {
    id: 'customers.list', area: 'Cadastros', title: 'ver clientes',
    method: 'get', path: CU, allow: MEMBERS, permission: 'viewCustomers',
  },
  {
    id: 'customers.detail', area: 'Cadastros', title: 'abrir cliente',
    method: 'get', path: `${CU}/cust1`, allow: MEMBERS, permission: 'viewCustomers',
  },
  {
    id: 'customers.delete', area: 'Cadastros', title: 'apagar cliente',
    method: 'delete', path: `${CU}/cust1`,
    allow: ['owner', 'admin', 'supervisor', 'consultant'], permission: 'manageCustomers',
  },
  {
    id: 'customers.import', area: 'Cadastros', title: 'importar clientes de planilha',
    method: 'post', path: `${CU}/import`, body: { importId: 'imp-00000001', customers: [{ name: 'Rita' }] },
    allow: ['owner', 'admin', 'supervisor', 'consultant'], permission: 'manageCustomers',
  },
  {
    id: 'devices.list', area: 'Cadastros', title: 'ver aparelhos/veículos',
    method: 'get', path: '/v1/app/devices', allow: MEMBERS, permission: 'viewDevices',
  },
  {
    id: 'devices.detail', area: 'Cadastros', title: 'abrir aparelho/veículo',
    method: 'get', path: '/v1/app/devices/d1', allow: MEMBERS, permission: 'viewDevices',
  },
  {
    id: 'devices.delete', area: 'Cadastros', title: 'apagar aparelho/veículo',
    method: 'delete', path: '/v1/app/devices/d1', allow: ['owner', 'admin', 'supervisor'], permission: 'manageDevices',
  },
  {
    id: 'devices.maintenance', area: 'Cadastros', title: 'marcar a próxima manutenção',
    method: 'put', path: '/v1/app/devices/d1/next-maintenance', body: { date: '2099-01-01' },
    allow: ['owner', 'admin', 'supervisor'], permission: 'manageDevices',
  },

  // ─── Catálogo (web) ────────────────────────────────────────────────────
  {
    id: 'catalog.services.list', area: 'Catálogo', title: 'ver serviços',
    method: 'get', path: '/v1/app/services', allow: ['owner', 'admin', 'supervisor', 'manager', 'consultant'], permission: 'viewServices',
  },
  {
    id: 'catalog.products.list', area: 'Catálogo', title: 'ver produtos',
    method: 'get', path: '/v1/app/products', allow: ['owner', 'admin', 'supervisor', 'manager', 'consultant'], permission: 'viewProducts',
  },
  {
    id: 'catalog.services.create', area: 'Catálogo', title: 'cadastrar serviço',
    method: 'post', path: '/v1/app/services', body: { name: 'Novo' }, allow: ADMINS, permission: 'manageServices',
  },
  {
    id: 'catalog.products.create', area: 'Catálogo', title: 'cadastrar produto',
    method: 'post', path: '/v1/app/products', body: { name: 'Novo' }, allow: ADMINS, permission: 'manageProducts',
  },
  {
    id: 'catalog.services.price', area: 'Catálogo', title: 'mudar o preço do serviço (manageServices e editPrices)',
    method: 'patch', path: '/v1/app/services/s1', body: { value: 90 }, allow: ADMINS, permission: 'manageServices',
  },
  {
    id: 'catalog.products.delete', area: 'Catálogo', title: 'apagar produto',
    method: 'delete', path: '/v1/app/products/p1', allow: ADMINS, permission: 'manageProducts',
  },
  {
    id: 'catalog.services.import', area: 'Catálogo', title: 'importar serviços de planilha',
    method: 'post', path: '/v1/app/services/import', body: { importId: 'imp-00000001', items: [{ name: 'Rita' }] }, allow: ADMINS, permission: 'manageServices',
  },
  {
    id: 'catalog.services.prices', area: 'Catálogo', title: 'mudar preços em lote (manageServices e editPrices)',
    method: 'post', path: '/v1/app/services/prices', body: { changes: [{ id: 's1', from: 80, to: 88 }] }, allow: ADMINS, permission: 'manageServices',
  },
  {
    id: 'nofin.catalog.price', area: 'Sem valores', title: 'pôr preço no catálogo com valores desligados',
    method: 'post', path: '/v1/app/services', body: { name: 'Novo', value: 10 }, company: 'nofin',
    allow: [],
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
  },
  {
    id: 'ai.orderAssist', area: 'IA', title: 'preencher a OS com a IA',
    method: 'post', path: '/v1/app/ai/order-assist', body: { text: 'polimento' },
    allow: MEMBERS, permission: 'editOrder',
  },
];
