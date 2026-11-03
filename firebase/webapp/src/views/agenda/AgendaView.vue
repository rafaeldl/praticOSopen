<script setup lang="ts">
// Agenda: the visits (or the deliveries, without useScheduling) of a day or a
// week, in the company's zone, with the month on the side. On a big screen a
// visit is moved by dragging or by Shift + arrows; a move the customer counts
// on asks first, and every move can be undone. Reads and writes go through the
// API (lib/agenda/data.ts): who sees what and the values come from the server.
import { computed, defineAsyncComponent, nextTick, onBeforeUnmount, onMounted, ref, shallowRef, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ChevronLeft, ChevronRight } from '@lucide/vue'
import EmptyState from '@/components/EmptyState.vue'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import StatusLabel from '@/components/StatusLabel.vue'
import MonthCalendar from '@/components/agenda/MonthCalendar.vue'
import TimeGrid, { type ArrowKey } from '@/components/agenda/TimeGrid.vue'
import ChoiceDialog from '@/components/orders/ChoiceDialog.vue'
import ConfirmDialog from '@/components/orders/ConfirmDialog.vue'
import { loadOrderTexts, t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { loadAgenda, saveDate, type AgendaField, type AgendaOrder } from '@/lib/agenda/data'
import {
  affectsCustomer,
  firstDayOfWeek,
  hourSpan,
  isDay,
  monthGrid,
  nudge,
  placeVisits,
  queryRange,
  sameTarget,
  step,
  targetInstant,
  storedText,
  today,
  visibleDays,
  wallOf,
  weekOf,
  type AgendaView,
  type Target,
  type Visit,
} from '@/lib/agenda/model'
import { agendaLocale, dayLong, dayMonth, dayNumber, dayShort, targetText, timeOf, weekdayShort, zone } from '@/lib/agenda/text'
import '@/styles/agenda.css'
import { onOrderEvent, orderChanged } from '@/lib/orders/bus'
import { loadTeam, type Member } from '@/lib/orders/catalog'
import { accessOf } from '@/lib/orders/model'
import { lateText, orderShort, statusText } from '@/lib/orders/text'
import { orderOf } from '@/lib/orders/writes'
import { useRoutePanel } from '@/lib/route-layer'
import { can, effectiveUseFinancial, session } from '@/lib/session'
import { registerShortcut } from '@/lib/shortcuts'
import { showToast } from '@/lib/toast'
import { announce } from '@/lib/ui'

const OrderDetail = defineAsyncComponent(() => Promise.all([import('@/components/orders/OrderDetail.vue'), loadOrderTexts()]).then(([m]) => m))

const route = useRoute()
const router = useRouter()
const panel = useRoutePanel('order')
const now = ref(new Date())
const media = typeof matchMedia === 'function' ? matchMedia('(min-width: 48rem)') : null
const wide = ref(media?.matches ?? true)
const items = shallowRef<AgendaOrder[]>([])
const state = ref<'loading' | 'ready' | 'failed'>('loading')
const cut = ref(false)
const team = ref<Member[]>([])
const picking = ref(false)
const showMonth = ref(false)
const pending = shallowRef<{ item: AgendaOrder; target: Target; from: Target } | null>(null)
const asking = shallowRef<{ item: AgendaOrder; target: Target; from: Target } | null>(null)
let loadToken = 0

const country = () => session.company?.country
const companyZone = computed(() => zone())
const todayDay = computed(() => today(companyZone.value, now.value))
const day = computed(() => (isDay(route.query.d) ? route.query.d : todayDay.value))
const view = computed<AgendaView>(() => (wide.value && route.query.view !== 'day' ? 'week' : 'day'))
const firstDay = computed(() => firstDayOfWeek(country(), agendaLocale()))
const days = computed(() => visibleDays(view.value, day.value, firstDay.value))
const grid = computed(() => monthGrid(day.value, firstDay.value))
/** useScheduling off (company): the agenda shows deliveries (agenda.mode-due), all as "Dia todo". */
const timed = computed(() => (session.company as { useScheduling?: boolean } | null)?.useScheduling !== false)
const field = computed<AgendaField>(() => (timed.value ? 'scheduledDate' : 'dueDate'))
/** "De quem": admin, manager and supervisor (app: isAdmin, isManager, isSupervisor). */
const canFilter = computed(() => ['owner', 'admin', 'manager', 'supervisor'].includes(session.role ?? ''))
const who = computed(() => (canFilter.value && typeof route.query.who === 'string' && route.query.who ? route.query.who : null))
const whoName = computed(() => team.value.find((member) => member.id === who.value)?.name || t('noName'))
const nowMinutes = computed(() => {
  const wall = wallOf(now.value, companyZone.value)
  return wall.hour * 60 + wall.minute
})

/** The loaded orders with the one being moved by keyboard at its preview place. */
const shown = computed(() => {
  const moving = pending.value
  if (!moving) return items.value
  const preview = { ...moving.item, stored: targetInstant(moving.target, companyZone.value).toISOString() }
  const rest = items.value.filter((item) => item.order.id !== moving.item.order.id)
  return [...rest, preview]
})
const placed = computed(() => placeVisits(shown.value, (item) => item.stored, companyZone.value, timed.value))
const counts = computed(() => Object.fromEntries([...placed.value].map(([key, list]) => [key, list.length])))
const visibleVisits = computed(() => days.value.flatMap((key) => placed.value.get(key) ?? []))
const span = computed(() => hourSpan(visibleVisits.value))
const dayVisits = computed(() => placed.value.get(day.value) ?? [])
const strip = computed(() => weekOf(day.value, firstDay.value))

const summary = computed(() => {
  const when =
    view.value === 'day'
      ? dayLong(day.value)
      : t('web.agenda.weekRange', { from: dayMonth(days.value[0] as string), to: dayMonth(days.value[days.value.length - 1] as string) })
  return `${when} · ${t('agendaDayCount', { count: visibleVisits.value.length })}`
})
const emptyTitle = computed(() =>
  view.value === 'day' ? t(timed.value ? 'noScheduledOrders' : 'noOrdersDueOnDate') : t(timed.value ? 'web.agenda.noneWeek' : 'web.agenda.noneWeekDue'),
)
const stepLabels = computed(() =>
  view.value === 'week' ? [t('agendaPreviousWeek'), t('agendaNextWeek')] : [t('web.agenda.previousDay'), t('web.agenda.nextDay')],
)

function setQuery(patch: Record<string, string | undefined>) {
  const query = { ...route.query, ...patch }
  for (const key of Object.keys(patch)) if (patch[key] === undefined) delete query[key]
  void router.replace({ query })
}

const goTo = (next: string) => setQuery({ d: next === todayDay.value ? undefined : next })
const setView = (next: AgendaView) => setQuery({ view: next === 'week' ? undefined : 'day' })
const move = (direction: -1 | 1) => goTo(step(view.value, day.value, direction))

async function load(quiet = false) {
  const token = ++loadToken
  if (!quiet) state.value = 'loading'
  try {
    const range = queryRange([...grid.value, ...days.value], companyZone.value)
    const result = await loadAgenda({ field: field.value, ...range, assignedTo: who.value })
    if (token !== loadToken) return
    items.value = result.orders
    cut.value = result.cut
    state.value = 'ready'
    if (!quiet) announce(summary.value)
  } catch (error) {
    console.error('agenda: failed', error)
    if (token === loadToken && !quiet) state.value = 'failed'
  }
}

// Another month: read its grid (a keyboard move in progress follows to it).
watch(
  () => grid.value[0],
  () => void load(),
)
// Another person, company or kind of date: what was being moved belongs to the old list.
watch(
  () => [field.value, who.value, session.companyId],
  () => {
    pending.value = null
    void load()
  },
)
// Another company: the person filter belongs to the old one (app defect F1).
watch(
  () => session.companyId,
  () => {
    if (route.query.who) setQuery({ who: undefined })
  },
)

const canMove = (item: AgendaOrder) => can('editOrder') && accessOf(item.order, session.role, session.uid, effectiveUseFinancial()).canEditMainFields

/** Where the order is now: its day, and its time unless it is "Dia todo". */
function placeOf(item: AgendaOrder): Target {
  const visit = placeVisits([item], (one) => one.stored, companyZone.value, timed.value).values().next().value?.[0]
  if (!visit) return { day: day.value, minutes: null }
  return { day: visit.day, minutes: visit.allDay ? null : visit.hour * 60 + visit.minute }
}

function focusBlock(id: string) {
  void nextTick(() => document.getElementById(`blk-${id}`)?.focus())
}

function onNudge(item: AgendaOrder, key: ArrowKey) {
  if (!canMove(item)) {
    showToast(t('web.agenda.cannotMove'))
    return
  }
  // Without times (deliveries) only the day moves.
  if (!timed.value && (key === 'ArrowUp' || key === 'ArrowDown')) return
  const current = pending.value?.item.order.id === item.order.id ? pending.value : null
  const from = current?.from ?? placeOf(item)
  const target = nudge(current?.target ?? from, key)
  pending.value = { item, target, from }
  if (!days.value.includes(target.day)) goTo(target.day)
  announce(t('web.agenda.movePreview', { order: orderShort(), number: item.order.number ?? '', when: targetText(target) }))
  focusBlock(item.order.id)
}

function onCancel() {
  const id = pending.value?.item.order.id
  pending.value = null
  if (id) focusBlock(id)
}

function commit(item: AgendaOrder, target: Target, from: Target) {
  if (sameTarget(target, from)) {
    pending.value = null
    return
  }
  if (affectsCustomer(item.order, !!item.stored)) {
    asking.value = { item, target, from }
    return
  }
  void save(item, target, from)
}

function onDrop(item: AgendaOrder, target: Target) {
  if (!canMove(item)) {
    showToast(t('web.agenda.cannotMove'))
    return
  }
  // Dropped on the hours without times (deliveries): only the day counts.
  commit(item, timed.value ? target : { day: target.day, minutes: null }, placeOf(item))
}

function replaceItem(next: AgendaOrder) {
  items.value = [...items.value.filter((item) => item.order.id !== next.order.id), next]
}

let ownEvent = false
async function save(item: AgendaOrder, target: Target, from: Target, undoing = false) {
  pending.value = null
  asking.value = null
  // As the app writes it: company's local time, no zone (revisão do #521, M1).
  const value = storedText(target)
  const before = items.value
  // Where the focus was when the move started: if the person goes on to something else while it saves, it stays there.
  const focused = document.activeElement
  replaceItem({ ...item, stored: value })
  try {
    const response = await saveDate(item.order, field.value, value)
    const fresh = orderOf(response, can('viewPrices'))
    const stored = (response.order?.[field.value] as string | undefined) ?? value
    const next = { order: fresh ?? item.order, stored }
    replaceItem(next)
    if (fresh) {
      ownEvent = true
      orderChanged(fresh)
      ownEvent = false
    }
    const params = { order: orderShort(), number: item.order.number ?? '' }
    if (undoing) showToast(t('web.agenda.undone', { ...params, when: targetText(target) }))
    else showToast(t('web.agenda.moved', { ...params, when: targetText(target) }), { undo: () => void save(next, from, target, true) })
    if (document.activeElement === focused || document.activeElement === document.body) focusBlock(item.order.id)
  } catch (error) {
    items.value = before
    showToast(t(errorMessageKey(error)))
    // Someone saved the order meanwhile: show the new version.
    if ((error as { code?: string })?.code === 'ORDER_CHANGED') void load(true)
  }
}

const askingTexts = computed(() => {
  const value = asking.value
  if (!value) return null
  const name = value.item.order.customer?.name || t('web.orders.noCustomer')
  return {
    title: t(timed.value ? 'web.agenda.confirmTitle' : 'web.agenda.confirmDueTitle', { name }),
    body: t('web.agenda.confirmBody', { from: targetText(value.from), to: targetText(value.target) }),
  }
})

function keepAsWas() {
  const id = asking.value?.item.order.id
  asking.value = null
  pending.value = null
  if (id) focusBlock(id)
}

function open(item: AgendaOrder) {
  if (pending.value) return
  void panel.open(item.order.id)
}

function closePanel() {
  const id = panel.value.value
  panel.close()
  if (id) focusBlock(id)
}

const whoChoices = computed(() => [
  { id: '', label: t('allTeam'), current: !who.value },
  ...team.value.map((member) => ({ id: member.id, label: member.name || t('noName'), current: member.id === who.value })),
])

/** The picker's layer takes its entry out of the URL as it closes: change the query after that. */
async function pickWho(id: string) {
  picking.value = false
  await nextTick()
  if (route.query.layer) {
    await new Promise<void>((resolve) => {
      const timer = setTimeout(done, 1000)
      const stop = watch(() => route.query.layer, (layer) => !layer && done())
      function done() {
        clearTimeout(timer)
        stop()
        resolve()
      }
    })
  }
  setQuery({ who: id || undefined })
}

function lineOf(item: AgendaOrder): string {
  const order = item.order
  const devices = order.devices
  const device = devices.length ? `${devices[0]?.name || devices[0]?.serial || ''}${devices.length > 1 ? ` +${devices.length - 1}` : ''}` : ''
  return [device, order.assignedTo?.name ? t('agendaWithPerson', { name: order.assignedTo.name }) : ''].filter(Boolean).join(' · ')
}

const insidePanel = () => !!document.activeElement?.closest('.panel')
const visitTime = (visit: Visit<AgendaOrder>) => (visit.allDay ? t('allDay') : timeOf(visit.at))

let stopBus: (() => void) | undefined
let reloadTimer: ReturnType<typeof setTimeout> | undefined
const onMedia = () => (wide.value = media?.matches ?? true)
const onFocus = () => void load(true)
const clock = setInterval(() => (now.value = new Date()), 60_000)
const removers: (() => void)[] = []

onMounted(() => {
  onMedia()
  media?.addEventListener('change', onMedia)
  window.addEventListener('focus', onFocus)
  void load()
  if (canFilter.value) void loadTeam().then((list) => (team.value = list), () => (team.value = []))
  // The order beside (or another screen) changed one: read the range again, quietly.
  stopBus = onOrderEvent(() => {
    if (ownEvent) return
    clearTimeout(reloadTimer)
    reloadTimer = setTimeout(() => void load(true), 300)
  })
  removers.push(
    registerShortcut({ keys: 't', label: 'web.shortcuts.agendaToday', run: () => goTo(todayDay.value) }),
    // Arrows inside the open order belong to it.
    registerShortcut({ keys: 'arrowleft', label: 'web.shortcuts.agendaStep', run: () => !insidePanel() && move(-1) }),
    registerShortcut({ keys: 'arrowright', label: 'web.shortcuts.agendaStep', run: () => !insidePanel() && move(1) }),
  )
})
onBeforeUnmount(() => {
  loadToken++
  media?.removeEventListener('change', onMedia)
  window.removeEventListener('focus', onFocus)
  clearInterval(clock)
  clearTimeout(reloadTimer)
  stopBus?.()
  removers.forEach((remove) => remove())
})
</script>

<template>
  <header class="page-head">
    <div>
      <h1 class="page-title" tabindex="-1" data-page-title>{{ t('agenda') }}</h1>
      <p class="page-sub page-answer" data-testid="agenda-summary">{{ state === 'ready' ? summary : '' }}</p>
    </div>
    <div v-if="wide" class="tabs" role="group" :aria-label="t('web.agenda.viewAs')">
      <button type="button" :aria-pressed="view === 'day'" @click="setView('day')">{{ t('web.agenda.day') }}</button>
      <button type="button" :aria-pressed="view === 'week'" @click="setView('week')">{{ t('web.agenda.week') }}</button>
    </div>
  </header>

  <div class="toolbar ag-toolbar">
    <div class="ag-step">
      <button type="button" class="icon-btn" :aria-label="stepLabels[0]" @click="move(-1)"><ChevronLeft aria-hidden="true" /></button>
      <button type="button" class="btn" @click="goTo(todayDay)">{{ t('today') }} <kbd v-if="wide">T</kbd></button>
      <button type="button" class="icon-btn" :aria-label="stepLabels[1]" @click="move(1)"><ChevronRight aria-hidden="true" /></button>
    </div>
    <span class="spacer"></span>
    <button v-if="!wide" type="button" class="btn btn--ghost" @click="showMonth = !showMonth">{{ showMonth ? t('agendaShowWeek') : t('agendaShowMonth') }}</button>
    <button v-if="canFilter" type="button" class="btn" data-testid="agenda-who" @click="picking = true">
      {{ who ? t('agendaWhose', { name: whoName }) : t('agendaWhose', { name: t('allTeam') }) }}
    </button>
  </div>
  <p v-if="who" class="ag-only" data-testid="agenda-only">
    {{ t('agendaOnlyOf', { name: whoName }) }}
    <button type="button" class="link" @click="setQuery({ who: undefined })">{{ t('agendaShowAll') }}</button>
  </p>
  <p v-if="cut && state === 'ready'" class="offline" role="alert">{{ t('web.agenda.cut', { count: items.length }) }}</p>

  <div class="workspace" :class="{ 'has-panel': !!panel.value.value }">
    <div class="list-pane ag-pane">
      <div class="ag" :class="{ 'ag--wide': wide }">
        <aside v-if="wide || showMonth" class="ag-side">
          <MonthCalendar :day="day" :today="todayDay" :first-day="firstDay" :counts="counts" @pick="goTo" />
        </aside>
        <div class="ag-main">
          <nav v-if="!wide && !showMonth" class="ag-strip" :aria-label="t('web.agenda.week')">
            <button
              v-for="cell in strip"
              :key="cell"
              type="button"
              class="ag-strip-day"
              :class="{ 'is-today': cell === todayDay, 'is-chosen': cell === day }"
              :aria-pressed="cell === day"
              :aria-current="cell === todayDay ? 'date' : undefined"
              @click="goTo(cell)"
            >
              <span class="sr">{{ counts[cell] ? t('agendaDayHasOrders', { day: dayLong(cell) }) : dayLong(cell) }}</span>
              <span class="sub" aria-hidden="true">{{ weekdayShort(cell) }}</span>
              <span class="num" aria-hidden="true">{{ dayNumber(cell) }}</span>
              <span class="cal-dot" :class="{ 'is-empty': !counts[cell] }" aria-hidden="true"></span>
            </button>
          </nav>
          <LoadingState v-if="state === 'loading'" />
          <ErrorState v-else-if="state === 'failed'" :body="t('web.agenda.loadError')" :retry="() => load()" />
          <EmptyState v-else-if="!visibleVisits.length" :title="emptyTitle" :body="t(timed ? 'web.agenda.emptyHint' : 'web.agenda.emptyHintDue')" data-testid="agenda-empty" />
          <div v-else-if="wide" class="ag-scroll">
            <TimeGrid
              :days="days"
              :visits="placed"
              :span="span"
              :today="todayDay"
              :now="now"
              :now-minutes="nowMinutes"
              :timed="timed"
              :pending-id="pending?.item.order.id ?? null"
              :can-move="canMove"
              @open="open"
              @drop="onDrop"
              @nudge="onNudge"
              @confirm="(item) => pending && commit(item, pending.target, pending.from)"
              @cancel="onCancel"
              @show-day="(next) => setQuery({ d: next === todayDay ? undefined : next, view: 'day' })"
            />
          </div>
          <section v-else class="ag-list" aria-labelledby="ag-day-title">
            <h2 id="ag-day-title" class="ag-day-title">{{ dayShort(day) }} <span class="sub">· {{ t('agendaDayCount', { count: dayVisits.length }) }}</span></h2>
            <ul>
              <li v-for="visit in dayVisits" :key="visit.item.order.id">
                <button type="button" class="ag-row" :data-order="visit.item.order.id" @click="open(visit.item)">
                  <span class="ag-row-top"><span class="who">{{ visit.item.order.customer?.name || t('web.orders.noCustomer') }}</span><span class="num">{{ visitTime(visit) }}</span></span>
                  <StatusLabel
                    :status="visit.item.order.status"
                    :late-text="lateText(visit.item.order, now) ? `${lateText(visit.item.order, now)} · ${visit.item.order.number ?? ''}` : null"
                    :text="`${statusText(visit.item.order.status)} · ${visit.item.order.number ?? ''}`"
                  />
                  <span v-if="lineOf(visit.item)" class="sub">{{ lineOf(visit.item) }}</span>
                </button>
              </li>
            </ul>
          </section>
        </div>
      </div>
    </div>
    <aside v-if="panel.value.value" class="panel" :aria-label="t('web.orders.panel')">
      <OrderDetail :key="panel.value.value" :order-id="panel.value.value" @close="closePanel" />
    </aside>
  </div>

  <ChoiceDialog v-if="picking" :title="t('agendaWhoseTitle')" :choices="whoChoices" @pick="pickWho" @close="picking = false" />
  <ConfirmDialog
    v-if="asking && askingTexts"
    :title="askingTexts.title"
    :body="askingTexts.body"
    :confirm="t('web.agenda.confirm')"
    :keep="t('web.agenda.keep')"
    @confirm="asking && save(asking.item, asking.target, asking.from)"
    @close="keepAsWas"
  />
</template>
