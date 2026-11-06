<script setup lang="ts">
// The day's sheet of a work stage (docs/WORK_STAGES.md): the cards of its
// column in the board's order, with only the services done there and a box to
// tick. Never values. Same print sheet as OrderPrint (WEB_APP_DESIGN, Impressão).
import { t } from '@/i18n'
import { formatDateLong } from '@/lib/format'
import { deviceSummary, type Order } from '@/lib/orders/model'
import { linesForStage, type WorkStage } from '@/lib/orders/stages'
import { country, orderShort } from '@/lib/orders/text'
import { session } from '@/lib/session'

defineProps<{ stage: WorkStage; orders: Order[] }>()
const today = new Date().toISOString()
</script>

<template>
  <Teleport to="body">
    <article class="print-sheet stage-sheet" data-testid="stage-print">
      <header>
        <p class="print-company">{{ session.company?.name }}</p>
        <h1>{{ stage.name }}</h1>
        <p>{{ formatDateLong(today, country()) }} · {{ t('web.board.printCount', { count: orders.length }) }}</p>
      </header>
      <table>
        <thead>
          <tr>
            <th scope="col">#</th>
            <th scope="col">{{ orderShort() }}</th>
            <th scope="col">{{ t('web.board.printTodo') }}</th>
            <th scope="col">{{ t('web.board.printDone') }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(order, index) in orders" :key="order.id">
            <td>{{ index + 1 }}</td>
            <td><strong>{{ order.number }}</strong> · {{ order.customer?.name }}<br /><small>{{ deviceSummary(order) }}</small></td>
            <td>
              <template v-for="(line, at) in linesForStage(order, stage)" :key="line.id ?? at">
                {{ line.name }}<small v-if="line.description && line.description !== line.name"> · {{ line.description }}</small><br />
              </template>
            </td>
            <td><span class="stage-box" aria-hidden="true"></span></td>
          </tr>
        </tbody>
      </table>
    </article>
  </Teleport>
</template>
