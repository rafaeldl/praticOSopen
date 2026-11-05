// "Dados para nota" of the customer (customer.invoice-data.*, docs/NFSE_DIRECT.md):
// the CNPJ and CEP lookups, the repeated CPF/CNPJ and the "Emitir nota sozinha" rule.
import { describe, expect, test, vi } from 'vitest'
import {
  autoIssueOf,
  findByTaxId,
  formatPostalCode,
  lookupCnpj,
  lookupPostalCode,
  parseAutoIssue,
  showAutoIssue,
} from '../src/lib/customers/invoice-data'

vi.mock('../src/lib/firebase', () => ({ firestoreLite: vi.fn() }))

const reply = (body: unknown, ok = true) => vi.fn(async () => ({ ok, json: async () => body }))

describe('lookupCnpj', () => {
  test('legal name, address with the IBGE code and e-mail, as people write them', async () => {
    const fetcher = reply({
      razao_social: 'REVENDA EXEMPLO LTDA',
      descricao_tipo_de_logradouro: 'RUA',
      logradouro: 'DAS FLORES',
      numero: '100',
      complemento: 'SALA 2',
      bairro: 'CENTRO',
      cep: '80010-000',
      municipio: 'CURITIBA',
      codigo_municipio_ibge: 4106902,
      uf: 'pr',
      email: 'FISCAL@REVENDA.COM.BR',
    })
    const info = await lookupCnpj('11222333000181', fetcher)
    expect(fetcher).toHaveBeenCalledWith('https://brasilapi.com.br/api/cnpj/v1/11222333000181')
    expect(info).toEqual({
      legalName: 'REVENDA EXEMPLO LTDA',
      email: 'fiscal@revenda.com.br',
      address: {
        postalCode: '80010000',
        street: 'Rua Das Flores',
        number: '100',
        complement: 'Sala 2',
        district: 'Centro',
        cityCode: '4106902',
        cityName: 'Curitiba',
        state: 'PR',
      },
    })
  })

  test('not found, offline or alphanumeric: null', async () => {
    expect(await lookupCnpj('11222333000181', reply({ message: 'x' }, false))).toBeNull()
    expect(await lookupCnpj('11222333000181', vi.fn(async () => Promise.reject(new Error('offline'))))).toBeNull()
    const never = reply({})
    expect(await lookupCnpj('12ABC34501DE35', never)).toBeNull()
    expect(never).not.toHaveBeenCalled()
  })
})

describe('lookupPostalCode', () => {
  test('street, district, city with the IBGE code and UF', async () => {
    const fetcher = reply({ logradouro: 'Avenida Paulista', bairro: 'Bela Vista', localidade: 'São Paulo', uf: 'SP', ibge: '3550308' })
    const address = await lookupPostalCode('01310100', fetcher)
    expect(fetcher).toHaveBeenCalledWith('https://viacep.com.br/ws/01310100/json/')
    expect(address).toMatchObject({ postalCode: '01310100', street: 'Avenida Paulista', district: 'Bela Vista', cityName: 'São Paulo', cityCode: '3550308', state: 'SP' })
  })

  test('a CEP that does not exist or is short: null', async () => {
    expect(await lookupPostalCode('99999999', reply({ erro: 'true' }))).toBeNull()
    expect(await lookupPostalCode('123', reply({}))).toBeNull()
  })
})

describe('rules', () => {
  test('a CPF/CNPJ lives in one customer, in any format, never the one being saved', () => {
    const list = [
      { id: 'a', taxId: '11222333000181' },
      { id: 'b', taxId: '52998224725' },
    ]
    expect(findByTaxId(list, '11.222.333/0001-81', 'x')?.id).toBe('a')
    expect(findByTaxId(list, '529.982.247-25')?.id).toBe('b')
    expect(findByTaxId(list, '11222333000181', 'a')).toBeNull()
    expect(findByTaxId(list, '')).toBeNull()
  })

  test('"Emitir nota sozinha" shows only when the nota goes out by itself and follows the mode', () => {
    expect(showAutoIssue({ enabled: true, autoIssue: 'never' })).toBe(false)
    expect(showAutoIssue({ enabled: false, autoIssue: 'allOrders' })).toBe(false)
    expect(autoIssueOf({ enabled: true, autoIssue: 'selectedCustomers' }, null)).toBe(false)
    expect(autoIssueOf({ enabled: true, autoIssue: 'allOrders' }, undefined)).toBe(true)
    expect(autoIssueOf({ enabled: true, autoIssue: 'allOrders' }, false)).toBe(false)
    expect(parseAutoIssue('paid')).toBe('never')
  })

  test('CEP mask', () => {
    expect(formatPostalCode('80010000')).toBe('80010-000')
    expect(formatPostalCode('800')).toBe('800')
    expect(formatPostalCode(null)).toBe('')
  })
})
