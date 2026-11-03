<script setup lang="ts">
// "Qual a situação?", "Quem é o responsável?", "Por que parou?": a question as
// the title, ✓ on the current one, destructive options last. Picking closes.
import { onBeforeUnmount, onMounted, ref } from 'vue'
import { t } from '@/i18n'
import Layer from '@/components/Layer.vue'

export interface Choice {
  id: string
  label: string
  sub?: string
  dot?: string
  current?: boolean
  danger?: boolean
}

const props = defineProps<{ title: string; sub?: string; choices: Choice[]; anchor?: HTMLElement | null }>()
// With an anchor it is a menu held under its button, not a box in the middle of the screen.
// Placed again after the layer opens and on resize: opening can still move the
// button (the panel settling), and the menu must stay held under it.
const place = () => {
  const rect = props.anchor?.getBoundingClientRect()
  return rect ? { top: `${Math.round(rect.bottom + 4)}px`, right: `${Math.max(8, Math.round(window.innerWidth - rect.right))}px` } : undefined
}
const boxStyle = ref(place())
const replace = () => (boxStyle.value = place())
let frame = 0
onMounted(() => {
  frame = requestAnimationFrame(replace)
  window.addEventListener('resize', replace)
})
onBeforeUnmount(() => {
  cancelAnimationFrame(frame)
  window.removeEventListener('resize', replace)
})
const emit = defineEmits<{ pick: [id: string]; close: [] }>()
</script>

<template>
  <Layer :kind="anchor ? 'menu' : 'sheet'" :box-style="boxStyle" :label="title" @close="emit('close')">
    <template #default="{ close }">
      <div class="layer-head">
        <h2 class="layer-title">{{ title }}</h2>
        <p v-if="sub" class="sub">{{ sub }}</p>
      </div>
      <div class="layer-body">
        <slot />
        <div class="opts" role="group" :aria-label="title">
          <button
            v-for="choice in choices"
            :key="choice.id"
            type="button"
            class="opt"
            :class="{ 'opt--danger': choice.danger }"
            :aria-current="choice.current ? 'true' : undefined"
            :data-autofocus="choice === choices[0] ? '' : undefined"
            @click="emit('pick', choice.id)"
          >
            <span v-if="choice.dot" class="dot" :class="`dot--${choice.dot}`" aria-hidden="true"></span>
            <span class="opt-main">
              <span>{{ choice.label }}</span>
              <small v-if="choice.sub" class="sub">{{ choice.sub }}</small>
            </span>
            <span v-if="choice.current" class="check-mark" aria-hidden="true">✓</span>
          </button>
        </div>
      </div>
      <div class="layer-foot">
        <button type="button" class="btn btn--ghost" @click="close()">{{ t('cancel') }}</button>
      </div>
    </template>
  </Layer>
</template>
