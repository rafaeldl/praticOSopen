// ⌘K from any screen (web.search.global): orders by number, customers, devices,
// the catalog and the screens, each only for who may open it (canOpen, the same
// guard as the routes). The data comes from the API, already cut by role on the
// server; prices only arrive for who sees them. Loaded with the palette.
import { ClipboardList, FileText, Hash, Settings, Tags, Upload, User, UserPlus, Wallet, Wrench, type LucideIcon } from '@lucide/vue'
import { t, type MessageKey } from '@/i18n'
import { loadCatalogList } from '@/lib/catalog/data'
import { itemMatches, visibleKinds, type CatalogItem, type CatalogKind } from '@/lib/catalog/model'
import type { Command } from '@/lib/commands'
import { loadCustomerDirectory, loadDeviceDirectory } from '@/lib/customers/data'
import { customerMatches, deviceMatches, type CustomerRow, type DeviceRow } from '@/lib/customers/model'
import { formatMoney } from '@/lib/format'
import { formatPhone } from '@/lib/phone'
import { createListLoader, listContext } from '@/lib/orders/data'
import { deviceSummary, type Order } from '@/lib/orders/model'
import { orderShort, statusText } from '@/lib/orders/text'
import { resolveLabel, segmentLabels } from '@/lib/segments'
import { can, session } from '@/lib/session'
import { canOpen, router } from '@/router'
import { NAV } from '@/navigation'

export { GROUPS, groupOf, type Group } from './palette-order'
import type { Group } from './palette-order'
const PER_GROUP = 6
const tr = (key: MessageKey) => t(key)

export function groupLabel(group: Group): string {
  switch (group) {
    case 'orders':
      return t('web.nav.ordersShort')
    case 'customers':
      return resolveLabel('customer._entity_plural', segmentLabels(), tr)
    case 'devices':
      return resolveLabel('device._entity_plural', segmentLabels(), tr)
    case 'catalog':
      return t('web.nav.catalog')
    case 'create':
      return t('web.palette.create')
    default:
      return t('web.palette.actions')
  }
}

/** Screens with the order panel beside them keep the person where they are. */
const PANEL_SCREENS = ['/', '/orders', '/schedule', '/finance', '/finance/report']
export function openOrderAnywhere(id: string): void {
  const current = router.currentRoute.value
  const path = PANEL_SCREENS.includes(current.path) ? current.path : '/'
  void router.push({ path, query: { ...(path === current.path ? current.query : {}), order: id } })
}

interface Screen {
  path: string
  label: MessageKey
  icon: LucideIcon
}

/** Screens outside the menu that people look for by name. */
const EXTRA_SCREENS: Screen[] = [
  { path: '/finance/receive', label: 'web.palette.goReceive', icon: Wallet },
  { path: '/finance/report', label: 'web.palette.goReport', icon: FileText },
  { path: '/devices', label: 'web.palette.goDevices', icon: Wrench },
  { path: '/checklists', label: 'web.palette.goChecklists', icon: ClipboardList },
  { path: '/customers/import', label: 'web.palette.importCustomers', icon: Upload },
  { path: '/catalog/import', label: 'web.palette.importCatalog', icon: Upload },
  { path: '/settings', label: 'settings', icon: Settings },
]

/** "Ir para …": every screen this person may open. */
export function screenCommands(): Command[] {
  const nav = NAV.map((entry) => ({ path: entry.path, text: t('web.palette.goTo', { screen: t(entry.label) }), icon: entry.icon }))
  const extra = EXTRA_SCREENS.map((screen) => ({
    path: screen.path,
    text: screen.path === '/devices' ? t('web.palette.goTo', { screen: groupLabel('devices') }) : t(screen.label),
    icon: screen.icon,
  }))
  return [...nav, ...extra]
    .filter((screen) => canOpen(screen.path))
    .map((screen) => ({ id: `go:${screen.path}`, label: 'search' as const, text: screen.text, icon: screen.icon, run: () => void router.push(screen.path) }))
}

export interface Directory {
  customers: CustomerRow[]
  devices: DeviceRow[]
  catalog: { kind: CatalogKind; item: CatalogItem; prices: boolean }[]
}

/** Lists this person may search, read once when the palette opens (failures leave a group empty). */
export async function loadDirectory(): Promise<Directory> {
  const kinds = canOpen('/catalog') ? visibleKinds((p) => can(p)) : []
  const [customers, devices, ...lists] = await Promise.all([
    canOpen('/customers') ? loadCustomerDirectory().then((d) => d.rows).catch(() => []) : Promise.resolve([]),
    canOpen('/devices') ? loadDeviceDirectory().then((d) => d.rows).catch(() => []) : Promise.resolve([]),
    ...kinds.map((kind) => loadCatalogList(kind).then((list) => list.items.map((item) => ({ kind, item, prices: list.prices }))).catch(() => [])),
  ])
  return { customers: customers as CustomerRow[], devices: devices as DeviceRow[], catalog: lists.flat() }
}

const country = () => session.company?.country

export function directoryResults(directory: Directory, query: string): Command[] {
  const text = query.trim()
  if (!text) return []
  const customers = directory.customers
    .filter((row) => customerMatches(row, text))
    .slice(0, PER_GROUP)
    .map((row) => ({
      id: `customer:${row.id}`,
      label: 'customer' as const,
      text: row.name,
      sub: formatPhone(row.phone, country()) || undefined,
      icon: User,
      run: () => void router.push({ path: '/customers', query: { customer: row.id } }),
    }))
  const devices = directory.devices
    .filter((row) => deviceMatches(row, text))
    .slice(0, PER_GROUP)
    .map((row) => ({
      id: `device:${row.id}`,
      label: 'device' as const,
      text: [row.serial, row.name].filter(Boolean).join(' · '),
      sub: row.manufacturer ?? undefined,
      icon: Wrench,
      run: () => void router.push({ path: '/devices', query: { device: row.id } }),
    }))
  const catalog = directory.catalog
    .filter(({ item }) => itemMatches(item, text))
    .slice(0, PER_GROUP)
    .map(({ kind, item, prices }) => ({
      id: `catalog:${kind}:${item.id}`,
      label: 'search' as const,
      text: item.name,
      sub: [prices && typeof item.value === 'number' ? formatMoney(item.value, country()) : null, kind === 'service' ? t('service') : resolveLabel('product._entity', segmentLabels(), tr, t('product'))]
        .filter(Boolean)
        .join(' · '),
      icon: Tags,
      run: () => void router.push({ path: '/catalog', query: { kind, q: item.name } }),
    }))
  return [...customers, ...devices, ...catalog]
}

/** An order by its number, from anywhere: the list's own reads (Firestore or the API, by role). */
export async function ordersByNumber(query: string): Promise<Command[]> {
  const text = query.trim().replace(/^#/, '')
  if (!/^\d{1,9}$/.test(text)) return []
  const found: Order[] = await createListLoader(listContext(), null).byNumber(Number(text))
  return found.slice(0, PER_GROUP).map((order) => ({
    id: `order:${order.id}`,
    label: 'order' as const,
    text: `${orderShort()} ${order.number ?? ''} · ${order.customer?.name ?? ''}`,
    sub: deviceSummary(order) || statusText(order.status),
    icon: Hash,
    run: () => openOrderAnywhere(order.id),
  }))
}


/**
 * "Cadastrar cliente «…»": what was typed becomes a new customer (name, or the
 * phone when only digits), for who registers customers. A number alone stays a
 * search for an order, and an exact name already there is not offered again.
 */
export function createResults(directory: Directory, query: string): Command[] {
  const text = query.trim()
  if (!text || /^#?\d{1,9}$/.test(text) || !canOpen('/customers') || !can('manageCustomers')) return []
  const same = (name: string) => name.localeCompare(text, undefined, { sensitivity: 'base' }) === 0
  if (directory.customers.some((row) => same(row.name))) return []
  return [
    {
      id: 'create:customer',
      label: 'search' as const,
      text: t('web.palette.createCustomer', { name: text }),
      icon: UserPlus,
      run: () => void router.push({ path: '/customers', query: { new: text } }),
    },
  ]
}
