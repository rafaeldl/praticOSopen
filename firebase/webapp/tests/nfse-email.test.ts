// The nota by e-mail in the web (issue #611): the panel's "E-mail ao cliente"
// line with "Enviar de novo", the sheet's sentence and the company option.
// The nfseApi is a fake: no e-mail leaves.
import { flushPromises, mount } from '@vue/test-utils'
import { beforeAll, beforeEach, describe, expect, test, vi } from 'vitest'
import { setLocale } from '../src/i18n'

const { nfseApi, toasts } = vi.hoisted(() => ({ nfseApi: vi.fn(), toasts: [] as string[] }))
vi.mock('../src/lib/session', () => ({
  nfseApi: (...args: unknown[]) => nfseApi(...args),
  api: vi.fn(),
  can: () => true,
  session: { companyId: 'c1', role: 'owner' },
}))
vi.mock('../src/lib/firebase', () => ({ firestoreClient: vi.fn(), firestoreLite: vi.fn(), storageClient: vi.fn() }))
vi.mock('../src/lib/toast', () => ({ showToast: (text: string) => toasts.push(text) }))

import InvoiceEmailFact from '../src/components/finance/InvoiceEmailFact.vue'
import { emailDeliveryText, emailLine, type DirectPreview } from '../src/lib/nfse/direct-issue'
import { settingsOf } from '../src/lib/nfse/direct'
import { emailDeliveryOf, invoiceOf } from '../src/lib/nfse/model'

const AT = '2026-11-05T13:00:00.000Z'
const nota = (extra: Record<string, unknown> = {}) =>
  invoiceOf('nf1', { provider: 'direct', status: 'authorized', number: '29', value: 270, xmlPath: 'tenants/c1/invoices/nf1/nfse.xml', ...extra })

beforeAll(async () => {
  await setLocale('pt')
})
beforeEach(() => {
  nfseApi.mockReset()
  toasts.length = 0
})

describe('e-mail delivery text (same words as the app)', () => {
  test('sent, cancellation notice, failed, skipped, never', () => {
    expect(emailDeliveryText(emailDeliveryOf({ status: 'sent', kind: 'issued', to: 'nota@example.com', at: AT }), 'BR')).toBe(
      'Enviada para nota@example.com em 05/11/2026',
    )
    expect(emailDeliveryText(emailDeliveryOf({ status: 'sent', kind: 'canceled', to: 'nota@example.com', at: AT }), 'BR')).toBe(
      'Aviso de cancelamento enviado para nota@example.com em 05/11/2026',
    )
    expect(emailDeliveryText(emailDeliveryOf({ status: 'failed', kind: 'issued', to: 'nota@example.com', at: AT }), 'BR')).toBe(
      'Não deu para mandar para nota@example.com em 05/11/2026',
    )
    expect(emailDeliveryText(emailDeliveryOf({ status: 'skipped', kind: 'issued', at: AT, reason: 'turnedOff' }), 'BR')).toBe(
      'Não foi: o envio automático está desligado',
    )
    expect(emailDeliveryText(null, 'BR')).toBe('Ainda não foi por e-mail')
    expect(emailDeliveryOf({ status: 'weird' })).toBeNull()
  })

  test('the sheet says where the nota goes, or that it does not', () => {
    const preview = { recipient: { email: 'nota@example.com' }, emailToCustomer: true } as unknown as DirectPreview
    expect(emailLine(preview, [])).toBe('A nota vai por e-mail para nota@example.com.')
    expect(emailLine(preview, ['email'])).toBeNull()
    expect(emailLine({ ...preview, emailToCustomer: false }, [])).toBe('A nota não vai por e-mail: o envio automático está desligado.')
  })

  test('the company option reads as on unless turned off', () => {
    expect(settingsOf(undefined).emailToCustomer).toBe(true)
    expect(settingsOf({ emailToCustomer: false }).emailToCustomer).toBe(false)
  })
})

describe('InvoiceEmailFact', () => {
  test('failed: says so; "Enviar de novo" sends now and shows the result', async () => {
    nfseApi.mockResolvedValue({ emailDelivery: { status: 'sent', kind: 'issued', to: 'nota@example.com', at: AT, manual: true } })
    const wrapper = mount(InvoiceEmailFact, {
      props: { invoice: nota({ emailDelivery: { status: 'failed', kind: 'issued', to: 'nota@example.com', at: AT } }) },
    })
    expect(wrapper.get('[data-testid="nfse-email-text"]').text()).toBe('Não deu para mandar para nota@example.com em 05/11/2026')
    expect(wrapper.get('[data-testid="nfse-email-send"]').text()).toBe('Enviar de novo')
    await wrapper.get('[data-testid="nfse-email-send"]').trigger('click')
    await flushPromises()
    expect(nfseApi).toHaveBeenCalledWith('/v1/app/nfse/direct/invoices/nf1/email', { method: 'POST', body: {} })
    expect(wrapper.get('[data-testid="nfse-email-text"]').text()).toBe('Enviada para nota@example.com em 05/11/2026')
    expect(toasts).toEqual(['Nota enviada para nota@example.com'])
  })

  test('the customer has no e-mail: the toast says what to do', async () => {
    nfseApi.mockResolvedValue({ emailDelivery: { status: 'skipped', kind: 'issued', at: AT, reason: 'noEmail' } })
    const wrapper = mount(InvoiceEmailFact, { props: { invoice: nota() } })
    expect(wrapper.get('[data-testid="nfse-email-send"]').text()).toBe('Enviar')
    await wrapper.get('[data-testid="nfse-email-send"]').trigger('click')
    await flushPromises()
    expect(toasts).toEqual(['O cliente não tem e-mail. Coloque o e-mail no cadastro dele e envie de novo.'])
  })

  test('not before the nota is issued, nor on an Asaas nota', () => {
    expect(mount(InvoiceEmailFact, { props: { invoice: nota({ status: 'creating', xmlPath: null }) } }).find('[data-testid="nfse-email"]').exists()).toBe(false)
    expect(mount(InvoiceEmailFact, { props: { invoice: nota({ provider: 'asaas' }) } }).find('[data-testid="nfse-email"]').exists()).toBe(false)
  })
})
