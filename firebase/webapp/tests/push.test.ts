// Browser notifications (auth.gate.notification-open, order.offer.notifications):
// when the browser is asked, where a click goes, and what the service worker does.
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { askNotificationsOnce, claimBrowser, declineOffer, DEVICE_KEY, OWNER_KEY, pushConfigured, pushOffer, releaseBrowser } from '@/lib/push'
import { linkToPath, noticeRedirect } from '@/lib/push/open'
import { dropLegacyWorker } from '@/lib/push/token'

describe('pushConfigured', () => {
  const full = { VITE_FIREBASE_VAPID_KEY: 'v', VITE_FIREBASE_MESSAGING_SENDER_ID: 's', VITE_FIREBASE_APP_ID: 'a' }
  it('needs the key pair, the sender and the web app id', () => {
    expect(pushConfigured(full)).toBe(true)
    expect(pushConfigured({ ...full, VITE_FIREBASE_VAPID_KEY: '' })).toBe(false)
    expect(pushConfigured({ ...full, VITE_FIREBASE_MESSAGING_SENDER_ID: undefined })).toBe(false)
    expect(pushConfigured({ ...full, VITE_FIREBASE_APP_ID: undefined })).toBe(false)
  })
})

describe('askNotificationsOnce', () => {
  beforeEach(() => {
    localStorage.clear()
    pushOffer.open = false
    vi.stubEnv('VITE_FIREBASE_VAPID_KEY', 'v')
    vi.stubEnv('VITE_FIREBASE_MESSAGING_SENDER_ID', 's')
    vi.stubEnv('VITE_FIREBASE_APP_ID', 'a')
    vi.stubGlobal('Notification', { permission: 'default', requestPermission: vi.fn() })
    vi.stubGlobal('PushManager', function PushManager() {})
    Object.defineProperty(navigator, 'serviceWorker', { value: {}, configurable: true })
    Object.defineProperty(window, 'isSecureContext', { value: true, configurable: true })
  })
  afterEach(() => {
    vi.unstubAllEnvs()
    vi.unstubAllGlobals()
  })

  it('explains once, while the browser has not been answered', () => {
    askNotificationsOnce()
    expect(pushOffer.open).toBe(true)
    declineOffer()
    expect(pushOffer.open).toBe(false)
    askNotificationsOnce()
    expect(pushOffer.open).toBe(false)
  })

  it('says nothing when the browser already answered', () => {
    vi.stubGlobal('Notification', { permission: 'denied', requestPermission: vi.fn() })
    askNotificationsOnce()
    expect(pushOffer.open).toBe(false)
    vi.stubGlobal('Notification', { permission: 'granted', requestPermission: vi.fn() })
    askNotificationsOnce()
    expect(pushOffer.open).toBe(false)
  })

  it('says nothing when the key pair is not configured', () => {
    vi.stubEnv('VITE_FIREBASE_VAPID_KEY', '')
    askNotificationsOnce()
    expect(pushOffer.open).toBe(false)
  })
})

describe('claimBrowser (computador compartilhado)', () => {
  beforeEach(() => localStorage.clear())

  it('first time: a new id for this browser, owned by who signed in, nothing dropped', async () => {
    const drop = vi.fn(() => Promise.resolve())
    const id = await claimBrowser('a', drop)
    expect(id).toMatch(/^web-/)
    expect(localStorage.getItem(OWNER_KEY)).toBe('a')
    expect(drop).not.toHaveBeenCalled()
    // Same person again: same id, nothing dropped.
    expect(await claimBrowser('a', drop)).toBe(id)
    expect(drop).not.toHaveBeenCalled()
  })

  it("another person here (A never signed out): A's token is deleted and B gets a new id", async () => {
    const drop = vi.fn(() => Promise.resolve())
    const first = await claimBrowser('a', drop)
    const second = await claimBrowser('b', drop)
    expect(drop).toHaveBeenCalledTimes(1)
    expect(second).not.toBe(first)
    expect(localStorage.getItem(OWNER_KEY)).toBe('b')
  })

  it('a token from before the owner was kept counts as someone else’s', async () => {
    localStorage.setItem(DEVICE_KEY, 'web-old')
    const drop = vi.fn(() => Promise.resolve())
    expect(await claimBrowser('a', drop)).not.toBe('web-old')
    expect(drop).toHaveBeenCalledTimes(1)
  })

  it('when the old token cannot be deleted, B gets nothing (and A keeps the browser)', async () => {
    await claimBrowser('a', () => Promise.resolve())
    await expect(claimBrowser('b', () => Promise.reject(new Error('offline')))).rejects.toThrow('offline')
    expect(localStorage.getItem(OWNER_KEY)).toBe('a')
  })

  it('after signing out with the token deleted, the next person starts clean', async () => {
    const drop = vi.fn(() => Promise.resolve())
    await claimBrowser('a', drop)
    releaseBrowser()
    await claimBrowser('b', drop)
    expect(drop).not.toHaveBeenCalled()
  })
})

describe('noticeRedirect', () => {
  it('opens the order of the company in use, without the company in the address', () => {
    expect(noticeRedirect({ order: 'o1', company: 'c1' }, 'c1')).toEqual({ order: 'o1' })
  })
  it('ignores an order of another company, like the app', () => {
    expect(noticeRedirect({ order: 'o1', company: 'c2' }, 'c1')).toEqual({})
  })
  it('leaves other addresses alone', () => {
    expect(noticeRedirect({ order: 'o1' }, 'c1')).toBeNull()
  })
})

describe('dropLegacyWorker (web app moved from /app to /web)', () => {
  function withRegistration(scope: string | null) {
    const unregister = vi.fn(async () => true)
    const getRegistration = vi.fn(async () => (scope ? { scope, unregister } : undefined))
    Object.defineProperty(navigator, 'serviceWorker', { value: { getRegistration }, configurable: true })
    return { unregister, getRegistration }
  }

  it('unregisters the old worker at /app/', async () => {
    const { unregister, getRegistration } = withRegistration('https://praticos.app/app/')
    await dropLegacyWorker()
    expect(getRegistration).toHaveBeenCalledWith('/app/')
    expect(unregister).toHaveBeenCalled()
  })

  it('leaves any other worker alone (the browser answers with the closest scope)', async () => {
    const { unregister } = withRegistration('https://praticos.app/')
    await dropLegacyWorker()
    expect(unregister).not.toHaveBeenCalled()
  })

  it('does nothing without one', async () => {
    withRegistration(null)
    await expect(dropLegacyWorker()).resolves.toBeUndefined()
  })
})

describe('linkToPath', () => {
  it('turns the link of the notification into a route of /web', () => {
    expect(linkToPath('https://praticos.app/web/?order=o1&company=c1')).toBe('/?order=o1&company=c1')
    expect(linkToPath('/web/')).toBe('/')
    expect(linkToPath('https://praticos.app/web/notifications')).toBe('/notifications')
    expect(linkToPath('https://evil.example/elsewhere')).toBe('/')
  })
})

/** Runs public/firebase-messaging-sw.js against a fake worker scope. */
function loadWorker(windows: { url: string; visibilityState: string; focus?: () => Promise<void>; postMessage?: (m: unknown) => void }[]) {
  const listeners: Record<string, (event: unknown) => void> = {}
  const shown: { title: string; options: { body?: string; data?: { link?: string } } }[] = []
  const opened: string[] = []
  const scope = {
    location: new URL('https://praticos.app/web/firebase-messaging-sw.js'),
    addEventListener: (type: string, listener: (event: unknown) => void) => (listeners[type] = listener),
    skipWaiting: () => Promise.resolve(),
    registration: { showNotification: (title: string, options: { body?: string; data?: { link?: string } }) => (shown.push({ title, options }), Promise.resolve()) },
    clients: {
      matchAll: () => Promise.resolve(windows),
      openWindow: (url: string) => (opened.push(url), Promise.resolve(null)),
      claim: () => Promise.resolve(),
    },
  }
  const code = readFileSync(resolve(import.meta.dirname, '../public/firebase-messaging-sw.js'), 'utf8')
  new Function('self', code)(scope)
  async function fire(type: string, event: Record<string, unknown>) {
    let pending: Promise<unknown> = Promise.resolve()
    listeners[type]!({ ...event, waitUntil: (promise: Promise<unknown>) => (pending = promise) })
    await pending
  }
  return { fire, shown, opened }
}

const PUSH = {
  notification: { title: 'Orçamento Aprovado! ✅', body: 'Ana aprovou o orçamento da OS #42' },
  data: { type: 'order_approved', orderId: 'o1', companyId: 'c1' },
  fcmOptions: { link: 'https://praticos.app/web/?order=o1&company=c1' },
}

describe('firebase-messaging-sw.js', () => {
  it('shows the notification when no tab of the web app is on screen', async () => {
    const worker = loadWorker([{ url: 'https://praticos.app/web/', visibilityState: 'hidden' }])
    await worker.fire('push', { data: { json: () => PUSH } })
    expect(worker.shown).toEqual([
      { title: PUSH.notification.title, options: expect.objectContaining({ body: PUSH.notification.body, data: { link: '/web/?order=o1&company=c1' } }) },
    ])
  })

  it('hands it to the tab on screen instead (the bell and a notice inside the page)', async () => {
    const postMessage = vi.fn()
    const worker = loadWorker([{ url: 'https://praticos.app/web/orders', visibilityState: 'visible', postMessage }])
    await worker.fire('push', { data: { json: () => PUSH } })
    expect(worker.shown).toEqual([])
    expect(postMessage).toHaveBeenCalledWith({ type: 'praticos:notice', title: PUSH.notification.title, body: PUSH.notification.body, data: PUSH.data })
  })

  it('a click focuses the open tab and tells it what to open', async () => {
    const postMessage = vi.fn()
    const focus = vi.fn(() => Promise.resolve())
    const worker = loadWorker([{ url: 'https://praticos.app/web/', visibilityState: 'hidden', focus, postMessage }])
    const close = vi.fn()
    await worker.fire('notificationclick', { notification: { close, data: { link: '/web/?order=o1&company=c1' } } })
    expect(close).toHaveBeenCalled()
    expect(focus).toHaveBeenCalled()
    expect(postMessage).toHaveBeenCalledWith({ type: 'praticos:notice-open', link: '/web/?order=o1&company=c1' })
    expect(worker.opened).toEqual([])
  })

  it('a click without an open tab opens the link', async () => {
    const worker = loadWorker([])
    await worker.fire('notificationclick', { notification: { close: vi.fn(), data: { link: '/web/?order=o1&company=c1' } } })
    expect(worker.opened).toEqual(['/web/?order=o1&company=c1'])
  })

  it('reads the link from notification.click_action too, only inside /web', async () => {
    const worker = loadWorker([])
    const notification = { title: 'x', click_action: 'https://praticos.app/web/?order=o2&company=c1' }
    await worker.fire('push', { data: { json: () => ({ notification, data: {} }) } })
    await worker.fire('push', { data: { json: () => ({ notification: { ...notification, click_action: 'https://praticos.app/pricing' }, data: {} }) } })
    expect(worker.shown.map((n) => n.options.data?.link)).toEqual(['/web/?order=o2&company=c1', '/web/'])
  })

  it('without a link from the server, builds it from the data; without an order, the start', async () => {
    const worker = loadWorker([])
    await worker.fire('push', { data: { json: () => ({ ...PUSH, fcmOptions: undefined }) } })
    await worker.fire('push', { data: { json: () => ({ notification: { title: 'Manutenção' }, data: { type: 'maintenance_due' } }) } })
    expect(worker.shown.map((n) => n.options.data?.link)).toEqual(['/web/?order=o1&company=c1', '/web/'])
  })
})
