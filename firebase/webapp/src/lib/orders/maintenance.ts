// "Quando é a próxima manutenção?" after the order is done (device.maintenance.*,
// docs/DEVICE_NEXT_MAINTENANCE.md). Same rules as the app's next_maintenance_offer:
// only who manages devices, an order with devices and no contract, devices with
// an active contract left out, 3 refusals in a row stop the question (per
// company, in this browser), setting a date resets the count. The date goes
// through the API, which keeps the customer and the main service.
import { loadContractOrder, loadContracts } from '@/lib/contracts/data'
import { loadDeviceDirectory, setNextMaintenance } from '@/lib/customers/data'
import { toIsoDay } from '@/lib/format'
import { can, session } from '@/lib/session'
import { readStorage, writeStorage } from '@/lib/storage'
import type { Order } from './model'

export const OFFER_LIMIT = 3
const key = () => `praticos.maintenanceDeclined.${session.companyId}`

export function declines(): number {
  return Number(readStorage(key()) ?? 0) || 0
}
export function decline(): void {
  writeStorage(key(), String(declines() + 1))
}
export function resetDeclines(): void {
  writeStorage(key(), '0')
}

/** Months later, on the last day of the month when it is shorter (31 Jan + 1 month = 28/29 Feb). */
export function addMonths(day: string, months: number): string {
  const [y, m, d] = day.split('-').map(Number) as [number, number, number]
  const first = new Date(Date.UTC(y, m - 1 + months, 1))
  const last = new Date(Date.UTC(first.getUTCFullYear(), first.getUTCMonth() + 1, 0)).getUTCDate()
  return `${first.getUTCFullYear()}-${String(first.getUTCMonth() + 1).padStart(2, '0')}-${String(Math.min(d, last)).padStart(2, '0')}`
}

/** Within the next 7 days or late: the date this order fulfilled ("Não repetir" takes only that one out). */
export function fulfilledBy(date: string | null | undefined, today: string): boolean {
  return !!date && date <= addDays(today, 7)
}
function addDays(day: string, days: number): string {
  const [y, m, d] = day.split('-').map(Number) as [number, number, number]
  return new Date(Date.UTC(y, m - 1, d + days)).toISOString().slice(0, 10)
}

/** Devices to ask about, or none (no question). */
export async function devicesToAsk(order: Order): Promise<{ id: string; name: string }[]> {
  if (!can('manageDevices') || declines() >= OFFER_LIMIT) return []
  const devices = order.devices.filter((device): device is typeof device & { id: string } => !!device.id)
  if (!devices.length) return []
  try {
    const [self, contracts] = await Promise.all([loadContractOrder(order.id), loadContracts()])
    if (self.isContract || self.contract) return []
    const covered = new Set(contracts.filter((c) => c.contract?.active).flatMap((c) => c.devices.map((d) => d.id)))
    return devices.filter((device) => !covered.has(device.id)).map((device) => ({ id: device.id, name: device.name ?? device.serial ?? '' }))
  } catch {
    // Without knowing the contracts, no question: never a date over a contract's.
    return []
  }
}

/** Saves the date on every device (one write each: a deleted one does not stop the others). */
export async function answer(deviceIds: string[], months: number | null, now = new Date()): Promise<number> {
  const today = toIsoDay(now)
  let failed = 0
  if (months === null) {
    // "Não repetir": only a date this order fulfilled leaves.
    const rows = (await loadDeviceDirectory(true)).rows
    for (const id of deviceIds) {
      if (!fulfilledBy(rows.find((row) => row.id === id)?.nextMaintenanceDate, today)) continue
      await setNextMaintenance(id, null).catch(() => failed++)
    }
    decline()
    return failed
  }
  for (const id of deviceIds) await setNextMaintenance(id, addMonths(today, months)).catch(() => failed++)
  resetDeclines()
  return failed
}
