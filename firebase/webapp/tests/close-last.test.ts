// Rules of the last lines of the matrix (feat/webapp-close-last): next charge,
// assistant draft and money card, device picker and the customer's ✓.
import { beforeEach, describe, expect, it } from 'vitest'
import type { Debtor } from '@/lib/finance/data'
import { nextChargeCandidates, openOrdersOf, resolveNextCharge, sendPath, snoozeNextCharge, snoozedKeys } from '@/lib/finance/next-charge'
import { contextOf, paymentAmount, planAiActions, stepsOf, type ActionsContext, type DraftActions } from '@/lib/orders/ai-actions'
import { changeTarget, currentCustomerId, customerStep, deviceStep, dueFromDraft, newDeviceOf, noteKey, normalizeDraft, usesLeft } from '@/lib/orders/assist-draft'
import { canConfirm, deviceIdsOf, emptyPick, pickResult, toggleAll, toggleDevice, toggleGeneral } from '@/lib/orders/device-pick'
import { normalizeOrder } from '@/lib/orders/model'

const NOW = new Date('2026-11-04T12:00:00-03:00')
const debtor = (key: string, since: string | null, orders = 1): Debtor => ({
  key,
  customer: key === '_none' ? null : { id: key, name: key.toUpperCase() },
  amount: 100,
  since,
  orders: Array.from({ length: orders }, (_, i) => ({ id: `${key}-${i}`, number: i + 1, status: 'done', customer: { id: key, name: key }, device: null, total: 100, paid: 0, open: 100, createdAt: since, amount: 100 })),
})

describe('fin.tab.next-charge', () => {
  beforeEach(() => localStorage.clear())

  it('orders the last 90 days oldest first, then older newest first, no date last, without snoozed', () => {
    const list = [
      debtor('old1', '2026-01-10T10:00:00.000'),
      debtor('recent2', '2026-10-20T10:00:00.000'),
      debtor('nodate', null),
      debtor('recent1', '2026-09-01T10:00:00.000'),
      debtor('old2', '2026-06-01T10:00:00.000'),
      debtor('snoozed', '2026-10-01T10:00:00.000'),
    ]
    expect(nextChargeCandidates(list, new Set(['snoozed']), NOW).map((d) => d.key)).toEqual(['recent1', 'recent2', 'old2', 'old1', 'nodate'])
  })

  it('skips who has an open link and hides on a failed or slow read', async () => {
    const list = [debtor('a', '2026-10-01'), debtor('b', '2026-10-02')]
    expect((await resolveNextCharge(list, async (d) => d.key === 'a'))?.key).toBe('b')
    expect(await resolveNextCharge(list, async () => true)).toBeNull()
    expect(await resolveNextCharge(list, async () => Promise.reject(new Error('denied')))).toBeNull()
    expect(await resolveNextCharge(list, () => new Promise((resolve) => setTimeout(() => resolve(false), 50)), 10)).toBeNull()
  })

  it('checks links on every open order of the customer, done or not', () => {
    const d = debtor('c1', '2026-10-01')
    const running = [{ ...d.orders[0]!, id: 'running', status: 'progress' as const }, { ...d.orders[0]!, id: 'other', customer: { id: 'c2', name: 'x' } }]
    expect(openOrdersOf(d, running)).toEqual(['c1-0', 'running'])
  })

  it('"Agora não" lasts 30 days in this browser, per company', () => {
    snoozeNextCharge('co1', 'c1', NOW)
    expect(snoozedKeys('co1', NOW).has('c1')).toBe(true)
    expect(snoozedKeys('co2', NOW).has('c1')).toBe(false)
    expect(snoozedKeys('co1', new Date(NOW.getTime() + 31 * 86_400_000)).has('c1')).toBe(false)
    // The expired entry was dropped as it was read.
    expect(snoozedKeys('co1', NOW).has('c1')).toBe(false)
  })

  it('sends one customer charge only with several orders, a customer and Asaas ready', () => {
    expect(sendPath(debtor('c1', null, 2), true)).toBe('customer')
    expect(sendPath(debtor('c1', null, 2), false)).toBe('order')
    expect(sendPath(debtor('c1', null, 1), true)).toBe('order')
    expect(sendPath(debtor('_none', null, 2), true)).toBe('order')
  })
})

const ctx = (over: Partial<ActionsContext> = {}): ActionsContext => ({
  status: 'done',
  total: 1000,
  remaining: 1000,
  showMoney: true,
  canReceive: true,
  canDiscount: true,
  canChangeStatus: () => true,
  pendingChecklists: 0,
  nfseAutoIssue: null,
  ...over,
})
const act = (over: Partial<DraftActions>): DraftActions => ({ payment: null, discount: null, status: null, ...over })

describe('order.ai.money-plan', () => {
  it('"pagou tudo" is the balance and settles at saving time', () => {
    const plan = planAiActions(act({ payment: { kind: 'full', value: null, method: 'pix', paidDate: null } }), ctx())
    expect(plan.payment).toMatchObject({ amount: 1000, settlesAll: true, paysOff: true, method: 'pix' })
    expect(plan.canConfirm).toBe(true)
  })

  it('percent of the balance after the discount; discount percent of the total', () => {
    const plan = planAiActions(act({ discount: { kind: 'percent', value: 10 }, payment: { kind: 'percent', value: 50, method: null, paidDate: null } }), ctx())
    expect(plan.discount?.amount).toBe(100)
    expect(plan.payment?.amount).toBe(450)
    expect(stepsOf(plan)).toEqual(['discount', 'payment'])
  })

  it('"ficou devendo 200" and an amount above the balance (Falta só)', () => {
    expect(planAiActions(act({ payment: { kind: 'leaving', value: 200, method: null, paidDate: null } }), ctx()).payment?.amount).toBe(800)
    const over = planAiActions(act({ payment: { kind: 'value', value: 1500, method: null, paidDate: null } }), ctx())
    expect(over.payment?.amount).toBe(1000)
    expect(over.notices).toContainEqual({ kind: 'onlyLeft', amount: 1000 })
  })

  it('no amount said: the row asks and Confirmar waits', () => {
    const plan = planAiActions(act({ payment: { kind: 'value', value: null, method: null, paidDate: null } }), ctx())
    expect(plan.payment?.amount).toBeNull()
    expect(plan.canConfirm).toBe(false)
  })

  it('a quote is approved first, or nothing when the person cannot approve', () => {
    const said = act({ payment: { kind: 'full', value: null, method: null, paidDate: null } })
    expect(stepsOf(planAiActions(said, ctx({ status: 'quote' })))).toEqual(['approve', 'payment'])
    const denied = planAiActions(said, ctx({ status: 'quote', canChangeStatus: () => false }))
    expect(denied.hasSteps).toBe(false)
    expect(denied.notices).toContainEqual({ kind: 'statusDenied' })
  })

  it('status only forward, never with checklists to finish', () => {
    expect(planAiActions(act({ status: 'approved' }), ctx({ status: 'progress' })).hasSteps).toBe(false)
    expect(planAiActions(act({ status: 'done' }), ctx({ status: 'progress' })).status).toBe('done')
    expect(planAiActions(act({ status: 'done' }), ctx({ status: 'progress', pendingChecklists: 2 })).notices).toContainEqual({ kind: 'pendingChecklists', count: 2 })
  })

  it('who cannot receive or give discount gets the reason; canceled stops everything', () => {
    const plan = planAiActions(act({ payment: { kind: 'full', value: null, method: null, paidDate: null }, discount: { kind: 'value', value: 10 } }), ctx({ canReceive: false, canDiscount: false }))
    expect(plan.notices.map((n) => n.kind)).toEqual(['cannotDiscount', 'cannotReceive'])
    expect(planAiActions(act({ status: 'done' }), ctx({ status: 'canceled' })).notices).toEqual([{ kind: 'canceled' }])
  })

  it('warns about the nota only when a payment settles or the order is done', () => {
    const full = act({ payment: { kind: 'full', value: null, method: null, paidDate: null } })
    expect(planAiActions(full, ctx({ nfseAutoIssue: 'paid' })).issuesNfse).toBe(true)
    expect(planAiActions(act({ discount: { kind: 'value', value: 1000 } }), ctx({ nfseAutoIssue: 'paid' })).issuesNfse).toBe(false)
    expect(planAiActions(act({ status: 'done' }), ctx({ status: 'progress', nfseAutoIssue: 'completed' })).issuesNfse).toBe(true)
  })

  it('pays the current balance for "tudo" or when the balance went down', () => {
    const step = { amount: 500, max: 1000, method: null, paidDay: null, settlesAll: false, left: 500, paysOff: false }
    expect(paymentAmount(step, 1000)).toBe(500)
    expect(paymentAmount(step, 300)).toBe(300)
    expect(paymentAmount({ ...step, settlesAll: true }, 900)).toBe(900)
  })

  it('the context follows the order rules (consultant receives only on own orders)', () => {
    const order = normalizeOrder('o1', { status: 'done', total: 100, paidAmount: 0, createdBy: { id: 'u1' } }, true)
    expect(contextOf(order, 'consultant', 'u1', true, 0, null).canReceive).toBe(true)
    expect(contextOf(order, 'consultant', 'u2', true, 0, null).canReceive).toBe(false)
    expect(contextOf(order, 'admin', 'u2', false, 0, null).showMoney).toBe(false)
  })
})

describe('order.ai assistant draft', () => {
  const draft = (over: Record<string, unknown>) => normalizeDraft(over)

  it('customer: match, new on the Nova OS, or asks; never over a chosen one', () => {
    const base = { hasCustomer: false, isNew: true, canRegister: true }
    expect(customerStep(draft({ customer: { match: { id: 'c1', name: 'Ana' }, guess: null, alternatives: [] } }), base)).toEqual({ kind: 'match', customer: { id: 'c1', name: 'Ana' } })
    expect(customerStep(draft({ customer: { match: null, guess: { name: 'Juliana', phone: '48 2222-2222' }, alternatives: [] } }), base)).toEqual({ kind: 'new', name: 'Juliana', phone: '48 2222-2222' })
    const alt = { match: null, guess: { name: 'Juliene' }, alternatives: [{ id: 'c2', name: 'Juliana' }] }
    expect(customerStep(draft({ customer: alt }), base)).toMatchObject({ kind: 'ask', name: 'Juliene', options: [{ id: 'c2' }] })
    // Without manageCustomers or on a saved order, the new one never enters by itself.
    expect(customerStep(draft({ customer: { ...alt, alternatives: [] } }), { ...base, canRegister: false }).kind).toBe('ask')
    expect(customerStep(draft({ customer: { ...alt, alternatives: [] } }), { ...base, isNew: false }).kind).toBe('ask')
    expect(customerStep(draft({ customer: alt }), { ...base, hasCustomer: true }).kind).toBe('none')
  })

  it('device: a plate not in the register is new, a model with look-alikes asks', () => {
    const base = { devices: [], isNew: true, canRegister: true }
    expect(deviceStep(draft({ device: { match: null, guess: { name: 'Corsa', serial: 'mmm0099' }, alternatives: [] } }), base)).toEqual({ kind: 'new', device: { name: 'Corsa', serial: 'MMM0099', manufacturer: null } })
    expect(deviceStep(draft({ device: { match: null, guess: { name: 'Super Classic' }, alternatives: [{ id: 'd1', name: 'Classic 1.0' }] } }), base)).toMatchObject({ kind: 'ask', label: 'Super Classic' })
    expect(deviceStep(draft({ device: { match: { id: 'd1', name: 'Corsa' }, guess: null, alternatives: [] } }), { ...base, devices: [{ id: 'd1' }] }).kind).toBe('none')
    expect(deviceStep(draft({ device: { match: null, guess: { serial: 'ABC1234' }, alternatives: [] } }), { ...base, canRegister: false })).toMatchObject({ kind: 'ask', label: 'ABC1234' })
    expect(newDeviceOf({ serial: ' abc1d23 ' })).toEqual({ name: 'ABC1D23', serial: 'ABC1D23', manufacturer: null })
  })

  it('a change names its line or asks between the candidates', () => {
    const sent = { services: ['Pintura capô', 'Pintura porta'], products: ['Óleo'] }
    expect(changeTarget({ action: 'update', line: { kind: 'product', index: 0 }, candidates: [], name: 'Óleo', value: 50 }, sent)).toEqual({ line: 'Óleo', candidates: [] })
    expect(changeTarget({ action: 'update', line: null, candidates: [{ kind: 'service', index: 0 }, { kind: 'service', index: 1 }, { kind: 'service', index: 9 }], name: 'Pintura' }, sent)).toEqual({ line: null, candidates: ['Pintura capô', 'Pintura porta'] })
  })

  it('date, note and uses left as the app', () => {
    expect(dueFromDraft('2026-11-06')).toBe('2026-11-06T18:00')
    expect(dueFromDraft('2026-11-06T09:30')).toBe('2026-11-06T09:30')
    expect(dueFromDraft('sexta')).toBe('')
    expect(noteKey({ filled: false, hasActions: false, isNew: true, onlyChanges: false })).toBe('orderAssistantNothingFound')
    expect(noteKey({ filled: false, hasActions: true, isNew: false, onlyChanges: false })).toBeNull()
    expect(noteKey({ filled: true, hasActions: true, isNew: true, onlyChanges: false })).toBe('aiActionsAfterSave')
    expect(noteKey({ filled: true, hasActions: false, isNew: false, onlyChanges: true })).toBe('orderAssistantChanged')
    expect(noteKey({ filled: true, hasActions: false, isNew: true, onlyChanges: false })).toBe('orderAssistantFilled')
    expect(usesLeft({ used: 79, limit: 100 })).toBeNull()
    expect(usesLeft({ used: 85, limit: 100 })).toBe(15)
    expect(usesLeft({ used: 5, limit: -1 })).toBeNull()
  })
})

describe('order.device-picker', () => {
  const all = ['d1', 'd2', 'd3']
  it('Geral clears the devices, a device clears Geral, all toggles', () => {
    let s = toggleDevice(emptyPick(), 'd1')
    expect(canConfirm(emptyPick())).toBe(false)
    expect(pickResult(s, all)).toEqual({ kind: 'specific', deviceId: 'd1' })
    s = toggleGeneral(s)
    expect(s).toEqual({ general: true, ids: [] })
    expect(pickResult(s, all)).toEqual({ kind: 'general' })
    s = toggleAll(s, all)
    expect(pickResult(s, all)).toEqual({ kind: 'all' })
    expect(toggleAll(s, all).ids).toEqual([])
    s = toggleDevice(toggleDevice(emptyPick(), 'd3'), 'd1')
    expect(pickResult(s, all)).toEqual({ kind: 'multiSpecific', deviceIds: ['d1', 'd3'] })
    expect(deviceIdsOf({ kind: 'all' }, all)).toEqual(all)
    expect(deviceIdsOf({ kind: 'general' }, all)).toEqual([null])
  })
})

describe('customer.picker.choose', () => {
  const list = [
    { id: 'a', name: 'Ana Souza', phone: '(48) 99999-0000' },
    { id: 'b', name: 'Ana Souza', phone: '(48) 98888-1111' },
    { id: 'c', name: 'Bruno', phone: null },
    { id: 'd', name: 'Carla', phone: '(48) 97777-2222' },
  ]
  it('by id, then by name and phone, then a single name; in doubt no ✓', () => {
    expect(currentCustomerId({ id: 'c', name: 'x' }, list)).toBe('c')
    expect(currentCustomerId({ name: ' ana  souza ', phone: '48999990000' }, list)).toBe('a')
    expect(currentCustomerId({ name: 'Ana Souza' }, list)).toBeNull()
    expect(currentCustomerId({ name: 'Ana Souza', phone: '48 3333-3333' }, list)).toBeNull()
    expect(currentCustomerId({ id: 'gone', name: 'bruno', phone: '48 3333-3333' }, list)).toBe('c')
    expect(currentCustomerId({ name: 'Carla', phone: '48 3333-3333' }, list)).toBeNull()
    expect(currentCustomerId(null, list)).toBeNull()
  })
})
