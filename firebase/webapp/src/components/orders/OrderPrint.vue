<script setup lang="ts">
// Own print sheet, light theme, no navigation (WEB_APP_DESIGN, Impressão).
// The browser saves it as PDF. Values only for who sees them.
import { t } from '@/i18n'
import { formatDate } from '@/lib/format'
import { totals, type Order } from '@/lib/orders/model'
import { country, deviceLabel, lineKindText, money, orderTitle, statusText } from '@/lib/orders/text'
import { session } from '@/lib/session'

const props = defineProps<{ order: Order }>()
const sum = totals(props.order)
</script>

<template>
  <Teleport to="body">
    <article class="print-sheet" data-testid="print-sheet">
      <header>
        <p class="print-company">{{ session.company?.name }}</p>
        <h1>{{ orderTitle(order) }}</h1>
        <p>{{ statusText(order.status) }} · {{ formatDate(order.createdAt, country()) }}</p>
      </header>
      <dl>
        <dt>{{ t('customer') }}</dt>
        <dd>{{ order.customer?.name }}</dd>
        <template v-if="order.devices.length">
          <dt>{{ deviceLabel() }}</dt>
          <dd>{{ order.devices.map((d) => [d.name, d.serial].filter(Boolean).join(' · ')).join(', ') }}</dd>
        </template>
      </dl>
      <table>
        <thead>
          <tr>
            <th scope="col">{{ t('orderServicesAndParts') }}</th>
            <th scope="col">{{ t('orderItemQuantity') }}</th>
            <th v-if="order.showsMoney" scope="col">{{ t('total') }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(line, index) in order.lines" :key="line.id ?? index">
            <td>{{ line.name }} <small>({{ lineKindText(line.kind) }})</small><br v-if="line.description && line.description !== line.name" /><small>{{ line.description !== line.name ? line.description : '' }}</small></td>
            <td>{{ line.quantity ?? 1 }}</td>
            <td v-if="order.showsMoney">{{ (line.kind === 'product' ? line.total : line.value) === null ? t('catalogNoPrice') : money(line.kind === 'product' ? line.total : line.value) }}</td>
          </tr>
        </tbody>
      </table>
      <p v-if="order.showsMoney" class="print-total">{{ t('orderTotalLabel') }}: {{ money(sum.total) }}</p>
    </article>
  </Teleport>
</template>
