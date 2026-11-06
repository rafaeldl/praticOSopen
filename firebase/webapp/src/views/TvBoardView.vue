<script setup lang="ts">
// Modo TV (#627): the board on a screen in the shop. No menu, no values, no
// clicks on the cards; big type; updates by itself and keeps the screen awake.
import { computed, onBeforeUnmount, onMounted, ref, shallowRef } from 'vue'
import { Maximize, X } from '@lucide/vue'
import ErrorState from '@/components/ErrorState.vue'
import { t } from '@/i18n'
import { formatTime } from '@/lib/format'
import { listContext } from '@/lib/orders/data'
import { deviceSummary, isHeld, type Order, type OrderStatus } from '@/lib/orders/model'
import { country, holdText, lateText, statusText } from '@/lib/orders/text'
import { TV_COLUMNS, TV_LIMIT, dayStartIso, emptyColumns, sortForTv, watchTv, type TvColumns } from '@/lib/orders/tv'
import { session } from '@/lib/session'
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

/**
 * With work stages (docs/WORK_STAGES.md), "Em andamento" shows one column per
 * stage, in the order set on the board: that is the queue the team follows.
 */
const shown = computed(() => {
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

let live: ReturnType<typeof watchTv> | null = null
let day = ''

function start() {
  live?.stop()
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

onMounted(() => {
  start()
  void keepAwake()
  document.addEventListener('visibilitychange', onVisible)
  document.addEventListener('fullscreenchange', onFullscreen)
})
onBeforeUnmount(() => {
  live?.stop()
  clearInterval(clock)
  void lock?.release().catch(() => {})
  document.removeEventListener('visibilitychange', onVisible)
  document.removeEventListener('fullscreenchange', onFullscreen)
})

const flag = (order: Order) => lateText(order, now.value) || (isHeld(order) ? holdText(order, now.value) : '')
</script>

<template>
  <main class="tv" data-testid="tv">
    <header class="tv-head">
      <h1 class="tv-title">{{ session.company?.name ?? t('web.tv.title') }}</h1>
      <p class="tv-clock num" aria-hidden="true">{{ formatTime(now, country()) }}</p>
      <div class="tv-actions">
        <button v-if="canFullscreen && !full" type="button" class="btn btn--ghost" data-testid="tv-fullscreen" @click="toggleFullscreen">
          <Maximize :size="18" aria-hidden="true" /> {{ t('web.tv.fullscreen') }}
        </button>
        <RouterLink class="btn btn--ghost" :to="{ path: '/', query: { view: 'board' } }" data-testid="tv-exit">
          <X :size="18" aria-hidden="true" /> {{ t('web.tv.exit') }}
        </RouterLink>
      </div>
    </header>

    <ErrorState v-if="failed" :retry="start" />
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
