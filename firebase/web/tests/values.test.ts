import { test } from 'node:test'
import assert from 'node:assert/strict'
import { showsValues } from '../utils/values.ts'

test('shows values when the api does not send the flag (older api)', () => {
  assert.equal(showsValues({}), true)
  assert.equal(showsValues(null), true)
  assert.equal(showsValues(undefined), true)
})

test('shows values when the company uses values and billing', () => {
  assert.equal(showsValues({ showValues: true }), true)
})

test('hides values only on an explicit false', () => {
  assert.equal(showsValues({ showValues: false }), false)
  assert.equal(showsValues({ showValues: null }), true)
})
