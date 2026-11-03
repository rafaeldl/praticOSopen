<script setup lang="ts">
// Batch on the selected rows (home.batch.*): status, person in charge, charge,
// the assistant, PDF and print. Every change asks first and says how many orders
// change; each order goes through the API (never money in Firestore); what the
// server refuses is counted and said. Undo when the way back is allowed.
import { computed, defineAsyncComponent, nextTick, onMounted, ref, shallowRef } from 'vue'
import { t } from '@/i18n'
import { orderChanged } from '@/lib/orders/bus'
import { loadTeam, type Member } from '@/lib/orders/catalog'
import { accessOf, remainingOnRow, type Order, type OrderStatus } from '@/lib/orders/model'
import { orderShort, statusText } from '@/lib/orders/text'
import * as writes from '@/lib/orders/writes'
import { assistStatus } from '@/lib/orders/assistant'
import { can, effectiveUseFinancial, session } from '@/lib/session'
import { ordersForPrint, paymentSettings } from '@/lib/receive/data'
import { receivableOf, receivesMoney } from '@/lib/receive/model'
import { errorMessageKey } from '@/lib/api'
import { firestoreLite } from '@/lib/firebase'
import OrderPrint from './OrderPrint.vue'
import '@/styles/receive.css'
import { showToast } from '@/lib/toast'
import { announce } from '@/lib/ui'
import ChoiceDialog from './ChoiceDialog.vue'
import BatchConfirm from './BatchConfirm.vue'
const PdfDialog = defineAsyncComponent(() => import('./PdfDialog.vue'))
const BatchChargeDialog = defineAsyncComponent(() => import('./BatchChargeDialog.vue'))
const AiBatchDialog = defineAsyncComponent(() => import('./AiBatchDialog.vue'))
const ReceiveCustomerDialog = defineAsyncComponent(() => import('./receive/ReceiveCustomerDialog.vue'))

const props = defineProps<{ orders: Order[] }>()
const emit = defineEmits<{ done: [] }>()
type Dialog = 'status' | 'assignee' | 'receive' | 'pdf' | 'charge' | 'ai' | null
const dialog = ref<Dialog>(null)
const printing = shallowRef<Order[]>([])
const busy = ref(false)
const team = shallowRef<Member[]>([])
const chargesReady = ref(false)
const aiReady = ref(false)
const DOT: Record<OrderStatus, string> = { quote: 'neutral', approved: 'accent', progress: 'warning', done: 'success', canceled: 'hollow' }

const accessFor = (order: Order) => accessOf(order, session.role, session.uid, effectiveUseFinancial())
const accesses = computed(() => props.orders.map(accessFor))
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
/** "Mandar cobrança" (home.batch.charge): who charges, with Asaas on, and something owed. */
const canCharge = computed(() => chargesReady.value && props.orders.some((order) => order.customer?.id && (receivableOf(order) ?? 0) > 0))
/** The assistant (order.ai.batch): on for the company and every order open to item changes. */
const canAsk = computed(() => aiReady.value && accesses.value.every((access) => access.canEditMainFields))

onMounted(async () => {
  if (can('chargeOrder') && can('viewPrices')) chargesReady.value = (await paymentSettings({ retries: 0 })).ready
  if (accesses.value.every((access) => access.canEditMainFields)) {
    try {
      aiReady.value = (await assistStatus()).enabled
    } catch {
      aiReady.value = false
    }
  }
})

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

// ---------------------------------------------------------------------------
// Status and person in charge: ask, apply, undo
// ---------------------------------------------------------------------------

interface Pending {
  title: string
  /** Orders that change, with what they become. */
  changes: { order: Order; text: string }[]
  /** Orders left as they are, said in the dialog. */
  note: string
  apply: (order: Order) => Promise<{ order?: Record<string, unknown> }>
  /** The way back for one order, from its new version; null when it cannot go back. */
  back: (before: Order, after: Order) => ((version: string | null | undefined) => Promise<{ order?: Record<string, unknown> }>) | null
}
const pending = shallowRef<Pending | null>(null)
const line = (order: Order) => `${orderShort()} ${order.number ?? ''} · ${order.customer?.name ?? ''}`

/** Orders with a checklist not completed: they cannot be concluded (order.status.pending-checklist, as the order screen). */
async function withPendingForms(orders: Order[]): Promise<Set<string>> {
  const [db, { collection, getDocs }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
  const found = await Promise.all(
    orders.map(async (order) => {
      const snap = await getDocs(collection(db, 'companies', session.companyId as string, 'orders', order.id, 'forms'))
      return snap.docs.some((d) => d.data().status !== 'completed') ? order.id : null
    }),
  )
  return new Set(found.filter((id): id is string => !!id))
}

async function askStatus(status: OrderStatus) {
  dialog.value = null
  let changes = props.orders.filter((order) => order.status !== status)
  const same = props.orders.length - changes.length
  let pendingForms = 0
  if (status === 'done') {
    busy.value = true
    try {
      const blocked = await withPendingForms(changes)
      pendingForms = blocked.size
      changes = changes.filter((order) => !blocked.has(order.id))
    } catch (error) {
      // Not knowing is not "no checklist": nothing is concluded.
      console.warn('batch: checklists not read', error)
      showToast(t('web.error.generic'))
      return
    } finally {
      busy.value = false
    }
  }
  pending.value = {
    title: t('web.batch.statusTitle', { count: changes.length, order: orderShort(), status: statusText(status) }),
    changes: changes.map((order) => ({ order, text: `${statusText(order.status)} → ${statusText(status)}` })),
    note: [same ? t('web.batch.alreadySo', { count: same }) : '', pendingForms ? t('web.batch.pendingForms', { count: pendingForms }) : ''].filter(Boolean).join(' '),
    apply: (order) => writes.patchOrder(order.id, { status }, order.version),
    // Back only where the role allows the opposite move from the new status.
    back: (before, after) => (accessFor(after).transitions.includes(before.status) ? (version) => writes.patchOrder(after.id, { status: before.status }, version) : null),
  }
}

function askAssignee(id: string) {
  dialog.value = null
  const member = team.value.find((m) => m.id === id)
  const target = id === 'none' ? null : id
  const changes = props.orders.filter((order) => (order.assignedTo?.id ?? null) !== target)
  const same = props.orders.length - changes.length
  pending.value = {
    title: member
      ? t('web.batch.assigneeTitle', { name: member.name, count: changes.length, order: orderShort() })
      : t('web.batch.assigneeNoneTitle', { count: changes.length, order: orderShort() }),
    changes: changes.map((order) => ({ order, text: `${order.assignedTo?.name ?? t('web.batch.nobody')} → ${member?.name ?? t('web.batch.nobody')}` })),
    note: same ? t('web.batch.alreadySo', { count: same }) : '',
    apply: (order) => writes.patchOrder(order.id, { assignedTo: target }, order.version),
    back: (before, after) => (version) => writes.patchOrder(after.id, { assignedTo: before.assignedTo?.id ?? null }, version),
  }
}

async function confirmPending() {
  const plan = pending.value
  // One run only: a second click finds nothing pending (B1).
  if (!plan || busy.value) return
  pending.value = null
  busy.value = true
  const failures: string[] = []
  const ways: { after: Order; go: (version: string | null | undefined) => Promise<{ order?: Record<string, unknown> }> }[] = []
  let undoable = true
  for (const { order } of plan.changes) {
    try {
      const fresh = writes.orderOf(await plan.apply(order), order.showsMoney)
      if (fresh) {
        orderChanged(fresh)
        const go = plan.back(order, fresh)
        if (go) ways.push({ after: fresh, go })
        else undoable = false
      } else undoable = false
    } catch (error) {
      console.warn('batch: order not changed', order.id, error)
      failures.push(t('web.batch.failedOne', { order: `${orderShort()} ${order.number ?? ''}`, reason: t(errorMessageKey(error)) }))
    }
  }
  busy.value = false
  const failed = failures.length
  const changed = plan.changes.length - failed
  const message = failed ? [t('web.batch.partial', { changed, failed }), ...failures.slice(0, 3)].join(' ') : t('web.batch.done', { count: changed })
  showToast(message, undoable && ways.length ? { undo: () => void undo(ways) } : {})
  announce(message)
  emit('done')
}

async function undo(ways: { after: Order; go: (version: string | null | undefined) => Promise<{ order?: Record<string, unknown> }> }[]) {
  let failed = 0
  for (const { after, go } of ways) {
    try {
      const fresh = writes.orderOf(await go(after.version), after.showsMoney)
      if (fresh) orderChanged(fresh)
    } catch (error) {
      // Someone changed it since: the server refuses (409) and it stays as it is now.
      console.warn('batch: undo refused', after.id, error)
      failed++
    }
  }
  const message = failed ? t('web.batch.undoPartial', { count: failed }) : t('web.batch.undone')
  showToast(message)
  announce(message)
}

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
    <button v-if="canCharge" type="button" class="btn" :disabled="busy" data-testid="batch-charge" @click="dialog = 'charge'">{{ t('chargeLinkTitle') }}</button>
    <button v-if="canAsk" type="button" class="btn" :disabled="busy" data-testid="batch-ai" @click="dialog = 'ai'"><span class="ai" aria-hidden="true">✦</span> {{ t('web.ai.batchButton') }}</button>
    <button v-if="receivable" type="button" class="btn wide-only" :disabled="busy" data-testid="batch-receive" @click="dialog = 'receive'">{{ t('web.batch.receive', { name: receivable.name }) }}</button>
    <button v-if="canPrint" type="button" class="btn" :disabled="busy" data-testid="batch-pdf" @click="dialog = 'pdf'">{{ t('web.batch.pdf') }}</button>
    <button v-if="canPrint" type="button" class="btn wide-only" :disabled="busy" data-testid="batch-print" @click="printAll">{{ t('web.batch.print') }}</button>
    <button type="button" class="btn btn--ghost" :disabled="busy" @click="emit('done')">{{ t('clear') }} <kbd>Esc</kbd></button>
  </div>
  <ChoiceDialog
    v-if="dialog === 'status'"
    :title="t('pickerStatusTitle')"
    :sub="t('web.orders.selected', { count: orders.length })"
    :choices="statuses.map((status) => ({ id: status, label: statusText(status), dot: DOT[status] }))"
    @pick="(id) => askStatus(id as OrderStatus)"
    @close="dialog = null"
  />
  <ChoiceDialog
    v-if="dialog === 'assignee'"
    :title="t('pickerAssigneeTitle')"
    :sub="t('web.orders.selected', { count: orders.length })"
    :choices="[...team.map((member) => ({ id: member.id, label: member.name })), { id: 'none', label: t('orderResponsibleRemove'), danger: true }]"
    @pick="askAssignee"
    @close="dialog = null"
  />
  <BatchConfirm
    v-if="pending"
    :title="pending.title"
    :lines="pending.changes.map((change) => ({ id: change.order.id, text: line(change.order), right: change.text }))"
    :note="pending.note"
    :confirm="t('web.batch.confirm', { count: pending.changes.length, order: orderShort() })"
    :disabled="busy"
    @confirm="confirmPending"
    @close="pending = null"
  />
  <BatchChargeDialog v-if="dialog === 'charge'" :orders="orders" @close="dialog = null" />
  <AiBatchDialog v-if="dialog === 'ai'" :orders="orders" @close="dialog = null" @done="(dialog = null), emit('done')" />
  <ReceiveCustomerDialog
    v-if="dialog === 'receive' && receivable"
    :customer-id="receivable.id"
    :customer-name="receivable.name"
    :checked="orders.map((o) => o.id)"
    @done="(dialog = null), emit('done')"
    @close="dialog = null"
  />
  <PdfDialog v-if="dialog === 'pdf'" :ids="orders.map((o) => o.id)" :numbers="orders.map((o) => o.number)" @close="dialog = null" />
  <OrderPrint v-for="order in printing" :key="order.id" :order="order" />
</template>
