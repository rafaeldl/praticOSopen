// Orders made for one test, straight in the emulator, so tests that write do
// not step on each other (they run in parallel). Refuses to run outside it.
import { getApps, initializeApp } from 'firebase-admin/app'
import { getFirestore } from 'firebase-admin/firestore'
import { randomUUID } from 'node:crypto'
import { COMPANIES, COMPANY_A, PROJECT_ID, USERS } from './fixtures.mjs'

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
