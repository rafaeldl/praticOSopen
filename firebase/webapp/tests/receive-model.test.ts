import { describe, expect, it } from 'vitest'
import {
  allocate,
  allocationSummary,
  asaasUrl,
  canRemove,
  canceledPlanOf,
  chargeOf,
  chargeState,
  initialChargeValue,
  installmentValue,
  messageKind,
  openChargeOf,
  paidAtFor,
  paymentsOf,
  permissionKind,
  pickToken,
  previewUrl,
  receivesMoney,
  safeUrl,
  undoAllState,
  validityDays,
  whatsappLink,
  type OpenOrder,
  receivableOf,
} from '@/lib/receive/model'
import { normalizeOrder } from '@/lib/orders/model'

const order = (id: string, open: number, createdAt: string, number = 1): OpenOrder => ({ id, number, open, createdAt, own: true })

describe('paymentsOf', () => {
  it('newest day first, by paidAt and then createdAt', () => {
    const list = paymentsOf([
      { id: 'a', type: 'payment', amount: 10, createdAt: '2026-10-01T10:00:00Z' },
      { id: 'b', type: 'payment', amount: 20, createdAt: '2026-10-01T10:00:00Z', paidAt: '2026-10-05T12:00:00Z' },
      { id: 'c', type: 'discount', amount: 5, createdAt: '2026-10-03T10:00:00Z' },
    ])
    expect(list.map((p) => p.id)).toEqual(['b', 'c', 'a'])
  })
  it('proof from documents, Asaas lock and receipt share', () => {
    const [asaas, share] = paymentsOf(
      [
        { id: 'asaas_pay_0', type: 'payment', amount: 10, createdAt: '2026-10-02T00:00:00Z', receiptUrl: 'https://www.asaas.com/r/1' },
        { id: 'r1_0', type: 'payment', amount: 10, createdAt: '2026-10-01T00:00:00Z', receiptGroupId: 'r1', receiptDocumentId: 'd1' },
      ],
      [{ id: 'd1', url: 'https://firebasestorage.googleapis.com/x' }],
    )
    expect(asaas!.isAsaas).toBe(true)
    expect(canRemove(asaas!)).toBe(false)
    expect(share!.proofUrl).toBe('https://firebasestorage.googleapis.com/x')
    expect(canRemove(share!)).toBe(false)
  })
  it('drops what is not a payment or discount and never links javascript:', () => {
    const list = paymentsOf([{ type: 'payment', amount: 1, receiptUrl: 'javascript:alert(1)' }, { type: 'x', amount: 1 }, { type: 'payment' }])
    expect(list).toHaveLength(1)
    expect(list[0]!.proofUrl).toBeUndefined()
    expect(safeUrl('javascript:alert(1)')).toBeUndefined()
  })
})

describe('undoAllState and receivesMoney', () => {
  it('none, blocked by a receipt share, allowed', () => {
    expect(undoAllState(paymentsOf([{ id: 'asaas_1', type: 'payment', amount: 1 }]))).toBe('none')
    expect(undoAllState(paymentsOf([{ id: 'x', type: 'payment', amount: 1, receiptGroupId: 'r' }]))).toBe('blocked')
    expect(undoAllState(paymentsOf([{ id: 'x', type: 'payment', amount: 1 }]))).toBe('allowed')
  })
  it('quote and canceled take no payment', () => {
    expect(receivesMoney('quote')).toBe(false)
    expect(receivesMoney('canceled')).toBe(false)
    expect(receivesMoney('done')).toBe(true)
  })
})

describe('allocate', () => {
  const orders = [order('new', 50, '2026-10-03', 18), order('old', 100.1, '2026-10-01', 12), order('mid', 30, '2026-10-02', 15)]
  it('oldest first, each up to what it owes, in cents', () => {
    expect(allocate(140.1, orders)).toEqual([
      { orderId: 'old', number: 12, amount: 100.1, settles: true },
      { orderId: 'mid', number: 15, amount: 30, settles: true },
      { orderId: 'new', number: 18, amount: 10, settles: false },
    ])
  })
  it('never more than the orders owe', () => {
    const split = allocate(1000, orders)
    expect(split.reduce((s, a) => s + a.amount, 0)).toBeCloseTo(180.1)
  })
  it('summary: settled, the part and what is left', () => {
    const split = allocate(140.1, orders)
    expect(allocationSummary(split, 180.1)).toEqual({ settled: [12, 15], part: split[2], left: 40 })
  })
  it('0.1 + 0.2 stays 0.3 (cents)', () => {
    expect(allocate(0.3, [order('a', 0.1, '1'), order('b', 0.2, '2')]).map((a) => a.amount)).toEqual([0.1, 0.2])
  })
})

describe('paidAtFor', () => {
  it('now for today, noon of the day otherwise', () => {
    const now = new Date(2026, 10, 3, 9, 30)
    expect(paidAtFor('2026-11-03', now)).toBe(now.toISOString())
    expect(paidAtFor('2026-11-01', now)).toBe(new Date(2026, 10, 1, 12).toISOString())
  })
})

describe('share link', () => {
  const now = new Date('2026-11-03T12:00:00Z')
  it('first valid token', () => {
    const tokens = [
      { token: 'a', url: 'u/a', permissions: ['view' as const], expiresAt: '2026-11-01T00:00:00Z' },
      { token: 'b', url: 'u/b', permissions: ['view' as const], expiresAt: '2026-11-20T00:00:00Z' },
    ]
    expect(pickToken(tokens, now)?.token).toBe('b')
    expect(pickToken([{ ...tokens[1]!, isExpired: true }], now)).toBeNull()
  })
  it('permissions, validity and message kind', () => {
    expect(permissionKind(['view', 'approve', 'comment'])).toBe('all')
    expect(permissionKind(['view', 'comment'])).toBe('comment')
    expect(permissionKind([])).toBe('view')
    expect(validityDays({ expiresAt: '2026-12-03T12:00:00Z' }, now)).toBe(30)
    expect(messageKind('canceled')).toBe('other')
    expect(whatsappLink('5511999999999', 'Olá & até')).toBe('https://wa.me/5511999999999?text=Ol%C3%A1%20%26%20at%C3%A9')
  })
})

describe('charges', () => {
  const charge = (id: string, raw: Record<string, unknown>) => chargeOf(id, { value: 100, dueDate: '2026-11-10', createdAt: '2026-11-01T00:00:00Z', ...raw })
  it('only an https Asaas page is a payment link', () => {
    expect(asaasUrl('https://sandbox.asaas.com/i/1')).toBe('https://sandbox.asaas.com/i/1')
    expect(asaasUrl('https://asaas.com.evil.io/i/1')).toBeUndefined()
    expect(asaasUrl('http://www.asaas.com/i/1')).toBeUndefined()
  })
  it('the newest open one', () => {
    const list = [charge('a', { status: 'pending', createdAt: '2026-11-01T00:00:00Z' }), charge('b', { status: 'overdue', createdAt: '2026-11-02T00:00:00Z' }), charge('c', { status: 'paid', createdAt: '2026-11-03T00:00:00Z' })]
    expect(openChargeOf(list)?.id).toBe('b')
  })
  it('expired, changed and owed outside the link', () => {
    const open = charge('a', { status: 'pending' })
    expect(chargeState(open, 80, '2026-11-05')).toEqual({ expired: false, changed: true, outside: 0 })
    expect(chargeState(open, 130, '2026-11-11')).toEqual({ expired: true, changed: false, outside: 30 })
    expect(chargeState(charge('b', { status: 'pending', paidAsaasPaymentIds: ['p1'] }), 80, '2026-11-05').changed).toBe(false)
  })
  it('canceled plan only while the order still owes', () => {
    const plan = charge('a', { status: 'canceled', autoCanceled: true })
    expect(canceledPlanOf([plan], 50)?.id).toBe('a')
    expect(canceledPlanOf([plan], 0)).toBeNull()
  })
  it('installments and the first value', () => {
    expect(installmentValue(100, 3)).toBe(33.33)
    expect(initialChargeValue(50, 80)).toBe(50)
    expect(initialChargeValue(90, 80)).toBe(80)
    expect(initialChargeValue(undefined, 80)).toBe(80)
  })
})

describe('revisão #518', () => {
  const row = (status: string, total: number, paidAmount: number) => normalizeOrder('x', { status, total, paidAmount }, true)
  it('a receber: concluída com saldo e OS aberta com sinal; orçamento, cancelada e aberta sem sinal não', () => {
    expect(receivableOf(row('done', 100, 30))).toBe(70)
    expect(receivableOf(row('approved', 100, 30))).toBe(70)
    expect(receivableOf(row('progress', 80, 0.01))).toBe(79.99)
    expect(receivableOf(row('progress', 80, 0))).toBeNull()
    expect(receivableOf(row('quote', 80, 10))).toBeNull()
    expect(receivableOf(row('canceled', 80, 10))).toBeNull()
    expect(receivableOf(row('done', 100, 100))).toBeNull()
  })
  it('duas abas: o link mais novo dos válidos', () => {
    const now = new Date('2026-11-03T12:00:00Z')
    const tokens = [
      { token: 'old', url: 'u/old', permissions: ['view' as const], expiresAt: '2026-11-20T00:00:00Z', createdAt: '2026-11-03T10:00:00Z' },
      { token: 'new', url: 'u/new', permissions: ['view' as const], expiresAt: '2026-11-20T00:00:00Z', createdAt: '2026-11-03T11:00:00Z' },
    ]
    expect(pickToken(tokens, now)?.token).toBe('new')
  })
})

describe('previewUrl ("Ver como o cliente vê")', () => {
  it('opens the same link marked as a preview', () => {
    expect(previewUrl('https://praticos.app/q/ST_1')).toBe('https://praticos.app/q/ST_1?preview=1')
  })
  it('keeps other query params and does not repeat the flag', () => {
    expect(previewUrl('https://praticos.app/q/ST_1?lang=en')).toBe('https://praticos.app/q/ST_1?lang=en&preview=1')
    expect(previewUrl('https://praticos.app/q/ST_1?preview=1')).toBe('https://praticos.app/q/ST_1?preview=1')
  })
})
