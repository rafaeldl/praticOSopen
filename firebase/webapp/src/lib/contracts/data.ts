// Recurring contracts in Firestore, by its REST API with a field mask: only the
// contract, the customer, the devices and who created it travel. No price or
// payment of the order reaches the browser, for any role (supervisor and
// technician do not see values), and nothing goes to the persistent cache.
//
// Writes change only the contract fields, with the version read as a
// precondition (`updateTime`): if the app or another tab saved the order since,
// the web reads it again and writes only if the contract fields it changes are
// still as they were. Offline, the request fails and the screen says so (the
// web has no offline queue).
import { ApiError } from '@/lib/api'
import { authClient } from '@/lib/firebase'
import { can, session } from '@/lib/session'
import { wallText } from '@/lib/zone'
import { normalizeContract, type Contract, type ContractPatch } from './model'

// import.meta.env read in place, so the emulator branch is dropped from production builds.
function host(): string {
  return import.meta.env.VITE_USE_EMULATORS === '1' ? `http://127.0.0.1:${import.meta.env.VITE_EMULATOR_FIRESTORE_PORT ?? 8080}` : 'https://firestore.googleapis.com'
}
const root = () => `projects/${import.meta.env.VITE_FIREBASE_PROJECT_ID}/databases/(default)/documents`
const companyId = () => session.companyId as string
const orderName = (id: string) => `${root()}/companies/${companyId()}/orders/${id}`

/** Who only sees their own orders (consultant, technician): every query says so, as the rules ask. */
const ownOnly = () => !can('viewAllOrders')

async function call<T>(path: string, init: { method?: string; body?: unknown } = {}): Promise<T> {
  const auth = await authClient()
  const token = await auth.currentUser?.getIdToken()
  let response: Response
  try {
    response = await fetch(`${host()}/v1/${path}`, {
      method: init.method ?? 'GET',
      headers: { Authorization: `Bearer ${token}`, ...(init.body ? { 'Content-Type': 'application/json' } : {}) },
      body: init.body ? JSON.stringify(init.body) : undefined,
    })
  } catch (error) {
    console.warn('contracts: request failed', error)
    throw new ApiError('NETWORK', 0, 'web.error.network')
  }
  if (!response.ok) {
    const text = await response.text().catch(() => '')
    if (text.includes('FAILED_PRECONDITION') || response.status === 409) throw new ApiError('FAILED_PRECONDITION', 409, 'web.error.orderChanged')
    if (response.status === 403) throw new ApiError('FORBIDDEN', 403, 'web.error.forbidden')
    if (response.status === 404) throw new ApiError('NOT_FOUND', 404, 'web.error.notFound')
    throw new ApiError('FIRESTORE', response.status, 'web.error.generic')
  }
  return (await response.json()) as T
}

// ---------------------------------------------------------------------------
// Firestore REST values
// ---------------------------------------------------------------------------

type Value = Record<string, unknown>

/** REST value → plain JS (timestamps stay ISO text with Z). */
export function fromValue(value: Value | undefined): unknown {
  if (!value) return null
  if ('nullValue' in value) return null
  if ('stringValue' in value) return value.stringValue
  if ('booleanValue' in value) return value.booleanValue
  if ('integerValue' in value) return Number(value.integerValue)
  if ('doubleValue' in value) return Number(value.doubleValue)
  if ('timestampValue' in value) return value.timestampValue
  if ('arrayValue' in value) return ((value.arrayValue as { values?: Value[] }).values ?? []).map(fromValue)
  if ('mapValue' in value) return fromFields((value.mapValue as { fields?: Record<string, Value> }).fields)
  return null
}

export function fromFields(fields: Record<string, Value> | undefined): Record<string, unknown> {
  return Object.fromEntries(Object.entries(fields ?? {}).map(([key, value]) => [key, fromValue(value)]))
}

/** Plain JS → REST value. Whole numbers are integers, as Dart writes `int`. */
export function toValue(value: unknown): Value {
  if (value === null || value === undefined) return { nullValue: null }
  if (typeof value === 'string') return { stringValue: value }
  if (typeof value === 'boolean') return { booleanValue: value }
  if (typeof value === 'number') return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value }
  if (Array.isArray(value)) return { arrayValue: { values: value.map(toValue) } }
  return { mapValue: { fields: Object.fromEntries(Object.entries(value as Record<string, unknown>).map(([k, v]) => [k, toValue(v)])) } }
}

// ---------------------------------------------------------------------------
// Reading
// ---------------------------------------------------------------------------

export interface ContractOrder {
  id: string
  number: number | null
  status: string
  customer: { id?: string; name?: string } | null
  devices: { id?: string; name?: string; serial?: string | null }[]
  createdBy: { id?: string; name?: string } | null
  isContract: boolean
  contract: Contract | null
  /** Firestore's version of the document, the precondition of a write. */
  updateTime: string
}

const FIELDS = ['number', 'status', 'customer', 'device', 'devices', 'createdBy', 'isContract', 'contract']

function contractOrderOf(doc: { name: string; fields?: Record<string, Value>; updateTime: string }): ContractOrder {
  const data = fromFields(doc.fields)
  const devices = Array.isArray(data.devices) && data.devices.length ? data.devices : data.device ? [data.device] : []
  return {
    id: doc.name.split('/').pop() as string,
    number: typeof data.number === 'number' ? data.number : null,
    status: typeof data.status === 'string' ? data.status : 'quote',
    customer: (data.customer as ContractOrder['customer']) ?? null,
    devices: devices as ContractOrder['devices'],
    createdBy: (data.createdBy as ContractOrder['createdBy']) ?? null,
    isContract: data.isContract === true,
    contract: normalizeContract(data.contract, wallText),
    updateTime: doc.updateTime,
  }
}

type Filter = { field: string; value: unknown }

async function query(filters: Filter[]): Promise<ContractOrder[]> {
  const all = ownOnly() ? [...filters, { field: 'createdBy.id', value: session.uid }] : filters
  const fieldFilters = all.map((f) => ({ fieldFilter: { field: { fieldPath: f.field }, op: 'EQUAL', value: toValue(f.value) } }))
  const where = fieldFilters.length === 1 ? fieldFilters[0] : { compositeFilter: { op: 'AND', filters: fieldFilters } }
  const rows = await call<{ document?: { name: string; fields?: Record<string, Value>; updateTime: string } }[]>(`${root()}/companies/${companyId()}:runQuery`, {
    method: 'POST',
    body: {
      structuredQuery: {
        from: [{ collectionId: 'orders' }],
        where,
        select: { fields: FIELDS.map((fieldPath) => ({ fieldPath })) },
        limit: 1000,
      },
    },
  })
  return rows.filter((row) => row.document).map((row) => contractOrderOf(row.document!))
}

/** The orders that repeat (isContract == true); consultant and technician only theirs, like the app. */
export function loadContracts(): Promise<ContractOrder[]> {
  return query([{ field: 'isContract', value: true }])
}

/** Orders a contract generated (contract.parentOrderId), as the app's streamChildOrders. */
export function loadGenerated(templateId: string): Promise<ContractOrder[]> {
  return query([{ field: 'contract.parentOrderId', value: templateId }])
}

/** One order's contract fields. */
export async function loadContractOrder(id: string): Promise<ContractOrder> {
  const mask = FIELDS.map((field) => `mask.fieldPaths=${field}`).join('&')
  const doc = await call<{ name: string; fields?: Record<string, Value>; updateTime: string }>(`${orderName(id)}?${mask}`)
  return contractOrderOf(doc)
}

// ---------------------------------------------------------------------------
// Writing
// ---------------------------------------------------------------------------

/** Someone else changed the same contract fields since the screen read them. */
export class ContractChanged extends Error {
  constructor(readonly current: ContractOrder) {
    super('CONTRACT_CHANGED')
  }
}

const author = () => ({ id: session.uid, name: session.name ?? session.email ?? '' })

async function commit(id: string, fields: Record<string, unknown>, mask: string[], precondition: { updateTime: string } | { exists: true }): Promise<void> {
  const data: Record<string, unknown> = { ...fields, updatedAt: new Date().toISOString(), updatedBy: author() }
  // A field in the mask and missing from `fields` is deleted (pausedAt on "Retomar").
  const present = Object.fromEntries(Object.entries(data).filter(([, value]) => value !== undefined))
  const nested: Record<string, unknown> = {}
  for (const [path, value] of Object.entries(present)) {
    const [head, tail] = path.split('.') as [string, string | undefined]
    if (tail) nested[head] = { ...((nested[head] as Record<string, unknown>) ?? {}), [tail]: value }
    else nested[head] = value
  }
  await call(`${root()}:commit`, {
    method: 'POST',
    body: {
      writes: [
        {
          update: { name: orderName(id), fields: (toValue(nested).mapValue as { fields: Record<string, Value> }).fields },
          updateMask: { fieldPaths: [...mask, 'updatedAt', 'updatedBy'] },
          currentDocument: precondition,
        },
      ],
    },
  })
}

const same = (a: unknown, b: unknown) => JSON.stringify(a ?? null) === JSON.stringify(b ?? null)

/**
 * Writes only the changed contract fields over the version read. If the order
 * was saved since, reads it again: unchanged in those fields, writes over the
 * new version; changed, throws ContractChanged with what is there now.
 */
export async function saveContract(order: ContractOrder, patch: ContractPatch): Promise<void> {
  const keys = Object.keys(patch) as (keyof ContractPatch)[]
  if (!keys.length) return
  const fields: Record<string, unknown> = {}
  for (const key of keys) fields[`contract.${key}`] = key === 'pausedAt' && patch.pausedAt === null ? undefined : patch[key]
  const mask = keys.map((key) => `contract.${key}`)
  try {
    await commit(order.id, fields, mask, { updateTime: order.updateTime })
  } catch (error) {
    if (!(error instanceof ApiError) || error.code !== 'FAILED_PRECONDITION') throw error
    const current = await loadContractOrder(order.id)
    const unchanged = keys.every((key) => same(current.contract?.[key], order.contract?.[key]))
    if (!unchanged || !current.contract) throw new ContractChanged(current)
    await commit(order.id, fields, mask, { updateTime: current.updateTime })
  }
}

/** A new contract on an order just created (Novo contrato): the whole map, as OrderContract.toJson. */
export async function startContract(orderId: string, contract: Contract): Promise<void> {
  const { pausedAt: _web, ...appShape } = contract
  await commit(orderId, { contract: appShape, isContract: true }, ['contract', 'isContract'], { exists: true })
}

/** "Usar contratos" (contract.off.turn-on): only `useContracts` of the company. */
export async function turnOnContracts(): Promise<void> {
  await call(`${root()}:commit`, {
    method: 'POST',
    body: {
      writes: [
        {
          update: { name: `${root()}/companies/${companyId()}`, fields: { useContracts: { booleanValue: true } } },
          updateMask: { fieldPaths: ['useContracts'] },
          currentDocument: { exists: true },
        },
      ],
    },
  })
}
