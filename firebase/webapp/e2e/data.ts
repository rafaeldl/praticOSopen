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

export interface TestOrder {
  id: string
  number: number
}

/** A fresh order in company A. Number is unique, so the row is easy to find. */
export async function makeOrder(author: UserKey, data: Record<string, unknown> = {}): Promise<TestOrder> {
  const id = `t-${randomUUID().slice(0, 8)}`
  const number = 700000 + Math.floor(Math.random() * 99999)
  const now = new Date().toISOString()
  const services = (data.services as unknown[]) ?? [{ service: { id: 'service-1', name: 'Serviço 1', value: 50 }, value: 50 }]
  await db()
    .doc(`companies/${COMPANY_A}/orders/${id}`)
    .set({
      number,
      status: 'approved',
      company: { id: COMPANY_A, name: COMPANIES[COMPANY_A].name },
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
      ...data,
    })
  return { id, number }
}

/** Another device saving: a plain field update, like the app. */
export async function updateOrderDoc(id: string, fields: Record<string, unknown>): Promise<void> {
  await db().doc(`companies/${COMPANY_A}/orders/${id}`).update({ ...fields, updatedAt: new Date().toISOString() })
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

export async function readOrder(id: string): Promise<Record<string, unknown> | undefined> {
  return (await db().doc(`companies/${COMPANY_A}/orders/${id}`).get()).data()
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
      number: 800000 + Math.floor(Math.random() * 99999),
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
