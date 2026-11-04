<script setup lang="ts">
// "Peça ao assistente" at the foot of the open order (order.ai.type, .photo,
// .change-lines, .ask-line, .money-card). Only for who edits the order's items
// (the app does not check: defect 3). Applies at once through the item routes,
// marks with ✦ and offers Desfazer; errors go in the note, never in an alert.
// It never receives, cancels or deletes on its own: a line leaves only when the
// person asked ("tira a lavação"), and money waits for the "Confere?" card.
import { computed, onBeforeUnmount, onMounted, ref, shallowRef, watch } from 'vue'
import { ImagePlus } from '@lucide/vue'
import { t } from '@/i18n'
import { ApiError } from '@/lib/api'
import { contextOf, offerOf, planAiActions, type DraftActions, type NfseMoment } from '@/lib/orders/ai-actions'
import { noticeText } from '@/lib/orders/ai-actions-text'
import { changeTarget, dueFromDraft, noteKey, usesLeft as usesLeftOf, type AssistDraft, type DraftChange } from '@/lib/orders/assist-draft'
import { ASSIST_MAX_PHOTOS, assistPhoto } from '@/lib/orders/assist-photo'
import { askAssistant, assistStatus } from '@/lib/orders/assistant'
import { orderChanged } from '@/lib/orders/bus'
import type { Order, OrderLine } from '@/lib/orders/model'
import { money, orderShort } from '@/lib/orders/text'
import * as writes from '@/lib/orders/writes'
import { can, effectiveUseFinancial, session } from '@/lib/session'
import { currentToast, showToast } from '@/lib/toast'
import { announce, ui } from '@/lib/ui'
import AiActionsDialog from './AiActionsDialog.vue'
import AssistTalk from './AssistTalk.vue'
import ChoiceDialog from './ChoiceDialog.vue'

const props = defineProps<{ order: Order; pendingChecklists?: number }>()
/** hide/unhide: a line asked out leaves the screen at once and the server only hears it when the notice goes (as "Tirar" in the order). */
const emit = defineEmits<{ added: [ids: string[]]; undone: [ids: string[]]; hide: [ids: string[]]; unhide: [ids: string[]] }>()
const enabled = ref(false)
const text = ref('')
const reading = ref<'' | 'text' | 'photos' | 'speech'>('')
/** Falar is listening: the bar shows only Cancelar and Parar e preencher. */
const listening = ref(false)
const note = ref('')
const usesLeft = ref<number | null>(null)
/** The month's limit, for "Você já usou os {limit} pedidos" (from the last status or answer). */
const monthLimit = ref(0)
const canPhoto = computed(() => can('attachPhotos'))
/** "Qual Pintura?": the change waiting for the person to pick its line. */
const asking = shallowRef<{ change: DraftChange; lines: OrderLine[]; resolve: (line: OrderLine | null) => void } | null>(null)
/** The "Confere?" card: from this answer, or left by the Nova OS just saved (aiActionsAfterSave). */
const card = shallowRef<{ actions: DraftActions; nfse: NfseMoment | null; undoDraft: (() => Promise<void>) | null } | null>(null)

onMounted(async () => {
  try {
    const status = await assistStatus()
    enabled.value = status.enabled
    usesLeft.value = usesLeftOf(status.usage)
    monthLimit.value = Math.max(0, status.usage?.limit ?? 0)
  } catch {
    enabled.value = false
  }
  // Nova OS with money said: the card opens once the order exists (order.ai.money-card),
  // only with the assistant on and a step this person may take; otherwise the reason in the note.
  const left = ui.aiActionsFor
  if (left && left.orderId === props.order.id) {
    ui.aiActionsFor = null
    if (enabled.value) offer(left.actions, left.nfse, null)
  }
})

/** The card, or the reason in the note (offerOf). Returns whether the card opened. */
function offer(actions: DraftActions, nfse: NfseMoment | null, undoDraftFn: (() => Promise<void>) | null): boolean {
  const plan = planAiActions(actions, contextOf(props.order, session.role, session.uid, effectiveUseFinancial(), props.pendingChecklists ?? 0, nfse))
  const result = offerOf(plan)
  if (result.kind === 'card') {
    card.value = { actions, nfse, undoDraft: undoDraftFn }
    return true
  }
  if (result.notice) note.value = noticeText(result.notice)
  else if (!undoDraftFn) note.value = t('orderAssistantNothingFound')
  return false
}

// Lines asked out wait for the notice to go: Desfazer then writes nothing (no price is lost).
const pending: { orderId: string; ids: string[] }[] = []
const ownToasts = new Set<number>()
function commitRemovals() {
  for (const batch of pending.splice(0)) for (const id of batch.ids) void writes.removeItem(batch.orderId, id).catch((error) => {
    console.warn('assistant: line not removed', error)
    emit('unhide', [id])
    showToast(t('web.order.itemRemoveFailed'))
  })
}
watch(currentToast, (toast) => {
  if (pending.length && !(toast && ownToasts.has(toast.id))) commitRemovals()
})
onBeforeUnmount(commitRemovals)
function ownToast(message: string, undo?: () => void) {
  showToast(message, undo ? { undo } : {})
  if (currentToast.value) ownToasts.add(currentToast.value.id)
}

function errorNote(error: unknown): string {
  if (error instanceof ApiError && error.code === 'AI_DISABLED') return t('orderAssistantErrorDisabled')
  if (error instanceof ApiError && error.code === 'AI_QUOTA_EXCEEDED') return t('orderAssistantErrorQuota', { limit: monthLimit.value })
  return t('orderAssistantErrorUnavailable')
}

function pickLine(change: DraftChange, lines: OrderLine[]): Promise<OrderLine | null> {
  return new Promise((resolve) => (asking.value = { change, lines, resolve }))
}
function answered(id: string | null) {
  const current = asking.value
  asking.value = null
  current?.resolve(id === null ? null : (current.lines[Number(id)] ?? null))
}

interface Undo {
  added: string[]
  changed: { id: string; before: { value?: number | null; quantity?: number; description?: string | null } }[]
  removed: OrderLine[]
  due: boolean
}

const emptyUndo = (): Undo => ({ added: [], changed: [], removed: [], due: false })
const hasUndo = (undo: Undo) => undo.added.length + undo.changed.length + undo.removed.length > 0 || undo.due

/** Fills `undo` as each write lands, so an error halfway still undoes what was saved. */
async function apply(draft: AssistDraft, sent: Order, undo: Undo): Promise<{ filled: boolean; onlyChanges: boolean }> {
  let version = props.order.version
  const take = (response: Parameters<typeof writes.orderOf>[0]) => {
    const fresh = writes.orderOf(response, props.order.showsMoney)
    if (fresh) {
      version = fresh.version
      orderChanged(fresh)
    }
  }
  const lines = { services: sent.lines.filter((l) => l.kind === 'service'), products: sent.lines.filter((l) => l.kind === 'product') }
  // Changes first, on the lines that were sent (still in the order by id).
  for (const change of draft.changes) {
    let { line } = changeTarget(change, lines)
    if (!line) {
      const { candidates } = changeTarget(change, lines)
      line = candidates.length ? await pickLine(change, candidates) : null
    }
    if (!line?.id || !props.order.lines.some((l) => l.id === line?.id)) continue
    if (change.action === 'remove') {
      // The same line asked out twice is one removal.
      if (!undo.removed.some((l) => l.id === line?.id)) undo.removed.push(line)
      continue
    }
    const patch: { value?: number | null; quantity?: number; description?: string } = {}
    if (change.value !== undefined && can('editPrices')) patch.value = change.value
    if (change.quantity !== undefined && line.kind === 'product') patch.quantity = change.quantity
    if (change.description !== undefined) patch.description = change.description
    if (!Object.keys(patch).length) continue
    take(await writes.updateItem(props.order.id, line.id, patch, version))
    undo.changed.push({ id: line.id, before: { value: line.value, quantity: line.quantity, description: line.description ?? null } })
  }
  // New lines: catalog items with their price, the rest by name only (never into the catalog).
  for (const item of draft.items) {
    const response = await writes.addItem(
      props.order.id,
      {
        kind: item.catalogId ? item.kind : 'service',
        ...(item.catalogId ? { catalogId: item.catalogId } : { description: item.name }),
        ...(item.catalogId && item.description ? { description: item.description } : {}),
        ...(can('editPrices') && item.value !== null ? { value: item.value } : {}),
        ...(item.catalogId && item.kind === 'product' ? { quantity: Math.max(1, Math.round(item.quantity || 1)) } : {}),
      },
      version,
    )
    if (response.itemId) undo.added.push(response.itemId)
    take(response)
  }
  // "Fica pronto" only when the order has none.
  const due = dueFromDraft(draft.dueDate)
  if (due && !props.order.dueDate) {
    take(await writes.patchOrder(props.order.id, { dueDate: `${due}:00.000` }, version))
    undo.due = true
  }
  const onlyChanges = !draft.items.length && !undo.due && (undo.changed.length > 0 || undo.removed.length > 0)
  return { filled: hasUndo(undo), onlyChanges }
}

/** The removals of this answer leave the screen now and the server later (commitRemovals). */
function holdRemovals(undo: Undo) {
  const ids = undo.removed.map((l) => l.id).filter((id): id is string => !!id)
  if (!ids.length) return
  pending.push({ orderId: props.order.id, ids })
  emit('hide', ids)
}

async function undoDraft(undo: Undo) {
  for (const id of undo.added) await writes.removeItem(props.order.id, id).catch(() => {})
  for (const item of undo.changed) {
    const patch = { ...(item.before.value !== undefined && can('editPrices') ? { value: item.before.value } : {}), ...(item.before.quantity ? { quantity: item.before.quantity } : {}), description: item.before.description ?? '' }
    await writes.updateItem(props.order.id, item.id, patch).catch(() => {})
  }
  // Removals were never sent: they only come back to the screen.
  const ids = undo.removed.map((l) => l.id).filter((id): id is string => !!id)
  for (const batch of pending) batch.ids = batch.ids.filter((id) => !ids.includes(id))
  if (ids.length) emit('unhide', ids)
  if (undo.due) await writes.patchOrder(props.order.id, { dueDate: null }).catch(() => {})
  emit('undone', undo.added)
}

async function run(input: { text?: string; files?: File[]; audio?: { mimeType: string; data: string } }) {
  if (reading.value) return
  // What was said goes alone; the typed text stays in the box.
  const value = input.audio ? '' : (input.text?.trim() ?? '')
  const files = (input.files ?? []).filter((file) => file.type.startsWith('image/'))
  if (!value && !files.length && !input.audio) return
  reading.value = input.audio ? 'speech' : files.length ? 'photos' : 'text'
  note.value = ''
  const undo = emptyUndo()
  try {
    // The photo goes into the order first, then it is read (there is no photo just for the assistant).
    const photos = []
    for (const file of files.slice(0, ASSIST_MAX_PHOTOS)) {
      await writes.uploadPhoto(props.order.id, file)
      photos.push(await assistPhoto(file))
    }
    const sent = props.order
    const draft = await askAssistant(value, sent, photos, input.audio)
    usesLeft.value = usesLeftOf(draft.usage)
    monthLimit.value = Math.max(0, draft.usage?.limit ?? monthLimit.value)
    const { filled, onlyChanges } = await apply(draft, sent, undo)
    holdRemovals(undo)
    if (!input.audio) text.value = ''
    emit('added', undo.added)
    const actions = draft.actions ?? null
    const key = noteKey({ filled, hasActions: !!actions, isNew: false, onlyChanges })
    if (key) note.value = t(key)
    // Nothing the person may do with the money: the reason in the note, no card (offerActions).
    if (actions) offer(actions, draft.nfseAutoIssue ?? null, filled ? () => undoDraft(undo) : null)
    if (filled) {
      announce(note.value)
      ownToast(note.value, () => void undoDraft(undo).then(() => (note.value = '')))
    }
  } catch (error) {
    console.warn('assistant: failed', error)
    note.value = errorNote(error)
    // What was saved before the error can still be undone.
    if (hasUndo(undo)) {
      holdRemovals(undo)
      ownToast(note.value, () => void undoDraft(undo).then(() => (note.value = '')))
    }
  } finally {
    reading.value = ''
  }
}

/** After the card: its note, and Desfazer takes back the card's steps and what the same sentence put in the order. */
function cardDone(text: string, undoActions: (() => Promise<void>) | null) {
  const undoDraftFn = card.value?.undoDraft ?? null
  if (!text) return
  note.value = text
  announce(text)
  ownToast(text, undoActions ? () => void undoActions().then(() => undoDraftFn?.()) : undefined)
}
</script>

<template>
  <div v-if="enabled" class="assist-bar" data-testid="assistant">
    <p v-if="note" class="assist-note small" role="status">{{ note }}</p>
    <p v-if="usesLeft !== null" class="assist-note small">{{ t('orderAssistantUsesLeft', { count: usesLeft }) }}</p>
    <form @submit.prevent="run({ text })">
      <span class="ai" aria-hidden="true">✦</span>
      <label class="sr" for="od-assist">{{ t('web.order.askAssistant') }}</label>
      <input v-show="!listening" id="od-assist" v-model="text" class="field" maxlength="2000" :placeholder="t('web.order.askAssistantHint')" :disabled="!!reading" />
      <AssistTalk :disabled="!!reading" @audio="(audio) => run({ audio })" @note="(message) => (note = message)" @listening="(on) => (listening = on)" />
      <label v-if="canPhoto && !listening" class="btn assist-photo" :title="t('orderAssistantPhoto')">
        <ImagePlus :size="16" aria-hidden="true" />
        <span class="sr">{{ t('web.assist.photo') }}</span>
        <input class="sr" type="file" accept="image/*" multiple :disabled="!!reading" data-testid="assistant-photo" @change="run({ text, files: [...(($event.target as HTMLInputElement).files ?? [])] }); ($event.target as HTMLInputElement).value = ''" />
      </label>
      <button v-if="!listening" type="submit" class="btn" :disabled="!text.trim() || !!reading">{{ reading === 'photos' ? t('orderAssistantReadingPhotos') : reading === 'speech' ? t('orderAssistantReadingSpeech') : reading ? t('web.order.reading') : t('web.order.send') }}</button>
    </form>
  </div>
  <ChoiceDialog
    v-if="asking"
    :title="t('orderAssistantWhichLine', { name: asking.change.name })"
    :choices="asking.lines.map((line, i) => ({ id: String(i), label: line.name, sub: line.value === undefined ? undefined : line.value === null ? t('catalogNoPrice') : money(line.value) }))"
    @pick="answered"
    @close="answered(null)"
  />
  <AiActionsDialog
    v-if="card"
    :order="order"
    :actions="card.actions"
    :nfse="card.nfse"
    :pending-checklists="pendingChecklists ?? 0"
    :sub="`${orderShort()} ${order.number ?? ''} · ${order.customer?.name ?? ''}`"
    @done="cardDone"
    @close="card = null"
  />
</template>
