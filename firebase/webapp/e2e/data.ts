// Orders made for one test, straight in the emulator, so tests that write do
// not step on each other (they run in parallel). Refuses to run outside it.
import { getApps, initializeApp } from 'firebase-admin/app'
import { getFirestore } from 'firebase-admin/firestore'
import { randomUUID } from 'node:crypto'
import { COMPANIES, COMPANY_A, COMPANY_B, PROJECT_ID, USERS } from './fixtures.mjs'

function db() {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error('FIRESTORE_EMULATOR_HOST ausente: os testes só rodam no emulador.')
  const app = getApps()[0] ?? initializeApp({ projectId: PROJECT_ID })
  return getFirestore(app)
}

type UserKey = keyof typeof USERS
const aggr = (user: UserKey) => ({ id: USERS[user].uid, name: USERS[user].name })

/** Noon in Brazil, `offset` days from today. */
export function brDay(offset = 0): string {
  const today = new Date().toLocaleDateString('en-CA', { timeZone: 'America/Sao_Paulo' })
  const date = new Date(`${today}T15:00:00.000Z`)
  date.setUTCDate(date.getUTCDate() + offset)
  return date.toISOString()
}

/**
 * The next order number from `base` (700000 in company A, 800000 in B), unique
 * across workers and runs: a counter in the emulator, read and bumped in one
 * transaction. Random numbers collided (R3 of receive.spec saw one test's
 * order with another's number).
 */
async function nextNumber(base: number): Promise<number> {
  const ref = db().doc(`e2eCounters/order-${base}`)
  const n = await db().runTransaction(async (tx) => {
    const next = ((await tx.get(ref)).data()?.next as number | undefined) ?? 0
    tx.set(ref, { next: next + 1 })
    return next
  })
  return base + (n % 99999)
}

export interface TestOrder {
  id: string
  number: number
}

/** A fresh order (company A unless another is given). Number is unique, so the row is easy to find. */
export async function makeOrder(author: UserKey, data: Record<string, unknown> = {}, company: string = COMPANY_A): Promise<TestOrder> {
  const id = `t-${randomUUID().slice(0, 8)}`
  const number = await nextNumber(700000)
  const now = new Date().toISOString()
  const services = (data.services as unknown[]) ?? [{ service: { id: 'service-1', name: 'Serviço 1', value: 50 }, value: 50 }]
  await db()
    .doc(`companies/${company}/orders/${id}`)
    .set({
      number,
      status: 'approved',
      company: { id: company, name: (COMPANIES as Record<string, { name: string }>)[company]?.name },
      customer: { id: 'customer-2', name: 'Cliente 02' },
      device: { id: 'device-2', name: 'Veículo 2', serial: 'TST0002' },
      devices: [{ id: 'device-2', name: 'Veículo 2', serial: 'TST0002' }],
      deviceIds: ['device-2'],
      services,
      products: [],
      total: 50,
      discount: 0,
      paidAmount: 0,
      payment: 'unpaid',
      paid: false,
      createdAt: now,
      createdBy: aggr(author),
      updatedAt: now,
      updatedBy: aggr(author),
      // Born done: the date of completion is already there, so the create trigger's
      // stamp finds nothing to write and no update trigger follows. The emulator runs
      // the triggers one at a time: each extra one delays the claims of an invite
      // accepted in another test (CI of #542: 23 s behind order triggers).
      ...(data.status === 'done' && !('completedAt' in data) ? { completedAt: new Date(Date.now() + 120_000).toISOString() } : {}),
      ...data,
    })
  return { id, number }
}

/** Another device saving: a plain field update, like the app. */
export async function updateOrderDoc(id: string, fields: Record<string, unknown>): Promise<void> {
  await db().doc(`companies/${COMPANY_A}/orders/${id}`).update({ ...fields, updatedAt: new Date().toISOString() })
}

/** Removes test orders of company A or B, so a repeated run starts from the same screen. */
export async function deleteOrderDocs(ids: { id: string; company: 'A' | 'B' }[]): Promise<void> {
  await Promise.all(ids.map(({ id, company }) => db().doc(`companies/${company === 'A' ? COMPANY_A : COMPANY_B}/orders/${id}`).delete()))
}

/** Like the app writes: the fields as given, updatedAt included (no server time added). */
export async function writeOrderFieldsRaw(id: string, fields: Record<string, unknown>): Promise<void> {
  await db().doc(`companies/${COMPANY_A}/orders/${id}`).update(fields)
}

export async function readComments(orderId: string): Promise<Record<string, unknown>[]> {
  const snapshot = await db().collection(`companies/${COMPANY_A}/orders/${orderId}/comments`).get()
  return snapshot.docs.map((doc) => doc.data())
}

export async function addCommentDoc(orderId: string, data: Record<string, unknown>): Promise<void> {
  await db().collection(`companies/${COMPANY_A}/orders/${orderId}/comments`).add({ createdAt: new Date().toISOString(), ...data })
}

export async function updateCustomerDoc(id: string, fields: Record<string, unknown>): Promise<void> {
  await db().doc(`companies/${COMPANY_A}/customers/${id}`).update(fields)
}

export async function countOrders(field: string, value: unknown): Promise<number> {
  return (await db().collection(`companies/${COMPANY_A}/orders`).where(field, '==', value).get()).size
}

export async function readOrder(id: string, company: string = COMPANY_A): Promise<Record<string, unknown> | undefined> {
  return (await db().doc(`companies/${company}/orders/${id}`).get()).data()
}

/** A fresh customer in company A, with a unique name (fatia 03 tests write and run in parallel). */
export async function makeCustomer(data: Record<string, unknown> = {}, company: string = COMPANY_A): Promise<{ id: string; name: string }> {
  const id = `c-${randomUUID().slice(0, 8)}`
  const name = (data.name as string) ?? `Freguês ${id.slice(2)}`
  await db()
    .doc(`companies/${company}/customers/${id}`)
    .set({ name, phone: null, company: { id: company, name: COMPANIES[company as keyof typeof COMPANIES].name }, createdAt: new Date().toISOString(), createdBy: aggr('owner'), ...data })
  return { id, name }
}

/**
 * A late order in company B. The order list tests count the late ones of
 * company A ("1 atrasada"), so a test that needs another one makes it here.
 */
export async function makeLateOrderInB(customer: { id: string; name: string }): Promise<void> {
  const now = new Date().toISOString()
  await db()
    .doc(`companies/${COMPANY_B}/orders/t-${randomUUID().slice(0, 8)}`)
    .set({
      number: await nextNumber(800000),
      status: 'approved',
      company: { id: COMPANY_B, name: COMPANIES[COMPANY_B].name },
      customer,
      dueDate: brDay(-3),
      services: [],
      products: [],
      total: 0,
      createdAt: now,
      createdBy: aggr('owner'),
      updatedAt: now,
    })
}

/** Fields of company B's document (merge). Tests that change it put it back. */
export async function updateCompanyB(fields: Record<string, unknown>): Promise<void> {
  await db().doc(`companies/${COMPANY_B}`).set(fields, { merge: true })
}

/** An order in company B (United States), for the country format tests. */
export async function makeOrderInB(data: Record<string, unknown>): Promise<TestOrder> {
  const id = `t-${randomUUID().slice(0, 8)}`
  const number = await nextNumber(800000)
  const now = new Date().toISOString()
  await db()
    .doc(`companies/${COMPANY_B}/orders/${id}`)
    .set({
      number,
      status: 'approved',
      company: { id: COMPANY_B, name: COMPANIES[COMPANY_B].name },
      customer: { id: 'cust-us', name: 'Dana Customer' },
      services: [],
      products: [],
      total: 0,
      createdAt: now,
      createdBy: aggr('owner'),
      updatedAt: now,
      ...data,
    })
  return { id, number }
}

/** A fresh device in company A, with a unique serial (three letters and four digits). */
export async function makeDevice(data: Record<string, unknown> = {}): Promise<{ id: string; name: string; serial: string }> {
  const id = `d-${randomUUID().slice(0, 8)}`
  const letters = Array.from({ length: 3 }, () => String.fromCharCode(65 + Math.floor(Math.random() * 26))).join('')
  const serial = (data.serial as string) ?? `${letters}${Math.floor(1000 + Math.random() * 8999)}`
  // Sorted after the seed's "Veículo N": the order tests list the first devices of the company.
  const name = (data.name as string) ?? `Yaris ${id.slice(2)}`
  await db()
    .doc(`companies/${COMPANY_A}/devices/${id}`)
    .set({ name, serial, company: { id: COMPANY_A, name: COMPANIES[COMPANY_A].name }, createdAt: new Date().toISOString(), createdBy: aggr('owner'), ...data })
  return { id, name, serial }
}

/** Customers of company A whose name starts with `prefix`. */
export async function countCustomersNamed(prefix: string): Promise<number> {
  const snapshot = await db().collection(`companies/${COMPANY_A}/customers`).where('name', '>=', prefix).where('name', '<', `${prefix}`).get()
  return snapshot.size
}

export async function readDoc(path: string): Promise<Record<string, unknown> | undefined> {
  return (await db().doc(`companies/${COMPANY_A}/${path}`).get()).data()
}

/**
 * Waits for the order triggers to recount the customer (`openOrders`,
 * customer-aggregates.service.ts): the Clientes list reads it from the customer.
 */
export async function waitForOpenOrders(customerId: string, count: number, company: string = COMPANY_A): Promise<void> {
  const ref = db().doc(`companies/${company}/customers/${customerId}`)
  for (const deadline = Date.now() + 20_000; Date.now() < deadline; await new Promise((done) => setTimeout(done, 250))) {
    if ((await ref.get()).data()?.openOrders === count) return
  }
  throw new Error(`customer ${customerId} never got openOrders = ${count}`)
}

/** A customer of the company with the direct nota on (e2e/customer-invoice.spec.ts). */
export async function makeCustomerInN(data: Record<string, unknown> = {}): Promise<{ id: string; name: string }> {
  return makeCustomer(data, 'company-nfse')
}

export async function readCustomerInN(id: string): Promise<Record<string, unknown> | undefined> {
  return (await db().doc(`companies/company-nfse/customers/${id}`).get()).data()
}

/** Writes any document of company A (charges the tests simulate, since Asaas is not in the emulator). */
export async function writeDoc(path: string, data: Record<string, unknown>, merge = false): Promise<void> {
  await db().doc(`companies/${COMPANY_A}/${path}`).set(data, { merge })
}

export async function queryDocs(collection: string, field: string, value: unknown): Promise<Record<string, unknown>[]> {
  return (await db().collection(`companies/${COMPANY_A}/${collection}`).where(field, '==', value).get()).docs.map((doc) => ({ id: doc.id, ...doc.data() }))
}

export async function readShareToken(token: string): Promise<Record<string, unknown> | undefined> {
  return (await db().doc(`links/share/tokens/${token}`).get()).data()
}

const CATALOG_COLLECTION = { service: 'services', product: 'products' } as const

/**
 * A fresh service or product in company A. Names start with "Zeta" so they sort
 * after the seed's "Serviço N" and "Peça N", which the order tests type.
 */
export async function makeCatalogItem(kind: 'service' | 'product', data: Record<string, unknown> = {}): Promise<{ id: string; name: string }> {
  const id = `k-${randomUUID().slice(0, 8)}`
  const name = (data.name as string) ?? `Zeta ${id.slice(2)}`
  const now = new Date().toISOString()
  await db()
    .doc(`companies/${COMPANY_A}/${CATALOG_COLLECTION[kind]}/${id}`)
    .set({ name, value: null, photo: null, company: { id: COMPANY_A, name: COMPANIES[COMPANY_A].name }, createdAt: now, createdBy: aggr('owner'), updatedAt: now, ...data })
  return { id, name }
}

export async function readCatalogItem(kind: 'service' | 'product', id: string): Promise<Record<string, unknown> | undefined> {
  return (await db().doc(`companies/${COMPANY_A}/${CATALOG_COLLECTION[kind]}/${id}`).get()).data()
}

/** Like the app saving the item: plain field update with a new updatedAt. */
export async function updateCatalogItem(kind: 'service' | 'product', id: string, fields: Record<string, unknown>): Promise<void> {
  await db().doc(`companies/${COMPANY_A}/${CATALOG_COLLECTION[kind]}/${id}`).update({ ...fields, updatedAt: new Date().toISOString() })
}

/** Items of company A whose name starts with `prefix`, with their data. */
export async function catalogNamed(kind: 'service' | 'product', prefix: string): Promise<Record<string, unknown>[]> {
  const snapshot = await db().collection(`companies/${COMPANY_A}/${CATALOG_COLLECTION[kind]}`).where('name', '>=', prefix).where('name', '<', `${prefix}\uf8ff`).get()
  return snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }))
}

// \u2500\u2500 Checklists (fatia 07) \u2500\u2500

type Question = { id: string; label: string; type: string; options?: string[] | null; required?: boolean; allowPhotos?: boolean }
const question = (q: Question) => ({ options: null, required: false, allowPhotos: true, labelI18n: null, optionsI18n: null, ...q })

/** A fresh checklist template in company A, with a unique title ("Zeta \u2026" sorts last). */
export async function makeTemplate(data: { title?: string; isActive?: boolean; description?: string | null; items?: Question[] } = {}): Promise<{ id: string; title: string }> {
  const id = `f-${randomUUID().slice(0, 8)}`
  const title = data.title ?? `Zeta ${id.slice(2)}`
  const now = new Date().toISOString()
  await db()
    .doc(`companies/${COMPANY_A}/forms/${id}`)
    .set({
      id,
      title,
      description: data.description ?? null,
      isActive: data.isActive ?? true,
      items: (data.items ?? [{ id: 'q1', label: 'Tudo certo?', type: 'boolean' }]).map(question),
      titleI18n: null,
      descriptionI18n: null,
      company: { id: COMPANY_A, name: COMPANIES[COMPANY_A].name },
      createdAt: now,
      createdBy: aggr('owner'),
      updatedAt: now,
      updatedBy: aggr('owner'),
    })
  return { id, title }
}

export async function readTemplate(id: string): Promise<Record<string, unknown> | undefined> {
  return (await db().doc(`companies/${COMPANY_A}/forms/${id}`).get()).data()
}

/** Like the app saving the template: the whole document, a new updatedAt. */
export async function updateTemplateDoc(id: string, fields: Record<string, unknown>): Promise<void> {
  await db().doc(`companies/${COMPANY_A}/forms/${id}`).set({ ...fields, updatedAt: new Date().toISOString() }, { merge: true })
}

export async function templatesNamed(prefix: string): Promise<Record<string, unknown>[]> {
  const snapshot = await db().collection(`companies/${COMPANY_A}/forms`).where('title', '>=', prefix).where('title', '<', `${prefix}\uf8ff`).get()
  return snapshot.docs.map((doc) => ({ docId: doc.id, ...doc.data() }))
}

/** A checklist already in an order (as FormsService.addFormToOrder writes it). */
export async function makeOrderForm(orderId: string, data: { title?: string; items?: Question[]; responses?: unknown[]; status?: string; deviceId?: string | null } = {}): Promise<string> {
  const now = new Date().toISOString()
  const ref = await db()
    .collection(`companies/${COMPANY_A}/orders/${orderId}/forms`)
    .add({
      formDefinitionId: 'seg-entrada',
      title: data.title ?? 'Vistoria de entrada',
      status: data.status ?? 'pending',
      items: (data.items ?? [{ id: 'q1', label: 'Tudo certo?', type: 'boolean' }]).map(question),
      responses: data.responses ?? [],
      startedAt: now,
      completedAt: null,
      updatedAt: now,
      titleI18n: null,
      deviceId: data.deviceId ?? null,
    })
  return ref.id
}

export async function readOrderForms(orderId: string): Promise<Record<string, unknown>[]> {
  const snapshot = await db().collection(`companies/${COMPANY_A}/orders/${orderId}/forms`).get()
  return snapshot.docs.map((doc) => ({ docId: doc.id, ...doc.data() }))
}

/** Companies a first access created for `user` (owner.id), with what the server put in them. */
export async function companiesOwnedBy(user: UserKey): Promise<{ id: string; data: Record<string, unknown>; forms: string[]; services: string[]; customers: string[]; orders: number }[]> {
  const snapshot = await db().collection('companies').where('owner.id', '==', USERS[user].uid).get()
  return Promise.all(
    snapshot.docs.map(async (doc) => {
      const [forms, services, customers, orders] = await Promise.all(
        ['forms', 'services', 'customers', 'orders'].map((name) => db().collection(`companies/${doc.id}/${name}`).get()),
      )
      return {
        id: doc.id,
        data: doc.data(),
        forms: forms!.docs.map((form) => form.id).sort(),
        services: services!.docs.map((service) => String(service.data().name)).sort(),
        customers: customers!.docs.map((customer) => String(customer.data().name)).sort(),
        orders: orders!.size,
      }
    }),
  )
}

/** Another device writing the checklist as it is (the app's offline path replaces the whole list). */
export async function writeOrderFormRaw(orderId: string, formId: string, fields: Record<string, unknown>): Promise<void> {
  await db().doc(`companies/${COMPANY_A}/orders/${orderId}/forms/${formId}`).update(fields)
}

/** "2026-11-03T00:00:00.000": a day in Brazil, `offset` days from today, as the app writes contract dates. */
export function brWall(offset = 0): string {
  return `${brDay(offset).slice(0, 10)}T00:00:00.000`
}

/** "03/11/2026": the same day as the screen shows it (pt-BR). */
export function brShown(wall: string): string {
  const [y, m, d] = wall.slice(0, 10).split('-')
  return `${d}/${m}/${y}`
}

/** An order that repeats (isContract + contract, OrderContract.toJson), in company A, for one test. */
export async function makeContract(author: UserKey, contract: Record<string, unknown> = {}, data: Record<string, unknown> = {}): Promise<TestOrder & { customer: string }> {
  const customer = `Contrato ${randomUUID().slice(0, 6)}`
  const order = await makeOrder(author, {
    status: 'approved',
    customer: { id: 'customer-2', name: customer },
    isContract: true,
    contract: {
      frequency: 'monthly',
      interval: 1,
      startDate: brWall(-20),
      endDate: null,
      nextDueDate: brWall(10),
      lastGeneratedDate: null,
      generatedCount: 0,
      autoGenerate: true,
      active: true,
      reminderDaysBefore: 3,
      parentOrderId: null,
      parentOrderNumber: null,
      ...contract,
    },
    ...data,
  })
  return { ...order, customer }
}

/** Any field of a company (Contratos on or off in company C). */
export async function setCompanyFields(company: string, fields: Record<string, unknown>): Promise<void> {
  await db().doc(`companies/${company}`).set(fields, { merge: true })
}

export async function readCompany(company: string): Promise<Record<string, unknown> | undefined> {
  return (await db().doc(`companies/${company}`).get()).data()
}

/** A ready-made checklist of the automotive segment, unique per test, so "Usar" can run again. */
export async function makeReadyTemplate(title: string): Promise<string> {
  const id = `seg-${randomUUID().slice(0, 8)}`
  await db()
    .doc(`segments/automotive/forms/${id}`)
    .set({ title, description: 'Só o teste de Usar', isActive: true, items: [question({ id: 'um', label: 'Uma pergunta', type: 'text' })] })
  return id
}

/** Fields of a checklist of company B (merge), so a test starts from the seed's state. */
export async function setTemplateInB(id: string, fields: Record<string, unknown>): Promise<void> {
  await db().doc(`companies/${COMPANY_B}/forms/${id}`).set({ ...fields, updatedAt: new Date().toISOString() }, { merge: true })
}

export async function readUser(uid: string): Promise<Record<string, unknown> | undefined> {
  return (await db().doc(`users/${uid}`).get()).data()
}

/** Writes a document of the company with the direct nota on (the emitters the server would write: e2e/nfse-direct.spec.ts). */
export async function writeDocInN(path: string, data: Record<string, unknown>, merge = false): Promise<void> {
  await db().doc(`companies/company-nfse/${path}`).set(data, { merge })
}

export async function deleteDocInN(path: string): Promise<void> {
  await db().doc(`companies/company-nfse/${path}`).delete()
}
