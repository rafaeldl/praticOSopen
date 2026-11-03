<script setup lang="ts">
// The open order, beside the list: who (customer, device), where it stands
// (status and one phrase), the next step in blue, then what is done, money,
// photos, comments and details. Each row opens its own editor; there is no
// "Editar" mode. Money, status and items go through the API (writes.ts).
import { computed, defineAsyncComponent, onBeforeUnmount, onMounted, ref, shallowRef, watch } from 'vue'
import { MoreHorizontal, X } from '@lucide/vue'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import StatusLabel from '@/components/StatusLabel.vue'
import type { ComboboxGroup, ComboboxItem } from '@/components/Combobox.vue'
import { loadTexts, t } from '@/i18n'
import { ApiError, errorMessageKey } from '@/lib/api'
import { orderChanged, orderRemoved } from '@/lib/orders/bus'
import { loadCatalog, loadCustomers, loadDevices, loadTeam, search, type CatalogItem, type Customer, type Device, type Member } from '@/lib/orders/catalog'
import { listContext, watchOrder, type DetailState } from '@/lib/orders/data'
import {
  accessOf,
  holdDays,
  isActive,
  isHeld,
  linesByDevice,
  STATUSES,
  nextStep,
  totals,
  type HoldReason,
  type Order,
  type OrderLine,
  type OrderStatus,
} from '@/lib/orders/model'
import {
  deviceLabel,
  headerPhrase,
  holdReasonText,
  lateText,
  lineKindText,
  money,
  orderShort,
  orderTitle,
  statusText,
  whenText,
} from '@/lib/orders/text'
import * as writes from '@/lib/orders/writes'
import { formatPhone } from '@/lib/phone'
import { can, effectiveUseFinancial, session } from '@/lib/session'
import { registerShortcut } from '@/lib/shortcuts'
import { currentToast, showToast } from '@/lib/toast'
import { announce } from '@/lib/ui'
import ChoiceDialog, { type Choice } from './ChoiceDialog.vue'
import ComboDialog from './ComboDialog.vue'
import ConfirmDialog from './ConfirmDialog.vue'
import DateDialog from './DateDialog.vue'
import HoldDialog from './HoldDialog.vue'
import ItemDialog from './ItemDialog.vue'
import MoneyDialog from './MoneyDialog.vue'
import OrderComments from './OrderComments.vue'
import OrderPhotos from './OrderPhotos.vue'
import OrderPrint from './OrderPrint.vue'
import OrderAssistant from './OrderAssistant.vue'
import PaymentHistory from './receive/PaymentHistory.vue'
import { paymentSettings, removeTransaction, resetPayments } from '@/lib/receive/data'
import { receivesMoney, type Payment } from '@/lib/receive/model'
// Opened on demand: the order shows without them.
const ShareDialog = defineAsyncComponent(() => import('./receive/ShareDialog.vue'))
const OrderCharge = defineAsyncComponent(() => import('./receive/OrderCharge.vue'))
// Notas fiscais (fatia 6): the dialog and its texts come only when asked for.
const IssueInvoiceDialog = defineAsyncComponent(() => Promise.all([import('@/components/finance/IssueInvoiceDialog.vue'), loadTexts('finance')]).then(([m]) => m))
// Checklists, after the order shows (their texts are in the orders chunk).
const PdfDialog = defineAsyncComponent(() => import('./PdfDialog.vue'))
const OrderForms = defineAsyncComponent(() => import('@/components/forms/OrderForms.vue'))

const props = defineProps<{ orderId: string }>()
const emit = defineEmits<{ close: [] }>()

const ctx = listContext()
const state = shallowRef<DetailState>({ kind: 'loading' })
const busy = ref(false)
const now = ref(new Date())
const printing = ref(false)
/** Lines the assistant added in this visit: marked with ✦ (order.ai.marked). */
const aiLines = ref<string[]>([])
type Dialog =
  | { kind: 'status' }
  | { kind: 'cancel' }
  | { kind: 'delete' }
  | { kind: 'hold' }
  | { kind: 'menu' }
  | { kind: 'due' }
  | { kind: 'schedule' }
  | { kind: 'assignee' }
  | { kind: 'receive' }
  | { kind: 'discount' }
  | { kind: 'item'; line: OrderLine }
  | { kind: 'addItem' }
  | { kind: 'customer' }
  | { kind: 'device' }
  | { kind: 'keepDevices'; customer: Customer }
  | { kind: 'share' }
  | { kind: 'pendingForms'; count: number; first: string }
const dialog = shallowRef<Dialog | null>(null)
const menuButton = ref<HTMLElement | null>(null)
const catalog = shallowRef<CatalogItem[]>([])
const customers = shallowRef<Customer[]>([])
const devices = shallowRef<Device[]>([])
const team = shallowRef<Member[]>([])

const order = computed(() => (state.value.kind === 'ready' ? state.value.order : null))
const access = computed(() => (order.value ? accessOf(order.value, session.role, session.uid, effectiveUseFinancial()) : null))
const money$ = computed(() => (order.value ? totals(order.value) : null))
const step = computed(() => (order.value && access.value ? nextStep(order.value, access.value) : null))
const phrase = computed(() => (order.value ? headerPhrase(order.value, now.value, money$.value?.remaining ?? null) : null))
const showsMoney = computed(() => !!order.value?.showsMoney)
const canAddItems = computed(() => !!access.value?.canEditMainFields && (can('viewServices') || can('viewProducts')))
const showItems = computed(() => !!order.value && (order.value.lines.length > 0 || !!access.value?.canEditMainFields))
const groups = computed(() => (order.value ? linesByDevice({ ...order.value, lines: order.value.lines.filter((line) => !line.id || !hiddenLines.value.includes(line.id)) }) : []))
const useScheduling = computed(() => session.company && (session.company as { useScheduling?: boolean }).useScheduling !== false)
const canPrint = computed(() => can('viewPrices') || !effectiveUseFinancial())
const moneyRowTone = computed(() => order.value && order.value.status !== 'quote' && order.value.status !== 'canceled')
const holdLine = computed(() => {
  const o = order.value
  if (!o || !isHeld(o) || !o.onHold) return null
  return { reason: holdReasonText(o.onHold.reason), days: t('orderHoldSince', { count: holdDays(o, now.value) ?? 0 }), note: o.onHold.note }
})
const stepLabel = computed(() => {
  const value = step.value
  if (!value) return ''
  if (value.kind === 'resume') return t('orderHoldResume')
  if (value.kind === 'receive') return t('orderNextStepReceive', { amount: money(value.amount) })
  return value.to === 'approved' ? t('orderActionApproveQuote') : value.to === 'progress' ? t('orderActionStartService') : t('web.order.markDone')
})
const STATUS_DOT: Record<OrderStatus, string> = { quote: 'neutral', approved: 'accent', progress: 'warning', done: 'success', canceled: 'hollow' }

let watcher: ReturnType<typeof watchOrder> | undefined
/** Payment links of Asaas: pilot on and account connected, for who charges (chargeOrder). */
const chargesOn = ref(false)
/** Notas fiscais on for the company (settings/payments): "Emitir nota fiscal" in the menu, for chargeOrder. */
const nfseOn = ref(false)
const issuing = ref(false)
const pdfOpen = ref(false)
/** settings/payments still being read: whether there can be a link is not known yet. */
const chargesPending = ref(false)
onMounted(() => {
  watcher = watchOrder(ctx, props.orderId, (next) => (state.value = next))
  // Who receives also reads the open link (the consultant included, #513 / R4); only chargeOrder acts on it.
  if (can('chargeOrder') || (session.role === 'consultant' && effectiveUseFinancial())) {
    chargesPending.value = true
    void paymentSettings()
      .then((settings) => {
        chargesOn.value = settings.ready
        nfseOn.value = settings.nfse
      })
      .finally(() => (chargesPending.value = false))
  }
})
/**
 * A payment link is open (true), none (false), or not known yet / the read
 * failed (null). Marking received is the blue step only when it is known that
 * no link is open (M1 of #518); the sheet says the link adjusts only when one is.
 */
const linkOpen = ref<boolean | null>(false)
const showCharge = computed(() => chargesOn.value && !!order.value && receivesMoney(order.value.status) && !!access.value?.canReceive)
const noLinkKnown = computed(() => !chargesPending.value && (!showCharge.value || linkOpen.value === false))
// The card starts not knowing; it says when it knows (OrderCharge emits open).
watch(showCharge, (shown) => (linkOpen.value = shown ? null : false))

async function removePayment(payment: Payment) {
  if (!order.value || !payment.id) return
  await run(() => removeTransaction(order.value!.id, payment.id as string, payment.type), t('web.receive.removed', { amount: money(payment.amount) }))
}

async function undoAllPayments() {
  if (!order.value) return
  await run(() => resetPayments(order.value!.id), t('web.receive.undoneAll'))
}
onBeforeUnmount(() => watcher?.stop())
const clock = setInterval(() => (now.value = new Date()), 60_000)
onBeforeUnmount(() => clearInterval(clock))

/**
 * One write at a time, in the order asked: a second one waits for the first
 * (never dropped). The response refreshes the screen and the list row.
 */
let queue: Promise<unknown> = Promise.resolve()
function run(action: () => Promise<{ order?: Record<string, unknown> } | void>, done?: string): Promise<boolean> {
  const next = queue.then(() => write(action, done))
  queue = next.catch(() => {})
  return next
}

async function write(action: () => Promise<{ order?: Record<string, unknown> } | void>, done?: string): Promise<boolean> {
  busy.value = true
  const over = order.value?.version ?? null
  try {
    const response = await action()
    const fresh = response && response.order ? writes.orderOf(response, ctx.showsMoney) : null
    // The next write in the queue sends this version even if the listener is late (B5).
    if (fresh?.version) saved = { version: fresh.version, over }
    if (fresh) {
      // Firestore users get the change from the listener (with item ids); the API is read again.
      if (!ctx.showsMoney) state.value = { kind: 'ready', order: fresh }
      orderChanged(fresh)
    } else if (!ctx.showsMoney) await watcher?.refresh()
    if (done) {
      showToast(done)
      announce(done)
    }
    return true
  } catch (error) {
    console.warn('order: write failed', error)
    showToast(t(errorMessageKey(error)))
    if (error instanceof ApiError && ['ORDER_CHANGED', 'ITEM_NOT_FOUND', 'PAYMENT_EXCEEDS_BALANCE'].includes(error.code)) await watcher?.refresh()
    return false
  } finally {
    busy.value = false
  }
}

/**
 * The version to send (opaque, never compared as a date). The last response's,
 * while the listener still shows the version that write replaced (B5); once the
 * listener moves on, its own.
 */
let saved: { version: string; over: string | null } | null = null
const expected = () => {
  const seen = order.value?.version ?? null
  return saved && seen === saved.over ? saved.version : seen
}

/** The order's checklists, as OrderForms reads them (live). */
const orderForms = shallowRef<{ id: string; status: string }[]>([])
const formsRef = ref<{ open: (id: string) => void } | null>(null)

async function setStatus(status: OrderStatus) {
  dialog.value = null
  if (!order.value) return
  // A checklist not completed blocks "concluída" and offers to open it (order.status.pending-checklist).
  const pendingForms = status === 'done' && order.value.status !== 'done' ? orderForms.value.filter((form) => form.status !== 'completed') : []
  if (pendingForms.length) {
    dialog.value = { kind: 'pendingForms', count: pendingForms.length, first: (pendingForms[0] as { id: string }).id }
    return
  }
  await run(() => writes.patchOrder(order.value!.id, { status }, expected()), t('web.order.statusChanged', { status: statusText(status) }))
}

async function runStep() {
  const value = step.value
  if (!value || !order.value) return
  if (value.kind === 'status') await setStatus(value.to)
  else if (value.kind === 'resume') await run(() => writes.resumeOrder(order.value!.id), t('web.order.resumed'))
  else dialog.value = { kind: 'receive' }
}

async function hold(reason: HoldReason, note: string) {
  dialog.value = null
  await run(() => writes.markOnHold(order.value!.id, reason, note || undefined), t('web.order.held'))
}

async function saveDate(field: 'dueDate' | 'scheduledDate', value: string | null) {
  dialog.value = null
  await run(() => writes.patchOrder(order.value!.id, { [field]: value }, expected()), t('web.saved'))
}

async function assign(id: string) {
  dialog.value = null
  await run(() => writes.patchOrder(order.value!.id, { assignedTo: id === 'none' ? null : id }, expected()), t('web.saved'))
}

async function receive(value: { amount: number; paymentMethod?: string; paidAt?: string; clientTransactionId: string }) {
  const ok = await run(() => writes.receivePayment(order.value!.id, value, expected()), t('web.order.received', { amount: money(value.amount) }))
  if (ok) dialog.value = null
}

async function discount(value: { amount: number; clientTransactionId: string }) {
  const ok = await run(() => writes.giveDiscount(order.value!.id, { amount: value.amount, clientTransactionId: value.clientTransactionId }, expected()), t('web.saved'))
  if (ok) dialog.value = null
}

async function addCatalogItem(item: CatalogItem) {
  dialog.value = null
  await run(() => writes.addItem(order.value!.id, { kind: item.kind, catalogId: item.id }, expected()), t('web.order.itemAdded', { name: item.name }))
}

async function addFreeItem(name: string) {
  dialog.value = null
  await run(() => writes.addItem(order.value!.id, { kind: 'service', description: name }, expected()), t('web.order.itemAdded', { name }))
}

async function saveLine(line: OrderLine, patch: { description?: string; value?: number | null; quantity?: number }) {
  if (!Object.keys(patch).length || !line.id) {
    dialog.value = null
    return
  }
  const ok = await run(() => writes.updateItem(order.value!.id, line.id as string, patch, expected()), t('web.saved'))
  if (ok) dialog.value = null
}

/**
 * Tirar com Desfazer (no app confirmation, no app undo: defect 10). The line
 * leaves the screen at once and the server only hears about it when the notice
 * goes away (the next action): Desfazer keeps the line where it was, with its
 * own description.
 */
const hiddenLines = ref<string[]>([])
let pendingRemoval: { orderId: string; line: OrderLine } | null = null
function commitRemoval() {
  const pending = pendingRemoval
  pendingRemoval = null
  if (!pending) return
  void run(() => writes.removeItem(pending.orderId, pending.line.id as string, expected())).then((ok) => {
    if (!ok) hiddenLines.value = hiddenLines.value.filter((id) => id !== pending.line.id)
  })
}
function removeLine(line: OrderLine) {
  if (!line.id || !order.value) return
  commitRemoval()
  dialog.value = null
  pendingRemoval = { orderId: order.value.id, line }
  hiddenLines.value = [...hiddenLines.value, line.id]
  showToast(t('web.order.itemRemoved', { name: line.name }), {
    undo: () => {
      pendingRemoval = null
      hiddenLines.value = hiddenLines.value.filter((id) => id !== line.id)
      announce(t('web.order.itemRestored', { name: line.name }))
    },
  })
  announce(t('web.order.itemRemoved', { name: line.name }))
}
// The notice was replaced or closed without Desfazer: now the line really leaves.
watch(currentToast, () => {
  if (pendingRemoval && !currentToast.value?.undo) commitRemoval()
})
onBeforeUnmount(commitRemoval)

async function deleteIt() {
  dialog.value = null
  const id = order.value?.id
  if (!id) return
  const title = orderTitle(order.value!)
  const ok = await run(async () => void (await writes.deleteOrder(id)), t('web.order.deleted', { order: title }))
  if (ok) {
    orderRemoved(id)
    emit('close')
  }
}

async function chooseCustomer(customer: Customer) {
  const o = order.value
  if (!o) return
  if (o.devices.length && o.customer?.id && o.customer.id !== customer.id) {
    // Changing the customer keeps the previous one's device unless the person says (defect 26).
    dialog.value = { kind: 'keepDevices', customer }
    return
  }
  await applyCustomer(customer, false)
}

async function applyCustomer(customer: Customer, dropDevices: boolean) {
  dialog.value = null
  const o = order.value as Order
  // Same customer summary the app and the server write (id, name, phone, e-mail, CPF/CNPJ).
  const summary = { id: customer.id, name: customer.name, phone: customer.phone, email: customer.email, taxId: customer.taxId }
  const fields: Record<string, unknown> = { customer: Object.fromEntries(Object.entries(summary).filter(([, v]) => v !== undefined && v !== null && v !== '')) }
  // The customer's address comes when the order has no place yet (order.customer.address-from-customer).
  if (!o.address && customer.address) fields.address = customer.address
  if (dropDevices) Object.assign(fields, { device: null, devices: [], deviceIds: [] })
  await run(() => writes.updateOrderFields(o.id, fields), t('web.saved'))
}

async function addDevice(device: Device) {
  dialog.value = null
  const o = order.value as Order
  if (o.devices.some((item) => item.id === device.id)) return
  const list = [...o.devices, { id: device.id, name: device.name, ...(device.serial ? { serial: device.serial } : {}) }]
  await run(() => writes.updateOrderFields(o.id, { device: list[0], devices: list, deviceIds: list.map((item) => item.id) }), t('web.saved'))
}

async function openPicker(kind: 'addItem' | 'customer' | 'device' | 'assignee') {
  try {
    if (kind === 'addItem' && !catalog.value.length) catalog.value = await loadCatalog()
    if (kind === 'customer' && !customers.value.length) customers.value = await loadCustomers()
    if (kind === 'device' && !devices.value.length) devices.value = await loadDevices()
    if (kind === 'assignee' && !team.value.length) team.value = await loadTeam()
  } catch (error) {
    showToast(t(errorMessageKey(error)))
    return
  }
  if (kind === 'assignee' && !team.value.length) return
  dialog.value = { kind }
}

const itemGroups = (query: string): ComboboxGroup[] => {
  const list = search(catalog.value, query, (item) => lineKindText(item.kind), 10)
  return [
    {
      title: query ? undefined : t('orderAllItems'),
      items: list.map((item) => ({
        id: `${item.kind}:${item.id}`,
        label: item.name,
        sub: lineKindText(item.kind),
        right: showsMoney.value ? (item.value === null ? t('catalogNoPrice') : money(item.value)) : undefined,
      })),
    },
    // Outside the catalog, named by what was typed (POST /items without catalogId, #516).
    { items: writes.API_516 && query.trim() ? [{ id: FREE_ITEM, label: t('web.newOrder.useFree', { name: query.trim() }) }] : [] },
  ]
}
const FREE_ITEM = '__free'
const pickItem = (picked: ComboboxItem, query = '') => {
  if (picked.id === FREE_ITEM && query.trim()) return void addFreeItem(query.trim())
  const item = catalog.value.find((entry) => `${entry.kind}:${entry.id}` === picked.id)
  if (item) void addCatalogItem(item)
}
const customerGroups = (query: string): ComboboxGroup[] => [
  { items: search(customers.value, query, (c) => c.phone ?? '').map((c) => ({ id: c.id, label: c.name, sub: formatPhone(c.phone) || undefined })) },
]
const deviceGroups = (query: string): ComboboxGroup[] => [
  { items: search(devices.value, query, (d) => d.serial ?? '').map((d) => ({ id: d.id, label: d.name, sub: d.serial ?? undefined })) },
]

const statusChoices = computed<Choice[]>(() => {
  const o = order.value
  if (!o || !access.value) return []
  const allowed: OrderStatus[] = access.value.transitions.filter((status) => status !== 'canceled')
  // In the order of the work (quote → done), the current one marked with ✓.
  return STATUSES.filter((status) => status === o.status || allowed.includes(status)).map((status) => ({ id: status, label: statusText(status), dot: STATUS_DOT[status], current: status === o.status }))
})
const teamChoices = computed<Choice[]>(() => [
  ...team.value.map((member) => ({ id: member.id, label: member.name, current: member.id === order.value?.assignedTo?.id })),
  ...(order.value?.assignedTo ? [{ id: 'none', label: t('orderResponsibleRemove'), danger: true }] : []),
])

/** The "…" menu: only what this order and this person allow (order.menu.view). */
const menuChoices = computed<Choice[]>(() => {
  const o = order.value
  const a = access.value
  if (!o || !a) return []
  const list: Choice[] = []
  if (a.transitions.some((status) => status !== 'canceled')) list.push({ id: 'status', label: t('orderMenuChangeStatus') })
  if (a.canChangeHold) list.push({ id: isHeld(o) ? 'resume' : 'hold', label: isHeld(o) ? t('orderHoldResume') : t('orderHoldMark') })
  if (a.canDiscount && o.status !== 'quote' && o.status !== 'canceled' && (money$.value?.remaining ?? 0) > 0) list.push({ id: 'discount', label: t('orderAddDiscount') })
  if (a.canEditMainFields && !o.dueDate) list.push({ id: 'due', label: t('orderAddDueDate') })
  if (a.canEditMainFields && !o.scheduledDate && useScheduling.value) list.push({ id: 'schedule', label: t('orderAddSchedule') })
  if (a.canAssign && !o.assignedTo) list.push({ id: 'assignee', label: t('orderAddResponsible') })
  if (a.canEditMainFields) list.push({ id: 'device', label: t('orderAddAnotherDevice', { device: deviceLabel().toLocaleLowerCase() }) })
  list.push({ id: 'share', label: t('shareTitle') })
  // order.pdf.view: the same rule as the app (canShareOrderPdf), values only for who sees them.
  if (canPrint.value) list.push({ id: 'pdf', label: t('web.order.pdf') })
  if (canPrint.value) list.push({ id: 'print', label: t('web.order.print') })
  // The server decides the rest (already has a nota, no service with value, not set up) and the dialog says why.
  if (nfseOn.value && can('chargeOrder') && o.status !== 'quote' && o.status !== 'canceled') list.push({ id: 'invoice', label: t('nfseIssueAction') })
  if (a.transitions.includes('canceled')) list.push({ id: 'cancel', label: t('orderMenuCancel', { order: orderShort() }), danger: true })
  if (a.canDelete) list.push({ id: 'delete', label: t('orderMenuDelete', { order: orderShort() }), danger: true })
  return list
})

function onMenu(id: string) {
  dialog.value = null
  if (id === 'status') dialog.value = { kind: 'status' }
  else if (id === 'hold') dialog.value = { kind: 'hold' }
  else if (id === 'resume') void run(() => writes.resumeOrder(order.value!.id), t('web.order.resumed'))
  else if (id === 'discount') dialog.value = { kind: 'discount' }
  else if (id === 'due') dialog.value = { kind: 'due' }
  else if (id === 'schedule') dialog.value = { kind: 'schedule' }
  else if (id === 'assignee') void openPicker('assignee')
  else if (id === 'device') void openPicker('device')
  else if (id === 'print') print()
  else if (id === 'pdf') pdfOpen.value = true
  else if (id === 'invoice') issuing.value = true
  else if (id === 'share') dialog.value = { kind: 'share' }
  else if (id === 'cancel') dialog.value = { kind: 'cancel' }
  else if (id === 'delete') dialog.value = { kind: 'delete' }
}

function openPendingForm(id: string) {
  dialog.value = null
  formsRef.value?.open(id)
}

function print() {
  printing.value = true
  window.addEventListener('afterprint', () => (printing.value = false), { once: true })
  requestAnimationFrame(() => window.print())
}

function onPhrase() {
  const o = order.value
  if (!o || !access.value) return
  if (o.status === 'done' && access.value.canReceive && (money$.value?.remaining ?? 0) > 0) dialog.value = { kind: 'receive' }
  else if (o.dueDate && access.value.canEditMainFields) dialog.value = { kind: 'due' }
}
const phraseActs = computed(() => {
  const o = order.value
  if (!o || !access.value) return false
  return (o.status === 'done' && access.value.canReceive) || (!!o.dueDate && access.value.canEditMainFields && o.status !== 'done')
})

// Keys of the open order (WEB_APP_DESIGN, Teclado). Only outside fields.
const removers = [
  registerShortcut({ keys: 'a', label: 'web.shortcuts.addItem', run: () => canAddItems.value && void openPicker('addItem') }),
  registerShortcut({ keys: 's', label: 'web.shortcuts.status', run: () => statusChoices.value.length > 1 && (dialog.value = { kind: 'status' }) }),
  registerShortcut({ keys: 'c', label: 'web.shortcuts.customer', run: () => access.value?.canEditMainFields && void openPicker('customer') }),
  registerShortcut({ keys: 'd', label: 'web.shortcuts.schedule', run: () => access.value?.canEditMainFields && (dialog.value = { kind: 'schedule' }) }),
  registerShortcut({ keys: 'm', label: 'web.shortcuts.share', run: () => order.value && (dialog.value = { kind: 'share' }) }),
  registerShortcut({ keys: 'r', label: 'web.shortcuts.receive', run: () => access.value?.canReceive && (money$.value?.remaining ?? 0) > 0 && (dialog.value = { kind: 'receive' }) }),
]
onBeforeUnmount(() => removers.forEach((remove) => remove()))
watch(
  () => order.value?.status,
  (status, old) => {
    if (status && old && status !== old) announce(t('web.order.statusChanged', { status: statusText(status) }))
  },
)
</script>

<template>
  <section class="od" :aria-label="order ? `${orderTitle(order)}, ${order.customer?.name ?? ''}` : t('web.orders.panel')" data-testid="order-detail">
    <div class="od-top">
      <span v-if="order" class="num">{{ orderTitle(order) }}</span>
      <span class="spacer"></span>
      <button v-if="order && menuChoices.length" ref="menuButton" type="button" class="icon-btn" :aria-label="t('orderMoreActions')" @click="dialog = { kind: 'menu' }">
        <MoreHorizontal :size="18" aria-hidden="true" />
      </button>
      <button type="button" class="icon-btn" :aria-label="t('close')" @click="emit('close')"><X :size="18" aria-hidden="true" /></button>
    </div>

    <LoadingState v-if="state.kind === 'loading'" />
    <div v-else-if="state.kind === 'notFound'" class="empty" role="alert">
      <h2>{{ t('web.order.notFound', { order: orderShort() }) }}</h2>
      <p>{{ t('web.order.notFoundBody') }}</p>
      <button type="button" class="btn" @click="emit('close')">{{ t('back') }}</button>
    </div>
    <ErrorState v-else-if="state.kind === 'failed'" :retry="() => watcher?.retry()" />

    <div v-else-if="order && access" class="od-scroll" tabindex="-1" data-od-focus>
      <header class="od-head">
        <h2 class="od-h">
          <button v-if="access.canEditMainFields && order.customer?.name" type="button" class="od-name" :aria-label="t('web.order.changeCustomer', { name: order.customer.name })" @click="openPicker('customer')">
            {{ order.customer.name }}
          </button>
          <span v-else class="od-name">{{ order.customer?.name || orderTitle(order) }}</span>
        </h2>
        <button v-if="!order.customer?.name && access.canEditMainFields" type="button" class="link" @click="openPicker('customer')">{{ t('orderPickCustomerRow') }}</button>
        <p v-if="order.devices.length" class="od-device-line">
          <span v-for="(device, index) in order.devices" :key="device.id ?? index">{{ index ? ' · ' : '' }}{{ device.name }}<template v-if="device.serial"> · <span class="num">{{ device.serial }}</span></template></span>
        </p>
        <button v-else-if="access.canEditMainFields" type="button" class="link od-device-add" @click="openPicker('device')">
          {{ t('orderPickDevice', { device: deviceLabel().toLocaleLowerCase() }) }}
        </button>
        <div class="od-state">
          <StatusLabel :status="order.status" :held="isHeld(order)" :late-text="lateText(order, now) ? t('orderOverdue') : null" :text="lateText(order, now) ? undefined : statusText(order.status)" data-testid="order-status" />
          <button v-if="phrase && phraseActs" type="button" class="od-sentence link-plain" :class="{ 'od-sentence--late': phrase.late }" @click="onPhrase">{{ phrase.text }}</button>
          <span v-else-if="phrase" class="od-sentence" :class="{ 'od-sentence--late': phrase.late }">{{ phrase.text }}</span>
        </div>
        <p v-if="holdLine" class="od-hold" data-testid="hold-line">
          <strong>{{ holdLine.reason }}</strong> · {{ holdLine.days }}<template v-if="holdLine.note"><br /><span class="muted">{{ holdLine.note }}</span></template>
        </p>
        <div class="od-actions">
          <button v-if="step" type="button" class="btn" :class="{ 'btn--primary': !(step.kind === 'receive' && !noLinkKnown) }" :disabled="busy" data-testid="next-step" @click="runStep">{{ stepLabel }}</button>
          <button type="button" class="link" data-testid="share-open" @click="dialog = { kind: 'share' }">{{ t('shareTitle') }}</button>
          <button v-if="access.canChangeHold && !isHeld(order) && isActive(order)" type="button" class="link" @click="dialog = { kind: 'hold' }">{{ t('orderHoldMark') }}</button>
        </div>
      </header>

      <div class="od-body">
        <section v-if="showItems" class="od-sec od-sec--items" aria-labelledby="od-items-title">
          <h3 id="od-items-title">
            {{ t('orderServicesAndParts') }}
            <button v-if="canAddItems" type="button" class="link" @click="openPicker('addItem')">{{ t('orderAddItemRow') }}</button>
          </h3>
          <template v-for="group in groups" :key="group.device?.id ?? 'general'">
            <h4 v-if="order.devices.length > 1" class="od-group">{{ group.device ? [group.device.name, group.device.serial].filter(Boolean).join(' - ') : t('generalNoDevice') }}</h4>
            <ul v-if="group.lines.length" class="items">
              <li v-for="(line, index) in group.lines" :key="line.id ?? index" class="item" data-testid="order-line">
                <span>
                  <span class="item-name"><span v-if="line.id && aiLines.includes(line.id)" class="ai" :title="t('orderAssistantMarked')">✦ </span>{{ line.name }}</span>
                  <span class="sub">{{ lineKindText(line.kind) }}<template v-if="line.kind === 'product'"> · {{ t('orderItemQuantityValue', { count: line.quantity ?? 1 }) }}</template></span>
                  <span v-if="line.description && line.description !== line.name" class="sub">{{ line.description }}</span>
                </span>
                <span v-if="showsMoney" class="num">{{ (line.kind === 'product' ? line.total : line.value) === null ? t('catalogNoPrice') : money(line.kind === 'product' ? line.total : line.value) }}</span>
                <span v-else></span>
                <button v-if="access.canEditMainFields && line.id" type="button" class="link" :aria-label="t('web.order.editLine', { name: line.name })" @click="dialog = { kind: 'item', line }">{{ t('web.order.change') }}</button>
                <span v-else></span>
              </li>
            </ul>
          </template>
          <p v-if="!order.lines.length" class="muted">{{ t('web.order.noItems') }}</p>
        </section>

        <section v-if="showsMoney && money$" class="od-sec od-sec--money" aria-labelledby="od-money-title">
          <h3 id="od-money-title" class="sr">{{ t('orderTotalLabel') }}</h3>
          <dl class="receipt" data-testid="order-totals">
            <div v-if="money$.discount"><dt>{{ t('subtotal') }}</dt><dd>{{ money(money$.subtotal) }}</dd></div>
            <div v-if="money$.discount"><dt>{{ t('discount') }}</dt><dd>− {{ money(money$.discount) }}</dd></div>
            <div class="is-total"><dt>{{ t('orderTotalLabel') }}</dt><dd>{{ money(money$.total) }}</dd></div>
            <div v-if="money$.paid && moneyRowTone"><dt>{{ t('received') }}</dt><dd>{{ money(money$.paid) }}</dd></div>
            <div v-if="moneyRowTone && money$.remaining > 0" class="is-rest"><dt>{{ t('financialToReceive') }}</dt><dd>{{ money(money$.remaining) }}</dd></div>
            <div v-else-if="moneyRowTone && money$.total > 0" class="is-paid"><dt>{{ t('orderFullyPaid') }}</dt><dd>✓</dd></div>
          </dl>
          <p v-if="money$.unpricedCount" class="sub">{{ t('orderUnpricedCount', { count: money$.unpricedCount }) }}</p>
          <button v-if="access.canReceive && moneyRowTone && money$.remaining > 0 && step?.kind !== 'receive'" type="button" class="link" @click="dialog = { kind: 'receive' }">{{ t('receiveTitle') }}</button>
          <p v-if="!moneyRowTone && order.transactions.length" class="sub" data-testid="blocked-status">{{ t('web.receive.blockedStatus', { status: statusText(order.status) }) }}</p>
          <PaymentHistory :order="order" :can-receive="access.canReceive && !!moneyRowTone" :can-discount="access.canDiscount && !!moneyRowTone" :busy="busy" @remove="removePayment" @undo-all="undoAllPayments" />
          <OrderCharge v-if="showCharge" :key="order.id" :order="order" :remaining="money$.remaining" :can-charge="can('chargeOrder')" @open="(open) => (linkOpen = open)" />
        </section>

        <OrderPhotos :order="order" />
        <OrderComments :order-id="order.id" />
        <OrderForms ref="formsRef" :order="order" @forms="(list: { id: string; status: string }[]) => (orderForms = list)" />

        <section class="od-sec od-sec--details" aria-labelledby="od-details-title">
          <h3 id="od-details-title">{{ t('details') }}</h3>
          <dl class="kv">
            <template v-if="order.dueDate || access.canEditMainFields">
              <dt>{{ t('orderDueLabel') }}</dt>
              <dd>
                <button v-if="access.canEditMainFields" type="button" class="link" @click="dialog = { kind: 'due' }">{{ order.dueDate ? whenText(order.dueDate, now) : t('orderDueNone') }}</button>
                <span v-else>{{ whenText(order.dueDate as string, now) }}</span>
              </dd>
            </template>
            <template v-if="order.scheduledDate || (access.canEditMainFields && useScheduling)">
              <dt>{{ t('orderScheduleLabel') }}</dt>
              <dd>
                <button v-if="access.canEditMainFields" type="button" class="link" @click="dialog = { kind: 'schedule' }">{{ order.scheduledDate ? whenText(order.scheduledDate, now) : t('orderDueNone') }}</button>
                <span v-else>{{ whenText(order.scheduledDate as string, now) }}</span>
              </dd>
            </template>
            <template v-if="order.assignedTo || access.canAssign">
              <dt>{{ t('orderAddResponsible') }}</dt>
              <dd>
                <button v-if="access.canAssign" type="button" class="link" @click="openPicker('assignee')">{{ order.assignedTo?.name || t('web.order.nobody') }}</button>
                <span v-else>{{ order.assignedTo?.name }}</span>
              </dd>
            </template>
            <template v-if="order.address">
              <dt>{{ t('orderAddressLabel') }}</dt>
              <dd>
                {{ order.address }}
                <a class="link" :href="`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(order.address)}`" target="_blank" rel="noopener">{{ t('openInMaps') }}</a>
              </dd>
            </template>
          </dl>
        </section>
      </div>
    </div>
    <OrderAssistant v-if="order && access?.canEditMainFields" :order="order" @added="(ids) => (aiLines = [...aiLines, ...ids])" @undone="(ids) => (aiLines = aiLines.filter((id) => !ids.includes(id)))" />
  </section>

  <template v-if="order && access && dialog">
    <ChoiceDialog v-if="dialog.kind === 'menu'" :anchor="menuButton" :title="orderTitle(order)" :choices="menuChoices" @pick="onMenu" @close="dialog = null" />
    <ChoiceDialog v-else-if="dialog.kind === 'status'" :title="t('pickerStatusTitle')" :sub="orderTitle(order)" :choices="statusChoices" @pick="(id) => (id === order!.status ? (dialog = null) : setStatus(id as OrderStatus))" @close="dialog = null" />
    <ChoiceDialog v-else-if="dialog.kind === 'assignee'" :title="t('pickerAssigneeTitle')" :choices="teamChoices" @pick="assign" @close="dialog = null" />
    <ConfirmDialog
      v-else-if="dialog.kind === 'cancel'"
      :title="t('orderCancelConfirmTitle', { order: orderTitle(order) })"
      :body="t('orderCancelConfirmMessage')"
      :confirm="t('orderMenuCancel', { order: orderShort() })"
      :keep="t('web.order.keep')"
      danger
      @confirm="setStatus('canceled')"
      @close="dialog = null"
    />
    <ConfirmDialog
      v-else-if="dialog.kind === 'delete'"
      :title="t('orderDeleteConfirmTitle', { order: orderTitle(order) })"
      :body="t('orderDeleteConfirmMessage')"
      :confirm="t('orderMenuDelete', { order: orderShort() })"
      :keep="t('web.order.keep')"
      danger
      @confirm="deleteIt"
      @close="dialog = null"
    />
    <ConfirmDialog
      v-else-if="dialog.kind === 'keepDevices'"
      :title="t('web.order.dropDevicesTitle', { device: deviceLabel().toLocaleLowerCase() })"
      :body="t('web.order.dropDevicesBody', { devices: order.devices.map((d) => d.name).join(', '), customer: dialog.customer.name })"
      :confirm="t('web.order.dropDevices')"
      :keep="t('cancel')"
      @confirm="applyCustomer((dialog as { customer: Customer }).customer, true)"
      @close="dialog = null"
    />
    <ConfirmDialog
      v-else-if="dialog.kind === 'pendingForms'"
      :title="t('orderPendingChecklists', { count: dialog.count })"
      :body="t('web.forms.pendingBody')"
      :confirm="t('orderOpenChecklist')"
      :keep="t('notNow')"
      @confirm="openPendingForm((dialog as { first: string }).first)"
      @close="dialog = null"
    />
    <HoldDialog v-else-if="dialog.kind === 'hold'" @save="hold" @close="dialog = null" />
    <DateDialog v-else-if="dialog.kind === 'due'" :title="t('orderAddDueDate')" :label="t('orderDueLabel')" :value="order.dueDate" :clear-label="t('web.order.clearDue')" @save="(value) => saveDate('dueDate', value)" @close="dialog = null" />
    <DateDialog v-else-if="dialog.kind === 'schedule'" :title="t('orderAddSchedule')" :label="t('orderScheduleLabel')" :value="order.scheduledDate" :clear-label="t('orderScheduleRemove')" @save="(value) => saveDate('scheduledDate', value)" @close="dialog = null" />
    <MoneyDialog v-else-if="dialog.kind === 'receive' && money$" kind="receive" :remaining="money$.remaining" :total="money$.total" :busy="busy" :created-at="order.createdAt" :link-note="linkOpen === true ? (order.customer?.name ? t('receiveChargeAdjusts', { customer: order.customer.name }) : t('receiveChargeAdjustsNoName')) : ''" @save="receive" @close="dialog = null" />
    <ShareDialog v-else-if="dialog.kind === 'share'" :order="order" @pick-customer="openPicker('customer')" @close="dialog = null" />
    <MoneyDialog v-else-if="dialog.kind === 'discount' && money$" kind="discount" :remaining="money$.remaining" :total="money$.total" :busy="busy" @save="discount" @close="dialog = null" />
    <ItemDialog v-else-if="dialog.kind === 'item'" :line="dialog.line" :shows-money="showsMoney" :can-edit-price="can('editPrices')" :busy="busy" @save="(patch) => saveLine((dialog as { line: OrderLine }).line, patch)" @remove="removeLine((dialog as { line: OrderLine }).line)" @close="dialog = null" />
    <ComboDialog v-else-if="dialog.kind === 'addItem'" id="od-add-item" :title="t('pickerItemTitle')" :label="t('orderItemSearchPlaceholder')" :groups="itemGroups" @pick="pickItem" @close="dialog = null" />
    <ComboDialog v-else-if="dialog.kind === 'customer'" id="od-customer" :title="t('pickCustomerTitle')" :label="t('customer')" :groups="customerGroups" :selected-id="order.customer?.id" @pick="(item) => chooseCustomer(customers.find((c) => c.id === item.id) as Customer)" @close="dialog = null" />
    <ComboDialog v-else-if="dialog.kind === 'device'" id="od-device" :title="t('orderPickDevice', { device: deviceLabel().toLocaleLowerCase() })" :label="deviceLabel()" :groups="deviceGroups" @pick="(item) => addDevice(devices.find((d) => d.id === item.id) as Device)" @close="dialog = null" />
  </template>
  <PdfDialog v-if="pdfOpen && order" :ids="[order.id]" :numbers="[order.number]" @close="pdfOpen = false" />
  <IssueInvoiceDialog v-if="issuing && order" :order-ids="[order.id]" :customer-id="order.customer?.id ?? null" @done="issuing = false" @close="issuing = false" />
  <OrderPrint v-if="printing && order" :order="order" />
</template>
