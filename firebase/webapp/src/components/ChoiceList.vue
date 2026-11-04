<script setup lang="ts">
// The options of a question ("Qual a situação?", the "…" menu): buttons in a
// group, with ↑/↓, Home/End and the first letter to move (as a menu does), and
// Enter or Space to pick. The suggested option takes the first focus.
import { ref } from 'vue'

export interface Choice {
  id: string
  label: string
  sub?: string
  dot?: string
  current?: boolean
  danger?: boolean
}

const props = defineProps<{ label: string; choices: Choice[]; suggested?: string | null }>()
const emit = defineEmits<{ pick: [id: string] }>()
const group = ref<HTMLElement | null>(null)

const first = () => props.choices.find((choice) => choice.id === props.suggested) ?? props.choices[0]
const fold = (text: string) => text.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase()

function onKeydown(event: KeyboardEvent) {
  if (event.ctrlKey || event.metaKey || event.altKey) return
  const buttons = [...(group.value?.querySelectorAll<HTMLButtonElement>('button.opt') ?? [])]
  const at = buttons.indexOf(document.activeElement as HTMLButtonElement)
  if (!buttons.length) return
  let next = -1
  if (event.key === 'ArrowDown') next = (at + 1) % buttons.length
  else if (event.key === 'ArrowUp') next = (at - 1 + buttons.length) % buttons.length
  else if (event.key === 'Home') next = 0
  else if (event.key === 'End') next = buttons.length - 1
  else if (event.key.length === 1 && /\p{L}|\p{N}/u.test(event.key)) {
    // The next option after this one that starts with the letter, going round.
    const letter = fold(event.key)
    for (let step = 1; step <= buttons.length; step++) {
      const index = (at + step + buttons.length) % buttons.length
      if (fold(props.choices[index]?.label ?? '').startsWith(letter)) {
        next = index
        break
      }
    }
  }
  if (next < 0) return
  event.preventDefault()
  buttons[next]?.focus()
}
</script>

<template>
  <div ref="group" class="opts" role="group" :aria-label="label" @keydown="onKeydown">
    <button
      v-for="choice in choices"
      :key="choice.id"
      type="button"
      class="opt"
      :class="{ 'opt--danger': choice.danger }"
      :aria-current="choice.current ? 'true' : undefined"
      :data-autofocus="choice === first() ? '' : undefined"
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
</template>
