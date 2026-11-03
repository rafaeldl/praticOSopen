// Charges of an order and settings/payments come from Firestore. A read that
// fails once (emulator or network under load) must not read as "no charge":
// the consultant would see Receber in blue and no open link (CI of #520, R4).
import { afterEach, describe, expect, it, vi } from 'vitest'

const listeners: { next: (snap: unknown) => void; error: (e: unknown) => void; stopped: boolean }[] = []
let settingsFailures = 0

vi.mock('../src/lib/firebase', () => ({ firestoreClient: vi.fn(async () => ({})) }))
vi.mock('firebase/firestore', () => ({
  collection: vi.fn(() => ({})),
  doc: vi.fn(() => ({})),
  onSnapshot: vi.fn((_ref: unknown, next: (snap: unknown) => void, error: (e: unknown) => void) => {
    const entry = { next, error, stopped: false }
    listeners.push(entry)
    return () => (entry.stopped = true)
  }),
  getDoc: vi.fn(async () => {
    if (settingsFailures-- > 0) throw new Error('unavailable')
    return { data: () => ({ asaasEnabled: true, asaasConnected: true }) }
  }),
}))

import { paymentSettings, watchOrderCharges } from '../src/lib/receive/data'

const snapOf = (ids: string[]) => ({ docs: ids.map((id) => ({ id, data: () => ({ status: 'pending', value: 60, dueDate: '2099-01-01', mode: 'single' }) })) })

afterEach(() => {
  listeners.length = 0
  settingsFailures = 0
  vi.useRealTimers()
})

describe('leituras do Receber que falham uma vez', () => {
  it('cobranças: um erro passageiro tenta de novo em vez de mostrar "sem cobrança"', async () => {
    vi.useFakeTimers()
    const seen: string[][] = []
    const stop = await watchOrderCharges('o1', (list) => seen.push(list.map((c) => c.id)), { retries: 2, wait: 100 })
    listeners[0]!.error(new Error('unavailable'))
    expect(seen).toEqual([])
    await vi.advanceTimersByTimeAsync(100)
    expect(listeners).toHaveLength(2)
    listeners[1]!.next(snapOf(['open1']))
    expect(seen).toEqual([['open1']])
    stop()
    expect(listeners[1]!.stopped).toBe(true)
  })

  it('cobranças: depois das novas tentativas, a lista vazia (a tela some com a seção, como o app)', async () => {
    vi.useFakeTimers()
    const seen: string[][] = []
    await watchOrderCharges('o1', (list) => seen.push(list.map((c) => c.id)), { retries: 1, wait: 100 })
    listeners[0]!.error(new Error('x'))
    await vi.advanceTimersByTimeAsync(100)
    listeners[1]!.error(new Error('x'))
    expect(seen).toEqual([[]])
  })

  it('cobranças: parar durante a espera não abre outra leitura', async () => {
    vi.useFakeTimers()
    const stop = await watchOrderCharges('o1', () => undefined, { retries: 2, wait: 100 })
    listeners[0]!.error(new Error('x'))
    stop()
    await vi.advanceTimersByTimeAsync(500)
    expect(listeners).toHaveLength(1)
  })

  it('settings/payments: uma falha passageira não desliga a cobrança', async () => {
    settingsFailures = 1
    expect(await paymentSettings({ wait: 0 })).toEqual({ ready: true })
  })
})
