<script setup lang="ts">
// Visits one after another, grouped by day (agenda.list): the phone's day list
// and the "Lista" of a week on a big screen. Days without visits are left out.
import { computed } from 'vue'
import StatusLabel from '@/components/StatusLabel.vue'
import { t } from '@/i18n'
import type { AgendaOrder } from '@/lib/agenda/data'
import type { Visit } from '@/lib/agenda/model'
import { dayLong, dayShort, timeOf } from '@/lib/agenda/text'
import { lateText, statusText } from '@/lib/orders/text'

const props = defineProps<{
  days: string[]
  visits: Map<string, Visit<AgendaOrder>[]>
  today: string
  now: Date
  /** Week list: long day titles, "Hoje" marked. */
  long?: boolean
}>()
const emit = defineEmits<{ open: [item: AgendaOrder] }>()

const groups = computed(() =>
  props.days.map((day) => ({ day, visits: props.visits.get(day) ?? [] })).filter((group) => group.visits.length),
)

function lineOf(item: AgendaOrder): string {
  const order = item.order
  const devices = order.devices
  const device = devices.length ? `${devices[0]?.name || devices[0]?.serial || ''}${devices.length > 1 ? ` +${devices.length - 1}` : ''}` : ''
  return [device, order.assignedTo?.name ? t('agendaWithPerson', { name: order.assignedTo.name }) : ''].filter(Boolean).join(' · ')
}

const visitTime = (visit: Visit<AgendaOrder>) => (visit.allDay ? t('allDay') : timeOf(visit.at))
</script>

<template>
  <div class="ag-list" :class="{ 'ag-list--long': long }" data-testid="agenda-list">
    <section v-for="group in groups" :key="group.day" :aria-labelledby="`ag-day-${group.day}`" :data-list-day="group.day">
      <h2 :id="`ag-day-${group.day}`" class="ag-day-title" :class="{ 'is-today': group.day === today }">
        {{ long ? dayLong(group.day) : dayShort(group.day) }}
        <span class="sub">· <template v-if="long && group.day === today">{{ t('today') }} · </template>{{ t('agendaDayCount', { count: group.visits.length }) }}</span>
      </h2>
      <ul>
        <li v-for="visit in group.visits" :key="visit.item.order.id">
          <button type="button" class="ag-row" :data-order="visit.item.order.id" @click="emit('open', visit.item)">
            <span class="ag-row-top"><span class="who">{{ visit.item.order.customer?.name || t('web.orders.noCustomer') }}</span><span class="num">{{ visitTime(visit) }}</span></span>
            <StatusLabel
              :status="visit.item.order.status"
              :late-text="lateText(visit.item.order, now)"
              :text="statusText(visit.item.order.status)"
            > · {{ visit.item.order.number ?? '' }}</StatusLabel>
            <span v-if="lineOf(visit.item)" class="sub">{{ lineOf(visit.item) }}</span>
          </button>
        </li>
      </ul>
    </section>
  </div>
</template>
