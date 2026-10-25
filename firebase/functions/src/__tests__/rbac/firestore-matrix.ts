/**
 * Role × action matrix for firestore.rules.
 *
 * Each case is one client operation in company c1 and the list of actors the
 * rules must allow; every other actor must be denied. The suite
 * (rbac-firestore.rules.test.ts) runs every case for every actor, and
 * rbac-app-consistency.test.ts compares `allow` with the app's
 * RolePermissions (app-permissions.json) for cases that name a `permission`.
 *
 * `gap` documents a known, accepted difference between the app and the rules
 * (the app hides something the rules still allow, or the reverse). The
 * consistency test fails if a gap is missing or no longer true.
 *
 * See docs/E2E_ROLES_TESTING.md for how to add a role or an action.
 */

import type * as FirestoreModule from 'firebase/firestore';

export type Firestore = FirestoreModule.Firestore;
type Fs = typeof FirestoreModule;

export const ROLE_ACTORS = ['owner', 'admin', 'supervisor', 'manager', 'consultant', 'technician'] as const;
export const OUTSIDE_ACTORS = ['otherCompany', 'noCompany', 'anonymous'] as const;
export const ACTORS = [...ROLE_ACTORS, ...OUTSIDE_ACTORS] as const;

export type RoleActor = (typeof ROLE_ACTORS)[number];
export type Actor = (typeof ACTORS)[number];

export interface ActorInfo {
  uid: string | null;
  roles: Record<string, string>;
}

export const ACTOR_INFO: Record<Actor, ActorInfo> = {
  owner: { uid: 'owner1', roles: { c1: 'owner' } },
  admin: { uid: 'admin1', roles: { c1: 'admin' } },
  supervisor: { uid: 'sup1', roles: { c1: 'supervisor' } },
  manager: { uid: 'mgr1', roles: { c1: 'manager' } },
  consultant: { uid: 'cons1', roles: { c1: 'consultant' } },
  technician: { uid: 'tech1', roles: { c1: 'technician' } },
  // Admin of another company: must get nothing in c1.
  otherCompany: { uid: 'other1', roles: { c2: 'admin' } },
  // Signed in, no company yet (first access / onboarding).
  noCompany: { uid: 'nocomp', roles: {} },
  anonymous: { uid: null, roles: {} },
};

const MEMBERS: Actor[] = [...ROLE_ACTORS];
const ADMINS: Actor[] = ['owner', 'admin'];
const FINANCIAL: Actor[] = ['owner', 'admin', 'manager'];
const SEE_ALL_ORDERS: Actor[] = ['owner', 'admin', 'manager', 'supervisor'];
const SIGNED_IN: Actor[] = [...ROLE_ACTORS, 'otherCompany', 'noCompany'];

const C = 'companies/c1';

export interface Ctx {
  db: Firestore;
  fs: Fs;
  /** uid of the acting user ('anon' for anonymous) */
  uid: string;
}

export interface RulesCase {
  id: string;
  area: string;
  title: string;
  run: (ctx: Ctx) => Promise<unknown>;
  allow: Actor[];
  /** PermissionType from lib/models/permission.dart that guards this action in the app */
  permission?: string;
  /** Known difference between app and rules (see header) */
  gap?: string;
}

const own = (uid: string) => `${C}/orders/own_${uid}`;
const ownApproved = (uid: string) => `${C}/orders/appr_${uid}`;
const GHOST_ORDER = `${C}/orders/ghost_quote`;

export const CASES: RulesCase[] = [
  // ─── Company ────────────────────────────────────────────────────────────
  {
    id: 'company.read', area: 'Empresa', title: 'ler a empresa',
    run: ({ db, fs }) => fs.getDoc(fs.doc(db, C)),
    allow: MEMBERS,
  },
  {
    id: 'company.update', area: 'Empresa', title: 'editar dados da empresa',
    run: ({ db, fs }) => fs.updateDoc(fs.doc(db, C), { name: 'Renamed' }),
    allow: ADMINS, permission: 'manageCompany',
  },
  {
    id: 'company.subscription', area: 'Empresa', title: 'se dar plano pago',
    run: ({ db, fs }) => fs.updateDoc(fs.doc(db, C), { subscription: { plan: 'pro', status: 'active' } }),
    allow: [],
  },
  {
    id: 'company.delete', area: 'Empresa', title: 'apagar a empresa',
    run: ({ db, fs }) => fs.deleteDoc(fs.doc(db, C)),
    allow: ADMINS,
  },
  {
    id: 'crossTenant.control', area: 'Empresa', title: 'ler a própria empresa c2 (controle do actor de fora)',
    run: ({ db, fs }) => fs.getDoc(fs.doc(db, 'companies/c2')),
    allow: ['otherCompany'],
  },

  // ─── Orders ─────────────────────────────────────────────────────────────
  {
    id: 'orders.read.own', area: 'OS', title: 'abrir OS que criou',
    run: ({ db, fs, uid }) => fs.getDoc(fs.doc(db, own(uid))),
    allow: MEMBERS,
  },
  {
    id: 'orders.read.others', area: 'OS', title: 'abrir OS de outra pessoa',
    run: ({ db, fs }) => fs.getDoc(fs.doc(db, GHOST_ORDER)),
    allow: SEE_ALL_ORDERS, permission: 'viewAllOrders',
  },
  {
    id: 'orders.list.all', area: 'OS', title: 'listar todas as OS',
    run: ({ db, fs }) => fs.getDocs(fs.collection(db, `${C}/orders`)),
    allow: SEE_ALL_ORDERS, permission: 'viewAllOrders',
  },
  {
    id: 'orders.list.own', area: 'OS', title: 'listar as OS que criou (filtro createdBy)',
    run: ({ db, fs, uid }) =>
      fs.getDocs(fs.query(fs.collection(db, `${C}/orders`), fs.where('createdBy.id', '==', uid))),
    allow: MEMBERS,
  },
  {
    // Same query the Home tab runs (OrderRepositoryV2.getOrdersWithPagination):
    // no createdBy filter, so the rules reject it for consultant/technician.
    id: 'orders.list.homeQuery', area: 'OS', title: 'abrir a Início (consulta de OS em aberto)',
    run: ({ db, fs }) =>
      fs.getDocs(fs.query(fs.collection(db, `${C}/orders`),
        fs.where('status', 'in', ['quote', 'approved', 'progress']), fs.orderBy('createdAt', 'desc'), fs.limit(10))),
    allow: SEE_ALL_ORDERS,
  },
  {
    // The Home tab query as the app runs it since #456: consultant and
    // technician add createdBy.id == uid (OrderRepositoryV2.getOrdersWithPagination).
    id: 'orders.list.homeQueryScoped', area: 'OS', title: 'abrir a Início com o filtro do perfil (createdBy)',
    run: ({ db, fs, uid }) =>
      fs.getDocs(fs.query(fs.collection(db, `${C}/orders`),
        fs.where('status', 'in', ['quote', 'approved', 'progress']), fs.where('createdBy.id', '==', uid),
        fs.orderBy('createdAt', 'desc'), fs.limit(10))),
    allow: MEMBERS,
  },
  {
    // Agenda by scheduled date (TenantOrderRepository.streamOrdersByScheduledDateRange
    // + creator scope).
    id: 'orders.list.agendaScheduledScoped', area: 'OS', title: 'abrir a Agenda (agendadas) com o filtro do perfil',
    run: ({ db, fs, uid }) =>
      fs.getDocs(fs.query(fs.collection(db, `${C}/orders`),
        fs.where('scheduledDate', '>=', '2026-10-01T00:00:00.000'),
        fs.where('scheduledDate', '<', '2026-11-01T00:00:00.000'),
        fs.where('createdBy.id', '==', uid), fs.orderBy('scheduledDate'))),
    allow: MEMBERS,
  },
  {
    // Agenda by due date (streamOrdersByDueDateRange + creator scope).
    id: 'orders.list.agendaDueScoped', area: 'OS', title: 'abrir a Agenda (prazos) com o filtro do perfil',
    run: ({ db, fs, uid }) =>
      fs.getDocs(fs.query(fs.collection(db, `${C}/orders`),
        fs.where('dueDate', '>=', '2026-10-01T00:00:00.000'),
        fs.where('dueDate', '<', '2026-11-01T00:00:00.000'),
        fs.where('createdBy.id', '==', uid), fs.orderBy('dueDate'))),
    allow: MEMBERS,
  },
  {
    id: 'orders.create', area: 'OS', title: 'criar OS',
    run: ({ db, fs, uid }) =>
      fs.setDoc(fs.doc(db, `${C}/orders/new_${uid}`), {
        status: 'quote', createdBy: { id: uid, name: uid }, company: { id: 'c1' },
      }),
    allow: ['owner', 'admin', 'supervisor', 'consultant', 'technician'], permission: 'createOrder',
  },
  {
    id: 'orders.update.own', area: 'OS', title: 'editar OS que criou',
    run: ({ db, fs, uid }) => fs.updateDoc(fs.doc(db, own(uid)), { status: 'approved' }),
    allow: MEMBERS,
  },
  {
    id: 'orders.update.others', area: 'OS', title: 'editar OS de outra pessoa',
    run: ({ db, fs }) => fs.updateDoc(fs.doc(db, GHOST_ORDER), { status: 'approved' }),
    allow: SEE_ALL_ORDERS,
  },
  {
    id: 'orders.delete.ownQuote', area: 'OS', title: 'apagar orçamento que criou',
    run: ({ db, fs, uid }) => fs.deleteDoc(fs.doc(db, own(uid))),
    allow: MEMBERS,
  },
  {
    id: 'orders.delete.othersQuote', area: 'OS', title: 'apagar orçamento de outra pessoa',
    run: ({ db, fs }) => fs.deleteDoc(fs.doc(db, GHOST_ORDER)),
    allow: SEE_ALL_ORDERS,
  },
  {
    id: 'orders.delete.approved', area: 'OS', title: 'apagar OS aprovada (não orçamento)',
    run: ({ db, fs, uid }) => fs.deleteDoc(fs.doc(db, ownApproved(uid))),
    allow: ADMINS,
  },
  {
    id: 'orders.photos.readOthers', area: 'OS', title: 'ver fotos de OS de outra pessoa',
    run: ({ db, fs }) => fs.getDoc(fs.doc(db, `${GHOST_ORDER}/photos/p1`)),
    allow: MEMBERS, permission: 'viewAllOrders',
    gap: 'Fotos, formulários e comentários checam só se é membro: consultor e técnico leem os de OS que não podem abrir.',
  },
  {
    id: 'orders.photos.write', area: 'OS', title: 'anexar foto na OS que criou',
    run: ({ db, fs, uid }) => fs.setDoc(fs.doc(db, `${own(uid)}/photos/new_${uid}`), { url: 'x' }),
    allow: MEMBERS,
  },
  {
    id: 'orders.forms.writeOthers', area: 'OS', title: 'preencher checklist de OS de outra pessoa',
    run: ({ db, fs, uid }) => fs.setDoc(fs.doc(db, `${GHOST_ORDER}/forms/new_${uid}`), { status: 'pending' }),
    allow: MEMBERS, permission: 'fillForms',
    gap: 'Checklist da OS aceita escrita de qualquer membro: o gerente (sem fillForms no app) e quem não pode abrir a OS também gravam.',
  },
  {
    id: 'orders.comments.create', area: 'OS', title: 'comentar na OS que criou',
    run: ({ db, fs, uid }) =>
      fs.setDoc(fs.doc(db, `${own(uid)}/comments/new_${uid}`), { text: 'oi', author: { userId: uid } }),
    allow: MEMBERS,
  },
  {
    id: 'orders.comments.readOthers', area: 'OS', title: 'ler comentários de OS de outra pessoa',
    run: ({ db, fs }) => fs.getDoc(fs.doc(db, `${GHOST_ORDER}/comments/cm1`)),
    allow: MEMBERS, permission: 'viewAllOrders',
    gap: 'Fotos, formulários e comentários checam só se é membro: consultor e técnico leem os de OS que não podem abrir.',
  },
  {
    id: 'orders.charges.read', area: 'Cobrança', title: 'ver cobrança Asaas da OS',
    run: ({ db, fs }) => fs.getDoc(fs.doc(db, `${GHOST_ORDER}/charges/ch1`)),
    allow: FINANCIAL, permission: 'chargeOrder',
  },
  {
    id: 'orders.charges.write', area: 'Cobrança', title: 'gravar cobrança direto (sem servidor)',
    run: ({ db, fs, uid }) => fs.setDoc(fs.doc(db, `${GHOST_ORDER}/charges/new_${uid}`), { value: 1 }),
    allow: [],
  },

  // ─── Customers, devices, catalog, templates ─────────────────────────────
  {
    id: 'customers.read', area: 'Cadastros', title: 'listar clientes',
    run: ({ db, fs }) => fs.getDocs(fs.collection(db, `${C}/customers`)),
    allow: MEMBERS, permission: 'viewCustomers',
  },
  {
    id: 'customers.write', area: 'Cadastros', title: 'cadastrar cliente',
    run: ({ db, fs, uid }) => fs.setDoc(fs.doc(db, `${C}/customers/new_${uid}`), { name: 'Novo' }),
    allow: ['owner', 'admin', 'supervisor', 'consultant'], permission: 'manageCustomers',
  },
  {
    id: 'customers.delete', area: 'Cadastros', title: 'apagar cliente',
    run: ({ db, fs }) => fs.deleteDoc(fs.doc(db, `${C}/customers/cust1`)),
    allow: ['owner', 'admin', 'supervisor', 'consultant'], permission: 'manageCustomers',
  },
  {
    id: 'devices.read', area: 'Cadastros', title: 'listar aparelhos/veículos',
    run: ({ db, fs }) => fs.getDocs(fs.collection(db, `${C}/devices`)),
    allow: MEMBERS, permission: 'viewDevices',
  },
  {
    id: 'devices.write', area: 'Cadastros', title: 'cadastrar aparelho/veículo',
    run: ({ db, fs, uid }) => fs.setDoc(fs.doc(db, `${C}/devices/new_${uid}`), { name: 'Novo' }),
    allow: ['owner', 'admin', 'supervisor'], permission: 'manageDevices',
  },
  {
    id: 'products.read', area: 'Cadastros', title: 'listar produtos (com preço)',
    run: ({ db, fs }) => fs.getDocs(fs.collection(db, `${C}/products`)),
    allow: MEMBERS, permission: 'viewProducts',
    gap: 'O técnico não tem viewProducts no app, mas as regras deixam ler o catálogo (com preço).',
  },
  {
    id: 'products.write', area: 'Cadastros', title: 'cadastrar produto',
    run: ({ db, fs, uid }) => fs.setDoc(fs.doc(db, `${C}/products/new_${uid}`), { name: 'Novo', value: 10 }),
    allow: ADMINS, permission: 'manageProducts',
  },
  {
    id: 'services.read', area: 'Cadastros', title: 'listar serviços (com preço)',
    run: ({ db, fs }) => fs.getDocs(fs.collection(db, `${C}/services`)),
    allow: MEMBERS, permission: 'viewServices',
    gap: 'O técnico não tem viewServices no app, mas as regras deixam ler o catálogo (com preço).',
  },
  {
    id: 'services.write', area: 'Cadastros', title: 'cadastrar serviço',
    run: ({ db, fs, uid }) => fs.setDoc(fs.doc(db, `${C}/services/new_${uid}`), { name: 'Novo', value: 10 }),
    allow: ADMINS, permission: 'manageServices',
  },
  {
    id: 'forms.write', area: 'Cadastros', title: 'criar modelo de checklist',
    run: ({ db, fs, uid }) => fs.setDoc(fs.doc(db, `${C}/forms/new_${uid}`), { title: 'Novo' }),
    allow: ['owner', 'admin', 'supervisor'], permission: 'manageForms',
  },
  {
    id: 'brands.write', area: 'Cadastros', title: 'cadastrar marca',
    run: ({ db, fs, uid }) => fs.setDoc(fs.doc(db, `${C}/brands/new_${uid}`), { name: 'Nova' }),
    allow: ADMINS,
  },
  {
    id: 'accumulated.create', area: 'Cadastros', title: 'guardar valor de autocompletar',
    run: ({ db, fs, uid }) =>
      fs.setDoc(fs.doc(db, `${C}/accumulatedFields/brand/values/new_${uid}`), { value: 'x' }),
    allow: MEMBERS,
  },
  {
    id: 'accumulated.delete', area: 'Cadastros', title: 'apagar valor de autocompletar',
    run: ({ db, fs }) => fs.deleteDoc(fs.doc(db, `${C}/accumulatedFields/brand/values/v1`)),
    allow: ADMINS,
  },

  // ─── Team ───────────────────────────────────────────────────────────────
  {
    id: 'memberships.read', area: 'Equipe', title: 'ver a equipe',
    run: ({ db, fs }) => fs.getDocs(fs.collection(db, `${C}/memberships`)),
    allow: MEMBERS,
  },
  {
    id: 'memberships.create', area: 'Equipe', title: 'adicionar alguém à equipe',
    run: ({ db, fs }) =>
      fs.setDoc(fs.doc(db, `${C}/memberships/newbie`), { user: { id: 'newbie' }, role: 'technician' }),
    allow: ADMINS, permission: 'manageUsers',
  },
  {
    id: 'memberships.changeRole', area: 'Equipe', title: 'mudar o papel de outra pessoa',
    run: ({ db, fs }) => fs.updateDoc(fs.doc(db, `${C}/memberships/tech1`), { role: 'admin' }),
    allow: ADMINS, permission: 'manageRoles',
  },
  {
    // CollaboratorStore.updateCollaboratorRole/removeCollaborator also batch-write
    // users/{otherUid}.companies, which only the user itself may write.
    id: 'team.changeRole.userDoc', area: 'Equipe', title: 'mudar o papel (perfil do colega em /users)',
    run: ({ db, fs }) => fs.updateDoc(fs.doc(db, 'users/ghost'), { companies: [] }),
    allow: [], permission: 'manageRoles',
    gap: 'BUG: o app grava users/{colega} ao trocar papel ou remover alguém, e as regras só deixam o próprio usuário gravar. A troca de papel falha para o admin.',
  },
  {
    id: 'memberships.selfPromote', area: 'Equipe', title: 'se promover a admin',
    run: ({ db, fs, uid }) => fs.setDoc(fs.doc(db, `${C}/memberships/${uid}`), { user: { id: uid }, role: 'admin' }),
    allow: ADMINS,
  },
  {
    id: 'memberships.remove', area: 'Equipe', title: 'tirar alguém da equipe',
    run: ({ db, fs }) => fs.deleteDoc(fs.doc(db, `${C}/memberships/cons1`)),
    allow: ADMINS, permission: 'manageUsers',
  },
  {
    id: 'invites.create', area: 'Equipe', title: 'convidar colaborador',
    run: ({ db, fs, uid }) =>
      fs.setDoc(fs.doc(db, `links/invites/tokens/NEW_${uid}`), {
        company: { id: 'c1' }, role: 'technician', email: 'x@example.com', status: 'pending',
      }),
    allow: ADMINS, permission: 'manageUsers',
  },
  {
    id: 'invites.read', area: 'Equipe', title: 'ver convite pendente da empresa',
    run: ({ db, fs }) => fs.getDoc(fs.doc(db, 'links/invites/tokens/INV_c1')),
    allow: ADMINS, permission: 'manageUsers',
  },
  {
    id: 'invites.legacy.create', area: 'Equipe', title: 'convidar pela coleção antiga /invites',
    run: ({ db, fs, uid }) =>
      fs.setDoc(fs.doc(db, `invites/new_${uid}`), { company: { id: 'c1' }, role: 'admin', email: 'x@example.com' }),
    allow: ADMINS, permission: 'manageUsers',
  },

  // ─── Financial ──────────────────────────────────────────────────────────
  {
    id: 'financial.entries.read', area: 'Financeiro', title: 'ver lançamentos',
    run: ({ db, fs }) => fs.getDocs(fs.collection(db, `${C}/financialEntries`)),
    allow: FINANCIAL, permission: 'viewBilling',
  },
  {
    id: 'financial.entries.create', area: 'Financeiro', title: 'lançar despesa/receita',
    run: ({ db, fs, uid }) => fs.setDoc(fs.doc(db, `${C}/financialEntries/new_${uid}`), { amount: 10 }),
    allow: FINANCIAL, permission: 'viewBilling',
  },
  {
    id: 'financial.entries.delete', area: 'Financeiro', title: 'apagar lançamento de vez',
    run: ({ db, fs }) => fs.deleteDoc(fs.doc(db, `${C}/financialEntries/fe1`)),
    allow: [],
  },
  {
    id: 'financial.accounts.read', area: 'Financeiro', title: 'ver contas',
    run: ({ db, fs }) => fs.getDocs(fs.collection(db, `${C}/financialAccounts`)),
    allow: FINANCIAL, permission: 'viewBilling',
  },
  {
    id: 'financial.payments.read', area: 'Financeiro', title: 'ver pagamentos',
    run: ({ db, fs }) => fs.getDocs(fs.collection(db, `${C}/financialPayments`)),
    allow: FINANCIAL, permission: 'viewBilling',
  },
  {
    id: 'receipts.create', area: 'Financeiro', title: 'registrar recebimento de cliente',
    run: ({ db, fs, uid }) =>
      fs.setDoc(fs.doc(db, `${C}/receipts/new_${uid}`), {
        createdBy: { id: uid }, status: 'active', amount: 10, allocations: [{ orderId: 'x', amount: 10 }],
      }),
    allow: ['owner', 'admin', 'manager', 'consultant'],
  },
  {
    id: 'receipts.readOthers', area: 'Financeiro', title: 'ver recebimento registrado por outra pessoa',
    run: ({ db, fs }) => fs.getDoc(fs.doc(db, `${C}/receipts/r_ghost`)),
    allow: FINANCIAL, permission: 'viewBilling',
  },
  {
    id: 'customerCharges.read', area: 'Cobrança', title: 'ver cobrança de várias OS',
    run: ({ db, fs }) => fs.getDocs(fs.collection(db, `${C}/customerCharges`)),
    allow: FINANCIAL, permission: 'chargeOrder',
  },
  {
    id: 'invoices.read', area: 'Cobrança', title: 'ver notas fiscais',
    run: ({ db, fs }) => fs.getDocs(fs.collection(db, `${C}/invoices`)),
    allow: FINANCIAL, permission: 'chargeOrder',
  },
  {
    id: 'settings.payments.read', area: 'Cobrança', title: 'ler configuração do Asaas',
    run: ({ db, fs }) => fs.getDoc(fs.doc(db, `${C}/settings/payments`)),
    allow: MEMBERS,
  },
  {
    id: 'settings.payments.write', area: 'Cobrança', title: 'ligar o Asaas direto (sem servidor)',
    run: ({ db, fs }) => fs.setDoc(fs.doc(db, `${C}/settings/payments`), { enabled: true }),
    allow: [],
  },
  {
    id: 'settings.nfse.read', area: 'Cobrança', title: 'ler configuração da nota fiscal',
    run: ({ db, fs }) => fs.getDoc(fs.doc(db, `${C}/settings/nfse`)),
    allow: FINANCIAL, permission: 'chargeOrder',
  },

  // ─── Notifications & private ────────────────────────────────────────────
  {
    id: 'notifications.readOwn', area: 'Avisos', title: 'ler os próprios avisos',
    run: ({ db, fs, uid }) => fs.getDoc(fs.doc(db, `${C}/notifications/n_${uid}`)),
    allow: MEMBERS,
  },
  {
    id: 'notifications.readOthers', area: 'Avisos', title: 'ler avisos de outra pessoa',
    run: ({ db, fs }) => fs.getDoc(fs.doc(db, `${C}/notifications/n_ghost`)),
    allow: [],
  },
  {
    id: 'notifications.markRead', area: 'Avisos', title: 'marcar aviso como lido',
    run: ({ db, fs, uid }) => fs.updateDoc(fs.doc(db, `${C}/notifications/n_${uid}`), { read: true }),
    allow: MEMBERS,
  },
  {
    id: 'notifications.create', area: 'Avisos', title: 'criar aviso direto',
    run: ({ db, fs, uid }) =>
      fs.setDoc(fs.doc(db, `${C}/notifications/new_${uid}`), { recipientId: 'admin1', title: 'x' }),
    allow: [],
  },
  {
    id: 'private.read', area: 'Servidor', title: 'ler dados privados do servidor',
    run: ({ db, fs }) => fs.getDoc(fs.doc(db, `${C}/private/members`)),
    allow: [],
  },

  // ─── Global ─────────────────────────────────────────────────────────────
  {
    id: 'users.readOther', area: 'Global', title: 'ler o perfil de outro usuário',
    run: ({ db, fs }) => fs.getDoc(fs.doc(db, 'users/ghost')),
    allow: [],
  },
  {
    id: 'segments.read', area: 'Global', title: 'ler ramos de atividade',
    run: ({ db, fs }) => fs.getDoc(fs.doc(db, 'segments/automotive')),
    allow: SIGNED_IN,
  },
  {
    id: 'shareTokens.read', area: 'Link do cliente', title: 'ler token de link da empresa',
    run: ({ db, fs }) => fs.getDoc(fs.doc(db, 'links/share/tokens/ST_c1')),
    allow: MEMBERS,
  },
  {
    id: 'shareTokens.write', area: 'Link do cliente', title: 'criar link de cliente direto',
    run: ({ db, fs, uid }) =>
      fs.setDoc(fs.doc(db, `links/share/tokens/new_${uid}`), { companyId: 'c1', orderId: 'ghost_quote' }),
    allow: [],
  },
  {
    id: 'authTokens.read', area: 'Global', title: 'ler token de login do WhatsApp',
    run: ({ db, fs }) => fs.getDoc(fs.doc(db, 'links/auth/tokens/AT1')),
    allow: [],
  },
];

/** Seeds c1 (target) and c2 (other tenant). Called before every case. */
export async function seed(db: Firestore, fs: Fs): Promise<void> {
  const batch = fs.writeBatch(db);
  const set = (path: string, data: Record<string, unknown>) => batch.set(fs.doc(db, path), data);

  set('companies/c1', { name: 'Company c1', owner: { id: 'owner1', name: 'Owner' } });
  set('companies/c2', { name: 'Company c2', owner: { id: 'other1', name: 'Other' } });

  for (const actor of ACTORS) {
    const uid = ACTOR_INFO[actor].uid ?? 'anon';
    set(`${C}/orders/own_${uid}`, { status: 'quote', createdBy: { id: uid, name: uid } });
    set(`${C}/orders/appr_${uid}`, { status: 'approved', createdBy: { id: uid, name: uid } });
    set(`${C}/notifications/n_${uid}`, { recipientId: uid, read: false });
    const role = ACTOR_INFO[actor].roles.c1;
    if (role) set(`${C}/memberships/${uid}`, { user: { id: uid, name: uid }, role });
  }
  set(GHOST_ORDER, { status: 'quote', createdBy: { id: 'ghost', name: 'Ghost' } });
  set(`${GHOST_ORDER}/photos/p1`, { url: 'x' });
  set(`${GHOST_ORDER}/comments/cm1`, { text: 'oi', author: { userId: 'ghost' } });
  set(`${GHOST_ORDER}/charges/ch1`, { value: 100 });
  set(`${C}/notifications/n_ghost`, { recipientId: 'ghost', read: false });
  set(`${C}/customers/cust1`, { name: 'Cliente' });
  set(`${C}/devices/dev1`, { name: 'Aparelho' });
  set(`${C}/products/prod1`, { name: 'Peça', value: 50 });
  set(`${C}/services/serv1`, { name: 'Serviço', value: 80 });
  set(`${C}/accumulatedFields/brand/values/v1`, { value: 'Fiat' });
  set(`${C}/financialEntries/fe1`, { amount: 10 });
  set(`${C}/financialAccounts/fa1`, { name: 'Caixa' });
  set(`${C}/financialPayments/fp1`, { amount: 10 });
  set(`${C}/receipts/r_ghost`, {
    createdBy: { id: 'ghost' }, status: 'active', amount: 10, allocations: [{ orderId: 'x', amount: 10 }],
  });
  set(`${C}/customerCharges/cc1`, { value: 10 });
  set(`${C}/invoices/inv1`, { value: 10 });
  set(`${C}/settings/payments`, { enabled: false });
  set(`${C}/settings/nfse`, { serviceCode: '1.01' });
  set(`${C}/private/members`, { owner1: 'owner' });
  set('users/ghost', { id: 'ghost', companies: [] });
  set('segments/automotive', { name: 'Mecânica' });
  set('links/share/tokens/ST_c1', { companyId: 'c1', orderId: 'ghost_quote' });
  set('links/invites/tokens/INV_c1', {
    company: { id: 'c1' }, role: 'technician', email: 'invitee@example.com', status: 'pending',
  });
  set('links/auth/tokens/AT1', { userId: 'ghost' });

  await batch.commit();
}
