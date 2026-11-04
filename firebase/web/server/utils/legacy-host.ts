// praticos.app is the only domain. praticos.web.app and praticos.firebaseapp.com
// are the same Firebase Hosting site, so firebase.json cannot redirect per host
// (it would loop on praticos.app). The pages this server renders answer 301
// themselves, keeping path and query: every /q/{token} link already sent on
// WhatsApp, printed on a PDF or still made by an old app keeps opening.
export const MAIN_ORIGIN = 'https://praticos.app'

const LEGACY_HOSTS = new Set(['praticos.web.app', 'praticos.firebaseapp.com'])

// Pages only: the APIs (/api/**) and assets (/_nuxt/**) answer on any host.
const PAGE_PATH = /^\/(q|pro|admin)(\/|$)/

// Firebase Hosting calls Cloud Run with its own Host and the visitor's domain
// in X-Forwarded-Host (a comma list when there is more than one proxy).
export function legacyRedirect(
  method: string,
  forwardedHost: string | undefined,
  url: string,
): string | null {
  if (method !== 'GET' && method !== 'HEAD') return null
  const host = (forwardedHost ?? '').split(',')[0].trim().toLowerCase().replace(/:\d+$/, '')
  if (!LEGACY_HOSTS.has(host)) return null
  if (!PAGE_PATH.test(url)) return null
  return MAIN_ORIGIN + url
}
