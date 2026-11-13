<script setup lang="ts">
// The assistant over several orders (order.ai.batch, WEB_APP_DESIGN rule 9): the
// same route as one order (POST /v1/app/ai/order-assist), asked once per order.
// It only proposes: the list shows what each order would get, and nothing is
// written before "Aplicar". It only adds catalog items (as on one order); it
// never receives, cancels nor deletes. Each order is one request of the month's
// quota, so the batch is refused up front when the quota cannot cover it.
import { computed, onMounted, ref, shallowRef } from 'vue'
import Layer from '@/components/Layer.vue'
import { t } from '@/i18n'
import { ApiError, errorMessageKey } from '@/lib/api'
import { formatMoney } from '@/lib/format'
import { askAssistant, assistStatus, type DraftItem } from '@/lib/orders/assistant'
import { orderChanged } from '@/lib/orders/bus'
import type { Order } from '@/lib/orders/model'
import { orderShort, ordersShort } from '@/lib/orders/text'
import * as writes from '@/lib/orders/writes'
import { ordersForPrint } from '@/lib/receive/data'
import { can, session } from '@/lib/session'
import { showToast } from '@/lib/toast'
import { announce } from '@/lib/ui'
import '@/styles/receive.css'

/** A batch the person can still read through before applying. */
const MAX_AI_BATCH = 10

const props = defineProps<{ orders: Order[] }>()
const emit = defineEmits<{ close: []; done: [] }>()

const text = ref('')
const left = ref<number | null>(null)
const state = ref<'ask' | 'reading' | 'plan' | 'saving'>('ask')
const note = ref('')
const plan = shallowRef<{ order: Order; items: DraftItem[] }[]>([])
const title = computed(() => t('web.ai.batchTitle', { count: props.orders.length, order: ordersShort(props.orders.length) }))
const tooMany = computed(() => props.orders.length > MAX_AI_BATCH)
const short = computed(() => left.value !== null && left.value < props.orders.length)
const ready = computed(() => state.value === 'ask' && !!text.value.trim() && !tooMany.value && !short.value)
const withItems = computed(() => plan.value.filter((entry) => entry.items.length))
const country = () => session.company?.country

onMounted(async () => {
  try {
    const status = await assistStatus()
    if (status.usage && status.usage.limit > 0) {
      left.value = Math.max(0, status.usage.limit - status.usage.used)
    }
  } catch {
    // The bar only shows with the assistant on; a failed read here is said on Preparar.
  }
})

function errorNote(error: unknown): string {
  if (error instanceof ApiError && error.code === 'AI_DISABLED') return t('orderAssistantErrorDisabled')
  if (error instanceof ApiError && error.code === 'AI_QUOTA_EXCEEDED' && error.details?.period === 'day') return t('orderAssistantErrorQuotaDay')
  if (error instanceof ApiError && error.code === 'AI_QUOTA_EXCEEDED') return t('orderAssistantErrorQuota')
  return t('orderAssistantErrorUnavailable')
}

async function prepare() {
  if (!ready.value) return
  state.value = 'reading'
  note.value = ''
  const value = text.value.trim()
  try {
    // The items of each order, as the assistant reads them on one order.
    const full = await ordersForPrint(props.orders.map((o) => o.id), props.orders[0]?.showsMoney ?? false)
    const result: { order: Order; items: DraftItem[] }[] = []
    for (const order of full) {
      try {
        const draft = await askAssistant(value, order)
        if (draft.usage && draft.usage.limit > 0) left.value = Math.max(0, draft.usage.limit - draft.usage.used)
        result.push({ order, items: draft.items.filter((item) => item.catalogId) })
      } catch (error) {
        // Quota or the model out: stop, show what was prepared and why the rest was not.
        note.value = errorNote(error)
        break
      }
    }
    plan.value = result
    state.value = result.length ? 'plan' : 'ask'
    if (result.length && !withItems.value.length && !note.value) note.value = t('orderAssistantNothingFound')
  } catch (error) {
    console.warn('ai batch: orders not read', error)
    note.value = t('web.error.generic')
    state.value = 'ask'
  }
}

async function apply() {
  // One run only: a second click while it saves does nothing (B1).
  if (state.value !== 'plan') return
  state.value = 'saving'
  const added: { order: Order; ids: string[]; version: string | null | undefined }[] = []
  const failures: string[] = []
  for (const { order, items } of withItems.value) {
    const ids: string[] = []
    let version = order.version
    try {
      for (const item of items) {
        const response = await writes.addItem(
          order.id,
          {
            kind: item.kind,
            catalogId: item.catalogId as string,
            ...(can('editPrices') && item.value !== null ? { value: item.value } : {}),
            ...(item.kind === 'product' ? { quantity: Math.max(1, Math.round(item.quantity || 1)) } : {}),
          },
          version,
        )
        if (response.itemId) ids.push(response.itemId)
        const fresh = writes.orderOf(response, order.showsMoney)
        if (fresh) {
          version = fresh.version
          orderChanged(fresh)
        }
      }
    } catch (error) {
      console.warn('ai batch: order not changed', order.id, error)
      failures.push(t('web.batch.failedOne', { order: `${orderShort()} ${order.number ?? ''}`, reason: t(errorMessageKey(error)) }))
    }
    if (ids.length) added.push({ order, ids, version })
  }
  const changed = added.length
  const failed = failures.length
  const message = failed ? [t('web.batch.partial', { changed, failed }), ...failures.slice(0, 3)].join(' ') : t('web.batch.done', { count: changed })
  showToast(message, added.length ? { undo: () => void undo(added) } : {})
  announce(message)
  emit('done')
}

async function undo(added: { order: Order; ids: string[]; version: string | null | undefined }[]) {
  let failed = 0
  for (const entry of added) {
    let version = entry.version
    for (const id of entry.ids) {
      try {
        const fresh = writes.orderOf(await writes.removeItem(entry.order.id, id, version), entry.order.showsMoney)
        if (fresh) {
          version = fresh.version
          orderChanged(fresh)
        }
      } catch (error) {
        console.warn('ai batch: undo refused', entry.order.id, error)
        failed++
      }
    }
  }
  showToast(failed ? t('web.batch.undoPartial', { count: failed }) : t('web.batch.undone'))
}

const itemText = (item: DraftItem) =>
  `+ ${item.name}${item.kind === 'product' && item.quantity > 1 ? ` × ${item.quantity}` : ''}${can('viewPrices') && typeof item.value === 'number' ? ` · ${formatMoney(item.value, country())}` : ''}`
</script>

<template>
  <Layer kind="sheet" :label="title" :guard="() => state !== 'saving' && state !== 'reading'" @close="emit('close')">
    <template #default="{ close }">
      <div class="layer-head">
        <h2 class="layer-title"><span class="ai" aria-hidden="true">✦</span> {{ title }}</h2>
        <p class="sub">{{ t('web.ai.batchSub') }}</p>
      </div>
      <div class="layer-body">
        <template v-if="state === 'ask' || state === 'reading'">
          <label class="field-label" for="ai-batch-text">{{ t('web.ai.batchAsk') }}</label>
          <textarea id="ai-batch-text" v-model="text" class="field" rows="3" :placeholder="t('web.ai.batchPlaceholder')" :disabled="state === 'reading'"></textarea>
          <p v-if="tooMany" class="sub" role="status">{{ t('web.ai.batchTooMany', { max: MAX_AI_BATCH, order: orderShort() }) }}</p>
          <p v-else-if="left !== null && short" class="sub" role="status">{{ t('web.ai.batchQuota', { count: left, order: ordersShort(2) }) }}</p>
          <p v-else-if="left !== null" class="sub">{{ t('web.ai.batchUses', { count: orders.length, left }) }}</p>
          <p v-if="state === 'reading'" role="status">{{ t('web.ai.batchReading') }}</p>
        </template>
        <ul v-else class="batch-lines" data-testid="ai-batch-plan">
          <li v-for="entry in plan" :key="entry.order.id" class="ai-plan-row">
            <strong>{{ orderShort() }} {{ entry.order.number }} · {{ entry.order.customer?.name }}</strong>
            <span v-for="(item, i) in entry.items" :key="i" class="ai-plan-item"><span class="ai" aria-hidden="true">✦</span> {{ itemText(item) }}</span>
            <span v-if="!entry.items.length" class="muted">{{ t('web.ai.batchNothing') }}</span>
          </li>
        </ul>
        <p v-if="note" class="sub" role="status">{{ note }}</p>
      </div>
      <div class="layer-foot">
        <button type="button" class="btn" data-autofocus @click="close()">{{ t('web.batch.notNow') }}</button>
        <button v-if="state === 'ask' || state === 'reading'" type="button" class="btn btn--primary" :disabled="!ready" @click="prepare">{{ t('web.ai.batchPrepare') }}</button>
        <button v-else type="button" class="btn btn--primary" :disabled="state === 'saving' || !withItems.length" @click="apply">
          {{ t('web.ai.batchApply', { count: withItems.length, order: ordersShort(withItems.length) }) }}
        </button>
      </div>
    </template>
  </Layer>
</template>
