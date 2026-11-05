// NFS-e direct in the web (issue #566): the issue sheet, the list's tag and
// filter, and canceling with the reason. The nfseApi and Firestore are fakes.
import { mount } from '@vue/test-utils'
import { afterEach, beforeAll, beforeEach, describe, expect, test, vi } from 'vitest'
import { defineComponent, h, nextTick } from 'vue'
import { createMemoryHistory, createRouter } from 'vue-router'
import { setLocale, t } from '../src/i18n'
import { ApiError } from '../src/lib/api'

const { nfseApi, session, listed } = vi.hoisted(() => ({
  nfseApi: vi.fn(),
  session: { companyId: 'c1', role: 'owner' as string },
  listed: { invoices: [] as Record<string, unknown>[] },
}))
vi.mock('../src/lib/session', () => ({
  nfseApi: (...args: unknown[]) => nfseApi(...args),
  api: vi.fn(),
  can: () => true,
  session,
}))
vi.mock('../src/lib/firebase', () => ({ firestoreClient: vi.fn(), firestoreLite: vi.fn(async () => ({})), storageClient: vi.fn() }))
// The company's CNPJs read when the server cannot mark one: none here.
vi.mock('firebase/firestore/lite', () => ({ collection: vi.fn(), getDocs: vi.fn(async () => ({ docs: [] })) }))
vi.mock('../src/lib/customers/data', () => ({
  loadCustomerDirectory: async () => ({
    rows: [
      { id: 'cust1', name: 'Loja Centro', taxId: null },
      { id: 'rev', name: 'Revenda Exemplo', taxId: '11222333000181' },
    ],
    truncated: false,
    partial: false,
  }),
}))
vi.mock('../src/lib/nfse/data', () => ({
  nfseSettings: async () => ({ available: true, ready: true, direct: true }),
  monthInvoices: async () => {
    const { invoiceOf } = await vi.importActual<typeof import('../src/lib/nfse/model')>('../src/lib/nfse/model')
    return listed.invoices.map((d) => invoiceOf(d.id as string, d))
  },
  customerInvoices: async () => [],
  cancelInvoice: vi.fn(),
}))

import DirectIssueDialog from '../src/components/finance/DirectIssueDialog.vue'
import InvoicesView from '../src/views/finance/InvoicesView.vue'
import {
  addressComplete,
  cancelFailureText,
  directBlocker,
  directFailure,
  fillAddress,
  lookupPostalCode,
  meiWarningText,
  recipientInput,
  type DirectForm,
  type DirectPreview,
} from '../src/lib/nfse/direct-issue'
import { byEmitter, canCancel, canReconcile, emittersOf, invoiceOf, isActive, refusalMessage, refusalOf } from '../src/lib/nfse/model'

beforeAll(() => setLocale('pt'))

const flush = async () => {
  for (let i = 0; i < 8; i++) {
    await nextTick()
    await new Promise((resolve) => setTimeout(resolve, 0))
  }
}

const emitterA = { id: 'ea', legalName: 'OFICINA EXEMPLO LTDA', taxId: '11222333000181', regime: 'simples', problem: null, isDefault: true, serviceName: 'Conserto' }
const emitterB = { id: 'eb', legalName: 'JOAO MEI', taxId: '45723174000110', regime: 'mei', problem: null, isDefault: false, serviceName: 'Conserto' }
const address = { postalCode: '89010000', street: 'Rua A', number: '10', complement: null, district: 'Centro', cityCode: '4202404', cityName: 'Blumenau', state: 'SC' }

function previewOf(over: Partial<DirectPreview> = {}): DirectPreview {
  return {
    value: 300,
    orders: [{ orderId: 'o1', orderNumber: 182, value: 300, servicesTotal: 300, productsTotal: 120, discount: 0 }],
    hasProducts: true,
    description: 'Troca de óleo, Alinhamento',
    complementaryInfo: 'OS 182 · Emitida pelo PraticOS (praticos.app)',
    emitter: emitterA,
    emitters: [emitterA, emitterB],
    customer: { id: 'cust1', name: 'Loja Centro' },
    recipient: { customerId: 'rev', name: 'Revenda', legalName: 'REVENDA EXEMPLO LTDA', taxId: '11222333000181', address, email: 'nota@revenda.com', viaInvoiceRecipient: true },
    missing: [],
    meiWarning: 'none',
    invoicedOrders: {},
    ...over,
  }
}

const form = (over: Partial<DirectForm> = {}): DirectForm => ({ asking: [], taxId: '', email: '', address: {}, ...over })

describe('folha da nota direta: regras', () => {
  test('o que deixa "Emitir" cinza, primeiro o primeiro motivo', () => {
    expect(directBlocker(previewOf(), form())).toBeNull()
    expect(directBlocker(previewOf({ invoicedOrders: { o1: 'n1' } }), form())).toEqual({ kind: 'invoiced', numbers: '182' })
    expect(directBlocker(previewOf({ value: 0 }), form())).toEqual({ kind: 'zero' })
    expect(directBlocker(previewOf({ emitter: { ...emitterA, problem: 'certificateExpired' } }), form())).toEqual({ kind: 'emitter', problem: 'certificateExpired' })
    expect(directBlocker(previewOf(), form({ asking: ['taxId'], taxId: '123' }))).toEqual({ kind: 'taxId' })
    expect(directBlocker(previewOf(), form({ asking: ['taxId'], taxId: '11.222.333/0001-81' }))).toBeNull()
    expect(directBlocker(previewOf(), form({ asking: ['address'], address: { ...address, cityCode: '' } }))).toEqual({ kind: 'address' })
    expect(directBlocker(previewOf(), form({ asking: ['email'], email: 'x' }))).toEqual({ kind: 'email' })
  })

  test('endereço completo pede CEP, rua, número, bairro, código IBGE e UF', () => {
    expect(addressComplete(address)).toBe(true)
    expect(addressComplete({ ...address, number: ' ' })).toBe(false)
    expect(addressComplete({ ...address, state: 'S' })).toBe(false)
  })

  test('o pedido leva só o que foi pedido, e o outro cliente desta nota', () => {
    expect(recipientInput(form(), null)).toBeNull()
    expect(recipientInput(form(), 'rev')).toEqual({ customerId: 'rev' })
    const sent = recipientInput(form({ asking: ['taxId', 'address', 'email'], taxId: '529.982.247-25', email: ' a@b.co ', address: { ...address, postalCode: '89010-000', state: 'sc' } }), null)
    expect(sent?.taxId).toBe('52998224725')
    expect(sent?.email).toBe('a@b.co')
    expect(sent?.address).toMatchObject({ postalCode: '89010000', state: 'SC', cityCode: '4202404' })
  })

  test('CEP pelo ViaCEP traz o código IBGE e não passa por cima do digitado', async () => {
    const fetcher = vi.fn(async () => new Response(JSON.stringify({ logradouro: 'Rua XV', bairro: 'Centro', localidade: 'Blumenau', uf: 'SC', ibge: '4202404' })))
    const found = await lookupPostalCode('89010-000', fetcher as unknown as typeof fetch)
    expect(fetcher).toHaveBeenCalledWith('https://viacep.com.br/ws/89010000/json/')
    expect(found?.cityCode).toBe('4202404')
    expect(fillAddress({ street: 'Minha rua', number: '5' }, found!)).toMatchObject({ street: 'Minha rua', number: '5', district: 'Centro', cityCode: '4202404', state: 'SC' })
    expect(await lookupPostalCode('123')).toBeNull()
    const missing = vi.fn(async () => new Response(JSON.stringify({ erro: true })))
    expect(await lookupPostalCode('00000000', missing as unknown as typeof fetch)).toBeNull()
  })

  test('aviso do MEI sem bloquear', () => {
    expect(meiWarningText('none')).toBeNull()
    expect(meiWarningText('near')).toBe('Com esta nota, o MEI passa de 80% do teto do ano.')
    expect(meiWarningText('over')).toBe('Com esta nota, o MEI passa do teto do ano. Fale com o seu contador.')
  })

  const refused = (group: string, message = { pt: 'Falta o endereço do cliente.', en: 'Customer address missing.' }) =>
    new ApiError('NFSE_REFUSED', 422, 'web.error.validation', undefined, { refusal: { code: 'E0001', group, message, govText: 'texto do governo' }, invoiceId: 'n9' })

  test('recusa por grupo: dados do cliente abrem os campos; configuração e certificado, a configuração; outro, o texto', () => {
    expect(directFailure(refused('customerData'), 'pt')).toMatchObject({ text: 'Falta o endereço do cliente.', fields: true })
    expect(directFailure(refused('customerData'), 'en').text).toBe('Customer address missing.')
    expect(directFailure(refused('customerData'), 'es').text).toBe('Falta o endereço do cliente.')
    expect(directFailure(refused('emitterSetup'), 'pt')).toMatchObject({ setup: true })
    expect(directFailure(refused('certificate'), 'pt')).toMatchObject({ setup: true })
    const other = directFailure(refused('other', { pt: 'Algo novo.' } as never), 'pt')
    expect(other.text).toBe('O governo recusou a nota: Algo novo.')
    expect(other.detail).toBe('texto do governo')
  })

  test('outros erros em frase simples', () => {
    const err = (code: string, status: number, details?: Record<string, unknown>) => new ApiError(code, status, 'web.error.generic', undefined, details)
    expect(directFailure(err('EMITTER_NOT_READY', 409, { problem: 'notEnabledInCity' }), 'pt')).toMatchObject({ text: t('web.nfseDirect.problem.notEnabledInCity'), setup: true })
    expect(directFailure(err('CERT_EXPIRED', 400), 'pt').text).toBe(t('web.nfseDirect.problem.certificateExpired'))
    expect(directFailure(err('RECIPIENT_TAX_ID_REQUIRED', 400), 'pt')).toMatchObject({ fields: true })
    expect(directFailure(err('ORDER_HAS_INVOICE', 409), 'pt').text).toBe(t('web.nfseDirect.orderHasInvoice'))
    expect(directFailure(err('SEFIN_UNAVAILABLE', 503), 'pt').text).toBe(t('web.nfseDirect.govUnavailable'))
  })

  test('cancelamento recusado pela cidade manda ao portal', () => {
    const error = new ApiError('CANCEL_REFUSED', 422, 'web.error.validation', undefined, { usePortal: true, refusal: { group: 'other', message: { pt: 'x' } } })
    expect(cancelFailureText(error, 'pt')).toBe('A cidade não aceitou o cancelamento por aqui. Cancele no portal do governo (nfse.gov.br).')
  })
})

describe('nota direta no modelo e na lista', () => {
  const now = Date.parse('2026-11-05T12:00:00Z')
  const direct = (id: string, over: Record<string, unknown> = {}) =>
    invoiceOf(id, {
      status: 'authorized',
      provider: 'direct',
      source: 'praticos',
      emitter: { id: 'ea', taxId: '11222333000181', legalName: 'OFICINA EXEMPLO LTDA', regime: 'simples' },
      recipient: { customerId: 'rev', taxId: '11222333000181', legalName: 'REVENDA EXEMPLO LTDA' },
      accessKey: '42024042211222333000181000000000002926110000000001',
      xmlPath: 'tenants/c1/invoices/x/nfse.xml',
      customer: { id: 'cust1', name: 'Loja Centro' },
      orderIds: ['o1'],
      value: 300,
      effectiveDate: '2026-11-05',
      ...over,
    })

  test('lê os campos da nota direta', () => {
    const invoice = direct('n1', { source: 'external', refusal: { code: 'E0312', group: 'emitterSetup', message: { pt: 'Serviço fora da lista da cidade.' } } })
    expect(invoice.provider).toBe('direct')
    expect(invoice.source).toBe('external')
    expect(invoice.emitter?.legalName).toBe('OFICINA EXEMPLO LTDA')
    expect(invoice.recipient?.legalName).toBe('REVENDA EXEMPLO LTDA')
    expect(invoice.refusal?.group).toBe('emitterSetup')
    expect(refusalMessage(invoice.refusal!, 'en')).toBe('Serviço fora da lista da cidade.')
    expect(invoiceOf('a', { status: 'authorized' }).provider).toBe('asaas')
    expect(refusalOf({ group: 'nope' })?.group).toBe('other')
  })

  test('direta "creating" segura a OS e pode ser conferida depois de 3 minutos', () => {
    const waiting = direct('n2', { status: 'creating', createdAt: new Date(now - 4 * 60 * 1000).toISOString() })
    expect(isActive({ ...waiting, createdAt: now - 60 * 60 * 1000 }, now)).toBe(true)
    expect(canReconcile(waiting, now)).toBe(true)
    expect(canReconcile({ ...waiting, createdAt: now - 60 * 1000 }, now)).toBe(false)
  })

  test('cancelar só a direta emitida com chave', () => {
    expect(canCancel(direct('n3'))).toBe(true)
    expect(canCancel(direct('n4', { accessKey: null }))).toBe(false)
  })

  test('filtro por emitente só com mais de um', () => {
    const a = direct('n5')
    const b = direct('n6', { emitter: { id: 'eb', taxId: '45723174000110', legalName: 'JOAO MEI', regime: 'mei' } })
    expect(emittersOf([a, direct('n7')])).toEqual([])
    expect(emittersOf([a, b]).map((e) => e.id)).toEqual(['eb', 'ea'])
    expect(byEmitter(a, 'eb')).toBe(false)
    expect(byEmitter(a, null)).toBe(true)
  })
})

// ---------------------------------------------------------------------------
// Components
// ---------------------------------------------------------------------------

async function withRouter(path = '/') {
  const router = createRouter({
    history: createMemoryHistory('/web/'),
    routes: [
      { path: '/', component: { render: () => null } },
      { path: '/invoices', component: { render: () => null } },
      { path: '/invoices/direct', component: { render: () => null } },
      { path: '/invoices/setup', component: { render: () => null } },
    ],
  })
  await router.push(path)
  return router
}

const $ = <T extends Element = HTMLElement>(selector: string) => document.querySelector<T>(selector)
const text = (selector: string) => $(selector)?.textContent?.trim() ?? ''

afterEach(() => {
  document.body.innerHTML = ''
})

describe('DirectIssueDialog', () => {
  beforeEach(() => {
    nfseApi.mockReset()
    session.role = 'owner'
  })

  async function open(preview = previewOf()) {
    nfseApi.mockImplementation(async (path: string) => (path.endsWith('/preview') ? preview : { id: 'n1', status: 'authorized', number: '29' }))
    const router = await withRouter()
    const host = defineComponent({ setup: () => () => h(DirectIssueDialog, { orderIds: ['o1'], customerId: 'cust1' }) })
    const wrapper = mount(host, { global: { plugins: [router] }, attachTo: document.body })
    await flush()
    return { wrapper, router, dialog: wrapper.findComponent(DirectIssueDialog) }
  }

  test('mostra emitente, destinatário do "Nota fiscal para", valor sem peças e a descrição', async () => {
    await open()
    expect(nfseApi).toHaveBeenCalledWith('/v1/app/nfse/direct/invoices/preview', { method: 'POST', body: { orderIds: ['o1'] } })
    expect(text('[data-testid="nfse-emitter"]')).toContain('OFICINA EXEMPLO LTDA · 11.222.333/0001-81')
    expect(text('[data-testid="nfse-recipient-line"]')).toBe('REVENDA EXEMPLO LTDA · CNPJ 11.222.333/0001-81')
    expect(text('[data-testid="nfse-via"]')).toContain('Loja Centro')
    expect($('[data-testid="nfse-products-out"]')).not.toBeNull()
    expect($<HTMLTextAreaElement>('#dx-text')?.value).toBe('Troca de óleo, Alinhamento')
    expect(text('[data-testid="nfse-info"]')).toBe('OS 182 · Emitida pelo PraticOS (praticos.app)')
    expect($('[data-testid="nfse-mei"]')).toBeNull()
  })

  test('aviso do MEI aparece e não bloqueia', async () => {
    await open(previewOf({ meiWarning: 'over' }))
    expect(text('[data-testid="nfse-mei"]')).toBe(t('web.nfseDirect.meiOver'))
    expect($<HTMLButtonElement>('[data-testid="nfse-send"]')?.disabled).toBe(false)
  })

  test('trocar o emitente refaz a prévia com emitterId; emitente com problema não emite', async () => {
    await open()
    nfseApi.mockImplementation(async () => previewOf({ emitter: { ...emitterB, problem: 'certificateExpired' } }))
    $<HTMLButtonElement>('[data-testid="nfse-emitter-change"]')!.click()
    await flush()
    const option = [...document.querySelectorAll<HTMLButtonElement>('button.opt')].find((b) => b.textContent?.includes('JOAO MEI'))
    option!.click()
    await flush()
    expect(nfseApi).toHaveBeenLastCalledWith('/v1/app/nfse/direct/invoices/preview', { method: 'POST', body: { orderIds: ['o1'], emitterId: 'eb' } })
    expect(text('[data-testid="nfse-emitter-problem"]')).toContain(t('web.nfseDirect.problem.certificateExpired'))
    expect($<HTMLButtonElement>('[data-testid="nfse-send"]')?.disabled).toBe(true)
  })

  test('um emitente só: sem "Trocar"', async () => {
    await open(previewOf({ emitters: [emitterA] }))
    expect($('[data-testid="nfse-emitter-change"]')).toBeNull()
  })

  test('trocar o destinatário vale só nesta nota e vai na emissão', async () => {
    await open(previewOf({ recipient: { ...previewOf().recipient, customerId: 'cust1', viaInvoiceRecipient: false } }))
    $<HTMLButtonElement>('[data-testid="nfse-recipient-change"]')!.click()
    await flush()
    const input = $<HTMLInputElement>('#dx-recipient')!
    input.dispatchEvent(new Event('focus'))
    input.value = 'Revenda'
    input.dispatchEvent(new Event('input'))
    await flush()
    const option = [...document.querySelectorAll<HTMLElement>('[role="option"]')].find((o) => o.textContent?.includes('Revenda Exemplo'))
    option!.dispatchEvent(new MouseEvent('mousedown', { bubbles: true }))
    option!.click()
    await flush()
    expect(nfseApi).toHaveBeenLastCalledWith('/v1/app/nfse/direct/invoices/preview', { method: 'POST', body: { orderIds: ['o1'], recipientCustomerId: 'rev' } })
    expect($('[data-testid="nfse-recipient-once"]')).not.toBeNull()
    $<HTMLFormElement>('[data-testid="nfse-direct-issue"]')!.dispatchEvent(new Event('submit'))
    await flush()
    expect(nfseApi).toHaveBeenLastCalledWith('/v1/app/nfse/direct/invoices', {
      method: 'POST',
      body: { orderIds: ['o1'], emitterId: 'ea', recipient: { customerId: 'rev' } },
    })
  })

  test('faltando dados, os campos aparecem e vão na emissão', async () => {
    const { dialog } = await open(previewOf({ missing: ['email'], recipient: { ...previewOf().recipient, email: null } }))
    expect($('#dx-email')).not.toBeNull()
    expect($('#dx-cep')).toBeNull()
    expect($<HTMLButtonElement>('[data-testid="nfse-send"]')?.disabled).toBe(true)
    const email = $<HTMLInputElement>('#dx-email')!
    email.value = 'nota@loja.com'
    email.dispatchEvent(new Event('input'))
    await flush()
    $<HTMLFormElement>('[data-testid="nfse-direct-issue"]')!.dispatchEvent(new Event('submit'))
    await flush()
    expect(nfseApi).toHaveBeenLastCalledWith('/v1/app/nfse/direct/invoices', expect.objectContaining({ body: expect.objectContaining({ recipient: { email: 'nota@loja.com' } }) }))
    expect(dialog.emitted('done')).toBeTruthy()
  })

  test('recusa dos dados do cliente abre todos os campos do "Para"', async () => {
    await open()
    nfseApi.mockImplementation(async (path: string) => {
      if (path.endsWith('/preview')) return previewOf()
      throw new ApiError('NFSE_REFUSED', 422, 'web.error.validation', undefined, { refusal: { code: 'E0100', group: 'customerData', message: { pt: 'O endereço do cliente está errado.' } } })
    })
    $<HTMLFormElement>('[data-testid="nfse-direct-issue"]')!.dispatchEvent(new Event('submit'))
    await flush()
    expect(text('[data-testid="nfse-refusal"]')).toContain('O endereço do cliente está errado.')
    expect($('#dx-taxid')).not.toBeNull()
    expect($('#dx-cep')).not.toBeNull()
    expect($('#dx-email')).not.toBeNull()
  })

  test('recusa de configuração: dono abre a configuração; gerente é avisado', async () => {
    const { router } = await open()
    nfseApi.mockImplementation(async (path: string) => {
      if (path.endsWith('/preview')) return previewOf()
      throw new ApiError('NFSE_REFUSED', 422, 'web.error.validation', undefined, { refusal: { group: 'emitterSetup', message: { pt: 'Falta a inscrição municipal.' } } })
    })
    $<HTMLFormElement>('[data-testid="nfse-direct-issue"]')!.dispatchEvent(new Event('submit'))
    await flush()
    const hint = $('[data-testid="nfse-setup-hint"]')!
    expect(hint.textContent).toContain(t('web.nfseDirect.openSetup'))
    hint.querySelector<HTMLButtonElement>('button')!.click()
    await flush()
    expect(router.currentRoute.value.path).toBe('/invoices/direct')
    expect(router.currentRoute.value.query.e).toBe('ea')
  })

  test('governo sem resposta: avisa que a nota aparece quando ele confirmar', async () => {
    const { dialog } = await open()
    nfseApi.mockImplementation(async (path: string) => (path.endsWith('/preview') ? previewOf() : { id: 'n1', status: 'creating' }))
    $<HTMLFormElement>('[data-testid="nfse-direct-issue"]')!.dispatchEvent(new Event('submit'))
    await flush()
    expect(dialog.emitted('done')).toBeTruthy()
    expect(document.body.textContent ?? '').not.toContain('undefined')
  })

  test('sem CNPJ cadastrado: o gerente é avisado, sem link', async () => {
    session.role = 'manager'
    nfseApi.mockRejectedValue(new ApiError('EMITTER_NOT_FOUND', 404, 'web.error.notFound'))
    const router = await withRouter()
    mount(defineComponent({ setup: () => () => h(DirectIssueDialog, { orderIds: ['o1'] }) }), { global: { plugins: [router] }, attachTo: document.body })
    await flush()
    expect(text('[data-testid="nfse-refusal"]')).toBe(t('web.nfseDirect.noEmitter'))
    expect(text('[data-testid="nfse-setup-hint"]')).toBe(t('web.nfseDirect.setupOther'))
  })
})

describe('InvoicesView com nota direta', () => {
  const doc = (id: string, over: Record<string, unknown> = {}) => ({
    id,
    status: 'authorized',
    provider: 'direct',
    source: 'praticos',
    emitter: { id: 'ea', taxId: '11222333000181', legalName: 'OFICINA EXEMPLO LTDA', regime: 'simples' },
    recipient: { customerId: 'rev', taxId: '11222333000181', legalName: 'REVENDA EXEMPLO LTDA' },
    accessKey: '4202404221122233300018100000000000292611',
    number: '29',
    customer: { id: 'cust1', name: 'Loja Centro' },
    orderIds: ['o1'],
    orders: [{ orderId: 'o1', orderNumber: 182, value: 300 }],
    value: 300,
    effectiveDate: new Date().toISOString().slice(0, 10),
    ...over,
  })

  beforeEach(() => {
    nfseApi.mockReset()
    listed.invoices = [
      doc('n1'),
      doc('n2', { source: 'external', number: '30', emitter: { id: 'eb', taxId: '45723174000110', legalName: 'JOAO MEI', regime: 'mei' } }),
    ]
  })

  async function view(path: string) {
    const router = await withRouter(path)
    const wrapper = mount(InvoicesView, { global: { plugins: [router] }, attachTo: document.body })
    await flush()
    return { wrapper, router }
  }

  test('etiqueta "Emitida fora do PraticOS" e filtro por emitente', async () => {
    const { wrapper, router } = await view('/invoices')
    expect(wrapper.findAll('[data-testid="nfse-row"]')).toHaveLength(2)
    expect(wrapper.findAll('[data-testid="nfse-external"]')).toHaveLength(1)
    const filter = wrapper.get('[data-testid="nfse-emitter-filter"]')
    expect(filter.findAll('option').map((o) => o.text())).toEqual(['Todos os CNPJs', 'JOAO MEI', 'OFICINA EXEMPLO LTDA'])
    await filter.setValue('eb')
    await flush()
    expect(router.currentRoute.value.query.emitter).toBe('eb')
    expect(wrapper.findAll('[data-testid="nfse-row"]')).toHaveLength(1)
    wrapper.unmount()
  })

  test('um emitente só: sem filtro', async () => {
    listed.invoices = [doc('n1')]
    const { wrapper } = await view('/invoices')
    expect(wrapper.find('[data-testid="nfse-emitter-filter"]').exists()).toBe(false)
    wrapper.unmount()
  })

  test('detalhe mostra emitente, destinatário e chave; cancelar pede o motivo', async () => {
    const { wrapper } = await view('/invoices?invoice=n1')
    expect(wrapper.get('[data-testid="nfse-emitter-line"]').text()).toBe('OFICINA EXEMPLO LTDA · 11.222.333/0001-81')
    expect(wrapper.get('[data-testid="nfse-recipient-line"]').text()).toBe('REVENDA EXEMPLO LTDA · 11.222.333/0001-81')
    expect(wrapper.get('[data-testid="nfse-key"]').text()).toBe('4202404221122233300018100000000000292611')
    nfseApi.mockResolvedValue({ status: 'canceled' })
    await wrapper.get('[data-testid="nfse-cancel"]').trigger('click')
    await flush()
    const reasons = [...document.querySelectorAll<HTMLButtonElement>('button.opt')]
    expect(reasons.map((b) => b.textContent?.trim())).toEqual(['Erro na nota', 'Serviço não prestado'])
    reasons[1]!.click()
    await flush()
    expect(nfseApi).toHaveBeenCalledWith('/v1/app/nfse/direct/invoices/n1/cancel', { method: 'POST', body: { reason: 'serviceNotProvided' } })
    wrapper.unmount()
  })

  test('cidade recusa o cancelamento: manda ao portal do governo', async () => {
    const { wrapper } = await view('/invoices?invoice=n1')
    nfseApi.mockRejectedValue(new ApiError('CANCEL_REFUSED', 422, 'web.error.validation', undefined, { usePortal: true }))
    await wrapper.get('[data-testid="nfse-cancel"]').trigger('click')
    await flush()
    document.querySelectorAll<HTMLButtonElement>('button.opt')[0]!.click()
    await flush()
    expect(nfseApi).toHaveBeenCalledWith('/v1/app/nfse/direct/invoices/n1/cancel', { method: 'POST', body: { reason: 'issueError' } })
    expect(wrapper.get('[data-testid="nfse-panel-note"]').text()).toBe(t('web.nfseDirect.cancelPortal'))
    wrapper.unmount()
  })

  test('recusa direta mostra a frase da recusa; nota parada há mais de 3 minutos pode ser conferida', async () => {
    listed.invoices = [
      doc('n3', { status: 'error', number: null, refusal: { code: 'E0312', group: 'emitterSetup', message: { pt: 'Serviço fora da lista da cidade.' } }, statusDescription: 'E0312 texto cru' }),
      doc('n4', { status: 'creating', number: null, accessKey: null, createdAt: new Date(Date.now() - 10 * 60 * 1000).toISOString() }),
    ]
    const { wrapper, router } = await view('/invoices?invoice=n3')
    expect(wrapper.get('[data-testid="nfse-reason"]').text()).toBe('Serviço fora da lista da cidade.')
    await router.push('/invoices?invoice=n4')
    await flush()
    nfseApi.mockResolvedValue({ status: 'authorized' })
    await wrapper.get('[data-testid="nfse-reconcile"]').trigger('click')
    await flush()
    expect(nfseApi).toHaveBeenCalledWith('/v1/app/nfse/direct/invoices/n4/reconcile', { method: 'POST', body: {} })
    wrapper.unmount()
  })
})
