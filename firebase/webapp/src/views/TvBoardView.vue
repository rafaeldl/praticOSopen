<script setup lang="ts">
// Modo TV (#627): the board on a screen in the shop. No menu, no values, no
// clicks on the cards; big type; updates by itself and keeps the screen awake.
// Plan (#724): needs `tvMode` (Pro); without it the screen shows the plan notice.
import { computed, onBeforeUnmount, onMounted, ref, shallowRef, watch } from 'vue'
import { Columns3, Maximize, X } from '@lucide/vue'
import ErrorState from '@/components/ErrorState.vue'
import PlanFeatureNotice from '@/components/PlanFeatureNotice.vue'
import { usePlanFeature } from '@/lib/plan-feature-gate'
import { t } from '@/i18n'
import { formatTime } from '@/lib/format'
import { listContext } from '@/lib/orders/data'
import { deviceSummary, isHeld, type Order, type OrderStatus } from '@/lib/orders/model'
import { country, holdText, lateText, statusText } from '@/lib/orders/text'
import { TV_COLUMNS, TV_LIMIT, dayStartIso, emptyColumns, sortForTv, watchTv, type TvColumns } from '@/lib/orders/tv'
import { session } from '@/lib/session'
import { prefs } from '@/lib/prefs'
import { sortInStage, stageIdOf, workStages } from '@/lib/orders/stages'
import '@/styles/tv.css'

const DOT: Record<OrderStatus, string> = { quote: 'neutral', approved: 'accent', progress: 'warning', done: 'success', canceled: 'hollow' }
const ctx = listContext()
const now = ref(new Date())
const columns = shallowRef<TvColumns>(emptyColumns())
const arrived = ref<Set<OrderStatus>>(new Set())
const failed = ref(false)
const canFullscreen = typeof document !== 'undefined' && !!document.fullscreenEnabled
const full = ref(false)
const tvMode = usePlanFeature('tvMode')

/**
 * With work stages (docs/WORK_STAGES.md), "Em andamento" shows one column per
 * stage, in the order set on the board: that is the queue the team follows.
 */
const all = computed(() => {
  const stages = workStages()
  return TV_COLUMNS.flatMap((status) => {
    if (status === 'progress' && stages.length) {
      const progress = columns.value.progress
      return stages.map((stage) => ({
        key: `stage-${stage.id}`,
        status,
        title: stage.name,
        orders: sortInStage(progress.filter((order) => stageIdOf(order, stages) === stage.id), stage.id),
        full: progress.length >= TV_LIMIT,
      }))
    }
    return [{
      key: status as string,
      status,
      title: status === 'done' ? t('web.tv.doneToday') : statusText(status),
      orders: status === 'done' ? columns.value.done : sortForTv(columns.value[status], now.value),
      full: columns.value[status].length >= TV_LIMIT,
    }]
  })
})

/** The columns the person left on (Colunas): never none, the last one cannot be turned off. */
const shown = computed(() => {
  const hidden = new Set(Array.isArray(prefs.tvHidden) ? prefs.tvHidden : [])
  const kept = all.value.filter((col) => !hidden.has(col.key))
  return kept.length ? kept : all.value
})
const isShown = (key: string) => shown.value.some((col) => col.key === key)
function toggleColumn(key: string) {
  const hidden = new Set(Array.isArray(prefs.tvHidden) ? prefs.tvHidden : [])
  if (hidden.has(key)) hidden.delete(key)
  else if (shown.value.length > 1) hidden.add(key)
  prefs.tvHidden = [...hidden]
}

const colsMenu = ref<HTMLDetailsElement | null>(null)
function closeColumns() {
  if (!colsMenu.value?.open) return
  colsMenu.value.open = false
  colsMenu.value.querySelector('summary')?.focus()
}
// A click outside closes the list, like a menu.
const onDocClick = (event: MouseEvent) => {
  if (colsMenu.value?.open && !colsMenu.value.contains(event.target as Node)) colsMenu.value.open = false
}

let live: ReturnType<typeof watchTv> | null = null
let day = ''

function start() {
  live?.stop()
  live = null
  if (!tvMode.value.allowed) return
  failed.value = false
  day = dayStartIso(now.value)
  live = watchTv(
    ctx,
    day,
    (status, orders) => {
      columns.value = { ...columns.value, [status]: orders }
      arrived.value = new Set([...arrived.value, status])
    },
    (error) => {
      console.error('tv: failed', error)
      failed.value = true
    },
  )
}

// The screen of a TV must not go dark (Screen Wake Lock, where the browser has it).
let lock: { release: () => Promise<void> } | null = null
async function keepAwake() {
  try {
    const nav = navigator as Navigator & { wakeLock?: { request: (type: 'screen') => Promise<{ release: () => Promise<void> }> } }
    if (document.visibilityState !== 'visible' || !nav.wakeLock || lock) return
    const next = await nav.wakeLock.request('screen')
    lock = next
    // The browser lets go when the tab hides; onVisible asks again.
    ;(next as unknown as EventTarget).addEventListener('release', () => (lock = null))
  } catch {
    // Battery saver or no permission: the TV's own settings decide.
  }
}

function onVisible() {
  if (document.visibilityState !== 'visible') return
  void keepAwake()
  void live?.refresh()
}

async function toggleFullscreen() {
  try {
    if (document.fullscreenElement) await document.exitFullscreen()
    else await document.documentElement.requestFullscreen()
  } catch {
    // Refused by the browser: the page still works in the window.
  }
}
const onFullscreen = () => (full.value = !!document.fullscreenElement)

// The clock: "Atrasada" and "parada há" follow it, and Concluído starts over at midnight.
const clock = setInterval(() => {
  now.value = new Date()
  if (dayStartIso(now.value) !== day) start()
}, 30_000)

// The switch arrives after the first paint: a plan without the TV stops listening.
watch(
  () => tvMode.value.allowed,
  (allowed) => {
    if (!allowed) {
      live?.stop()
      live = null
    }
    else if (!live) start()
  },
)

onMounted(() => {
  start()
  void keepAwake()
  document.addEventListener('visibilitychange', onVisible)
  document.addEventListener('fullscreenchange', onFullscreen)
  document.addEventListener('click', onDocClick)
})
onBeforeUnmount(() => {
  live?.stop()
  clearInterval(clock)
  void lock?.release().catch(() => {})
  document.removeEventListener('visibilitychange', onVisible)
  document.removeEventListener('fullscreenchange', onFullscreen)
  document.removeEventListener('click', onDocClick)
})

const flag = (order: Order) => lateText(order, now.value) || (isHeld(order) ? holdText(order, now.value) : '')
</script>

<template>
  <main class="tv" data-testid="tv">
    <header class="tv-head">
      <h1 class="tv-title">{{ session.company?.name ?? t('web.tv.title') }}</h1>
      <p class="tv-clock num" aria-hidden="true">{{ formatTime(now, country()) }}</p>
      <div class="tv-actions">
        <details ref="colsMenu" class="tv-cols-menu" data-testid="tv-columns" @keydown.esc="closeColumns">
          <summary class="btn btn--ghost"><Columns3 :size="18" aria-hidden="true" /> {{ t('web.tv.columns') }}</summary>
          <fieldset class="tv-cols-box">
            <legend>{{ t('web.tv.columnsTitle') }}</legend>
            <label v-for="col in all" :key="col.key" class="tv-cols-opt">
              <input
                type="checkbox"
                :checked="isShown(col.key)"
                :disabled="isShown(col.key) && shown.length === 1"
                :data-testid="`tv-show-${col.key}`"
                @change="toggleColumn(col.key)"
              />
              {{ col.title }}
            </label>
          </fieldset>
        </details>
        <button v-if="canFullscreen && !full" type="button" class="btn btn--ghost" data-testid="tv-fullscreen" @click="toggleFullscreen">
          <Maximize :size="18" aria-hidden="true" /> {{ t('web.tv.fullscreen') }}
        </button>
        <RouterLink class="btn btn--ghost" :to="{ path: '/', query: { view: 'board' } }" data-testid="tv-exit">
          <X :size="18" aria-hidden="true" /> {{ t('web.tv.exit') }}
        </RouterLink>
      </div>
    </header>

    <PlanFeatureNotice v-if="!tvMode.allowed" class="tv-plan" feature="tvMode" :required-plan="tvMode.requiredPlan" />
    <ErrorState v-else-if="failed" :retry="start" />
    <div v-else class="tv-board" :style="{ '--tv-cols': shown.length }">
      <section v-for="col in shown" :key="col.key" class="tv-col" :aria-labelledby="`tv-${col.key}`" :data-testid="`tv-col-${col.key}`">
        <h2 :id="`tv-${col.key}`" class="tv-col-head">
          <span class="dot" :class="`dot--${DOT[col.status]}`" aria-hidden="true"></span>{{ col.title }}<span class="num tv-count">{{ col.orders.length }}{{ col.full ? '+' : '' }}</span>
        </h2>
        <ul class="tv-list">
          <li v-for="order in col.orders" :key="order.id" class="tv-card" :class="{ 'is-late': !!lateText(order, now) }">
            <span class="tv-card-top"><strong class="tv-who">{{ order.customer?.name }}</strong><span class="num tv-number">{{ order.number }}</span></span>
            <span v-if="deviceSummary(order)" class="tv-sub">{{ deviceSummary(order) }}</span>
            <span v-if="flag(order)" class="tv-flag" :class="{ 'tv-flag--late': !!lateText(order, now) }">{{ flag(order) }}</span>
          </li>
        </ul>
        <p v-if="arrived.has(col.status) && !col.orders.length" class="tv-empty">{{ t('web.board.emptyColumn') }}</p>
        <p v-if="col.full" class="tv-empty">{{ t('web.tv.more', { count: TV_LIMIT }) }}</p>
      </section>
    </div>
  </main>
</template>
