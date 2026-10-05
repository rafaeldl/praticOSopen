import { test } from 'node:test'
import assert from 'node:assert/strict'
import { quietRefresh } from '../utils/quiet-refresh.ts'

test('assigns the fresh value on success', async () => {
  let current: unknown = 'old'
  await quietRefresh(async () => 'new', (v) => { current = v })
  assert.equal(current, 'new')
})

test('keeps previous data and does not throw on failure', async () => {
  let current: unknown = 'old'
  await quietRefresh(async () => { throw new Error('network') }, (v) => { current = v })
  assert.equal(current, 'old')
})

test('keeps previous data when the fetcher throws synchronously', async () => {
  let current: unknown = 'old'
  await quietRefresh(() => { throw new Error('boom') }, (v) => { current = v })
  assert.equal(current, 'old')
})
