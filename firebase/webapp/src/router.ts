import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router'
import { decideAccess, type RouteAccess } from '@/lib/access'
import { stripStaleLayers } from '@/lib/route-layer'
import { effectiveUseFinancial, session, startSession } from '@/lib/session'
import { NAV } from '@/navigation'
import { readPending } from '@/lib/onboarding/pending'
import { loadOrderTexts, loadTexts } from '@/i18n'
import type { MessageKey } from '@/generated/message-keys'

declare module 'vue-router' {
  interface RouteMeta {
    /** Required on every route. The guard denies a route without it. */
    access?: RouteAccess
    title?: MessageKey
    /** Screens without the navigation shell. */
    bare?: boolean
  }
}

const Placeholder = () => import('@/views/PlaceholderView.vue')
const OrdersView = () => import('@/views/OrdersView.vue')
// Customer screens come with their texts (and the order ones: they open orders and Nova OS).
const withCustomerTexts = <T>(view: () => Promise<T>) => () => Promise.all([view(), loadTexts('customers'), loadOrderTexts()]).then(([m]) => m)
const CustomersView = withCustomerTexts(() => import('@/views/customers/CustomersView.vue'))
const DevicesView = withCustomerTexts(() => import('@/views/customers/DevicesView.vue'))
const ImportView = withCustomerTexts(() => import('@/views/customers/ImportView.vue'))
// Financeiro (fatia 6): its texts in their own chunk; the screens open orders, so the orders' come too.
const withFinanceTexts = <T>(view: () => Promise<T>) => () => Promise.all([view(), loadTexts('finance'), loadOrderTexts()]).then(([m]) => m)
const FinanceView = withFinanceTexts(() => import('@/views/finance/FinanceView.vue'))
// Receber lives with the receive components (orders chunk) and shows the Financeiro's tabs.
const FinanceReceiveView = withFinanceTexts(() => import('@/components/orders/receive/FinanceReceive.vue'))
const ReportView = withFinanceTexts(() => import('@/views/finance/ReportView.vue'))
const InvoicesView = withFinanceTexts(() => import('@/views/finance/InvoicesView.vue'))
// Agenda opens orders beside it, so it brings their texts too.
const AgendaView = () => Promise.all([import('@/views/agenda/AgendaView.vue'), loadTexts('agenda'), loadOrderTexts()]).then(([m]) => m)
// The catalog's texts are in the same chunk as the customers' (scripts/gen.mjs FEATURES).
const CatalogView = withCustomerTexts(() => import('@/views/catalog/CatalogView.vue'))
const CatalogImportView = withCustomerTexts(() => import('@/views/catalog/CatalogImportView.vue'))
// Checklists: their texts are in the orders chunk (scripts/gen.mjs FEATURES).
const ChecklistsView = () => Promise.all([import('@/views/forms/ChecklistsView.vue'), loadOrderTexts()]).then(([m]) => m)
// Contracts open orders beside the list and Nova OS: their texts are in the orders chunk.
const ContractsView = () => Promise.all([import('@/views/contracts/ContractsView.vue'), loadOrderTexts()]).then(([m]) => m)
// Configurações and what opens from it (equipe, empresa, plano, conta, integrações): own texts chunk.
const withSettingsTexts = <T>(view: () => Promise<T>) => () => Promise.all([view(), loadTexts('settings')]).then(([m]) => m)
const SettingsView = withSettingsTexts(() => import('@/views/settings/SettingsView.vue'))
const TeamView = withSettingsTexts(() => import('@/views/settings/TeamView.vue'))
const ANY_MEMBER = { kind: 'member', anyOf: ['viewAllOrders', 'viewOwnOrders', 'viewAssignedOrders'] } as const
const SCREENS: Record<string, RouteRecordRaw['component']> = { home: OrdersView, schedule: AgendaView, customers: CustomersView, finance: FinanceView, invoices: InvoicesView, catalog: CatalogView, team: TeamView }

export const routes: RouteRecordRaw[] = [
  {
    path: '/login',
    name: 'login',
    component: () => import('@/views/LoginView.vue'),
    meta: { access: { kind: 'public' }, title: 'login', bare: true },
  },
  {
    path: '/not-allowed',
    name: 'notAllowed',
    component: () => import('@/views/NotAllowedView.vue'),
    meta: { access: { kind: 'outsideList' }, title: 'web.notAllowed.title', bare: true },
  },
  {
    path: '/choose-company',
    name: 'chooseCompany',
    component: () => import('@/views/ChooseCompanyView.vue'),
    meta: { access: { kind: 'signedIn' }, title: 'web.chooseCompany.title', bare: true },
  },
  {
    path: '/no-company',
    name: 'noCompany',
    component: () => import('@/views/NoCompanyView.vue'),
    meta: { access: { kind: 'signedIn' }, title: 'web.noCompany.title', bare: true },
  },
  // First access (docs/ONBOARDING.md): only reached from /no-company, without a company and without invites.
  {
    path: '/start',
    name: 'onboarding',
    component: () => Promise.all([import('@/views/onboarding/OnboardingView.vue'), loadTexts('onboarding')]).then(([m]) => m),
    meta: { access: { kind: 'signedIn' }, title: 'pickSegmentTitle', bare: true },
  },
  {
    path: '/forbidden',
    name: 'forbidden',
    component: () => import('@/views/ForbiddenView.vue'),
    meta: { access: { kind: 'signedIn' }, title: 'web.forbidden.title' },
  },
  ...NAV.map(
    (entry): RouteRecordRaw => ({
      path: entry.path,
      name: entry.name,
      component: SCREENS[entry.name] ?? Placeholder,
      meta: { access: entry.access, title: entry.label },
    }),
  ),
  // Same list under its own name: shared links and the performance test use it.
  { path: '/orders', name: 'orders', component: OrdersView, meta: { access: NAV[0]!.access, title: 'orders' } },
  {
    path: '/customers/import',
    name: 'customersImport',
    component: ImportView,
    meta: { access: { kind: 'member', anyOf: ['manageCustomers'] }, title: 'web.import.title' },
  },
  {
    path: '/catalog/import',
    name: 'catalogImport',
    component: CatalogImportView,
    meta: { access: { kind: 'member', anyOf: ['manageServices', 'manageProducts'] }, title: 'web.nav.catalog' },
  },
  // From Ajustes, as in the app, but only for who manages checklists (the app lets any role in: defect 27).
  {
    path: '/checklists',
    name: 'checklists',
    component: ChecklistsView,
    meta: { access: { kind: 'member', anyOf: ['manageForms'] }, title: 'checklistsTitle' },
  },
  // Avisos, from the bell on Início (home.notifications.open).
  {
    path: '/notifications',
    name: 'notifications',
    component: () => Promise.all([import('@/views/notifications/NotificationsView.vue'), loadOrderTexts()]).then(([m]) => m),
    meta: { access: NAV[0]!.access, title: 'noticesTitle' },
  },
  {
    path: '/finance/receive',
    name: 'financeReceive',
    component: FinanceReceiveView,
    meta: { access: { kind: 'member', anyOf: ['viewFinancialReports'] }, title: 'receiveTitle' },
  },
  {
    path: '/finance/report',
    name: 'financeReport',
    component: ReportView,
    meta: { access: { kind: 'member', anyOf: ['viewFinancialReports'] }, title: 'financialReport' },
  },
  // From Ajustes, as in the app (settings.open-contracts): any role that sees orders.
  {
    path: '/contracts',
    name: 'contracts',
    component: ContractsView,
    meta: { access: { kind: 'member', anyOf: ['viewOwnOrders', 'viewAllOrders', 'viewAssignedOrders'] }, title: 'contracts' },
  },
  {
    path: '/devices',
    name: 'devices',
    component: DevicesView,
    meta: { access: { kind: 'member', anyOf: ['viewDevices'] }, title: 'devices' },
  },
  {
    path: '/settings',
    name: 'settings',
    component: SettingsView,
    meta: { access: { kind: 'signedIn' }, title: 'settings' },
  },
  {
    path: '/settings/account',
    name: 'account',
    component: withSettingsTexts(() => import('@/views/settings/AccountView.vue')),
    meta: { access: { kind: 'signedIn' }, title: 'yourAccount' },
  },
  // Owner and admin, as the app (manageCompany).
  {
    path: '/settings/company',
    name: 'company',
    component: withSettingsTexts(() => import('@/views/settings/CompanyView.vue')),
    meta: { access: { kind: 'member', anyOf: ['manageCompany'] }, title: 'web.company.title' },
  },
  // Every role reads the plan; nothing is bought here.
  {
    path: '/settings/plan',
    name: 'plan',
    component: withSettingsTexts(() => import('@/views/settings/PlanView.vue')),
    meta: { access: ANY_MEMBER, title: 'planTitle' },
  },
  // Asaas and MCP connections: owner and admin, the same guard the API keeps.
  {
    path: '/settings/integrations',
    name: 'integrations',
    component: withSettingsTexts(() => import('@/views/settings/IntegrationsView.vue')),
    meta: { access: { kind: 'member', anyOf: ['manageUsers'] }, title: 'integrations' },
  },
  // Component gallery for tests and design review. Compiled out of production.
  ...(import.meta.env.VITE_USE_EMULATORS === '1'
    ? [
        {
          path: '/dev/components',
          name: 'gallery',
          component: () => import('@/views/GalleryView.vue'),
          // Uses the company's country, so it needs a chosen company.
          meta: { access: { kind: 'member', anyOf: ['viewOwnOrders', 'viewAllOrders', 'viewAssignedOrders'] }, title: 'web.gallery.title' },
        } satisfies RouteRecordRaw,
      ]
    : []),
  {
    path: '/:rest(.*)*',
    name: 'notFound',
    component: () => import('@/views/NotFoundView.vue'),
    meta: { access: { kind: 'signedIn' }, title: 'web.notFound.title' },
  },
]

export const router = createRouter({
  history: createWebHistory('/app/'),
  routes,
})

router.beforeEach(stripStaleLayers)

function currentDecision(access: RouteAccess | undefined) {
  return decideAccess(access, {
    signedIn: !!session.uid,
    companyId: session.companyId,
    role: session.role,
    useFinancial: effectiveUseFinancial(),
    webAccess: session.webAccess,
    needsCompanyChoice: session.needsCompanyChoice,
  })
}

/**
 * The screen on display after the session changed (company switch, role or
 * values option changed): a screen the new role cannot use goes to the start.
 */
export async function recheckCurrentRoute(): Promise<void> {
  const route = router.currentRoute.value
  if (route.matched.length === 0) return
  if (currentDecision(route.meta.access) !== 'allow') await router.replace('/')
}

// Every navigation passes here, direct URLs included. The server checks again.
router.beforeEach(async (to) => {
  await startSession()
  const decision = currentDecision(to.meta.access)
  if (decision === 'login') return { name: 'login', query: to.fullPath === '/' ? {} : { next: to.fullPath }, replace: true }
  if (decision === 'notAllowed') return { name: 'notAllowed', replace: true }
  if (decision === 'chooseCompany') return { name: 'chooseCompany', query: { next: to.fullPath }, replace: true }
  if (decision === 'noCompany') return { name: 'noCompany', replace: true }
  if (decision === 'forbidden') return { name: 'forbidden', query: { from: to.path }, replace: true }
  if (to.name === 'login' && session.uid) return { path: '/', replace: true }
  // A first access stopped after creating the company (reload): finish it before anything else.
  if (session.uid && to.name !== 'onboarding' && readPending(session.uid)) return { name: 'onboarding', replace: true }
  return true
})
