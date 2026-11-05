import { test } from 'node:test'
import assert from 'node:assert/strict'
import { isPreview, orderDataPath } from '../utils/preview.ts'

test('preview only with preview=1', () => {
  assert.equal(isPreview({ preview: '1' }), true)
  assert.equal(isPreview({ preview: ['1'] }), true)
  assert.equal(isPreview({ preview: 'true' }), false)
  assert.equal(isPreview({ preview: '0' }), false)
  assert.equal(isPreview({}), false)
  assert.equal(isPreview(null), false)
})

test('order data path carries the flag only in preview', () => {
  assert.equal(orderDataPath('ST_abc', false), '/api/orders/ST_abc')
  assert.equal(orderDataPath('ST_abc', true), '/api/orders/ST_abc?preview=1')
})

test('token is encoded', () => {
  assert.equal(orderDataPath('a/b', false), '/api/orders/a%2Fb')
})
