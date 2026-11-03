<script setup lang="ts">
// Skeleton of the list: real query, side panel in the URL and the `list-visible`
// mark the performance test reads. No prices here: who cannot see values must
// get a server projection (ADR-001), so this reads Firestore only for who can.
import { computed, nextTick, onBeforeUnmount, onMounted, ref, shallowRef } from 'vue'
import { X } from '@lucide/vue'
import EmptyState from '@/components/EmptyState.vue'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import PageHead from '@/components/PageHead.vue'
import StatusLabel from '@/components/StatusLabel.vue'
import { t } from '@/i18n'
import { formatDate } from '@/lib/format'
import { mark } from '@/lib/marks'
import { FIRST_PAGE, PAGE_SIZE, firstOrdersPage, nextOrdersPage, onFreshFirstPage, type OrderRow } from '@/lib/orders-query'
import { useRoutePanel } from '@/lib/route-layer'
import { can, session } from '@/lib/session'
import { announce } from '@/lib/ui'

const rows = shallowRef<OrderRow[]>([])
const state = ref<'loading' | 'ready' | 'failed' | 'projectionPending'>('loading')
const panel = useRoutePanel('order')
const openOrder = computed(() => rows.value.find((row) => row.id === panel.value.value) ?? null)
const country = computed(() => session.company?.country)

async function load() {
  state.value = 'loading'
  if (!can('viewPrices')) {
    state.value = 'projectionPending'
    return
  }
  const query = { companyId: session.companyId as string, createdBy: can('viewAllOrders') ? null : session.uid }
  try {
    rows.value = await firstOrdersPage(query)
    state.value = 'ready'
    await nextTick()
    requestAnimationFrame(() => mark('list-visible'))
    // The rest of the page after the first paint.
    const last = rows.value[rows.value.length - 1]
    if (last && rows.value.length === FIRST_PAGE) {
      rows.value = [...rows.value, ...(await nextOrdersPage(query, last, PAGE_SIZE - FIRST_PAGE))]
    }
    announce(t('web.orders.count', { count: rows.value.length }))
  } catch (error) {
    console.error('orders: list failed', error)
    state.value = 'failed'
  }
}

// Shown from this browser's copy: replace the first page when the server answers.
onFreshFirstPage((fresh) => {
  rows.value = [...fresh, ...rows.value.slice(fresh.length)]
})
onBeforeUnmount(() => onFreshFirstPage(undefined))
onMounted(load)
</script>

<template>
  <PageHead :title="t('orders')" :sub="state === 'ready' ? t('web.orders.count', { count: rows.length }) : undefined" />
  <div class="workspace" :class="{ 'has-panel': panel.value.value }">
    <div class="list-pane">
      <LoadingState v-if="state === 'loading'" />
      <ErrorState v-else-if="state === 'failed'" :retry="load" />
      <EmptyState v-else-if="state === 'projectionPending'" :title="t('web.placeholder.title')" :body="t('web.placeholder.body')" />
      <EmptyState v-else-if="!rows.length" :title="t('web.orders.empty')" />
      <table v-else class="grid" data-testid="orders-table">
        <thead>
          <tr>
            <th class="c-num" scope="col">{{ t('web.orders.number') }}</th>
            <th scope="col">{{ t('customer') }}</th>
            <th scope="col">{{ t('status') }}</th>
            <th class="c-when" scope="col">{{ t('date') }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="row in rows" :key="row.id" :class="{ 'is-open': row.id === panel.value.value }">
            <td class="c-num num">{{ row.number }}</td>
            <td>
              <button type="button" class="row-btn who" @click="panel.open(row.id)">{{ row.customer?.name }}</button>
            </td>
            <td><StatusLabel :status="row.status ?? 'quote'" /></td>
            <td class="c-when num">{{ formatDate(row.createdAt, country) }}</td>
          </tr>
        </tbody>
      </table>
    </div>
    <aside v-if="panel.value.value" class="panel" :aria-label="t('web.orders.panel')">
      <div class="panel-top">
        <span class="num muted">{{ openOrder?.number }}</span>
        <span class="spacer"></span>
        <button type="button" class="icon-btn" :aria-label="t('close')" @click="panel.close()">
          <X :size="18" aria-hidden="true" />
        </button>
      </div>
      <div class="panel-body">
        <h2 class="panel-title">{{ openOrder?.customer?.name }}</h2>
        <StatusLabel v-if="openOrder" :status="openOrder.status ?? 'quote'" />
      </div>
    </aside>
  </div>
</template>
