<script setup lang="ts">
// Month on the side (agenda.toggle-month, agenda.day-markers): a dot on each
// day with an order, today in blue and bold, the chosen day filled. Days of
// the neighbor months are there too, with their dots (the app leaves them
// empty: it loads only the chosen day's month).
import { computed } from 'vue'
import { ChevronLeft, ChevronRight } from '@lucide/vue'
import { t } from '@/i18n'
import { addMonths, monthGrid } from '@/lib/agenda/model'
import { dayLong, dayNumber, monthTitle, weekdayLong, weekdayShort } from '@/lib/agenda/text'

const props = defineProps<{ day: string; today: string; firstDay: number; counts: Record<string, number> }>()
const emit = defineEmits<{ pick: [day: string] }>()

const grid = computed(() => monthGrid(props.day, props.firstDay))
const weeks = computed(() => Array.from({ length: 6 }, (_, index) => grid.value.slice(index * 7, index * 7 + 7)))
const month = computed(() => props.day.slice(0, 7))

function label(day: string): string {
  const text = dayLong(day)
  return props.counts[day] ? t('agendaDayHasOrders', { day: text }) : text
}
</script>

<template>
  <section class="cal" :aria-label="t('web.agenda.calendar')">
    <div class="cal-head">
      <h2 class="cal-title" aria-live="polite">{{ monthTitle(day) }}</h2>
      <button type="button" class="icon-btn" :aria-label="t('agendaPreviousMonth')" @click="emit('pick', addMonths(day, -1))"><ChevronLeft aria-hidden="true" /></button>
      <button type="button" class="icon-btn" :aria-label="t('agendaNextMonth')" @click="emit('pick', addMonths(day, 1))"><ChevronRight aria-hidden="true" /></button>
    </div>
    <table class="cal-grid">
      <thead>
        <tr>
          <th v-for="weekday in weeks[0]" :key="weekday" scope="col"><abbr :title="weekdayLong(weekday)">{{ weekdayShort(weekday) }}</abbr></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="week in weeks" :key="week[0]">
          <td v-for="cell in week" :key="cell">
            <button
              type="button"
              class="cal-day"
              :class="{ 'is-other': cell.slice(0, 7) !== month, 'is-today': cell === today, 'is-chosen': cell === day }"
              :aria-label="label(cell)"
              :aria-pressed="cell === day"
              :aria-current="cell === today ? 'date' : undefined"
              :data-day="cell"
              @click="emit('pick', cell)"
            >
              <span>{{ dayNumber(cell) }}</span>
              <span v-if="counts[cell]" class="cal-dot" aria-hidden="true"></span>
            </button>
          </td>
        </tr>
      </tbody>
    </table>
  </section>
</template>
