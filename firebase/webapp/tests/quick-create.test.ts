// Cadastro rápido de dentro da OS (order.quick.*): o texto vai para o campo certo,
// o preço só vai para quem pode editar preço e a OS mostra só o que falta de útil.
import { beforeEach, describe, expect, test, vi } from 'vitest'

const api = vi.fn()
const allowed = new Set<string>()
vi.mock('../src/lib/firebase', () => ({ firestoreLite: vi.fn(), authClient: vi.fn() }))
vi.mock('../src/lib/session', () => ({ api: (...args: unknown[]) => api(...args), can: (key: string) => allowed.has(key), session: { companyId: 'c1' } }))

const { createCustomer, createDevice, createItem, customerDraft, customerSummary, deviceDraft, missingOnOrder, registerKinds } = await import('../src/lib/orders/quick-create')

beforeEach(() => {
  api.mockReset()
  allowed.clear()
})

describe('rascunho', () => {
  test('só números (6 ou mais) é telefone; o resto é nome', () => {
    expect(customerDraft('Ana Souza ')).toEqual({ name: 'Ana Souza', phone: '' })
    expect(customerDraft('(11) 98888-7777')).toEqual({ name: '', phone: '(11) 98888-7777' })
    expect(customerDraft('Loja 12345')).toEqual({ name: 'Loja 12345', phone: '' })
  })

  test('placa vai para a série em maiúsculas; o resto é o modelo', () => {
    expect(deviceDraft('abc1d23')).toEqual({ name: '', serial: 'ABC1D23' })
    expect(deviceDraft('ABC-1234')).toEqual({ name: '', serial: 'ABC-1234' })
    expect(deviceDraft('Fiat Argo')).toEqual({ name: 'Fiat Argo', serial: '' })
  })

  test('tipos de item pela permissão, serviço primeiro', () => {
    allowed.add('manageProducts')
    expect(registerKinds()).toEqual(['product'])
    allowed.add('manageServices')
    expect(registerKinds()).toEqual(['service', 'product'])
  })
})

describe('gravação', () => {
  test('cliente leva o telefone só quando foi digitado', async () => {
    api.mockResolvedValue({ id: 'k1', name: 'Ana' })
    expect(await createCustomer({ name: ' Ana ', phone: '' })).toEqual({ id: 'k1', name: 'Ana' })
    expect(api).toHaveBeenLastCalledWith('/v1/app/customers', { method: 'POST', body: { name: 'Ana' } })
    expect(await createCustomer({ name: 'Ana', phone: '(11) 98888-7777' })).toMatchObject({ phone: '(11) 98888-7777' })
    expect(api).toHaveBeenLastCalledWith('/v1/app/customers', { method: 'POST', body: { name: 'Ana', phone: '(11) 98888-7777' } })
  })

  test('aparelho leva modelo e placa; sem modelo, o nome é a placa', async () => {
    api.mockResolvedValue({ id: 'd1', name: 'Argo', serial: 'ABC1D23' })
    expect(await createDevice({ name: 'Argo', serial: 'abc1d23' })).toEqual({ id: 'd1', name: 'Argo', serial: 'ABC1D23' })
    expect(api).toHaveBeenLastCalledWith('/v1/app/devices', { method: 'POST', body: { name: 'Argo', serial: 'ABC1D23' } })
    api.mockResolvedValue({ id: 'd2', name: null, serial: 'XYZ9A99' })
    expect(await createDevice({ name: '', serial: 'XYZ9A99' })).toEqual({ id: 'd2', name: 'XYZ9A99', serial: 'XYZ9A99' })
  })

  test('preço só vai com editPrices; peça vai para produtos', async () => {
    api.mockResolvedValue({ id: 'i1' })
    expect(await createItem({ name: 'Pastilha', kind: 'product', value: 120 })).toEqual({ id: 'i1', kind: 'product', name: 'Pastilha', value: null })
    expect(api).toHaveBeenLastCalledWith('/v1/app/products', { method: 'POST', body: { name: 'Pastilha' } })
    allowed.add('editPrices')
    expect(await createItem({ name: 'Troca', kind: 'service', value: 80 })).toMatchObject({ value: 80 })
    expect(api).toHaveBeenLastCalledWith('/v1/app/services', { method: 'POST', body: { name: 'Troca', value: 80 } })
  })
})

describe('o que falta na OS', () => {
  const order = {
    customer: { id: 'k1', name: 'Ana', phone: '' },
    devices: [
      { id: 'd1', name: 'Argo', serial: null },
      { id: 'd2', name: 'ABC1D23', serial: 'ABC1D23' },
      { id: 'd3', name: 'Onix', serial: 'XYZ9A99' },
    ],
  }
  test('WhatsApp do cliente, placa ou modelo do aparelho; nada mais', () => {
    expect(missingOnOrder(order, { customers: true, devices: true })).toEqual([
      { kind: 'phone' },
      { kind: 'serial', deviceId: 'd1' },
      { kind: 'model', deviceId: 'd2' },
    ])
  })
  test('sem permissão, não oferece', () => {
    expect(missingOnOrder(order, { customers: false, devices: false })).toEqual([])
    expect(missingOnOrder({ customer: { id: 'k1', phone: '11 99999-0000' }, devices: [] }, { customers: true, devices: true })).toEqual([])
  })
  test('cópia do cliente na OS sem campos vazios', () => {
    expect(customerSummary({ id: 'k1', name: 'Ana', phone: '11', email: null, taxId: '' })).toEqual({ id: 'k1', name: 'Ana', phone: '11' })
  })
})
