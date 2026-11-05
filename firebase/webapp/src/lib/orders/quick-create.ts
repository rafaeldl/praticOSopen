// Quick register from inside the order (docs/QUICK_REGISTER.md): "+ Cadastrar «X»"
// opens a small block with the one or two fields companies really fill (phone;
// model + plate/serial; kind + price) instead of saving the name alone.
import { isBrazilianPlate } from '@/lib/customers/model'
import { api, can } from '@/lib/session'
import { forgetLists, type CatalogItem, type Customer, type Device } from './catalog'

/** What was typed goes to the field it looks like: only digits (6+) is the phone, else the name (customer.picker.create). */
export function customerDraft(text: string): { name: string; phone: string } {
  const typed = text.trim()
  const digits = /^[\d\s()+-]+$/.test(typed) && /\d{6}/.test(typed.replace(/\D/g, ''))
  return digits ? { name: '', phone: typed } : { name: typed, phone: '' }
}

/** A Brazilian plate goes to the serial in capitals, anything else to the model (device.list.pick-create). */
export function deviceDraft(text: string): { name: string; serial: string } {
  const typed = text.trim()
  return isBrazilianPlate(typed) ? { name: '', serial: typed.toUpperCase() } : { name: typed, serial: '' }
}

/** The kinds this person may register, services first (the app's order). */
export function registerKinds(): CatalogItem['kind'][] {
  return (['service', 'product'] as const).filter((kind) => can(kind === 'service' ? 'manageServices' : 'manageProducts'))
}

export async function createCustomer(input: { name: string; phone: string }): Promise<Customer> {
  const name = input.name.trim()
  const phone = input.phone.trim()
  const created = await api<{ id: string; name: string }>('/v1/app/customers', { method: 'POST', body: { name, ...(phone ? { phone } : {}) } })
  forgetLists()
  return { id: created.id, name: created.name || name, ...(phone ? { phone } : {}) }
}

export async function createDevice(input: { name: string; serial: string }): Promise<Device> {
  const name = input.name.trim()
  const serial = input.serial.trim().toUpperCase()
  const created = await api<{ id: string; name: string | null; serial?: string | null }>('/v1/app/devices', {
    method: 'POST',
    body: { ...(name ? { name } : {}), ...(serial ? { serial } : {}) },
  })
  forgetLists()
  const saved = created.serial ?? (serial || null)
  return { id: created.id, name: created.name || name || saved || '', ...(saved ? { serial: saved } : {}) }
}

/** The price only for who may edit prices; without it the item stays without price, as before. */
export async function createItem(input: { name: string; kind: CatalogItem['kind']; value: number | null }): Promise<CatalogItem> {
  const name = input.name.trim()
  const value = can('editPrices') ? input.value : null
  const created = await api<{ id: string }>(input.kind === 'service' ? '/v1/app/services' : '/v1/app/products', {
    method: 'POST',
    body: { name, ...(value !== null ? { value } : {}) },
  })
  forgetLists()
  return { id: created.id, kind: input.kind, name, value }
}

export type Missing = { kind: 'phone' } | { kind: 'serial' | 'model'; deviceId: string }

/**
 * What the order's customer and devices still lack that is worth asking (order.quick.complete):
 * the customer's phone (WhatsApp) and each device's plate/serial or model. Never e-mail or CPF.
 */
export function missingOnOrder(
  order: { customer?: { id?: string; phone?: string | null } | null; devices: { id?: string; name?: string | null; serial?: string | null }[] },
  allowed: { customers: boolean; devices: boolean },
): Missing[] {
  const list: Missing[] = []
  if (allowed.customers && order.customer?.id && !order.customer.phone?.trim()) list.push({ kind: 'phone' })
  if (allowed.devices) {
    for (const device of order.devices) {
      if (!device.id) continue
      if (!device.serial?.trim()) list.push({ kind: 'serial', deviceId: device.id })
      else if (!device.name?.trim() || device.name.trim() === device.serial.trim()) list.push({ kind: 'model', deviceId: device.id })
    }
  }
  return list
}

/** The order's copy of the customer after an edit (id, name, phone, e-mail, CPF/CNPJ; empty ones left out). */
export function customerSummary(customer: { id: string; name: string; phone?: string | null; email?: string | null; taxId?: string | null }): Record<string, string> {
  const summary = { id: customer.id, name: customer.name, phone: customer.phone, email: customer.email, taxId: customer.taxId }
  return Object.fromEntries(Object.entries(summary).filter(([, value]) => typeof value === 'string' && value !== '')) as Record<string, string>
}
