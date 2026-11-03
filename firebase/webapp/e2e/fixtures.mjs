// Fictional data shared by the seed and the tests. Nothing here is real: every
// address uses the reserved .test domain and the password only opens the emulator.
export const PROJECT_ID = 'demo-praticos'
export const PASSWORD = 'emulator-only-password'
export const COMPANY_A = 'company-alpha'
export const COMPANY_B = 'company-beta'
/** "Valores e cobrança" off (useFinancial: false): nobody sees money, not even the owner. */
export const COMPANY_C = 'company-gamma'
/** "Manutenções chegando" (e2e/maintenance.spec.ts): its own devices, so counts do not move. */
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
  /** Owner of company C, where "Valores e cobrança" is off. */
  noValues: { ...user('novalues', 'Vera Sem Valores'), roles: { [COMPANY_C]: 'owner' } },
  /** First access (e2e/onboarding.spec.ts): each one creates a company once. */
  founder: { ...user('founder', 'Fábio Fundador'), roles: {} },
  founderLean: { ...user('founderlean', 'Lia Sem Exemplos'), roles: {} },
  /** No name on the account: the name on the order is required. */
  founderNoName: { ...user('foundernoname', ''), roles: {} },
  /** Owner and technician of company D (maintenances). */
  maintOwner: { ...user('maintowner', 'Mara Dona Delta'), roles: { [COMPANY_D]: 'owner' } },
  maintTech: { ...user('mainttech', 'Tito Tecnico Delta'), roles: { [COMPANY_D]: 'technician' } },
  /** Avisos (e2e/notifications.spec.ts): three new and one read; the other one has 120 new. */
  bellUser: { ...user('belluser', 'Bela Avisos'), roles: { [COMPANY_D]: 'admin' } },
  bellBusy: { ...user('bellbusy', 'Beto Muitos Avisos'), roles: { [COMPANY_D]: 'manager' } },
  /** No company and outside the access list: never reaches the first access. */
  strangerNew: { ...user('strangernew', 'Saulo Fora'), roles: {}, blocked: true },
}

/** Pending invites: one for who has no company, one for who already works in A. */
export const INVITES = {
  newcomer: { token: 'INV_E2E_NEWCOMER', company: COMPANY_A, role: 'technician', email: 'newcomer@praticos.test' },
  invitee: { token: 'INV_E2E_INVITEE_B', company: COMPANY_B, role: 'supervisor', email: 'invitee@praticos.test' },
}

export const COMPANIES = {
  [COMPANY_A]: { name: 'Oficina Alfa', country: 'BR', segment: 'automotive', owner: USERS.owner },
  [COMPANY_B]: { name: 'Beta Repairs', country: 'US', segment: 'electronics', owner: USERS.owner },
  [COMPANY_C]: { name: 'Gama Sem Valores', country: 'BR', segment: 'automotive', owner: USERS.noValues, useFinancial: false },
  [COMPANY_D]: { name: 'Delta Manutenção', country: 'BR', segment: 'automotive', owner: USERS.maintOwner },
}

export const DEFAULT_ORDERS = 30
