// Fictional data shared by the seed and the tests. Nothing here is real: every
// address uses the reserved .test domain and the password only opens the emulator.
export const PROJECT_ID = 'demo-praticos'
export const PASSWORD = 'emulator-only-password'
export const COMPANY_A = 'company-alpha'
export const COMPANY_B = 'company-beta'
/** "Valores e cobrança" off (useFinancial: false): nobody sees money, not even the owner. */
export const COMPANY_C = 'company-gamma'
/** Fatia 07 (equipe, empresa, plano): companies of their own, so switching values off or
 * changing roles never reaches the screens other tests read. */
export const COMPANY_G = 'company-settings'
export const COMPANY_T = 'company-team'
/** "Manutenções chegando", sino and Agora (e2e/maintenance.spec.ts, notifications.spec.ts): its own devices, so counts do not move. */
export const COMPANY_M = 'company-maint'
export const COMPANY_D = 'company-delta'
/** A company without a segment (a first access stopped in the app): auth.gate.resume-company. */
export const COMPANY_R = 'company-resume'
/** Início filters as server queries (e2e/home-filters.spec.ts): more orders per filter than one page. */
export const COMPANY_P = 'company-paging'
/** NFS-e direta on (settings/payments.nfseDirectEnabled): "Dados para nota" of the customer (e2e/customer-invoice.spec.ts). */
export const COMPANY_N = 'company-nfse'
/** Work stages on (docs/WORK_STAGES.md): the board splits Em andamento, so no other board test reads it. */
export const COMPANY_S = 'company-stages'
/** Web checkout against the real Asaas sandbox (e2e/billing-sandbox.spec.ts): this id is the
 * appUserID it touches in RevenueCat, so it must never be a real company's. */
export const COMPANY_W = 'e2e-web-checkout-sandbox'

const user = (key, name) => ({ uid: `e2e-${key}`, email: `${key}@praticos.test`, name })

/** One user per role in company A. The owner also owns company B. */
export const USERS = {
  owner: { ...user('owner', 'Olivia Dona'), roles: { [COMPANY_A]: 'owner', [COMPANY_B]: 'owner' } },
  admin: { ...user('admin', 'Alberto Admin'), roles: { [COMPANY_A]: 'admin' } },
  manager: { ...user('manager', 'Marta Gerente'), roles: { [COMPANY_A]: 'manager' } },
  supervisor: { ...user('supervisor', 'Sergio Supervisor'), roles: { [COMPANY_A]: 'supervisor' } },
  consultant: { ...user('consultant', 'Carla Consultora'), roles: { [COMPANY_A]: 'consultant' } },
  technician: { ...user('technician', 'Tiago Tecnico'), roles: { [COMPANY_A]: 'technician' } },
  noCompany: { ...user('nocompany', 'Nina Sem Empresa'), roles: {} },
  /** Technician of company A, but outside the web access list. */
  outsider: { ...user('outsider', 'Otto Fora Da Lista'), roles: { [COMPANY_A]: 'technician' }, blocked: true },
  /** Only for the invite tests, so accepting does not change other tests' users. */
  invitee: { ...user('invitee', 'Ivo Convidado'), roles: { [COMPANY_A]: 'technician' } },
  newcomer: { ...user('newcomer', 'Nara Nova'), roles: {} },
  /** Administrator in A, technician in B: switching must re-check the open screen. */
  mixed: { ...user('mixed', 'Mauro Dois Papeis'), roles: { [COMPANY_A]: 'admin', [COMPANY_B]: 'technician' } },
  /** On the list, but the e-mail was never confirmed: the server says no. */
  unverified: { ...user('unverified', 'Ugo Sem Confirmar'), roles: { [COMPANY_A]: 'technician' }, emailVerified: false },
  /** Owner of company C, where "Valores e cobrança" is off. */
  noValues: { ...user('novalues', 'Vera Sem Valores'), roles: { [COMPANY_C]: 'owner' } },
  /** First access (e2e/onboarding.spec.ts): each one creates a company once. */
  founder: { ...user('founder', 'Fábio Fundador'), roles: {} },
  founderLean: { ...user('founderlean', 'Lia Sem Exemplos'), roles: {} },
  /** No name on the account: the name on the order is required. */
  founderNoName: { ...user('foundernoname', ''), roles: {} },
  /** Reloads between creating the company and seeding it; loses the seed's answer. */
  founderReload: { ...user('founderreload', 'Rui Recarrega'), roles: {} },
  founderTwice: { ...user('foundertwice', 'Teca Duas Vezes'), roles: {} },
  /** Owner and technician of company D (maintenances). */
  maintOwner: { ...user('maintowner', 'Mara Dona Manutencao'), roles: { [COMPANY_M]: 'owner' } },
  maintTech: { ...user('mainttech', 'Tito Tecnico Manutencao'), roles: { [COMPANY_M]: 'technician' } },
  /** Avisos (e2e/notifications.spec.ts): three new and one read; the other one has 120 new. */
  bellUser: { ...user('belluser', 'Bela Avisos'), roles: { [COMPANY_M]: 'admin' } },
  bellBusy: { ...user('bellbusy', 'Beto Muitos Avisos'), roles: { [COMPANY_M]: 'manager' } },
  /** No company and outside the access list: never reaches the first access. */
  strangerNew: { ...user('strangernew', 'Saulo Fora'), roles: {}, blocked: true },
  // Company gamma: settings, plan and integrations (its owner switches values off and on).
  gOwner: { ...user('g-owner', 'Gina Dona'), roles: { [COMPANY_G]: 'owner' } },
  gAdmin: { ...user('g-admin', 'Gil Admin'), roles: { [COMPANY_G]: 'admin' } },
  gManager: { ...user('g-manager', 'Gabi Gerente'), roles: { [COMPANY_G]: 'manager' } },
  gTech: { ...user('g-tech', 'Guto Tecnico'), roles: { [COMPANY_G]: 'technician' } },
  wOwner: { ...user('w-owner', 'Wanda Dona'), roles: { [COMPANY_W]: 'owner' } },
  // Company team: roles changed and people removed by the team tests.
  tOwner: { ...user('t-owner', 'Tereza Dona'), roles: { [COMPANY_T]: 'owner' } },
  tAdmin: { ...user('t-admin', 'Tadeu Admin'), roles: { [COMPANY_T]: 'admin' } },
  tTech1: { ...user('t-tech1', 'Tomas Tecnico'), roles: { [COMPANY_T]: 'technician' } },
  tTech2: { ...user('t-tech2', 'Tania Tecnica'), roles: { [COMPANY_T]: 'technician' } },
  tSuper: { ...user('t-super', 'Teo Supervisor'), roles: { [COMPANY_T]: 'supervisor' } },
  // Account deletion: sole owner of company delta, and someone with no company.
  dOwner: { ...user('d-owner', 'Dora Sozinha'), roles: { [COMPANY_D]: 'owner' } },
  dAlone: { ...user('d-alone', 'Davi Sem Empresa'), roles: {} },
  /** Joins company B with an invite code typed in Sua conta. */
  joiner: { ...user('joiner', 'Joana Codigo'), roles: { [COMPANY_G]: 'technician' } },
  // Entry (e2e/entry.spec.ts): each one changes only itself.
  /** No company; joins company B by typing a code in the first access. */
  codeNew: { ...user('codenew', 'Caio Codigo Novo'), roles: {} },
  /** No company; accepts the invite on the list and lands in company B. */
  firstAccept: { ...user('firstaccept', 'Flora Primeiro Convite'), roles: {} },
  /** No company; refuses the invite after the question. */
  rejecter: { ...user('rejecter', 'Rosa Recusa'), roles: {} },
  /** No company; the account says Spanish (users.preferredLanguage). */
  polyglot: { ...user('polyglot', 'Paco Idiomas'), roles: {}, preferredLanguage: 'es-ES' },
  /** Signs in for the first time on the web: no users/{uid} yet. */
  fresh: { ...user('fresh', 'Fabi Primeira Vez'), roles: {}, noUserDoc: true },
  /** Owner of a company without a segment: the first access completes it (auth.gate.resume-company). */
  resumer: { ...user('resumer', 'Rita Retoma'), roles: { [COMPANY_R]: 'owner' } },
  // Company paging: one page is never the whole filter (home.filter.server).
  pOwner: { ...user('p-owner', 'Paulo Dono Paginas'), roles: { [COMPANY_P]: 'owner' } },
  pConsultant: { ...user('p-consultant', 'Patricia Consultora Paginas'), roles: { [COMPANY_P]: 'consultant' } },
  pTech: { ...user('p-tech', 'Pedro Tecnico Paginas'), roles: { [COMPANY_P]: 'technician' } },
  pSuper: { ...user('p-super', 'Priscila Supervisora Paginas'), roles: { [COMPANY_P]: 'supervisor' } },
  // Company nfse: the direct nota on, so the customer form has "Dados para nota".
  nOwner: { ...user('n-owner', 'Nadia Dona Nota'), roles: { [COMPANY_N]: 'owner' } },
  // Company stages: Pintura → Polimento inside Em andamento.
  sOwner: { ...user('s-owner', 'Sonia Dona Etapas'), roles: { [COMPANY_S]: 'owner' } },
  sConsultant: { ...user('s-consultant', 'Simone Consultora Etapas'), roles: { [COMPANY_S]: 'consultant' } },
}

/** Pending invites: one for who has no company, one for who already works in A. */
export const INVITES = {
  newcomer: { token: 'INV_E2E_NEWCOMER', company: COMPANY_A, role: 'technician', email: 'newcomer@praticos.test' },
  invitee: { token: 'INV_E2E_INVITEE_B', company: COMPANY_B, role: 'supervisor', email: 'invitee@praticos.test' },
  joiner: { token: 'INV_E2E_JOINER_B', company: COMPANY_B, role: 'technician', email: 'joiner@praticos.test' },
  firstAccept: { token: 'INV_E2E_FIRST_B', company: COMPANY_B, role: 'technician', email: 'firstaccept@praticos.test' },
  rejecter: { token: 'INV_E2E_REJECT_B', company: COMPANY_B, role: 'technician', email: 'rejecter@praticos.test' },
  /** Sent to someone else's e-mail: only the code reaches codeNew. */
  codeNew: { token: 'INV_E2E_CODE_NEW', company: COMPANY_B, role: 'technician', email: 'someone-else@praticos.test' },
}

export const COMPANIES = {
  [COMPANY_A]: { name: 'Oficina Alfa', country: 'BR', segment: 'automotive', owner: USERS.owner },
  [COMPANY_B]: { name: 'Beta Repairs', country: 'US', segment: 'electronics', owner: USERS.owner },
  [COMPANY_C]: { name: 'Gama Sem Valores', country: 'BR', segment: 'automotive', owner: USERS.noValues, useFinancial: false },
  [COMPANY_M]: { name: 'Oficina Manutenção', country: 'BR', segment: 'automotive', owner: USERS.maintOwner },
  [COMPANY_G]: { name: 'Oficina Gama', country: 'BR', segment: 'automotive', owner: USERS.gOwner },
  [COMPANY_T]: { name: 'Equipe Teta', country: 'BR', segment: 'automotive', owner: USERS.tOwner },
  [COMPANY_D]: { name: 'Delta Sozinha', country: 'BR', segment: 'electronics', owner: USERS.dOwner },
  [COMPANY_R]: { name: 'Retoma Sem Ramo', country: 'BR', segment: null, phone: '(48) 3333-4444', owner: USERS.resumer },
  [COMPANY_P]: { name: 'Oficina Paginas', country: 'BR', segment: 'automotive', owner: USERS.pOwner },
  [COMPANY_N]: { name: 'Oficina Nota Direta', country: 'BR', segment: 'automotive', owner: USERS.nOwner },
  [COMPANY_W]: { name: 'Oficina Teste Sandbox', country: 'BR', segment: 'automotive', owner: USERS.wOwner },
  [COMPANY_S]: {
    name: 'Funilaria Etapas', country: 'BR', segment: 'automotive', owner: USERS.sOwner,
    workStages: [{ id: 'paint', name: 'Pintura', keywords: ['pint'] }, { id: 'polish', name: 'Polimento', keywords: ['polim', 'higien'] }],
  },
}

/** Invites of the team company: one waiting, one expired (the app hides it; the web offers "Convidar de novo"). */
export const TEAM_INVITES = {
  waiting: { token: 'INV_E2E_TEAM_WAIT', name: 'Paula Pendente', email: 'paula@praticos.test', role: 'consultant', days: 5 },
  expired: { token: 'INV_E2E_TEAM_OLD', name: 'Pedro Vencido', phone: '11988887777', role: 'technician', days: -2 },
}

export const DEFAULT_ORDERS = 30
