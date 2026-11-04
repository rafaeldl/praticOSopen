// Faster by keyboard and by fewer decisions (docs/web-app/timed-comparison.md):
// the first option ready for Enter, arrows and first letter in a list of choices,
// typed dates ("amanhã 14h"), the payment method and the next step suggested by
// what was done before, and the palette's actions before the records.
import { mount } from '@vue/test-utils'
import { beforeAll, beforeEach, describe, expect, test, vi } from 'vitest'
import { computed, nextTick } from 'vue'
import Combobox from '../src/components/Combobox.vue'
import ChoiceList from '../src/components/ChoiceList.vue'
import { setLocale } from '../src/i18n'
import { paletteGroups } from '../src/lib/palette-order'
import { parseQuickWhen, shiftWhen } from '../src/lib/quick-when'
import { preferredStep, rememberMethod, rememberTransition, suggestedMethod } from '../src/lib/orders/suggest'
import { keyOf, registerShortcut, shortcutRows } from '../src/lib/shortcuts'

vi.mock('../src/lib/firebase', () => ({ firestoreClient: vi.fn() }))

beforeAll(() => setLocale('pt'))
beforeEach(() => localStorage.clear())

const groups = () => [
  { title: 'Recentes', items: [{ id: 'c3', label: 'Cliente 03' }, { id: 'c1', label: 'Cliente 01' }] },
  { title: 'Clientes', items: [{ id: 'c2', label: 'Cliente 02' }] },
]

function combo(props: Record<string, unknown> = {}) {
  return mount(Combobox, { props: { id: 'cb', label: 'Cliente', groups, ...props }, attachTo: document.body })
}

describe('Combobox: the first option is ready for Enter', () => {
  test('empty field: the first suggestion is active and Enter picks it', async () => {
    const wrapper = combo()
    const input = wrapper.get('input')
    await input.trigger('focus')
    await nextTick()
    expect(input.attributes('aria-activedescendant')).toBe('cb-opt-0')
    await input.trigger('keydown', { key: 'Enter' })
    expect(wrapper.emitted('pick')?.[0]?.[0]).toMatchObject({ id: 'c3' })
    wrapper.unmount()
  })

  test('the current choice (✓) is the active one, so Enter keeps it', async () => {
    const wrapper = combo({ selectedId: 'c2' })
    const input = wrapper.get('input')
    await input.trigger('focus')
    await nextTick()
    expect(input.attributes('aria-activedescendant')).toBe('cb-opt-2')
    wrapper.unmount()
  })

  test('an optional field (skippable) keeps Enter for "next" when nothing is suggested', async () => {
    const wrapper = combo({ skippable: true })
    const input = wrapper.get('input')
    await input.trigger('focus')
    await nextTick()
    expect(input.attributes('aria-activedescendant')).toBeUndefined()
    await input.trigger('keydown', { key: 'Enter' })
    expect(wrapper.emitted('pick')).toBeUndefined()
    expect(wrapper.emitted('next')).toHaveLength(1)
    wrapper.unmount()
  })
})

describe('ChoiceList: arrows and first letter', () => {
  const choices = [
    { id: 'quote', label: 'Orçamento' },
    { id: 'approved', label: 'Aprovado', current: true },
    { id: 'progress', label: 'Em andamento' },
    { id: 'done', label: 'Concluído' },
  ]
  const list = (extra: Record<string, unknown> = {}) => mount(ChoiceList, { props: { label: 'Qual a situação?', choices, ...extra }, attachTo: document.body })
  const focusedText = () => (document.activeElement as HTMLElement | null)?.textContent?.trim()
  const press = async (key: string) => {
    document.activeElement!.dispatchEvent(new KeyboardEvent('keydown', { key, bubbles: true, cancelable: true }))
    await nextTick()
  }

  test('↓ and ↑ move between the options, Home and End go to the ends', async () => {
    const wrapper = list()
    ;(wrapper.findAll('button')[0]!.element as HTMLElement).focus()
    await press('ArrowDown')
    expect(focusedText()).toContain('Aprovado')
    await press('ArrowUp')
    expect(focusedText()).toContain('Orçamento')
    await press('End')
    expect(focusedText()).toContain('Concluído')
    await press('Home')
    expect(focusedText()).toContain('Orçamento')
    wrapper.unmount()
  })

  test('a letter goes to the option that starts with it, ignoring accents', async () => {
    const wrapper = list()
    ;(wrapper.findAll('button')[0]!.element as HTMLElement).focus()
    await press('c')
    expect(focusedText()).toContain('Concluído')
    await press('o')
    expect(focusedText()).toContain('Orçamento')
    wrapper.unmount()
  })

  test('the suggested option takes the first focus', () => {
    const wrapper = list({ suggested: 'done' })
    const marked = wrapper.findAll('button').filter((b) => b.attributes('data-autofocus') !== undefined)
    expect(marked.map((b) => b.text())).toEqual([expect.stringContaining('Concluído')])
    wrapper.unmount()
  })
})

describe('parseQuickWhen: typed day and time', () => {
  // Tuesday, 3 Nov 2026, 10:00 on the company's clock.
  const now = { y: 2026, m: 11, d: 3, h: 10, min: 0 }
  const current = '2026-11-04T14:00'
  test.each([
    ['amanhã', '2026-11-04T14:00'],
    ['amanha 9h', '2026-11-04T09:00'],
    ['hoje 18:30', '2026-11-03T18:30'],
    ['+3', '2026-11-06T14:00'],
    ['+7 8:30', '2026-11-10T08:30'],
    ['+7 8h30', '2026-11-10T08:30'],
    ['seg 14h', '2026-11-09T14:00'],
    ['qui 8', '2026-11-05T08:00'],
    ['sex 8:30', '2026-11-06T08:30'],
    ['sáb', '2026-11-07T14:00'],
    ['ter', '2026-11-10T14:00'],
    ['9/12 14h', '2026-12-09T14:00'],
    ['9/1', '2027-01-09T14:00'],
    ['9/5/2030 8:30', '2030-05-09T08:30'],
    ['15h', '2026-11-04T15:00'],
    ['tomorrow 9', '2026-11-04T09:00'],
    ['mañana 9h', '2026-11-04T09:00'],
    ['lun 14h', '2026-11-09T14:00'],
  ])('%s → %s', (text, expected) => {
    expect(parseQuickWhen(text, now, current)).toBe(expected)
  })

  test('without a time and without one before, 9:00', () => {
    expect(parseQuickWhen('amanhã', now, '')).toBe('2026-11-04T09:00')
  })

  test('English order is month/day, and 2pm', () => {
    expect(parseQuickWhen('12/9 2pm', now, current, 'en')).toBe('2026-12-09T14:00')
  })

  test.each(['', 'xyz', '25h', '31/2', '+', 'seg seg'])('%s is not understood', (text) => {
    expect(parseQuickWhen(text, now, current)).toBeNull()
  })

  test('arrows: a day or half an hour', () => {
    expect(shiftWhen('2026-11-30T14:00', 'day', 1)).toBe('2026-12-01T14:00')
    expect(shiftWhen('2026-11-04T14:00', 'day', -1)).toBe('2026-11-03T14:00')
    expect(shiftWhen('2026-11-04T23:30', 'time', 1)).toBe('2026-11-05T00:00')
    expect(shiftWhen('2026-11-04T08:00', 'time', -1)).toBe('2026-11-04T07:30')
  })
})

describe('suggestions from what was done before', () => {
  test("payment method: the order's last payment, then the last one used here, else none", () => {
    expect(suggestedMethod({ transactions: [] }, 'c1')).toBe('')
    rememberMethod('c1', 'cash')
    expect(suggestedMethod({ transactions: [] }, 'c1')).toBe('cash')
    expect(suggestedMethod({ transactions: [{ type: 'payment', amount: 10, paymentMethod: 'pix' }, { type: 'discount', amount: 5 }] }, 'c1')).toBe('pix')
    expect(suggestedMethod({ transactions: [] }, 'other-company')).toBe('')
  })

  test('next step: after Aprovado, what this person did last time, if it moves forward and is allowed', () => {
    expect(preferredStep('c1', 'approved', ['progress', 'done', 'canceled'])).toBeNull()
    rememberTransition('c1', 'approved', 'done')
    expect(preferredStep('c1', 'approved', ['progress', 'done', 'canceled'])).toBe('done')
    expect(preferredStep('c1', 'approved', ['progress', 'canceled'])).toBeNull()
    // Going back or canceling is never remembered as the next step.
    rememberTransition('c1', 'approved', 'quote')
    rememberTransition('c1', 'approved', 'canceled')
    expect(preferredStep('c1', 'approved', ['progress', 'done', 'quote', 'canceled'])).toBe('done')
  })
})

describe('next step memory follows at once (CI #538: the page left before the server answered)', () => {
  test('a screen showing the step sees the memory as soon as it is written, with no reload', () => {
    const shown = computed(() => preferredStep('c1', 'approved', ['progress', 'done']))
    expect(shown.value).toBeNull()
    rememberTransition('c1', 'approved', 'done')
    expect(shown.value).toBe('done')
  })

  test('written when chosen; a refused write puts the previous memory back', () => {
    rememberTransition('c1', 'approved', 'progress')
    const undo = rememberTransition('c1', 'approved', 'done')
    expect(preferredStep('c1', 'approved', ['progress', 'done'])).toBe('done')
    undo()
    expect(preferredStep('c1', 'approved', ['progress', 'done'])).toBe('progress')
  })
})

describe('palette: actions before the records when the text names an action', () => {
  const cmd = (id: string, text: string) => ({ id, label: 'search' as const, text, run: () => {} })
  test('"cli" puts "Novo cliente" and "Ir para Clientes" before the customers', () => {
    const result = paletteGroups('cli', [cmd('customer:1', 'Cliente 01'), cmd('new-customer', 'Novo cliente'), cmd('go:/customers', 'Ir para Clientes')])
    expect(result.map((entry) => entry.group)).toEqual(['actions', 'customers'])
  })
  test('a number keeps the orders first', () => {
    const result = paletteGroups('501', [cmd('order:1', 'OS 501'), cmd('customer:1', 'Cliente 501')])
    expect(result.map((entry) => entry.group)).toEqual(['orders', 'customers'])
  })
  test('the new-record offer comes last', () => {
    const result = paletteGroups('Joana', [cmd('create:customer', 'Cadastrar cliente «Joana»'), cmd('customer:1', 'Joana Silva')])
    expect(result.map((entry) => entry.group)).toEqual(['customers', 'create'])
  })
})

describe('shortcuts', () => {
  test('"-" is a key of its own (discount)', () => {
    expect(keyOf(new KeyboardEvent('keydown', { key: '-' }))).toBe('-')
  })
  test('keys that share a row in the help (0–9) show once', () => {
    const removers = ['1', '2', '3'].map((key) => registerShortcut({ keys: key, label: 'web.shortcuts.findNumber', display: '0–9', run: () => {} }))
    expect(shortcutRows().filter((row) => row.label === 'web.shortcuts.findNumber')).toEqual([{ label: 'web.shortcuts.findNumber', keys: '0–9' }])
    removers.forEach((remove) => remove())
  })
})
