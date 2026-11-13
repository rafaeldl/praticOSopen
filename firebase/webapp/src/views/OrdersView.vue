<script setup lang="ts">
// Início: the order list with the app's filters, search, selection and the
// open order beside it. Firestore for who sees values, the API projection for
// who does not (lib/orders/data.ts). The detail, the board and the batch
// pickers load on demand so the first paint stays inside the budget.
import { computed, defineAsyncComponent, nextTick, onBeforeUnmount, onMounted, ref, shallowRef, watch } from 'vue'
import { showPlanFeatureNotice, usePlanFeature } from '@/lib/plan-feature-gate'
import { PLAN_NAME } from '@/lib/plan-limits'
import { useRoute, useRouter } from 'vue-router'
import { Bell, Eye, EyeOff, Tv } from '@lucide/vue'
import EmptyState from '@/components/EmptyState.vue'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import StatusLabel from '@/components/StatusLabel.vue'
import { loadOrderTexts, t } from '@/i18n'
import { formatMonthYear, formatTime } from '@/lib/format'
import { mark } from '@/lib/marks'
import { applyFreshFirstPage, compareBy, compareRows, mergeById, type RowCompare } from '@/lib/order-list'
import { onOrderEvent } from '@/lib/orders/bus'
import { FIRST_PAGE, companyHasOrders, createFilterLoader, createListLoader, listContext, type ListLoader } from '@/lib/orders/data'
import {
  canCreateOrders,
  defaultFilter,
  exactFirst,
  deviceSummary,
  filtersFor,
  holdDays,
  isHeld,
  matchesFilter,
  matchesSearch,
  monthGroups,
  nextVisit,
  queryStatuses,
  sameDay,
  paymentOnRow,
  rowsFor,
  servicesSummary,
  summaryFromCounts,
  summaryOf,
  type FilterCounts,
  type ListFilter,
  type Order,
} from '@/lib/orders/model'
import { watchListEnd } from '@/lib/orders/list-end'
import { country, deviceLabel, holdText, lateText, orderShort, shownMoney as money, statusLine, statusText, whenCell } from '@/lib/orders/text'
import { prefs } from '@/lib/prefs'
import { useRoutePanel } from '@/lib/route-layer'
import { can, session } from '@/lib/session'
import { stageNameOf, workStages } from '@/lib/orders/stages'
import { registerShortcut } from '@/lib/shortcuts'
import { announce, ui } from '@/lib/ui'

// Each comes with its texts (a second catalog, scripts/gen.mjs).
const OrderDetail = defineAsyncComponent(() => Promise.all([import('@/components/orders/OrderDetail.vue'), loadOrderTexts()]).then(([m]) => m))
const OrderBoard = defineAsyncComponent(() => Promise.all([import('@/components/orders/OrderBoard.vue'), loadOrderTexts()]).then(([m]) => m))
const FirstRun = defineAsyncComponent(() => Promise.all([import('@/components/orders/FirstRun.vue'), loadOrderTexts()]).then(([m]) => m))
// "Manutenções chegando": read after the list paints, only on the open lists (home.maintenance.list).
const Maintenances = defineAsyncComponent(() => Promise.all([import('@/components/orders/Maintenances.vue'), loadOrderTexts()]).then(([m]) => m))
// The assistant's presentation, once per browser (order.ai.intro).
const AiIntro = defineAsyncComponent(() => Promise.all([import('@/components/orders/AiIntro.vue'), loadOrderTexts()]).then(([m]) => m))
const aiIntro = ref(false)
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
/** The search as it is in the URL (after the pause in typing): what the board asks the server. */
const searchQuery = computed(() => (typeof route.query.q === 'string' ? route.query.q.trim() : ''))
const rows = shallowRef<Order[]>([])
const hasMore = ref(false)
const loadingMore = ref(false)
const state = ref<'loading' | 'ready' | 'failed'>('loading')
/** The next page did not come: 'offline' (no connection, the loaded rows stay) or 'failed' (the query itself). */
const moreError = ref<'offline' | 'failed' | null>(null)
const firstRun = ref(false)
const unpaid = ref<{ count: number; amount: number } | null>(null)
/** The server's count of the filter (home.summary.count): never what happens to be loaded. */
const counts = ref<FilterCounts | null>(null)
/** The order of the filter's query, so pages and live rows join without skipping one. */
let compare: RowCompare<Order> = compareRows
/** New notices of this person (home.notifications.badge); read after the list paints. */
const unread = ref(0)
let stopSearch: (() => void) | undefined
const selected = ref<string[]>([])
const tvMode = usePlanFeature('tvMode')
const searchEl = ref<HTMLInputElement | null>(null)
const sentinel = ref<HTMLElement | null>(null)
let loader: ListLoader | null = null
let stopWatch: (() => void) | undefined
let loadToken = 0

const showsMoney = ctx.showsMoney
const canCreate = computed(() => canCreateOrders(session.role, can('createOrder')))
const filterRows = computed(() => rowsFor(filter.value, rows.value, now.value, session.uid))
/** "Agora" of the technician in Minhas, never while searching (home.next.card). */
const agora = computed(() => (filter.value === 'mine' && !search.value.trim() && state.value === 'ready' ? nextVisit(rows.value, now.value, session.uid) : null))
const visible = computed(() => {
  const query = search.value.trim()
  if (query) return exactFirst(filterRows.value.filter((order) => matchesSearch(order, query, statusText(order.status))), query)
  // The visit of "Agora" is not repeated in the list.
  return agora.value ? filterRows.value.filter((order) => order.id !== agora.value?.id) : filterRows.value
})
/** "Próximo: Ana, Gol, às 14:00." with the first name and, when the segment shows it, the device. */
const agoraText = computed(() => {
  const order = agora.value
  if (!order) return ''
  const customer = (order.customer?.name ?? '').trim().split(/\s+/)[0] ?? ''
  const time = formatTime(order.scheduledDate, country())
  const device = deviceSummary(order)
  return device ? t('nextVisitDevice', { customer, device, time }) : t('nextVisit', { customer, time })
})
const visitTime = (order: Order) => (filter.value === 'mine' && sameDay(order.scheduledDate, now.value) ? formatTime(order.scheduledDate, country()) : '')
const groups = computed(() =>
  filter.value === 'all' && !search.value.trim()
    ? monthGroups(visible.value).map((group) => ({ ...group, title: group.month ? formatMonthYear(group.month, country()) : '' }))
    : [{ key: 'list', title: '', rows: visible.value }],
)
const summary = computed(() => (search.value.trim() ? null : summaryFromCounts(filter.value, counts.value, filterRows.value, !hasMore.value, now.value)))
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
/** The hint does not fit the box (phone, text at 200%): the box says only "Buscar"; the label keeps the whole hint. */
const searchShort = ref(false)
let measure: CanvasRenderingContext2D | null = null
function fitSearch() {
  const el = searchEl.value
  if (!el || !el.clientWidth) return
  const style = getComputedStyle(el)
  measure ??= document.createElement('canvas').getContext('2d')
  if (!measure) return
  measure.font = style.font
  const room = el.clientWidth - parseFloat(style.paddingLeft) - parseFloat(style.paddingRight)
  // A little room for the clear button of type="search".
  searchShort.value = measure.measureText(searchHint.value).width > room - 4
}
let searchResize: ResizeObserver | undefined
const panelOpen = computed(() => !!panel.value.value)
const showsMaintenances = computed(() => state.value === 'ready' && !search.value.trim() && ['open', 'mine', 'quotes', 'onHold'].includes(filter.value))
const selectedOrders = computed(() => selected.value.map((id) => rows.value.find((row) => row.id === id)).filter((row): row is Order => !!row))

const FILTER_LABEL: Record<ListFilter, () => string> = {
  open: () => t('filterOpen'),
  late: () => t('web.orders.filterLate'),
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
  unpaid: () => t('web.orders.noUnpaid'),
  quotes: () => t('noQuotesWaiting'),
  onHold: () => t('noOrdersOnHold'),
  mine: () => t('noOrdersWithYou'),
  done: () => t('noOrdersInView'),
  all: () => t('noOrdersInView'),
}

/** An order found or changed on this screen, outside the pages: only shown if it belongs to the filter. */
const inFilter = (order: Order) => board.value || matchesFilter(filter.value, order, now.value, session.uid)

let recountTimer: ReturnType<typeof setTimeout> | undefined
/** After a change on screen: the server counts the filter again (and Sem receber). */
function recount() {
  clearTimeout(recountTimer)
  const token = loadToken
  recountTimer = setTimeout(() => {
    void import('@/lib/orders/list-extras').then((extras) => {
      if (token !== loadToken) return
      if (showsMoney) void extras.unpaidTotals(ctx).then((totals) => token === loadToken && (unpaid.value = totals))
      void extras.filterCounts(ctx, filter.value, now.value).then((found) => token === loadToken && (counts.value = found))
    })
  }, 400)
}

function setQuery(patch: Record<string, string | undefined>) {
  const query = { ...route.query, ...patch }
  for (const key of Object.keys(patch)) if (patch[key] === undefined) delete query[key]
  void router.replace({ query })
}

async function load() {
  const token = ++loadToken
  state.value = 'loading'
  moreError.value = null
  firstRun.value = false
  stopWatch?.()
  stopWatch = undefined
  counts.value = null
  // Each filter is its own server query (home.filter.*): what shows is never filtered from what was loaded.
  loader = board.value ? createListLoader(ctx, queryStatuses('all')) : createFilterLoader(ctx, filter.value, now.value)
  const order = loader.query.order
  compare = order ? compareBy<Order>(order.field, order.dir) : compareRows
  try {
    const page = await loader.first()
    if (token !== loadToken) return
    rows.value = [...page.rows].sort(compare)
    hasMore.value = page.hasMore
    state.value = 'ready'
    await nextTick()
    requestAnimationFrame(() => mark('list-visible'))
    announce(t('web.orders.count', { count: visible.value.length }))
    // "Primeira vez" only when the company never created an order (home.empty.first-run).
    if (!rows.value.length && (filter.value === 'all' || filter.value === 'open' || filter.value === 'mine')) {
      firstRun.value = !(await companyHasOrders(ctx))
    }
    // After the paint: the assistant's presentation, only for who opens Nova OS (order.ai.intro).
    if (canCreate.value && !aiIntro.value) {
      void Promise.all([import('@/lib/orders/ai-intro'), import('@/lib/orders/assistant')])
        .then(([intro, assistant]) =>
          intro.shouldShowAiIntro(
            () => token === loadToken && route.path === '/' && ui.layers === 0 && !ui.newOrder,
            async () => (await assistant.assistStatus()).enabled,
          ),
        )
        .then((show) => show && (aiIntro.value = true))
        .catch(() => {})
    }
    // After the paint: the bell's count (lib/notifications, its own chunk).
    void import('@/lib/notifications')
      .then((notices) => notices.unreadCount())
      .then((count) => token === loadToken && (unread.value = count))
      .catch((error) => console.warn('orders: notices not counted', error))
    // After the paint: Sem receber count, ⌘K search and the lists of Nova OS (list-extras.ts).
    void import('@/lib/orders/list-extras').then((extras) => {
      if (token !== loadToken) return
      if (showsMoney) void extras.unpaidTotals(ctx).then((totals) => token === loadToken && (unpaid.value = totals))
      void extras.filterCounts(ctx, filter.value, now.value).then((found) => token === loadToken && (counts.value = found))
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
        if (token === loadToken) rows.value = applyFreshFirstPage(rows.value, fresh, FIRST_PAGE, compare)
      },
      (error) => console.warn('orders: live list stopped', error),
    )
    if (token !== loadToken) stopWatch()
  } catch (error) {
    console.error('orders: list failed', error)
    if (token === loadToken) state.value = 'failed'
  }
}

const isOffline = (error: unknown) => !navigator.onLine || (error as { code?: string } | null)?.code === 'unavailable'

/** "Tentar de novo" of the next page: the same query asked again (not the cache). */
function retryMore() {
  if (loadingMore.value) return
  moreError.value = null
  // A page came: the infinite scroll looks at the end again (the observer only fires on a change).
  void loadMore().then((loaded) => loaded && observer?.watch(sentinel.value ?? null))
}

/** True when a page came (the infinite scroll then looks at the end of the list again). */
async function loadMore(): Promise<boolean> {
  if (!loader || loadingMore.value || !hasMore.value) return false
  loadingMore.value = true
  const token = loadToken
  try {
    const page = await loader.more()
    if (token !== loadToken) return false
    rows.value = mergeById(rows.value, page.rows, compare)
    hasMore.value = page.hasMore
    moreError.value = null
    return true
  } catch (error) {
    console.warn('orders: next page failed', error)
    // "Sem conexão" only when there is none; a refused query is an error that says so.
    if (token === loadToken) moreError.value = isOffline(error) ? 'offline' : 'failed'
    return false
  } finally {
    // A filter that shows few rows (Paradas) keeps the end in view: watchListEnd looks again after each page.
    loadingMore.value = false
  }
}

/** "Buscar nas mais antigas": the number straight from the server, then older pages. */
async function searchOlder() {
  const number = Number(search.value.trim())
  if (loader && Number.isInteger(number) && number > 0) {
    const found = (await loader.byNumber(number).catch(() => [])).filter(inFilter)
    if (found.length) {
      rows.value = mergeById(rows.value, found, compare)
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
    // The same server search as the board (number, customer, vehicle): an order of the
    // filter that is not among the loaded pages still shows (lib/orders/search.ts).
    if (!board.value && text.trim()) {
      const token = loadToken
      void import('@/lib/orders/search')
        .then((module) => module.searchOrders(ctx, text))
        .then((found) => {
          const kept = found.filter(inFilter)
          if (token === loadToken && kept.length) rows.value = mergeById(rows.value, kept, compare)
        })
        .catch((error) => console.warn('orders: search not asked', error))
    }
  }, 250)
})
watch(() => [filter.value, board.value, session.companyId], () => void load())
// A notification arrived with the page on screen (lib/push): the bell counts again.
watch(
  () => ui.noticesChanged,
  () =>
    void import('@/lib/notifications')
      .then((notices) => notices.unreadCount())
      .then((count) => (unread.value = count))
      .catch((error) => console.warn('orders: notices not counted', error)),
)
watch(
  () => route.query.q,
  (q) => {
    if ((q ?? '') !== search.value.trim()) search.value = typeof q === 'string' ? q : ''
  },
)

const stopBus = onOrderEvent(({ order, removedId, createdId }) => {
  // Firestore's live rows bring a new order by themselves; the API list is read again.
  if (createdId && !ctx.showsMoney) void load()
  if (removedId) rows.value = rows.value.filter((row) => row.id !== removedId)
  if (order) {
    const current = rows.value.find((row) => row.id === order.id)
    // A list row of the API has no lines: keep what the row had when the update has none.
    const merged = current && !order.hasLines ? { ...order, lines: current.lines, hasLines: current.hasLines } : order
    // Changed here and out of the filter now (approved in Orçamentos, received in Sem receber): it leaves the list.
    rows.value = inFilter(merged) ? mergeById(rows.value, [merged], compare) : rows.value.filter((row) => row.id !== merged.id)
  }
  if (order || removedId || createdId) recount()
})

/**
 * On a phone the filters are one row that scrolls sideways (home.filter.scroll):
 * the chosen one is brought into view, also when it comes from the URL.
 */
function showChosenFilter() {
  const row = document.querySelector<HTMLElement>('.toolbar .chips')
  const chosen = row?.querySelector<HTMLElement>('[aria-pressed="true"]')
  if (!row || !chosen || row.scrollWidth <= row.clientWidth) return
  const left = chosen.getBoundingClientRect().left - row.getBoundingClientRect().left + row.scrollLeft
  if (left < row.scrollLeft || left + chosen.offsetWidth > row.scrollLeft + row.clientWidth) row.scrollLeft = Math.max(0, left - 16)
}
watch(filter, () => void nextTick(showChosenFilter))

let observer: ReturnType<typeof watchListEnd> | undefined
const clock = setInterval(() => (now.value = new Date()), 60_000)
const removers: (() => void)[] = []
onMounted(() => {
  void load()
  void nextTick(showChosenFilter)
  window.addEventListener('keydown', onKeys)
  removers.push(registerShortcut({ keys: '/', label: 'web.shortcuts.filter', run: () => searchEl.value?.focus() }))
  // Infinite scroll: more rows before the end shows (home.list.load-more).
  observer = watchListEnd(loadMore)
  watch(sentinel, (element) => observer?.watch(element), { immediate: true })
  // The search box changes size with the window and the text size; the hint is fitted again each time.
  if ('ResizeObserver' in window) searchResize = new ResizeObserver(() => fitSearch())
  watch(
    searchEl,
    (element, previous) => {
      if (previous) searchResize?.unobserve(previous)
      if (element) searchResize?.observe(element)
      fitSearch()
    },
    { immediate: true },
  )
  watch(searchHint, () => void nextTick(fitSearch))
  // Measured in the page's font: again once the web font is in (a fallback font is wider).
  document.fonts?.addEventListener?.('loadingdone', fitSearch)
  void document.fonts?.ready.then(fitSearch)
})
onBeforeUnmount(() => {
  loadToken++
  clearTimeout(recountTimer)
  stopWatch?.()
  stopBus()
  observer?.disconnect()
  clearInterval(clock)
  window.removeEventListener('keydown', onKeys)
  removers.forEach((remove) => remove())
  searchResize?.disconnect()
  document.fonts?.removeEventListener?.('loadingdone', fitSearch)
  stopSearch?.()
})

// The plate (or serial) after the device's name: the user tests looked for it on the row (P3 17 of #515).
const plateOf = (order: Order) => (order.devices[0]?.name && order.devices[0]?.serial ? order.devices[0].serial : '')
const rowDetail = (order: Order) => [deviceSummary(order), servicesSummary(order)].filter(Boolean).join(' · ')
// Below 64rem of list the row keeps its short form: the dates go after the status and the plate stays out.
const rowDates = (order: Order) => (lateText(order, now.value) ? '' : statusLine(order).slice(statusText(order.status).length))
// "Quando" is its own column when the list is 64rem wide or more (a container query in
// orders.css, so text at 200% counts); below it the dates stay in the status line.
const columns = 5 + (showsMoney ? 1 : 0)
</script>

<template>
  <header class="page-head home-head">
    <div>
      <h1 class="page-title" tabindex="-1" data-page-title>{{ title }}</h1>
      <!-- Always there: the sentence arrives after the rows (what is left to receive) and must not push the screen down;
           on the board it stays empty, so the toolbar and its search sit where they sit on the list. -->
      <p class="page-sub page-answer" data-testid="summary" :aria-hidden="board || undefined">{{ board ? '' : summaryText }}</p>
    </div>
    <!-- One row, the same place in Lista and Quadro: the search lives below, in the toolbar, and never moves these. -->
    <div class="head-actions">
    <RouterLink class="btn btn--ghost bell" to="/notifications" data-testid="bell">
      <Bell :size="18" aria-hidden="true" />
      <span class="sr">{{ unread ? t('notificationsA11y', { count: unread }) : t('noticesTitle') }}</span>
      <span v-if="unread" class="bell-count num" aria-hidden="true" data-testid="bell-count">{{ unread > 99 ? '99+' : unread }}</span>
    </RouterLink>
    <!-- The eye of bank apps: values as "R$ •••" in this browser (a TV in the shop). Only on screen, not a permission. -->
    <button
      v-if="showsMoney"
      type="button"
      class="btn btn--ghost eye"
      :aria-pressed="prefs.hideValues"
      data-testid="hide-values"
      :title="prefs.hideValues ? t('web.money.show') : t('web.money.hide')"
      @click="prefs.hideValues = !prefs.hideValues"
    >
      <EyeOff v-if="prefs.hideValues" :size="18" aria-hidden="true" />
      <Eye v-else :size="18" aria-hidden="true" />
      <span class="sr">{{ t('web.money.hide') }}</span>
    </button>
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
    </div>
  </header>

  <div class="toolbar home-bar" :class="{ 'board-bar': board }">
    <p v-if="board" class="board-hint sub">{{ t(workStages().length ? 'web.board.hintStages' : 'web.board.hint') }}</p>
    <!-- Modo TV (#627): the same board alone, big and live, for a screen in the shop. -->
    <!-- Plan (#724): without tvMode (Pro) the button opens the plan notice instead. -->
    <RouterLink v-if="board && can('viewAllOrders') && tvMode.allowed" class="btn btn--ghost tv-open hide-phone" to="/tv" data-testid="open-tv">
      <Tv :size="18" aria-hidden="true" /> {{ t('web.tv.open') }}
    </RouterLink>
    <button v-else-if="board && can('viewAllOrders')" type="button" class="btn btn--ghost tv-open hide-phone" data-testid="open-tv" @click="showPlanFeatureNotice('tvMode', tvMode.requiredPlan)">
      <Tv :size="18" aria-hidden="true" /> {{ t('web.tv.open') }} <span class="plan-badge">{{ t('planFeatureBadge', { plan: PLAN_NAME[tvMode.requiredPlan ?? 'pro'] }) }}</span>
    </button>
    <BatchActions v-else-if="selected.length" :orders="selectedOrders" @done="selected = []" />
    <template v-if="board || !selected.length">
      <template v-if="!board">
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
      </template>
        <span class="spacer"></span>
        <label class="sr" for="orders-search">{{ searchHint }}</label>
        <input
          id="orders-search"
          ref="searchEl"
          v-model="search"
          class="field search-mini"
          type="search"
          autocomplete="off"
          :style="{ '--search-w': `calc(${searchHint.length}ch + 2.4rem)` }"
          :placeholder="searchShort ? t('search') : searchHint"
        />
    </template>
  </div>

  <OrderBoard v-if="board" :search="searchQuery" />
  <template v-else>
    <div class="workspace" :class="{ 'has-panel': panelOpen }">
      <div class="list-pane">
        <p v-if="moreError && state === 'ready'" class="offline" role="alert" :data-testid="`more-${moreError}`">
          {{ moreError === 'offline' ? t('web.orders.stale') : t('web.orders.moreFailed') }}
          <button type="button" class="link" @click="retryMore">{{ t('web.tryAgain') }}</button>
        </p>
        <Maintenances v-if="showsMaintenances" />
        <section v-if="agora" class="next-visit" aria-labelledby="next-visit-label" data-testid="next-visit">
          <h2 id="next-visit-label" class="next-visit-label">{{ t('nextVisitLabel') }}</h2>
          <p>{{ agoraText }}</p>
          <button type="button" class="btn btn--primary" @click="open(agora)">{{ t('openOrderNumber', { number: agora.number ?? '' }) }}</button>
        </section>
        <AiIntro v-if="aiIntro" @close="aiIntro = false" />
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
              <th class="c-when" scope="col">{{ t('web.orders.when') }}</th>
              <th v-if="showsMoney" class="c-money" scope="col">{{ t('total') }}</th>
            </tr>
          </thead>
          <tbody v-for="group in groups" :key="group.key">
            <tr v-if="group.title" class="group-row no-click">
              <th :colspan="columns" scope="rowgroup">{{ group.title }}</th>
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
                <span v-if="rowDetail(order)" class="sub row-detail"
                  >{{ deviceSummary(order) }}<span v-if="plateOf(order)" class="row-plate"> · {{ plateOf(order) }}</span
                  >{{ deviceSummary(order) && servicesSummary(order) ? ' · ' : '' }}{{ servicesSummary(order) }}</span
                >
              </td>
              <td>
                <span v-if="visitTime(order)" class="num visit-time" data-testid="visit-time">{{ visitTime(order) }}</span>
                <StatusLabel :status="order.status" :late-text="lateText(order, now)" :held="isHeld(order)" :text="stageNameOf(order, workStages()) ?? statusText(order.status)" /><span
                  v-if="rowDates(order)"
                  class="st-narrow"
                >{{ rowDates(order) }}</span>
                <span v-if="isHeld(order) && holdDays(order, now) !== null" class="sub row-hold">{{ holdText(order, now) }}</span>
              </td>
              <td class="c-when" data-testid="row-when">
                <span v-if="whenCell(order, now)" :class="{ 'is-late': whenCell(order, now)?.late }">{{ whenCell(order, now)?.text }}</span>
              </td>
              <td v-if="showsMoney" class="c-money">
                <span class="num" :aria-label="prefs.hideValues ? t('web.money.hiddenA11y') : undefined">{{ money(order.total) }}</span>
                <template v-if="paymentOnRow(order)">
                  <span v-if="'paid' in paymentOnRow(order)!" class="owed is-paid" data-testid="row-paid">{{ t('web.orders.paid') }}</span>
                  <span v-else class="owed" data-testid="row-left">{{ t('web.orders.owedShort', { amount: money((paymentOnRow(order) as { left: number }).left) }) }}</span>
                </template>
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
