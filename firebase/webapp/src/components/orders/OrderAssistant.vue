<script setup lang="ts">
// "Peça ao assistente" at the foot of the open order (order.ai.type). Only for
// who can edit the order's items (the app does not check: defect 3). Adds the
// catalog items it understood, marks them with ✦ and offers Undo; errors go in
// the note, never in an alert.
import { onMounted, ref } from 'vue'
import { t } from '@/i18n'
import { ApiError } from '@/lib/api'
import { askAssistant, assistStatus } from '@/lib/orders/assistant'
import { orderChanged } from '@/lib/orders/bus'
import type { Order } from '@/lib/orders/model'
import * as writes from '@/lib/orders/writes'
import { can } from '@/lib/session'
import { showToast } from '@/lib/toast'
import { announce } from '@/lib/ui'

const props = defineProps<{ order: Order }>()
const emit = defineEmits<{ added: [ids: string[]]; undone: [ids: string[]] }>()
const enabled = ref(false)
const text = ref('')
const reading = ref(false)
const note = ref('')
const usesLeft = ref<number | null>(null)

onMounted(async () => {
  try {
    const status = await assistStatus()
    enabled.value = status.enabled
    if (status.usage && status.usage.limit > 0 && status.usage.used >= status.usage.limit * 0.8) usesLeft.value = Math.max(0, status.usage.limit - status.usage.used)
  } catch {
    enabled.value = false
  }
})

function errorNote(error: unknown, limit?: number): string {
  if (error instanceof ApiError && error.code === 'AI_DISABLED') return t('orderAssistantErrorDisabled')
  if (error instanceof ApiError && error.code === 'AI_QUOTA_EXCEEDED') return t('orderAssistantErrorQuota', { limit: limit ?? 0 })
  return t('orderAssistantErrorUnavailable')
}

async function ask() {
  const value = text.value.trim()
  if (!value || reading.value) return
  reading.value = true
  note.value = ''
  try {
    const draft = await askAssistant(value, props.order)
    if (draft.usage && draft.usage.limit > 0 && draft.usage.used >= draft.usage.limit * 0.8) usesLeft.value = Math.max(0, draft.usage.limit - draft.usage.used)
    const items = draft.items.filter((item) => item.catalogId)
    if (!items.length) {
      note.value = t('orderAssistantNothingFound')
      return
    }
    const added: string[] = []
    let updatedAt = props.order.updatedAt
    for (const item of items) {
      const response = await writes.addItem(props.order.id, {
        kind: item.kind,
        catalogId: item.catalogId as string,
        ...(can('editPrices') && item.value !== null ? { value: item.value } : {}),
        ...(item.kind === 'product' ? { quantity: Math.max(1, Math.round(item.quantity || 1)) } : {}),
      }, updatedAt)
      if (response.itemId) added.push(response.itemId)
      const fresh = writes.orderOf(response, props.order.showsMoney)
      if (fresh) {
        updatedAt = fresh.updatedAt
        orderChanged(fresh)
      }
    }
    text.value = ''
    emit('added', added)
    note.value = t('orderAssistantApplied')
    announce(note.value)
    showToast(t('orderAssistantApplied'), {
      undo: () => {
        void (async () => {
          for (const id of added) await writes.removeItem(props.order.id, id).catch(() => {})
          emit('undone', added)
          note.value = ''
        })()
      },
    })
  } catch (error) {
    console.warn('assistant: failed', error)
    note.value = errorNote(error)
  } finally {
    reading.value = false
  }
}
</script>

<template>
  <div v-if="enabled" class="assist-bar" data-testid="assistant">
    <p v-if="note" class="assist-note small" role="status">{{ note }}</p>
    <p v-if="usesLeft !== null" class="assist-note small">{{ t('orderAssistantUsesLeft', { count: usesLeft }) }}</p>
    <form @submit.prevent="ask">
      <span class="ai" aria-hidden="true">✦</span>
      <label class="sr" for="od-assist">{{ t('web.order.askAssistant') }}</label>
      <input id="od-assist" v-model="text" class="field" maxlength="2000" :placeholder="t('web.order.askAssistantHint')" :disabled="reading" />
      <button type="submit" class="btn" :disabled="!text.trim() || reading">{{ reading ? t('web.order.reading') : t('web.order.send') }}</button>
    </form>
  </div>
</template>
