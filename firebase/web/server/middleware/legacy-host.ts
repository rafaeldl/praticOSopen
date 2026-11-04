import { legacyRedirect } from '../utils/legacy-host'

export default defineEventHandler((event) => {
  const target = legacyRedirect(event.method, getRequestHeader(event, 'x-forwarded-host'), event.path)
  if (!target) return
  // Never cache the redirect: the Hosting CDN could hand it to praticos.app
  // for the same path and loop.
  setResponseHeader(event, 'Cache-Control', 'no-store')
  return sendRedirect(event, target, 301)
})
