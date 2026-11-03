import { createApp } from 'vue'
import '../../hosting/src/css/tokens.css'
import './styles/fonts.css'
import './styles/app.css'
import './styles/foundation.css'
import App from './App.vue'
import { startI18n } from './i18n'
import { startPrefs } from './lib/prefs'
import { router } from './router'

startPrefs()
// Text first: nothing on screen can render without it.
void startI18n().then(() => {
  createApp(App).use(router).mount('#app')
})
