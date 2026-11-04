// Charges of an order and settings/payments come from Firestore. A read that
// fails once (emulator or network under load) must not read as "no charge":
// the consultant would see Receber in blue and no open link (CI of #520, R4).
import { afterEach, describe, expect, it, vi } from 'vitest'

const listeners: { next: (snap: unknown) => void; error: (e: unknown) => void; stopped: boolean }[] = []
let settingsFailures = 0

const liteGetDocs = vi.fn(async () => snapOf(['open1']))
vi.mock('../src/lib/firebase', () => ({ firestoreClient: vi.fn(async () => ({})), firestoreLite: vi.fn(async () => ({})) }))
// One-off reads go through the REST build: the full client's getDoc waits on the live channel, which can stall.
vi.mock('firebase/firestore/lite', () => ({
  collection: vi.fn(() => ({})),
  doc: vi.fn(() => ({})),
  getDocs: (...args: unknown[]) => liteGetDocs(...(args as [])),
  getDoc: vi.fn(async () => {
    if (settingsFailures-- > 0) throw new Error('unavailable')
    return { data: () => ({ asaasEnabled: true, asaasConnected: true }) }
  }),
}))
vi.mock('firebase/firestore', () => ({
  collection: vi.fn(() => ({})),
  doc: vi.fn(() => ({})),
  onSnapshot: vi.fn((_ref: unknown, next: (snap: unknown) => void, error: (e: unknown) => void) => {
    const entry = { next, error, stopped: false }
    listeners.push(entry)
    return () => (entry.stopped = true)
  }),
  getDoc: vi.fn(async () => new Promise(() => {})),
}))

import { paymentSettings, watchOrderCharges } from '../src/lib/receive/data'

function snapOf(ids: string[]) {
  return { docs: ids.map((id) => ({ id, data: () => ({ status: 'pending', value: 60, dueDate: '2099-01-01', mode: 'single' }) })) }
}

afterEach(() => {
  listeners.length = 0
  settingsFailures = 0
  vi.useRealTimers()
})

describe('canal ao vivo travado (CI do #521, R4)', () => {
  it('cobranças: a cópia vazia do disco não é "sem cobrança"; sem resposta do canal, lê uma vez pelo REST', async () => {
    vi.useFakeTimers()
    const seen: string[][] = []
    await watchOrderCharges('o1', (list) => seen.push(list.map((c) => c.id)))
    listeners[0]!.next({ docs: [], metadata: { fromCache: true } })
    expect(seen).toEqual([])
    await vi.advanceTimersByTimeAsync(4000)
    expect(seen).toEqual([['open1']])
    // The channel answering later still updates.
    listeners[0]!.next({ ...snapOf([]), metadata: { fromCache: false } })
    expect(seen).toEqual([['open1'], []])
  })

  it('cobranças: canal calado e leitura REST com erro dão erro, nunca lista vazia', async () => {
    vi.useFakeTimers()
    liteGetDocs.mockRejectedValueOnce(new Error('unavailable'))
    const seen: string[][] = []
    let failed = 0
    await watchOrderCharges('o1', (list) => seen.push(list.map((c) => c.id)), { onFailed: () => failed++ })
    await vi.advanceTimersByTimeAsync(4000)
    expect(seen).toEqual([])
    expect(failed).toBe(1)
  })

  it('cobranças: a cópia do disco com dados aparece na hora, mas a leitura REST só para com a resposta do servidor', async () => {
    vi.useFakeTimers()
    liteGetDocs.mockClear()
    const seen: string[][] = []
    await watchOrderCharges('o1', (list) => seen.push(list.map((c) => c.id)))
    listeners[0]!.next({ ...snapOf(['cached']), metadata: { fromCache: true } })
    expect(seen).toEqual([['cached']])
    await vi.advanceTimersByTimeAsync(4000)
    expect(liteGetDocs).toHaveBeenCalledTimes(1)
    expect(seen).toEqual([['cached'], ['open1']])
  })

  it('cobranças: resposta do servidor antes do prazo cancela a leitura REST', async () => {
    vi.useFakeTimers()
    liteGetDocs.mockClear()
    await watchOrderCharges('o1', () => undefined)
    listeners[0]!.next({ ...snapOf([]), metadata: { fromCache: false } })
    await vi.advanceTimersByTimeAsync(4000)
    expect(liteGetDocs).not.toHaveBeenCalled()
  })

  it('settings/payments não espera o canal (o getDoc do cliente completo fica preso nele)', async () => {
    expect(await paymentSettings({ wait: 0 })).toEqual({ ready: true, nfse: false, nfseReady: false })
  })
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

  it('cobranças: depois das novas tentativas, erro e nunca lista vazia (M1 do #518)', async () => {
    vi.useFakeTimers()
    const seen: string[][] = []
    let failed = 0
    await watchOrderCharges('o1', (list) => seen.push(list.map((c) => c.id)), { retries: 1, wait: 100, onFailed: () => failed++ })
    listeners[0]!.error(new Error('x'))
    await vi.advanceTimersByTimeAsync(100)
    listeners[1]!.error(new Error('x'))
    expect(seen).toEqual([])
    expect(failed).toBe(1)
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
    expect(await paymentSettings({ wait: 0 })).toEqual({ ready: true, nfse: false, nfseReady: false })
  })
})
