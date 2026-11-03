// Fictional data shared by the seed and the tests. Nothing here is real: every
// address uses the reserved .test domain and the password only opens the emulator.
export const PROJECT_ID = 'demo-praticos'
export const PASSWORD = 'emulator-only-password'
export const COMPANY_A = 'company-alpha'
export const COMPANY_B = 'company-beta'
/** Fatia 07 (equipe, empresa, plano): companies of their own, so switching values off or
 * changing roles never reaches the screens other tests read. */
export const COMPANY_G = 'company-gamma'
export const COMPANY_T = 'company-team'
export const COMPANY_D = 'company-delta'

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
  // Company gamma: settings, plan and integrations (its owner switches values off and on).
  gOwner: { ...user('g-owner', 'Gina Dona'), roles: { [COMPANY_G]: 'owner' } },
  gAdmin: { ...user('g-admin', 'Gil Admin'), roles: { [COMPANY_G]: 'admin' } },
  gManager: { ...user('g-manager', 'Gabi Gerente'), roles: { [COMPANY_G]: 'manager' } },
  gTech: { ...user('g-tech', 'Guto Tecnico'), roles: { [COMPANY_G]: 'technician' } },
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
}

/** Pending invites: one for who has no company, one for who already works in A. */
export const INVITES = {
  newcomer: { token: 'INV_E2E_NEWCOMER', company: COMPANY_A, role: 'technician', email: 'newcomer@praticos.test' },
  invitee: { token: 'INV_E2E_INVITEE_B', company: COMPANY_B, role: 'supervisor', email: 'invitee@praticos.test' },
  joiner: { token: 'INV_E2E_JOINER_B', company: COMPANY_B, role: 'technician', email: 'joiner@praticos.test' },
}

export const COMPANIES = {
  [COMPANY_A]: { name: 'Oficina Alfa', country: 'BR', segment: 'automotive', owner: USERS.owner },
  [COMPANY_B]: { name: 'Beta Repairs', country: 'US', segment: 'electronics', owner: USERS.owner },
  [COMPANY_G]: { name: 'Oficina Gama', country: 'BR', segment: 'automotive', owner: USERS.gOwner },
  [COMPANY_T]: { name: 'Equipe Teta', country: 'BR', segment: 'automotive', owner: USERS.tOwner },
  [COMPANY_D]: { name: 'Delta Sozinha', country: 'BR', segment: 'electronics', owner: USERS.dOwner },
}

/** Invites of the team company: one waiting, one expired (the app hides it; the web offers "Convidar de novo"). */
export const TEAM_INVITES = {
  waiting: { token: 'INV_E2E_TEAM_WAIT', name: 'Paula Pendente', email: 'paula@praticos.test', role: 'consultant', days: 5 },
  expired: { token: 'INV_E2E_TEAM_OLD', name: 'Pedro Vencido', phone: '11988887777', role: 'technician', days: -2 },
}

export const DEFAULT_ORDERS = 30
