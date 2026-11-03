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
}

export const COMPANIES = {
  [COMPANY_A]: { name: 'Oficina Alfa', country: 'BR', segment: 'automotive', owner: USERS.owner },
  [COMPANY_B]: { name: 'Beta Repairs', country: 'US', segment: 'electronics', owner: USERS.owner },
}

export const DEFAULT_ORDERS = 30
