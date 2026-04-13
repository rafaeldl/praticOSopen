import { initializeApp, getApps } from 'firebase/app'
import { getAuth } from 'firebase/auth'

export default defineNuxtPlugin(() => {
  const config = useRuntimeConfig()

  const app = getApps().length === 0
    ? initializeApp(config.public.firebaseConfig as Record<string, string>)
    : getApps()[0]

  const auth = getAuth(app)

  return {
    provide: {
      firebaseAuth: auth,
    },
  }
})
