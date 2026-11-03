import { mount } from '@vue/test-utils'
import { describe, expect, test } from 'vitest'
import { defineComponent, h, nextTick } from 'vue'
import { createMemoryHistory, createRouter } from 'vue-router'
import Layer from '../src/components/Layer.vue'

const flush = async () => {
  for (let i = 0; i < 5; i++) {
    await nextTick()
    await new Promise((resolve) => setTimeout(resolve, 0))
  }
}

async function setup(guard: () => boolean) {
  const router = createRouter({ history: createMemoryHistory(), routes: [{ path: '/', component: { render: () => null } }] })
  await router.push('/')
  const host = defineComponent({
    setup: () => () => h(Layer, { label: 'Teste', guard }, { default: () => h('button', 'Ok') }),
  })
  const wrapper = mount(host, { global: { plugins: [router] }, attachTo: document.body })
  await flush()
  return { router, wrapper, layer: wrapper.findComponent(Layer) }
}

describe('Layer', () => {
  test('renders at the end of body and makes the rest inert', async () => {
    const app = document.createElement('div')
    app.id = 'app-test'
    document.body.appendChild(app)
    const { wrapper } = await setup(() => true)
    expect(document.body.lastElementChild?.classList.contains('layer')).toBe(true)
    expect(app.hasAttribute('inert')).toBe(true)
    wrapper.unmount()
    expect(app.hasAttribute('inert')).toBe(false)
    app.remove()
  })

  test('a close outside the history still asks the guard', async () => {
    let asked = 0
    const { router, layer, wrapper } = await setup(() => {
      asked++
      return false
    })
    // The URL lost the layer some other way (replace): Cancel must not skip the guard.
    await router.replace('/')
    await flush()
    const emittedBefore = layer.emitted('close')?.length ?? 0
    await (layer.vm as unknown as { close: () => Promise<void> }).close()
    expect(asked).toBeGreaterThan(0)
    expect(layer.emitted('close')?.length ?? 0).toBe(emittedBefore)
    wrapper.unmount()
  })

  test('Voltar with the guard saying no keeps the layer open', async () => {
    const { router, layer, wrapper } = await setup(() => false)
    expect(String(router.currentRoute.value.query.layer ?? '')).not.toBe('')
    router.back()
    await flush()
    expect(layer.emitted('close')).toBeUndefined()
    wrapper.unmount()
  })
})
