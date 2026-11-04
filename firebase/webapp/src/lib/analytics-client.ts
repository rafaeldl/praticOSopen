// The Firebase Analytics client, downloaded only after consent and after the
// first screen (lib/analytics.ts). Never imported statically.
import {
  initializeAnalytics,
  isSupported,
  logEvent,
  setAnalyticsCollectionEnabled,
  setConsent,
  setDefaultEventParameters,
  setUserId,
  setUserProperties,
} from 'firebase/analytics'
import type { AnalyticsSink } from './analytics'
import { firebaseApp } from './firebase'

const pageLocation = (path: string) => `${location.origin}${import.meta.env.BASE_URL.replace(/\/$/, '')}${path}`

export async function loadFirebaseAnalytics(): Promise<AnalyticsSink> {
  if (!(await isSupported())) throw new Error('analytics not supported in this browser')
  // Asked for in the notice: statistics only. Ads, ad personalization and Google signals stay off.
  setConsent({ analytics_storage: 'granted', ad_storage: 'denied', ad_user_data: 'denied', ad_personalization: 'denied' })
  const app = await firebaseApp()
  const analytics = initializeAnalytics(app, {
    config: {
      // screen_view is logged by the router with the app's names; the address never carries ids or search.
      send_page_view: false,
      page_location: pageLocation('/'),
      allow_google_signals: false,
      allow_ad_personalization_signals: false,
    },
  })
  return {
    event: (name, params) => logEvent(analytics, name, params),
    identify: (user) => {
      setUserId(analytics, user?.userId ?? null)
      setUserProperties(analytics, {
        company_id: user?.companyId ?? null,
        segment: user?.segment ?? null,
        user_role: user?.userRole ?? null,
      })
      setDefaultEventParameters({ company_id: user?.companyId ?? undefined, segment: user?.segment ?? undefined })
    },
    page: (path) => setDefaultEventParameters({ page_location: pageLocation(path) }),
    stop: () => {
      setConsent({ analytics_storage: 'denied' })
      setAnalyticsCollectionEnabled(analytics, false)
    },
  }
}
