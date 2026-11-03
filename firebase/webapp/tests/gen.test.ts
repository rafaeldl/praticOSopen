import { describe, expect, test } from 'vitest'
import { compileAll, compileIcu, mergeWeb, messagesOf, parityProblems, placeholdersOf, usedKeys } from '../scripts/gen-lib.mjs'
import { detectLocale, render, type Compiled } from '../src/i18n'

const show = (source: string, params = {}, locale = 'pt') => render(compileIcu(source) as Compiled, params, locale)

describe('ICU compiler', () => {
  test('plain text stays a string', () => {
    expect(compileIcu('Salvar')).toBe('Salvar')
  })

  test('placeholders', () => {
    expect(show('Olá, {name}!', { name: 'Ana' })).toBe('Olá, Ana!')
  })

  test('plural with a number inside and before the branches', () => {
    const source = '{count} {count, plural, =1{item} other{itens}}'
    expect(show(source, { count: 1 })).toBe('1 item')
    expect(show(source, { count: 5 })).toBe('5 itens')
  })

  test('nested placeholder in a branch', () => {
    const source = '{count, plural, =1{1 cliente} other{{count} clientes}}'
    expect(show(source, { count: 1 })).toBe('1 cliente')
    expect(show(source, { count: 3 })).toBe('3 clientes')
  })

  test('# and plural categories follow the locale', () => {
    const source = '{count, plural, one{# item} other{# items}}'
    expect(show(source, { count: 1 }, 'en')).toBe('1 item')
    expect(show(source, { count: 2 }, 'en')).toBe('2 items')
  })

  test('select', () => {
    const source = '{kind, select, a{Alfa} other{Outro}}'
    expect(show(source, { kind: 'a' })).toBe('Alfa')
    expect(show(source, { kind: 'z' })).toBe('Outro')
  })

  test('broken messages fail the build', () => {
    expect(() => compileIcu('{count, plural, =1{x}}', 'k')).toThrow(/other/)
    expect(() => compileIcu('fim }', 'k')).toThrow(/sobrando/)
    expect(() => compileIcu('{count, date}', 'k')).toThrow(/não suportado/)
  })

  test('lists placeholders of nested branches', () => {
    expect(placeholdersOf(compileIcu('{a} {n, plural, other{{b}}}'))).toEqual(['a', 'b', 'n'])
  })
})

describe('language parity', () => {
  test('a key missing in one language is a failure', () => {
    const problems = parityProblems({ pt: { a: '1', b: '2' }, en: { a: '1' }, es: { a: '1', b: '2' } }, 'ARB')
    expect(problems).toEqual(['ARB: faltam em en: b'])
  })

  test('different placeholders are a failure', () => {
    const { problems } = compileAll({ pt: { a: 'Oi {x}' }, en: { a: 'Hi {y}' } }, 'ARB')
    expect(problems).toEqual(['ARB: parâmetros diferentes em a (pt × en)'])
  })

  test('ARB metadata is not a message', () => {
    expect(messagesOf({ '@@locale': 'pt', a: 'x', '@a': {}, _note: 'y' })).toEqual({ a: 'x' })
  })

  test('web keys cannot shadow the app', () => {
    expect(mergeWeb({ save: 'x' }, { save: 'y' }).problems).toEqual([
      'chave web sem prefixo "web.": save',
      'chave web repete chave do app: save',
    ])
    expect(mergeWeb({ save: 'x' }, { 'web.a': 'y' }).problems).toEqual([])
  })
})

test('pruning finds literal keys in code and templates', () => {
  const keys = usedKeys([`t('save')`, `{{ t("close") }}`, 'label: \'web.a.b\''])
  expect([...keys]).toEqual(['save', 'close', 'web.a.b'])
})

test('language detection falls back to Portuguese', () => {
  expect(detectLocale(['en-GB', 'pt-BR'])).toBe('en')
  expect(detectLocale(['fr', 'es-MX'])).toBe('es')
  expect(detectLocale(['fr'])).toBe('pt')
})
