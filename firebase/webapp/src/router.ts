import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router'
import { decideAccess, type RouteAccess } from '@/lib/access'
import { stripStaleLayers } from '@/lib/route-layer'
import { effectiveUseFinancial, session, startSession } from '@/lib/session'
import { NAV } from '@/navigation'
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
      component: entry.name === 'orders' ? () => import('@/views/OrdersView.vue') : Placeholder,
      meta: { access: entry.access, title: entry.label },
    }),
  ),
  {
    path: '/settings',
    name: 'settings',
    component: () => import('@/views/SettingsView.vue'),
    meta: { access: { kind: 'signedIn' }, title: 'settings' },
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
  return true
})
