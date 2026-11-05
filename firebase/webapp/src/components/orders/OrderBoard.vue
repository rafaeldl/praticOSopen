<script setup lang="ts">
// Board of orders, a tab of the list: one column per status. Dragging moves a
// card, and always has an alternative (WCAG 2.5.7): the "Mover" button or
// Shift + arrow with the card in focus. Only moves this person may make.
import { computed, nextTick, onBeforeUnmount, onMounted, ref, shallowRef, watch } from 'vue'
import { MoreHorizontal } from '@lucide/vue'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import { t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { mergeById } from '@/lib/order-list'
import { onOrderEvent, orderChanged } from '@/lib/orders/bus'
import { createListLoader, listContext } from '@/lib/orders/data'
import { accessOf, deviceSummary, isHeld, remainingOnRow, type Order, type OrderStatus } from '@/lib/orders/model'
import { holdText, lateText, money, orderShort, statusText } from '@/lib/orders/text'
import * as writes from '@/lib/orders/writes'
import { useRoutePanel } from '@/lib/route-layer'
import { effectiveUseFinancial, session } from '@/lib/session'
import { showToast } from '@/lib/toast'
import { announce } from '@/lib/ui'
import ChoiceDialog from './ChoiceDialog.vue'
import OrderDetail from './OrderDetail.vue'

const COLUMNS: OrderStatus[] = ['quote', 'approved', 'progress', 'done']
const DOT: Record<OrderStatus, string> = { quote: 'neutral', approved: 'accent', progress: 'warning', done: 'success', canceled: 'hollow' }
const ctx = listContext()
const loader = createListLoader(ctx, COLUMNS)
const rows = shallowRef<Order[]>([])
const state = ref<'loading' | 'ready' | 'failed'>('loading')
const now = new Date()
const dragging = ref<string | null>(null)
const over = ref<OrderStatus | null>(null)
const moving = ref<Order | null>(null)
const panel = useRoutePanel('order')

const props = defineProps<{ search?: string }>()
/** Cards of the search, straight from the server (lib/orders/search.ts); null while not searching. */
const found = shallowRef<Order[] | null>(null)
const searching = ref(false)
const searchFailed = ref(false)
let searchToken = 0
const shown = computed(() => found.value ?? rows.value)
const cards = computed(
  () => Object.fromEntries(COLUMNS.map((status) => [status, shown.value.filter((order) => order.status === status)])) as Record<OrderStatus, Order[]>,
)

/** The search of the toolbar: the same server query as the list (number, customer, vehicle). */
async function runSearch(text: string) {
  const token = ++searchToken
  searchFailed.value = false
  if (!text) {
    found.value = null
    searching.value = false
    return
  }
  searching.value = true
  try {
    const { searchOrders } = await import('@/lib/orders/search')
    const result = await searchOrders(ctx, text)
    if (token !== searchToken) return
    found.value = mergeById([], result)
    announce(t('web.orders.count', { count: COLUMNS.reduce((sum, status) => sum + cards.value[status].length, 0) }))
  } catch (error) {
    console.warn('board: search failed', error)
    if (token === searchToken) searchFailed.value = true
  } finally {
    if (token === searchToken) searching.value = false
  }
}
watch(() => props.search ?? '', (text) => void runSearch(text), { immediate: true })
const access = (order: Order) => accessOf(order, session.role, session.uid, effectiveUseFinancial())

async function load() {
  state.value = 'loading'
  try {
    const page = await loader.first()
    rows.value = page.rows
    if (page.hasMore) rows.value = mergeById(rows.value, (await loader.more()).rows)
    state.value = 'ready'
  } catch (error) {
    console.error('board: failed', error)
    state.value = 'failed'
  }
}

async function move(order: Order, to: OrderStatus) {
  moving.value = null
  if (order.status === to) return
  if (!access(order).transitions.includes(to)) {
    showToast(t('web.board.notAllowed', { status: statusText(to) }))
    return
  }
  try {
    const fresh = writes.orderOf(await writes.patchOrder(order.id, { status: to }, order.version), ctx.showsMoney)
    if (fresh) {
      rows.value = mergeById(rows.value, [fresh])
      if (found.value) found.value = mergeById(found.value, [fresh])
      orderChanged(fresh)
    }
    announce(t('web.order.statusChanged', { status: statusText(to) }))
    await nextTick()
    document.getElementById(`card-${order.id}`)?.focus()
  } catch (error) {
    showToast(t(errorMessageKey(error)))
  }
}

function onKey(event: KeyboardEvent, order: Order) {
  if (!event.shiftKey || (event.key !== 'ArrowLeft' && event.key !== 'ArrowRight')) return
  event.preventDefault()
  const next = COLUMNS[COLUMNS.indexOf(order.status) + (event.key === 'ArrowRight' ? 1 : -1)]
  if (next) void move(order, next)
}

function drop(status: OrderStatus) {
  const order = rows.value.find((row) => row.id === dragging.value)
  dragging.value = null
  over.value = null
  if (order) void move(order, status)
}

const stop = onOrderEvent(({ order, removedId }) => {
  if (removedId) rows.value = rows.value.filter((row) => row.id !== removedId)
  if (order) rows.value = mergeById(rows.value.filter((row) => row.id !== order.id), order.status === 'canceled' ? [] : [order])
  if (found.value && removedId) found.value = found.value.filter((row) => row.id !== removedId)
  if (found.value && order && found.value.some((row) => row.id === order.id)) found.value = mergeById(found.value.filter((row) => row.id !== order.id), order.status === 'canceled' ? [] : [order])
})
onMounted(load)
onBeforeUnmount(stop)
</script>

<template>
  <LoadingState v-if="state === 'loading' || searching" />
  <ErrorState v-else-if="state === 'failed'" :retry="load" />
  <ErrorState v-else-if="searchFailed" :retry="() => runSearch(props.search ?? '')" />
  <div v-else-if="found && !found.some((order) => COLUMNS.includes(order.status))" class="empty" data-testid="board-no-match">
    <h2>{{ t('web.orders.noMatch', { query: props.search ?? '' }) }}</h2>
  </div>
  <div v-else class="board-wrap" :class="{ 'has-panel': panel.value.value }">
    <div class="board" data-testid="board">
      <section
        v-for="status in COLUMNS"
        :key="status"
        class="col"
        :class="{ 'is-over': over === status }"
        :aria-labelledby="`col-${status}`"
        @dragover.prevent="over = status"
        @dragleave.self="over = null"
        @drop.prevent="drop(status)"
      >
        <h2 :id="`col-${status}`" class="col-head">
          <span class="dot" :class="`dot--${DOT[status]}`" aria-hidden="true"></span>{{ statusText(status) }}<span class="num">{{ cards[status].length }}</span>
        </h2>
        <ul class="col-list">
          <li
            v-for="order in cards[status]"
            :key="order.id"
            class="card"
            :class="{ 'is-dragging': dragging === order.id }"
            :draggable="access(order).transitions.length > 0"
            :data-order="order.id"
            @dragstart="dragging = order.id"
            @dragend="dragging = null; over = null"
          >
            <button :id="`card-${order.id}`" type="button" class="card-open" :aria-describedby="`card-${order.id}-state`" @click="panel.open(order.id)" @keydown="onKey($event, order)">
              <span class="card-top"><strong class="who">{{ order.customer?.name }}</strong><span class="num">{{ order.number }}</span></span>
              <span class="sub">{{ deviceSummary(order) }}</span>
            </button>
            <span :id="`card-${order.id}-state`" class="card-flag" :class="{ 'card-flag--late': lateText(order, now) }">
              {{ lateText(order, now) || (isHeld(order) ? holdText(order, now) : '') }}
            </span>
            <span v-if="order.showsMoney" class="num card-money">{{ money(remainingOnRow(order) ?? order.total) }}</span>
            <button v-if="access(order).transitions.length" type="button" class="icon-btn card-move" :aria-label="t('web.board.move', { order: orderShort(), number: order.number ?? '' })" @click="moving = order">
              <MoreHorizontal :size="16" aria-hidden="true" />
            </button>
          </li>
        </ul>
        <p v-if="!cards[status].length" class="muted small">{{ t('web.board.emptyColumn') }}</p>
      </section>
    </div>
    <aside v-if="panel.value.value" class="panel" :aria-label="t('web.orders.panel')">
      <OrderDetail :key="panel.value.value" :order-id="panel.value.value" @close="panel.close()" />
    </aside>
  </div>
  <ChoiceDialog
    v-if="moving"
    :title="t('web.board.moveTitle')"
    :sub="`${moving.number} · ${moving.customer?.name ?? ''}`"
    :choices="COLUMNS.filter((status) => status === moving!.status || access(moving!).transitions.includes(status)).map((status) => ({ id: status, label: statusText(status), dot: DOT[status], current: status === moving!.status }))"
    @pick="(id) => move(moving as Order, id as OrderStatus)"
    @close="moving = null"
  />
</template>
