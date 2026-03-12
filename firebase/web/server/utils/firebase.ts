import { initializeApp, getApps, cert, type App } from 'firebase-admin/app'
import { getFirestore, type Firestore } from 'firebase-admin/firestore'

let app: App
let db: Firestore

export function getAdminDb(): Firestore {
  if (!db) {
    if (getApps().length === 0) {
      // Cloud Run provides Application Default Credentials automatically
      // For local dev, set GOOGLE_APPLICATION_CREDENTIALS env var
      const serviceAccount = process.env.GOOGLE_APPLICATION_CREDENTIALS
      app = serviceAccount
        ? initializeApp({ credential: cert(serviceAccount) })
        : initializeApp()
    } else {
      app = getApps()[0]
    }
    db = getFirestore(app)
  }
  return db
}
