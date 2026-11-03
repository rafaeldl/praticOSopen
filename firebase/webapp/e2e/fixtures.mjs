// Fictional data shared by the seed and the tests. Nothing here is real: every
// address uses the reserved .test domain and the password only opens the emulator.
export const PROJECT_ID = 'demo-praticos'
export const PASSWORD = 'emulator-only-password'
export const COMPANY_A = 'company-alpha'
export const COMPANY_B = 'company-beta'

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
}

/** Pending invites: one for who has no company, one for who already works in A. */
export const INVITES = {
  newcomer: { token: 'INV_E2E_NEWCOMER', company: COMPANY_A, role: 'technician', email: 'newcomer@praticos.test' },
  invitee: { token: 'INV_E2E_INVITEE_B', company: COMPANY_B, role: 'supervisor', email: 'invitee@praticos.test' },
}

export const COMPANIES = {
  [COMPANY_A]: { name: 'Oficina Alfa', country: 'BR', segment: 'automotive', owner: USERS.owner },
  [COMPANY_B]: { name: 'Beta Repairs', country: 'US', segment: 'electronics', owner: USERS.owner },
}

export const DEFAULT_ORDERS = 30
