import { test } from 'node:test'
import assert from 'node:assert/strict'
import { createVisibilityRefresher } from '../utils/visibility-refresher.ts'

function setup(opts: { when?: () => boolean; refresh?: () => unknown } = {}) {
  let calls = 0
  let t = 1_000
  const handle = createVisibilityRefresher({
    refresh: opts.refresh ?? (() => { calls++ }),
    when: opts.when,
    minIntervalMs: 10_000,
    now: () => t,
  })
  return { handle, calls: () => calls, advance: (ms: number) => { t += ms } }
}

test('ignores hidden tab', () => {
  const s = setup()
  s.handle('hidden')
  assert.equal(s.calls(), 0)
})

test('ignores when `when` is false', () => {
  const s = setup({ when: () => false })
  s.handle('visible')
  assert.equal(s.calls(), 0)
})

test('refreshes when visible and allowed', () => {
  const s = setup({ when: () => true })
  s.handle('visible')
  assert.equal(s.calls(), 1)
})

test('throttles by minIntervalMs', () => {
  const s = setup()
  s.handle('visible')
  s.advance(9_999)
  s.handle('visible')
  assert.equal(s.calls(), 1)
  s.advance(1)
  s.handle('visible')
  assert.equal(s.calls(), 2)
})

test('skipped calls do not consume the throttle window', () => {
  let allowed = false
  const s = setup({ when: () => allowed })
  s.handle('visible')
  allowed = true
  s.handle('visible')
  assert.equal(s.calls(), 1)
})

test('sync and async refresh errors do not throw or go unhandled', async () => {
  const unhandled: unknown[] = []
  const onUnhandled = (e: unknown) => unhandled.push(e)
  process.on('unhandledRejection', onUnhandled)
  const sync = setup({ refresh: () => { throw new Error('boom') } })
  assert.doesNotThrow(() => sync.handle('visible'))
  const async_ = setup({ refresh: () => Promise.reject(new Error('boom')) })
  assert.doesNotThrow(() => async_.handle('visible'))
  await new Promise((r) => setTimeout(r, 20))
  process.off('unhandledRejection', onUnhandled)
  assert.equal(unhandled.length, 0)
})
