import { mount } from '@vue/test-utils'
import { beforeAll, describe, expect, test, vi } from 'vitest'
import { nextTick } from 'vue'
import MoneyInput from '../src/components/MoneyInput.vue'
import StatusLabel from '../src/components/StatusLabel.vue'
import { setLocale, t } from '../src/i18n'
import { commands, registerCommand, searchCommands } from '../src/lib/commands'
import { prefs } from '../src/lib/prefs'
import { handleShortcut, keyOf, registerShortcut } from '../src/lib/shortcuts'
import { currentToast, dismissToast, showToast, undoToast } from '../src/lib/toast'
import { ui } from '../src/lib/ui'

vi.mock('../src/lib/firebase', () => ({ firestoreClient: vi.fn() }))

beforeAll(() => setLocale('pt'))

function money(modelValue: number | null, country = 'BR') {
  return mount(MoneyInput, {
    props: { id: 'm', label: 'Preço', modelValue, country, 'onUpdate:modelValue': vi.fn() },
    attachTo: document.body,
  })
}

describe('MoneyInput', () => {
  test('shows the value with the country format and a decimal keyboard', () => {
    const input = money(1234.5).get('input')
    expect((input.element as HTMLInputElement).value).toBe('1.234,50')
    expect(input.attributes('inputmode')).toBe('decimal')
  })

  test('selects everything on focus, so typing replaces', async () => {
    const wrapper = money(90)
    const element = wrapper.get('input').element as HTMLInputElement
    const select = vi.spyOn(element, 'select')
    await wrapper.get('input').trigger('focus')
    expect(select).toHaveBeenCalled()
  })

  test.each([
    ['150', 150],
    ['100', 100],
    ['1,50', 1.5],
  ])('typing %s gives %d, no shift of cents', async (typed, value) => {
    const wrapper = money(90)
    await wrapper.get('input').trigger('focus')
    await wrapper.get('input').setValue(typed)
    await wrapper.get('input').trigger('blur')
    expect(wrapper.emitted('update:modelValue')?.at(-1)).toEqual([value])
  })

  test('nonsense keeps the old value and explains', async () => {
    const wrapper = money(90)
    await wrapper.get('input').setValue('abc')
    await wrapper.get('input').trigger('blur')
    expect(wrapper.emitted('update:modelValue')).toBeUndefined()
    expect(wrapper.get('input').attributes('aria-invalid')).toBe('true')
    expect(wrapper.text()).toContain(t('web.field.invalidMoney'))
  })

  test('negative is refused', async () => {
    const wrapper = money(90)
    await wrapper.get('input').setValue('-5')
    await wrapper.get('input').trigger('blur')
    expect(wrapper.emitted('update:modelValue')).toBeUndefined()
  })

  test('empty clears, unless required', async () => {
    const wrapper = money(90)
    await wrapper.get('input').setValue('')
    await wrapper.get('input').trigger('blur')
    expect(wrapper.emitted('update:modelValue')?.at(-1)).toEqual([null])
  })
})

describe('StatusLabel', () => {
  test('always has text next to the dot', () => {
    const wrapper = mount(StatusLabel, { props: { status: 'progress' } })
    expect(wrapper.get('.dot--warning').attributes('aria-hidden')).toBe('true')
    expect(wrapper.text()).toBe(t('statusInProgress'))
  })

  test('late wins and is marked', () => {
    const wrapper = mount(StatusLabel, { props: { status: 'progress', lateDays: 2 } })
    expect(wrapper.classes()).toContain('status--late')
    expect(wrapper.text()).toBe('Atrasada 2 dias')
  })
})

describe('Toast', () => {
  test('with Undo it does not leave by itself', () => {
    vi.useFakeTimers()
    showToast('x', { undo: () => {} })
    vi.advanceTimersByTime(600000)
    expect(currentToast.value?.message).toBe('x')
    dismissToast()
    vi.useRealTimers()
  })

  test('without Undo it leaves', () => {
    vi.useFakeTimers()
    showToast('x')
    vi.advanceTimersByTime(60000)
    expect(currentToast.value).toBeNull()
    vi.useRealTimers()
  })

  test('Undo runs and closes', () => {
    const undo = vi.fn()
    showToast('x', { undo })
    undoToast()
    expect(undo).toHaveBeenCalledOnce()
    expect(currentToast.value).toBeNull()
  })
})

describe('shortcuts', () => {
  const press = (key: string, init: KeyboardEventInit = {}, target: EventTarget = document.body) => {
    const event = new KeyboardEvent('keydown', { key, bubbles: true, cancelable: true, ...init })
    Object.defineProperty(event, 'target', { value: target })
    handleShortcut(event)
    return event
  }

  test('single key works outside fields, not inside', () => {
    const run = vi.fn()
    const remove = registerShortcut({ keys: 'n', label: 'save', run })
    press('n')
    expect(run).toHaveBeenCalledOnce()
    press('n', {}, document.createElement('input'))
    expect(run).toHaveBeenCalledOnce()
    remove()
  })

  test('can be turned off, WCAG 2.1.4', () => {
    const run = vi.fn()
    const remove = registerShortcut({ keys: 'n', label: 'save', run })
    prefs.singleKeyShortcuts = false
    press('n')
    expect(run).not.toHaveBeenCalled()
    prefs.singleKeyShortcuts = true
    remove()
  })

  test('layers stop them, unless global', () => {
    const local = vi.fn()
    const global = vi.fn()
    const removers = [
      registerShortcut({ keys: 'n', label: 'save', run: local }),
      registerShortcut({ keys: 'mod+k', label: 'save', global: true, run: global }),
    ]
    ui.layers = 1
    press('n')
    press('k', { ctrlKey: true })
    ui.layers = 0
    expect(local).not.toHaveBeenCalled()
    expect(global).toHaveBeenCalledOnce()
    removers.forEach((remove) => remove())
  })

  test('browser shortcuts are left alone', () => {
    const event = press('f', { ctrlKey: true })
    expect(event.defaultPrevented).toBe(false)
    expect(keyOf(new KeyboardEvent('keydown', { key: 'p', ctrlKey: true, shiftKey: true }))).toBeNull()
  })
})

describe('commands', () => {
  test('starts empty and receives commands', async () => {
    expect(commands.size).toBe(0)
    const remove = registerCommand({ id: 'x', label: 'save', run: () => {} })
    await nextTick()
    expect(searchCommands('', () => 'Salvar').map((c) => c.id)).toEqual(['x'])
    expect(searchCommands('sal', () => 'Salvar')).toHaveLength(1)
    expect(searchCommands('zzz', () => 'Salvar')).toHaveLength(0)
    remove()
    expect(commands.size).toBe(0)
  })
})
