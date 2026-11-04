<script setup lang="ts">
// The assistant on the Nova OS (order.ai.type/.photo on a new order,
// .ask-customer, .register-customer, .ask-device, .register-device, .ask-line,
// .change-lines): the app's _applyDraft. It fills the same blank form, marks
// with ✦ what it filled and offers Desfazer; nothing is saved before the ✓, and
// a customer or device that is not in the register is registered only then.
// It never replaces a customer already chosen, a request already typed or a
// date already set. Money said here waits: the "Confere?" card opens on the
// order once it exists (aiActionsAfterSave).
import { computed, nextTick, onMounted, ref, shallowRef } from 'vue'
import { ImagePlus } from '@lucide/vue'
import { t } from '@/i18n'
import { ApiError } from '@/lib/api'
import type { DraftActions, NfseMoment } from '@/lib/orders/ai-actions'
import { changeTarget, customerStep, deviceStep, dueFromDraft, noteKey, usesLeft as usesLeftOf, type CustomerHit, type DeviceHit, type DraftChange, type NewDevice } from '@/lib/orders/assist-draft'
import { ASSIST_MAX_PHOTOS, assistPhoto } from '@/lib/orders/assist-photo'
import { assistStatus, requestAssist } from '@/lib/orders/assistant'
import type { CatalogItem, Customer, Device } from '@/lib/orders/catalog'
import { deviceLabel, money } from '@/lib/orders/text'
import { formatPhone } from '@/lib/phone'
import { can, session } from '@/lib/session'
import { announce } from '@/lib/ui'
import ChoiceDialog from './ChoiceDialog.vue'

export interface FormLine {
  key: string
  item: CatalogItem
  value: number | null
  quantity: number
  free?: boolean
}
/** The Nova OS form, shared with the drawer (refs unwrapped by reactive()). */
export interface AssistForm {
  customer: Customer | null
  device: Device | null
  lines: FormLine[]
  request: string
  due: string
  photos: File[]
  /** What the assistant filled (✦): 'customer', 'device', 'request', 'due' and line keys. */
  marked: Set<string>
  /** Heard and not in the register: registered at the ✓ (AssistantRegistration). */
  newCustomer: { name: string; phone?: string } | null
  newDevice: NewDevice | null
  /** Money said: the card opens after the order is saved. */
  actions: { actions: DraftActions; nfse: NfseMoment | null } | null
}

const props = defineProps<{ form: AssistForm; catalog: CatalogItem[]; autofocus?: boolean }>()
const emit = defineEmits<{ otherCustomer: []; otherDevice: [] }>()

const enabled = ref(false)
const text = ref('')
const reading = ref<'' | 'text' | 'photos'>('')
const note = ref('')
const usesLeft = ref<number | null>(null)
const monthLimit = ref(0)
const canPhoto = computed(() => can('attachPhotos'))
const input = ref<HTMLInputElement | null>(null)
/** "Ouvi “Juliene”": the rows that ask (order.ai.ask-customer / ask-device). */
const customerAsk = shallowRef<{ name: string; phone?: string; options: CustomerHit[] } | null>(null)
const deviceAsk = shallowRef<{ label: string; device: NewDevice; options: DeviceHit[] } | null>(null)
const choosing = ref<null | 'customer' | 'device'>(null)
const lastUndo = shallowRef<Undo | null>(null)
const asking = shallowRef<{ change: DraftChange; lines: FormLine[]; resolve: (line: FormLine | null) => void } | null>(null)

onMounted(async () => {
  try {
    const status = await assistStatus()
    enabled.value = status.enabled
    usesLeft.value = usesLeftOf(status.usage)
    monthLimit.value = Math.max(0, status.usage?.limit ?? 0)
  } catch {
    enabled.value = false
  }
  // "Experimentar agora": the cursor starts here, after the drawer placed its own first focus.
  if (enabled.value && props.autofocus) {
    await nextTick()
    const focus = () => {
      const active = document.activeElement as HTMLInputElement | null
      if (!active?.value) input.value?.focus()
    }
    focus()
    setTimeout(focus, 300)
  }
})

function errorNote(error: unknown): string {
  if (error instanceof ApiError && error.code === 'AI_DISABLED') return t('orderAssistantErrorDisabled')
  if (error instanceof ApiError && error.code === 'AI_QUOTA_EXCEEDED') return t('orderAssistantErrorQuota', { limit: monthLimit.value })
  return t('orderAssistantErrorUnavailable')
}

function pickLine(change: DraftChange, lines: FormLine[]): Promise<FormLine | null> {
  return new Promise((resolve) => (asking.value = { change, lines, resolve }))
}
function answered(id: string | null) {
  const current = asking.value
  asking.value = null
  current?.resolve(id === null ? null : (current.lines[Number(id)] ?? null))
}

interface Undo {
  customer: Customer | null
  device: Device | null
  added: string[]
  changed: { key: string; value: number | null; quantity: number }[]
  removed: { line: FormLine; index: number }[]
  request: string | null
  due: string | null
  asks: { customer: typeof customerAsk.value; device: typeof deviceAsk.value }
}

async function run(files: File[] = []) {
  const value = text.value.trim()
  const images = files.filter((file) => file.type.startsWith('image/')).slice(0, ASSIST_MAX_PHOTOS)
  if (reading.value || (!value && !images.length)) return
  reading.value = images.length ? 'photos' : 'text'
  note.value = ''
  const f = props.form
  try {
    // The photo goes into the Nova OS first (order.new.photos), then it is read.
    if (images.length) f.photos = [...f.photos, ...images]
    const photos = await Promise.all(images.map((file) => assistPhoto(file)))
    const sent = { services: f.lines.filter((l) => l.item.kind === 'service'), products: f.lines.filter((l) => l.item.kind === 'product') }
    const draft = await requestAssist({ text: value, photos, lines: f.lines.map((l) => ({ kind: l.item.kind, name: l.item.name, value: l.value, quantity: l.quantity })) })
    usesLeft.value = usesLeftOf(draft.usage)
    monthLimit.value = Math.max(0, draft.usage?.limit ?? monthLimit.value)
    const undo: Undo = { customer: f.customer, device: f.device, added: [], changed: [], removed: [], request: null, due: null, asks: { customer: customerAsk.value, device: deviceAsk.value } }
    // 0. Changes on the lines that were sent: value, quantity, or out (only when asked).
    for (const change of draft.changes) {
      let { line } = changeTarget(change, sent)
      if (!line) {
        const { candidates } = changeTarget(change, sent)
        line = candidates.length ? await pickLine(change, candidates) : null
      }
      const current = line && f.lines.find((l) => l.key === line?.key)
      if (!current) continue
      if (change.action === 'remove') {
        const index = f.lines.indexOf(current)
        f.lines = f.lines.filter((l) => l !== current)
        undo.removed.push({ line: current, index })
        f.marked.delete(current.key)
        continue
      }
      if (change.value === undefined && change.quantity === undefined) continue
      undo.changed.push({ key: current.key, value: current.value, quantity: current.quantity })
      if (change.value !== undefined) current.value = change.value
      if (change.quantity !== undefined && current.item.kind === 'product') current.quantity = change.quantity
      f.marked.add(current.key)
    }
    // 1. Customer, only when none is chosen.
    const c = customerStep(draft, { hasCustomer: !!f.customer, isNew: true, canRegister: can('manageCustomers') })
    if (c.kind === 'match') {
      f.customer = { id: c.customer.id, name: c.customer.name, ...(c.customer.phone ? { phone: c.customer.phone } : {}) }
      f.marked.add('customer')
      customerAsk.value = null
    } else if (c.kind === 'new') {
      setNewCustomer(c.name, c.phone)
      f.marked.add('customer')
    } else if (c.kind === 'ask') customerAsk.value = { name: c.name, ...(c.phone ? { phone: c.phone } : {}), options: c.options }
    // 2. Device.
    const d = deviceStep(draft, { devices: f.device ? [f.device] : [], isNew: true, canRegister: can('manageDevices') })
    if (d.kind === 'match' && !f.device) {
      f.device = { id: d.device.id, name: d.device.name, serial: d.device.serial ?? null }
      f.marked.add('device')
    } else if (d.kind === 'new' && !f.device) {
      setNewDevice(d.device)
      f.marked.add('device')
    } else if (d.kind === 'ask' && !f.device) deviceAsk.value = { label: d.label, device: d.device, options: d.options }
    // 3. Items: catalog ones with their price, the rest by name only (never into the catalog).
    for (const item of draft.items) {
      const known = item.catalogId ? props.catalog.find((entry) => entry.id === item.catalogId && entry.kind === item.kind) : null
      const line: FormLine = known
        ? { key: crypto.randomUUID(), item: known, value: item.value ?? known.value, quantity: item.kind === 'product' ? Math.max(1, Math.round(item.quantity || 1)) : 1 }
        : { key: crypto.randomUUID(), item: { id: '', kind: 'service', name: item.name, value: null }, value: item.value, quantity: 1, free: true }
      f.lines = [...f.lines, line]
      f.marked.add(line.key)
      undo.added.push(line.key)
    }
    // 4. "O que o cliente pediu" and 5. "Fica pronto", only when blank.
    if (draft.notes && !f.request.trim()) {
      f.request = draft.notes
      undo.request = draft.notes
      f.marked.add('request')
    }
    const due = dueFromDraft(draft.dueDate)
    if (due && !f.due) {
      f.due = due
      undo.due = due
      f.marked.add('due')
    }
    // 6. Money waits for the order (order.ai.money-card).
    if (draft.actions) f.actions = { actions: draft.actions, nfse: draft.nfseAutoIssue ?? null }
    text.value = ''
    const filled =
      f.customer !== undo.customer || f.device !== undo.device || undo.added.length + undo.changed.length + undo.removed.length > 0 || !!undo.request || !!undo.due || !!draft.actions || customerAsk.value !== undo.asks.customer || deviceAsk.value !== undo.asks.device
    const onlyChanges = !undo.added.length && (undo.changed.length > 0 || undo.removed.length > 0) && f.customer === undo.customer
    const key = noteKey({ filled, hasActions: !!draft.actions, isNew: true, onlyChanges })
    note.value = key ? t(key) : ''
    // Desfazer sits in the note: the drawer is modal, a toast behind it could not be reached.
    lastUndo.value = filled ? undo : null
    if (filled) announce(note.value)
  } catch (error) {
    console.warn('new order assistant: failed', error)
    note.value = errorNote(error)
  } finally {
    reading.value = ''
  }
}

function setNewCustomer(name: string, phone?: string) {
  props.form.newCustomer = { name, ...(phone ? { phone } : {}) }
  props.form.customer = { id: '', name, ...(phone ? { phone } : {}) }
  customerAsk.value = null
}
function setNewDevice(device: NewDevice) {
  props.form.newDevice = device
  props.form.device = { id: '', name: device.name, serial: device.serial }
  deviceAsk.value = null
}

/** Takes back only what this answer did; what the person changed afterwards stays. */
function undoDraft(undo: Undo) {
  const f = props.form
  f.actions = null
  if (f.customer !== undo.customer && f.marked.has('customer')) {
    f.customer = undo.customer
    f.newCustomer = null
  }
  if (f.device !== undo.device && f.marked.has('device')) {
    f.device = undo.device
    f.newDevice = null
  }
  for (const changed of undo.changed) {
    const line = f.lines.find((l) => l.key === changed.key)
    if (line) Object.assign(line, { value: changed.value, quantity: changed.quantity })
  }
  const lines = f.lines.filter((l) => !undo.added.includes(l.key))
  for (const { line, index } of [...undo.removed].reverse()) lines.splice(Math.min(index, lines.length), 0, line)
  f.lines = lines
  if (undo.request && f.request === undo.request) f.request = ''
  if (undo.due && f.due === undo.due) f.due = ''
  for (const key of ['customer', 'device', 'request', 'due', ...undo.added, ...undo.changed.map((c) => c.key)]) f.marked.delete(key)
  customerAsk.value = undo.asks.customer
  deviceAsk.value = undo.asks.device
  note.value = ''
  lastUndo.value = null
}

// "Qual Juliene?" / "Qual Super Classic?": the look-alikes, "Cadastrar …" (with the permission) and "Outro …".
const NEW = '__new'
const OTHER = '__other'
const customerChoices = computed(() => [
  ...(customerAsk.value?.options ?? []).map((c) => ({ id: c.id, label: c.name, sub: formatPhone(c.phone, session.company?.country) || undefined })),
  ...(can('manageCustomers') && customerAsk.value ? [{ id: NEW, label: t('orderAssistantRegisterNewCustomer', { name: customerAsk.value.name }), sub: formatPhone(customerAsk.value.phone, session.company?.country) || undefined }] : []),
  { id: OTHER, label: t('orderAssistantOtherCustomer') },
])
const deviceChoices = computed(() => [
  ...(deviceAsk.value?.options ?? []).map((d) => ({ id: d.id, label: d.name, sub: d.serial || undefined })),
  ...(can('manageDevices') && deviceAsk.value ? [{ id: NEW, label: t('orderAssistantRegisterNewDevice', { name: deviceAsk.value.label }) }] : []),
  { id: OTHER, label: t('orderAssistantOtherDevice', { label: deviceLabel().toLocaleLowerCase() }) },
])

/** A picked one is the person's choice: no ✦ on it. */
function pickCustomer(id: string) {
  const ask = customerAsk.value
  choosing.value = null
  if (!ask) return
  if (id === OTHER) return void emit('otherCustomer')
  if (id === NEW) setNewCustomer(ask.name, ask.phone)
  else {
    const hit = ask.options.find((c) => c.id === id)
    if (hit) props.form.customer = { id: hit.id, name: hit.name, ...(hit.phone ? { phone: hit.phone } : {}) }
  }
  customerAsk.value = null
  props.form.marked.delete('customer')
}
function pickDevice(id: string) {
  const ask = deviceAsk.value
  choosing.value = null
  if (!ask) return
  if (id === OTHER) return void emit('otherDevice')
  if (id === NEW) setNewDevice(ask.device)
  else {
    const hit = ask.options.find((d) => d.id === id)
    if (hit) props.form.device = { id: hit.id, name: hit.name, serial: hit.serial ?? null }
  }
  deviceAsk.value = null
  props.form.marked.delete('device')
}

/** Choosing by hand clears the row that asked. */
defineExpose({
  clearCustomerAsk: () => (customerAsk.value = null),
  clearDeviceAsk: () => (deviceAsk.value = null),
})
</script>

<template>
  <div v-if="enabled" class="assist-new" data-testid="new-order-assistant">
    <form class="assist-new-bar" @submit.prevent="run()">
      <span class="ai" aria-hidden="true">✦</span>
      <label class="sr" for="no-assist">{{ t('web.order.askAssistant') }}</label>
      <input id="no-assist" ref="input" v-model="text" class="field" maxlength="2000" :placeholder="t('web.newOrder.assistHint')" :disabled="!!reading" />
      <label v-if="canPhoto" class="btn assist-photo" :title="t('orderAssistantPhoto')">
        <ImagePlus :size="16" aria-hidden="true" />
        <span class="sr">{{ t('web.assist.photo') }}</span>
        <input class="sr" type="file" accept="image/*" multiple :disabled="!!reading" data-testid="new-order-assistant-photo" @change="run([...(($event.target as HTMLInputElement).files ?? [])]); ($event.target as HTMLInputElement).value = ''" />
      </label>
      <button type="submit" class="btn" :disabled="!text.trim() || !!reading">{{ reading === 'photos' ? t('orderAssistantReadingPhotos') : reading ? t('orderAssistantReadingSpeech') : t('web.order.send') }}</button>
    </form>
    <p v-if="note" class="assist-note small" role="status">
      <span data-testid="new-order-assistant-note">{{ note }}</span>
      <button v-if="lastUndo" type="button" class="link" data-testid="new-order-assistant-undo" @click="undoDraft(lastUndo)">{{ t('orderAssistantUndo') }}</button>
    </p>
    <p v-if="usesLeft !== null" class="assist-note small">{{ t('orderAssistantUsesLeft', { count: usesLeft }) }}</p>
    <button v-if="customerAsk && !form.customer" type="button" class="assist-ask" data-testid="assist-ask-customer" @click="choosing = 'customer'">
      <span class="ai" aria-hidden="true">✦</span> {{ t('orderAssistantCustomerGuess', { name: customerAsk.name }) }}
    </button>
    <button v-if="deviceAsk && !form.device" type="button" class="assist-ask" data-testid="assist-ask-device" @click="choosing = 'device'">
      <span class="ai" aria-hidden="true">✦</span> {{ t('orderAssistantDeviceGuess', { device: deviceAsk.label }) }}
    </button>
  </div>
  <ChoiceDialog v-if="choosing === 'customer' && customerAsk" :title="t('orderAssistantWhichCustomer', { name: customerAsk.name })" :choices="customerChoices" @pick="pickCustomer" @close="choosing = null" />
  <ChoiceDialog v-else-if="choosing === 'device' && deviceAsk" :title="t('orderAssistantWhichDevice', { name: deviceAsk.label })" :choices="deviceChoices" @pick="pickDevice" @close="choosing = null" />
  <ChoiceDialog
    v-if="asking"
    :title="t('orderAssistantWhichLine', { name: asking.change.name })"
    :choices="asking.lines.map((line, i) => ({ id: String(i), label: line.item.name, sub: line.value === null ? t('catalogNoPrice') : money(line.value) }))"
    @pick="answered"
    @close="answered(null)"
  />
</template>
