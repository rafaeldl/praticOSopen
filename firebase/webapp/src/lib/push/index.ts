// Browser notifications (Web Push through FCM), docs/WEB_APP.md "Avisos do
// navegador". The same notices the phones get (notification.service.ts): a
// quote approved, a comment, a payment. Nothing here loads Firebase Messaging:
// that comes with ./token, only once notifications are allowed.
import { reactive } from 'vue'
import { readStorage, writeStorage } from '@/lib/storage'

const ASKED = 'praticos.push.asked'
/** This browser's id in users/{uid}.fcmTokens (the app uses the phone's). */
export const DEVICE_KEY = 'praticos.push.device'
/** The account this browser's token was saved for. */
export const OWNER_KEY = 'praticos.push.owner'

/**
 * Shared computer: the token goes to `uid` only if it was never someone
 * else's. Another person signed in here (or the last one's session ended
 * without "Sair", so their token was never removed): the old token is dropped
 * first and this browser gets a new id, so B never gets A's notices.
 * Resolves with the device id to save the new token under.
 */
export async function claimBrowser(uid: string, dropToken: () => Promise<void>): Promise<string> {
  const owner = readStorage(OWNER_KEY)
  let device = readStorage(DEVICE_KEY)
  if (device && owner !== uid) {
    await dropToken()
    device = null
  }
  if (!device) {
    device = `web-${crypto.randomUUID()}`
    writeStorage(DEVICE_KEY, device)
  }
  writeStorage(OWNER_KEY, uid)
  return device
}

/** Signed out with the token removed: nobody owns this browser's (deleted) token any more. */
export function releaseBrowser(): void {
  writeStorage(OWNER_KEY, '')
  writeStorage(DEVICE_KEY, '')
}

type PushEnv = Pick<ImportMetaEnv, 'VITE_FIREBASE_VAPID_KEY' | 'VITE_FIREBASE_MESSAGING_SENDER_ID' | 'VITE_FIREBASE_APP_ID'>

/** The key pair and the web app registered in the Firebase console. Missing: no notifications, nothing shown. */
export function pushConfigured(env: PushEnv = import.meta.env): boolean {
  return !!(env.VITE_FIREBASE_VAPID_KEY && env.VITE_FIREBASE_MESSAGING_SENDER_ID && env.VITE_FIREBASE_APP_ID)
}

export function pushSupported(): boolean {
  return (
    pushConfigured() &&
    typeof window !== 'undefined' &&
    window.isSecureContext &&
    'Notification' in window &&
    'serviceWorker' in navigator &&
    'PushManager' in window
  )
}

/** The explanation before the browser's own question (AppShell shows it). */
export const pushOffer = reactive({ open: false })

/**
 * After saving an order, or a visit on a saved one (order.offer.notifications,
 * askNotificationsOnce in lib/screens/order/new_order_offers.dart): once per
 * browser, while it has not answered. Never on the entry screen.
 */
export function askNotificationsOnce(): void {
  if (!pushSupported() || Notification.permission !== 'default' || readStorage(ASKED)) return
  pushOffer.open = true
}

export function declineOffer(): void {
  writeStorage(ASKED, '1')
  pushOffer.open = false
}

/** "Continuar": the browser asks (inside the click, as browsers require), then this browser joins the account. */
export async function acceptOffer(): Promise<NotificationPermission> {
  declineOffer()
  const answer = await Notification.requestPermission()
  if (answer === 'granted') await registerThisBrowser()
  return answer
}

export async function registerThisBrowser(): Promise<void> {
  const { saveToken } = await import('./token')
  await saveToken()
}

/** Signed in with notifications already allowed: keep this browser on the account, as the app does at each start. */
export function syncThisBrowser(): void {
  if (!pushSupported() || Notification.permission !== 'granted') return
  registerThisBrowser().catch((error) => console.warn('push: not registered', error))
}

/** Signing out: this browser stops getting the account's notifications. */
export async function forgetThisBrowser(uid: string): Promise<void> {
  if (!readStorage(DEVICE_KEY)) return
  const { removeToken } = await import('./token')
  await removeToken(uid)
}

export interface ForegroundNotice {
  title: string
  body: string
  data: Record<string, string>
}

/**
 * Messages from the service worker (public/firebase-messaging-sw.js): a
 * notification clicked while a tab was open, and one that arrived while the
 * page was on screen (shown inside the page, not by the system).
 */
export function listenToWorker(handlers: { open: (link: string) => void; notice: (notice: ForegroundNotice) => void }): () => void {
  if (!pushSupported()) return () => {}
  const listener = (event: MessageEvent) => {
    const message = event.data as { type?: string; link?: string } & Partial<ForegroundNotice>
    if (message?.type === 'praticos:notice-open' && typeof message.link === 'string') handlers.open(message.link)
    if (message?.type === 'praticos:notice') handlers.notice({ title: message.title ?? '', body: message.body ?? '', data: message.data ?? {} })
  }
  navigator.serviceWorker.addEventListener('message', listener)
  return () => navigator.serviceWorker.removeEventListener('message', listener)
}
