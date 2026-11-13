import { describe, expect, it } from 'vitest'
import { normalizeOrder } from '@/lib/orders/model'
import { buildStatementPdf, type StatementPdfTexts } from '@/lib/pdf/statement-pdf'
import { statementItemLabel, statementLightOf, statementOrderOf, statementText, statementTotal, type StatementTexts } from '@/lib/receive/statement'
import { pdfPageCount, pdfText } from './pdf-text'

const money = (value: number) => `R$ ${value.toFixed(2).replace('.', ',')}`
const day = (iso: string) => iso.slice(8, 10) + '/' + iso.slice(5, 7)

const done = normalizeOrder(
  'a',
  {
    number: 182,
    status: 'done',
    devices: [{ id: 'd1', name: 'Fiat Uno', serial: 'ABC-1234' }],
    services: [{ id: 's1', service: { id: 'cat1', name: 'Troca de óleo' }, description: 'Óleo 5W30', value: 150 }],
    products: [{ id: 'p1', product: { id: 'cat2', name: 'Filtro' }, value: 50, quantity: 2, total: 100 }],
    total: 230,
    discount: 20,
    paidAmount: 30,
    createdAt: '2026-10-03T12:00:00.000Z',
  },
  true,
)
const running = normalizeOrder(
  'b',
  { number: 190, status: 'progress', services: [{ id: 's2', description: 'Alinhamento', value: 150 }], total: 150, paidAmount: 0, createdAt: '2026-10-12T12:00:00.000Z' },
  true,
)

const texts: StatementTexts = {
  hello: (name) => `Olá, ${name}! Estas são as OS em aberto com Oficina Boa:`,
  orderNumber: (number) => `OS ${number}`,
  openLine: (amount) => `Falta ${amount}`,
  inProgress: 'em andamento',
  totalOpen: (amount) => `Total em aberto: ${amount}`,
  money,
  dayMonth: day,
}

describe('statementOrderOf', () => {
  it('services and parts with quantity and line value, device with serial, amounts', () => {
    const order = statementOrderOf(done)
    expect(order.items).toEqual([
      { name: 'Troca de óleo', description: 'Óleo 5W30', quantity: 1, value: 150 },
      { name: 'Filtro', quantity: 2, value: 100 },
    ])
    expect(order.items.map(statementItemLabel)).toEqual(['Troca de óleo - Óleo 5W30', 'Filtro'])
    expect(statementOrderOf(running).items[0]).not.toHaveProperty('description')
    expect(order.device).toBe('Fiat Uno · ABC-1234')
    expect(order.completed).toBe(true)
    expect([order.total, order.paid, order.open, order.discount]).toEqual([230, 30, 200, 20])
  })

  it('in progress, described by its first service', () => {
    const order = statementOrderOf(running)
    expect(order.completed).toBe(false)
    expect(order.device).toBe('Alinhamento')
  })

  it('an order known only by its balance has no status nor items', () => {
    const order = statementLightOf({ id: 'x', number: 5, open: 90, createdAt: null, own: false })
    expect(order).toMatchObject({ number: 5, completed: null, items: [], open: 90 })
  })
})

describe('statementText', () => {
  it('one block per order and the total owed', () => {
    const orders = [statementOrderOf(done), statementOrderOf(running)]
    expect(statementTotal(orders)).toBe(350)
    expect(statementText(orders, texts, 'João')).toBe(
      [
        'Olá, João! Estas são as OS em aberto com Oficina Boa:',
        '',
        'OS 182 · 03/10 · Fiat Uno · ABC-1234',
        'Falta R$ 200,00',
        '',
        'OS 190 · 12/10 · Alinhamento · em andamento',
        'Falta R$ 150,00',
        '',
        'Total em aberto: R$ 350,00',
      ].join('\n'),
    )
  })
})

describe('buildStatementPdf', () => {
  const pdfTexts: StatementPdfTexts = {
    title: 'Extrato',
    date: '06/11/2026',
    sentence: 'OS em aberto de João em 06/11/2026.',
    itemColumn: 'Serviço ou peça',
    quantityColumn: 'Qtd',
    valueColumn: 'Valor',
    orderNumber: (number) => `OS ${number}`,
    completed: 'Concluído',
    inProgress: 'Em Andamento',
    discount: 'Desconto',
    totals: (total, paid, open) => `Total ${total}  ·  Pago ${paid}  ·  Falta ${open}`,
    totalOpen: 'Total em aberto',
    money,
    day: (iso) => `${iso.slice(8, 10)}/${iso.slice(5, 7)}/${iso.slice(0, 4)}`,
  }

  it('company, each order with its items and amounts, and the total owed', async () => {
    const orders = [statementOrderOf(done), statementOrderOf(running)]
    const text = pdfText(await buildStatementPdf(orders, { name: 'Oficina Boa', phone: '(11) 3333-4444' }, pdfTexts))
    for (const expected of [
      'Oficina Boa',
      'EXTRATO',
      'OS em aberto de João em 06/11/2026.',
      'OS 182 · 03/10/2026 · Concluído',
      'Fiat Uno · ABC-1234',
      'Troca de óleo - Óleo 5W30',
      'Filtro',
      'R$ 100,00',
      'Desconto  - R$ 20,00',
      'Total R$ 230,00  ·  Pago R$ 30,00  ·  Falta R$ 200,00',
      'OS 190 · 12/10/2026 · Em Andamento',
      'Total em aberto',
      'R$ 350,00',
    ]) {
      expect(text).toContain(expected)
    }
  })

  it('many orders go on to more pages', async () => {
    const orders = Array.from({ length: 40 }, () => statementOrderOf(done))
    const bytes = await buildStatementPdf(orders, { name: 'Oficina Boa' }, pdfTexts)
    expect(pdfPageCount(bytes)).toBeGreaterThan(1)
    expect(pdfText(bytes)).toContain(money(8000))
  })
})
