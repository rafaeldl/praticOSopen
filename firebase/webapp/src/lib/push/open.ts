// Where a browser notification goes (auth.gate.notification-open). The server
// links to /app/?order={id}&company={id} (notification.service.ts webPushLink).
import type { LocationQuery } from 'vue-router'

const BASE = '/app'

/**
 * The query of a notification's link once the session is known: the order of
 * the company in use opens; an order of another company is ignored, as the
 * app's NotificationTapHandler does (the order is read from the current company).
 * Null when the address did not come from a notification.
 */
export function noticeRedirect(query: LocationQuery, companyId: string | null): LocationQuery | null {
  if (typeof query.company !== 'string') return null
  const { company, ...rest } = query
  if (company === companyId) return rest
  const { order: _order, ...withoutOrder } = rest
  return withoutOrder
}

/** The route inside /app of a notification's link (absolute or not); anything outside /app is the start. */
export function linkToPath(link: string): string {
  let url: URL
  try {
    url = new URL(link, 'https://praticos.app')
  } catch {
    return '/'
  }
  if (url.pathname !== BASE && !url.pathname.startsWith(`${BASE}/`)) return '/'
  return (url.pathname.slice(BASE.length) || '/') + url.search
}
