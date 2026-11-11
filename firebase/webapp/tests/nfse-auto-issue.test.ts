// Automatic nota of the NFS-e direct (issue #571): "Emitida sozinha", the
// reason of one that did not go out, and "Tentar novamente" (one click, the
// same nota the server would make). The nfseApi is a fake.
import { flushPromises, mount } from '@vue/test-utils'
import { beforeAll, beforeEach, describe, expect, test, vi } from 'vitest'
import { setLocale } from '../src/i18n'

const { nfseApi, watchInvoicesOf } = vi.hoisted(() => ({ nfseApi: vi.fn(), watchInvoicesOf: vi.fn() }))
vi.mock('../src/lib/session', () => ({
  nfseApi: (...args: unknown[]) => nfseApi(...args),
  api: vi.fn(),
  can: () => true,
  session: { companyId: 'c1', role: 'owner' },
}))
vi.mock('../src/lib/firebase', () => ({ firestoreClient: vi.fn(), firestoreLite: vi.fn(), storageClient: vi.fn() }))
vi.mock('../src/lib/nfse/data', () => ({ watchInvoicesOf: (...args: unknown[]) => watchInvoicesOf(...args) }))

import OrderNfse from '../src/components/finance/OrderNfse.vue'
import { retryAutoIssue } from '../src/lib/nfse/direct-issue'
import { canRetryAuto, invoiceOf, isAutoDirectFailure, nfseNextStep } from '../src/lib/nfse/model'
import { autoFailureReason, invoiceStatusText } from '../src/lib/nfse/text'

const nota = (data: Record<string, unknown>) =>
  invoiceOf('auto-o1', { provider: 'direct', orderIds: ['o1'], createdAt: new Date(Date.now() - 1000).toISOString(), ...data })
const failed = (errorCode: string, extra: Record<string, unknown> = {}) => nota({ status: 'error', auto: true, errorCode, ...extra })
const doneOrder = { status: 'done', discount: 0, lines: [{ kind: 'service' as const, value: 100 }] }

beforeAll(async () => {
  await setLocale('pt')
})
beforeEach(() => {
  nfseApi.mockReset()
  watchInvoicesOf.mockReset()
})

describe('status words', () => {
  test('issued by itself: "Emitida sozinha", with the number when there is one', () => {
    expect(invoiceStatusText(nota({ status: 'authorized', auto: true, number: '29' }), '2026-11-06')).toBe('Emitida sozinha · nº 29')
    expect(invoiceStatusText(nota({ status: 'authorized', auto: true }), '2026-11-06')).toBe('Emitida sozinha')
    expect(invoiceStatusText(nota({ status: 'authorized', number: '30' }), '2026-11-06')).toBe('Emitida · nº 30')
  })

  test('did not go out: the short reason on the row', () => {
    expect(invoiceStatusText(failed('RECIPIENT_TAX_ID_REQUIRED'), '2026-11-06')).toBe('Falta o CPF ou CNPJ do cliente')
    expect(invoiceStatusText(failed('CERT_EXPIRED'), '2026-11-06')).toBe('Certificado vencido')
    expect(invoiceStatusText(failed('DAILY_LIMIT_REACHED'), '2026-11-06')).toBe('Limite de notas de hoje')
    expect(invoiceStatusText(failed('AUTO_ISSUE_FAILED'), '2026-11-06')).toBe('Não saiu sozinha')
  })

  test('a refusal of the government keeps its own words, not ours', () => {
    const refused = failed('E0312', { refusal: { code: 'E0312', group: 'emitterSetup', message: { pt: 'x' } } })
    expect(isAutoDirectFailure(refused)).toBe(false)
    expect(canRetryAuto(refused)).toBe(false)
  })

  test('full reason on the panel', () => {
    expect(autoFailureReason('DAILY_LIMIT_REACHED')).toContain('limite de notas de hoje')
    expect(autoFailureReason('EMITTER_NOT_FOUND')).toContain('CNPJ padrão')
  })
})

describe('one-click retry', () => {
  test('retry for what a new try may fix; the dialog for missing customer data', () => {
    expect(canRetryAuto(failed('DAILY_LIMIT_REACHED'))).toBe(true)
    expect(canRetryAuto(failed('CERT_EXPIRED'))).toBe(true)
    expect(canRetryAuto(failed('RECIPIENT_TAX_ID_REQUIRED'))).toBe(false)
    // An Asaas automatic nota is not this one.
    expect(canRetryAuto(invoiceOf('a', { status: 'error', auto: true, errorCode: 'TAX_ID_REQUIRED', orderIds: ['o1'] }))).toBe(false)
  })

  test('blue step of the order: "Tentar novamente" (retry) or "Corrigir e emitir" (fix)', () => {
    expect(nfseNextStep(doneOrder, failed('DAILY_LIMIT_REACHED'), true, 0)).toBe('retry')
    expect(nfseNextStep(doneOrder, failed('RECIPIENT_TAX_ID_REQUIRED'), true, 0)).toBe('fix')
  })

  test('sends only the order: the server uses the default emitter, the description and the value', async () => {
    nfseApi.mockResolvedValue({ id: 'n1', status: 'authorized', number: '31' })
    await retryAutoIssue(['o1'])
    expect(nfseApi).toHaveBeenCalledWith('/v1/app/nfse/direct/invoices', { method: 'POST', body: { orderIds: ['o1'] } })
  })
})

describe('the order row', () => {
  test('"Nota fiscal · Emitida sozinha · nº 29"', async () => {
    watchInvoicesOf.mockImplementation(async (_query: unknown, onList: (list: unknown[]) => void) => {
      onList([nota({ status: 'authorized', auto: true, number: '29' })])
      return () => undefined
    })
    const wrapper = mount(OrderNfse, {
      props: { order: { id: 'o1', ...doneOrder } as never, ready: true, remaining: 0, direct: true },
      global: { stubs: { RouterLink: { template: '<a><slot /></a>' } } },
    })
    await flushPromises()
    expect(wrapper.get('[data-testid="order-nfse"]').text()).toContain('Emitida sozinha · nº 29')
  })
})
