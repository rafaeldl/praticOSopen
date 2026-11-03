// Session loading against mocked Firebase: failures must never leave stale or
// financial data on screen.
import { beforeEach, describe, expect, test, vi } from 'vitest'

const docs = new Map<string, unknown>()
const failing = new Set<string>()

vi.mock('firebase/firestore', () => ({
  doc: (_db: unknown, path: string) => path,
  getDoc: async (path: string) => {
    if (failing.has(path)) throw new Error('offline')
    return { exists: () => docs.has(path), data: () => docs.get(path) }
  },
  getDocFromCache: async () => {
    throw new Error('not cached')
  },
}))

const user = {
  uid: 'u1',
  email: 'u1@praticos.test',
  displayName: 'U1',
  getIdTokenResult: vi.fn(async () => ({ claims: { roles: { a: 'owner' } } })),
  getIdToken: async () => 'token',
}

vi.mock('firebase/auth', () => ({
  signInWithEmailAndPassword: async () => ({ user }),
}))

vi.mock('../src/lib/firebase', () => ({
  authClient: async () => ({ currentUser: user }),
  firestoreClient: async () => ({}),
  clearFirestoreCache: async () => {},
}))

beforeEach(() => {
  docs.clear()
  failing.clear()
  localStorage.clear()
  user.getIdTokenResult.mockClear()
  vi.stubGlobal('fetch', async () => new Response(JSON.stringify({ success: true, data: { allowed: true } })))
  docs.set('users/u1', { name: 'U1', companies: [{ company: { id: 'a', name: 'Alfa' }, role: 'owner' }] })
  docs.set('companies/a', { name: 'Alfa', country: 'BR' })
})

describe('hydrate', () => {
  test('loads company, role and access', async () => {
    const { can, session, signInWithEmail } = await import('../src/lib/session')
    await signInWithEmail('u1@praticos.test', 'x')
    expect(session.companyId).toBe('a')
    expect(session.role).toBe('owner')
    expect(session.webAccess).toBe('allowed')
    expect(session.companyFailed).toBe(false)
    expect(can('viewPrices')).toBe(true)
  })

  test('company that does not load: warning, and money hidden', async () => {
    failing.add('companies/a')
    const { can, session, signInWithEmail } = await import('../src/lib/session')
    await signInWithEmail('u1@praticos.test', 'x')
    expect(session.companyId).toBe('a')
    expect(session.companyFailed).toBe(true)
    expect(can('viewPrices')).toBe(false)
    expect(can('manageUsers')).toBe(true)
  })

  test('account that does not load clears what was on screen', async () => {
    const { session, signInWithEmail } = await import('../src/lib/session')
    await signInWithEmail('u1@praticos.test', 'x')
    expect(session.companyId).toBe('a')
    failing.add('users/u1')
    await signInWithEmail('u1@praticos.test', 'x')
    expect(session.failed).toBe(true)
    expect(session.companyId).toBeNull()
    expect(session.company).toBeNull()
    expect(session.role).toBeNull()
    expect(session.companies).toEqual([])
  })

  test('a listed company the claim never gets refreshes the token once, not every time', async () => {
    docs.set('users/u1', {
      companies: [
        { company: { id: 'a', name: 'Alfa' }, role: 'owner' },
        { company: { id: 'ghost', name: 'Fantasma' }, role: 'admin' },
      ],
    })
    const { signInWithEmail } = await import('../src/lib/session')
    await signInWithEmail('u1@praticos.test', 'x')
    await signInWithEmail('u1@praticos.test', 'x')
    const forced = user.getIdTokenResult.mock.calls.filter((call) => (call as unknown[])[0] === true)
    expect(forced).toHaveLength(1)
  })

  test('company without a name in the document keeps an empty name for the screen to label', async () => {
    docs.set('users/u1', { companies: [{ company: { id: 'a' }, role: 'owner' }] })
    const { session, signInWithEmail } = await import('../src/lib/session')
    await signInWithEmail('u1@praticos.test', 'x')
    expect(session.companies).toEqual([{ id: 'a', name: '', role: 'owner' }])
  })
})
