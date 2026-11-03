<script setup lang="ts">
// Financeiro > Resumo (fin.tab.*): Recebido and Vendido of the chosen month,
// A receber and Em andamento of today. Every number comes from the server
// (GET /v1/app/finance/summary): nothing is added up in the browser.
// The month is in the URL (?month=2026-03) and never goes to the future.
import { computed, onBeforeUnmount, onMounted, ref, shallowRef, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ChevronLeft, ChevronRight } from '@lucide/vue'
import EmptyState from '@/components/EmptyState.vue'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import PageHead from '@/components/PageHead.vue'
import StatusLabel from '@/components/StatusLabel.vue'
import FinanceTabs from '@/components/finance/FinanceTabs.vue'
import { t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { financeSummary, type FinanceRow, type FinanceSummary } from '@/lib/finance/data'
import { monthOf, periodOf, shiftMonth } from '@/lib/finance/period'
import { monthName, monthYear, today } from '@/lib/finance/text'
import { formatDayMonth } from '@/lib/format'
import { monthInvoices, nfseSettings } from '@/lib/nfse/data'
import { monthList } from '@/lib/nfse/model'
import { country, money, orderShort } from '@/lib/orders/text'
import { can } from '@/lib/session'
import { registerShortcut } from '@/lib/shortcuts'
import '@/styles/finance.css'

type List = 'received' | 'sold' | 'receivable' | 'progress'
const LISTS: List[] = ['received', 'sold', 'receivable', 'progress']

const route = useRoute()
const router = useRouter()

const current = computed(() => monthOf(today()))
const month = computed(() => {
  const asked = typeof route.query.month === 'string' && /^\d{4}-(0[1-9]|1[0-2])$/.test(route.query.month) ? route.query.month : null
  return asked && asked <= current.value ? asked : current.value
})
const list = computed<List>(() => (LISTS.includes(route.query.list as List) ? (route.query.list as List) : 'received'))
const isCurrent = computed(() => month.value === current.value)

const state = ref<'loading' | 'ready' | 'failed'>('loading')
const failure = ref('')
const summary = shallowRef<FinanceSummary | null>(null)
/** The month on screen while another one is on its way (the old numbers stay, marked busy). */
const busy = ref(false)
let asked = 0

async function load() {
  const run = ++asked
  const wanted = month.value
  busy.value = state.value === 'ready'
  if (!busy.value) state.value = 'loading'
  try {
    const data = await financeSummary(wanted)
    // A late answer for a month already left is dropped (the app's guard, fin.tab.month).
    if (run !== asked) return
    summary.value = data
    state.value = 'ready'
  } catch (error) {
    if (run !== asked) return
    failure.value = t(errorMessageKey(error))
    // Pulling again keeps what was on screen; only the first load shows the error.
    if (state.value !== 'ready') state.value = 'failed'
    else failure.value = ''
  } finally {
    if (run === asked) busy.value = false
  }
}

watch(month, () => void load())
onMounted(() => {
  void load()
  void loadInvoices()
  window.addEventListener('focus', onFocus)
})
onBeforeUnmount(() => window.removeEventListener('focus', onFocus))
/** Coming back from the app or another tab: the numbers may have changed (app reloads on return). */
function onFocus() {
  if (state.value === 'ready') void load()
}

function go(query: Record<string, string | undefined>) {
  void router.replace({ query: { ...route.query, ...query } })
}
const step = (by: number) => {
  const next = shiftMonth(month.value, by)
  if (next > current.value) return
  go({ month: next === current.value ? undefined : next })
}
const toToday = () => go({ month: undefined })

const removers: (() => void)[] = []
onMounted(() =>
  removers.push(
    registerShortcut({ keys: 'arrowleft', label: 'financialPreviousMonth', run: () => step(-1) }),
    registerShortcut({ keys: 'arrowright', label: 'financialNextMonth', run: () => step(1) }),
  ),
)
onBeforeUnmount(() => removers.forEach((remove) => remove()))

const name = computed(() => monthName(month.value))
const title = computed(() => {
  const received = summary.value?.received.total ?? 0
  if (!received) return t('web.fin.titleNothing', { month: name.value })
  return isCurrent.value
    ? t('web.fin.titleSoFar', { month: name.value, amount: money(received) })
    : t('web.fin.titleMonth', { month: name.value, amount: money(received) })
})

// ---------------------------------------------------------------------------
// The list under the cards
// ---------------------------------------------------------------------------

interface Line {
  key: string
  row: FinanceRow
  sub: string
  amount: number
}
const customerName = (row: FinanceRow) => row.customer?.name || t('web.fin.noCustomer')
const lines = computed<Line[]>(() => {
  const s = summary.value
  if (!s) return []
  if (list.value === 'received') return s.received.orders.map((row) => ({ key: row.id, row, sub: '', amount: row.amount }))
  if (list.value === 'sold') return s.sold.orders.map((row) => ({ key: row.id, row, sub: row.createdAt ? formatDayMonth(row.createdAt, country()) : '', amount: row.amount }))
  if (list.value === 'progress') return s.progress.orders.map((row) => ({ key: row.id, row, sub: row.device ?? '', amount: row.amount }))
  return []
})
const listTitle = computed(() => {
  if (list.value === 'received') return t('web.fin.listReceived', { month: name.value })
  if (list.value === 'sold') return t('web.fin.listSold', { month: name.value })
  if (list.value === 'progress') return t('financialInProgress')
  return t('financialReceivable')
})
const emptyText = computed(() => {
  if (list.value === 'received') return t('financialEmptyReceived', { month: name.value })
  if (list.value === 'sold') return t('financialEmptyMonth', { month: name.value })
  if (list.value === 'progress') return t('financialEmptyInProgress')
  return t('financialEmptyReceivable')
})
/** Rótulos "Concluídas"/"Em aberto" only when both groups exist (fin.tab.receivable). */
const bothGroups = computed(() => !!summary.value?.receivable.debtors.length && !!summary.value?.receivable.deposits.length)

function openOrder(row: FinanceRow) {
  void router.push({ path: '/', query: { order: row.id } })
}

// ---------------------------------------------------------------------------
// Notas fiscais of the month (fin.tab.nfse-row): a count, never money
// ---------------------------------------------------------------------------

const notas = ref<{ issued: number; attention: number } | null>(null)
async function loadInvoices() {
  if (!can('chargeOrder')) return
  try {
    const settings = await nfseSettings()
    if (!settings.available) return
    const invoices = await monthInvoices(month.value, today())
    const result = monthList(invoices, month.value, today())
    notas.value = { issued: result.issuedCount, attention: result.attention.length }
  } catch (error) {
    // A failed read never shows "0" (the app's D10): the row stays out.
    console.warn('finance: invoices not read', error)
    notas.value = null
  }
}
watch(month, () => void loadInvoices())

const reportLink = computed(() => {
  const days = periodOf('month', 0, `${month.value}-01`)
  return { path: '/finance/report', query: isCurrent.value ? {} : { from: days.from, to: days.to } }
})
</script>

<template>
  <div class="finance" data-testid="finance-summary">
    <PageHead :title="state === 'ready' ? title : t('financial')" :sub="t('web.fin.sub')">
      <div class="fin-month" role="group" :aria-label="t('web.fin.month')">
        <button type="button" class="icon-btn" :aria-label="t('financialPreviousMonth')" data-testid="fin-prev" @click="step(-1)">
          <ChevronLeft :size="18" aria-hidden="true" />
        </button>
        <button
          type="button"
          class="fin-month-label"
          :disabled="isCurrent"
          :aria-label="isCurrent ? monthYear(month) : t('web.fin.backToToday', { month: monthYear(month) })"
          data-testid="fin-month"
          @click="toToday"
        >
          <span aria-live="polite">{{ monthYear(month) }}</span>
        </button>
        <button type="button" class="icon-btn" :disabled="isCurrent" :aria-label="t('financialNextMonth')" data-testid="fin-next" @click="step(1)">
          <ChevronRight :size="18" aria-hidden="true" />
        </button>
      </div>
    </PageHead>
    <FinanceTabs />
    <LoadingState v-if="state === 'loading'" />
    <ErrorState v-else-if="state === 'failed'" :body="failure" :retry="load" />
    <div v-else-if="summary" class="fin" :aria-busy="busy ? 'true' : 'false'">
      <p v-if="summary.truncated" class="list-note" role="note">{{ t('web.fin.truncated') }}</p>
      <div class="fin-cards">
        <section class="fin-group" :aria-labelledby="'fin-g-month'">
          <h2 id="fin-g-month">{{ t('web.fin.inMonth', { month: name }) }}</h2>
          <div>
            <button type="button" class="fin-card" :aria-pressed="list === 'received'" data-testid="fin-card-received" @click="go({ list: undefined })">
              <span>{{ t('received') }}</span><b class="num">{{ money(summary.received.total) }}</b>
              <small>{{ t('web.fin.payments', { count: summary.received.orders.length }) }}</small>
            </button>
            <button type="button" class="fin-card" :aria-pressed="list === 'sold'" data-testid="fin-card-sold" @click="go({ list: 'sold' })">
              <span>{{ t('financialSold') }}</span><b class="num">{{ money(summary.sold.total) }}</b>
              <small>{{ t('web.fin.orders', { count: summary.sold.orders.length, order: orderShort() }) }}</small>
            </button>
          </div>
        </section>
        <section class="fin-group" aria-labelledby="fin-g-today">
          <h2 id="fin-g-today">{{ t('financialToday') }}</h2>
          <div>
            <button type="button" class="fin-card" :aria-pressed="list === 'receivable'" data-testid="fin-card-receivable" @click="go({ list: 'receivable' })">
              <span>{{ t('financialReceivable') }}</span><b class="num">{{ money(summary.receivable.total) }}</b>
              <small>{{ summary.receivable.customers ? t('web.fin.customers', { count: summary.receivable.customers }) : t('web.fin.allPaid') }}</small>
            </button>
            <button type="button" class="fin-card" :aria-pressed="list === 'progress'" data-testid="fin-card-progress" @click="go({ list: 'progress' })">
              <span>{{ t('financialInProgress') }}</span><b class="num">{{ money(summary.progress.total) }}</b>
              <small>{{ t('web.fin.orders', { count: summary.progress.orders.length, order: orderShort() }) }}</small>
            </button>
          </div>
        </section>
      </div>

      <div class="fin-links">
        <RouterLink class="btn" :to="reportLink" data-testid="fin-report">{{ t('web.fin.seeReport') }}</RouterLink>
        <RouterLink class="btn btn--ghost" :to="{ path: '/finance/report', query: { pick: '1' } }" data-testid="fin-other-period">{{ t('financialOtherPeriod') }}</RouterLink>
        <RouterLink v-if="notas" class="fin-nfse" :to="{ path: '/invoices', query: isCurrent ? {} : { month } }" data-testid="fin-nfse-row">
          <span>{{ t('nfseListTitle') }} · <span class="num">{{ notas.issued }}</span></span>
          <span v-if="notas.attention" class="fin-nfse-alert">{{ t('nfseListAttentionCount', { count: notas.attention }) }}</span>
        </RouterLink>
      </div>

      <section class="fin-list" aria-labelledby="fin-list-title" data-testid="fin-list">
        <h2 id="fin-list-title">{{ listTitle }}</h2>
        <template v-if="list === 'receivable'">
          <p v-if="!summary.receivable.debtors.length && !summary.receivable.deposits.length" class="muted fin-none">{{ emptyText }}</p>
          <template v-if="summary.receivable.debtors.length">
            <h3 v-if="bothGroups" class="fin-sub">{{ t('financialReceivableCompleted') }}</h3>
            <ul class="fin-rows">
              <li v-for="debtor in summary.receivable.debtors" :key="debtor.key">
                <RouterLink
                  class="fin-row"
                  :to="debtor.customer?.id ? { path: '/finance/receive', query: { customer: debtor.customer.id } } : { path: '/', query: { order: debtor.orders[0]!.id } }"
                >
                  <span>
                    <span class="who">{{ debtor.customer?.name || t('web.fin.noCustomer') }}</span>
                    <span class="sub"> · {{ t('web.fin.orders', { count: debtor.orders.length, order: orderShort() }) }}<template v-if="debtor.since"> · {{ t('financialSince', { date: formatDayMonth(debtor.since, country()) }) }}</template></span>
                  </span>
                  <span class="num">{{ money(debtor.amount) }}</span>
                </RouterLink>
              </li>
            </ul>
          </template>
          <template v-if="summary.receivable.deposits.length">
            <h3 v-if="bothGroups" class="fin-sub">{{ t('financialReceivableOpen') }}</h3>
            <ul class="fin-rows">
              <li v-for="row in summary.receivable.deposits" :key="row.id">
                <button type="button" class="fin-row" @click="openOrder(row)">
                  <span><span class="who">{{ customerName(row) }}</span> <span class="sub num">{{ t('web.fin.orderNumber', { order: orderShort(), number: row.number ?? '' }) }}</span></span>
                  <span class="num">{{ money(row.amount) }}</span>
                </button>
              </li>
            </ul>
          </template>
        </template>
        <template v-else>
          <p v-if="!lines.length" class="muted fin-none" data-testid="fin-empty">{{ emptyText }}</p>
          <ul v-else class="fin-rows">
            <li v-for="line in lines" :key="line.key">
              <button type="button" class="fin-row" data-testid="fin-row" @click="openOrder(line.row)">
                <span>
                  <span class="who">{{ customerName(line.row) }}</span>
                  <span class="sub num"> {{ t('web.fin.orderNumber', { order: orderShort(), number: line.row.number ?? '' }) }}</span>
                  <span v-if="line.sub" class="sub"> · {{ line.sub }}</span>
                  <StatusLabel v-if="list === 'progress' && line.row.status" class="fin-row-status" :status="line.row.status" />
                </span>
                <span class="num">{{ money(line.amount) }}</span>
              </button>
            </li>
          </ul>
        </template>
      </section>
    </div>
    <EmptyState v-else :title="t('financialLoadError')" />
  </div>
</template>
