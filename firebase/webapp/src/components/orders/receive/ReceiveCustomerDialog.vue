<script setup lang="ts">
// "Receber de {nome}" (pay.customer.*): several orders of one customer in one
// receipt, or one payment link for them. The amount is split oldest first and
// the split and the total are on screen before anything is saved; then a
// confirmation repeats them. Before saving, the balances are read again: if one
// changed (a link was paid, someone received), nothing is saved and the screen says so.
import { computed, nextTick, onMounted, ref, shallowRef, watch } from 'vue'
import { useRouter } from 'vue-router'
import Layer from '@/components/Layer.vue'
import MoneyInput from '@/components/MoneyInput.vue'
import ConfirmDialog from '@/components/orders/ConfirmDialog.vue'
import { t } from '@/i18n'
import { ApiError, errorMessageKey } from '@/lib/api'
import { formatDate, formatDayMonth, formatMoney } from '@/lib/format'
import { firestoreLite } from '@/lib/firebase'
import { country, money, orderShort } from '@/lib/orders/text'
import { loadCustomer } from '@/lib/customers/data'
import { whatsappNumber } from '@/lib/phone'
import { cancelCustomerCharge, customerCharges, listReceipts, openOrders, paymentSettings, registerReceipt } from '@/lib/receive/data'
import { allocate, allocationSummary, chargeOf, localDay, openChargeOf, owedOf, paidAtFor, toCents, whatsappLink, type Charge, type OpenOrder } from '@/lib/receive/model'
import { can, session } from '@/lib/session'
import { showToast } from '@/lib/toast'
import { ensurePlanFeature } from '@/lib/plan-feature-gate'
import { announce } from '@/lib/ui'
import ChargeDialog from './ChargeDialog.vue'
import StatementDialog from './StatementDialog.vue'
import '@/styles/receive.css'

// startCharge: opened by the Financeiro's "Próxima cobrança" (pay.customer.start-charge): the charge
// sheet opens by itself, only once it is known that the customer has no open link.
// inProgress: orders not done yet (the customer screen's "Em andamento"): they say so under the number,
// and with it given, checked is taken as it is, even empty (they start unchecked, for the statement).
const props = defineProps<{ customerId: string; customerName: string; checked?: string[]; inProgress?: string[]; startCharge?: boolean }>()
const emit = defineEmits<{ close: []; done: [] }>()
const router = useRouter()

const state = ref<'loading' | 'ready' | 'failed'>('loading')
const orders = shallowRef<OpenOrder[]>([])
const picked = ref<string[]>([])
const amount = ref<number | null>(null)
const method = ref('')
const today = localDay(new Date())
const day = ref(today)
const saving = ref(false)
const dialog = ref<null | 'confirm' | 'charge' | 'cancelCharge' | 'replace' | 'statement'>(null)
/** Open links of one order each (pay.customer.replace-single): the row says so and a new charge asks first. */
const singleLinks = shallowRef(new Map<string, Charge>())
let startedCharge = false
const charge = shallowRef<Charge | null>(null)
const chargesReady = ref(false)
/** The payment links could not be read: no charge is offered until they are (Tentar de novo). */
const chargesFailed = ref(false)
// One id per receipt the person asks for: repeating the same request after a lost
// answer sends it again (the server books it once). A new one when the balances
// changed or the person changed what goes in (R2 of the #518 review).
let receiptId = crypto.randomUUID()
const renewReceipt = () => (receiptId = crypto.randomUUID())
const phone = ref('')
const charger = can('chargeOrder')

const financial = can('viewFinancialReports')
// "Outras OS de {nome}": only a consultant without financial access sees them apart (pay.customer.others).
const own = computed(() => (financial ? orders.value : orders.value.filter((o) => o.own)))
const others = computed(() => (financial ? [] : orders.value.filter((o) => !o.own)))
const chosen = computed(() => orders.value.filter((o) => picked.value.includes(o.id)))
const owed = computed(() => owedOf(chosen.value))
const split = computed(() => allocate(amount.value ?? 0, chosen.value))
const summary = computed(() => allocationSummary(split.value, owed.value))
const tooMuch = computed(() => toCents(amount.value ?? 0) > toCents(owed.value))
// One day of slack before the newest order, like the server (24 h by the company's zone). Today is always fine.
const minDay = computed(() => chosen.value.map((o) => (o.createdAt ? localDay(new Date(Date.parse(o.createdAt) - 86_400_000)) : '')).sort().at(-1) ?? '')
const dayValid = computed(() => day.value === today || (!!day.value && day.value < today && (!minDay.value || day.value >= minDay.value)))
const problem = computed(() => {
  if (!chosen.value.length) return t('receiveCustomerNoneChecked')
  if (toCents(amount.value ?? 0) <= 0) return t('receiveCustomerZero')
  if (tooMuch.value) return t('receiveCustomerTooMuchChosen', { total: money(owed.value) })
  if (!dayValid.value) return t('web.receive.dayInvalid')
  return ''
})
const wa = computed(() => whatsappNumber(phone.value, session.company?.country))
/** "Mandar de novo": the Asaas link, the same one the order sends (defect 7), to the record's phone. */
const resend = computed(() => {
  const open = charge.value
  if (!open?.invoiceUrl || !wa.value) return ''
  const text = `${t('web.share.msgHello', { name: props.customerName })} ${t('web.charge.msg', { amount: formatMoney(open.value, 'BR'), orders: ordersOf(open), date: formatDate(`${open.dueDate}T12:00:00`, 'BR') })}\n${open.invoiceUrl}`
  return whatsappLink(wa.value, text)
})
const ordersOf = (open: Charge) => `${orderShort()} ${(open.orderIds ?? []).map((id) => orders.value.find((o) => o.id === id)?.number ?? '').filter(Boolean).join(', ')}`.trim()
const canCharge = computed(() => chargesReady.value && charger && !charge.value && chosen.value.length > 0 && chosen.value.every((o) => o.own || financial))
const numbers = (list: readonly { number: number | null }[]) => list.map((o) => o.number ?? '').join(', ')
const rowText = (order: OpenOrder) => {
  const part = split.value.find((a) => a.orderId === order.id)
  if (!picked.value.includes(order.id)) return ''
  if (!part) return t('receiveCustomerRowLater')
  return part.settles ? t('receiveCustomerRowSettles') : t('receiveCustomerRowPartial', { amount: money(part.amount), left: money(order.open - part.amount) })
}

async function load() {
  state.value = 'loading'
  try {
    orders.value = await openOrders(props.customerId)
    const start = props.inProgress ? (props.checked ?? []) : props.checked?.length ? props.checked : own.value.map((o) => o.id)
    picked.value = orders.value.filter((o) => start.includes(o.id) && (financial || o.own)).map((o) => o.id)
    amount.value = owed.value
    state.value = 'ready'
  } catch (error) {
    console.warn('receive: open orders not read', error)
    state.value = 'failed'
  }
}

/** Who receives also sees an open link, read only (like the app after #513); who charges acts on it. */
async function loadCharges() {
  const settings = await paymentSettings()
  if (!settings.ready) return
  try {
    const [list, detail] = await Promise.all([customerCharges(props.customerId), loadCustomer(props.customerId).catch(() => null)])
    charge.value = openChargeOf(list)
    phone.value = detail?.customer.phone ?? ''
    if (charger) singleLinks.value = await orderLinks(orders.value.length ? orders.value.map((o) => o.id) : (await openOrders(props.customerId)).map((o) => o.id))
  } catch (error) {
    // Without knowing, never offer a link that could cancel one about to be paid (send_charge_flow):
    // the drawer says so, with Tentar de novo (B2 of #543).
    console.warn('receive: customer charges not read', error)
    chargesFailed.value = true
    return
  }
  chargesFailed.value = false
  chargesReady.value = true
}

/** The open link of each order (the newest open one), read once. A failed read throws: loadCharges says so. */
async function orderLinks(ids: readonly string[]): Promise<Map<string, Charge>> {
  const found = new Map<string, Charge>()
  const [db, { collection, getDocs }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  await Promise.all(
    ids.map(async (id) => {
      const snap = await getDocs(collection(db, 'companies', session.companyId as string, 'orders', id, 'charges'))
      const open = openChargeOf(snap.docs.map((d) => chargeOf(d.id, d.data())))
      if (open) found.set(id, open)
    }),
  )
  return found
}

onMounted(() => {
  void load()
  void loadCharges()
})

// Próxima cobrança: once the orders and the customer's links are known and nothing is open, the sheet opens (once).
watch([chargesReady, state], () => {
  if (!props.startCharge || startedCharge || !chargesReady.value || state.value !== 'ready') return
  startedCharge = true
  if (!charge.value && canCharge.value) newCharge()
})

/** Mandar cobrança over orders that have their own link asks first: the new one cancels those in Asaas. */
function newCharge() {
  // Charges are Starter (#724).
  if (!ensurePlanFeature('charges')) return
  dialog.value = chosen.value.some((o) => singleLinks.value.has(o.id)) ? 'replace' : 'charge'
}
/** Closed first: the confirmation takes its history entry out, then the charge opens. */
async function replaceConfirmed() {
  dialog.value = null
  await nextTick()
  dialog.value = 'charge'
}
/** "Esperando o pagamento" or "Venceu em dd/mm" of the order's own link. */
function linkText(id: string): string {
  const link = singleLinks.value.get(id)
  if (!link) return ''
  return link.status === 'overdue' ? t('chargeExpiredOn', { date: formatDayMonth(`${link.dueDate}T12:00:00`, country()) }) : t('chargeWaitingPayment')
}

// Marking or unmarking starts the amount again from what the marked orders owe (pay.customer.pick-orders).
watch(picked, () => (amount.value = owed.value), { deep: true })
watch([picked, amount, method, day], renewReceipt, { deep: true })

function toggle(id: string) {
  picked.value = picked.value.includes(id) ? picked.value.filter((x) => x !== id) : [...picked.value, id]
}

function ask() {
  if (problem.value || saving.value) return
  dialog.value = 'confirm'
}

async function save() {
  dialog.value = null
  if (problem.value || saving.value) return
  saving.value = true
  try {
    // Balances read again on the server: something changed, nothing is saved (pay.customer.balance-check).
    const fresh = await openOrders(props.customerId)
    const changed = chosen.value.some((o) => toCents(fresh.find((f) => f.id === o.id)?.open ?? 0) !== toCents(o.open))
    if (changed) {
      renewReceipt()
      orders.value = fresh
      picked.value = picked.value.filter((id) => fresh.some((f) => f.id === id))
      showToast(t('receiveCustomerBalanceChanged'))
      announce(t('receiveCustomerBalanceChanged'))
      return
    }
    const total = amount.value as number
    await registerReceipt(props.customerId, {
      receiptId,
      paidAt: paidAtFor(day.value, new Date()),
      allocations: split.value.map((a) => ({ orderId: a.orderId, amount: a.amount })),
      ...(method.value ? { paymentMethod: method.value } : {}),
    })
    done(total)
  } catch (error) {
    // The same receipt id came back: the first try was saved, the answer was lost.
    if (error instanceof ApiError && error.code === 'RECEIPT_EXISTS') return savedBefore()
    if (error instanceof ApiError && error.code === 'VALUE_EXCEEDS_BALANCE') {
      renewReceipt()
      showToast(t('receiveCustomerBalanceChanged'))
      await load()
      return
    }
    showToast(t(errorMessageKey(error)))
  } finally {
    saving.value = false
  }
}

/** RECEIPT_EXISTS: say what the server really booked under this id, never what is typed now. */
async function savedBefore() {
  const id = receiptId
  try {
    const saved = (await listReceipts(props.customerId)).find((receipt) => receipt.id === id)
    if (saved) return done(saved.amount)
  } catch (error) {
    console.warn('receive: receipts not read', error)
  }
  renewReceipt()
  showToast(t('receiveCustomerBalanceChanged'))
  await load()
}

function done(total: number) {
  const text = t('receiveCustomerDone', { amount: money(total), name: props.customerName })
  showToast(text)
  announce(text)
  emit('done')
}

async function cancelCharge() {
  const open = charge.value
  dialog.value = null
  if (!open) return
  try {
    await cancelCustomerCharge(props.customerId, open.id)
    charge.value = null
    showToast(t('receiveCustomerChargeCanceled'))
  } catch (error) {
    showToast(t(errorMessageKey(error)))
  }
}

async function copyCharge() {
  try {
    await navigator.clipboard.writeText(charge.value?.invoiceUrl ?? '')
    showToast(t('chargeLinkCopied'))
  } catch {
    showToast(t('web.share.copyFailed'))
  }
}

/** Closed first: the drawer takes its history entry out on unmount, and only then the order opens (or that would undo it). */
async function openOrder(id: string) {
  emit('close')
  await nextTick()
  await router.push({ path: '/', query: { order: id } })
}

const METHODS = [
  { id: 'pix', label: () => t('paymentMethodPix') },
  { id: 'cash', label: () => t('paymentMethodCash') },
  { id: 'card', label: () => t('paymentMethodCard') },
  { id: 'other', label: () => t('paymentMethodOther') },
]
const methodText = computed(() => METHODS.find((m) => m.id === method.value)?.label() ?? t('receivePaymentMethodNone'))
const preview = computed(() => {
  const parts: string[] = []
  if (summary.value.settled.length === chosen.value.length && chosen.value.length) parts.push(t('receivePreviewAll', { count: chosen.value.length }))
  else if (summary.value.settled.length) parts.push(t('receivePreviewSettles', { numbers: summary.value.settled.join(', ') }))
  if (summary.value.part) parts.push(t('receivePreviewPart', { amount: money(summary.value.part.amount), number: summary.value.part.number ?? '' }))
  if (summary.value.left > 0) parts.push(t('receivePreviewLeft', { amount: money(summary.value.left) }))
  return parts.join(' ')
})
</script>

<template>
  <Layer kind="drawer" :label="t('receiveCustomerTitle', { name: customerName })" :guard="() => !saving" @close="emit('close')">
    <template #default="{ close }">
      <form class="layer-form" data-testid="receive-customer" @submit.prevent="ask">
        <div class="layer-head">
          <h2 class="layer-title">{{ t('receiveCustomerTitle', { name: customerName }) }}</h2>
          <p v-if="state === 'ready'" class="sub">{{ t('receiveCustomerOpenCount', { count: own.length }) }}</p>
        </div>
        <div class="layer-body">
          <p v-if="state === 'loading'" role="status">{{ t('web.loading') }}</p>
          <div v-else-if="state === 'failed'" class="empty" role="alert">
            <p>{{ t('web.error.generic') }}</p>
            <button type="button" class="btn" @click="load">{{ t('web.tryAgain') }}</button>
          </div>
          <div v-else-if="!orders.length" class="empty">
            <h3>{{ t('receiveAllDone') }}</h3>
            <p>{{ t('web.receive.nothingOwed', { name: customerName }) }}</p>
          </div>
          <template v-else>
            <div v-if="chargesFailed" class="charge-warn" role="alert" data-testid="customer-links-failed">
              <p>{{ t('web.receive.linksFailed') }}</p>
              <button type="button" class="btn btn--small" @click="loadCharges">{{ t('web.tryAgain') }}</button>
            </div>
            <div v-if="charge" class="charge-warn" role="status" data-testid="customer-charge">
              <strong>{{ t('receiveCustomerOpenCharge', { amount: formatMoney(charge.value, 'BR') }) }}</strong>
              <p class="sub">{{ t('chargeDetailUntil', { value: formatMoney(charge.value, 'BR'), date: formatDate(`${charge.dueDate}T12:00:00`, 'BR') }) }}</p>
              <p class="sub">{{ t('receiveChargeAdjusts', { customer: customerName }) }}</p>
              <div class="row-actions">
                <a v-if="resend" class="btn btn--small" :href="resend" target="_blank" rel="noopener noreferrer">{{ t('chargeSendAgainWhatsApp') }}</a>
                <button v-if="charge.invoiceUrl" type="button" class="link" @click="copyCharge">{{ t('chargeCopyLink') }}</button>
                <button v-if="charger" type="button" class="link link--danger" @click="dialog = 'cancelCharge'">{{ t('chargeCancelLink') }}</button>
              </div>
            </div>
            <fieldset class="pick-orders">
              <legend class="field-label">{{ t('receiveOrdersIncluded') }}</legend>
              <div v-for="order in own" :key="order.id" class="check-row pick-row" data-testid="receive-order">
                <input :id="`rc-${order.id}`" class="check" type="checkbox" :checked="picked.includes(order.id)" @change="toggle(order.id)" />
                <label :for="`rc-${order.id}`">
                  <span>{{ orderShort() }} {{ order.number }}</span>
                  <span class="sub"> · {{ order.createdAt ? formatDate(order.createdAt, country()) : '' }}</span>
                  <span v-if="rowText(order)" class="sub pick-split"> · {{ rowText(order) }}</span>
                  <span v-if="linkText(order.id)" class="sub" data-testid="order-link"> · {{ linkText(order.id) }}</span>
                  <span v-else-if="inProgress?.includes(order.id)" class="sub" data-testid="order-in-progress"> · {{ t('financialInProgress') }}</span>
                </label>
                <span class="num">{{ money(order.open) }}</span>
                <button type="button" class="link" :aria-label="t('receiveCustomerOpenOrder', { number: order.number ?? '' })" @click="openOrder(order.id)">{{ t('web.receive.open') }}</button>
              </div>
            </fieldset>
            <fieldset v-if="others.length" class="pick-orders">
              <legend class="field-label">{{ t('receiveCustomerOthersTitle', { name: customerName }) }}</legend>
              <p class="sub">{{ t('web.receive.othersNote') }}</p>
              <div v-for="order in others" :key="order.id" class="check-row pick-row">
                <input :id="`rc-${order.id}`" class="check" type="checkbox" :checked="picked.includes(order.id)" @change="toggle(order.id)" />
                <label :for="`rc-${order.id}`">{{ t('receiveCustomerPickRow', { number: order.number ?? '' }) }}<span v-if="rowText(order)" class="sub"> · {{ rowText(order) }}</span></label>
                <span class="num">{{ money(order.open) }}</span>
                <span></span>
              </div>
            </fieldset>
            <MoneyInput id="rc-amount" v-model="amount" :label="t('receiveCustomerAmountLabel')" :country="country()" required />
            <p class="field-hint">{{ t('receiveCustomerOldestFirst') }}</p>
            <label class="field-label" for="rc-method">{{ t('receivePaymentMethodQuestion') }} <span class="muted">({{ t('receivePaymentMethodOptional') }})</span></label>
            <select id="rc-method" v-model="method" class="field">
              <option value="">{{ t('receivePaymentMethodNone') }}</option>
              <option v-for="item in METHODS" :key="item.id" :value="item.id">{{ item.label() }}</option>
            </select>
            <label class="field-label" for="rc-day">{{ t('receiveWhen') }}</label>
            <input id="rc-day" v-model="day" class="field" type="date" :max="today" required />
            <div class="pay-total" aria-live="polite" data-testid="receive-total">
              <p v-if="problem" :class="chosen.length ? 'sub' : 'field-error'">{{ problem }}</p>
              <template v-else>
                <p><strong>{{ t('web.receive.total', { amount: money(amount ?? 0), count: split.length }) }}</strong></p>
                <p class="sub">{{ preview }}</p>
              </template>
            </div>
          </template>
        </div>
        <div class="layer-foot">
          <button v-if="canCharge" type="button" class="btn" data-testid="customer-charge-new" @click="newCharge">{{ t('chargeSend') }}</button>
          <button v-if="orders.length" type="button" class="btn btn--ghost" :disabled="!chosen.length || saving" data-testid="customer-statement" @click="dialog = 'statement'">{{ t('statementSend') }}</button>
          <span class="spacer"></span>
          <button type="button" class="btn" @click="close()">{{ t('cancel') }}</button>
          <button v-if="orders.length" type="submit" class="btn" :class="{ 'btn--primary': !charge }" :disabled="!!problem || saving" data-testid="receive-customer-save">{{ t('receiveMarkReceived') }}</button>
        </div>
      </form>
    </template>
  </Layer>
  <ConfirmDialog
    v-if="dialog === 'confirm'"
    :title="t('web.receive.confirmTitle', { amount: money(amount ?? 0), name: customerName })"
    :body="`${preview} ${t('web.receive.confirmMethod', { method: methodText, date: formatDate(paidAtFor(day, new Date()), country()) })}`"
    :confirm="t('receiveConfirmButton')"
    :keep="t('back')"
    @confirm="save"
    @close="dialog = null"
  />
  <ConfirmDialog
    v-else-if="dialog === 'cancelCharge' && charge"
    :title="t('receiveCustomerChargeCancelTitle', { amount: formatMoney(charge.value, 'BR') })"
    :body="t('chargeCancelConfirm')"
    :confirm="t('chargeCancelLink')"
    :keep="t('chargeKeepLink', { value: formatMoney(charge.value, 'BR') })"
    danger
    @confirm="cancelCharge"
    @close="dialog = null"
  />
  <ConfirmDialog
    v-else-if="dialog === 'replace'"
    :title="t('chargeReplaceTitle')"
    :body="t('chargeReplaceConfirm')"
    :confirm="t('chargeReplace')"
    :keep="t('cancel')"
    @confirm="replaceConfirmed"
    @close="dialog = null"
  />
  <StatementDialog
    v-else-if="dialog === 'statement'"
    :customer-id="customerId"
    :customer-name="customerName"
    :orders="chosen"
    @close="dialog = null"
  />
  <ChargeDialog
    v-else-if="dialog === 'charge'"
    :order-ids="chosen.map((o) => o.id)"
    :orders-text="`${orderShort()} ${numbers(chosen)}`"
    :customer-id="customerId"
    :customer-name="customerName"
    :owed="owed"
    :value="amount ?? undefined"
    @created="loadCharges"
    @close="dialog = null"
  />
</template>
