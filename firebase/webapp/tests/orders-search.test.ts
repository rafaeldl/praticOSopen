// Search of Início (Lista and Quadro) asked to the server: number, customer and
// vehicle, each an indexed query, with the owner filter for who sees only their own.
import { afterEach, describe, expect, test, vi } from 'vitest'

const calls: unknown[][] = []
const apiCalls: string[] = []
vi.mock('../src/lib/firebase', () => ({ firestoreClient: vi.fn(async () => ({})), firestoreLite: vi.fn(async () => ({})) }))
vi.mock('../src/lib/orders/catalog', () => ({
  loadCustomers: async () => [
    { id: 'c-zeca', name: 'Zeca Antiguidades' },
    { id: 'c-ana', name: 'Ana Zélia' },
  ],
  loadDevices: async () => [{ id: 'd-fusca', name: 'Fusca 1970', serial: 'OLD1970' }],
}))
vi.mock('firebase/firestore/lite', () => {
  const record = (name: string) => (...args: unknown[]) => {
    calls.push([name, ...args])
    return { name, args }
  }
  return {
    collection: record('collection'),
    documentId: () => '__name__',
    where: record('where'),
    orderBy: record('orderBy'),
    limit: record('limit'),
    query: record('query'),
    getDocs: vi.fn(async (q: { args: { name: string; args: unknown[] }[] }) => {
      const filters = q.args.filter((part) => part?.name === 'where').map((part) => part.args)
      if (filters.some(([field]) => field === 'customer.id')) return { docs: [{ id: 'o900', data: () => ({ number: 900, status: 'progress' }) }] }
      if (filters.some(([field]) => field === 'deviceIds')) return { docs: [{ id: 'o900', data: () => ({ number: 900, status: 'progress' }) }, { id: 'o2', data: () => ({ number: 2, status: 'done' }) }] }
      if (filters.some(([field]) => field === 'number')) return { docs: [{ id: 'o900', data: () => ({ number: 900, status: 'progress' }) }] }
      return { docs: [] }
    }),
  }
})
vi.mock('../src/lib/session', () => ({
  session: { companyId: 'c1', uid: 'u1' },
  can: () => true,
  api: vi.fn(async (path: string) => {
    apiCalls.push(path)
    return { data: [{ id: 'o900', number: 900, status: 'progress' }] }
  }),
}))

import { matchIds, searchOrders } from '../src/lib/orders/search'

const admin = { companyId: 'c1', uid: 'u1', seesAll: true, showsMoney: true }
const consultant = { companyId: 'c1', uid: 'cons', seesAll: false, showsMoney: true }
const technician = { companyId: 'c1', uid: 'tech', seesAll: false, showsMoney: false }
const wheres = () => calls.filter((call) => call[0] === 'where').map((call) => call.slice(1))

afterEach(() => {
  calls.length = 0
  apiCalls.length = 0
})

describe('search of Início', () => {
  test('words match the start of a word of the customer, the vehicle or its plate, without accents', () => {
    const customers = [
      { id: 'a', name: 'Zeca Antiguidades' },
      { id: 'b', name: 'Ana Zélia' },
    ]
    const devices = [{ id: 'f', name: 'Fusca 1970', serial: 'OLD1970' }]
    expect(matchIds('zec', customers, devices)).toEqual({ customers: ['a'], devices: [] })
    expect(matchIds('zelia', customers, devices).customers).toEqual(['b'])
    expect(matchIds('old1970', customers, devices).devices).toEqual(['f'])
    expect(matchIds('  ', customers, devices)).toEqual({ customers: [], devices: [] })
  })

  test('who sees every order: customer by `in`, newest first; vehicle by deviceIds; one copy of each order', async () => {
    const found = await searchOrders(admin, 'Zeca')
    expect(found.map((order) => order.id)).toEqual(['o900'])
    expect(wheres()).toEqual([['customer.id', 'in', ['c-zeca']]])
    expect(calls.filter((call) => call[0] === 'orderBy').map((call) => call.slice(1))).toEqual([['createdAt', 'desc']])
    calls.length = 0
    const byVehicle = await searchOrders(admin, 'fusca')
    expect(byVehicle.map((order) => order.id)).toEqual(['o900', 'o2'])
    expect(wheres()).toEqual([['deviceIds', 'array-contains-any', ['d-fusca']]])
  })

  test('who sees only their own: createdBy on the customer query, and no vehicle query (no index for it)', async () => {
    await searchOrders(consultant, 'fusca')
    expect(wheres().some(([field]) => field === 'deviceIds')).toBe(false)
    calls.length = 0
    await searchOrders(consultant, 'Zeca')
    expect(wheres()).toEqual([
      ['createdBy.id', '==', 'cons'],
      ['customer.id', 'in', ['c-zeca']],
    ])
  })

  test('a number asks number ==', async () => {
    const found = await searchOrders(admin, '900')
    expect(found.map((order) => order.id)).toEqual(['o900'])
    expect(wheres()).toContainEqual(['number', '==', 900])
  })

  test('who does not see values asks the API: number and customer, which applies who sees what', async () => {
    await searchOrders(technician, 'Zeca')
    expect(apiCalls).toEqual(['/v1/app/orders?customerId=c-zeca&limit=50'])
    apiCalls.length = 0
    await searchOrders(technician, '900')
    expect(apiCalls).toEqual(['/v1/app/orders?number=900'])
  })
})
