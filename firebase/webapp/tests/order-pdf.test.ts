import { describe, expect, it } from 'vitest'
import { normalizeOrder } from '@/lib/orders/model'
import { normalizeOrderForm } from '@/lib/forms/model'
import { buildOrdersPdf, pdfFileName, pdfSafe, type PdfOrderPart, type PdfTexts } from '@/lib/pdf/order-pdf'
import { pdfPageCount, pdfText } from './pdf-text'

const money = (value: number) => `R$ ${value.toFixed(2).replace('.', ',')}`
const texts: PdfTexts = {
  serviceOrder: 'OS',
  customer: 'Cliente',
  newOrder: 'NOVA',
  notInformed: 'Não informado',
  generatedBy: 'Gerado por PraticOS',
  site: 'praticos.app',
  description: 'DESCRIÇÃO',
  quantity: 'Qtd',
  unitValue: 'Valor Unit.',
  total: 'Total',
  services: 'Serviços',
  products: 'Produtos',
  discount: 'Desconto',
  paid: 'Pago',
  summary: 'Resumo',
  general: 'Geral',
  equipment: 'Equipamento',
  serviceType: 'Serviço',
  productType: 'Peça',
  itemType: 'Tipo',
  technician: 'Técnico',
  created: 'Criada',
  completed: 'Concluída',
  serviceLocation: 'Local do Atendimento',
  trackOnline: 'Acompanhe online',
  trackOnlineDescription: 'Escaneie o QR Code para acompanhar esta ordem de serviço',
  terms: 'Termos e Condições',
  clientSignature: 'Cliente',
  companySignature: 'Responsável',
  photosDigital: 'Fotos disponíveis no sistema digital',
  yes: 'Sim',
  no: 'Não',
  formCompleted: 'Concluído',
  formInProgress: 'Em Andamento',
  formPending: 'Pendente',
  notAnswered: 'Não Respondido',
  notSelected: 'Não selecionado',
  status: (status) => ({ quote: 'Orçamento', approved: 'Aprovada', progress: 'Na oficina', done: 'Concluída', canceled: 'Cancelada' })[status],
  money,
  date: (iso) => iso.slice(0, 10).split('-').reverse().join('/'),
  pageOf: (current, total) => `Página ${current} de ${total}`,
  attachedPhotos: (count) => `Fotos Anexadas (${count})`,
  formLabel: (title) => `Formulário: ${title}`,
  formTitle: (form) => form.title,
  itemLabel: (item) => item.label,
  optionText: (_item, value) => value,
}

const raw = (extra: Record<string, unknown> = {}) => ({
  number: 186,
  status: 'done',
  customer: { id: 'c1', name: 'Ana Souza' },
  devices: [{ id: 'd1', name: 'Fiat Uno', serial: 'ABC1D23' }],
  services: [{ id: 's1', service: { id: 'cat1', name: 'Alinhamento' }, value: 150, description: 'dianteiro' }],
  products: [{ id: 'p1', product: { id: 'cat2', name: 'Óleo 5W30' }, value: 40, quantity: 3, total: 120 }],
  total: 250,
  discount: 20,
  paidAmount: 100,
  createdAt: '2026-10-01T12:00:00.000Z',
  updatedAt: '2026-10-02T12:00:00.000Z',
  address: 'Rua das Flores, 10',
  assignedTo: { id: 'u1', name: 'Tiago' },
  ...extra,
})

const part = (show: boolean, extra: Record<string, unknown> = {}, over: Partial<PdfOrderPart> = {}): PdfOrderPart => ({
  order: normalizeOrder('o1', raw(extra), show),
  customer: { name: 'Ana Souza', phone: '(11) 98888-7777', email: 'ana@exemplo.test' },
  paid: false,
  shareUrl: null,
  photos: [],
  missingPhotos: 0,
  forms: [],
  ...over,
})
const company = { name: 'Oficina Alfa', address: 'Av. Brasil, 1', phone: '(11) 3333-4444', email: 'oficina@exemplo.test', terms: 'Garantia de 90 dias.' }

// 1x1 PNG, white.
const PNG = Uint8Array.from(
  atob('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='),
  (c) => c.charCodeAt(0),
)

describe('buildOrdersPdf', () => {
  it('draws the order like the app: header, customer, items, summary, terms and signatures', async () => {
    const text = pdfText(await buildOrdersPdf([part(true)], company, texts, { showValues: true }))
    for (const expected of ['Oficina Alfa', 'Av. Brasil, 1', '#186', 'CONCLUÍDA', 'Técnico: Tiago', 'Criada: 01/10/2026', 'Concluída: 02/10/2026', 'Ana Souza', '(11) 98888-7777 · ana@exemplo.test', 'Rua das Flores, 10', 'Fiat Uno', 'ABC1D23', 'Alinhamento - dianteiro', 'Óleo 5W30', 'R$ 150,00', 'R$ 120,00', '- R$ 20,00', 'R$ 250,00', 'Pago', 'R$ 100,00', 'Garantia de 90 dias.', 'Responsável', 'Página 1 de 1']) {
      expect(text).toContain(expected)
    }
  })

  it('without values: no prices, totals, payments nor the summary', async () => {
    const text = pdfText(await buildOrdersPdf([part(false)], company, texts, { showValues: false }))
    expect(text).toContain('Alinhamento - dianteiro')
    expect(text).toContain('Ana Souza')
    expect(text).not.toMatch(/R\$/)
    expect(text).not.toContain('RESUMO')
    expect(text).not.toContain('Valor Unit.')
    expect(text).not.toContain('Pago')
  })

  it('groups items by device with the general block, as buildEquipmentBlocks', async () => {
    const extra = {
      devices: [
        { id: 'd1', name: 'Fiat Uno' },
        { id: 'd2', name: 'Gol' },
      ],
      services: [
        { service: { name: 'Pintura' }, value: 300, deviceId: 'd2' },
        { service: { name: 'Lavagem' }, value: 50 },
      ],
      products: [],
    }
    const text = pdfText(await buildOrdersPdf([part(true, extra)], company, texts, { showValues: true }))
    expect(text.indexOf('Gol')).toBeLessThan(text.indexOf('Pintura'))
    expect(text.indexOf('Geral')).toBeLessThan(text.indexOf('Lavagem'))
    expect(text).toContain('R$ 300,00')
  })

  it('several orders: each one on its own pages, numbered on its own', async () => {
    const second = part(true, { number: 187, customer: { name: 'Bruno' } }, { customer: null })
    const bytes = await buildOrdersPdf([part(true), second], company, texts, { showValues: true })
    const text = pdfText(bytes)
    expect(text).toContain('#186')
    expect(text).toContain('#187')
    expect(text.match(/Página 1 de 1/g)?.length).toBe(2)
    expect(pdfPageCount(bytes)).toBe(2)
  })

  it('long orders run over pages, with the header on each', async () => {
    const services = Array.from({ length: 70 }, (_, i) => ({ service: { name: `Serviço ${i + 1}` }, value: 10 }))
    const bytes = await buildOrdersPdf([part(true, { services, products: [] })], company, texts, { showValues: true })
    const pages = pdfPageCount(bytes)
    expect(pages).toBeGreaterThan(1)
    const text = pdfText(bytes)
    expect(text.match(/#186/g)?.length).toBe(pages)
    expect(text).toContain(`Página ${pages} de ${pages}`)
    expect(text).toContain('Serviço 70')
  })

  it('photos, the share link and a checklist page', async () => {
    const form = normalizeOrderForm('f1', {
      formDefinitionId: 't1',
      title: 'Entrada do veículo',
      status: 'completed',
      items: [
        { id: 'i1', label: 'Pneus bons?', type: 'boolean' },
        { id: 'i2', label: 'Itens', type: 'checklist', options: ['Estepe', 'Macaco'] },
        { id: 'i3', label: 'Observação', type: 'text' },
        { id: 'i4', label: 'Combustível', type: 'select', options: ['Cheio', 'Meio'] },
      ],
      responses: [
        { itemId: 'i1', value: true, photoUrls: ['x'] },
        { itemId: 'i2', value: ['Estepe'], photoUrls: [] },
      ],
    })
    const photo = { bytes: PNG, kind: 'png' as const }
    const bytes = await buildOrdersPdf(
      [part(true, {}, { photos: [photo, photo], missingPhotos: 1, shareUrl: 'https://praticos.app/q/abc', forms: [{ form, photos: { i1: [photo] } }] })],
      company,
      texts,
      { showValues: true },
    )
    const text = pdfText(bytes)
    for (const expected of ['FOTOS ANEXADAS (2)', 'Fotos disponíveis no sistema digital', 'Acompanhe online', 'https://praticos.app/q/abc', 'ENTRADA DO VEÍCULO', 'Pneus bons?', 'X SIM', '[X] Estepe', '[ ] Macaco', 'Não Respondido', 'CONCLUÍDO', 'Formulário: Entrada do veículo']) {
      expect(text).toContain(expected)
    }
    expect(pdfPageCount(bytes)).toBe(2)
  })

  it('a broken image is left out and the PDF still comes out', async () => {
    const broken = { bytes: new Uint8Array([1, 2, 3]), kind: 'jpg' as const }
    const text = pdfText(await buildOrdersPdf([part(true, {}, { photos: [broken] })], { ...company, logo: broken }, texts, { showValues: true }))
    expect(text).not.toContain('FOTOS ANEXADAS')
    expect(text).toContain('#186')
  })
})

describe('fonte de reserva (B4)', () => {
  const roboto = async () => {
    const [{ readFileSync }, fontkit] = await Promise.all([import('node:fs'), import('@pdf-lib/fontkit')])
    return { fontkit: fontkit.default, bytes: new Uint8Array(readFileSync(`${process.cwd()}/../../assets/fonts/Roboto-Regular.ttf`)) }
  }

  it('texto fora do Latin-1 sai pela Roboto, sem virar "?"', async () => {
    const bytes = await buildOrdersPdf([part(true, { services: [{ service: { name: 'Capacitor 35μF' }, value: 10 }], products: [] })], company, texts, { showValues: true, fallbackFont: roboto })
    const raw = Buffer.from(bytes).toString('latin1')
    expect(raw).toContain('/FontFile2')
    expect(pdfText(bytes)).not.toContain('35?F')
  })

  it('sem caractere estranho a fonte nem é carregada', async () => {
    let loaded = false
    const bytes = await buildOrdersPdf([part(true)], company, texts, { showValues: true, fallbackFont: async () => ((loaded = true), roboto()) })
    expect(loaded).toBe(false)
    expect(Buffer.from(bytes).toString('latin1')).not.toContain('/FontFile2')
  })
})

describe('pdfSafe', () => {
  it('keeps what Helvetica draws and simplifies the rest', () => {
    expect(pdfSafe('Ação “ok” – 35€')).toBe('Ação “ok” – 35€')
    expect(pdfSafe('35μF ✓')).toBe('35?F ?')
    expect(pdfSafe('ő\nlinha')).toBe('o linha')
  })
})

describe('pdfFileName', () => {
  it('names the file like the app', () => {
    expect(pdfFileName('OS', [186])).toBe('OS-186.pdf')
    expect(pdfFileName('Ordem de Serviço', [190, 186, 188])).toBe('Ordem-de-Serviço-186-190.pdf')
    expect(pdfFileName('OS', [undefined])).toBe('OS-NOVA.pdf')
  })
})
