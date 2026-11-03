<script setup lang="ts">
// Financeiro > Receber (fin.tab.receivable, fin.tab.pick-order): every order
// that still owes (done with a balance, open with a down payment: not the P1
// of the user test), by customer, the oldest debt first. Marking
// orders of one customer opens one receipt or one payment link for them, with
// the total on screen and a confirmation before anything is saved.
import { computed, defineAsyncComponent, onMounted, ref, shallowRef } from 'vue'
import { useRouter } from 'vue-router'
import EmptyState from '@/components/EmptyState.vue'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import PageHead from '@/components/PageHead.vue'
import { t } from '@/i18n'
import { formatDate } from '@/lib/format'
import type { Order } from '@/lib/orders/model'
import { country, deviceLabel, money, orderTitle, statusText } from '@/lib/orders/text'
import { receivableOrders } from '@/lib/receive/data'
import { fromCents, receivableOf, toCents } from '@/lib/receive/model'
import '@/styles/receive.css'

const ReceiveCustomerDialog = defineAsyncComponent(() => import('@/components/orders/receive/ReceiveCustomerDialog.vue'))
const router = useRouter()

const state = ref<'loading' | 'ready' | 'failed'>('loading')
const orders = shallowRef<Order[]>([])
const truncated = ref(false)
const selected = ref<string[]>([])
const receiving = ref<{ id: string; name: string; checked: string[] } | null>(null)

const owed = (order: Order) => receivableOf(order) ?? 0
const groups = computed(() => {
  const map = new Map<string, { id: string; name: string; orders: Order[]; cents: number; oldest: string }>()
  for (const order of orders.value) {
    const id = order.customer?.id ?? `none:${order.id}`
    const group = map.get(id) ?? { id, name: order.customer?.name ?? '', orders: [], cents: 0, oldest: order.createdAt ?? '' }
    group.orders.push(order)
    group.cents += toCents(owed(order))
    if ((order.createdAt ?? '') < group.oldest) group.oldest = order.createdAt ?? ''
    map.set(id, group)
  }
  return [...map.values()]
    .map((group) => ({ ...group, orders: [...group.orders].sort((a, b) => (a.createdAt ?? '').localeCompare(b.createdAt ?? '')) }))
    .sort((a, b) => a.oldest.localeCompare(b.oldest))
})
const total = computed(() => fromCents(groups.value.reduce((sum, group) => sum + group.cents, 0)))
const title = computed(() => (orders.value.length ? t('web.finance.toReceive', { amount: money(total.value), count: groups.value.length }) : t('receiveAllDone')))
const picked = computed(() => orders.value.filter((order) => selected.value.includes(order.id)))
const pickedCustomers = computed(() => new Set(picked.value.map((order) => order.customer?.id ?? order.id)))
const pickedTotal = computed(() => fromCents(picked.value.reduce((sum, order) => sum + toCents(owed(order)), 0)))
const oneCustomer = computed(() => (pickedCustomers.value.size === 1 && picked.value[0]?.customer?.id ? picked.value[0].customer : null))

async function load() {
  state.value = 'loading'
  try {
    const result = await receivableOrders()
    orders.value = result.orders
    truncated.value = result.truncated
    selected.value = selected.value.filter((id) => result.orders.some((order) => order.id === id))
    state.value = 'ready'
  } catch (error) {
    console.warn('finance: receivables not read', error)
    state.value = 'failed'
  }
}
onMounted(load)

const isOn = (order: Order) => selected.value.includes(order.id)
function toggle(order: Order) {
  selected.value = isOn(order) ? selected.value.filter((id) => id !== order.id) : [...selected.value, order.id]
}
const groupOn = (group: { orders: Order[] }) => group.orders.every(isOn)
function toggleGroup(group: { orders: Order[] }) {
  const ids = group.orders.map((order) => order.id)
  selected.value = groupOn(group) ? selected.value.filter((id) => !ids.includes(id)) : [...new Set([...selected.value, ...ids])]
}

function receive() {
  const customer = oneCustomer.value
  if (!customer?.id) return
  receiving.value = { id: customer.id, name: customer.name ?? '', checked: [...selected.value] }
}

function receiveGroup(group: { id: string; name: string; orders: Order[] }) {
  if (group.id.startsWith('none:')) return openOrder(group.orders[0]!.id)
  receiving.value = { id: group.id, name: group.name, checked: group.orders.map((order) => order.id) }
}

async function received() {
  receiving.value = null
  selected.value = []
  await load()
}

function openOrder(id: string) {
  void router.push({ path: '/', query: { order: id } })
}
</script>

<template>
  <div class="finance" data-testid="finance-receive">
    <PageHead :title="title" :sub="orders.length ? t('web.finance.receiveSub') : undefined" />
    <nav class="tabs fin-tabs" :aria-label="t('web.finance.parts')">
      <span aria-current="page" class="fin-tab">{{ t('receiveTitle') }} <span v-if="orders.length" class="num">{{ orders.length }}</span></span>
    </nav>
    <LoadingState v-if="state === 'loading'" />
    <ErrorState v-else-if="state === 'failed'" :retry="load" />
    <EmptyState v-else-if="!orders.length" :title="t('receiveAllDone')" :body="t('web.finance.emptyBody')">
      <button type="button" class="btn" @click="router.push('/')">{{ t('web.finance.seeOrders') }}</button>
    </EmptyState>
    <template v-else>
      <div class="toolbar">
        <div v-if="picked.length" class="batchbar" role="region" :aria-label="t('web.batch.label')">
          <strong>{{ t('web.finance.picked', { count: picked.length, amount: money(pickedTotal) }) }}</strong>
          <button v-if="oneCustomer" type="button" class="btn btn--primary" data-testid="finance-receive-picked" @click="receive">{{ t('web.batch.receive', { name: oneCustomer.name ?? '' }) }}</button>
          <span v-else class="sub" role="status">{{ t('web.finance.oneCustomer') }}</span>
          <button type="button" class="btn btn--ghost" @click="selected = []">{{ t('clear') }}</button>
        </div>
      </div>
      <p v-if="truncated" class="list-note">{{ t('web.finance.truncated') }}</p>
      <div class="recv">
        <table class="grid">
          <caption class="sr">{{ title }}</caption>
          <thead>
            <tr>
              <th class="c-check" scope="col"><span class="sr">{{ t('web.finance.pick') }}</span></th>
              <th scope="col">{{ t('web.finance.customerAndOrder') }}</th>
              <th class="c-money" scope="col">{{ t('financialToReceive') }}</th>
            </tr>
          </thead>
          <tbody v-for="group in groups" :key="group.id">
            <tr class="group-row recv-group">
              <td class="c-check">
                <input class="check" type="checkbox" :checked="groupOn(group)" :aria-label="t('web.finance.pickAll', { name: group.name })" @change="toggleGroup(group)" />
              </td>
              <th scope="rowgroup">
                {{ group.name || '—' }}
                <button type="button" class="link" data-testid="finance-receive-group" @click="receiveGroup(group)">{{ t('receiveTitle') }}</button>
              </th>
              <td class="c-money"><span class="num">{{ money(fromCents(group.cents)) }}</span></td>
            </tr>
            <tr v-for="order in group.orders" :key="order.id" :class="{ 'is-selected': isOn(order) }" data-testid="finance-row">
              <td class="c-check"><input class="check" type="checkbox" :checked="isOn(order)" :aria-label="t('web.finance.pickOrder', { order: orderTitle(order) })" @change="toggle(order)" /></td>
              <td>
                <button type="button" class="link" @click="openOrder(order.id)">{{ orderTitle(order) }}</button>
                <span v-if="order.devices[0]" class="sub"> · {{ order.devices[0].name || deviceLabel() }}</span>
                <span v-if="order.status !== 'done'" class="sub"> · {{ statusText(order.status) }}</span>
                <span v-if="order.createdAt" class="sub"> · {{ formatDate(order.createdAt, country()) }}</span>
              </td>
              <td class="c-money"><span class="num">{{ money(owed(order)) }}</span></td>
            </tr>
          </tbody>
        </table>
      </div>
    </template>
    <ReceiveCustomerDialog v-if="receiving" :customer-id="receiving.id" :customer-name="receiving.name" :checked="receiving.checked" @done="received" @close="receiving = null" />
  </div>
</template>
