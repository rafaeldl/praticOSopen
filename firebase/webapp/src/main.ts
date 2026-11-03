import { createApp } from 'vue'
import '../../hosting/src/css/tokens.css'
import './styles/fonts.css'
import './styles/app.css'
import './styles/foundation.css'
import App from './App.vue'
import { startI18n } from './i18n'
import { firestoreClient } from './lib/firebase'
import { firstOrdersPage } from './lib/orders-query'
import { roleHasPermission } from './lib/permissions'
import { startPrefs } from './lib/prefs'
import { onSessionHint, startSession } from './lib/session'
import { router } from './router'

startPrefs()
// Opening on the list: its query leaves with the session documents, not after them.
// The screen applies the company's own rules again when it renders.
onSessionHint(({ uid, companyId, role }) => {
  if (!/^\/app\/orders\/?$/.test(location.pathname) || !roleHasPermission(role, 'viewPrices')) return
  void firstOrdersPage({ companyId, createdBy: roleHasPermission(role, 'viewAllOrders') ? null : uid }).catch(() => {})
})
// Network work starts now, side by side, so it does not wait for the screen.
// Firestore only for who already has a session: the login screen does not need it.
void startSession()
if (hasSavedSession()) void firestoreClient()
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
