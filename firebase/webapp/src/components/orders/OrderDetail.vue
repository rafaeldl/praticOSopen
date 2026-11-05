<script setup lang="ts">
// The open order, beside the list: who (customer, device), where it stands
// (status and one phrase), the next step in blue, then what is done, money,
// photos, comments and details. Each row opens its own editor; there is no
// "Editar" mode. Money, status and items go through the API (writes.ts).
import { computed, defineAsyncComponent, nextTick, onBeforeUnmount, onMounted, ref, shallowRef, watch } from 'vue'
import { MoreHorizontal, X } from '@lucide/vue'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import StatusLabel from '@/components/StatusLabel.vue'
import type { ComboboxGroup, ComboboxItem } from '@/components/Combobox.vue'
import { loadTexts, locale, t } from '@/i18n'
import { ApiError, errorMessageKey } from '@/lib/api'
import { orderChanged, orderRemoved } from '@/lib/orders/bus'
import { canRegisterItem, forgetLists, loadCatalog, loadCustomers, loadDevices, loadTeam, search, type CatalogItem, type Customer, type Device, type Member } from '@/lib/orders/catalog'
import { devicesOfCustomer, mostUsedKeys, ownerOf, plateHits, plateOwnerName, recentCustomers, type Named } from '@/lib/orders/pickers'
import { listContext, watchOrder, type DetailState } from '@/lib/orders/data'
import { loadLegacyRequest, readRequest, requestField, withRequest } from '@/lib/orders/request'
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
  country,
} from '@/lib/orders/text'
import * as writes from '@/lib/orders/writes'
import { formatPhone } from '@/lib/phone'
import { can, effectiveUseFinancial, session } from '@/lib/session'
import { useRouter } from 'vue-router'
import { canOpen } from '@/router'
import { featureOn } from '@/lib/company-features'
import { segmentFieldService } from '@/lib/segments'
import { registerShortcut } from '@/lib/shortcuts'
import { registerCommand } from '@/lib/commands'
import { preferredStep, rememberMethod, rememberTransition, suggestedMethod } from '@/lib/orders/suggest'
import { currentToast, showToast } from '@/lib/toast'
import { announce, ui } from '@/lib/ui'
import ChoiceDialog, { type Choice } from './ChoiceDialog.vue'
import ComboDialog from './ComboDialog.vue'
import QuickCreate from './QuickCreate.vue'
import Layer from '@/components/Layer.vue'
import { loadCustomer, loadDevice, saveDevice, type CustomerDetail, type DeviceDetail } from '@/lib/customers/data'
import { customerSummary, missingOnOrder, type Missing } from '@/lib/orders/quick-create'
import { resolveLabel, segmentLabels } from '@/lib/segments'
import * as maintenance from '@/lib/orders/maintenance-offer'
import { askNotificationsOnce } from '@/lib/push'
import { NOTIFY_NOTE_MS, shouldOfferStatusShare } from '@/lib/orders/notify'
import { formatMonthYear, fromIsoDay, toIsoDay } from '@/lib/format'
import TextDialog from './TextDialog.vue'
import ReadingDialog from './ReadingDialog.vue'
import { deviceReading, formatReading, readingAdvances, readingFieldOf, withReading } from '@/lib/device-reading'
import { fieldTitle, segmentFieldList } from '@/lib/segment-fields'
import OrderCustomFields from './OrderCustomFields.vue'
import ConfirmDialog from './ConfirmDialog.vue'
import DateDialog from './DateDialog.vue'
import HoldDialog from './HoldDialog.vue'
import ItemDialog from './ItemDialog.vue'
import { canChangeCatalogPrice, catalogPriceOffer, mayOfferCatalogPrice, type CatalogPriceOffer } from '@/lib/orders/catalog-price'
import { changedSince, loadItem as loadCatalogItem, saveItem as saveCatalogItem } from '@/lib/catalog/data'
import DevicePickerDialog from './DevicePickerDialog.vue'
import { deviceIdsOf, type PickResult } from '@/lib/orders/device-pick'
import { currentCustomerId } from '@/lib/orders/assist-draft'
import MoneyDialog from './MoneyDialog.vue'
import OrderComments from './OrderComments.vue'
import OrderPhotos from './OrderPhotos.vue'
import OrderDocuments from './OrderDocuments.vue'
import OrderPrint from './OrderPrint.vue'
import OrderAssistant from './OrderAssistant.vue'
import PaymentHistory from './receive/PaymentHistory.vue'
import { dropUpload, paymentSettings, removeProof, removeTransaction, resetPayments, setProof, uploadProof } from '@/lib/receive/data'
import { receivesMoney, type Payment } from '@/lib/receive/model'
import { canHaveNfse, isActive as nfseIsActive, nfseNextStep, type NfseInvoice } from '@/lib/nfse/model'
// Opened on demand: the order shows without them.
const ReceiptsDialog = defineAsyncComponent(() => import('./receive/ReceiptsDialog.vue'))
const ShareDialog = defineAsyncComponent(() => import('./receive/ShareDialog.vue'))
const OrderCharge = defineAsyncComponent(() => import('./receive/OrderCharge.vue'))
// Notas fiscais (fatia 6): the dialog and its texts come only when asked for.
const OrderNfse = defineAsyncComponent(() => Promise.all([import('@/components/finance/OrderNfse.vue'), loadTexts('finance')]).then(([m]) => m))
// The full forms behind "Mais dados" and the order's "+ WhatsApp" / "+ Placa" (order.quick.*), with the cadastros' texts.
const CustomerForm = defineAsyncComponent(() => Promise.all([import('@/components/customers/CustomerForm.vue'), loadTexts('customers')]).then(([m]) => m))
const DeviceForm = defineAsyncComponent(() => Promise.all([import('@/components/customers/DeviceForm.vue'), loadTexts('customers')]).then(([m]) => m))
const IssueInvoiceDialog = defineAsyncComponent(() => Promise.all([import('@/components/finance/IssueInvoiceDialog.vue'), loadTexts('finance')]).then(([m]) => m))
// Checklists, after the order shows (their texts are in the orders chunk).
const PdfDialog = defineAsyncComponent(() => import('./PdfDialog.vue'))
const OrderForms = defineAsyncComponent(() => import('@/components/forms/OrderForms.vue'))
// Contract of the order (repeats, next order, created ones), after the order shows.
const OrderContract = defineAsyncComponent(() => import('@/components/contracts/OrderContract.vue'))

const props = defineProps<{ orderId: string }>()
const emit = defineEmits<{ close: [] }>()

const ctx = listContext()
const router = useRouter()
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
  | { kind: 'catalogPrice'; offer: CatalogPriceOffer }
  | { kind: 'addItem' }
  | { kind: 'customer' }
  | { kind: 'address' }
  | { kind: 'request' }
  | { kind: 'reading'; deviceId: string; name: string }
  | { kind: 'device'; current?: { id: string; name: string } }
  | { kind: 'keepDevices'; customer: Customer }
  | { kind: 'share'; send?: boolean }
  | { kind: 'pendingForms'; count: number; first: string }
  | { kind: 'devicesFor'; name: string; add: (deviceId: string | null) => Promise<unknown> }
  | { kind: 'quick'; quick: 'device' | 'item'; text: string }
  | { kind: 'newDevice'; draft: { name: string; serial: string } }
  | { kind: 'editCustomer'; detail: CustomerDetail }
  | { kind: 'editDevice'; detail: DeviceDetail }
const dialog = shallowRef<Dialog | null>(null)
const menuButton = ref<HTMLElement | null>(null)
const catalog = shallowRef<CatalogItem[]>([])
const customers = shallowRef<Customer[]>([])
const devices = shallowRef<Device[]>([])
const team = shallowRef<Member[]>([])

const order = computed(() => (state.value.kind === 'ready' ? state.value.order : null))
const access = computed(() => (order.value ? accessOf(order.value, session.role, session.uid, effectiveUseFinancial()) : null))
// Money said on a Nova OS waits for this order's assistant; without it (no editing here), it is dropped.
watch(access, (value) => {
  if (value && !value.canEditMainFields && ui.aiActionsFor?.orderId === order.value?.id) ui.aiActionsFor = null
})
const money$ = computed(() => (order.value ? totals(order.value) : null))
/**
 * The blue step. From a status, where this person went from it last time wins
 * when still allowed (approved → done for who skips "Em andamento"): the choice
 * comes ready and P confirms it (timed-comparison T3).
 */
const step = computed(() => {
  if (!order.value || !access.value) return null
  const base = nextStep(order.value, access.value)
  // Finished and paid: the nota is the next step, for who issues (order.nfse.next-step).
  if (!base && nfseOn.value && nfseLoaded.value && can('chargeOrder')) {
    const nota = nfseNextStep(order.value, nfseCurrent.value, nfseReady.value, money$.value?.remaining ?? 0)
    if (nota) return { kind: 'nfse' as const, fix: nota === 'fix' }
  }
  if (base?.kind !== 'status') return base
  const preferred = preferredStep(session.companyId, order.value.status, access.value.transitions)
  return preferred ? { kind: 'status' as const, to: preferred } : base
})
const phrase = computed(() => (order.value ? headerPhrase(order.value, now.value, money$.value?.remaining ?? null) : null))
const showsMoney = computed(() => !!order.value?.showsMoney)
const canAddItems = computed(() => !!access.value?.canEditMainFields && (can('viewServices') || can('viewProducts')))
const showItems = computed(() => !!order.value && (order.value.lines.length > 0 || !!access.value?.canEditMainFields))
const groups = computed(() => (order.value ? linesByDevice({ ...order.value, lines: order.value.lines.filter((line) => !line.id || !hiddenLines.value.includes(line.id)) }) : []))
const useScheduling = computed(() => session.company && (session.company as { useScheduling?: boolean }).useScheduling !== false)
/**
 * "O que o cliente pediu" (order.request.edit): the segment's field, as the app.
 * While the field is empty, the request the old web Nova OS saved as a comment
 * is shown in its place (read only; the comment stays where it is).
 */
const reqField = computed(() => requestField())
const savedRequest = computed(() => (reqField.value && order.value ? readRequest(order.value.customData, reqField.value) : ''))
const oldRequest = ref('')
const requestText = computed(() => savedRequest.value || oldRequest.value)
watch(
  () => [order.value?.id, !!reqField.value, !!savedRequest.value] as const,
  async ([id, has, saved]) => {
    oldRequest.value = ''
    if (!id || !has || saved || !order.value) return
    const text = await loadLegacyRequest(order.value)
    if (order.value?.id === id) oldRequest.value = text
  },
  { immediate: true },
)

/**
 * The device's reading at this visit (docs/DEVICE_READING.md): "Quilometragem:
 * 98.000 km" under the devices, "+ Quilometragem" while an open order has none.
 * Nothing when the segment has no reading.
 */
const reading = computed(() => readingFieldOf(segmentFieldList()))
const readingTitle = computed(() => (reading.value ? fieldTitle(reading.value, locale.value) : ''))
const readingRows = computed(() => {
  const o = order.value
  const field = reading.value
  if (!o || !field) return []
  const open = ['quote', 'approved', 'progress'].includes(o.status)
  return o.devices
    .filter((device): device is typeof device & { id: string } => !!device.id)
    .map((device) => {
      const value = o.deviceReadings?.[device.id] ?? null
      return { id: device.id, name: device.name || device.serial || deviceLabel(), value, text: formatReading(field, value, session.company?.country) }
    })
    .filter((row) => row.text || (open && !!access.value?.canEditMainFields))
})

async function saveReading(deviceId: string, value: number | null) {
  dialog.value = null
  const o = order.value
  const field = reading.value
  if (!o || !field || (o.deviceReadings?.[deviceId] ?? null) === value) return
  const saved = await run(() => writes.updateOrderFields(o.id, { deviceReadings: withReading(o.deviceReadings, deviceId, value) }), t('web.saved'))
  if (!saved || value === null || !can('manageDevices')) return
  // The device keeps its last reading, never going back (the app's recordDeviceReading).
  try {
    const { device, version } = await loadDevice(deviceId)
    const current = deviceReading(device.customData, field)
    if (!readingAdvances(current, value) || current === value) return
    const name = field.key.split('.').pop() as string
    await saveDevice(deviceId, { customData: { ...(device.customData ?? {}), [name]: value }, ...(version ? { version } : {}) })
  } catch {
    // The order keeps the reading; the device form edits it by hand.
  }
}

async function saveRequest(text: string) {
  dialog.value = null
  const o = order.value as Order
  const field = reqField.value
  if (!field || text.trim() === requestText.value) return
  await run(() => writes.updateOrderFields(o.id, { customData: withRequest(o.customData, field, text) }), t('web.saved'))
}
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
  if (value.kind === 'nfse') return value.fix ? t('nfseFixAndIssue') : t('nfseIssueAction')
  return value.to === 'approved' ? t('orderActionApproveQuote') : value.to === 'progress' ? t('orderActionStartService') : t('web.order.markDone')
})
const STATUS_DOT: Record<OrderStatus, string> = { quote: 'neutral', approved: 'accent', progress: 'warning', done: 'success', canceled: 'hollow' }

let watcher: ReturnType<typeof watchOrder> | undefined
/** Payment links of Asaas: pilot on and account connected, for who charges (chargeOrder). */
const chargesOn = ref(false)
/** Notas fiscais on for the company (settings/payments): "Emitir nota fiscal" in the menu, for chargeOrder. */
const nfseOn = ref(false)
/** The nota setup is done (nfseReady): the nota can be the blue step (order.nfse.next-step). */
const nfseReady = ref(false)
/** The order's current nota, as OrderNfse reads it (live). */
const nfseCurrent = shallowRef<NfseInvoice | null>(null)
/** The order's notas were read (B8): before that, or after a failed read, no "Emitir". */
const nfseLoaded = ref(false)
const issuing = ref(false)
const pdfOpen = ref(false)
/** The receipt over several orders that a payment belongs to (pay.order.open-receipt-group). */
const receiptOpen = ref<string | null>(null)
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
        nfseReady.value = settings.nfseReady
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
/** Why the last write failed: a refusal by the server (ApiError) or the request never answered (left the page, offline). */
let lastError: unknown = null
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
    lastError = error
    console.warn('order: write failed', error)
    showToast(error instanceof ProofUploadError ? t('receiveCustomerUploadFailed') : t(errorMessageKey(error)))
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
  const was = order.value.status
  // Remembered when chosen, not after the answer: leaving the order right away must not lose it.
  const forget = rememberTransition(session.companyId, was, status)
  const ok = await run(() => writes.patchOrder(order.value!.id, { status }, expected()), t('web.order.statusChanged', { status: statusText(status) }))
  // Only a refusal by the server takes it back; a request cut by leaving the page (NETWORK, status 0) keeps the choice.
  if (!ok && lastError instanceof ApiError && lastError.status > 0) forget()
  if (ok) offerNotify(status)
  // Done now (the server took it): when is the next maintenance? (device.maintenance.offer)
  if (ok && status === 'done' && was !== 'done' && order.value) await offerMaintenance()
}

// Saved already done in the Nova OS: ask once the order is here (device.maintenance.offer).
watch(
  () => order.value?.id,
  async (id) => {
    if (!id || !maintenance.takeAskOnOpen(id) || !order.value || order.value.status !== 'done') return
    await offerMaintenance()
  },
  { immediate: true },
)

const maintenanceChoices = computed<Choice[]>(() => {
  const today = toIsoDay(new Date())
  const option = (id: string, label: string, months: number) => ({ id, label, sub: formatMonthYear(fromIsoDay(maintenance.addMonths(today, months)), country()) })
  return [
    option('3', t('nextMaintenanceThreeMonths'), 3),
    option('6', t('nextMaintenanceSixMonths'), 6),
    option('12', t('nextMaintenanceOneYear'), 12),
    { id: 'none', label: t('nextMaintenanceNoRepeat') },
  ]
})

/**
 * The question sits in the order, not over it: nothing to dismiss before going on
 * (timed-comparison T3). "Agora não", or leaving the order without answering,
 * counts as a refusal and changes nothing.
 */
const offer = shallowRef<{ devices: { id: string; name: string }[] } | null>(null)
async function offerMaintenance() {
  if (!order.value) return
  const devices = await maintenance.devicesToAsk(order.value)
  if (!devices.length) return
  offer.value = { devices }
  announce(`${t('nextMaintenanceQuestion')} ${devices.map((device) => device.name).join(', ')}`)
}
onBeforeUnmount(() => {
  if (offer.value) maintenance.decline()
})

/** device.maintenance.answer / no-repeat. */
async function answerMaintenance(id: string | null) {
  const current = offer.value
  offer.value = null
  if (!current) return
  if (id === null) return maintenance.decline()
  const failed = await maintenance.answer(current.devices.map((device) => device.id), id === 'none' ? null : Number(id), order.value?.id)
  if (failed) showToast(t('nextMaintenanceSaveError'))
  else if (id !== 'none') showToast(t('web.order.maintenanceSaved'))
}

/**
 * "Pronta. Avisar Ana?" (order.status.notify): a note under the actions for 8 s,
 * never an alert, once per order while this screen is open. "Avisar" opens
 * WhatsApp with the link and the words of the new situation (ShareDialog send).
 * Pointer or focus on it holds the time, so no one loses it while reading.
 */
const notify = ref<OrderStatus | null>(null)
const notifyAsked = new Set<string>()
let notifyTimer: ReturnType<typeof setTimeout> | undefined
function offerNotify(status: OrderStatus) {
  if (!order.value || !shouldOfferStatusShare(order.value, status, notifyAsked)) return
  notifyAsked.add(order.value.id)
  notify.value = status
  holdNotify(false)
}
function holdNotify(hold: boolean) {
  clearTimeout(notifyTimer)
  if (!hold && notify.value) notifyTimer = setTimeout(() => (notify.value = null), NOTIFY_NOTE_MS)
}
const notifyText = computed(() => {
  if (!notify.value) return ''
  const name = order.value?.customer?.name?.trim() || t('orderNotifyFallbackName')
  return t('orderNotifyNote', { status: statusText(notify.value), name })
})
function notifyNow() {
  holdNotify(true)
  notify.value = null
  dialog.value = { kind: 'share', send: true }
}
watch(() => order.value?.id, () => {
  holdNotify(true)
  notify.value = null
})
onBeforeUnmount(() => clearTimeout(notifyTimer))

/** order.pdf.share by WhatsApp: the PDF was downloaded; the customer gets the order's link. */
function sharePdfLink() {
  pdfOpen.value = false
  dialog.value = { kind: 'share', send: true }
}

async function runStep() {
  const value = step.value
  if (!value || !order.value) return
  if (value.kind === 'status') await setStatus(value.to)
  else if (value.kind === 'resume') await run(() => writes.resumeOrder(order.value!.id), t('web.order.resumed'))
  else if (value.kind === 'nfse') issuing.value = true
  else dialog.value = { kind: 'receive' }
}

async function hold(reason: HoldReason, note: string) {
  dialog.value = null
  await run(() => writes.markOnHold(order.value!.id, reason, note || undefined), t('web.order.held'))
}

async function saveDate(field: 'dueDate' | 'scheduledDate', value: string | null) {
  dialog.value = null
  const ok = await run(() => writes.patchOrder(order.value!.id, { [field]: value }, expected()), t('web.saved'))
  // A visit marked on a saved order: the browser's notifications, the first time (order.offer.notifications).
  if (ok && field === 'scheduledDate' && value) askNotificationsOnce()
}

async function assign(id: string) {
  dialog.value = null
  await run(() => writes.patchOrder(order.value!.id, { assignedTo: id === 'none' ? null : id }, expected()), t('web.saved'))
}

async function receive(value: { amount: number; paymentMethod?: string; paidAt?: string; clientTransactionId: string; proof?: File }) {
  const { proof, ...body } = value
  if (value.paymentMethod) rememberMethod(session.companyId, value.paymentMethod)
  const id = order.value!.id
  const ok = await run(async () => {
    // The file goes first (to the payment's folder), then the payment carries it.
    const receiptFile = proof ? await uploadProof(id, body.clientTransactionId, proof).catch(() => Promise.reject(new ProofUploadError())) : undefined
    try {
      return await writes.receivePayment(id, { ...body, ...(receiptFile ? { receiptFile } : {}) }, expected())
    } catch (error) {
      // Refused after the upload: the file goes away (it is never anyone's proof).
      if (receiptFile) await dropUpload(receiptFile.storagePath)
      throw error
    }
  }, t('web.order.received', { amount: money(value.amount) }))
  if (ok) dialog.value = null
}

class ProofUploadError extends Error {}

/** Attach or replace (the server deletes the old file) and take out the proof of a payment. */
async function attachProof(payment: Payment, file: File) {
  const id = order.value!.id
  await run(async () => {
    const receiptFile = await uploadProof(id, payment.id as string, file).catch(() => Promise.reject(new ProofUploadError()))
    try {
      return await setProof(id, payment.id as string, receiptFile)
    } catch (error) {
      await dropUpload(receiptFile.storagePath)
      throw error
    }
  }, t('web.receive.proofSaved'))
}

async function detachProof(payment: Payment) {
  await run(() => removeProof(order.value!.id, payment.id as string), t('web.receive.proofRemoved'))
}

async function discount(value: { amount: number; clientTransactionId: string }) {
  const ok = await run(() => writes.giveDiscount(order.value!.id, { amount: value.amount, clientTransactionId: value.clientTransactionId }, expected()), t('web.saved'))
  if (ok) dialog.value = null
}

async function addCatalogItem(item: CatalogItem) {
  await onDevices(item.name, (deviceId) => run(() => writes.addItem(order.value!.id, { kind: item.kind, catalogId: item.id, ...(deviceId ? { deviceId } : {}) }, expected()), t('web.order.itemAdded', { name: item.name })))
}

async function addFreeItem(name: string) {
  await onDevices(name, (deviceId) => run(() => writes.addItem(order.value!.id, { kind: 'service', description: name, ...(deviceId ? { deviceId } : {}) }, expected()), t('web.order.itemAdded', { name })))
}

/** Two or more devices: "Em quais veículos?" first, then the item once per chosen device (order.device-picker.*). */
async function onDevices(name: string, add: (deviceId: string | null) => Promise<unknown>) {
  const withIds = (order.value?.devices ?? []).filter((d) => d.id)
  if (withIds.length < 2) {
    dialog.value = null
    await add(withIds[0]?.id ?? null)
    return
  }
  dialog.value = null
  await nextTick()
  dialog.value = { kind: 'devicesFor', name, add }
}
async function addOnPicked(result: PickResult) {
  const current = dialog.value
  dialog.value = null
  if (current?.kind !== 'devicesFor') return
  const ids = (order.value?.devices ?? []).map((d) => d.id).filter((id): id is string => !!id)
  for (const deviceId of deviceIdsOf(result, ids)) await current.add(deviceId)
}

async function saveLine(line: OrderLine, patch: { description?: string; value?: number | null; quantity?: number; deviceId?: string | null }) {
  if (!Object.keys(patch).length || !line.id) {
    dialog.value = null
    return
  }
  const ok = await run(() => writes.updateItem(order.value!.id, line.id as string, patch, expected()), t('web.saved'))
  if (ok) dialog.value = null
  if (ok) await offerCatalogPrice(line, patch.value)
}

/** A new price on a line from the catalog: only on this order or always (#588)? */
async function offerCatalogPrice(line: OrderLine, to: number | null | undefined) {
  const allowed = canChangeCatalogPrice(line.kind, can)
  if (!mayOfferCatalogPrice(line, to, allowed)) return
  // Read now: the price and version the catalog has, not the one the order kept.
  const item = await loadCatalogItem(line.kind, line.catalogId as string).catch(() => null)
  const offer = catalogPriceOffer(line, to, item, allowed)
  if (offer && !dialog.value) dialog.value = { kind: 'catalogPrice', offer }
}

const catalogEntity = (kind: OrderLine['kind']) => (kind === 'service' ? t('service') : resolveLabel('product._entity', segmentLabels(), (key) => t(key), t('product')))

async function useCatalogPriceAlways(offer: CatalogPriceOffer) {
  dialog.value = null
  try {
    await saveCatalogItem(offer.kind, offer.id, { value: offer.to, ...(offer.version ? { version: offer.version } : {}) })
    forgetLists()
    showToast(t('orderItemCatalogPriceSaved', { to: money(offer.to) }))
  } catch (error) {
    showToast(changedSince(error) ? t('orderItemCatalogPriceFailed') : t(errorMessageKey(error)))
  }
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
  // Enter on the current one (✓, the first highlighted): nothing changes.
  if (customer.id === o.customer?.id) {
    dialog.value = null
    return
  }
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
  // With its coordinates, as the app's OrderStore.setCustomer; never over a place already there.
  if (!o.address && customer.address) Object.assign(fields, { address: customer.address, latitude: customer.latitude ?? null, longitude: customer.longitude ?? null })
  if (dropDevices) Object.assign(fields, { device: null, devices: [], deviceIds: [] })
  await run(() => writes.updateOrderFields(o.id, fields), t('web.saved'))
}

/** Responsável with the name, or the e-mail when the member has no name (order.details.section). */
const assigneeName = computed(() => {
  const who = order.value?.assignedTo as { name?: string; email?: string } | null | undefined
  return who?.name || who?.email || ''
})
// Absent on the company: the segment's default, as the app (auth.gate.feature-defaults).
const fieldService = computed(() => featureOn(session.company as Record<string, unknown> | null, 'fieldService', segmentFieldService()))

/**
 * The place of the order (order.address.edit / remove): a new text drops the
 * coordinates (they belonged to the customer's address); the same text keeps them.
 */
async function saveAddress(text: string | null) {
  dialog.value = null
  const o = order.value as Order
  const next = text?.trim() || null
  if (next === (o.address ?? null)) return
  await run(() => writes.updateOrderFields(o.id, { address: next, latitude: null, longitude: null }), next ? t('web.saved') : t('web.order.addressRemoved'))
}

async function addDevice(device: Device) {
  dialog.value = null
  const o = order.value as Order
  if (o.devices.some((item) => item.id === device.id)) return
  const list = [...o.devices, { id: device.id, name: device.name, ...(device.serial ? { serial: device.serial } : {}) }]
  await saveDevices(list)
}

function saveDevices(list: { id?: string; name?: string; serial?: string | null }[]) {
  const o = order.value as Order
  return run(() => writes.updateOrderFields(o.id, { device: list[0] ?? null, devices: list, deviceIds: list.map((item) => item.id) }), t('web.saved'))
}

/**
 * Changing one device of the order (order.device.change): another replaces it in its
 * place; "Nenhum" takes it out (device.list.pick-none), like the app's _changeDevice.
 */
async function changeDevice(current: { id: string }, picked: ComboboxItem) {
  dialog.value = null
  const o = order.value as Order
  if (picked.id === current.id) return
  const kept = o.devices.filter((item) => item.id !== current.id)
  if (picked.id === NONE) return saveDevices(kept)
  const device = devices.value.find((d) => d.id === picked.id)
  if (!device) return
  if (kept.some((item) => item.id === device.id)) return saveDevices(kept)
  await saveDevices(o.devices.map((item) => (item.id === current.id ? { id: device.id, name: device.name, ...(device.serial ? { serial: device.serial } : {}) } : item)))
}

/** A plate brings its owner and the device together (customer.picker.plate). */
async function pickCustomerItem(item: ComboboxItem) {
  if (!item.id.startsWith(PLATE)) return chooseCustomer((customers.value.find((c) => c.id === item.id) ?? recents.value.find((c) => c.id === item.id)) as Customer)
  const deviceId = item.id.slice(PLATE.length)
  dialog.value = null
  const device = devices.value.find((d) => d.id === deviceId)
  const owner = await ownerOf(deviceId)
  const o = order.value as Order
  if (owner && owner.id !== o.customer?.id) await applyCustomer(customers.value.find((c) => c.id === owner.id) ?? owner, false)
  if (device && !order.value?.devices.some((d) => d.id === device.id)) await addDevice(device)
}

async function openDevicePicker(current: { id?: string; name?: string }) {
  await openPicker('device')
  if (dialog.value?.kind === 'device' && current.id) dialog.value = { kind: 'device', current: { id: current.id, name: current.name ?? '' } }
}

async function openPicker(kind: 'addItem' | 'customer' | 'device' | 'assignee') {
  try {
    if (kind === 'addItem' && !catalog.value.length) catalog.value = await loadCatalog()
    // "Mais usados" as in the Nova OS (order.item-search.most-used); a failure only hides it.
    if (kind === 'addItem' && !mostUsed.value.length) void mostUsedKeys().then((keys) => (mostUsed.value = keys), () => {})
    if (kind === 'customer' && !customers.value.length) customers.value = await loadCustomers()
    if ((kind === 'device' || kind === 'customer') && !devices.value.length) devices.value = await loadDevices()
    if (kind === 'device' && order.value?.customer?.id) ownDevices.value = await devicesOfCustomer(order.value.customer.id, ctx.showsMoney)
    if (kind === 'customer') void recentCustomers().then((list) => (recents.value = list), () => {})
    if (kind === 'assignee' && !team.value.length) team.value = await loadTeam()
  } catch (error) {
    showToast(t(errorMessageKey(error)))
    return
  }
  if (kind === 'assignee' && !team.value.length) return
  dialog.value = { kind }
}

const mostUsed = shallowRef<string[]>([])
const itemGroups = (query: string): ComboboxGroup[] => {
  const list = search(catalog.value, query, (item) => lineKindText(item.kind), 10)
  const row = (item: CatalogItem) => ({
    id: `${item.kind}:${item.id}`,
    label: item.name,
    sub: lineKindText(item.kind),
    right: showsMoney.value ? (item.value === null ? t('catalogNoPrice') : money(item.value)) : undefined,
  })
  return [
    {
      title: t('orderMostUsed'),
      items: query.trim() ? [] : mostUsed.value.map((key) => catalog.value.find((item) => `${item.kind}:${item.id}` === key)).filter((item): item is CatalogItem => !!item).map(row),
    },
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
    {
      items: [
        ...(writes.API_516 && query.trim() ? [{ id: FREE_ITEM, label: t('web.newOrder.useFree', { name: query.trim() }) }] : []),
        // order.item-search.create: into the catalog and onto the order.
        ...(query.trim() && canRegisterItem(catalog.value, query) ? [{ id: REGISTER_ITEM, label: t('web.newOrder.registerItem', { name: query.trim() }) }] : []),
      ],
    },
  ]
}
const FREE_ITEM = '__free'
const REGISTER_ITEM = '__register'
/** order.quick.item: kind and price asked in a small sheet, then into the catalog and onto the order. */
function registerAndAdd(name: string) {
  dialog.value = { kind: 'quick', quick: 'item', text: name }
}

async function onQuickSaved(record: Customer | Device | CatalogItem) {
  const kind = dialog.value?.kind === 'quick' ? dialog.value.quick : null
  dialog.value = null
  if (kind === 'item') {
    catalog.value = [...catalog.value, record as CatalogItem]
    await addCatalogItem(record as CatalogItem)
  } else if (kind === 'device') {
    devices.value = [...devices.value, record as Device]
    await addDevice(record as Device)
  }
}
function onQuickMore(draft: { name: string; serial?: string }) {
  dialog.value = { kind: 'newDevice', draft: { name: draft.name, serial: draft.serial ?? '' } }
}
async function onNewDeviceSaved(id: string) {
  dialog.value = null
  forgetLists()
  devices.value = await loadDevices()
  const created = devices.value.find((d) => d.id === id)
  if (created) await addDevice(created)
}

/**
 * order.quick.complete: what the customer and the devices still lack (WhatsApp,
 * plate/serial, model), as links under them; each opens the record's form over the order.
 */
const label = (key: string) => resolveLabel(key, segmentLabels(), (k) => t(k))
const missing = computed<Missing[]>(() => {
  const o = order.value
  if (!o || !access.value?.canEditMainFields) return []
  return missingOnOrder(o, { customers: can('manageCustomers'), devices: can('manageDevices') })
})
const missingText = (item: Missing) => {
  const device = item.kind === 'phone' ? null : order.value?.devices.find((d) => d.id === item.deviceId)
  const many = (order.value?.devices.length ?? 0) > 1
  const what = item.kind === 'phone' ? t('web.quick.whatsapp') : label(item.kind === 'serial' ? 'device.serial' : 'device.model')
  return many && device ? `${what} · ${device.name || device.serial}` : what
}
async function openMissing(item: Missing) {
  if (item.kind === 'phone') await editCustomer()
  else await editDevice(item.deviceId)
}
async function editCustomer() {
  const id = order.value?.customer?.id
  if (!id) return
  try {
    dialog.value = { kind: 'editCustomer', detail: await loadCustomer(id) }
  } catch (error) {
    showToast(t(errorMessageKey(error)))
  }
}
async function editDevice(id: string) {
  try {
    dialog.value = { kind: 'editDevice', detail: await loadDevice(id) }
  } catch (error) {
    showToast(t(errorMessageKey(error)))
  }
}
/** Saved: the order's copy of the customer follows (name, phone, e-mail, CPF/CNPJ), so WhatsApp works at once. */
async function onCustomerEdited(id: string) {
  dialog.value = null
  const o = order.value
  if (!o) return
  try {
    const fresh = (await loadCustomer(id)).customer
    customers.value = customers.value.map((c) => (c.id === id ? { ...c, name: fresh.name, phone: fresh.phone ?? undefined } : c))
    await run(() => writes.updateOrderFields(o.id, { customer: customerSummary(fresh) }), t('web.saved'))
  } catch (error) {
    showToast(t(errorMessageKey(error)))
  }
}
/** Saved: the order's copy of that device follows (name and plate/serial). */
async function onDeviceEdited(id: string) {
  dialog.value = null
  const o = order.value
  if (!o) return
  try {
    const fresh = (await loadDevice(id)).device
    forgetLists()
    devices.value = devices.value.map((d) => (d.id === id ? { ...d, name: fresh.name ?? d.name, serial: fresh.serial } : d))
    await saveDevices(o.devices.map((item) => (item.id === id ? { ...item, name: fresh.name || fresh.serial || item.name, ...(fresh.serial ? { serial: fresh.serial } : {}) } : item)))
  } catch (error) {
    showToast(t(errorMessageKey(error)))
  }
}
const pickItem = (picked: ComboboxItem, query = '') => {
  if (picked.id === FREE_ITEM && query.trim()) return void addFreeItem(query.trim())
  if (picked.id === REGISTER_ITEM && query.trim()) return void registerAndAdd(query.trim())
  const item = catalog.value.find((entry) => `${entry.kind}:${entry.id}` === picked.id)
  if (item) void addCatalogItem(item)
}
const PLATE = 'plate:'
const NONE = '__none'
const recents = shallowRef<Named[]>([])
const customerRow = (c: Customer | Named) => ({ id: c.id, label: c.name, sub: formatPhone((c as Customer).phone) || undefined })
const customerGroups = (query: string): ComboboxGroup[] => [
  { title: t('web.newOrder.byPlate'), items: plateHits(devices.value, query).map((d) => ({ id: `${PLATE}${d.id}`, label: `${d.serial} · ${d.name}`, sub: plateOwnerName(d.id) })) },
  { title: t('pickerRecent'), items: query.trim() ? [] : recents.value.map((r) => customers.value.find((c) => c.id === r.id) ?? r).map(customerRow) },
  {
    title: query.trim() || !recents.value.length ? undefined : t('web.newOrder.customers'),
    items: search(query.trim() ? customers.value : customers.value.filter((c) => !recents.value.some((r) => r.id === c.id)), query, (c) => c.phone ?? '').map(customerRow),
  },
]
/** Devices the order's customer brought before: the section "do cliente" (device.list.pick). */
const ownDevices = shallowRef<Device[]>([])
const deviceGroups = (query: string): ComboboxGroup[] => {
  const current = dialog.value?.kind === 'device' ? dialog.value.current : undefined
  const row = (d: Device) => ({ id: d.id, label: d.name, sub: d.serial ?? undefined })
  if (current) {
    // Changing one device: the whole list, the current one always there with its ✓ (order.device.change).
    const list = search(devices.value, query, (d) => d.serial ?? '')
    const mine = devices.value.find((d) => d.id === current.id)
    const shown = mine && !query.trim() && !list.some((d) => d.id === mine.id) ? [mine, ...list] : list
    return [{ items: !query.trim() ? [{ id: NONE, label: t('pickerNoDevice', { device: deviceLabel().toLocaleLowerCase() }) }] : [] }, { items: shown.map(row) }]
  }
  const own = search(ownDevices.value, query, (d) => d.serial ?? '', 6)
  // Another customer's device never shows under this customer's name: it goes to "Outros".
  const others = search(devices.value.filter((d) => !own.some((o) => o.id === d.id)), query, (d) => d.serial ?? '')
  return [
    // "Nenhum …" only when changing a device and nothing is typed (device.list.pick-none).
    { items: current && !query.trim() ? [{ id: NONE, label: t('pickerNoDevice', { device: deviceLabel().toLocaleLowerCase() }) }] : [] },
    { title: own.length && order.value?.customer?.name ? t('web.order.devicesOf', { name: order.value.customer.name }) : undefined, items: own.map(row) },
    { title: own.length && others.length ? t('web.newOrder.otherDevices', { device: deviceLabel().toLocaleLowerCase() }) : undefined, items: others.map(row) },
    // device.list.pick-create: a plate becomes the serial, anything else the model; it comes back chosen.
    { items: query.trim() && can('manageDevices') && !current ? [{ id: NEW_DEVICE, label: t('web.newOrder.register', { name: query.trim() }) }] : [] },
  ]
}
const NEW_DEVICE = '__newDevice'
async function pickDeviceItem(item: ComboboxItem, query: string) {
  const current = dialog.value?.kind === 'device' ? dialog.value.current : undefined
  if (current) return changeDevice(current, item)
  if (item.id !== NEW_DEVICE) return addDevice(devices.value.find((d) => d.id === item.id) ?? (ownDevices.value.find((d) => d.id === item.id) as Device))
  // order.quick.device: model and plate/serial asked in a small sheet.
  dialog.value = { kind: 'quick', quick: 'device', text: query }
}

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
  if (canDiscountNow.value) list.push({ id: 'discount', label: t('orderAddDiscount') })
  // Not copied from the app: there an empty request can never be written on a saved order.
  if (a.canEditMainFields && reqField.value && !requestText.value) list.push({ id: 'request', label: t('web.order.requestAdd') })
  if (a.canEditMainFields && !o.dueDate) list.push({ id: 'due', label: t('orderAddDueDate') })
  if (a.canEditMainFields && !o.scheduledDate && useScheduling.value) list.push({ id: 'schedule', label: t('orderAddSchedule') })
  if (a.canAssign && !o.assignedTo) list.push({ id: 'assignee', label: t('orderAddResponsible') })
  if (a.canEditMainFields) list.push({ id: 'device', label: t('orderAddAnotherDevice', { device: deviceLabel().toLocaleLowerCase() }) })
  list.push({ id: 'share', label: t('shareTitle') })
  // order.quick.complete: the customer's and the devices' data in a form over the order, without leaving it;
  // "Abrir …" still goes to the record's own screen (order.customer.open / order.device.open).
  if (o.customer?.id && can('manageCustomers')) list.push({ id: 'editCustomer', label: t('web.quick.customerData') })
  if (o.customer?.id && canOpen('/customers')) list.push({ id: 'openCustomer', label: t('web.order.openCustomer') })
  for (const device of o.devices) if (device.id && can('manageDevices')) list.push({ id: `editDevice:${device.id}`, label: t('web.quick.deviceData', { name: device.name || device.serial || deviceLabel() }) })
  if (canOpen('/devices')) for (const device of o.devices) if (device.id) list.push({ id: `openDevice:${device.id}`, label: t('web.order.openDevice', { name: device.name ?? deviceLabel() }) })
  // order.pdf.view: the same rule as the app (canShareOrderPdf), values only for who sees them.
  if (canPrint.value) list.push({ id: 'pdf', label: t('web.order.pdf') })
  if (canPrint.value) list.push({ id: 'print', label: t('web.order.print') })
  // The server decides the rest (already has a nota, no service with value, not set up) and the dialog says why.
  if (nfseOn.value && nfseLoaded.value && can('chargeOrder') && canHaveNfse(o) && !(nfseCurrent.value && nfseIsActive(nfseCurrent.value))) list.push({ id: 'invoice', label: t('nfseIssueAction') })
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
  else if (id === 'request') dialog.value = { kind: 'request' }
  else if (id === 'due') dialog.value = { kind: 'due' }
  else if (id === 'schedule') dialog.value = { kind: 'schedule' }
  else if (id === 'assignee') void openPicker('assignee')
  else if (id === 'device') void openPicker('device')
  else if (id === 'print') print()
  else if (id === 'pdf') pdfOpen.value = true
  else if (id === 'invoice') issuing.value = true
  else if (id === 'share') dialog.value = { kind: 'share' }
  else if (id === 'openCustomer' && order.value?.customer?.id) void goTo('/customers', { customer: order.value.customer.id })
  else if (id === 'editCustomer') void editCustomer()
  else if (id.startsWith('editDevice:')) void editDevice(id.slice('editDevice:'.length))
  else if (id.startsWith('openDevice:')) void goTo('/devices', { device: id.slice('openDevice:'.length) })
  else if (id === 'cancel') dialog.value = { kind: 'cancel' }
  else if (id === 'delete') dialog.value = { kind: 'delete' }
}

/** After the menu left the page (its history entry is taken out on unmount), then another screen. */
async function goTo(path: string, query: Record<string, string>) {
  await nextTick()
  await router.push({ path, query })
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

const canReceiveNow = computed(() => !!access.value?.canReceive && (money$.value?.remaining ?? 0) > 0)
/** The menu's rule for "Adicionar desconto" (order.menu.view). */
const canDiscountNow = computed(() => {
  const o = order.value
  return !!o && !!access.value?.canDiscount && o.status !== 'quote' && o.status !== 'canceled' && (money$.value?.remaining ?? 0) > 0
})
// Keys of the open order (WEB_APP_DESIGN, Teclado). Only outside fields.
const removers = [
  registerShortcut({ keys: 'a', label: 'web.shortcuts.addItem', run: () => canAddItems.value && void openPicker('addItem') }),
  registerShortcut({ keys: 's', label: 'web.shortcuts.status', run: () => statusChoices.value.length > 1 && (dialog.value = { kind: 'status' }) }),
  registerShortcut({ keys: 'c', label: 'web.shortcuts.customer', run: () => access.value?.canEditMainFields && void openPicker('customer') }),
  registerShortcut({ keys: 'd', label: 'web.shortcuts.schedule', run: () => access.value?.canEditMainFields && (dialog.value = { kind: 'schedule' }) }),
  registerShortcut({ keys: 'm', label: 'web.shortcuts.share', run: () => order.value && (dialog.value = { kind: 'share' }) }),
  registerShortcut({ keys: 'r', label: 'web.shortcuts.receive', run: () => canReceiveNow.value && (dialog.value = { kind: 'receive' }) }),
  registerShortcut({ keys: 'p', label: 'web.shortcuts.nextStep', run: () => step.value && !busy.value && void runStep() }),
  registerShortcut({ keys: 'w', label: 'web.shortcuts.whatsapp', run: () => order.value && (dialog.value = { kind: 'share', send: true }) }),
  registerShortcut({ keys: '-', label: 'web.shortcuts.discount', run: () => canDiscountNow.value && (dialog.value = { kind: 'discount' }) }),
  // The same actions in ⌘K, by name ("desconto", "remarcar"…), only while they apply.
  registerCommand({ id: 'order-next', label: 'web.shortcuts.nextStep', keys: 'p', when: () => !!step.value, run: () => void runStep() }),
  registerCommand({ id: 'order-status', label: 'web.shortcuts.status', keys: 's', when: () => statusChoices.value.length > 1, run: () => (dialog.value = { kind: 'status' }) }),
  registerCommand({ id: 'order-receive', label: 'web.shortcuts.receive', keys: 'r', when: () => canReceiveNow.value, run: () => (dialog.value = { kind: 'receive' }) }),
  registerCommand({ id: 'order-discount', label: 'web.palette.discount', keys: '-', when: () => canDiscountNow.value, run: () => (dialog.value = { kind: 'discount' }) }),
  registerCommand({ id: 'order-schedule', label: 'web.palette.reschedule', keys: 'd', when: () => !!access.value?.canEditMainFields, run: () => (dialog.value = { kind: 'schedule' }) }),
  registerCommand({ id: 'order-share', label: 'web.shortcuts.share', keys: 'm', when: () => !!order.value, run: () => (dialog.value = { kind: 'share' }) }),
  registerCommand({ id: 'order-whatsapp', label: 'web.shortcuts.whatsapp', keys: 'w', when: () => !!order.value, run: () => (dialog.value = { kind: 'share', send: true }) }),
  registerCommand({ id: 'order-add-item', label: 'web.shortcuts.addItem', keys: 'a', when: () => canAddItems.value, run: () => void openPicker('addItem') }),
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
          <span v-for="(device, index) in order.devices" :key="device.id ?? index"
            >{{ index ? ' · ' : '' }}<button
              v-if="access.canEditMainFields && device.id"
              type="button"
              class="od-device-btn"
              :aria-label="t('web.order.changeDevice', { name: [device.name, device.serial].filter(Boolean).join(' · ') })"
              @click="openDevicePicker(device)"
            >{{ device.name }}<template v-if="device.serial"> · <span class="num">{{ device.serial }}</span></template></button
            ><template v-else>{{ device.name }}<template v-if="device.serial"> · <span class="num">{{ device.serial }}</span></template></template></span
          >
        </p>
        <button v-else-if="access.canEditMainFields" type="button" class="link od-device-add" @click="openPicker('device')">
          {{ t('orderPickDevice', { device: deviceLabel().toLocaleLowerCase() }) }}
        </button>
        <p v-if="readingRows.length" class="od-missing" data-testid="order-readings">
          <template v-for="row in readingRows" :key="row.id">
            <button
              v-if="access.canEditMainFields"
              type="button"
              class="link"
              :class="{ 'od-reading': row.text }"
              :data-testid="row.text ? `reading-${row.id}` : `reading-add-${row.id}`"
              @click="dialog = { kind: 'reading', deviceId: row.id, name: row.name }"
            >{{ row.text ? t('deviceReadingLine', { label: readingTitle, value: row.text }) : `+ ${readingTitle}` }}<template v-if="order.devices.length > 1"> · {{ row.name }}</template></button>
            <span v-else class="od-reading" :data-testid="`reading-${row.id}`">{{ t('deviceReadingLine', { label: readingTitle, value: row.text }) }}<template v-if="order.devices.length > 1"> · {{ row.name }}</template></span>
          </template>
        </p>
        <p v-if="missing.length" class="od-missing" data-testid="order-missing">
          <button v-for="item in missing" :key="item.kind + ('deviceId' in item ? item.deviceId : '')" type="button" class="link" :data-testid="`missing-${item.kind}`" @click="openMissing(item)">+ {{ missingText(item) }}</button>
        </p>
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
        <p v-if="notify" class="od-notify" role="status" data-testid="notify-note" @mouseenter="holdNotify(true)" @mouseleave="holdNotify(false)" @focusin="holdNotify(true)" @focusout="holdNotify(false)">
          <span>{{ notifyText }}</span>
          <button type="button" class="btn btn--small btn--primary" data-testid="notify-now" @click="notifyNow">{{ t('orderNotifyAction') }}</button>
        </p>
        <section v-if="offer" class="od-offer" aria-labelledby="od-offer-title" data-testid="maintenance-offer">
          <h3 id="od-offer-title" class="od-offer-title">{{ t('nextMaintenanceQuestion') }}</h3>
          <p class="sub">{{ offer.devices.map((device) => device.name).join(', ') }}</p>
          <div class="od-offer-opts" role="group" :aria-label="t('nextMaintenanceQuestion')">
            <button v-for="choice in maintenanceChoices" :key="choice.id" type="button" class="btn" @click="answerMaintenance(choice.id)">
              {{ choice.label }}<small v-if="choice.sub" class="sub"> · {{ choice.sub }}</small>
            </button>
            <button type="button" class="btn btn--ghost" @click="answerMaintenance(null)">{{ t('notNow') }}</button>
          </div>
        </section>
      </header>

      <div class="od-body">
        <section v-if="reqField && requestText" class="od-sec" aria-labelledby="od-request-title" data-testid="order-request">
          <h3 id="od-request-title">
            {{ t('orderCustomerRequestTitle') }}
            <button v-if="access.canEditMainFields" type="button" class="link" :aria-label="t('web.order.requestChange')" @click="dialog = { kind: 'request' }">{{ t('web.order.change') }}</button>
          </h3>
          <p class="od-request">{{ requestText }}</p>
        </section>
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
          <PaymentHistory
            :order="order"
            :can-receive="access.canReceive && !!moneyRowTone"
            :can-discount="access.canDiscount && !!moneyRowTone"
            :can-attach="access.canReceive && !!moneyRowTone && can('attachPhotos')"
            :busy="busy"
            @remove="removePayment"
            @undo-all="undoAllPayments"
            @attach="attachProof"
            @detach="detachProof"
            @open-receipt="(id: string) => (receiptOpen = id)"
          />
          <OrderCharge v-if="showCharge" :key="order.id" :order="order" :remaining="money$.remaining" :can-charge="can('chargeOrder')" @open="(open) => (linkOpen = open)" />
        </section>

        <OrderNfse v-if="nfseOn && can('chargeOrder')" :key="`nfse-${order.id}`" :order="order" :ready="nfseReady" :remaining="money$?.remaining ?? 0" @issue="issuing = true" @current="(value: NfseInvoice | null) => (nfseCurrent = value)" @loaded="(value: boolean) => (nfseLoaded = value)" />
        <OrderPhotos :order="order" />
        <OrderDocuments :order="order" :can-edit="true" />
        <OrderComments :order-id="order.id" />
        <section v-if="order.rating" class="od-sec" aria-labelledby="od-rating-title" data-testid="order-rating">
          <h3 id="od-rating-title">{{ t('rating') }}</h3>
          <p class="od-rating">
            <span class="od-stars" aria-hidden="true"><span v-for="i in 5" :key="i" :class="{ on: i <= order.rating.score }">★</span></span>
            <span class="sub num">{{ t('ratingScoreOf', { score: String(order.rating.score) }) }}</span>
          </p>
          <p v-if="order.rating.comment">{{ order.rating.comment }}</p>
        </section>
        <OrderForms ref="formsRef" :order="order" @forms="(list: { id: string; status: string }[]) => (orderForms = list)" />
        <OrderContract :key="order.id" :order="order" :can-edit="!!access?.canEditMainFields" />

        <OrderCustomFields :order="order" :can-edit="!!access.canEditMainFields" />

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
                <button v-if="access.canAssign" type="button" class="link" @click="openPicker('assignee')">{{ assigneeName || t('web.order.nobody') }}</button>
                <span v-else>{{ assigneeName }}</span>
              </dd>
            </template>
            <template v-if="order.address || (access.canEditMainFields && fieldService)">
              <dt>{{ t('orderAddressLabel') }}</dt>
              <dd class="od-address" data-testid="order-address">
                <span v-if="order.address">{{ order.address }}</span>
                <a v-if="order.address" class="link" :href="`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(order.address)}`" target="_blank" rel="noopener">{{ t('openInMaps') }}</a>
                <template v-if="access.canEditMainFields">
                  <button type="button" class="link" @click="dialog = { kind: 'address' }">{{ order.address ? t('orderAddressChange') : t('web.order.addAddress') }}</button>
                  <button v-if="order.address" type="button" class="link link--danger" :disabled="busy" @click="saveAddress(null)">{{ t('orderAddressRemove') }}</button>
                </template>
              </dd>
            </template>
          </dl>
        </section>
      </div>
    </div>
    <OrderAssistant v-if="order && access?.canEditMainFields" :order="order" :pending-checklists="orderForms.filter((form) => form.status !== 'completed').length"
      @hide="(ids: string[]) => (hiddenLines = [...hiddenLines, ...ids])"
      @unhide="(ids: string[]) => (hiddenLines = hiddenLines.filter((id) => !ids.includes(id)))" @added="(ids) => (aiLines = [...aiLines, ...ids])" @undone="(ids) => (aiLines = aiLines.filter((id) => !ids.includes(id)))" />
  </section>

  <template v-if="order && access && dialog">
    <ChoiceDialog v-if="dialog.kind === 'menu'" :anchor="menuButton" :title="orderTitle(order)" :choices="menuChoices" @pick="onMenu" @close="dialog = null" />
    <ChoiceDialog v-else-if="dialog.kind === 'status'" :title="t('pickerStatusTitle')" :sub="orderTitle(order)" :choices="statusChoices" :suggested="step?.kind === 'status' ? step.to : null" @pick="(id) => (id === order!.status ? (dialog = null) : setStatus(id as OrderStatus))" @close="dialog = null" />
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
    <ConfirmDialog
      v-else-if="dialog.kind === 'catalogPrice'"
      :title="t('orderItemCatalogPriceTitle')"
      :body="t('orderItemCatalogPriceMessage', { entity: catalogEntity(dialog.offer.kind), name: dialog.offer.name, from: dialog.offer.from === null ? t('catalogNoPrice') : money(dialog.offer.from), to: money(dialog.offer.to) })"
      :confirm="t('orderItemCatalogPriceAlways')"
      :keep="t('orderItemCatalogPriceOnlyHere')"
      @confirm="useCatalogPriceAlways((dialog as { offer: CatalogPriceOffer }).offer)"
      @close="dialog = null"
    />
    <HoldDialog v-else-if="dialog.kind === 'hold'" @save="hold" @close="dialog = null" />
    <DateDialog v-else-if="dialog.kind === 'due'" :title="t('orderAddDueDate')" :label="t('orderDueLabel')" :value="order.dueDate" :clear-label="t('web.order.clearDue')" @save="(value) => saveDate('dueDate', value)" @close="dialog = null" />
    <DateDialog v-else-if="dialog.kind === 'schedule'" :title="t('orderAddSchedule')" :label="t('orderScheduleLabel')" :value="order.scheduledDate" :clear-label="t('orderScheduleRemove')" @save="(value) => saveDate('scheduledDate', value)" @close="dialog = null" />
    <MoneyDialog v-else-if="dialog.kind === 'receive' && money$" kind="receive" :method="suggestedMethod(order, session.companyId)" :remaining="money$.remaining" :total="money$.total" :busy="busy" :can-attach="can('attachPhotos')" :created-at="order.createdAt" :link-note="linkOpen === true ? (order.customer?.name ? t('receiveChargeAdjusts', { customer: order.customer.name }) : t('receiveChargeAdjustsNoName')) : ''" @save="receive" @close="dialog = null" />
    <ShareDialog v-else-if="dialog.kind === 'share'" :order="order" :send="!!dialog.send" @pick-customer="openPicker('customer')" @linked="watcher?.reread()" @close="dialog = null" />
    <MoneyDialog v-else-if="dialog.kind === 'discount' && money$" kind="discount" :remaining="money$.remaining" :total="money$.total" :busy="busy" @save="discount" @close="dialog = null" />
    <ItemDialog v-else-if="dialog.kind === 'item'" :line="dialog.line" :devices="order.devices" :shows-money="showsMoney" :can-edit-price="can('editPrices')" :busy="busy" @save="(patch) => saveLine((dialog as { line: OrderLine }).line, patch)" @remove="removeLine((dialog as { line: OrderLine }).line)" @close="dialog = null" />
    <TextDialog
      v-else-if="dialog.kind === 'address'"
      :title="t('orderAddressLabel')"
      :label="t('orderAddressLabel')"
      :value="order.address ?? ''"
      @save="saveAddress"
      @close="dialog = null"
    />
    <ReadingDialog
      v-else-if="dialog.kind === 'reading' && reading"
      :title="readingTitle"
      :unit="reading.suffix"
      :sub="order.devices.length > 1 ? dialog.name : undefined"
      :value="order.deviceReadings?.[dialog.deviceId] ?? null"
      @save="(value) => saveReading((dialog as { deviceId: string }).deviceId, value)"
      @close="dialog = null"
    />
    <TextDialog
      v-else-if="dialog.kind === 'request'"
      :title="t('orderCustomerRequestTitle')"
      :label="t('orderCustomerRequestTitle')"
      :value="requestText"
      :placeholder="t('orderCustomerRequestPlaceholder', { segment: session.company?.segment ?? 'other' })"
      multiline
      @save="saveRequest"
      @close="dialog = null"
    />
    <ComboDialog v-else-if="dialog.kind === 'addItem'" id="od-add-item" :title="t('pickerItemTitle')" :label="t('orderItemSearchPlaceholder')" :groups="itemGroups" @pick="pickItem" @close="dialog = null" />
    <DevicePickerDialog v-else-if="dialog.kind === 'devicesFor'" :devices="order.devices" :sub="dialog.name" @pick="addOnPicked" @close="dialog = null" />
    <ComboDialog v-else-if="dialog.kind === 'customer'" id="od-customer" :title="t('pickCustomerTitle')" :label="t('customer')" :groups="customerGroups" :selected-id="currentCustomerId(order.customer, customers, session.company?.country) ?? undefined" @pick="pickCustomerItem" @close="dialog = null" />
    <ComboDialog
      v-else-if="dialog.kind === 'device'"
      id="od-device"
      :title="t('orderPickDevice', { device: deviceLabel().toLocaleLowerCase() })"
      :label="deviceLabel()"
      :groups="deviceGroups"
      :selected-id="dialog.current?.id"
      :selected-ids="dialog.current ? undefined : order.devices.map((d) => d.id).filter((id): id is string => !!id)"
      @pick="pickDeviceItem"
      @close="dialog = null"
    />
    <Layer v-else-if="dialog.kind === 'quick'" kind="sheet" :label="dialog.quick === 'item' ? t('web.quick.newItem') : t('web.quick.newDevice', { device: deviceLabel() })" @close="dialog = null">
      <div class="layer-body">
        <QuickCreate :id="`od-quick-${dialog.quick}`" :kind="dialog.quick" :text="dialog.text" @saved="onQuickSaved" @more="onQuickMore" @cancel="dialog = null" />
      </div>
    </Layer>
    <DeviceForm v-else-if="dialog.kind === 'newDevice'" :draft="dialog.draft" :devices="[]" @saved="onNewDeviceSaved" @close="dialog = null" />
    <CustomerForm v-else-if="dialog.kind === 'editCustomer'" :customer="dialog.detail.customer" :version="dialog.detail.version" :directory="[]" @saved="onCustomerEdited" @changed="editCustomer" @close="dialog = null" />
    <DeviceForm v-else-if="dialog.kind === 'editDevice'" :device="dialog.detail.device" :version="dialog.detail.version" :devices="[]" @saved="onDeviceEdited" @changed="editDevice(dialog.detail.device.id)" @close="dialog = null" />
  </template>
  <PdfDialog
    v-if="pdfOpen && order"
    :ids="[order.id]"
    :numbers="[order.number]"
    :whatsapp="!!(order.customer?.id || order.customer?.name)"
    @whatsapp="sharePdfLink"
    @close="pdfOpen = false"
  />
  <IssueInvoiceDialog v-if="issuing && order" :order-ids="[order.id]" :customer-id="order.customer?.id ?? null" @done="issuing = false" @close="issuing = false" />
  <OrderPrint v-if="printing && order" :order="order" />
  <ReceiptsDialog v-if="receiptOpen && order?.customer?.id" :customer-id="order.customer.id" :customer-name="order.customer.name ?? ''" :focus-id="receiptOpen" @changed="watcher?.refresh()" @close="receiptOpen = null" />
</template>
