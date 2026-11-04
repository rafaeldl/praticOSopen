import { afterEach, describe, expect, test, vi } from 'vitest'
import { shouldOfferStatusShare } from '../src/lib/orders/notify'
import type { Order } from '../src/lib/orders/model'
import { canShareFiles, canShareSheet, copyText, onShare, setShareListener, shareSheet, whatsappUrl } from '../src/lib/share'
import { logShare } from '../src/lib/analytics'

vi.mock('../src/lib/analytics', () => ({ logShare: vi.fn() }))

test('onShare sends the analytics share event once, with the content type', () => {
  vi.mocked(logShare).mockClear()
  onShare('whatsapp', 'receipt')
  expect(logShare).toHaveBeenCalledTimes(1)
  expect(logShare).toHaveBeenCalledWith('whatsapp', 'receipt')
})

const nav = globalThis.navigator as unknown as Record<string, unknown>
const saved = { share: nav.share, canShare: nav.canShare, clipboard: nav.clipboard }
function stubNavigator(values: Record<string, unknown>) {
  for (const [key, value] of Object.entries(values)) Object.defineProperty(globalThis.navigator, key, { value, configurable: true, writable: true })
}
afterEach(() => {
  stubNavigator(saved)
  setShareListener(null)
})

describe('whatsappUrl', () => {
  test('number and text go to wa.me', () => {
    expect(whatsappUrl('5511990001234', 'Olá! https://x.test/q/a b')).toBe('https://wa.me/5511990001234?text=Ol%C3%A1!%20https%3A%2F%2Fx.test%2Fq%2Fa%20b')
  })
  test('without a number WhatsApp asks for the contact', () => {
    expect(whatsappUrl('', 'oi')).toBe('https://wa.me/?text=oi')
    expect(whatsappUrl(null, 'oi')).toBe('https://wa.me/?text=oi')
  })
})

describe('onShare: the one place the share event goes through', () => {
  test('tells the listener the method and where', async () => {
    const seen: string[] = []
    setShareListener((method, context) => seen.push(`${method}:${context}`))
    onShare('whatsapp', 'order.link')
    stubNavigator({ clipboard: { writeText: vi.fn(async () => undefined) } })
    await copyText('abc', 'team.invite')
    stubNavigator({ share: vi.fn(async () => undefined) })
    await shareSheet({ text: 'x' }, 'order.photo')
    expect(seen).toEqual(['whatsapp:order.link', 'clipboard:team.invite', 'sheet:order.photo'])
  })

  test('a copy that fails or a sheet closed by the person is not counted', async () => {
    const seen: string[] = []
    setShareListener((method) => seen.push(method))
    stubNavigator({ clipboard: { writeText: vi.fn(async () => Promise.reject(new Error('denied'))) } })
    expect(await copyText('abc', 'x')).toBe(false)
    stubNavigator({ share: vi.fn(async () => Promise.reject(new DOMException('closed', 'AbortError'))) })
    expect(await shareSheet({ text: 'x' }, 'x')).toBe('cancelled')
    expect(seen).toEqual([])
  })
})

describe('Web Share API', () => {
  test('missing in the browser: no sheet', async () => {
    stubNavigator({ share: undefined, canShare: undefined })
    expect(canShareSheet()).toBe(false)
    expect(canShareFiles([new File(['a'], 'a.pdf')])).toBe(false)
    expect(await shareSheet({ text: 'x' }, 'x')).toBe('unavailable')
  })
  test('files only when canShare says so', () => {
    stubNavigator({ share: vi.fn(), canShare: vi.fn((data: ShareData) => !!data.files?.length) })
    expect(canShareSheet()).toBe(true)
    expect(canShareFiles([new File(['a'], 'a.pdf')])).toBe(true)
    stubNavigator({ canShare: vi.fn(() => false) })
    expect(canShareFiles([new File(['a'], 'a.pdf')])).toBe(false)
  })
})

describe('shouldOfferStatusShare (order_status_share.dart)', () => {
  const now = new Date('2026-11-04T12:00:00Z')
  const order = (extra: Partial<Order> = {}) => ({ id: 'o1', status: 'quote', customer: { id: 'c1', name: 'Ana', phone: '+5511990001234' }, shareLink: null, ...extra }) as unknown as Order

  test.each(['approved', 'progress', 'done'] as const)('%s with a phone and no link: asks', (status) => {
    expect(shouldOfferStatusShare(order(), status, new Set(), now)).toBe(true)
  })
  test.each(['quote', 'canceled'] as const)('%s: does not ask', (status) => {
    expect(shouldOfferStatusShare(order(), status, new Set(), now)).toBe(false)
  })
  test('without a phone, with an active link, or already asked for this order: does not ask', () => {
    expect(shouldOfferStatusShare(order({ customer: { id: 'c1', name: 'Ana', phone: '' } }), 'done', new Set(), now)).toBe(false)
    expect(shouldOfferStatusShare(order({ customer: undefined }), 'done', new Set(), now)).toBe(false)
    expect(shouldOfferStatusShare(order({ shareLink: { token: 't', expiresAt: '2026-11-10T00:00:00Z' } }), 'done', new Set(), now)).toBe(false)
    expect(shouldOfferStatusShare(order(), 'done', new Set(['o1']), now)).toBe(false)
  })
  test('an expired link, or one with no date, counts as the app does', () => {
    expect(shouldOfferStatusShare(order({ shareLink: { token: 't', expiresAt: '2026-11-01T00:00:00Z' } }), 'done', new Set(), now)).toBe(true)
    expect(shouldOfferStatusShare(order({ shareLink: { token: 't', expiresAt: null } }), 'done', new Set(), now)).toBe(false)
    expect(shouldOfferStatusShare(order({ shareLink: { token: null, expiresAt: null } }), 'done', new Set(), now)).toBe(true)
  })
})
