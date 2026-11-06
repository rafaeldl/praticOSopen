import { describe, expect, test } from 'vitest'
import { canHaveNfse, cityAccessKind, currentInvoiceOf, eligibleOrderIds, invoiceOf, nextSetupStep, nfseIssueRow, nfseNextStep, nfseValueOf, parsePercent } from '../src/lib/nfse/model'

const nota = (id: string, data: Record<string, unknown>) => invoiceOf(id, { orderIds: ['o1'], createdAt: new Date(Date.now() - 1000).toISOString(), ...data })
const order = (status: string, services: number[], products: { value: number; quantity?: number }[] = [], discount = 0) => ({
  status,
  discount,
  lines: [...services.map((value) => ({ kind: 'service' as const, value })), ...products.map((p) => ({ kind: 'product' as const, value: p.value, quantity: p.quantity ?? 1 }))],
})

describe('nota da OS (order.nfse.*)', () => {
  test('valor da nota: só serviços, com a parte do desconto (nfseValueOfOrder)', () => {
    expect(nfseValueOf(order('done', [300], [{ value: 100 }], 40))).toBe(270)
    expect(nfseValueOf(order('done', [], [{ value: 100 }]))).toBe(0)
    expect(canHaveNfse(order('quote', [100]))).toBe(false)
    expect(canHaveNfse(order('done', [], [{ value: 100 }]))).toBe(false)
    expect(canHaveNfse(order('approved', [100]))).toBe(true)
  })

  test('a nota da OS: a ativa mais nova, senão a mais nova; "criando" velha não conta', () => {
    const old = nota('a', { status: 'error', createdAt: '2026-01-01T00:00:00Z' })
    const active = nota('b', { status: 'authorized', createdAt: '2025-12-01T00:00:00Z' })
    expect(currentInvoiceOf([old, active])?.id).toBe('b')
    expect(currentInvoiceOf([old])?.id).toBe('a')
    expect(currentInvoiceOf([nota('c', { status: 'creating', createdAt: '2020-01-01T00:00:00Z' })])).toBeNull()
  })

  test('botão azul: concluída e paga, sem nota ativa; corrigir depois de erro; nada depois de cancelada', () => {
    const done = order('done', [100])
    expect(nfseNextStep(done, null, true, 0)).toBe('issue')
    expect(nfseNextStep(done, null, false, 0)).toBeNull()
    expect(nfseNextStep(done, null, true, 10)).toBeNull()
    expect(nfseNextStep(done, nota('x', { status: 'error' }), true, 0)).toBe('fix')
    expect(nfseNextStep(done, nota('x', { status: 'canceled' }), true, 0)).toBeNull()
    expect(nfseNextStep(done, nota('x', { status: 'authorized' }), true, 0)).toBeNull()
    expect(nfseNextStep(order('progress', [100]), null, true, 0)).toBeNull()
  })

  test('linha "Nota fiscal": aprovada também com a nota direta (#612)', () => {
    const approved = order('approved', [100])
    expect(nfseIssueRow(approved, null, true, true, 100)).toBe('issue')
    expect(nfseIssueRow(approved, null, true, false, 100)).toBeNull()
    expect(nfseIssueRow(order('quote', [100]), null, true, true, 100)).toBeNull()
    expect(nfseIssueRow(approved, nota('x', { status: 'authorized' }), true, true, 100)).toBeNull()
    expect(nfseIssueRow(approved, null, false, true, 100)).toBeNull()
    const done = order('done', [100])
    expect(nfseIssueRow(done, null, true, false, 0)).toBe('notIssued')
    expect(nfseIssueRow(done, null, true, false, 10)).toBe('issue')
  })

  test('várias OS do cliente: elegível pelo valor dos serviços, como o app (B7)', () => {
    const list = [
      { id: 'servico', order: order('done', [80]) },
      { id: 'produto', order: order('done', [], [{ value: 200 }]) },
    ]
    expect(eligibleOrderIds(list, [])).toEqual(['servico'])
  })

  test('OS que podem entrar numa nota: sem nota ativa (nfse.orders.pick)', () => {
    const list = [
      { id: 'o1', order: order('done', [100]) },
      { id: 'o2', order: order('done', [100]) },
      { id: 'o3', order: order('quote', [100]) },
    ]
    expect(eligibleOrderIds(list, [nota('n', { status: 'authorized', orderIds: ['o1'] })])).toEqual(['o2'])
    expect(eligibleOrderIds(list, [nota('n', { status: 'canceled', orderIds: ['o1'] })])).toEqual(['o1', 'o2'])
  })
})

describe('configurar a nota (nfse.setup.*)', () => {
  test('próximo passo na ordem do app', () => {
    expect(nextSetupStep(['service', 'fiscalInfo'])).toBe('fiscalInfo')
    expect(nextSetupStep(['service', 'cityAccess'])).toBe('cityAccess')
    expect(nextSetupStep([])).toBeNull()
  })
  test('texto do acesso à prefeitura', () => {
    expect(cityAccessKind({ fiscalInfo: null, municipalOptions: { authenticationType: 'TOKEN' } })).toBe('first')
    expect(cityAccessKind({ fiscalInfo: { email: 'a@b.c' }, municipalOptions: { authenticationType: 'CERTIFICATE' } })).toBe('certificate')
    expect(cityAccessKind({ fiscalInfo: { email: 'a@b.c' }, municipalOptions: null })).toBe('none')
  })
  test('percentual com vírgula ou ponto, de 0 a 100; vazio é 0; inválido não vira número (B6)', () => {
    expect(parsePercent('2,5')).toBe(2.5)
    expect(parsePercent('2.5 %')).toBe(2.5)
    expect(parsePercent('')).toBe(0)
    expect(parsePercent('abc')).toBeNull()
    expect(parsePercent('2,5abc')).toBeNull()
    expect(parsePercent('150')).toBeNull()
    expect(parsePercent('-3')).toBeNull()
    expect(parsePercent('100')).toBe(100)
  })
})
