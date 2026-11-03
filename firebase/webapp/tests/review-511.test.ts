// Fixes from the #511 review: access memory, list merge, stale builds.
import { beforeEach, describe, expect, test, vi } from 'vitest'
import { applyFreshFirstPage, compareRows, mergeById } from '../src/lib/order-list'
import { isChunkLoadError, reloadForNewBuild } from '../src/lib/stale-build'
import { ALLOWED_TTL_MS, rememberAccess, rememberedAccess, shouldRecheck } from '../src/lib/web-access'

beforeEach(() => localStorage.clear())

describe('access memory', () => {
  test('a time in the future is invalid', () => {
    localStorage.setItem('praticos.webAccess.u1', String(5000))
    expect(rememberedAccess('u1', 1000)).toBe(false)
    expect(shouldRecheck('u1', 1000)).toBe(true)
  })

  test('garbage is invalid', () => {
    localStorage.setItem('praticos.webAccess.u1', 'abc')
    expect(rememberedAccess('u1', 1000)).toBe(false)
  })

  test('valid yes, then expired', () => {
    rememberAccess('u1', true, 1000)
    expect(rememberedAccess('u1', 1000)).toBe(true)
    expect(rememberedAccess('u1', 1000 + ALLOWED_TTL_MS)).toBe(false)
  })
})

const row = (id: string, createdAt: string) => ({ id, createdAt })

describe('list merge', () => {
  test('newest first, id breaks ties', () => {
    const rows = [row('a', '2026-01-01'), row('c', '2026-01-02'), row('b', '2026-01-01')].sort(compareRows)
    expect(rows.map((r) => r.id)).toEqual(['c', 'b', 'a'])
  })

  test('pages join by id without repeating', () => {
    const page1 = [row('d', '4'), row('c', '3')]
    const page2 = [row('c', '3'), row('b', '2'), row('a', '1')]
    expect(mergeById(page1, page2).map((r) => r.id)).toEqual(['d', 'c', 'b', 'a'])
  })

  test('server first page replaces the disk copy for its stretch and keeps older pages', () => {
    const disk = [row('e', '5'), row('gone', '4'), row('c', '3'), row('b', '2'), row('a', '1')]
    const fresh = [row('new', '6'), row('e', '5'), row('c', '3')]
    expect(applyFreshFirstPage(disk, fresh, 3).map((r) => r.id)).toEqual(['new', 'e', 'c', 'b', 'a'])
  })

  test('a short server page means the list ended', () => {
    const disk = [row('b', '2'), row('a', '1')]
    expect(applyFreshFirstPage(disk, [row('b', '2')], 3).map((r) => r.id)).toEqual(['b'])
  })

  test('same createdAt across the page edge is not lost', () => {
    const disk = [row('z', '5'), row('y', '5'), row('x', '5')]
    const fresh = [row('z', '5'), row('y', '5')]
    expect(applyFreshFirstPage(disk, fresh, 2).map((r) => r.id)).toEqual(['z', 'y', 'x'])
  })
})

describe('stale build', () => {
  const storage = () => {
    const map = new Map<string, string>()
    return { getItem: (k: string) => map.get(k) ?? null, setItem: (k: string, v: string) => void map.set(k, v) }
  }

  test('reloads once, not in a loop', () => {
    const store = storage()
    const reload = vi.fn()
    expect(reloadForNewBuild(store, reload, 1000)).toBe(true)
    expect(reloadForNewBuild(store, reload, 2000)).toBe(false)
    expect(reload).toHaveBeenCalledOnce()
    expect(reloadForNewBuild(store, reload, 1000 + 61_000)).toBe(true)
  })

  test('recognizes failed chunk loads', () => {
    expect(isChunkLoadError(new TypeError('Failed to fetch dynamically imported module: /app/assets/x.js'))).toBe(true)
    expect(isChunkLoadError(new Error('boom'))).toBe(false)
  })
})
