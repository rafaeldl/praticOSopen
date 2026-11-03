// Customers and devices through the API (/v1/app/customers, /v1/app/devices):
// reads that depend on orders come filtered by the role on the server, and
// every write goes there too. No Firestore here, so these screens add nothing
// to the Firestore chunk of the first download.
import { ApiError } from '@/lib/api'
import { api, session } from '@/lib/session'
import type { CustomerRow, DeviceRow, DeviceStatus } from './model'

export interface OrderSummary {
  id: string
  number?: number
  status: string
  customer?: { id?: string; name?: string }
  devices?: { id: string; name?: string; serial?: string | null }[]
  device?: { id: string; name?: string; serial?: string | null }
  dueDate?: string
  createdAt?: string
  total?: number
  paidAmount?: number
  payment?: string | null
}

export interface CustomerDetail {
  /** Opaque version, sent back on save: 409 when someone saved since. */
  version: string | null
  ordersTruncated: boolean
  /** Every order, receipt and charge of the customer, whoever reads them (told before deleting). */
  links: { orders: number; receipts: number; charges: number }
  customer: {
    id: string
    name: string
    phone: string | null
    email: string | null
    taxId: string | null
    address: string | null
    latitude: number | null
    longitude: number | null
    customData: Record<string, unknown> | null
  }
  orders: OrderSummary[]
  devices: { id: string; name: string; serial: string | null; count: number }[]
  spent: number | null
  owed: number | null
  receivable: string[]
  partial: boolean
}

export interface DeviceDetail {
  version: string | null
  device: {
    id: string
    name: string | null
    serial: string | null
    manufacturer: string | null
    category: string | null
    description: string | null
    status: DeviceStatus | null
    photo: string | null
    customData: Record<string, unknown> | null
    nextMaintenanceDate: string | null
    nextMaintenanceCustomer: { id?: string; name?: string } | null
    nextMaintenanceLastService: string | null
  }
  orders: OrderSummary[]
  owner: { id: string; name: string } | null
  lastService: string | null
  partial: boolean
}

const cache = new Map<string, Promise<unknown>>()

function cached<T>(name: string, load: () => Promise<T>): Promise<T> {
  const key = `${session.companyId}|${name}`
  let promise = cache.get(key) as Promise<T> | undefined
  if (!promise) {
    promise = load()
    cache.set(key, promise)
    promise.catch(() => cache.delete(key))
  }
  return promise
}

/** After any write: the next read asks the server again. */
export function forgetDirectory(): void {
  cache.clear()
}

export interface Directory<T> {
  rows: T[]
  truncated: boolean
  partial: boolean
}

export const loadCustomerDirectory = (fresh = false): Promise<Directory<CustomerRow>> => {
  if (fresh) forgetDirectory()
  return cached('customers', async () => {
    const body = await api<{ data: CustomerRow[]; meta?: { truncated?: boolean; partial?: boolean } }>('/v1/app/customers', { raw: true })
    return { rows: body.data ?? [], truncated: !!body.meta?.truncated, partial: !!body.meta?.partial }
  })
}

export const loadDeviceDirectory = (fresh = false): Promise<Directory<DeviceRow>> => {
  if (fresh) cache.delete(`${session.companyId}|devices`)
  return cached('devices', async () => {
    const body = await api<{ data: DeviceRow[]; meta?: { truncated?: boolean } }>('/v1/app/devices', { raw: true })
    return { rows: body.data ?? [], truncated: !!body.meta?.truncated, partial: false }
  })
}

export const loadCustomer = (id: string) => api<CustomerDetail>(`/v1/app/customers/${encodeURIComponent(id)}`)
export const loadDevice = (id: string) => api<DeviceDetail>(`/v1/app/devices/${encodeURIComponent(id)}`)

/** Someone saved the record since it was read (CUSTOMER_CHANGED, DEVICE_CHANGED). */
export const changedSince = (error: unknown) => error instanceof ApiError && error.status === 409 && /_CHANGED$/.test(error.code)

export interface CustomerInput {
  name?: string
  phone?: string | null
  email?: string | null
  address?: string | null
  taxId?: string | null
  customData?: Record<string, unknown> | null
}

export async function saveCustomer(id: string | null, input: CustomerInput & { version?: string }): Promise<string> {
  const result = id
    ? await api<{ id: string }>(`/v1/app/customers/${encodeURIComponent(id)}`, { method: 'PATCH', body: input })
    : await api<{ id: string }>('/v1/app/customers', { method: 'POST', body: input })
  forgetDirectory()
  return result.id
}

export async function deleteCustomer(id: string): Promise<void> {
  await api(`/v1/app/customers/${encodeURIComponent(id)}`, { method: 'DELETE' })
  forgetDirectory()
}

export async function importCustomers(importId: string, customers: CustomerInput[]): Promise<{ created: number; existing: number }> {
  return api('/v1/app/customers/import', { method: 'POST', body: { importId, customers } })
}

export interface DeviceInput {
  name?: string | null
  serial?: string | null
  manufacturer?: string | null
  category?: string | null
  description?: string | null
  status?: DeviceStatus | null
  customData?: Record<string, unknown> | null
}

export async function saveDevice(id: string | null, input: DeviceInput & { version?: string }): Promise<{ id: string; name?: string | null; serial?: string | null }> {
  const result = id
    ? await api<{ id: string }>(`/v1/app/devices/${encodeURIComponent(id)}`, { method: 'PATCH', body: input })
    : await api<{ id: string; name: string | null; serial: string | null }>('/v1/app/devices', { method: 'POST', body: input })
  forgetDirectory()
  return result
}

export async function deleteDevice(id: string): Promise<void> {
  await api(`/v1/app/devices/${encodeURIComponent(id)}`, { method: 'DELETE' })
  forgetDirectory()
}

export async function setNextMaintenance(id: string, date: string | null): Promise<void> {
  await api(`/v1/app/devices/${encodeURIComponent(id)}/next-maintenance`, { method: 'PUT', body: { date } })
  forgetDirectory()
}
