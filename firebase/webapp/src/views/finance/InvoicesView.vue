<script setup lang="ts">
// Notas fiscais (nfse.list.*, nfse.invoice.*): the month's notas, what needs
// attention on top, the nota open beside the list (?invoice=). The list is read
// from Firestore (the server writes it); issuing and canceling go through
// /v1/app/nfse/*. With the nota off for the company the screen says so (the
// app's D23 spins forever).
import { computed, defineAsyncComponent, onBeforeUnmount, onMounted, ref, shallowRef, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ChevronLeft, ChevronRight, X } from '@lucide/vue'
import EmptyState from '@/components/EmptyState.vue'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import PageHead from '@/components/PageHead.vue'
import ConfirmDialog from '@/components/orders/ConfirmDialog.vue'
import { t } from '@/i18n'
import { ApiError, errorMessageKey } from '@/lib/api'
import { addDays, monthOf, shiftMonth } from '@/lib/finance/period'
import { monthName, monthYear, today } from '@/lib/finance/text'
import { formatDate } from '@/lib/format'
import { cancelInvoice, monthInvoices, nfseSettings, type NfseSettings } from '@/lib/nfse/data'
import { SEARCH_FROM, canCancel, canFix, matches, monthList, orderNumbers, type NfseInvoice, type NfseStatus } from '@/lib/nfse/model'
import { country, money, orderShort } from '@/lib/orders/text'
import { registerShortcut } from '@/lib/shortcuts'
import { showToast } from '@/lib/toast'
import '@/styles/finance.css'

const IssueInvoiceDialog = defineAsyncComponent(() => import('@/components/finance/IssueInvoiceDialog.vue'))

const route = useRoute()
const router = useRouter()

const todayDay = today()
const current = monthOf(todayDay)
/** A nota can be scheduled up to 60 days ahead: "next" goes as far as that month (nfse.list.month). */
const lastMonth = monthOf(addDays(todayDay, 60))
const month = computed(() => {
  const asked = typeof route.query.month === 'string' && /^\d{4}-(0[1-9]|1[0-2])$/.test(route.query.month) ? route.query.month : null
  return asked && asked <= lastMonth ? asked : current
})
const query = computed(() => (typeof route.query.q === 'string' ? route.query.q : ''))
const openId = computed(() => (typeof route.query.invoice === 'string' ? route.query.invoice : null))

const settings = ref<NfseSettings | null>(null)
const state = ref<'loading' | 'ready' | 'failed' | 'off'>('loading')
const failure = ref('')
const invoices = shallowRef<NfseInvoice[]>([])
let asked = 0

async function load() {
  const run = ++asked
  if (state.value !== 'ready') state.value = 'loading'
  try {
    settings.value ??= await nfseSettings()
    if (!settings.value.available) {
      state.value = 'off'
      return
    }
    const list = await monthInvoices(month.value, todayDay)
    if (run !== asked) return
    invoices.value = list
    state.value = 'ready'
  } catch (error) {
    if (run !== asked) return
    failure.value = t(errorMessageKey(error))
    state.value = 'failed'
  }
}
watch(month, () => void load())
const onFocus = () => state.value === 'ready' && void load()
onMounted(() => {
  void load()
  window.addEventListener('focus', onFocus)
})
onBeforeUnmount(() => window.removeEventListener('focus', onFocus))

function go(next: Record<string, string | undefined>) {
  void router.replace({ query: { ...route.query, ...next } })
}
function step(by: number) {
  const next = shiftMonth(month.value, by)
  if (next > lastMonth) return
  // A new month clears the search (nfse.list.month).
  go({ month: next === current ? undefined : next, q: undefined })
}
const removers: (() => void)[] = []
onMounted(() =>
  removers.push(
    registerShortcut({ keys: 'arrowleft', label: 'financialPreviousMonth', run: () => step(-1) }),
    registerShortcut({ keys: 'arrowright', label: 'financialNextMonth', run: () => step(1) }),
  ),
)
onBeforeUnmount(() => removers.forEach((remove) => remove()))

const result = computed(() => monthList(invoices.value, month.value, todayDay))
const searchable = computed(() => result.value.rows.length + result.value.attention.length > SEARCH_FROM)
const rows = computed(() => (searchable.value && query.value ? result.value.rows.filter((i) => matches(i, query.value)) : result.value.rows))
const attention = computed(() => (searchable.value && query.value ? result.value.attention.filter((i) => matches(i, query.value)) : result.value.attention))
const opened = computed(() => (openId.value ? (invoices.value.find((i) => i.id === openId.value) ?? null) : null))

const title = computed(() =>
  state.value === 'ready'
    ? t('nfseListSummary', { count: result.value.issuedCount, month: monthName(month.value), value: money(result.value.issuedTotal) })
    : t('nfseListTitle'),
)

// ---------------------------------------------------------------------------
// Status words (nfse_access.dart statusText)
// ---------------------------------------------------------------------------

const DOT: Record<NfseStatus, string> = {
  creating: 'warning',
  scheduled: 'warning',
  synchronized: 'warning',
  authorized: 'success',
  processingCancellation: 'warning',
  cancellationDenied: 'danger',
  canceled: 'hollow',
  error: 'danger',
}
function statusOf(invoice: NfseInvoice): string {
  if (invoice.conflict) return t('nfseConflictNotice')
  switch (invoice.status) {
    case 'scheduled':
      return invoice.effectiveDate && invoice.effectiveDate > todayDay
        ? t('nfseStatusScheduledFor', { date: formatDate(`${invoice.effectiveDate}T12:00:00`, country()) })
        : t('nfseStatusWaiting')
    case 'authorized':
      return invoice.number ? t('nfseStatusIssuedNumber', { number: invoice.number }) : t('nfseStatusIssued')
    case 'processingCancellation':
      return t('nfseStatusCanceling')
    case 'cancellationDenied':
      return t('nfseStatusCancelDenied')
    case 'canceled':
      return t('nfseStatusCanceled')
    case 'error':
      return t('nfseStatusError')
    default:
      return t('nfseStatusWaiting')
  }
}
function headOf(invoice: NfseInvoice): string {
  if (invoice.status === 'error') return invoice.auto ? t('nfseHeadAutoError') : invoice.errorCode ? t('nfseHeadNotIssued') : t('nfseHeadError')
  if (invoice.status === 'authorized') return t('nfseHeadIssued')
  if (invoice.status === 'processingCancellation') return t('nfseHeadCanceling')
  if (invoice.status === 'cancellationDenied') return t('nfseHeadCancelDenied')
  if (invoice.status === 'canceled') return t('nfseHeadCanceled')
  if (invoice.status === 'scheduled' && invoice.effectiveDate && invoice.effectiveDate > todayDay) {
    return t('nfseHeadScheduled', { date: formatDate(`${invoice.effectiveDate}T12:00:00`, country()) })
  }
  return t('nfseHeadWaiting')
}
const REASON: Record<string, Parameters<typeof t>[0]> = {
  TAX_ID_REQUIRED: 'nfseAutoErrorTaxId',
  CUSTOMER_DATA_REQUIRED: 'nfseErrorCustomerData',
  NO_SERVICES: 'nfseErrorNoServices',
  NFSE_SETUP_NEEDED: 'nfseErrorSetupNeeded',
  NFSE_NOT_READY: 'nfseErrorNotReady',
  NFSE_SETUP_REJECTED: 'nfseErrorSetupRejected',
}
/** Short reason on the row: the city's text, or ours for a code we know. */
function reasonOf(invoice: NfseInvoice): string | null {
  if (invoice.status !== 'error' && invoice.status !== 'cancellationDenied') return null
  const known = invoice.errorCode ? REASON[invoice.errorCode] : undefined
  return known ? t(known) : invoice.statusDescription
}
const label = (invoice: NfseInvoice) => (invoice.number ? t('nfseListNumber', { number: invoice.number }) : t('nfseNotIssued'))
const ordersText = (invoice: NfseInvoice) => (orderNumbers(invoice) ? `${orderShort()} ${orderNumbers(invoice)}` : '')

function open(invoice: NfseInvoice) {
  void router.push({ query: { ...route.query, invoice: invoice.id } })
}
function close() {
  void router.replace({ query: { ...route.query, invoice: undefined } })
}

// ---------------------------------------------------------------------------
// Cancel and fix
// ---------------------------------------------------------------------------

const asking = ref<'cancel' | 'atCity' | null>(null)
const working = ref(false)
const fixing = ref<NfseInvoice | null>(null)

async function cancel(onlyOnAsaas = false) {
  const invoice = opened.value
  if (!invoice || working.value) return
  working.value = true
  try {
    const answer = await cancelInvoice(invoice.id, onlyOnAsaas)
    asking.value = null
    showToast(answer.status === 'canceled' ? t('nfseCanceledToast') : t('nfseCancelRequested'))
    await load()
  } catch (error) {
    if (error instanceof ApiError && error.code === 'CANCEL_NOT_SUPPORTED') {
      asking.value = 'atCity'
      return
    }
    asking.value = null
    const code = error instanceof ApiError ? error.code : ''
    showToast(
      code === 'INVOICE_NOT_CANCELABLE'
        ? t('nfseErrorNotCancelable')
        : code === 'INVOICE_OTHER_ACCOUNT'
          ? t('nfseErrorOtherAccount')
          : code === 'INVOICE_NOT_FOUND'
            ? t('nfseErrorNotFound')
            : t(errorMessageKey(error)),
    )
  } finally {
    working.value = false
  }
}

async function fixed() {
  fixing.value = null
  await load()
}
</script>

<template>
  <div class="finance invoices" data-testid="invoices">
    <PageHead :title="title" :sub="state === 'ready' ? t('nfseListOnlyServices') : undefined">
      <div v-if="state === 'ready'" class="fin-month" role="group" :aria-label="t('web.fin.month')">
        <button type="button" class="icon-btn" :aria-label="t('financialPreviousMonth')" data-testid="nfse-prev" @click="step(-1)">
          <ChevronLeft :size="18" aria-hidden="true" />
        </button>
        <button type="button" class="fin-month-label" :disabled="month === current" data-testid="nfse-month" @click="go({ month: undefined, q: undefined })">
          <span aria-live="polite">{{ monthYear(month) }}</span>
        </button>
        <button type="button" class="icon-btn" :disabled="month >= lastMonth" :aria-label="t('financialNextMonth')" data-testid="nfse-next" @click="step(1)">
          <ChevronRight :size="18" aria-hidden="true" />
        </button>
      </div>
    </PageHead>

    <LoadingState v-if="state === 'loading'" />
    <ErrorState v-else-if="state === 'failed'" :body="failure" :retry="load" />
    <EmptyState v-else-if="state === 'off'" :title="t('nfseErrorNotEnabled')" :body="t('web.nfse.offBody')" data-testid="nfse-off" />
    <div v-else class="workspace" :class="{ 'has-panel': opened }">
      <div class="list-pane">
        <div v-if="searchable" class="toolbar">
          <label class="sr" for="nfse-search">{{ t('nfseListSearch') }}</label>
          <input
            id="nfse-search"
            class="field search-mini nfse-search"
            type="search"
            :placeholder="t('nfseListSearch')"
            :value="query"
            data-testid="nfse-search"
            @input="go({ q: ($event.target as HTMLInputElement).value || undefined })"
          />
        </div>
        <section v-if="attention.length" class="nfse-attention" aria-labelledby="nfse-att" data-testid="nfse-attention">
          <h2 id="nfse-att">{{ t('nfseListAttention') }}</h2>
          <ul class="fin-rows">
            <li v-for="invoice in attention" :key="invoice.id">
              <button type="button" class="fin-row" :class="{ 'is-open': invoice.id === openId }" @click="open(invoice)">
                <span>
                  <span class="who">{{ invoice.customerName || t('web.fin.noCustomer') }}</span>
                  <span class="sub"> · {{ ordersText(invoice) }}</span>
                  <span class="nfse-reason">{{ reasonOf(invoice) ?? statusOf(invoice) }}</span>
                </span>
                <span class="num">{{ money(invoice.value) }}</span>
              </button>
            </li>
          </ul>
        </section>
        <EmptyState
          v-if="!rows.length && !attention.length"
          :title="query ? t('nfseListNoResults', { month: monthName(month) }) : t('nfseListEmpty', { month: monthName(month) })"
          :body="query ? undefined : t('web.nfse.emptyHint')"
          data-testid="nfse-empty"
        />
        <table v-else-if="rows.length" class="grid" data-testid="nfse-table">
          <caption class="sr">{{ title }}</caption>
          <thead>
            <tr>
              <th scope="col">{{ t('nfseRowTitle') }}</th>
              <th scope="col">{{ t('customer') }}</th>
              <th scope="col">{{ t('web.nfse.status') }}</th>
              <th scope="col" class="c-money">{{ t('nfseValueLabel') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="invoice in rows" :key="invoice.id" :class="{ 'is-open': invoice.id === openId }" data-testid="nfse-row" @click="open(invoice)">
              <td>
                <button type="button" class="row-btn num" @click.stop="open(invoice)">{{ label(invoice) }}</button>
                <span class="sub block">{{ invoice.effectiveDate ? formatDate(`${invoice.effectiveDate}T12:00:00`, country()) : '' }}</span>
              </td>
              <td><span class="who">{{ invoice.customerName || t('web.fin.noCustomer') }}</span><span class="sub block">{{ ordersText(invoice) }}</span></td>
              <td>
                <span class="status"><span class="dot" :class="`dot--${DOT[invoice.status]}`" aria-hidden="true"></span><span>{{ statusOf(invoice) }}</span></span>
              </td>
              <td class="c-money"><span class="num">{{ money(invoice.value) }}</span></td>
            </tr>
          </tbody>
        </table>
      </div>

      <aside v-if="opened" class="nfse-panel" :aria-label="t('web.nfse.panel')" data-testid="nfse-panel">
        <div class="nfse-top">
          <span class="num">{{ label(opened) }}</span>
          <span class="spacer"></span>
          <button type="button" class="icon-btn" :aria-label="t('close')" @click="close"><X :size="18" aria-hidden="true" /></button>
        </div>
        <header class="nfse-head">
          <h2 class="nfse-name">{{ opened.customerName || t('web.fin.noCustomer') }}</h2>
          <span class="status" :class="{ 'status--late': opened.status === 'error' }">
            <span class="dot" :class="`dot--${DOT[opened.status]}`" aria-hidden="true"></span><span data-testid="nfse-status">{{ statusOf(opened) }}</span>
          </span>
          <p>{{ headOf(opened) }}</p>
          <div class="nfse-actions">
            <button v-if="canFix(opened)" type="button" class="btn btn--primary" data-testid="nfse-fix" @click="fixing = opened">{{ t('nfseFixAndIssue') }}</button>
            <a v-if="opened.status === 'authorized' && opened.pdfUrl" class="btn btn--primary" :href="opened.pdfUrl" target="_blank" rel="noopener noreferrer" data-testid="nfse-pdf">{{ t('nfseOpenPdf') }}</a>
            <a v-if="opened.status === 'authorized' && opened.xmlUrl" class="btn" :href="opened.xmlUrl" target="_blank" rel="noopener noreferrer" data-testid="nfse-xml">{{ t('nfseOpenXml') }}</a>
          </div>
        </header>
        <dl class="nfse-facts">
          <div><dt>{{ t('nfseValueLabel') }}</dt><dd class="num">{{ money(opened.value) }}</dd></div>
          <div v-if="opened.number"><dt>{{ t('nfseNumberLabel') }}</dt><dd class="num">{{ opened.number }}</dd></div>
          <div v-if="opened.effectiveDate"><dt>{{ t('nfseDateLabel') }}</dt><dd>{{ formatDate(`${opened.effectiveDate}T12:00:00`, country()) }}</dd></div>
          <div v-if="opened.orders.length">
            <dt>{{ t('nfseOrdersLabel') }}</dt>
            <dd>
              <RouterLink v-for="o in opened.orders" :key="o.orderId" class="link nfse-order" :to="{ path: '/', query: { order: o.orderId } }">{{ orderShort() }} {{ o.orderNumber }}</RouterLink>
            </dd>
          </div>
          <div v-if="reasonOf(opened)">
            <dt>{{ opened.auto ? t('nfseAutoReasonLabel') : t('nfseReasonLabel') }}</dt>
            <dd class="nfse-reason" data-testid="nfse-reason">{{ reasonOf(opened) }}</dd>
          </div>
        </dl>
        <p v-if="opened.conflict" class="field-error" role="note">{{ t('nfseConflictNotice') }}</p>
        <div v-if="canCancel(opened)" class="nfse-danger">
          <button type="button" class="link link--danger" data-testid="nfse-cancel" @click="asking = 'cancel'">{{ t('nfseCancelAction') }}</button>
        </div>
      </aside>
    </div>

    <ConfirmDialog
      v-if="asking === 'cancel' && opened"
      :title="t('nfseCancelQuestion', { value: money(opened.value) })"
      :body="t('nfseCancelMessage')"
      :confirm="t('nfseCancelAction')"
      :keep="t('nfseKeep')"
      danger
      @confirm="cancel()"
      @close="asking = null"
    />
    <ConfirmDialog
      v-if="asking === 'atCity' && opened"
      :title="t('nfseCancelAtCityTitle')"
      :body="t('nfseCancelAtCityMessage')"
      :confirm="t('nfseCanceledAtCity')"
      :keep="t('nfseKeep')"
      @confirm="cancel(true)"
      @close="asking = null"
    />
    <IssueInvoiceDialog v-if="fixing" :order-ids="fixing.orderIds" :customer-id="fixing.customerId" @done="fixed" @close="fixing = null" />
  </div>
</template>
