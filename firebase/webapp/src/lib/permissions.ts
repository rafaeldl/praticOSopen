// Same reading as the server (app-permission.middleware.ts) and the app.
// The server checks again: this only decides what to show.
import { FINANCIAL_PERMISSIONS, ROLE_PERMISSIONS, type AppRole, type Permission } from '@/generated/permissions'

export type { AppRole, Permission }

/** 'owner' is read as admin. Unknown roles get nothing. */
export function appRoleOf(role: string | null | undefined): AppRole | null {
  if (role === 'owner') return 'admin'
  return role && role in ROLE_PERMISSIONS ? (role as AppRole) : null
}

/** `useFinancial` absent means on, like the server. */
export function roleHasPermission(
  role: string | null | undefined,
  permission: Permission,
  useFinancial?: boolean | null,
): boolean {
  if (useFinancial === false && (FINANCIAL_PERMISSIONS as readonly string[]).includes(permission)) return false
  const appRole = appRoleOf(role)
  return !!appRole && (ROLE_PERMISSIONS[appRole] as readonly string[]).includes(permission)
}

export function hasAnyPermission(
  role: string | null | undefined,
  permissions: readonly Permission[],
  useFinancial?: boolean | null,
): boolean {
  return permissions.some((permission) => roleHasPermission(role, permission, useFinancial))
}
