<script setup lang="ts">
// Financeiro > Relatório (fin.report.*). The period, the chosen customer and the
// payment filter are in the URL; every number comes from the server
// (GET /v1/app/finance/report). Extra of the large screen: CSV, XLSX and print,
// always with only what the server answered to this role.
import { computed, defineAsyncComponent, onBeforeUnmount, onMounted, ref, shallowRef, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { CalendarDays, ChevronLeft, ChevronRight, Check } from '@lucide/vue'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import PageHead from '@/components/PageHead.vue'
import FinanceTabs from '@/components/finance/FinanceTabs.vue'
import { loadOrderTexts, t } from '@/i18n'
import { errorMessageKey } from '@/lib/api'
import { financeReport, type FinanceReport, type ReportCustomer } from '@/lib/finance/data'
import { CSV_TYPE, XLSX_TYPE, download, toCsv, toXlsx, type Cell } from '@/lib/finance/export'
import { isDay, periodOf, type Days, type PeriodKind } from '@/lib/finance/period'
import { dayText, periodLabel, periodPhrase, today } from '@/lib/finance/text'
import { countryFormat, formatDate, formatPercent } from '@/lib/format'
import { country, money, orderShort, statusText } from '@/lib/orders/text'
import { segmentLabels } from '@/lib/segments'
import { LAYER_PARAM, useRoutePanel, withoutParam } from '@/lib/route-layer'
import { registerShortcut } from '@/lib/shortcuts'
import { showToast } from '@/lib/toast'
import { ensurePlanFeature, usePlanFeature } from '@/lib/plan-feature-gate'
import { PLAN_NAME } from '@/lib/plan-limits'
import '@/styles/finance.css'

const PeriodDialog = defineAsyncComponent(() => import('@/components/finance/PeriodDialog.vue'))
// The order opens beside the report, as in the other screens (B6 of #525).
const OrderDetail = defineAsyncComponent(() => Promise.all([import('@/components/orders/OrderDetail.vue'), loadOrderTexts()]).then(([m]) => m))

const route = useRoute()
const router = useRouter()
const KINDS: PeriodKind[] = ['day', 'week', 'month', 'year']
const SHOWN = 5

const todayDay = today()
const custom = computed<Days | null>(() => {
  const { from, to } = route.query
  return isDay(from) && isDay(to) && from <= to ? { from, to } : null
})
const kind = computed<PeriodKind | 'custom'>(() => (custom.value ? 'custom' : KINDS.includes(route.query.kind as PeriodKind) ? (route.query.kind as PeriodKind) : 'month'))
const offset = computed(() => {
  const value = Number(route.query.offset ?? 0)
  return Number.isInteger(value) && value < 0 ? value : 0
})
const days = computed<Days>(() => custom.value ?? periodOf(kind.value as PeriodKind, offset.value, todayDay))
const customer = computed(() => (typeof route.query.customer === 'string' && route.query.customer ? route.query.customer : null))
const payment = computed(() => (route.query.payment === 'paid' || route.query.payment === 'unpaid' ? route.query.payment : null))

const state = ref<'loading' | 'ready' | 'failed'>('loading')
const failure = ref('')
const report = shallowRef<FinanceReport | null>(null)
const busy = ref(false)
let asked = 0

async function load() {
  const run = ++asked
  busy.value = state.value === 'ready'
  if (!busy.value) state.value = 'loading'
  try {
    const data = await financeReport({ ...days.value, customer: customer.value, payment: payment.value })
    if (run !== asked) return
    report.value = data
    state.value = 'ready'
  } catch (error) {
    if (run !== asked) return
    failure.value = t(errorMessageKey(error))
    state.value = 'failed'
  } finally {
    if (run === asked) busy.value = false
  }
}
watch(() => [days.value.from, days.value.to, customer.value, payment.value], () => void load())

const picking = ref(route.query.pick === '1')
onMounted(() => void load())

function go(query: Record<string, string | undefined>) {
  void router.replace({ query: { ...route.query, ...query } })
}
/** Presets keep the filters and go back to the current period (fin.report.period). */
function choose(next: PeriodKind) {
  go({ kind: next === 'month' ? undefined : next, offset: undefined, from: undefined, to: undefined })
}
function step(by: number) {
  if (kind.value === 'custom') return
  const next = offset.value + by
  if (next > 0) return
  go({ offset: next === 0 ? undefined : String(next) })
}
/** The label goes back to the current period and clears the filters (fin.report.reset-period). */
function reset() {
  void router.replace({ query: kind.value === 'custom' || kind.value === 'month' ? {} : { kind: kind.value } })
}
/**
 * The dates go to the URL first, in the same step that takes the dialog's own
 * entry out (the dialog then closes by itself): two replaces at once lost one.
 */
async function applyDays(picked: Days) {
  await router.replace({
    query: { ...withoutParam(route.query, LAYER_PARAM), from: picked.from, to: picked.to, kind: undefined, offset: undefined, pick: undefined },
  })
  picking.value = false
}
function closePicker() {
  picking.value = false
  if (route.query.pick) go({ pick: undefined })
}
function onKind(event: Event) {
  const value = (event.target as HTMLSelectElement).value
  if (value === 'custom') picking.value = true
  else choose(value as PeriodKind)
}

const removers: (() => void)[] = []
onMounted(() =>
  removers.push(
    registerShortcut({ keys: 'arrowleft', label: 'reportPreviousPeriod', run: () => step(-1) }),
    registerShortcut({ keys: 'arrowright', label: 'reportNextPeriod', run: () => step(1) }),
  ),
)
onBeforeUnmount(() => removers.forEach((remove) => remove()))

// ---------------------------------------------------------------------------
// What the screen shows
// ---------------------------------------------------------------------------

const paidLabel = computed(() => segmentLabels()['financial.total_paid'] ?? t('financialAlreadyPaid'))
const remainingLabel = computed(() => segmentLabels()['financial.remaining'] ?? t('financialReceivable'))
const label = computed(() => periodLabel(kind.value, offset.value, days.value))
const chosenCustomer = computed(() => (customer.value ? (report.value?.customers.find((c) => (c.id ?? 'none') === customer.value) ?? null) : null))
const customerName = (c: { name: string | null; id: string | null }) => c.name || (c.id ? t('web.fin.noName') : t('web.fin.noCustomer'))

const title = computed(() => {
  const r = report.value
  if (!r || !r.count) return t('web.report.titleEmpty', { period: periodPhrase(days.value) })
  return t('web.report.title', { amount: money(r.revenue), period: periodPhrase(days.value) })
})
const ticket = computed(() => (report.value?.count ? report.value.revenue / report.value.count : 0))
const composition = computed(() => {
  const c = report.value?.composition
  const sum = (c?.services ?? 0) + (c?.products ?? 0)
  if (!c || sum <= 0) return null
  return { ...c, servicesPercent: (c.services / sum) * 100, productsPercent: (c.products / sum) * 100 }
})
const paidPercent = computed(() => (report.value?.revenue ? (report.value.paid / report.value.revenue) * 100 : 0))

/** The value of a customer under the payment filter; zero leaves the ranking (fin.report.payment-filter). */
const valueOf = (c: ReportCustomer) => (payment.value === 'paid' ? c.paid : payment.value === 'unpaid' ? c.remaining : c.total)
const ranking = computed(() =>
  [...(report.value?.customers ?? [])].filter((c) => valueOf(c) > 0).sort((a, b) => valueOf(b) - valueOf(a)),
)
const rankingTitle = computed(() => (payment.value === 'paid' ? t('web.report.customersPaid') : payment.value === 'unpaid' ? t('web.report.customersUnpaid') : t('customers')))
const ordersTitle = computed(() => (payment.value === 'paid' ? t('web.report.ordersPaid', { order: orderShort() }) : payment.value === 'unpaid' ? t('web.report.ordersUnpaid', { order: orderShort() }) : t('web.report.orders', { order: orderShort() })))

function pickCustomer(c: ReportCustomer) {
  const key = c.id ?? 'none'
  go({ customer: customer.value === key ? undefined : key })
}
const togglePayment = (value: 'paid' | 'unpaid') => go({ payment: payment.value === value ? undefined : value })

const open = ref(new Set<string>())
const all = (section: string) => open.value.has(section) || printing.value
function toggle(section: string) {
  const next = new Set(open.value)
  if (next.has(section)) next.delete(section)
  else next.add(section)
  open.value = next
}
const first = <T,>(list: T[], section: string) => (all(section) ? list : list.slice(0, SHOWN))

const panel = useRoutePanel('order')
function openOrder(id: string) {
  void panel.open(id)
}
function closePanel() {
  panel.close()
  void load()
}

// ---------------------------------------------------------------------------
// Export and print
// ---------------------------------------------------------------------------

const printing = ref(false)
function print() {
  printing.value = true
  window.addEventListener('afterprint', () => (printing.value = false), { once: true })
  requestAnimationFrame(() => window.print())
}

const fileBase = computed(() => `${t('web.report.fileName')}-${days.value.from}-${days.value.to}`)
const paymentWord = (value: 'paid' | 'pending') => (value === 'paid' ? t('paid') : t('pending'))

function orderSheet(r: FinanceReport): Cell[][] {
  return [
    [orderShort(), t('web.report.colDate'), t('customer'), t('web.report.colDevice'), t('web.report.colStatus'), t('web.report.colPayment'), t('total'), paidLabel.value, remainingLabel.value],
    ...r.orders.map((o): Cell[] => [
      o.number,
      formatDate(o.createdAt, country()),
      o.customer?.name ?? '',
      o.device ?? '',
      o.status ? statusText(o.status) : '',
      paymentWord(o.payment),
      o.total,
      o.paid,
      o.payment === 'paid' ? 0 : o.open,
    ]),
  ]
}

function sheets(r: FinanceReport) {
  const who = chosenCustomer.value ? customerName(chosenCustomer.value) : t('web.report.allCustomers')
  return [
    {
      name: t('web.report.sheetSummary'),
      rows: [
        [t('period'), `${dayText(r.from)} – ${dayText(r.to)}`],
        [t('customer'), who],
        [t('web.report.revenue'), r.revenue],
        [paidLabel.value, r.paid],
        [remainingLabel.value, r.remaining],
        [t('web.report.orderCount', { order: orderShort() }), r.count],
        [t('averageTicket'), Math.round(ticket.value * 100) / 100],
        [t('web.report.services'), r.composition.services],
        [t('web.report.products'), r.composition.products],
      ] as Cell[][],
    },
    { name: orderShort(), rows: orderSheet(r) },
    {
      name: t('customers'),
      rows: [[t('customer'), t('total'), paidLabel.value, remainingLabel.value, orderShort()], ...r.customers.map((c): Cell[] => [customerName(c), c.total, c.paid, c.remaining, c.count])],
    },
    { name: t('web.report.services'), rows: [[t('web.report.colName'), t('total'), t('web.report.colQuantity')], ...r.services.map((s): Cell[] => [s.name ?? t('web.report.noName'), s.total, s.quantity])] },
    { name: t('web.report.products'), rows: [[t('web.report.colName'), t('total'), t('web.report.colQuantity')], ...r.products.map((p): Cell[] => [p.name ?? t('web.report.noName'), p.total, p.quantity])] },
  ]
}

// Plan (#724): the report as a spreadsheet (CSV or Excel) is Pro; printing is in every plan.
const spreadsheet = usePlanFeature('spreadsheetExport')

function exportCsv() {
  const r = report.value
  if (!r || !ensurePlanFeature('spreadsheetExport')) return
  const decimal = new Intl.NumberFormat(countryFormat(country()).locale).formatToParts(1.5).find((part) => part.type === 'decimal')?.value === ',' ? ',' : '.'
  download(`${fileBase.value}.csv`, toCsv(orderSheet(r), decimal), CSV_TYPE)
  showToast(t('web.report.exported'))
}
function exportXlsx() {
  const r = report.value
  if (!r || !ensurePlanFeature('spreadsheetExport')) return
  download(`${fileBase.value}.xlsx`, toXlsx(sheets(r)) as BlobPart, XLSX_TYPE)
  showToast(t('web.report.exported'))
}
</script>

<template>
  <div class="finance report" :class="{ 'is-printing': printing }" data-testid="finance-report">
    <PageHead
      :title="t('financial')"
      :answer="state === 'ready' ? title : ''"
      :sub="chosenCustomer ? t('web.report.onlyCustomer', { name: customerName(chosenCustomer) }) : undefined"
    >
      <div class="report-actions no-print">
        <button type="button" class="btn" :disabled="state !== 'ready'" data-testid="report-csv" @click="exportCsv">{{ t('web.report.csv') }}<span v-if="!spreadsheet.allowed" class="plan-badge">· {{ t('planFeatureBadge', { plan: PLAN_NAME[spreadsheet.requiredPlan ?? 'pro'] }) }}</span></button>
        <button type="button" class="btn" :disabled="state !== 'ready'" data-testid="report-xlsx" @click="exportXlsx">{{ t('web.report.xlsx') }}<span v-if="!spreadsheet.allowed" class="plan-badge">· {{ t('planFeatureBadge', { plan: PLAN_NAME[spreadsheet.requiredPlan ?? 'pro'] }) }}</span></button>
        <button type="button" class="btn" :disabled="state !== 'ready' || !report?.count" data-testid="report-print" @click="print">{{ t('web.report.print') }}</button>
      </div>
    </PageHead>
    <div class="toolbar report-tools no-print">
      <FinanceTabs />
      <label class="sr" for="report-kind">{{ t('period') }}</label>
      <select id="report-kind" class="field select-mini" :value="kind" data-testid="report-kind" @change="onKind">
        <option value="day">{{ t('today') }}</option>
        <option value="week">{{ t('reportThisWeek') }}</option>
        <option value="month">{{ t('reportThisMonth') }}</option>
        <option value="year">{{ t('reportThisYear') }}</option>
        <option value="custom">{{ t('reportPickDates') }}</option>
      </select>
      <div class="fin-month no-print" role="group" :aria-label="t('period')">
        <template v-if="kind !== 'custom'">
          <button type="button" class="icon-btn" :aria-label="t('reportPreviousPeriod')" data-testid="report-prev" @click="step(-1)">
            <ChevronLeft :size="18" aria-hidden="true" />
          </button>
          <button
            type="button"
            class="fin-month-label"
            :disabled="offset === 0 && !customer && !payment"
            :aria-label="t('web.report.backToCurrent', { period: label })"
            data-testid="report-label"
            @click="reset"
          >
            <span aria-live="polite">{{ label }}</span>
          </button>
          <button type="button" class="icon-btn" :disabled="offset === 0" :aria-label="t('reportNextPeriod')" data-testid="report-next" @click="step(1)">
            <ChevronRight :size="18" aria-hidden="true" />
          </button>
        </template>
        <button v-else type="button" class="fin-month-label fin-custom" data-testid="report-label" @click="picking = true">
          <CalendarDays :size="16" aria-hidden="true" />
          <span aria-live="polite">{{ label }}</span>
        </button>
      </div>
    </div>
    <p class="print-only report-print-head">{{ title }}</p>

    <LoadingState v-if="state === 'loading'" />
    <ErrorState v-else-if="state === 'failed'" :body="failure" :retry="load" />
    <div v-else-if="report" class="workspace fin-work" :class="{ 'has-panel': !!panel.value.value }">
    <div class="list-pane">
    <div class="fin report-body" :aria-busy="busy ? 'true' : 'false'">
      <p v-if="report.truncated" class="list-note" role="note">{{ t('web.fin.truncated') }}</p>
      <p v-if="!report.count" class="muted fin-none" data-testid="report-empty">{{ t('web.report.empty') }}</p>
      <template v-else>
        <section class="report-totals" aria-labelledby="r-totals">
          <h2 id="r-totals" class="sr">{{ t('financialSummary') }}</h2>
          <dl class="report-numbers">
            <div><dt>{{ t('web.report.revenue') }}</dt><dd class="num" data-testid="report-revenue">{{ money(report.revenue) }}</dd></div>
            <div><dt>{{ t('web.report.orderCount', { order: orderShort() }) }}</dt><dd class="num">{{ report.count }}</dd></div>
            <div><dt>{{ t('averageTicket') }}</dt><dd class="num">{{ money(ticket) }}</dd></div>
          </dl>
          <div class="report-legend" role="group" :aria-label="t('web.report.filterPayment')">
            <button type="button" class="fin-card fin-card--small" :aria-pressed="payment === 'paid'" data-testid="report-paid" @click="togglePayment('paid')">
              <span><i class="sw sw--paid" aria-hidden="true"></i>{{ paidLabel }} ({{ formatPercent(paidPercent, country()) }})</span>
              <b class="num">{{ money(report.paid) }}</b>
            </button>
            <button type="button" class="fin-card fin-card--small" :aria-pressed="payment === 'unpaid'" data-testid="report-unpaid" @click="togglePayment('unpaid')">
              <span><i class="sw sw--open" aria-hidden="true"></i>{{ remainingLabel }}</span>
              <b class="num">{{ money(report.remaining) }}</b>
            </button>
          </div>
        </section>

        <section v-if="composition" class="report-sec" aria-labelledby="r-mix">
          <h2 id="r-mix">{{ t('composition') }}</h2>
          <div class="fin-mix" aria-hidden="true"><i :style="{ width: `${composition.servicesPercent}%` }"></i></div>
          <dl class="fin-legend">
            <div><dt><i class="sw sw--a" aria-hidden="true"></i>{{ t('web.report.services') }}, {{ formatPercent(composition.servicesPercent, country()) }}</dt><dd class="num">{{ money(composition.services) }}</dd></div>
            <div><dt><i class="sw sw--b" aria-hidden="true"></i>{{ t('web.report.products') }}, {{ formatPercent(composition.productsPercent, country()) }}</dt><dd class="num">{{ money(composition.products) }}</dd></div>
          </dl>
        </section>

        <div class="report-cols">
          <section v-if="ranking.length" class="report-sec" aria-labelledby="r-customers" data-testid="report-customers">
            <h2 id="r-customers">{{ rankingTitle }}</h2>
            <ul class="fin-rows">
              <li v-for="c in first(ranking, 'customers')" :key="c.id ?? 'none'">
                <button type="button" class="fin-row" :aria-pressed="customer === (c.id ?? 'none')" @click="pickCustomer(c)">
                  <span>
                    <Check v-if="customer === (c.id ?? 'none')" :size="14" aria-hidden="true" />
                    <span class="who">{{ customerName(c) }}</span>
                    <span v-if="!payment && c.remaining > 0" class="sub"> · {{ t('web.report.toReceive', { amount: money(c.remaining) }) }}</span>
                  </span>
                  <span class="num">{{ money(valueOf(c)) }}</span>
                </button>
              </li>
            </ul>
            <button v-if="ranking.length > SHOWN" type="button" class="link no-print" @click="toggle('customers')">
              {{ all('customers') ? t('seeLess') : t('seeAllCount', { count: ranking.length }) }}
            </button>
          </section>

          <section v-if="report.services.length" class="report-sec" aria-labelledby="r-services">
            <h2 id="r-services">{{ t('web.report.servicesRanking') }}</h2>
            <ul class="fin-rows">
              <li v-for="s in first(report.services, 'services')" :key="s.name ?? ''" class="fin-row fin-row--plain">
                <span><span class="who">{{ s.name ?? t('web.report.noName') }}</span> <span class="sub">· {{ t('web.report.times', { count: s.quantity }) }}</span></span>
                <span class="num">{{ money(s.total) }}</span>
              </li>
            </ul>
            <button v-if="report.services.length > SHOWN" type="button" class="link no-print" @click="toggle('services')">
              {{ all('services') ? t('seeLess') : t('seeAllCount', { count: report.services.length }) }}
            </button>
          </section>

          <section v-if="report.products.length" class="report-sec" aria-labelledby="r-products">
            <h2 id="r-products">{{ t('web.report.productsRanking') }}</h2>
            <ul class="fin-rows">
              <li v-for="p in first(report.products, 'products')" :key="p.name ?? ''" class="fin-row fin-row--plain">
                <span><span class="who">{{ p.name ?? t('web.report.noName') }}</span> <span class="sub">· {{ t('web.report.units', { count: p.quantity }) }}</span></span>
                <span class="num">{{ money(p.total) }}</span>
              </li>
            </ul>
            <button v-if="report.products.length > SHOWN" type="button" class="link no-print" @click="toggle('products')">
              {{ all('products') ? t('seeLess') : t('seeAllCount', { count: report.products.length }) }}
            </button>
          </section>
        </div>

        <section class="report-sec" aria-labelledby="r-orders" data-testid="report-orders">
          <h2 id="r-orders">{{ ordersTitle }}</h2>
          <p v-if="!report.orders.length" class="muted">{{ t('web.report.noOrdersFiltered') }}</p>
          <ul v-else class="fin-rows">
            <li v-for="o in first(report.orders, 'orders')" :key="o.id">
              <button type="button" class="fin-row" data-testid="report-order" @click="openOrder(o.id)">
                <span>
                  <span class="status">
                    <span class="dot" :class="o.payment === 'paid' ? 'dot--success' : 'dot--warning'" aria-hidden="true"></span>
                    <span>{{ t('web.fin.orderNumber', { order: orderShort(), number: o.number ?? '' }) }} · {{ formatDate(o.createdAt, country()) }} · {{ paymentWord(o.payment) }}</span>
                  </span>
                  <span class="who block">{{ o.customer?.name || t('web.fin.noCustomer') }}</span>
                </span>
                <span class="num">{{ money(o.total) }}</span>
              </button>
            </li>
          </ul>
          <button v-if="report.orders.length > SHOWN" type="button" class="link no-print" @click="toggle('orders')">
            {{ all('orders') ? t('seeLess') : t('seeAllCount', { count: report.orders.length }) }}
          </button>
        </section>
      </template>
    </div>
    </div>
    <aside v-if="panel.value.value" class="panel no-print" :aria-label="t('web.orders.panel')">
      <OrderDetail :key="panel.value.value" :order-id="panel.value.value" @close="closePanel" />
    </aside>
    </div>
    <PeriodDialog v-if="picking" :today="todayDay" :initial="custom" @apply="applyDays" @close="closePicker" />
  </div>
</template>
