// The board's card keeps the focus when a live update redraws it (orders-list.spec.ts,
// "quadro como aba da lista"): the listener's first answer can come after a move and
// take the card back to its old column for a moment.
import { mount } from '@vue/test-utils'
import { describe, expect, test } from 'vitest'
import { defineComponent, h, nextTick, ref, withDirectives, type Directive } from 'vue'
import { useHeldFocus } from '../src/lib/held-focus'

// Chrome blurs the focused card while removing it, still connected.
const blurOnRemove: Directive<HTMLElement> = {
  beforeUnmount: (el) => {
    if (document.activeElement === el) el.dispatchEvent(new FocusEvent('focusout', { bubbles: true }))
  },
}
const card = () => withDirectives(h('button', { id: 'card-a', class: 'card-open' }, 'A'), [[blurOnRemove]])

const Columns = defineComponent({
  setup(_, { expose }) {
    const where = ref<'left' | 'right'>('left')
    const focus = useHeldFocus('card-', 'card-open', where)
    expose({ where, focus })
    return () =>
      h('div', [
        h('ul', { class: 'left' }, where.value === 'left' ? [card()] : []),
        h('ul', { class: 'right' }, where.value === 'right' ? [card()] : []),
        h('button', { id: 'other' }, 'Other'),
      ])
  },
})

async function board() {
  const wrapper = mount(Columns, { attachTo: document.body })
  const vm = wrapper.vm as unknown as { where: 'left' | 'right'; focus: { hold: (id: string) => void } }
  return { wrapper, vm }
}

describe('held focus on a redrawn card', () => {
  test('the card back in a new element gets the focus again', async () => {
    const { wrapper, vm } = await board()
    document.getElementById('card-a')!.focus()
    vm.where = 'right'
    await nextTick()
    expect(document.activeElement?.id).toBe('card-a')
    expect(wrapper.get('.right').element.contains(document.activeElement)).toBe(true)
    vm.where = 'left'
    await nextTick()
    expect(wrapper.get('.left').element.contains(document.activeElement)).toBe(true)
    // Held across more than one redraw (back to the old column, then to the new one).
    vm.where = 'right'
    await nextTick()
    expect(wrapper.get('.right').element.contains(document.activeElement)).toBe(true)
    wrapper.unmount()
  })

  test('a card held after a move gets it back after the redraw', async () => {
    const { wrapper, vm } = await board()
    vm.focus.hold('a')
    vm.where = 'right'
    await nextTick()
    expect(document.activeElement?.id).toBe('card-a')
    wrapper.unmount()
  })

  test('leaving the card by hand lets it go', async () => {
    const { wrapper, vm } = await board()
    document.getElementById('card-a')!.focus()
    document.getElementById('other')!.focus()
    vm.where = 'right'
    await nextTick()
    expect(document.activeElement?.id).toBe('other')
    document.getElementById('other')!.blur()
    vm.where = 'left'
    await nextTick()
    expect(document.activeElement?.id).not.toBe('card-a')
    wrapper.unmount()
  })
})
