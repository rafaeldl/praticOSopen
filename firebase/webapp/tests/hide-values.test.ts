// The eye of the order screens (prefs.hideValues): "R$ •••" in place of values.
import { afterEach, describe, expect, test, vi } from 'vitest'

vi.mock('../src/lib/firebase', () => ({
  authClient: vi.fn(),
  firestoreClient: vi.fn(),
  storageClient: vi.fn(),
  usesEmulators: false,
}))

const { prefs } = await import('../src/lib/prefs')
const { session } = await import('../src/lib/session')
const { hiddenMoney, money, shownMoney } = await import('../src/lib/orders/text')

// Intl uses narrow and non-breaking spaces depending on the ICU version.
const plain = (text: string) => text.replace(/[  ]/g, ' ')

afterEach(() => {
  prefs.hideValues = false
  session.company = null
})

describe('hidden values', () => {
  test('off by default: values as always', () => {
    session.company = { country: 'BR' }
    expect(prefs.hideValues).toBe(false)
    expect(shownMoney(1234.5)).toBe(money(1234.5))
  })

  test('on: dots in the company currency, no digit left', () => {
    prefs.hideValues = true
    session.company = { country: 'BR' }
    expect(plain(shownMoney(1234.5))).toBe('R$ •••')
    session.company = { country: 'US' }
    expect(shownMoney(99)).toBe('$•••')
    session.company = { country: 'ES' }
    expect(plain(hiddenMoney())).toBe('••• €')
    expect(shownMoney(4200)).not.toMatch(/\d/)
  })

  test('null and zero are hidden too (no "R$ 0,00" giving away an empty order)', () => {
    prefs.hideValues = true
    session.company = { country: 'BR' }
    expect(plain(shownMoney(null))).toBe('R$ •••')
    expect(plain(shownMoney(0))).toBe('R$ •••')
  })

  test('money() never hides: dialogs that change a price keep the number', () => {
    prefs.hideValues = true
    session.company = { country: 'BR' }
    expect(plain(money(10))).toBe('R$ 10,00')
  })
})
