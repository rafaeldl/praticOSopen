<script setup lang="ts">
// "Próxima cobrança" (fin.tab.next-charge, -send, -snooze): one customer to
// charge now, chosen by lib/finance/next-charge.ts. "Mandar cobrança" opens one
// charge for the customer's orders (Asaas, several orders: pay.customer.start-charge)
// or the order's own link (one order, or without Asaas: the link of the order).
// "Agora não" hides the customer for 30 days in this browser.
import { defineAsyncComponent, ref, shallowRef, watch } from 'vue'
import ChoiceDialog from '@/components/orders/ChoiceDialog.vue'
import { loadOrderTexts, t } from '@/i18n'
import type { Debtor, FinanceRow, FinanceSummary } from '@/lib/finance/data'
import { withNotice, nextChargeCandidates, openOrdersOf, resolveNextCharge, sendPath, snoozeNextCharge, snoozedKeys } from '@/lib/finance/next-charge'
import { formatDate, formatDayMonth } from '@/lib/format'
import { firestoreLite } from '@/lib/firebase'
import type { Order } from '@/lib/orders/model'
import { country, money, orderShort } from '@/lib/orders/text'
import { customerCharges, ordersForPrint, paymentSettings } from '@/lib/receive/data'
import { chargeOf, isOpenCharge } from '@/lib/receive/model'
import { can, session } from '@/lib/session'
import { showToast } from '@/lib/toast'
import { errorMessageKey } from '@/lib/api'

const ReceiveCustomerDialog = defineAsyncComponent(() => import('@/components/orders/receive/ReceiveCustomerDialog.vue'))
const ChargeDialog = defineAsyncComponent(() => import('@/components/orders/receive/ChargeDialog.vue'))
const ShareDialog = defineAsyncComponent(() => import('@/components/orders/receive/ShareDialog.vue'))

const props = defineProps<{ summary: FinanceSummary }>()
const emit = defineEmits<{ changed: [] }>()

const next = shallowRef<Debtor | null>(null)
const step = ref<null | 'sheet' | 'which' | 'customer' | 'charge' | 'share'>(null)
const order = shallowRef<FinanceRow | null>(null)
const shared = shallowRef<Order | null>(null)
const sending = ref(false)
let run = 0

/** A link of the customer, or of any of their open orders (pending or overdue). */
async function hasOpenCharge(debtor: Debtor): Promise<boolean> {
  const id = debtor.customer?.id
  if (id && (await customerCharges(id)).some(isOpenCharge)) return true
  const [db, { collection, getDocs }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  const running = [...props.summary.progress.orders, ...props.summary.receivable.deposits]
  for (const orderId of openOrdersOf(debtor, running)) {
    const snap = await getDocs(collection(db, 'companies', session.companyId as string, 'orders', orderId, 'charges'))
    if (snap.docs.some((d) => isOpenCharge(chargeOf(d.id, d.data())))) return true
  }
  return false
}

async function resolve() {
  const mine = ++run
  const now = new Date()
  const candidates = nextChargeCandidates(props.summary.receivable.debtors, snoozedKeys(session.companyId as string, now), now)
  // Kept on reload while still owing, until the links are read again (the app's store).
  if (next.value && !candidates.some((d) => d.key === next.value?.key)) next.value = null
  const found = await resolveNextCharge(candidates, hasOpenCharge)
  if (mine === run) next.value = found
}
watch(() => props.summary, () => void resolve(), { immediate: true })

const nameOf = (debtor: Debtor) => debtor.customer?.name || t('customerWithoutName')
/** dd/mm this year, the full date otherwise (formatDayMonthOrDate). */
function sinceText(iso: string | null): string {
  if (!iso) return ''
  return new Date(iso).getFullYear() === new Date().getFullYear() ? formatDayMonth(iso, country()) : formatDate(iso, country())
}

function snooze() {
  const debtor = next.value
  step.value = null
  if (!debtor) return
  snoozeNextCharge(session.companyId as string, debtor.key, new Date())
  next.value = null
  void resolve()
}

/** A second click while it runs is ignored (fin.tab.next-charge-send). */
async function send() {
  const debtor = next.value
  if (!debtor || sending.value) return
  sending.value = true
  step.value = null
  await withNotice(async () => {
    await loadOrderTexts()
    const settings = await paymentSettings()
    const asaas = settings.ready && can('chargeOrder')
    if (sendPath(debtor, asaas) === 'customer') {
      step.value = 'customer'
      return
    }
    if (debtor.orders.length === 1) await sendOrder(debtor.orders[0] as FinanceRow, asaas)
    else step.value = 'which'
  }, failed)
  sending.value = false
}
const failed = (error: unknown) => showToast(t(errorMessageKey(error)))

async function sendOrder(row: FinanceRow, asaas = false) {
  order.value = row
  if (asaas && row.status !== 'quote' && row.status !== 'canceled' && row.open > 0) {
    step.value = 'charge'
    return
  }
  // Without Asaas that charges: the order's link, as the app's ShareLinkSheet.
  try {
    const [full] = await ordersForPrint([row.id], can('viewPrices'))
    if (!full) return
    shared.value = full
    step.value = 'share'
  } catch (error) {
    showToast(t(errorMessageKey(error)))
  }
}

async function pickOrder(id: string) {
  const row = next.value?.orders.find((o) => o.id === id)
  step.value = null
  if (!row) return
  await withNotice(async () => sendOrder(row, (await paymentSettings()).ready && can('chargeOrder')), failed)
}

function done() {
  step.value = null
  emit('changed')
}
</script>

<template>
  <section v-if="next" class="fin-next" aria-labelledby="fin-next-title" data-testid="next-charge">
    <h2 id="fin-next-title">{{ t('financialNextCharge') }}</h2>
    <button type="button" class="fin-row" :aria-busy="sending ? 'true' : 'false'" @click="step = 'sheet'">
      <span class="who">{{ nameOf(next) }}</span>
      <span class="num">{{ money(next.amount) }}</span>
    </button>
  </section>
  <ChoiceDialog
    v-if="step === 'sheet' && next"
    :title="t('financialNextCharge')"
    :sub="t('financialNextChargeMessage', { name: nameOf(next), amount: money(next.amount), date: sinceText(next.since) })"
    :choices="[
      { id: 'send', label: t('financialSendCharge') },
      { id: 'later', label: t('notNow') },
    ]"
    suggested="send"
    @pick="(id) => (id === 'send' ? send() : snooze())"
    @close="step = null"
  />
  <ChoiceDialog
    v-else-if="step === 'which' && next"
    :title="t('financialWhichOrder')"
    :sub="t('financialPickOrderTitle', { name: nameOf(next) })"
    :choices="next.orders.map((o) => ({ id: o.id, label: t('financialOrderOption', { number: o.number ?? 0, amount: money(o.open), date: sinceText(o.createdAt) }) }))"
    @pick="pickOrder"
    @close="step = null"
  />
  <ReceiveCustomerDialog
    v-else-if="step === 'customer' && next?.customer?.id"
    :customer-id="next.customer.id"
    :customer-name="nameOf(next)"
    :checked="next.orders.map((o) => o.id)"
    start-charge
    @done="done"
    @close="done"
  />
  <ChargeDialog
    v-else-if="step === 'charge' && order"
    :order-id="order.id"
    :orders-text="`${orderShort()} ${order.number ?? ''}`"
    :customer-id="order.customer?.id ?? undefined"
    :customer-name="order.customer?.name ?? undefined"
    :owed="order.open"
    @created="emit('changed')"
    @close="done"
  />
  <ShareDialog v-else-if="step === 'share' && shared" :order="shared" send @close="step = null" />
</template>
