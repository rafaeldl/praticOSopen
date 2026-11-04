<script setup lang="ts">
// Falar in the assistant's bar (order.ai.talk, .cancel-talk, .stop-fill,
// order.new.assistant-bar), on the open order and on the Nova OS. The
// microphone is asked for only on Falar; the recorder (talk.ts) loads only then.
// While it listens: "Cancelar" throws the audio away, "Parar e preencher" sends
// it. A browser that cannot record shows no Falar: the text box stays.
import { computed, nextTick, onBeforeUnmount, ref, shallowRef } from 'vue'
import { Mic } from '@lucide/vue'
import { t } from '@/i18n'
import type { TalkHandle } from '@/lib/orders/talk'
import { talkSupported } from '@/lib/orders/talk-support'
import { deviceLabel } from '@/lib/orders/text'
import { announce } from '@/lib/ui'

defineProps<{ disabled?: boolean }>()
const emit = defineEmits<{ audio: [audio: { mimeType: string; data: string }]; note: [text: string]; listening: [on: boolean] }>()

const supported = talkSupported()
const phase = ref<'idle' | 'starting' | 'listening'>('idle')
const heard = ref(false)
const seconds = ref(0)
const handle = shallowRef<TalkHandle | null>(null)
const stopButton = ref<HTMLButtonElement | null>(null)
const talkButton = ref<HTMLButtonElement | null>(null)
let clock: ReturnType<typeof setInterval> | null = null
const elapsed = computed(() => `${Math.floor(seconds.value / 60)}:${String(seconds.value % 60).padStart(2, '0')}`)

function setPhase(next: typeof phase.value) {
  phase.value = next
  emit('listening', next !== 'idle')
}

async function talk() {
  if (phase.value !== 'idle') return
  setPhase('starting')
  emit('note', '')
  heard.value = false
  seconds.value = 0
  try {
    const { startTalk } = await import('@/lib/orders/talk')
    const current = await startTalk({ onHeard: () => (heard.value = true) })
    handle.value = current
    setPhase('listening')
    announce(t('speechListening'))
    clock = setInterval(() => seconds.value++, 1000)
    await nextTick()
    stopButton.value?.focus()
    const end = await current.done
    if (end.kind === 'audio') emit('audio', end.audio)
    else if (end.kind === 'empty') emit('note', t('speechNothingHeard'))
    else if (end.kind === 'too-long') emit('note', t('web.assist.talkTooLong'))
    else if (end.kind === 'failed') emit('note', t('web.assist.micFailed'))
  } catch (error) {
    const code = (error as { code?: string } | null)?.code
    emit('note', code === 'denied' ? t('web.assist.micDenied') : code === 'no-mic' ? t('web.assist.micMissing') : t('web.assist.micFailed'))
  } finally {
    if (clock) clearInterval(clock)
    clock = null
    handle.value = null
    setPhase('idle')
    await nextTick()
    talkButton.value?.focus()
  }
}

onBeforeUnmount(() => handle.value?.cancel())
</script>

<template>
  <template v-if="supported">
    <div v-if="phase === 'listening'" class="assist-talking" data-testid="assistant-listening" @keydown.esc.prevent="handle?.cancel()">
      <span class="assist-talking-status" role="status" :data-heard="heard ? 'true' : 'false'">
        <span class="assist-talking-dot" :class="{ 'is-heard': heard }" aria-hidden="true" />
        {{ t('speechListening') }} <span class="num">{{ elapsed }}</span>
      </span>
      <button type="button" class="btn" @click="handle?.cancel()">{{ t('speechCancel') }}</button>
      <button ref="stopButton" type="button" class="btn btn--primary" @click="handle?.stop()">{{ t('speechStopAndFill') }}</button>
    </div>
    <button
      v-else
      ref="talkButton"
      type="button"
      class="btn assist-talk"
      :title="t('speechHint', { device: deviceLabel().toLocaleLowerCase() })"
      :disabled="disabled || phase === 'starting'"
      data-testid="assistant-talk"
      @click="talk"
    >
      <Mic :size="16" aria-hidden="true" />
      {{ t('orderAssistantTalkShort') }}
    </button>
  </template>
</template>
