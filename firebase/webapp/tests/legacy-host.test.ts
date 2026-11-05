// The production index.html sends /web on the old domains to praticos.app before
// anything loads. Runs the exact inline script that ships, against fake locations.
import { describe, expect, test } from 'vitest'
import { LEGACY_HOST_SCRIPT, legacyHostRedirect } from '../scripts/legacy-host-plugin'

function run(href: string): string | null {
  const url = new URL(href)
  let target: string | null = null
  const location = {
    hostname: url.hostname,
    pathname: url.pathname,
    search: url.search,
    hash: url.hash,
    replace: (next: string) => (target = next),
  }
  new Function('location', LEGACY_HOST_SCRIPT)(location)
  return target
}

describe('old domain → praticos.app', () => {
  test.each([
    ['https://praticos.web.app/web/', 'https://praticos.app/web/'],
    ['https://praticos.web.app/web', 'https://praticos.app/web'],
    ['https://praticos.web.app/web/orders?order=abc&f=all#x', 'https://praticos.app/web/orders?order=abc&f=all#x'],
    ['https://praticos.firebaseapp.com/web/login', 'https://praticos.app/web/login'],
  ])('%s goes to %s', (from, to) => {
    expect(run(from)).toBe(to)
  })

  test.each([
    'https://praticos.app/web/orders',
    'http://localhost:5180/app/',
    'http://127.0.0.1:15050/app/login',
    'https://praticos.web.app/q/ST_x',
    'https://praticos.web.app/__/auth/handler',
    'https://praticos.web.app/',
    'https://praticos.web.app/application',
    'https://praticos--preview-1.web.app/app/',
  ])('%s stays', (href) => {
    expect(run(href)).toBeNull()
  })
})

describe('plugin', () => {
  type Hook = (html: string) => unknown
  const hook = (mode: string) => {
    const plugin = legacyHostRedirect()
    const configResolved = plugin.configResolved as (config: { mode: string }) => void
    configResolved({ mode })
    return (plugin.transformIndexHtml as { handler: Hook }).handler(HTML)
  }
  const HTML = '<head>\n    <meta charset="utf-8" />\n    <title>PraticOS</title>'

  test('production build carries the script right after the charset', () => {
    expect(hook('production')).toBe(
      `<head>\n    <meta charset="utf-8" />\n    <script>${LEGACY_HOST_SCRIPT}</script>\n    <title>PraticOS</title>`,
    )
  })

  test('e2e build and dev do not redirect', () => {
    expect(hook('e2e')).toBe(HTML)
    expect(hook('development')).toBe(HTML)
  })
})
