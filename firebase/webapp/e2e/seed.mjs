// Deterministic seed for the Emulator Suite. E2E_ORDERS=10000 generates the big list.
// Refuses to run unless every Admin SDK client points at a local emulator.
import { initializeApp } from 'firebase-admin/app'
import { getAuth } from 'firebase-admin/auth'
import { getFirestore } from 'firebase-admin/firestore'
import { createHash } from 'node:crypto'
import { COMPANIES, COMPANY_A, COMPANY_B, COMPANY_C, DEFAULT_ORDERS, INVITES, PASSWORD, PROJECT_ID, USERS } from './fixtures.mjs'

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
  // Phone mask by country (as firebase/scripts/seed_segments.js) and the segment form fields of fatia 03.
  await db.doc('segments/global').set({
    name: 'Global',
    customFields: [
      { key: 'customer.phone', type: 'text', labels: { 'pt-BR': 'Telefone', 'en-US': 'Phone', 'es-ES': 'Teléfono' }, masksByCountry: { BR: ['(99) 9999-9999', '(99) 99999-9999'], US: ['(999) 999-9999'] }, keyboardType: 'phone' },
    ],
  })
  await db.doc('segments/automotive').set({
    name: 'Mecânica',
    customFields: [
      label('device._entity', 'Veículo', 'Vehicle', 'Vehículo'),
      label('device._entity_plural', 'Veículos', 'Vehicles', 'Vehículos'),
      label('status.in_progress', 'Na oficina', 'In the shop', 'En el taller'),
      {
        key: 'device.serial', type: 'text', labels: { 'pt-BR': 'Placa', 'en-US': 'License plate', 'es-ES': 'Placa' },
        masksByCountry: { BR: ['AAA-9999', 'AAA9N99'] }, textCapitalization: 'characters',
      },
      {
        key: 'customer.birthday', type: 'date', labels: { 'pt-BR': 'Aniversário', 'en-US': 'Birthday', 'es-ES': 'Cumpleaños' },
        section: 'Extra', sectionI18n: { 'pt-BR': 'Mais sobre o cliente', 'en-US': 'More about the customer', 'es-ES': 'Más sobre el cliente' }, order: 1,
      },
      { key: 'device.mileage', type: 'number', labels: { 'pt-BR': 'Quilometragem', 'en-US': 'Mileage', 'es-ES': 'Kilometraje' }, min: 0, max: 9999999, order: 1 },
      { key: 'device.fuel', type: 'select', labels: { 'pt-BR': 'Combustível', 'en-US': 'Fuel', 'es-ES': 'Combustible' }, options: ['Flex', 'Diesel'], order: 2 },
      // Catalog (fatia 05): products named by the segment, and one segment field of a service.
      label('product._entity', 'Peça', 'Part', 'Pieza'),
      label('product._entity_plural', 'Peças', 'Parts', 'Piezas'),
      { key: 'service.warranty', type: 'text', labels: { 'pt-BR': 'Garantia', 'en-US': 'Warranty', 'es-ES': 'Garantía' }, order: 1 },
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
      // Device status and its list column (fatia 03); only the first company.
      ...(id === COMPANY_A ? { useDeviceManagement: true } : {}),
      ...(company.useFinancial === false ? { useFinancial: false } : {}),
      owner: aggr(company.owner),
      users: members.map((user) => ({ user: aggr(user), role: user.roles[id] })),
      // Next number after the seeded ones (1..E2E_ORDERS and the scenario 501..509), like a real counter.
      nextOrderNumber: Math.max(Number(process.env.E2E_ORDERS ?? DEFAULT_ORDERS), 509) + 1,
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
    // Payment links (Asaas pilot) on in company A. The charges themselves are
    // simulated by the tests: no Asaas account exists in the emulator.
    // Notas fiscais (fatia 6) too: on and set up, so the list and "Emitir nota fiscal" show. Asaas itself is simulated.
    if (id === COMPANY_A) {
      batch.set(db.doc(`companies/${id}/settings/payments`), {
        asaasEnabled: true, asaasConnected: true, asaasEnvironment: 'sandbox', nfseEnabled: true, nfseReady: true,
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

// Orders whose dates must sit around the day the tests run (late, today, visit):
// relative to now, at noon in Brazil, so the day is the same in the browser.
function brDay(offset) {
  const today = new Date().toLocaleDateString('en-CA', { timeZone: 'America/Sao_Paulo' })
  const date = new Date(`${today}T15:00:00.000Z`)
  date.setUTCDate(date.getUTCDate() + offset)
  return date.toISOString()
}

async function seedScenario() {
  const company = { id: COMPANY_A, name: COMPANIES[COMPANY_A].name }
  const customer = (n) => ({ id: `customer-${n}`, name: `Cliente ${String(n).padStart(2, '0')}` })
  const device = (n) => ({ id: `device-${n}`, name: `Veículo ${n}`, serial: `TST${String(n).padStart(4, '0')}` })
  const service = (n, value) => ({ service: { id: `service-${n}`, name: `Serviço ${n}`, value: n * 50 }, value })
  // Created "in the future" so they stay on the first page above the orders
  // the tests make while running (those carry the real now).
  const AHEAD = -5 * 365 * 24 * 60
  const base = (number, author, minutesAgo, extra) => ({
    number,
    company,
    products: [],
    discount: 0,
    paidAmount: 0,
    payment: 'unpaid',
    paid: false,
    ...audit(author, AHEAD + minutesAgo),
    ...extra,
  })
  const orders = {
    'scn-late': base(501, USERS.admin, -100, {
      status: 'approved', customer: customer(3), device: device(3), devices: [device(3)], deviceIds: ['device-3'],
      services: [service(2, 100)], total: 100, dueDate: brDay(-3),
    }),
    'scn-today': base(502, USERS.admin, -90, {
      status: 'progress', customer: customer(4), device: device(4), devices: [device(4)], deviceIds: ['device-4'],
      services: [service(1, 50)], total: 50, dueDate: brDay(0),
    }),
    'scn-hold': base(503, USERS.admin, -80, {
      status: 'progress', customer: customer(5), services: [service(3, 150)], total: 150,
      onHold: { reason: 'part', note: 'Peça chega sexta', since: brDay(-2) },
    }),
    'scn-owed': base(504, USERS.admin, -70, {
      status: 'done', customer: customer(6), services: [service(4, 300)], total: 300, paidAmount: 100, payment: 'unpaid',
    }),
    'scn-quote-old': base(505, USERS.consultant, -40, {
      status: 'quote', customer: customer(7), services: [service(1, 50)], total: 50, payment: null,
    }),
    'scn-tech-visit': base(506, USERS.technician, -60, {
      status: 'approved', customer: customer(8), services: [service(1, 50)], total: 50,
      assignedTo: aggr(USERS.technician), scheduledDate: brDay(0),
    }),
    'scn-tech-quote': base(507, USERS.technician, -50, {
      status: 'quote', customer: customer(9), services: [service(2, 100)], total: 100, payment: null,
    }),
    // Created by the admin and given to the technician: shows in their Minhas (#514, assignedTo).
    'scn-assigned': base(508, USERS.admin, -30, {
      status: 'approved', customer: customer(10), services: [service(1, 50)], total: 50,
      assignedTo: aggr(USERS.technician),
    }),
    // Saved by the app: updatedAt in local time without a zone, with microseconds (Dart toIso8601String).
    'scn-app-saved': base(509, USERS.admin, -20, {
      status: 'done', customer: customer(1), services: [service(1, 80)], total: 80,
      updatedAt: '2026-10-01T09:00:00.123456',
    }),
  }
  const batch = db.batch()
  for (const [id, data] of Object.entries(orders)) batch.set(db.doc(`companies/${COMPANY_A}/orders/${id}`), data)
  batch.set(db.doc(`companies/${COMPANY_A}/orders/scn-hold/comments/c1`), {
    text: 'Pedi a peça ao fornecedor', authorType: 'internal', author: { name: USERS.admin.name, userId: USERS.admin.uid },
    source: 'app', isInternal: true, createdAt: iso(10),
  })
  await batch.commit()
}

// Financeiro (fatia 6): a closed month with known numbers, March 2026 in São Paulo.
// Numbers 9101+ stay far from the counter the tests use.
async function seedFinance() {
  const company = { id: COMPANY_A, name: COMPANIES[COMPANY_A].name }
  const ana = { id: 'fin-ana', name: 'Ana Financeiro' }
  const bia = { id: 'fin-bia', name: 'Bia Financeiro' }
  const by = aggr(USERS.admin)
  const base = (number, extra) => ({
    number, company, createdBy: by, updatedBy: by, discount: 0, products: [],
    services: [{ service: { id: 'service-1', name: 'Serviço 1' }, value: extra.total }], ...extra,
  })
  const orders = {
    // Paid in March: 200 of service, 100 of parts.
    'fin-paid': base(9101, {
      status: 'done', customer: ana, total: 300, paidAmount: 300, payment: 'paid', paid: true,
      services: [{ service: { id: 'service-2', name: 'Revisão completa' }, value: 200 }],
      products: [{ product: { id: 'product-1', name: 'Filtro de óleo' }, value: 50, quantity: 2, total: 100 }],
      transactions: [{ id: 'fin-t1', type: 'payment', amount: 300, paidAt: '2026-03-12T15:00:00.000Z', createdAt: '2026-03-12T15:00:00.000Z', createdBy: by, paymentMethod: 'pix' }],
      lastPaymentAt: '2026-03-12T15:00:00.000Z',
      createdAt: '2026-03-10T15:00:00.000Z', updatedAt: '2026-03-12T15:00:00.000Z',
    }),
    // Opened in February, paid in March: Recebido of March, Vendido of February.
    'fin-feb': base(9102, {
      status: 'done', customer: bia, total: 80, paidAmount: 80, payment: 'paid', paid: true,
      transactions: [{ id: 'fin-t2', type: 'payment', amount: 80, paidAt: '2026-03-02T15:00:00.000Z', createdAt: '2026-03-02T15:00:00.000Z', createdBy: by }],
      lastPaymentAt: '2026-03-02T15:00:00.000Z',
      createdAt: '2026-02-20T15:00:00.000Z', updatedAt: '2026-03-02T15:00:00.000Z',
    }),
    // Last day of March, 23:30 in São Paulo, written by the app (no zone): in March.
    'fin-last-day': base(9103, {
      status: 'approved', customer: bia, total: 50, paidAmount: 0, payment: 'unpaid', paid: false,
      createdAt: '2026-03-31T23:30:00.000123', updatedAt: '2026-03-31T23:30:00.000123',
    }),
    // Midnight of April 1st in São Paulo: April, not March.
    'fin-april': base(9104, {
      status: 'approved', customer: ana, total: 999, paidAmount: 0, payment: 'unpaid', paid: false,
      createdAt: '2026-04-01T03:00:00.000Z', updatedAt: '2026-04-01T03:00:00.000Z',
    }),
    // Quote of March: never in the numbers.
    'fin-quote': base(9105, {
      status: 'quote', customer: ana, total: 5000, payment: null, paid: false,
      createdAt: '2026-03-15T15:00:00.000Z', updatedAt: '2026-03-15T15:00:00.000Z',
    }),
  }
  const batch = db.batch()
  for (const [id, data] of Object.entries(orders)) batch.set(db.doc(`companies/${COMPANY_A}/orders/${id}`), data)

  // Notas fiscais of this month (the list opens on it).
  const today = new Date().toLocaleDateString('en-CA', { timeZone: 'America/Sao_Paulo' })
  const nota = (extra) => ({
    customer: { id: 'customer-6', name: 'Cliente 06' }, value: 270, effectiveDate: today,
    createdBy: by, createdAt: new Date().toISOString(), updatedAt: new Date().toISOString(), asaasEnvironment: 'sandbox', ...extra,
  })
  batch.set(db.doc(`companies/${COMPANY_A}/invoices/nf-ok`), nota({
    status: 'authorized', number: '4521', orderIds: ['scn-owed'], orders: [{ orderId: 'scn-owed', orderNumber: 504, value: 270 }],
    pdfUrl: 'https://sandbox.asaas.test/nota-4521.pdf', xmlUrl: 'https://sandbox.asaas.test/nota-4521.xml',
  }))
  batch.set(db.doc(`companies/${COMPANY_A}/invoices/nf-refused`), nota({
    status: 'error', customer: { id: 'customer-7', name: 'Cliente 07' }, value: 50, orderIds: ['scn-quote-old'],
    orders: [{ orderId: 'scn-quote-old', orderNumber: 505, value: 50 }], statusDescription: 'CEP do cliente é inválido.',
  }))
  await batch.commit()
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
// The big list measures the list alone; the scenarios are for the screen tests.
if (orders <= DEFAULT_ORDERS) {
  await seedScenario()
  await seedFinance()
}
console.log(`seed: ${Object.keys(USERS).length} usuários, ${orders} OS em ${Date.now() - started} ms`)
