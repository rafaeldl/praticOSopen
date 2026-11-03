// Deterministic seed for the Emulator Suite. E2E_ORDERS=10000 generates the big list.
// Refuses to run unless every Admin SDK client points at a local emulator.
import { initializeApp } from 'firebase-admin/app'
import { getAuth } from 'firebase-admin/auth'
import { getFirestore } from 'firebase-admin/firestore'
import { createHash } from 'node:crypto'
import { COMPANIES, COMPANY_A, COMPANY_B, DEFAULT_ORDERS, INVITES, PASSWORD, PROJECT_ID, USERS } from './fixtures.mjs'

for (const name of ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST']) {
  if (!process.env[name]) {
    console.error(`${name} ausente: o seed só roda dentro de emulators:exec.`)
    process.exit(1)
  }
}
if (process.env.GCLOUD_PROJECT && process.env.GCLOUD_PROJECT !== PROJECT_ID) {
  console.error(`Projeto ${process.env.GCLOUD_PROJECT} recusado: o seed só roda em ${PROJECT_ID}.`)
  process.exit(1)
}

const app = initializeApp({ projectId: PROJECT_ID })
const db = getFirestore(app)
const auth = getAuth(app)

// Fixed clock: the same seed gives the same screens on any day.
const BASE_TIME = Date.UTC(2026, 9, 15, 12)
const iso = (minutesAgo) => new Date(BASE_TIME - minutesAgo * 60000).toISOString()
const aggr = (user) => ({ id: user.uid, name: user.name })
const audit = (user, minutesAgo) => ({
  createdAt: iso(minutesAgo),
  createdBy: aggr(user),
  updatedAt: iso(minutesAgo),
  updatedBy: aggr(user),
})

/** Same result as buildRolesClaim (membership.service.ts) over the data below. */
function rolesClaim(user) {
  return user.roles
}

async function seedSegments() {
  const label = (key, pt, en, es) => ({ key, type: 'label', labels: { 'pt-BR': pt, 'en-US': en, 'es-ES': es } })
  await db.doc('segments/global').set({ name: 'Global', customFields: [] })
  await db.doc('segments/automotive').set({
    name: 'Mecânica',
    customFields: [
      label('device._entity', 'Veículo', 'Vehicle', 'Vehículo'),
      label('device._entity_plural', 'Veículos', 'Vehicles', 'Vehículos'),
      label('status.in_progress', 'Na oficina', 'In the shop', 'En el taller'),
    ],
  })
  await db.doc('segments/electronics').set({
    name: 'Eletrônica',
    customFields: [label('device._entity', 'Aparelho', 'Device', 'Aparato')],
  })
}

async function seedCompanies() {
  for (const [id, company] of Object.entries(COMPANIES)) {
    const members = Object.values(USERS).filter((user) => user.roles[id])
    await db.doc(`companies/${id}`).set({
      name: company.name,
      country: company.country,
      segment: company.segment,
      owner: aggr(company.owner),
      users: members.map((user) => ({ user: aggr(user), role: user.roles[id] })),
      nextOrderNumber: 100000,
      ...audit(company.owner, 100000),
    })
    // Server-only map: what buildRolesClaim verifies against.
    await db.doc(`companies/${id}/private/membership`).set({
      members: Object.fromEntries(members.map((user) => [user.uid, user.roles[id]])),
    })
    for (const user of members) {
      await db.doc(`companies/${id}/memberships/${user.uid}`).set({ userId: user.uid, user: aggr(user), role: user.roles[id] })
    }
  }
}

async function seedUsers() {
  for (const user of Object.values(USERS)) {
    await auth.createUser({
      uid: user.uid,
      email: user.email,
      password: PASSWORD,
      displayName: user.name,
      emailVerified: user.emailVerified !== false,
    })
    await db.doc(`users/${user.uid}`).set({
      id: user.uid,
      name: user.name,
      email: user.email,
      companies: Object.entries(user.roles).map(([id, role]) => ({
        company: { id, name: COMPANIES[id].name },
        role,
      })),
    })
    await auth.setCustomUserClaims(user.uid, { roles: rolesClaim(user) })
  }
}

async function seedCatalog() {
  for (const [id, company] of Object.entries(COMPANIES)) {
    const batch = db.batch()
    const author = company.owner
    for (let i = 1; i <= 5; i++) {
      batch.set(db.doc(`companies/${id}/services/service-${i}`), {
        name: `Serviço ${i}`,
        value: i * 50,
        company: { id, name: company.name },
        ...audit(author, 90000),
      })
      batch.set(db.doc(`companies/${id}/products/product-${i}`), {
        name: `Peça ${i}`,
        value: i * 25,
        company: { id, name: company.name },
        ...audit(author, 90000),
      })
    }
    for (let i = 1; i <= 10; i++) {
      batch.set(db.doc(`companies/${id}/customers/customer-${i}`), {
        name: `Cliente ${String(i).padStart(2, '0')}`,
        phone: `+55119900000${String(i).padStart(2, '0')}`,
        company: { id, name: company.name },
        ...audit(author, 90000),
      })
      batch.set(db.doc(`companies/${id}/devices/device-${i}`), {
        name: `Veículo ${i}`,
        serial: `TST${String(i).padStart(4, '0')}`,
        company: { id, name: company.name },
        ...audit(author, 90000),
      })
    }
    await batch.commit()
  }
}

const STATUSES = ['quote', 'approved', 'progress', 'done', 'canceled']

async function seedOrders(companyId, count) {
  const company = COMPANIES[companyId]
  const authors = Object.values(USERS).filter((user) => user.roles[companyId])
  const writer = db.bulkWriter()
  writer.onWriteError((error) => error.failedAttempts < 3)
  for (let i = 1; i <= count; i++) {
    const author = authors[i % authors.length]
    const customer = (i % 10) + 1
    const value = 50 + (i % 20) * 25
    const status = STATUSES[i % STATUSES.length]
    void writer.set(db.doc(`companies/${companyId}/orders/order-${i}`), {
      number: i,
      status,
      company: { id: companyId, name: company.name },
      customer: { id: `customer-${customer}`, name: `Cliente ${String(customer).padStart(2, '0')}` },
      device: { id: `device-${customer}`, name: `Veículo ${customer}` },
      services: [{ service: { id: 'service-1', name: 'Serviço 1' }, value }],
      products: [],
      total: value,
      paidAmount: status === 'done' ? value : 0,
      payment: status === 'done' ? 'paid' : status === 'quote' || status === 'canceled' ? null : 'unpaid',
      ...audit(author, i * 30),
    })
  }
  await writer.close()
}

// Same hash as web-access.routes.ts. Everyone but the outsider is on the list.
async function seedWebAccess() {
  const hash = (email) => createHash('sha256').update(email.trim().toLowerCase()).digest('hex')
  await db.doc('config/webApp').set({
    open: false,
    allowedEmailHashes: Object.values(USERS).filter((user) => !user.blocked).map((user) => hash(user.email)),
  })
}

async function seedInvites() {
  for (const invite of Object.values(INVITES)) {
    const company = COMPANIES[invite.company]
    await db.doc(`links/invites/tokens/${invite.token}`).set({
      token: invite.token,
      company: { id: invite.company, name: company.name },
      role: invite.role,
      email: invite.email,
      invitedBy: aggr(company.owner),
      channel: 'app',
      status: 'pending',
      createdAt: iso(60),
      expiresAt: '2099-01-01T00:00:00.000Z',
    })
  }
}

const orders = Number(process.env.E2E_ORDERS ?? DEFAULT_ORDERS)
const started = Date.now()
await seedSegments()
await seedCompanies()
await seedUsers()
await seedCatalog()
await seedWebAccess()
await seedInvites()
await seedOrders(COMPANY_A, orders)
await seedOrders(COMPANY_B, 5)
console.log(`seed: ${Object.keys(USERS).length} usuários, ${orders} OS em ${Date.now() - started} ms`)
