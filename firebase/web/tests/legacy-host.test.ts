import { test } from 'node:test'
import assert from 'node:assert/strict'
import { legacyRedirect } from '../server/utils/legacy-host.ts'

test('old domains go to praticos.app with the same path and query', () => {
  assert.equal(legacyRedirect('GET', 'praticos.web.app', '/q/ST_abc?x=1&y=2'), 'https://praticos.app/q/ST_abc?x=1&y=2')
  assert.equal(legacyRedirect('HEAD', 'praticos.firebaseapp.com', '/pro/joao'), 'https://praticos.app/pro/joao')
  assert.equal(legacyRedirect('GET', 'Praticos.Web.App:443, 10.0.0.1', '/admin'), 'https://praticos.app/admin')
  assert.equal(legacyRedirect('GET', 'praticos.web.app', '/admin/companies'), 'https://praticos.app/admin/companies')
})

test('praticos.app and direct calls stay (no loop)', () => {
  assert.equal(legacyRedirect('GET', 'praticos.app', '/q/ST_abc'), null)
  assert.equal(legacyRedirect('GET', undefined, '/q/ST_abc'), null)
  assert.equal(legacyRedirect('GET', 'praticos-web-xyz.a.run.app', '/q/ST_abc'), null)
})

test('apis, assets and writes are not redirected', () => {
  assert.equal(legacyRedirect('GET', 'praticos.web.app', '/api/orders/ST_abc'), null)
  assert.equal(legacyRedirect('POST', 'praticos.web.app', '/q/ST_abc'), null)
  assert.equal(legacyRedirect('GET', 'praticos.web.app', '/_nuxt/entry.js'), null)
  assert.equal(legacyRedirect('GET', 'praticos.web.app', '/__/auth/handler'), null)
  assert.equal(legacyRedirect('GET', 'praticos.web.app', '/quote'), null)
  assert.equal(legacyRedirect('GET', 'praticos.web.app', '/profile'), null)
})
