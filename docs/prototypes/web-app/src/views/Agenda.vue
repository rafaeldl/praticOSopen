<script setup>
import { computed, ref, nextTick, onMounted, onBeforeUnmount } from 'vue'
import { ChevronLeft, ChevronRight } from 'lucide-vue-next'
import { db, ui, customerOf, deviceOf, isOpen, moveOrderTo, agendaConflict, act, toast, STATUS, phone, touch } from '../store.js'
import { NOW, at, today, sameDay, hhmm, longDay, weekdayShort, dayMonth, friendlyWhen, plural, friendlyDay } from '../format.js'

const START = 7; const END = 19
const HOUR = Math.max(52, Math.floor((window.innerHeight - 150) / (END - START)))
const day = ref(today()); const mode = ref('day')
const dragging = ref(null); const over = ref(null); const overTray = ref(false)
const hours = Array.from({ length: END - START }, (_, i) => START + i)
const open = computed(() => db.value.orders.filter((o) => isOpen(o) || o.status === 'done'))
const onDay = (d) => open.value.filter((o) => o.scheduledAt && sameDay(o.scheduledAt, d) && isOpen(o))
const noDate = computed(() => db.value.orders.filter((o) => isOpen(o) && o.status !== 'quote' && !o.scheduledAt))
const lanes = computed(() => {
  const list = [...db.value.team]
  if (onDay(day.value).some((o) => !o.assignee)) list.push(null)
  return list
})
const laneOrders = (who) => onDay(day.value).filter((o) => (o.assignee || null) === who).sort((a, b) => new Date(a.scheduledAt) - new Date(b.scheduledAt))
const topOf = (o) => { const d = new Date(o.scheduledAt); return (d.getHours() - START + d.getMinutes() / 60) * HOUR }
const heightOf = (o) => Math.max(40, (o.duration / 60) * HOUR - 2)
function overlapClass(o, list) {
  const hit = list.filter((x) => x !== o && +new Date(x.scheduledAt) < +new Date(o.scheduledAt) + o.duration * 6e4 && +new Date(o.scheduledAt) < +new Date(x.scheduledAt) + x.duration * 6e4)
  if (!hit.length) return ''
  return list.indexOf(o) < list.indexOf(hit[0]) ? 'is-half' : 'is-half2'
}
const week = computed(() => {
  const m = new Date(day.value); m.setDate(m.getDate() - ((m.getDay() + 6) % 7))
  return Array.from({ length: 6 }, (_, i) => { const d = new Date(m); d.setDate(m.getDate() + i); return d })
})
const cellOrders = (who, d) => onDay(d).filter((o) => o.assignee === who).sort((a, b) => new Date(a.scheduledAt) - new Date(b.scheduledAt))
const nowTop = computed(() => (NOW.getHours() - START + NOW.getMinutes() / 60) * HOUR)
const showNow = computed(() => sameDay(day.value, NOW) && NOW.getHours() >= START && NOW.getHours() < END)
const title = computed(() => {
  const n = onDay(today()).length
  if (!db.value.orders.length) return 'Agenda livre'
  const base = `${plural(n, 'marcada', 'marcadas')} para hoje`
  return noDate.value.length ? `${base}, ${noDate.value.length} sem data` : base
})
const colorOf = (o) => ({ neutral: 'var(--color-neutral)', accent: 'var(--color-accent)', warning: 'var(--color-warning)', success: 'var(--color-success)' }[STATUS[o.status].dot])
function shift(n) { const d = new Date(day.value); d.setDate(d.getDate() + n * (mode.value === 'week' ? 7 : 1)); if (d.getDay() === 0) d.setDate(d.getDate() + n); day.value = d }
function place(o, date, who, focus = true) {
  const snapText = `OS ${o.number}: ${who || 'sem responsável'}, ${friendlyWhen(date)}`
  act(snapText, () => moveOrderTo(o, date, who))
  const clash = agendaConflict(o)
  if (clash) ui.toast.text = `${who} já tem a OS ${clash.number} nesse horário. Marcada mesmo assim.`
  if (focus) nextTick(() => document.getElementById('blk-' + o.id)?.focus())
}
const dragged = () => db.value.orders.find((x) => x.id === dragging.value)
function dropLane(e, who) {
  const o = dragged(); if (!o) return
  const rect = e.currentTarget.getBoundingClientRect()
  const mins = Math.round(((e.clientY - rect.top) / HOUR) * 2) * 30 + START * 60
  const clamped = Math.min(Math.max(START * 60, mins), END * 60 - 30)
  place(o, at(day.value, `${Math.floor(clamped / 60)}:${String(clamped % 60).padStart(2, '0')}`), who, false)
  dragging.value = null; over.value = null
}
function dropCell(who, d) {
  const o = dragged(); if (!o) return
  const prev = o.scheduledAt ? hhmm(o.scheduledAt) : '09:00'
  place(o, at(d, prev), who, false)
  dragging.value = null; over.value = null
}
function dropTray() {
  const o = dragged(); if (!o) return
  act(`OS ${o.number} ficou sem data`, () => { o.scheduledAt = null })
  dragging.value = null; overTray.value = false
}
function blockKey(e, o) {
  const d = new Date(o.scheduledAt)
  if (e.key === 'ArrowUp' || e.key === 'ArrowDown') {
    e.preventDefault(); d.setMinutes(d.getMinutes() + (e.key === 'ArrowUp' ? -30 : 30)); place(o, d, o.assignee)
  } else if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') {
    e.preventDefault()
    if (mode.value === 'week') { d.setDate(d.getDate() + (e.key === 'ArrowLeft' ? -1 : 1)); if (d.getDay() === 0) d.setDate(d.getDate() + (e.key === 'ArrowLeft' ? -1 : 1)); place(o, d, o.assignee); return }
    const team = db.value.team; const i = team.indexOf(o.assignee) + (e.key === 'ArrowLeft' ? -1 : 1)
    if (team[i]) place(o, d, team[i])
  }
}
function keys(e) {
  if (ui.layers || e.target.matches('input,textarea,select')) return
  if (e.key.toLowerCase() === 't') day.value = today()
}
onMounted(() => window.addEventListener('keydown', keys))
onBeforeUnmount(() => window.removeEventListener('keydown', keys))
const dayList = computed(() => lanes.value.flatMap(laneOrders).sort((a, b) => new Date(a.scheduledAt) - new Date(b.scheduledAt)))
</script>
<template>
  <header class="page-head">
    <div>
      <h1 class="page-title" tabindex="-1" data-page-title>{{ title }}</h1>
      <p class="page-sub">{{ mode === 'day' ? longDay(day) : `Semana de ${dayMonth(week[0])} a ${dayMonth(week[5])}` }}</p>
    </div>
    <div class="tabs hide-phone" role="group" aria-label="Forma de ver">
      <button :aria-pressed="mode === 'day'" @click="mode = 'day'">Dia</button>
      <button :aria-pressed="mode === 'week'" @click="mode = 'week'">Semana</button>
    </div>
    <div style="display: flex; gap: .25rem">
      <button class="icon-btn" aria-label="Anterior" @click="shift(-1)"><ChevronLeft :size="18" /></button>
      <button class="btn" @click="day = today()">Hoje</button>
      <button class="icon-btn" aria-label="Próximo" @click="shift(1)"><ChevronRight :size="18" /></button>
    </div>
  </header>
  <div v-if="phone" class="ag-list">
    <section aria-labelledby="ag-day">
      <h2 id="ag-day">Marcadas</h2>
      <button v-for="o in dayList" :key="o.id" class="ag-row" @click="ui.peek = o.id">
        <span class="num">{{ hhmm(o.scheduledAt) }}</span>
        <span><span class="who">{{ customerOf(o).name }}</span><span class="sub ag-sub">{{ o.items[0]?.name }}</span></span>
        <span class="sub">{{ o.assignee || 'Sem responsável' }}</span>
      </button>
      <p v-if="!dayList.length" class="muted ag-none">Nada marcado neste dia.</p>
    </section>
    <section v-if="noDate.length" aria-labelledby="ag-none">
      <h2 id="ag-none">Sem data <span class="num muted">{{ noDate.length }}</span></h2>
      <button v-for="o in noDate" :key="o.id" class="ag-row ag-row--plain" @click="ui.peek = o.id">
        <span><span class="who">{{ customerOf(o).name }}</span><span class="sub ag-sub">{{ o.items[0]?.name }}</span></span>
        <span class="link">Marcar</span>
      </button>
    </section>
  </div>
  <div v-else class="agenda">
    <aside class="tray" :class="{ 'is-over': overTray }" aria-label="Sem data" @dragover.prevent="overTray = true" @dragleave.self="overTray = false" @drop.prevent="dropTray">
      <h2>Sem data <span class="num muted">{{ noDate.length }}</span></h2>
      <p v-if="noDate.length && touch">Abra a OS e marque o dia.</p>
      <p v-else-if="noDate.length">Arraste para um horário, ou abra a OS e aperte <kbd>D</kbd>.</p>
      <p v-else>Nenhuma OS esperando data.</p>
      <article v-for="o in noDate" :key="o.id" class="card" draggable="true" :data-order="o.id" @dragstart="dragging = o.id; $event.dataTransfer.setData('text/plain', o.id)" @dragend="dragging = null">
        <button class="card-open" @click="ui.peek = o.id">
          <span class="card-top"><strong class="who">{{ customerOf(o).name }}</strong><span class="num">{{ o.number }}</span></span>
          <span class="sub">{{ o.items[0]?.name }}</span>
        </button>
      </article>
    </aside>
    <div class="day-scroll" tabindex="-1">
      <div v-if="mode === 'day'" class="day-grid" :style="{ '--cols': lanes.length, '--hour': HOUR + 'px' }">
        <div class="day-head" aria-hidden="true"></div>
        <div v-for="p in lanes" :key="p ?? 'none'" class="day-head">{{ p || 'Sem responsável' }}<small>{{ plural(laneOrders(p).length, 'OS', 'OS') }}</small></div>
        <div class="hours" :style="{ height: HOUR * (END - START) + 'px' }">
          <span v-for="h in hours.slice(1)" :key="h" class="hour" :style="{ top: (h - START) * HOUR + 'px' }">{{ String(h).padStart(2, '0') }}:00</span>
        </div>
        <div
          v-for="p in lanes" :key="p ?? 'none'" class="lane" :class="{ 'is-over': over === p }" :data-lane="p" :aria-label="`Agenda de ${p || 'sem responsável'}`" role="group"
          :style="{ height: HOUR * (END - START) + 'px' }" @dragover.prevent="over = p" @dragleave.self="over = null" @drop.prevent="dropLane($event, p)"
        >
          <button
            v-for="o in laneOrders(p)" :id="'blk-' + o.id" :key="o.id" class="block" :class="overlapClass(o, laneOrders(p))" draggable="true" :data-order="o.id"
            :style="{ top: topOf(o) + 'px', height: heightOf(o) + 'px', '--block': colorOf(o) }"
            :aria-label="`${hhmm(o.scheduledAt)}, ${customerOf(o).name}, OS ${o.number}. Setas movem.`"
            @click="ui.peek = o.id" @keydown="blockKey($event, o)" @dragstart="dragging = o.id; $event.dataTransfer.setData('text/plain', o.id)" @dragend="dragging = null; over = null"
          ><strong>{{ hhmm(o.scheduledAt) }} {{ customerOf(o).name }}</strong><span>{{ o.items[0]?.name }}</span></button>
        </div>
        <div v-if="showNow" class="now-line" :data-label="hhmm(NOW)" :style="{ top: `calc(${nowTop}px + 3.1rem)` }"></div>
      </div>
      <div v-else class="week">
        <div class="week-h" aria-hidden="true"></div>
        <div v-for="d in week" :key="+d" class="week-h" :class="{ 'is-today': sameDay(d, NOW) }">{{ weekdayShort(d) }} <span class="num muted">{{ dayMonth(d) }}</span></div>
        <template v-for="p in db.team" :key="p">
          <div class="week-p">{{ p }}</div>
          <div v-for="d in week" :key="+d" class="week-c" :class="{ 'is-over': over === p + d }" @dragover.prevent="over = p + d" @dragleave.self="over = null" @drop.prevent="dropCell(p, d)">
            <button
              v-for="o in cellOrders(p, d)" :id="'blk-' + o.id" :key="o.id" class="block" draggable="true" :data-order="o.id" :style="{ '--block': colorOf(o) }"
              @click="ui.peek = o.id" @keydown="blockKey($event, o)" @dragstart="dragging = o.id; $event.dataTransfer.setData('text/plain', o.id)" @dragend="dragging = null; over = null"
            ><strong>{{ hhmm(o.scheduledAt) }} {{ customerOf(o).name }}</strong></button>
          </div>
        </template>
      </div>
    </div>
  </div>
</template>
