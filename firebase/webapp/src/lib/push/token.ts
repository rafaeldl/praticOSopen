// This browser's FCM token on the account, in the same place and shape the app
// writes (lib/services/notification_service.dart, FcmToken): users/{uid}.fcmTokens,
// one entry per device, dates as ISO strings. platform 'web' makes the server
// send it the browser message (webpush), never the phones' one.
import { firebaseApp, firestoreLite } from '@/lib/firebase'
import { session } from '@/lib/session'
import { readStorage } from '@/lib/storage'
import { claimBrowser, DEVICE_KEY, releaseBrowser } from '.'

interface TokenEntry {
  token?: string
  deviceId?: string
  platform?: string
  createdAt?: string
  lastUsedAt?: string
}

/** The worker lives at /app/, so it never touches the site or another app's notifications. */
function worker(): Promise<ServiceWorkerRegistration> {
  const base = import.meta.env.BASE_URL
  return navigator.serviceWorker.register(`${base}firebase-messaging-sw.js`, { scope: base })
}

async function browserToken(device: string): Promise<string | null> {
  const registration = await worker()
  // The demo project of the emulators cannot reach FCM: the E2E build gets a token per device id.
  if (import.meta.env.VITE_USE_EMULATORS === '1') return `e2e-web-token-${device}`
  const [app, messaging] = await Promise.all([firebaseApp(), import('firebase/messaging')])
  if (!(await messaging.isSupported())) return null
  return messaging.getToken(messaging.getMessaging(app), {
    vapidKey: import.meta.env.VITE_FIREBASE_VAPID_KEY,
    serviceWorkerRegistration: registration,
  })
}

async function userDoc(uid: string) {
  const [db, fs] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  return { db, fs, ref: fs.doc(db, 'users', uid) }
}

const entries = (value: unknown): TokenEntry[] => (Array.isArray(value) ? (value as TokenEntry[]) : [])

export async function saveToken(): Promise<void> {
  const uid = session.uid
  if (!uid) return
  // Another account's token on this browser is deleted before this one is made (claimBrowser).
  const id = await claimBrowser(uid, dropFcmToken)
  const token = await browserToken(id)
  if (!token) return
  const { db, fs, ref } = await userDoc(uid)
  await fs.runTransaction(db, async (tx) => {
    const snapshot = await tx.get(ref)
    if (!snapshot.exists()) return
    const list = entries(snapshot.data().fcmTokens)
    const mine = list.find((entry) => entry?.deviceId === id)
    // Already there: no write at each start.
    if (mine?.token === token && mine.platform === 'web') return
    const now = new Date().toISOString()
    const others = list.filter((entry) => entry?.deviceId !== id && entry?.token !== token)
    tx.update(ref, { fcmTokens: [...others, { token, deviceId: id, platform: 'web', createdAt: mine?.createdAt ?? now, lastUsedAt: now }] })
  })
}

export async function removeToken(uid: string): Promise<void> {
  const id = readStorage(DEVICE_KEY)
  if (!id) return
  const { db, fs, ref } = await userDoc(uid)
  await fs.runTransaction(db, async (tx) => {
    const snapshot = await tx.get(ref)
    if (!snapshot.exists()) return
    const list = entries(snapshot.data().fcmTokens)
    const kept = list.filter((entry) => entry?.deviceId !== id)
    if (kept.length !== list.length) tx.update(ref, { fcmTokens: kept })
  })
  // The next person on this browser gets a new token, never this account's.
  try {
    await dropFcmToken()
    releaseBrowser()
  } catch (error) {
    console.warn('push: token not deleted', error)
  }
}

/**
 * Deletes this browser's FCM token: the next getToken makes a new one. Throws
 * when it could not, so a new account never reuses the old token.
 */
async function dropFcmToken(): Promise<void> {
  if (import.meta.env.VITE_USE_EMULATORS === '1' || Notification.permission !== 'granted') return
  const [app, messaging] = await Promise.all([firebaseApp(), import('firebase/messaging')])
  if (!(await messaging.isSupported())) return
  const client = messaging.getMessaging(app)
  // deleteToken needs the worker set on the client, or it looks for one at the site's root.
  await messaging.getToken(client, { vapidKey: import.meta.env.VITE_FIREBASE_VAPID_KEY, serviceWorkerRegistration: await worker() })
  await messaging.deleteToken(client)
}
