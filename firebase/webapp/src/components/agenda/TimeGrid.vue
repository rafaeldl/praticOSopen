<script setup lang="ts">
// Hours down, days across (one for Dia, seven for Semana). Dragging a visit to
// another hour or day moves it; the keyboard does the same (WCAG 2.5.7):
// Shift + arrows move a preview, Enter confirms, Esc puts it back. Clicking a
// free hour (or the "Dia todo" row) starts a Nova OS there; nothing is saved
// until its ✓.
import { computed, ref } from 'vue'
import { t } from '@/i18n'
import type { AgendaOrder } from '@/lib/agenda/data'
import { layoutColumn, slotAt, snapMinutes, type Target, type Visit } from '@/lib/agenda/model'
import { dayShort, hourLabel, minutesLabel, timeOf, weekdayShort, dayMonth } from '@/lib/agenda/text'
import { lateText, orderShort, statusText } from '@/lib/orders/text'

export type ArrowKey = 'ArrowUp' | 'ArrowDown' | 'ArrowLeft' | 'ArrowRight'

const props = defineProps<{
  days: string[]
  visits: Map<string, Visit<AgendaOrder>[]>
  span: { start: number; end: number }
  today: string
  now: Date
  nowMinutes: number
  timed: boolean
  pendingId: string | null
  canMove: (item: AgendaOrder) => boolean
  /** Who can create orders: a free hour opens Nova OS. */
  canCreate: boolean
}>()
const emit = defineEmits<{
  open: [item: AgendaOrder]
  drop: [item: AgendaOrder, target: Target]
  nudge: [item: AgendaOrder, key: ArrowKey]
  confirm: [item: AgendaOrder]
  cancel: []
  showDay: [day: string]
  create: [target: Target]
}>()

const dragging = ref<string | null>(null)
const over = ref<string | null>(null)
const hours = computed(() => Array.from({ length: props.span.end - props.span.start }, (_, index) => props.span.start + index))
const visitsOf = (day: string) => props.visits.get(day) ?? []
const allDay = (day: string) => visitsOf(day).filter((visit) => visit.allDay)
const timedVisits = (day: string) => visitsOf(day).filter((visit) => !visit.allDay)
const layouts = computed(() => new Map(props.days.map((day) => [day, layoutColumn(visitsOf(day))])))
const single = computed(() => props.days.length === 1)
/** The free half hour under the pointer: a "+ 14:00" shows where a click lands. */
const hover = ref<Target | null>(null)

function blockStyle(day: string, visit: Visit<AgendaOrder>) {
  const place = layouts.value.get(day)?.get(visit) ?? { lane: 0, lanes: 1 }
  const minutes = visit.hour * 60 + visit.minute - props.span.start * 60
  const width = 100 / Math.max(1, place.lanes)
  return {
    top: `calc(${minutes / 60} * var(--hour))`,
    left: `calc(${place.lane * width}% + 2px)`,
    width: `calc(${width}% - 4px)`,
  }
}

/** Device and person: on the block of Dia, read only by screen readers on Semana. */
function extraOf(item: AgendaOrder): string {
  const order = item.order
  return [deviceText(item), order.assignedTo?.name ? t('agendaWithPerson', { name: order.assignedTo.name }) : ''].filter(Boolean).join(' · ')
}

/** Tooltip with everything; the accessible name is the visible text (WCAG 2.5.3). */
function blockLabel(visit: Visit<AgendaOrder>): string {
  const order = visit.item.order
  const late = lateText(order, props.now)
  const extra = [deviceText(visit.item), order.assignedTo?.name ? t('agendaWithPerson', { name: order.assignedTo.name }) : ''].filter(Boolean).join(', ')
  const text = t('web.agenda.block', {
    time: visit.allDay ? t('allDay') : timeOf(visit.at),
    customer: order.customer?.name || t('web.orders.noCustomer'),
    order: orderShort(),
    number: order.number ?? '',
    status: late ?? statusText(order.status),
  })
  return extra ? `${text}, ${extra}` : text
}

/** "Uno +1" (app: first device and how many more). */
function deviceText(item: AgendaOrder): string {
  const devices = item.order.devices
  if (!devices.length) return ''
  const first = devices[0]?.name || devices[0]?.serial || ''
  return devices.length > 1 ? `${first} +${devices.length - 1}` : first
}

function onKey(event: KeyboardEvent, item: AgendaOrder) {
  const key = event.key as ArrowKey
  if (event.shiftKey && ['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'].includes(key)) {
    event.preventDefault()
    // Shift + arrow is the move, not the agenda's previous/next day.
    event.stopPropagation()
    emit('nudge', item, key)
  } else if (event.key === 'Enter' && props.pendingId === item.order.id) {
    event.preventDefault()
    emit('confirm', item)
  } else if (event.key === 'Escape' && props.pendingId === item.order.id) {
    event.preventDefault()
    event.stopPropagation()
    emit('cancel')
  }
}

function start(event: DragEvent, item: AgendaOrder) {
  if (!props.canMove(item)) {
    event.preventDefault()
    return
  }
  dragging.value = item.order.id
  event.dataTransfer?.setData('text/plain', item.order.id)
  if (event.dataTransfer) event.dataTransfer.effectAllowed = 'move'
}

function end() {
  dragging.value = null
  over.value = null
}

function find(id: string | null): AgendaOrder | undefined {
  if (!id) return undefined
  for (const list of props.visits.values()) {
    const found = list.find((visit) => visit.item.order.id === id)
    if (found) return found.item
  }
  return undefined
}

/** Where on the column the pointer is, as a half hour of the day. */
function dropOnHours(event: DragEvent, day: string) {
  const item = find(dragging.value ?? event.dataTransfer?.getData('text/plain') ?? null)
  end()
  if (!item) return
  const element = event.currentTarget as HTMLElement
  const rect = element.getBoundingClientRect()
  const perMinute = rect.height / ((props.span.end - props.span.start) * 60)
  // The block is grabbed by its top: the drop point is where it starts.
  const minutes = props.span.start * 60 + (event.clientY - rect.top) / perMinute
  emit('drop', item, { day, minutes: snapMinutes(minutes) })
}

/** The half hour under the pointer on a column, or null over a visit. */
function slotOf(event: MouseEvent, day: string): Target | null {
  const element = event.currentTarget as HTMLElement
  if (event.target !== element) return null
  const rect = element.getBoundingClientRect()
  const perMinute = rect.height / ((props.span.end - props.span.start) * 60)
  return { day, minutes: slotAt(props.span.start * 60 + (event.clientY - rect.top) / perMinute) }
}

function onHover(event: MouseEvent, day: string) {
  if (!props.canCreate || dragging.value) return
  // Deliveries have no hour: the whole day is the slot.
  const slot = slotOf(event, day)
  hover.value = slot && !props.timed ? { day, minutes: null } : slot
}

function onClickHours(event: MouseEvent, day: string) {
  if (!props.canCreate) return
  const slot = slotOf(event, day)
  if (slot) emit('create', props.timed ? slot : { day, minutes: null })
}

function onClickAllDay(event: MouseEvent, day: string) {
  if (props.canCreate && event.target === event.currentTarget) emit('create', { day, minutes: null })
}

const ghostStyle = (minutes: number) => ({ top: `calc(${(minutes - props.span.start * 60) / 60} * var(--hour))` })
const ghostText = (target: Target) => (target.minutes === null ? '+' : `+ ${minutesLabel(target.minutes)}`)

function dropAllDay(day: string, event: DragEvent) {
  const item = find(dragging.value ?? event.dataTransfer?.getData('text/plain') ?? null)
  end()
  if (item) emit('drop', item, { day, minutes: null })
}
</script>

<template>
  <div class="tg" :class="{ 'tg--single': single }" :style="{ '--cols': days.length, '--rows': span.end - span.start }">
    <p id="tg-move-hint" class="sr">{{ t('web.agenda.moveHint') }}</p>
    <div class="tg-head" aria-hidden="true"></div>
    <div v-for="day in days" :key="`h-${day}`" class="tg-head" :class="{ 'is-today': day === today }" :data-head="day">
      <h2 class="tg-day">
        <button v-if="!single" type="button" class="tg-day-btn" :aria-label="t('web.agenda.showDay', { day: dayShort(day) })" @click="emit('showDay', day)">
          <span class="tg-weekday">{{ weekdayShort(day) }}</span> <span class="num">{{ dayMonth(day) }}</span>
        </button>
        <span v-else>{{ dayShort(day) }}</span>
      </h2>
      <span class="sub">{{ t('agendaDayCount', { count: visitsOf(day).length }) }}</span>
    </div>

    <template v-if="days.length">
      <div class="tg-gutter tg-allday-label">{{ t('allDay') }}</div>
      <div
        v-for="day in days"
        :key="`a-${day}`"
        class="tg-allday"
        :class="{ 'is-over': over === `a-${day}`, 'can-create': canCreate }"
        :data-allday="day"
        :title="canCreate ? t('web.agenda.newAt', { when: dayShort(day) }) : undefined"
        @click="onClickAllDay($event, day)"
        @dragover.prevent="over = `a-${day}`"
        @dragleave.self="over = null"
        @drop.prevent="dropAllDay(day, $event)"
      >
        <button
          v-for="visit in allDay(day)"
          :id="`blk-${visit.item.order.id}`"
          :key="visit.item.order.id"
          type="button"
          class="tg-block tg-block--allday"
          :class="{ 'is-pending': pendingId === visit.item.order.id, 'is-late': !!lateText(visit.item.order, now) }"
          :draggable="canMove(visit.item)"
          :data-order="visit.item.order.id"
          :aria-describedby="canMove(visit.item) ? 'tg-move-hint' : undefined"
          :title="blockLabel(visit)"
          @click="emit('open', visit.item)"
          @keydown="onKey($event, visit.item)"
          @dragstart="start($event, visit.item)"
          @dragend="end"
        >
          <span class="sr">{{ t('allDay') }}, </span>
          <strong class="who">{{ visit.item.order.customer?.name || t('web.orders.noCustomer') }}</strong>
          <span class="tg-line"><span class="sr">{{ orderShort() }} </span><span class="num">{{ visit.item.order.number }}</span> · {{ lateText(visit.item.order, now) ?? statusText(visit.item.order.status) }}</span>
          <span v-if="extraOf(visit.item)" class="sr">, {{ extraOf(visit.item) }}</span>
        </button>
      </div>
    </template>

    <div class="tg-gutter tg-hours">
      <span v-for="hour in hours.slice(1)" :key="hour" class="tg-hour" :style="{ top: `calc(${hour - span.start} * var(--hour))` }">{{ hourLabel(hour) }}</span>
    </div>
    <div
      v-for="day in days"
      :key="`c-${day}`"
      class="tg-col"
      :class="{ 'is-over': over === day, 'is-today': day === today, 'can-create': canCreate }"
      :data-day="day"
      role="group"
      :aria-label="dayShort(day)"
      @mousemove="onHover($event, day)"
      @mouseleave="hover = null"
      @click="onClickHours($event, day)"
      @dragover.prevent="over = day"
      @dragleave.self="over = null"
      @drop.prevent="dropOnHours($event, day)"
    >
      <div
        v-if="hover && hover.day === day"
        class="tg-ghost"
        :class="{ 'tg-ghost--day': hover.minutes === null }"
        aria-hidden="true"
        data-testid="agenda-ghost"
        :style="hover.minutes === null ? undefined : ghostStyle(hover.minutes)"
      >{{ ghostText(hover) }}</div>
      <div v-if="day === today && nowMinutes >= span.start * 60 && nowMinutes < span.end * 60" class="tg-now" aria-hidden="true" :style="{ top: `calc(${(nowMinutes - span.start * 60) / 60} * var(--hour))` }"></div>
      <button
        v-for="visit in timedVisits(day)"
        :id="`blk-${visit.item.order.id}`"
        :key="visit.item.order.id"
        type="button"
        class="tg-block"
        :class="{ 'is-pending': pendingId === visit.item.order.id, 'is-late': !!lateText(visit.item.order, now), 'is-fixed': !canMove(visit.item) }"
        :style="blockStyle(day, visit)"
        :draggable="canMove(visit.item)"
        :data-order="visit.item.order.id"
        :aria-describedby="canMove(visit.item) ? 'tg-move-hint' : undefined"
        :title="blockLabel(visit)"
        @click="emit('open', visit.item)"
        @keydown="onKey($event, visit.item)"
        @dragstart="start($event, visit.item)"
        @dragend="end"
      >
        <strong><span class="num">{{ timeOf(visit.at) }}</span> <span class="who">{{ visit.item.order.customer?.name || t('web.orders.noCustomer') }}</span></strong>
        <!-- One line under the name: a one-hour block holds two lines at any text size. -->
        <span class="tg-line"><span class="sr">{{ orderShort() }} </span><span class="num">{{ visit.item.order.number }}</span> · {{ lateText(visit.item.order, now) ?? statusText(visit.item.order.status) }}<span v-if="single && extraOf(visit.item)" class="tg-extra"> · {{ extraOf(visit.item) }}</span></span>
        <span v-if="!single && extraOf(visit.item)" class="sr">, {{ extraOf(visit.item) }}</span>
      </button>
    </div>
  </div>
</template>
