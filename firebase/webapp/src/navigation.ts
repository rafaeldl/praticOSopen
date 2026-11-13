// Navigation entries, in the app's tab order. Each one carries the same access
// as its route, so a person never sees a link that would be denied.
import { CalendarDays, FileText, House, Tags, UserCog, Users, Wallet, type LucideIcon } from '@lucide/vue'
import type { MessageKey } from '@/generated/message-keys'
import type { RouteAccess } from '@/lib/access'
import type { Permission } from '@/lib/permissions'

const ANY_ORDERS: readonly Permission[] = ['viewAllOrders', 'viewOwnOrders', 'viewAssignedOrders']

export interface NavEntry {
  name: string
  path: string
  label: MessageKey
  icon: LucideIcon
  access: RouteAccess & { kind: 'member' }
  /** Bottom tab on phones. The rest goes under "Mais". */
  tab?: boolean
  /** Shorter text for the tab. */
  tabLabel?: MessageKey
  /** Shown only with this company feature on (the route itself stays open: a link still works). */
  needs?: 'nfse'
}

export interface NavFeatures {
  nfse: boolean
}

export const NAV: NavEntry[] = [
  // Início is the order list, as in the app; /orders is the same screen (router.ts).
  { name: 'home', path: '/', label: 'home', icon: House, access: { kind: 'member', anyOf: ANY_ORDERS }, tab: true },
  { name: 'schedule', path: '/schedule', label: 'agenda', icon: CalendarDays, access: { kind: 'member', anyOf: ANY_ORDERS }, tab: true },
  { name: 'finance', path: '/finance', label: 'financial', icon: Wallet, access: { kind: 'member', anyOf: ['viewFinancialReports'] }, tab: true },
  { name: 'customers', path: '/customers', label: 'customers', icon: Users, access: { kind: 'member', anyOf: ['viewCustomers'] } },
  // Notas fiscais: who issues them (chargeOrder: owner, admin, manager), and only
  // with the nota on (NFS-e direct or Asaas): with it off the screen has nothing to list.
  { name: 'invoices', path: '/invoices', label: 'web.nav.invoices', icon: FileText, access: { kind: 'member', anyOf: ['chargeOrder'] }, needs: 'nfse' },
  { name: 'catalog', path: '/catalog', label: 'web.nav.catalog', icon: Tags, access: { kind: 'member', anyOf: ['viewProducts', 'viewServices'] } },
  { name: 'team', path: '/team', label: 'web.nav.team', icon: UserCog, access: { kind: 'member', anyOf: ['manageUsers'] } },
]

/** The entries this person sees: their permission, and the company feature when the entry needs one. */
export function visibleNav(allowed: (anyOf: readonly Permission[]) => boolean, features: NavFeatures): NavEntry[] {
  return NAV.filter((entry) => allowed(entry.access.anyOf) && (entry.needs !== 'nfse' || features.nfse))
}
