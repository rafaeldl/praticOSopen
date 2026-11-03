<script setup lang="ts">
// Início: the order list with the app's filters, search, selection and the
// open order beside it. Firestore for who sees values, the API projection for
// who does not (lib/orders/data.ts). The detail, the board and the batch
// pickers load on demand so the first paint stays inside the budget.
import { computed, defineAsyncComponent, nextTick, onBeforeUnmount, onMounted, ref, shallowRef, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import EmptyState from '@/components/EmptyState.vue'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import StatusLabel from '@/components/StatusLabel.vue'
import { loadOrderTexts, t } from '@/i18n'
import { formatMonthYear } from '@/lib/format'
import { mark } from '@/lib/marks'
import { applyFreshFirstPage, mergeById } from '@/lib/order-list'
import { onFreshFirstPage } from '@/lib/orders-query'
import { onOrderEvent } from '@/lib/orders/bus'
import { ASSIGNED_READS, FIRST_PAGE, companyHasOrders, createListLoader, listContext, type ListLoader } from '@/lib/orders/data'
import {
  canCreateOrders,
  defaultFilter,
  exactFirst,
  deviceSummary,
  filtersFor,
  holdDays,
  isHeld,
  matchesSearch,
  monthGroups,
  normalizeOrder,
  queryStatuses,
  remainingOnRow,
  rowsFor,
  servicesSummary,
  summaryOf,
  type ListFilter,
  type Order,
} from '@/lib/orders/model'
import { country, deviceLabel, holdText, lateText, money, orderShort, statusLine, statusText } from '@/lib/orders/text'
import { useRoutePanel } from '@/lib/route-layer'
import { can, session } from '@/lib/session'
import { registerShortcut } from '@/lib/shortcuts'
import { announce, ui } from '@/lib/ui'

// Each comes with its texts (a second catalog, scripts/gen.mjs).
const OrderDetail = defineAsyncComponent(() => Promise.all([import('@/components/orders/OrderDetail.vue'), loadOrderTexts()]).then(([m]) => m))
const OrderBoard = defineAsyncComponent(() => Promise.all([import('@/components/orders/OrderBoard.vue'), loadOrderTexts()]).then(([m]) => m))
const FirstRun = defineAsyncComponent(() => Promise.all([import('@/components/orders/FirstRun.vue'), loadOrderTexts()]).then(([m]) => m))
const BatchActions = defineAsyncComponent(() => Promise.all([import('@/components/orders/BatchActions.vue'), loadOrderTexts()]).then(([m]) => m))

const route = useRoute()
const router = useRouter()
const panel = useRoutePanel('order')
const ctx = listContext()
const now = ref(new Date())
const filters = filtersFor(session.role, ctx.showsMoney)
const filter = computed<ListFilter>(() => {
  const wanted = route.query.f as ListFilter
  return filters.includes(wanted) ? wanted : defaultFilter(session.role)
})
const board = computed(() => route.query.view === 'board')
const search = ref(typeof route.query.q === 'string' ? route.query.q : '')
const rows = shallowRef<Order[]>([])
const hasMore = ref(false)
const loadingMore = ref(false)
const state = ref<'loading' | 'ready' | 'failed'>('loading')
const stale = ref(false)
const firstRun = ref(false)
const unpaid = ref<{ count: number; amount: number } | null>(null)
let stopSearch: (() => void) | undefined
const selected = ref<string[]>([])
const searchEl = ref<HTMLInputElement | null>(null)
const sentinel = ref<HTMLElement | null>(null)
let loader: ListLoader | null = null
let stopWatch: (() => void) | undefined
let loadToken = 0

const showsMoney = ctx.showsMoney
const canCreate = computed(() => canCreateOrders(session.role, can('createOrder')))
const filterRows = computed(() => rowsFor(filter.value, rows.value, now.value, session.uid))
const visible = computed(() => {
  const query = search.value.trim()
  return query ? exactFirst(filterRows.value.filter((order) => matchesSearch(order, query, statusText(order.status))), query) : filterRows.value
})
const groups = computed(() =>
  filter.value === 'all' && !search.value.trim()
    ? monthGroups(visible.value).map((group) => ({ ...group, title: group.month ? formatMonthYear(group.month, country()) : '' }))
    : [{ key: 'list', title: '', rows: visible.value }],
)
const summary = computed(() => (search.value.trim() ? null : summaryOf(filter.value, filterRows.value, !hasMore.value, now.value)))
const title = computed(() => t(route.name === 'orders' ? 'orders' : 'home'))
/** The answer of the screen, right under the title (home.summary.count). */
const summaryText = computed(() => {
  // While searching, how many were found; in Sem receber, how much the ones found owe (one customer's balance).
  if (search.value.trim()) {
    const found = summaryOf(filter.value, visible.value, true, now.value)
    return found?.kind === 'unpaid' ? t('web.orders.unpaidSummary', { count: found.count, amount: money(found.amount) }) : t('web.orders.count', { count: visible.value.length })
  }
  const value = summary.value
  // Not all open orders loaded (no count yet): the day still opens with what is left to receive.
  if (!value) return filter.value === 'open' && unpaid.value?.amount ? t('web.orders.toReceive', { amount: money(unpaid.value.amount) }) : ''
  if (value.kind === 'open') {
    // The day opens with what is left to receive too (done orders, outside Em aberto).
    const parts = [t('homeOpenCount', { count: value.open }), ...(value.late ? [t('homeLateCount', { count: value.late })] : [])]
    if (unpaid.value?.amount) parts.push(t('web.orders.toReceive', { amount: money(unpaid.value.amount) }))
    return parts.join(' · ')
  }
  if (value.kind === 'quotes') return t('homeQuotesWaiting', { count: value.count })
  if (value.kind === 'onHold') return t('homeOnHoldCount', { count: value.count })
  if (value.kind === 'unpaid') return t('web.orders.unpaidSummary', { count: value.count, amount: money(value.amount) })
  return value.today ? t('homeWithYouToday', { count: value.count }) : t('homeWithYou', { count: value.count })
})
const searchHint = computed(() => t('homeSearchHintDevice', { device: deviceLabel().toLocaleLowerCase() }))
const panelOpen = computed(() => !!panel.value.value)
const selectedOrders = computed(() => selected.value.map((id) => rows.value.find((row) => row.id === id)).filter((row): row is Order => !!row))

const FILTER_LABEL: Record<ListFilter, () => string> = {
  open: () => t('filterOpen'),
  late: () => t('web.orders.filterLate'),
  today: () => t('web.orders.filterToday'),
  unpaid: () => t('web.orders.filterUnpaid'),
  quotes: () => t('filterQuotes'),
  onHold: () => t('filterOnHold'),
  mine: () => t('filterMine'),
  done: () => t('filterDone'),
  all: () => t('filterAll'),
}
const EMPTY_TITLE: Record<ListFilter, () => string> = {
  open: () => t('noOpenOrders'),
  late: () => t('web.orders.noLate'),
  today: () => t('web.orders.noToday'),
  unpaid: () => t('web.orders.noUnpaid'),
  quotes: () => t('noQuotesWaiting'),
  onHold: () => t('noOrdersOnHold'),
  mine: () => t('noOrdersWithYou'),
  done: () => t('noOrdersInView'),
  all: () => t('noOrdersInView'),
}

function setQuery(patch: Record<string, string | undefined>) {
  const query = { ...route.query, ...patch }
  for (const key of Object.keys(patch)) if (patch[key] === undefined) delete query[key]
  void router.replace({ query })
}

async function load() {
  const token = ++loadToken
  state.value = 'loading'
  stale.value = false
  firstRun.value = false
  stopWatch?.()
  stopWatch = undefined
  // Minhas by assignedTo once #514 is in (ASSIGNED_READS); until then the orders the technician created.
  const assigned = ASSIGNED_READS && filter.value === 'mine' ? (session.uid as string) : undefined
  loader = createListLoader(ctx, queryStatuses(board.value ? 'all' : filter.value), assigned)
  try {
    const page = await loader.first()
    if (token !== loadToken) return
    rows.value = page.rows
    hasMore.value = page.hasMore
    state.value = 'ready'
    await nextTick()
    requestAnimationFrame(() => mark('list-visible'))
    announce(t('web.orders.count', { count: visible.value.length }))
    // "Primeira vez" only when the company never created an order (home.empty.first-run).
    if (!rows.value.length && (filter.value === 'all' || filter.value === 'open' || filter.value === 'mine')) {
      firstRun.value = !(await companyHasOrders(ctx))
    }
    // After the paint: Sem receber count, ⌘K search and the lists of Nova OS (list-extras.ts).
    void import('@/lib/orders/list-extras').then((extras) => {
      if (token !== loadToken) return
      if (showsMoney) void extras.unpaidTotals(ctx).then((totals) => (unpaid.value = totals))
      stopSearch?.()
      stopSearch = extras.paletteSearch(() => rows.value, (id) => void panel.open(id), (name) => {
        search.value = name
        choose('all')
      })
      if (canCreate.value) {
        if ('requestIdleCallback' in window) requestIdleCallback(extras.warmLists, { timeout: 3000 })
        else setTimeout(extras.warmLists, 1500)
      }
    })
    // Live first rows: another person's change shows without reloading.
    stopWatch = await loader.watch(
      FIRST_PAGE,
      (fresh) => {
        if (token === loadToken) rows.value = applyFreshFirstPage(rows.value, fresh, FIRST_PAGE)
      },
      (error) => console.warn('orders: live list stopped', error),
    )
    if (token !== loadToken) stopWatch()
  } catch (error) {
    console.error('orders: list failed', error)
    if (token === loadToken) state.value = 'failed'
  }
}

async function loadMore() {
  if (!loader || loadingMore.value || !hasMore.value) return
  loadingMore.value = true
  const token = loadToken
  try {
    const page = await loader.more()
    if (token !== loadToken) return
    rows.value = mergeById(rows.value, page.rows)
    hasMore.value = page.hasMore
    if (page.stale) stale.value = true
  } catch (error) {
    console.warn('orders: next page failed', error)
    stale.value = true
  } finally {
    loadingMore.value = false
  }
}

/** "Buscar nas mais antigas": the number straight from the server, then older pages. */
async function searchOlder() {
  const number = Number(search.value.trim())
  if (loader && Number.isInteger(number) && number > 0) {
    const found = await loader.byNumber(number).catch(() => [])
    if (found.length) {
      rows.value = mergeById(rows.value, found)
      return
    }
  }
  await loadMore()
}

function choose(next: ListFilter) {
  selected.value = []
  setQuery({ f: next === defaultFilter(session.role) ? undefined : next })
}

function setView(view: 'list' | 'board') {
  setQuery({ view: view === 'board' ? 'board' : undefined })
}

/** Closing the open order puts the focus back on its row (never on the page body, where a typed "n" would open Nova OS). */
function closePanel() {
  const id = panel.value.value
  panel.close()
  void nextTick(() => setTimeout(() => (document.querySelector(`#row-${CSS.escape(id ?? '')} .row-btn`) as HTMLElement | null)?.focus(), 0))
}

function open(order: Order) {
  void panel.open(order.id)
}

function toggle(order: Order) {
  const index = selected.value.indexOf(order.id)
  selected.value = index >= 0 ? selected.value.filter((id) => id !== order.id) : [...selected.value, order.id]
  announce(t('web.orders.selected', { count: selected.value.length }))
}

function move(step: number) {
  const list = visible.value
  if (!list.length) return
  const index = list.findIndex((order) => order.id === panel.value.value)
  const next = list[Math.max(0, Math.min(list.length - 1, index < 0 ? 0 : index + step))]
  if (!next) return
  void panel.open(next.id)
  void nextTick(() => document.getElementById(`row-${next.id}`)?.scrollIntoView({ block: 'nearest' }))
}

function onKeys(event: KeyboardEvent) {
  if (ui.layers || event.altKey || event.ctrlKey || event.metaKey || board.value) return
  const target = event.target as HTMLElement
  if (target.matches('input, textarea, select, [contenteditable]')) {
    if (event.key === 'Escape' && target === searchEl.value && search.value) {
      search.value = ''
      target.blur()
    } else if (event.key === 'ArrowDown' && target === searchEl.value) {
      event.preventDefault()
      target.blur()
      move(0)
    }
    return
  }
  // Keys inside the open order belong to it.
  if (target.closest('.panel')) return
  const key = event.key
  if (key === 'j' || key === 'ArrowDown') {
    event.preventDefault()
    move(1)
  } else if (key === 'k' || key === 'ArrowUp') {
    event.preventDefault()
    move(-1)
  } else if (key === '/') {
    event.preventDefault()
    searchEl.value?.focus()
  } else if (key === ' ' && !target.matches('button, a, label')) {
    const order = visible.value.find((row) => row.id === panel.value.value)
    if (order) {
      event.preventDefault()
      toggle(order)
    }
  } else if (key === 'Enter' && !target.matches('button, a')) {
    const focusable = document.querySelector<HTMLElement>('[data-od-focus]')
    if (focusable) {
      event.preventDefault()
      focusable.focus()
    }
  } else if (key === 'Escape') {
    if (selected.value.length) selected.value = []
    else if (panelOpen.value) closePanel()
  }
}

let typing: ReturnType<typeof setTimeout> | undefined
watch(search, (text) => {
  clearTimeout(typing)
  typing = setTimeout(() => {
    setQuery({ q: text.trim() || undefined })
    if (text.trim()) announce(t('web.orders.count', { count: visible.value.length }))
    // A number typed and not among the loaded rows: ask for it, so the exact one still comes first.
    const number = Number(text.trim())
    if (loader && Number.isInteger(number) && number > 0 && !rows.value.some((row) => row.number === number)) {
      const token = loadToken
      void loader.byNumber(number).then((found) => {
        if (token === loadToken && found.length) rows.value = mergeById(rows.value, found)
      }).catch(() => {})
    }
  }, 250)
})
watch(() => [filter.value, board.value, session.companyId], () => void load())
watch(
  () => route.query.q,
  (q) => {
    if ((q ?? '') !== search.value.trim()) search.value = typeof q === 'string' ? q : ''
  },
)

// Shown from this browser's copy: replace the first page when the server answers.
onFreshFirstPage((result) => {
  if (result.failed) stale.value = true
  else rows.value = applyFreshFirstPage(rows.value, result.rows.map((row) => normalizeOrder(row.id, row, ctx.showsMoney)), FIRST_PAGE)
})

const stopBus = onOrderEvent(({ order, removedId, createdId }) => {
  // Firestore's live rows bring a new order by themselves; the API list is read again.
  if (createdId && !ctx.showsMoney) void load()
  if (removedId) rows.value = rows.value.filter((row) => row.id !== removedId)
  if (order) {
    const current = rows.value.find((row) => row.id === order.id)
    // A list row of the API has no lines: keep what the row had when the update has none.
    const merged = current && !order.hasLines ? { ...order, lines: current.lines, hasLines: current.hasLines } : order
    rows.value = mergeById(rows.value, [merged])
  }
})

let observer: IntersectionObserver | undefined
const clock = setInterval(() => (now.value = new Date()), 60_000)
const removers: (() => void)[] = []
onMounted(() => {
  void load()
  window.addEventListener('keydown', onKeys)
  removers.push(registerShortcut({ keys: '/', label: 'web.shortcuts.filter', run: () => searchEl.value?.focus() }))
  // Infinite scroll: more rows before the end shows (home.list.load-more).
  observer = new IntersectionObserver((entries) => entries.some((entry) => entry.isIntersecting) && void loadMore(), { rootMargin: '200px' })
  watch(sentinel, (element, old) => {
    if (old) observer?.unobserve(old)
    if (element) observer?.observe(element)
  }, { immediate: true })
})
onBeforeUnmount(() => {
  loadToken++
  stopWatch?.()
  stopBus()
  observer?.disconnect()
  clearInterval(clock)
  window.removeEventListener('keydown', onKeys)
  removers.forEach((remove) => remove())
  stopSearch?.()
  onFreshFirstPage(undefined)
})

const rowDetail = (order: Order) => [deviceSummary(order), servicesSummary(order)].filter(Boolean).join(' · ')
</script>

<template>
  <header class="page-head">
    <div>
      <h1 class="page-title" tabindex="-1" data-page-title>{{ title }}</h1>
      <!-- Always there on the list: the sentence arrives after the rows (what is left to receive) and must not push the screen down. -->
      <p v-if="!board" class="page-sub page-answer" data-testid="summary">{{ summaryText }}</p>
    </div>
    <div class="tabs" role="group" :aria-label="t('web.orders.viewAs')">
      <button type="button" :aria-pressed="!board" @click="setView('list')">{{ t('web.orders.list') }}</button>
      <button type="button" :aria-pressed="board" @click="setView('board')">{{ t('web.orders.board') }}</button>
    </div>
    <button
      v-if="canCreate && !selected.length"
      type="button"
      class="btn hide-phone"
      :class="{ 'btn--primary': !panelOpen }"
      data-testid="new-order"
      @click="ui.newOrder = true"
    >
      {{ t('newOrderButton') }} <kbd>N</kbd>
    </button>
  </header>

  <OrderBoard v-if="board" />
  <template v-else>
    <div class="toolbar">
      <BatchActions v-if="selected.length" :orders="selectedOrders" @done="selected = []" />
      <template v-else>
        <div class="chips" role="group" :aria-label="t('web.orders.filters')">
          <button
            v-for="item in filters"
            :key="item"
            type="button"
            class="chip"
            :aria-pressed="filter === item"
            @click="choose(item)"
          >
            {{ FILTER_LABEL[item]() }}<span v-if="item === 'unpaid' && unpaid?.count" class="num"> {{ unpaid.count }}</span>
          </button>
        </div>
        <span class="spacer"></span>
        <label class="sr" for="orders-search">{{ searchHint }}</label>
        <input
          id="orders-search"
          ref="searchEl"
          v-model="search"
          class="field search-mini"
          type="search"
          autocomplete="off"
          :placeholder="searchHint"
        />
      </template>
    </div>

    <div class="workspace" :class="{ 'has-panel': panelOpen }">
      <div class="list-pane">
        <p v-if="stale && state === 'ready'" class="offline" role="alert">
          {{ t('web.orders.stale') }}
          <button type="button" class="link" @click="load">{{ t('web.tryAgain') }}</button>
        </p>
        <LoadingState v-if="state === 'loading'" />
        <ErrorState v-else-if="state === 'failed'" :body="t('loadOrdersError')" :retry="load" />
        <FirstRun v-else-if="firstRun" :can-create="canCreate" />
        <div v-else-if="!visible.length && search.trim()" class="empty">
          <h2>{{ t('web.orders.noMatch', { query: search.trim() }) }}</h2>
          <p>{{ hasMore ? t('searchNotFoundLoaded') : t('web.orders.noMatchHint', { device: deviceLabel().toLocaleLowerCase() }) }}</p>
          <div class="row-actions">
            <button v-if="hasMore" type="button" class="btn" :disabled="loadingMore" @click="searchOlder">{{ t('searchOlder') }}</button>
            <button v-if="filter !== 'all'" type="button" class="btn" @click="choose('all')">{{ t('web.orders.searchAll') }}</button>
            <button type="button" class="btn btn--ghost" @click="search = ''">{{ t('web.orders.clearSearch') }}</button>
          </div>
        </div>
        <EmptyState v-else-if="!visible.length" :title="EMPTY_TITLE[filter]()" data-testid="orders-empty">
          <button v-if="filter === 'open' || filter === 'mine'" type="button" class="btn" @click="choose('all')">{{ t('seeAllOrders') }}</button>
        </EmptyState>
        <table v-else class="grid" data-testid="orders-table">
          <caption class="sr">{{ FILTER_LABEL[filter]() }}</caption>
          <thead>
            <tr>
              <th class="c-check" scope="col"><span class="sr">{{ t('web.orders.select') }}</span></th>
              <th class="c-num" scope="col">{{ t('web.orders.number') }}</th>
              <th scope="col">{{ t('customer') }}</th>
              <th scope="col">{{ t('orderStatusLabel') }}</th>
              <th v-if="showsMoney" class="c-money" scope="col">{{ t('total') }}</th>
            </tr>
          </thead>
          <tbody v-for="group in groups" :key="group.key">
            <tr v-if="group.title" class="group-row no-click">
              <th :colspan="showsMoney ? 5 : 4" scope="rowgroup">{{ group.title }}</th>
            </tr>
            <tr
              v-for="order in group.rows"
              :id="`row-${order.id}`"
              :key="order.id"
              :class="{ 'is-open': order.id === panel.value.value, 'is-selected': selected.includes(order.id) }"
              :data-order="order.id"
              @click="open(order)"
            >
              <td class="c-check" @click.stop>
                <input
                  class="check"
                  type="checkbox"
                  :checked="selected.includes(order.id)"
                  :aria-label="t('web.orders.selectOrder', { order: orderShort(), number: order.number ?? '' })"
                  @change="toggle(order)"
                />
              </td>
              <td class="c-num"><span class="num">{{ order.number }}</span></td>
              <td>
                <button type="button" class="row-btn who" @click.stop="open(order)">
                  {{ order.customer?.name || t('web.orders.noCustomer') }}
                </button>
                <span v-if="rowDetail(order)" class="sub row-detail">{{ rowDetail(order) }}</span>
              </td>
              <td>
                <StatusLabel :status="order.status" :late-text="lateText(order, now)" :held="isHeld(order)" :text="statusLine(order)" />
                <span v-if="isHeld(order) && holdDays(order, now) !== null" class="sub row-hold">{{ holdText(order, now) }}</span>
              </td>
              <td v-if="showsMoney" class="c-money">
                <span class="num">{{ money(order.total) }}</span>
                <span v-if="remainingOnRow(order)" class="owed">{{ t('web.orders.owed', { amount: money(remainingOnRow(order)) }) }}</span>
              </td>
            </tr>
          </tbody>
        </table>
        <div v-if="state === 'ready' && hasMore && visible.length" ref="sentinel" class="more-rows">
          <button type="button" class="btn btn--ghost" :disabled="loadingMore" @click="loadMore">
            {{ loadingMore ? t('web.loading') : t('web.orders.loadMore') }}
          </button>
        </div>
      </div>
      <aside v-if="panelOpen" class="panel" :aria-label="t('web.orders.panel')">
        <OrderDetail :key="panel.value.value ?? ''" :order-id="panel.value.value as string" @close="closePanel" />
      </aside>
    </div>
  </template>
</template>
