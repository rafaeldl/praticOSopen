// Route access, decided in one place. A route that declares nothing is denied.
import { hasAnyPermission, type Permission } from './permissions'

export type RouteAccess =
  | { kind: 'public' }
  /** Signed in, company or not: settings and the no-company screen. */
  | { kind: 'signedIn' }
  /** Member of a company with at least one of these permissions. */
  | { kind: 'member'; anyOf: readonly Permission[] }

export interface AccessContext {
  signedIn: boolean
  companyId: string | null
  role: string | null
  useFinancial?: boolean | null
}

export type AccessDecision = 'allow' | 'login' | 'noCompany' | 'forbidden'

export function decideAccess(access: RouteAccess | undefined, context: AccessContext): AccessDecision {
  if (!access) return 'forbidden'
  if (access.kind === 'public') return 'allow'
  if (!context.signedIn) return 'login'
  if (access.kind === 'signedIn') return 'allow'
  if (!context.companyId) return 'noCompany'
  return hasAnyPermission(context.role, access.anyOf, context.useFinancial) ? 'allow' : 'forbidden'
}
