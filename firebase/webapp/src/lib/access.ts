// Route access, decided in one place. A route that declares nothing is denied.
import { hasAnyPermission, type Permission } from './permissions'

export type RouteAccess =
  | { kind: 'public' }
  /** Signed in, company or not: settings and the no-company screen. */
  | { kind: 'signedIn' }
  /** Signed in, even outside the access list: only the "not allowed yet" screen. */
  | { kind: 'outsideList' }
  /** Member of a company with at least one of these permissions. */
  | { kind: 'member'; anyOf: readonly Permission[] }

export interface AccessContext {
  signedIn: boolean
  companyId: string | null
  role: string | null
  useFinancial?: boolean | null
  /** Web app access list. Anything but 'allowed' keeps the app closed. */
  webAccess?: 'unknown' | 'allowed' | 'denied' | 'error'
  /** Several companies and none chosen in this browser yet. */
  needsCompanyChoice?: boolean
}

export type AccessDecision = 'allow' | 'login' | 'notAllowed' | 'chooseCompany' | 'noCompany' | 'forbidden'

export function decideAccess(access: RouteAccess | undefined, context: AccessContext): AccessDecision {
  if (!access) return 'forbidden'
  if (access.kind === 'public') return 'allow'
  if (!context.signedIn) return 'login'
  if (context.webAccess !== 'allowed') return access.kind === 'outsideList' ? 'allow' : 'notAllowed'
  if (access.kind === 'signedIn' || access.kind === 'outsideList') return 'allow'
  if (!context.companyId) return 'noCompany'
  if (context.needsCompanyChoice) return 'chooseCompany'
  return hasAnyPermission(context.role, access.anyOf, context.useFinancial) ? 'allow' : 'forbidden'
}
