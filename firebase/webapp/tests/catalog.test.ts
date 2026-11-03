// Fatia 05 (catálogo): search and order without the app's accent defects,
// kinds by permission, bulk price in cents (never 100 times smaller) and the
// spreadsheet review. Money parsing follows the currency contract cases.
import { describe, expect, test, vi } from 'vitest'
import {
  catalogImportPayload,
  guessCatalogFields,
  itemMatches,
  newPrice,
  parseKind,
  percentOk,
  MAX_PRICE_BATCH,
  pickKind,
  priceBatch,
  priceBatchBody,
  priceChanges,
  reverseBatch,
  reviewCatalogRows,
  sortByName,
  visibleKinds,
  type CatalogItem,
} from '../src/lib/catalog/model'

vi.mock('../src/lib/firebase', () => ({ firestoreClient: vi.fn() }))

const item = (id: string, name: string, value?: number | null): CatalogItem => ({ id, name, ...(value === undefined ? {} : { value }), photo: null, customData: null, version: null })

describe('lista', () => {
  test('busca contém, sem acento e sem caixa (o app não ignora acento: C14)', () => {
    expect(itemMatches({ name: 'Troca de Óleo' }, 'oleo')).toBe(true)
    expect(itemMatches({ name: 'Troca de Óleo' }, 'DE OL')).toBe(true)
    expect(itemMatches({ name: 'Alinhamento' }, 'óleo')).toBe(false)
    expect(itemMatches({ name: 'Qualquer' }, '  ')).toBe(true)
  })

  test('ordem por nome sem caixa e sem acento (o app põe "a" depois de "Z": C20)', () => {
    expect(sortByName([item('1', 'Zinco'), item('2', 'alinhamento'), item('3', 'Óleo'), item('4', 'Balanceamento')]).map((i) => i.name)).toEqual([
      'alinhamento',
      'Balanceamento',
      'Óleo',
      'Zinco',
    ])
  })

  test('tipos pela permissão; técnico não vê nenhum; URL só escolhe tipo permitido', () => {
    const all = visibleKinds(() => true)
    expect(all).toEqual(['service', 'product'])
    expect(visibleKinds((p) => p === 'viewProducts')).toEqual(['product'])
    expect(visibleKinds(() => false)).toEqual([])
    expect(pickKind('product', all)).toBe('product')
    expect(pickKind('nope', all)).toBe('service')
    expect(pickKind('service', ['product'])).toBe('product')
    expect(pickKind(undefined, [])).toBeNull()
  })
})

describe('preço em lote', () => {
  test('aumenta e baixa em centavos, sem deriva', () => {
    expect(newPrice(120, { direction: 'up', percent: 10, round: false })).toBe(132)
    expect(newPrice(35.5, { direction: 'up', percent: 10, round: false })).toBe(39.05)
    expect(newPrice(0.1, { direction: 'up', percent: 3, round: false })).toBe(0.1)
    expect(newPrice(19.99, { direction: 'down', percent: 15, round: false })).toBe(16.99)
    expect(newPrice(10, { direction: 'down', percent: 100, round: false })).toBe(0)
  })

  test('arredondar para inteiro e moeda sem centavos', () => {
    expect(newPrice(54.9, { direction: 'up', percent: 0, round: true })).toBe(55)
    expect(newPrice(49.4, { direction: 'up', percent: 0, round: true })).toBe(49)
    expect(newPrice(1000, { direction: 'up', percent: 5.5, round: false }, 0)).toBe(1055)
  })

  test('valor grande nunca vira centavos (150 continua 150)', () => {
    expect(newPrice(150, { direction: 'up', percent: 0, round: false })).toBe(150)
    expect(newPrice(1234.56, { direction: 'up', percent: 0, round: false })).toBe(1234.56)
  })

  test('porcentagem válida: baixar até 100, aumentar até 1000', () => {
    expect(percentOk({ direction: 'down', percent: 100 })).toBe(true)
    expect(percentOk({ direction: 'down', percent: 101 })).toBe(false)
    expect(percentOk({ direction: 'up', percent: 1000 })).toBe(true)
    expect(percentOk({ direction: 'up', percent: -1 })).toBe(false)
    expect(percentOk({ direction: 'up', percent: Number.NaN })).toBe(false)
  })

  test('antes e depois; sem preço e igual ficam de fora e são contados', () => {
    const result = priceChanges([item('a', 'A', 100), item('b', 'B', null), item('c', 'C', 0), item('d', 'D')], { direction: 'up', percent: 10, round: false })
    expect(result.changes.map((c) => [c.item.id, c.from, c.to])).toEqual([['a', 100, 110]])
    expect(result.withoutPrice).toBe(2)
    expect(result.same).toBe(1)
  })
})

describe('importar planilha', () => {
  test('adivinha nome, tipo e preço; preço antes de nome ("Valor do serviço")', () => {
    expect(guessCatalogFields(['Descrição', 'Tipo', 'Valor do serviço', 'Obs'])).toEqual(['name', 'kind', 'value', ''])
    expect(guessCatalogFields(['Serviço', 'Preço'])).toEqual(['name', 'value'])
    expect(guessCatalogFields(['Name', 'Type', 'Price', 'Name'])).toEqual(['name', 'kind', 'value', ''])
  })

  test('tipo escrito na célula; vazio usa o padrão; desconhecido fica de fora', () => {
    expect(parseKind('Serviço', 'product')).toBe('service')
    expect(parseKind('mão de obra', 'product')).toBe('service')
    expect(parseKind('Peça', 'service')).toBe('product')
    expect(parseKind('Componente', 'service')).toBe('product')
    expect(parseKind('', 'product')).toBe('product')
    expect(parseKind('Acessório', 'service')).toBeNull()
    expect(parseKind('Acessório', 'service', 'Acessório')).toBe('product')
  })

  test('prévia: sem nome, tipo ruim, preço ilegível, já no catálogo e repetido ficam de fora', () => {
    const rows = [
      ['Troca de óleo', 'Serviço', '90'],
      ['', 'Serviço', '10'],
      ['Polimento', 'Brinde', '10'],
      ['Lavagem', '', 'caro'],
      ['ALINHAMENTO', 'serviço', '140'],
      ['Troca de Oleo', 'servico', '95'],
      ['Filtro', 'Peça', 'R$ 1.234,56'],
      ['Junta', 'peça', ''],
    ]
    const review = reviewCatalogRows(rows, ['name', 'kind', 'value'], { service: [{ name: 'Alinhamento' }], product: [] }, { defaultKind: 'service', country: 'BR', prices: true })
    expect(review.map((r) => r.state)).toEqual(['ok', 'noName', 'badKind', 'badPrice', 'duplicate', 'repeated', 'ok', 'ok'])
    expect(review[5]?.clash).toBe(2)
    // "1.234,56" is 1234.56 and "90" is 90: read as typed, never as cents.
    expect(review[0]?.value).toBe(90)
    expect(review[6]?.value).toBe(1234.56)
    expect(review[7]?.value).toBeNull()
    expect(catalogImportPayload(review)).toEqual({
      service: [{ name: 'Troca de óleo', value: 90 }],
      product: [{ name: 'Filtro', value: 1234.56 }, { name: 'Junta', value: null }],
    })
  })

  test('mesmo nome em tipos diferentes entra; sem permissão de preço a coluna é ignorada', () => {
    const review = reviewCatalogRows([['Bateria', 'Serviço', '50'], ['Bateria', 'Peça', '400']], ['name', 'kind', 'value'], { service: [], product: [] }, { defaultKind: 'service', prices: false })
    expect(review.map((r) => r.state)).toEqual(['ok', 'ok'])
    expect(review[0]).not.toHaveProperty('value')
    expect(catalogImportPayload(review)).toEqual({ service: [{ name: 'Bateria' }], product: [{ name: 'Bateria' }] })
  })

  test('preço em país com ponto decimal (US)', () => {
    const review = reviewCatalogRows([['Screen', '', '$1,234.50']], ['name', 'kind', 'value'], { service: [], product: [] }, { defaultKind: 'product', country: 'US', prices: true })
    expect(review[0]?.value).toBe(1234.5)
  })
})

describe('lote de preços (revisão A1)', () => {
  const change = (id: string, from: number, to: number) => ({ item: item(id, id, from), from, to })

  test('o corpo leva a chave e os preços vistos; repetir o lote manda o mesmo corpo', () => {
    let n = 0
    const batch = priceBatch('service', [change('a', 100, 110)], () => `lote-${++n}`.padEnd(8, '0'))
    expect(priceBatchBody(batch)).toEqual({ batchId: 'lote-100', changes: [{ id: 'a', from: 100, to: 110 }] })
    expect(priceBatchBody(batch)).toEqual(priceBatchBody(batch))
  })

  test('desfazer volta de cada preço novo ao antigo, com chave própria', () => {
    const batch = priceBatch('product', [change('a', 100, 110), change('b', 35.5, 39.05)], () => 'ida-00000')
    const back = reverseBatch(batch, () => 'volta-0000')
    expect(back.kind).toBe('product')
    expect(priceBatchBody(back)).toEqual({ batchId: 'volta-0000', changes: [{ id: 'a', from: 110, to: 100 }, { id: 'b', from: 39.05, to: 35.5 }] })
  })

  test('acima de 500 itens não monta o lote: todos ou nenhum vale só numa transação', () => {
    const many = Array.from({ length: MAX_PRICE_BATCH + 1 }, (_, i) => change(`i${i}`, 1, 2))
    expect(() => priceBatch('service', many)).toThrow()
    expect(priceBatch('service', many.slice(0, MAX_PRICE_BATCH)).changes).toHaveLength(MAX_PRICE_BATCH)
  })
})
