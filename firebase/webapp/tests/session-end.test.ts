// The session ending without the button, and account changes, must clear the
// cache; a failed clear is retried on the next load.
import { beforeEach, describe, expect, test, vi } from 'vitest'

let authCallback: ((user: unknown) => void) | undefined
const clearFirestoreCache = vi.fn(async () => {})
const cacheState = { trusted: true }

vi.mock('firebase/auth', () => ({
  onAuthStateChanged: (_auth: unknown, callback: (user: unknown) => void) => {
    authCallback = callback
  },
}))
vi.mock('firebase/firestore', () => ({
  doc: (_db: unknown, path: string) => path,
  getDoc: async () => ({ exists: () => false, data: () => undefined }),
  getDocFromCache: async () => {
    throw new Error('not cached')
  },
}))
vi.mock('../src/lib/firebase', () => ({
  authClient: async () => ({ currentUser: null }),
  firestoreClient: async () => ({}),
  clearFirestoreCache: () => clearFirestoreCache(),
  cacheState,
}))

const flush = () => new Promise((resolve) => setTimeout(resolve, 0))

beforeEach(() => {
  localStorage.clear()
  clearFirestoreCache.mockReset()
  clearFirestoreCache.mockResolvedValue(undefined)
  vi.stubGlobal('fetch', async () => new Response(JSON.stringify({ success: true, data: { allowed: true } })))
})

describe('cache owner', () => {
  test('rule', async () => {
    const { cacheNeedsClearing } = await import('../src/lib/session')
    expect(cacheNeedsClearing(null, null)).toBe(false)
    expect(cacheNeedsClearing('u1', 'u1')).toBe(false)
    expect(cacheNeedsClearing('u1', 'u2')).toBe(true)
    expect(cacheNeedsClearing('u1', null)).toBe(true)
  })

  test('signed out at start with a cache left behind: it is cleared, and retried while it fails', async () => {
    localStorage.setItem('praticos.cacheOwner', 'old')
    clearFirestoreCache.mockRejectedValueOnce(new Error('blocked'))
    const { startSession } = await import('../src/lib/session')
    const started = startSession()
    await flush()
    authCallback?.(null)
    await started
    expect(clearFirestoreCache).toHaveBeenCalledTimes(1)
    // Failed: the owner stays, so the next load tries again.
    expect(localStorage.getItem('praticos.cacheOwner')).toBe('old')

    authCallback?.(null)
    await flush()
    await flush()
    expect(clearFirestoreCache).toHaveBeenCalledTimes(2)
    expect(localStorage.getItem('praticos.cacheOwner')).toBe('')
  })

  test('another account: cache cleared before reading, and access starts unknown', async () => {
    localStorage.setItem('praticos.cacheOwner', 'previous')
    const { session } = await import('../src/lib/session')
    session.webAccess = 'allowed'
    const user = {
      uid: 'u2',
      email: 'u2@praticos.test',
      emailVerified: true,
      displayName: 'U2',
      getIdTokenResult: async () => ({ claims: { roles: {} } }),
      getIdToken: async () => 't',
    }
    authCallback?.(user)
    await flush()
    await flush()
    expect(clearFirestoreCache).toHaveBeenCalledTimes(1)
    expect(localStorage.getItem('praticos.cacheOwner')).toBe('u2')
    expect(cacheState.trusted).toBe(true)
  })

  test('a failed clear for another account stops trusting the cache', async () => {
    localStorage.setItem('praticos.cacheOwner', 'someone')
    clearFirestoreCache.mockRejectedValueOnce(new Error('blocked'))
    const user = {
      uid: 'u3',
      email: 'u3@praticos.test',
      emailVerified: true,
      getIdTokenResult: async () => ({ claims: { roles: {} } }),
      getIdToken: async () => 't',
    }
    authCallback?.(user)
    await flush()
    await flush()
    expect(cacheState.trusted).toBe(false)
    expect(localStorage.getItem('praticos.cacheOwner')).toBe('someone')
  })
})

describe('access gate on network failure', () => {
  test('without a valid remembered yes, a failure is an error, not the previous value', async () => {
    vi.stubGlobal('fetch', async () => {
      throw new TypeError('Failed to fetch')
    })
    const { session } = await import('../src/lib/session')
    const user = {
      uid: 'u4',
      email: 'u4@praticos.test',
      emailVerified: true,
      getIdTokenResult: async () => ({ claims: { roles: {} } }),
      getIdToken: async () => 't',
    }
    session.webAccess = 'allowed'
    authCallback?.(user)
    for (let i = 0; i < 5; i++) await flush()
    expect(session.webAccess).toBe('error')
  })
})
