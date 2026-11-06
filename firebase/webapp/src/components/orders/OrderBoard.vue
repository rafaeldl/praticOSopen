<script setup lang="ts">
// Board of orders, a tab of the list: one column per status. With work stages
// (docs/WORK_STAGES.md), "Em andamento" becomes one column per stage, ordered by
// dragging, each with its own print. Dragging always has an alternative
// (WCAG 2.5.7): the "Mover" button, Shift + arrow (column) and Alt + arrow
// (place in the stage) with the card in focus. Only moves this person may make.
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
import { FIRST_PAGE, PAGE_SIZE } from '@/lib/orders-query'
import { holdText, lateText, orderShort, shownMoney, statusText } from '@/lib/orders/text'
import { prefs } from '@/lib/prefs'
import * as writes from '@/lib/orders/writes'
import { useRoutePanel } from '@/lib/route-layer'
import { effectiveUseFinancial, session } from '@/lib/session'
import { showToast } from '@/lib/toast'
import { announce } from '@/lib/ui'
import ChoiceDialog, { type Choice } from './ChoiceDialog.vue'
import StagePrint from './StagePrint.vue'
import { rankAt, sortInStage, stageIdOf, suggestedStage, workStages, type WorkStage } from '@/lib/orders/stages'
import OrderDetail from './OrderDetail.vue'

const STATUSES: OrderStatus[] = ['quote', 'approved', 'progress', 'done']
const DOT: Record<OrderStatus, string> = { quote: 'neutral', approved: 'accent', progress: 'warning', done: 'success', canceled: 'hollow' }
interface Column {
  key: string
  status: OrderStatus
  stage?: WorkStage
}
const stages = computed(workStages)
/** Statuses, with "Em andamento" split into the company's stages when it has them. */
const columns = computed<Column[]>(() =>
  STATUSES.flatMap((status): Column[] =>
    status === 'progress' && stages.value.length
      ? stages.value.map((stage) => ({ key: `stage-${stage.id}`, status, stage }))
      : [{ key: status, status }],
  ),
)
const columnLabel = (column: Column) => column.stage?.name ?? statusText(column.status)
const ctx = listContext()
const loader = createListLoader(ctx, STATUSES)
const rows = shallowRef<Order[]>([])
const state = ref<'loading' | 'ready' | 'failed'>('loading')
const now = ref(new Date())
const dragging = ref<string | null>(null)
const over = ref<string | null>(null)
/** Place in the column under the dragged card (stage columns only); null is the end. */
const overIndex = ref<number | null>(null)
const moving = ref<Order | null>(null)
const panel = useRoutePanel('order')

const props = defineProps<{ search?: string }>()
/** Cards of the search, straight from the server (lib/orders/search.ts); null while not searching. */
const found = shallowRef<Order[] | null>(null)
const searching = ref(false)
const searchFailed = ref(false)
let searchToken = 0
const shown = computed(() => found.value ?? rows.value)
function columnKeyOf(order: Order): string {
  const stageId = stageIdOf(order, stages.value)
  return stageId ? `stage-${stageId}` : order.status
}
const cards = computed(() => {
  const byKey: Record<string, Order[]> = Object.fromEntries(columns.value.map((column) => [column.key, []]))
  for (const order of shown.value) byKey[columnKeyOf(order)]?.push(order)
  for (const column of columns.value) if (column.stage) byKey[column.key] = sortInStage(byKey[column.key] ?? [], column.stage.id)
  return byKey
})
const cardsOf = (key: string): Order[] => cards.value[key] ?? []

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
    announce(t('web.orders.count', { count: columns.value.reduce((sum, column) => sum + cardsOf(column.key).length, 0) }))
  } catch (error) {
    console.warn('board: search failed', error)
    if (token === searchToken) searchFailed.value = true
  } finally {
    if (token === searchToken) searching.value = false
  }
}
watch(() => props.search ?? '', (text) => void runSearch(text), { immediate: true })
const access = (order: Order) => accessOf(order, session.role, session.uid, effectiveUseFinancial())

/** The board's cards: the first page and the next one, newest first. */
const BOARD_SIZE = FIRST_PAGE + PAGE_SIZE
/** Who reads the API (no values) has no live rows: the board asks again this often and when the tab comes back. */
const API_REFRESH_MS = 2 * 60_000
let stopLive: (() => void) | undefined
let refreshTimer: ReturnType<typeof setInterval> | undefined
let unmounted = false

async function read(): Promise<Order[]> {
  const page = await loader.first()
  return page.hasMore ? mergeById(page.rows, (await loader.more()).rows) : page.rows
}

async function load() {
  state.value = 'loading'
  try {
    rows.value = await read()
    state.value = 'ready'
    void goLive()
  } catch (error) {
    console.error('board: failed', error)
    state.value = 'failed'
  }
}

/**
 * The board stays open on a screen all day (a TV in the shop): another
 * person's change must show without reloading. Firestore readers watch the
 * same query the board read; API readers ask again from time to time.
 */
async function goLive() {
  stopLive?.()
  stopLive = undefined
  if (ctx.showsMoney) {
    const stop = await loader.watch(BOARD_SIZE, (fresh) => (rows.value = fresh), (error) => console.warn('board: live stopped', error))
    if (unmounted) stop()
    else stopLive = stop
    return
  }
  refreshTimer ??= setInterval(() => void refresh(), API_REFRESH_MS)
}

/** Quiet reload: keeps the cards on screen if it fails. */
async function refresh() {
  if (ctx.showsMoney || state.value !== 'ready' || document.visibilityState !== 'visible') return
  try {
    rows.value = await read()
  } catch (error) {
    console.warn('board: refresh failed', error)
  }
}

function onVisible() {
  if (document.visibilityState === 'visible') void refresh()
}

/** Who may put this order in a stage column, or reorder it there (canChangeOrderStage; starting also needs the transition). */
function canStage(order: Order): boolean {
  const access = accessOf(order, session.role, session.uid, effectiveUseFinancial())
  if (!access.canChangeHold) return false
  return order.status === 'progress' || (order.status === 'approved' && access.transitions.includes('progress'))
}

function canPlace(order: Order, column: Column): boolean {
  if (column.stage) return canStage(order)
  return column.status !== order.status && access(order).transitions.includes(column.status)
}

const canDrag = (order: Order) => columns.value.some((column) => canPlace(order, column))

function keep(fresh: Order) {
  rows.value = mergeById(rows.value, [fresh])
  if (found.value) found.value = mergeById(found.value, [fresh])
}

async function focusCard(id: string) {
  await nextTick()
  document.getElementById(`card-${id}`)?.focus()
}

/** Moves to a column; in a stage column, to `index` of it (the end when absent). */
async function move(order: Order, column: Column, index?: number) {
  moving.value = null
  if (column.stage) return placeInStage(order, column.stage, index)
  if (order.status === column.status) return
  if (!access(order).transitions.includes(column.status)) {
    showToast(t('web.board.notAllowed', { status: statusText(column.status) }))
    return
  }
  try {
    const fresh = writes.orderOf(await writes.patchOrder(order.id, { status: column.status }, order.version), ctx.showsMoney)
    if (fresh) {
      keep(fresh)
      orderChanged(fresh)
    }
    announce(t('web.order.statusChanged', { status: statusText(column.status) }))
    await focusCard(order.id)
  } catch (error) {
    showToast(t(errorMessageKey(error)))
  }
}

/**
 * Stage and place, shown at once (a reorder must feel instant) and put back if
 * the server refuses. An approved order starts (`progress`) in the same write.
 */
async function placeInStage(order: Order, stage: WorkStage, index?: number) {
  if (!canStage(order)) {
    showToast(t('web.board.notAllowed', { status: stage.name }))
    return
  }
  const key = `stage-${stage.id}`
  const others = cardsOf(key).filter((row) => row.id !== order.id)
  const at = index === undefined ? others.length : Math.max(0, Math.min(index, others.length))
  const sameColumn = columnKeyOf(order) === key
  if (sameColumn && cardsOf(key).indexOf(order) === at && order.stage?.id === stage.id) return
  const rank = rankAt(others, at, stage.id)
  const before = order
  keep({ ...order, status: 'progress', stage: { id: stage.id, rank: rank ?? Number.MAX_SAFE_INTEGER, since: sameColumn && order.stage?.since ? order.stage.since : new Date().toISOString() } })
  try {
    const fresh = writes.orderOf(await writes.setStage(order.id, stage.id, rank), ctx.showsMoney)
    if (fresh) {
      keep(fresh)
      orderChanged(fresh)
    }
    announce(sameColumn ? t('web.board.placed', { stage: stage.name, place: at + 1 }) : t('web.board.stageChanged', { stage: stage.name }))
    await focusCard(order.id)
  } catch (error) {
    keep(before)
    showToast(t(errorMessageKey(error)))
  }
}

/** Up or down one place in its stage column ("…" and Alt + arrow). */
function shift(order: Order, by: -1 | 1) {
  moving.value = null
  const column = columns.value.find((col) => col.key === columnKeyOf(order))
  if (!column?.stage) return
  const place = cardsOf(column.key).indexOf(order) + by
  if (place < 0 || place >= cardsOf(column.key).length) return
  void placeInStage(order, column.stage, place)
}

function onKey(event: KeyboardEvent, order: Order) {
  if (event.altKey && (event.key === 'ArrowUp' || event.key === 'ArrowDown')) {
    event.preventDefault()
    shift(order, event.key === 'ArrowUp' ? -1 : 1)
    return
  }
  if (!event.shiftKey || (event.key !== 'ArrowLeft' && event.key !== 'ArrowRight')) return
  event.preventDefault()
  const list = columns.value
  const next = list[list.findIndex((column) => column.key === columnKeyOf(order)) + (event.key === 'ArrowRight' ? 1 : -1)]
  if (next) void move(order, next)
}

/** Over a card of a stage column: before it in its top half, after it in the bottom one. */
function dragOverCard(event: DragEvent, column: Column, index: number) {
  if (!column.stage) return
  const box = (event.currentTarget as HTMLElement).getBoundingClientRect()
  overIndex.value = event.clientY > box.top + box.height / 2 ? index + 1 : index
}

/** A new column under the pointer starts at its end; its cards then say the place. */
function overColumn(column: Column) {
  if (over.value === column.key) return
  over.value = column.key
  overIndex.value = null
}

/** Over the empty part of a column, under its cards: the end. */
function dragOverList(event: DragEvent) {
  if (event.target === event.currentTarget) overIndex.value = null
}

function drop(column: Column) {
  const order = shown.value.find((row) => row.id === dragging.value)
  let index = overIndex.value ?? undefined
  // The dragged card leaves its own column first: a place under it moves up by one.
  if (order && index !== undefined && columnKeyOf(order) === column.key && cardsOf(column.key).indexOf(order) < index) index -= 1
  dragging.value = null
  over.value = null
  overIndex.value = null
  if (order) void move(order, column, index)
}

/** "…": the columns it may go to, and up/down in its stage. */
function moveChoices(order: Order) {
  const current = columnKeyOf(order)
  const list: Choice[] = columns.value
    .filter((column) => column.key === current || canPlace(order, column))
    .map((column) => ({ id: column.key, label: columnLabel(column), dot: DOT[column.status], current: column.key === current }))
  const column = columns.value.find((col) => col.key === current)
  if (column?.stage && canStage(order)) {
    const place = cardsOf(current).indexOf(order)
    if (place > 0) list.push({ id: 'up', label: t('web.board.up') })
    if (place < cardsOf(current).length - 1) list.push({ id: 'down', label: t('web.board.down') })
  }
  return list
}

function pick(order: Order, id: string) {
  if (id === 'up' || id === 'down') return shift(order, id === 'up' ? -1 : 1)
  const column = columns.value.find((col) => col.key === id)
  if (column) void move(order, column)
}

/** The stage being printed (StagePrint stays hidden on screen until the next print). */
/** The column whose "…" is open (its rare actions: print the stage's list). */
const columnMenu = shallowRef<Column | null>(null)
const printing = shallowRef<{ stage: WorkStage; orders: Order[] } | null>(null)
async function printStage(column: Column) {
  if (!column.stage) return
  printing.value = { stage: column.stage, orders: cardsOf(column.key) }
  await nextTick()
  requestAnimationFrame(() => window.print())
}

const stop = onOrderEvent(({ order, removedId }) => {
  if (removedId) rows.value = rows.value.filter((row) => row.id !== removedId)
  if (order) rows.value = mergeById(rows.value.filter((row) => row.id !== order.id), order.status === 'canceled' ? [] : [order])
  if (found.value && removedId) found.value = found.value.filter((row) => row.id !== removedId)
  if (found.value && order && found.value.some((row) => row.id === order.id)) found.value = mergeById(found.value.filter((row) => row.id !== order.id), order.status === 'canceled' ? [] : [order])
})
// "Atrasada" and "parada há" follow the clock, like the list.
const clock = setInterval(() => (now.value = new Date()), 60_000)
onMounted(() => {
  void load()
  document.addEventListener('visibilitychange', onVisible)
})
onBeforeUnmount(() => {
  unmounted = true
  stop()
  stopLive?.()
  clearInterval(clock)
  if (refreshTimer) clearInterval(refreshTimer)
  document.removeEventListener('visibilitychange', onVisible)
})
</script>

<template>
  <LoadingState v-if="state === 'loading' || searching" />
  <ErrorState v-else-if="state === 'failed'" :retry="load" />
  <ErrorState v-else-if="searchFailed" :retry="() => runSearch(props.search ?? '')" />
  <div v-else-if="found && !found.some((order) => STATUSES.includes(order.status))" class="empty" data-testid="board-no-match">
    <h2>{{ t('web.orders.noMatch', { query: props.search ?? '' }) }}</h2>
  </div>
  <div v-else class="board-wrap" :class="{ 'has-panel': panel.value.value }">
    <div class="board" data-testid="board" :style="{ '--board-cols': columns.length }">
      <section
        v-for="column in columns"
        :key="column.key"
        class="col"
        :class="{ 'is-over': over === column.key }"
        :aria-labelledby="`col-${column.key}`"
        :data-column="column.key"
        @dragover.prevent="overColumn(column)"
        @dragleave.self="over = null; overIndex = null"
        @drop.prevent="drop(column)"
      >
        <h2 :id="`col-${column.key}`" class="col-head">
          <span class="dot" :class="`dot--${DOT[column.status]}`" aria-hidden="true"></span>{{ columnLabel(column) }}<span class="num">{{ cardsOf(column.key).length }}</span>
          <button
            v-if="column.stage && cardsOf(column.key).length"
            type="button"
            class="icon-btn col-more"
            :data-testid="`column-more-${column.key}`"
            :aria-label="t('web.board.columnMore', { stage: column.stage.name })"
            @click="columnMenu = column"
          >
            <MoreHorizontal :size="16" aria-hidden="true" />
          </button>
        </h2>
        <ul class="col-list" @dragover="dragOverList">
          <li
            v-for="(order, index) in cardsOf(column.key)"
            :key="order.id"
            class="card"
            :class="{ 'is-dragging': dragging === order.id, 'drop-before': column.stage && over === column.key && overIndex === index && dragging !== order.id }"
            :draggable="canDrag(order)"
            :data-order="order.id"
            @dragstart="dragging = order.id"
            @dragend="dragging = null; over = null; overIndex = null"
            @dragover="dragOverCard($event, column, index)"
          >
            <button :id="`card-${order.id}`" type="button" class="card-open" :aria-describedby="`card-${order.id}-state`" @click="panel.open(order.id)" @keydown="onKey($event, order)">
              <span class="card-top"><strong class="who"><span v-if="column.stage" class="num card-place">{{ index + 1 }}</span>{{ order.customer?.name }}</strong><span class="num">{{ order.number }}</span></span>
              <span class="sub">{{ deviceSummary(order) }}</span>
            </button>
            <span :id="`card-${order.id}-state`" class="card-flag" :class="{ 'card-flag--late': lateText(order, now) }">
              {{ lateText(order, now) || (isHeld(order) ? holdText(order, now) : '') || (column.status === 'approved' && suggestedStage(order, stages) ? t('web.board.nextStage', { stage: suggestedStage(order, stages)!.name }) : '') }}
            </span>
            <span v-if="order.showsMoney" class="num card-money" :aria-label="prefs.hideValues ? t('web.money.hiddenA11y') : undefined">{{ shownMoney(remainingOnRow(order) ?? order.total) }}</span>
            <button v-if="canDrag(order)" type="button" class="icon-btn card-move" :aria-label="t('web.board.move', { order: orderShort(), number: order.number ?? '' })" @click="moving = order">
              <MoreHorizontal :size="16" aria-hidden="true" />
            </button>
          </li>
        </ul>
        <p v-if="!cardsOf(column.key).length" class="muted small">{{ t('web.board.emptyColumn') }}</p>
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
    :choices="moveChoices(moving)"
    @pick="(id) => pick(moving as Order, id)"
    @close="moving = null"
  />
  <ChoiceDialog
    v-if="columnMenu?.stage"
    :title="columnMenu.stage.name"
    :sub="t('web.board.printCount', { count: cardsOf(columnMenu.key).length })"
    :choices="[{ id: 'print', label: t('web.board.printStage', { stage: columnMenu.stage.name }) }]"
    @pick="() => { const column = columnMenu as Column; columnMenu = null; void printStage(column) }"
    @close="columnMenu = null"
  />
  <StagePrint v-if="printing" :key="printing.stage.id" :stage="printing.stage" :orders="printing.orders" />
</template>
