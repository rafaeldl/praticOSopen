import { createApp } from 'vue'
import '../../hosting/src/css/tokens.css'
import './styles/fonts.css'
import './styles/app.css'
import './styles/foundation.css'
import './styles/orders.css'
import App from './App.vue'
import { startI18n } from './i18n'
import { firestoreLite } from './lib/firebase'
import { firstOrdersPage } from './lib/orders-query'
import { roleHasPermission } from './lib/permissions'
import { startPrefs } from './lib/prefs'
import { onSessionHint, startSession } from './lib/session'
import { router } from './router'
import { watchForStaleBuild } from './lib/stale-build'

startPrefs()
// A tab from before a deploy: reload once to get the new chunks.
watchForStaleBuild((handler) => router.onError(handler))
// Opening on the list: its query leaves with the session documents, not after them.
// The screen applies the company's own rules again when it renders.
onSessionHint(({ uid, companyId, role }) => {
  if (!/^\/app\/(orders\/?)?$/.test(location.pathname) || !roleHasPermission(role, 'viewPrices')) return
  const params = new URLSearchParams(location.search)
  if (params.get('view') === 'board') return
  // Same statuses as queryStatuses (lib/orders/model.ts); who sees values never starts on "Minhas".
  const filter = params.get('f')
  void firstOrdersPage({
    companyId,
    createdBy: roleHasPermission(role, 'viewAllOrders') ? null : uid,
    statuses: filter === 'done' || filter === 'unpaid' ? ['done'] : filter === 'all' ? null : ['quote', 'approved', 'progress'],
  }).catch(() => {})
})
// Network work starts now, side by side, so it does not wait for the screen.
// Firestore only for who already has a session: the login screen does not need it.
void startSession()
if (hasSavedSession()) void firestoreLite()
// Text first: nothing on screen can render without it.
void startI18n().then(() => {
  createApp(App).use(router).mount('#app')
})

function hasSavedSession(): boolean {
  try {
    return Object.keys(localStorage).some((key) => key.startsWith('firebase:authUser:'))
  } catch {
    return false
  }
}
