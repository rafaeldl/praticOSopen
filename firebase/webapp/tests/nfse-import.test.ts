// "Importar notas" of the NFS-e direct in the web (issue #569, nfse.direct.import):
// reading until the proposal, the summary, the answers sent on "Importar", and the
// neutral style sample. The nfseApi is a fake; all names are fictional.
import { mount } from '@vue/test-utils'
import { afterEach, beforeAll, beforeEach, describe, expect, test, vi } from 'vitest'
import { defineComponent, h, nextTick } from 'vue'
import { createMemoryHistory, createRouter } from 'vue-router'
import { setLocale } from '../src/i18n'
import { ApiError, codeMessageKey } from '../src/lib/api'

const { nfseApi } = vi.hoisted(() => ({ nfseApi: vi.fn() }))
vi.mock('../src/lib/session', () => ({
  nfseApi: (...args: unknown[]) => nfseApi(...args),
  api: vi.fn(),
  can: () => true,
  session: { companyId: 'c1', role: 'owner' },
}))
vi.mock('../src/lib/firebase', () => ({ firestoreClient: vi.fn(), firestoreLite: vi.fn(async () => ({})), storageClient: vi.fn() }))
import NfseImportDrawer from '../src/components/finance/NfseImportDrawer.vue'
import { sampleServices } from '../src/lib/nfse/direct'
import { batchOf, canUndo, customerCounts, readUntilProposed, toAsk, withStores } from '../src/lib/nfse/import'

beforeAll(() => setLocale('pt'))

const proposal = {
  counts: { notas: 42, canceled: 1, customers: 5, newCustomers: 2, completedCustomers: 1, ask: 1, linked: 30, historyOnly: 12 },
  emitter: {
    fill: {},
    view: { legalName: 'OFICINA EXEMPLO LTDA', regime: 'simples', municipalRegistration: '12345', service: { name: 'Manutenção de veículos', issRate: 2.5 }, descriptionStyle: null, dpsSeries: '10' },
  },
  groups: [
    { key: '11222333000181', taxId: '11222333000181', legalName: 'REVENDA EXEMPLO LTDA', action: 'ask', notas: 4, customerId: 'cust-1', customerName: 'Revenda', stores: [], links: [] },
    { key: '45723174000110', taxId: '45723174000110', legalName: 'FROTA EXEMPLO SA', action: 'complete', notas: 9, customerId: 'cust-2', customerName: 'Frota', stores: [{ customerId: 'cust-3', customerName: 'Frota Filial', orders: 3 }], links: [] },
  ],
  autoIssue: [{ customerId: 'cust-2', customerName: 'Frota', orders: 10, withNota: 9 }],
}
const reading = (documents: number) => ({ id: 'b1', emitterId: 'e1', status: 'reading', read: { documents, lastNsu: documents } })
const proposed = { id: 'b1', emitterId: 'e1', status: 'proposed', read: { documents: 50, lastNsu: 50 }, proposal }

const flush = async () => {
  for (let i = 0; i < 8; i++) {
    await nextTick()
    await new Promise((resolve) => setTimeout(resolve, 0))
  }
}
const $ = <T extends Element = HTMLElement>(selector: string) => document.querySelector<T>(selector)
const text = (selector: string) => $(selector)?.textContent?.trim() ?? ''

afterEach(() => {
  document.body.innerHTML = ''
})

describe('importação: regras', () => {
  test('lê a proposta do servidor', () => {
    const batch = batchOf(proposed)
    expect(batch.status).toBe('proposed')
    expect(batch.documentsRead).toBe(50)
    expect(batch.proposal?.emitter).toMatchObject({ legalName: 'OFICINA EXEMPLO LTDA', regime: 'simples', dpsSeries: '10', service: { name: 'Manutenção de veículos', issRate: 2.5 } })
    expect(toAsk(batch.proposal!).map((g) => g.key)).toEqual(['11222333000181'])
    expect(withStores(batch.proposal!).map((g) => g.stores[0]?.customerName)).toEqual(['Frota Filial'])
    expect(batchOf({ status: 'whatever' }).status).toBe('failed')
  })

  test('"Sim" completa o cliente; sem resposta ou "Não" vira cliente novo', () => {
    const p = batchOf(proposed).proposal!
    expect(customerCounts(p, {})).toEqual({ created: 3, completed: 1 })
    expect(customerCounts(p, { '11222333000181': false })).toEqual({ created: 3, completed: 1 })
    expect(customerCounts(p, { '11222333000181': true })).toEqual({ created: 2, completed: 2 })
  })

  test('desfazer só nos 30 dias depois de importar', () => {
    const now = new Date('2026-11-05T12:00:00Z')
    expect(canUndo(batchOf({ status: 'applied', expiresAt: '2026-12-01T00:00:00Z' }), now)).toBe(true)
    expect(canUndo(batchOf({ status: 'applied', expiresAt: '2026-11-01T00:00:00Z' }), now)).toBe(false)
    expect(canUndo(batchOf({ status: 'undone', expiresAt: '2026-12-01T00:00:00Z' }), now)).toBe(false)
    expect(canUndo(null, now)).toBe(false)
  })

  test('continua lendo até a proposta ficar pronta', async () => {
    nfseApi.mockReset()
    nfseApi.mockResolvedValueOnce(reading(0)).mockResolvedValueOnce(reading(20)).mockResolvedValueOnce(proposed)
    const seen: number[] = []
    const batch = await readUntilProposed('e1', (b) => seen.push(b.documentsRead))
    expect(batch.status).toBe('proposed')
    expect(seen).toEqual([0, 20, 50])
    expect(nfseApi.mock.calls.map((c) => c[0])).toEqual(['/v1/app/nfse/imports', '/v1/app/nfse/imports/b1/continue', '/v1/app/nfse/imports/b1/continue'])
    expect(nfseApi.mock.calls[0]?.[1]).toEqual({ method: 'POST', body: { emitterId: 'e1' } })
  })

  test('erros da importação têm frase própria', () => {
    expect(codeMessageKey('SEFIN_UNAVAILABLE')).toBe('nfseDirectErrorGovUnavailable')
    expect(codeMessageKey('IMPORT_UNDO_EXPIRED')).toBe('nfseImportErrorUndoExpired')
  })

  test('exemplo do estilo: os serviços da empresa, senão um par neutro', () => {
    const neutral: [string, string] = ['Serviço 1', 'Serviço 2']
    expect(sampleServices(['Limpeza do split', ' Carga de gás ', 'Outro'], neutral)).toEqual(['Limpeza do split', 'Carga de gás'])
    expect(sampleServices(['Formatação', 'Formatação'], neutral)).toEqual(neutral)
    expect(sampleServices([], neutral)).toEqual(neutral)
  })
})

describe('NfseImportDrawer', () => {
  beforeEach(() => {
    nfseApi.mockReset()
  })

  async function open() {
    const router = createRouter({ history: createMemoryHistory('/web/'), routes: [{ path: '/', component: { render: () => null } }] })
    await router.push('/')
    const applied = vi.fn()
    const host = defineComponent({ setup: () => () => h(NfseImportDrawer, { emitterId: 'e1', onApplied: applied }) })
    const wrapper = mount(host, { global: { plugins: [router] }, attachTo: document.body })
    await flush()
    return { wrapper, applied }
  }

  test('mostra o resumo e manda as respostas no "Importar"', async () => {
    nfseApi.mockImplementation(async (path: string) => (path.endsWith('/apply') ? { ...proposed, status: 'applied' } : path.endsWith('/continue') ? proposed : reading(0)))
    const { applied } = await open()
    expect(text('[data-testid="nfse-import-headline"]')).toBe('Achamos 42 notas para 5 clientes. Vamos preencher seus clientes e o serviço da nota.')
    expect(text('[data-testid="nfse-import-service"]')).toContain('Manutenção de veículos · ISS 2,5%')
    expect(text('[data-testid="nfse-import-series"]')).toContain('10')
    expect(text('[data-testid="nfse-import-new"]')).toBe('3 clientes novos')
    expect(document.body.textContent).toContain('Nota fiscal para Frota')

    const yes = $<HTMLInputElement>('[data-testid="nfse-import-ask-11222333000181"] input[type="radio"]')!
    yes.click()
    await flush()
    expect(text('[data-testid="nfse-import-completed"]')).toBe('2 completam clientes que você já tem')
    $<HTMLInputElement>('[data-testid="nfse-import-auto-cust-2"]')!.click()
    $<HTMLButtonElement>('[data-testid="nfse-import-apply"]')!.click()
    await flush()

    expect(nfseApi).toHaveBeenLastCalledWith('/v1/app/nfse/imports/b1/apply', {
      method: 'POST',
      body: { answers: { sameCustomer: { '11222333000181': true }, autoIssueCustomerIds: ['cust-2'] } },
    })
    expect(applied).toHaveBeenCalled()
    expect(document.body.textContent).not.toContain('undefined')
  })

  test('o governo não respondeu: frase e "Tentar de novo", sem botão Importar', async () => {
    nfseApi.mockRejectedValue(new ApiError('SEFIN_UNAVAILABLE', 503, 'nfseDirectErrorGovUnavailable'))
    await open()
    expect(document.body.textContent).toContain('O governo não respondeu')
    expect($('[data-testid="nfse-import-apply"]')).toBeNull()
  })
})
