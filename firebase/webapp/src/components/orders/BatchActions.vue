<script setup lang="ts">
// Batch on the selected rows: status and person in charge, through the API one
// order at a time. Only what every selected order allows is offered; what the
// server refuses is counted and said (never silently skipped).
import { computed, defineAsyncComponent, nextTick, ref, shallowRef } from 'vue'
import { t } from '@/i18n'
import { orderChanged } from '@/lib/orders/bus'
import { loadTeam, type Member } from '@/lib/orders/catalog'
import { accessOf, remainingOnRow, type Order, type OrderStatus } from '@/lib/orders/model'
import { statusText } from '@/lib/orders/text'
import * as writes from '@/lib/orders/writes'
import { can, effectiveUseFinancial, session } from '@/lib/session'
import { ordersForPrint } from '@/lib/receive/data'
import { receivesMoney } from '@/lib/receive/model'
import OrderPrint from './OrderPrint.vue'
import '@/styles/receive.css'
import { showToast } from '@/lib/toast'
import { announce } from '@/lib/ui'
import ChoiceDialog from './ChoiceDialog.vue'
const ReceiveCustomerDialog = defineAsyncComponent(() => import('./receive/ReceiveCustomerDialog.vue'))

const props = defineProps<{ orders: Order[] }>()
const emit = defineEmits<{ done: [] }>()
const dialog = ref<'status' | 'assignee' | 'receive' | null>(null)
const printing = shallowRef<Order[]>([])
const busy = ref(false)
const team = shallowRef<Member[]>([])
const DOT: Record<OrderStatus, string> = { quote: 'neutral', approved: 'accent', progress: 'warning', done: 'success', canceled: 'hollow' }

const accesses = computed(() => props.orders.map((order) => accessOf(order, session.role, session.uid, effectiveUseFinancial())))
/** A status every selected order can go to (or already is in). */
const statuses = computed(() =>
  (['quote', 'approved', 'progress', 'done'] as OrderStatus[]).filter(
    (status) => props.orders.some((order) => order.status !== status) && props.orders.every((order, i) => order.status === status || accesses.value[i]?.transitions.includes(status)),
  ),
)
const canAssign = computed(() => accesses.value.every((access) => access.canAssign))
/** Several orders of one customer, all still owing and receivable by this person: one receipt (large screens). */
const receivable = computed(() => {
  const customer = props.orders[0]?.customer
  if (!customer?.id || props.orders.length < 2) return null
  const ok = props.orders.every(
    (order, i) => order.customer?.id === customer.id && receivesMoney(order.status) && (remainingOnRow(order) ?? 0) > 0 && accesses.value[i]?.canReceive,
  )
  return ok ? { id: customer.id, name: customer.name ?? '' } : null
})
const canPrint = computed(() => can('viewPrices') || !effectiveUseFinancial())

/** Each selected order on its own page, in the list's order (order.pdf.batch). */
async function printAll() {
  busy.value = true
  try {
    printing.value = await ordersForPrint(props.orders.map((o) => o.id), props.orders[0]?.showsMoney ?? false)
    await nextTick()
    // The sheets stay (hidden on screen) until the next print or until the selection closes: a print dialog that closes at once never empties the page before it prints.
    requestAnimationFrame(() => window.print())
  } catch (error) {
    console.warn('batch: print not loaded', error)
    showToast(t('web.error.generic'))
  } finally {
    busy.value = false
  }
}

async function apply(change: (order: Order) => Promise<{ order?: Record<string, unknown> }>, skip: (order: Order) => boolean) {
  dialog.value = null
  busy.value = true
  let failed = 0
  let changed = 0
  for (const order of props.orders) {
    if (skip(order)) continue
    try {
      const fresh = writes.orderOf(await change(order), order.showsMoney)
      if (fresh) orderChanged(fresh)
      changed++
    } catch (error) {
      console.warn('batch: order not changed', order.id, error)
      failed++
    }
  }
  busy.value = false
  const message = failed ? t('web.batch.partial', { changed, failed }) : t('web.batch.done', { count: changed })
  showToast(message)
  announce(message)
  emit('done')
}

const setStatus = (status: OrderStatus) =>
  apply((order) => writes.patchOrder(order.id, { status }, order.version), (order) => order.status === status)

const assign = (id: string) =>
  apply((order) => writes.patchOrder(order.id, { assignedTo: id === 'none' ? null : id }, order.version), () => false)

async function openAssignee() {
  try {
    team.value = await loadTeam()
    dialog.value = 'assignee'
  } catch {
    showToast(t('web.error.generic'))
  }
}
</script>

<template>
  <div class="batchbar" role="region" :aria-label="t('web.batch.label')">
    <strong>{{ t('web.orders.selected', { count: orders.length }) }}</strong>
    <button v-if="statuses.length" type="button" class="btn btn--primary" :disabled="busy" @click="dialog = 'status'">{{ t('orderMenuChangeStatus') }}</button>
    <button v-if="canAssign" type="button" class="btn" :disabled="busy" @click="openAssignee">{{ t('orderAddResponsible') }}</button>
    <button v-if="receivable" type="button" class="btn wide-only" :disabled="busy" data-testid="batch-receive" @click="dialog = 'receive'">{{ t('web.batch.receive', { name: receivable.name }) }}</button>
    <button v-if="canPrint" type="button" class="btn wide-only" :disabled="busy" data-testid="batch-print" @click="printAll">{{ t('web.batch.print') }}</button>
    <button type="button" class="btn btn--ghost" :disabled="busy" @click="emit('done')">{{ t('clear') }} <kbd>Esc</kbd></button>
  </div>
  <ChoiceDialog
    v-if="dialog === 'status'"
    :title="t('pickerStatusTitle')"
    :sub="t('web.orders.selected', { count: orders.length })"
    :choices="statuses.map((status) => ({ id: status, label: statusText(status), dot: DOT[status] }))"
    @pick="(id) => setStatus(id as OrderStatus)"
    @close="dialog = null"
  />
  <ChoiceDialog
    v-if="dialog === 'assignee'"
    :title="t('pickerAssigneeTitle')"
    :sub="t('web.orders.selected', { count: orders.length })"
    :choices="[...team.map((member) => ({ id: member.id, label: member.name })), { id: 'none', label: t('orderResponsibleRemove'), danger: true }]"
    @pick="assign"
    @close="dialog = null"
  />
  <ReceiveCustomerDialog
    v-if="dialog === 'receive' && receivable"
    :customer-id="receivable.id"
    :customer-name="receivable.name"
    :checked="orders.map((o) => o.id)"
    @done="(dialog = null), emit('done')"
    @close="dialog = null"
  />
  <OrderPrint v-for="order in printing" :key="order.id" :order="order" />
</template>
