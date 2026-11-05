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
import ChoiceDialog from '@/components/orders/ChoiceDialog.vue'
import ConfirmDialog from '@/components/orders/ConfirmDialog.vue'
import ShareButtons from '@/components/ShareButtons.vue'
import { locale, t } from '@/i18n'
import { ApiError, errorMessageKey } from '@/lib/api'
import { addDays, monthOf, shiftMonth } from '@/lib/finance/period'
import { monthName, monthYear, today } from '@/lib/finance/text'
import { formatDate } from '@/lib/format'
import { cancelInvoice, customerInvoices, monthInvoices, nfseSettings, type NfseSettings } from '@/lib/nfse/data'
import { can } from '@/lib/session'
import { DOT, invoiceStatusText } from '@/lib/nfse/text'
import { SEARCH_FROM, byEmitter, canCancel, canFix, canReconcile, emittersOf, matches, monthList, orderNumbers, refusalMessage, type NfseInvoice } from '@/lib/nfse/model'
import { CANCEL_REASONS, cancelDirect, cancelFailureText, directPdfPath, reconcileDirect, storageUrl, type CancelReason } from '@/lib/nfse/direct-issue'
import { formatTaxId } from '@/lib/tax-id'
import { country, money, orderShort } from '@/lib/orders/text'
import { registerShortcut } from '@/lib/shortcuts'
import { fileFromUrl } from '@/lib/share'
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
/** "Notas de X" (nfse.list.customer): only this customer's notas, from the customer's screen. */
const customerId = computed(() => (typeof route.query.customer === 'string' && route.query.customer ? route.query.customer : null))
/** Only the notas of one CNPJ (NFS-e direct with several emitters, spec §4.7). */
const emitterId = computed(() => (typeof route.query.emitter === 'string' && route.query.emitter ? route.query.emitter : null))

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
    let list: NfseInvoice[]
    if (customerId.value) {
      list = await customerInvoices(customerId.value)
      // Opens on the month of the customer's newest nota.
      const newest = [...list].filter((i) => i.effectiveDate).sort((a, b) => (b.effectiveDate as string).localeCompare(a.effectiveDate as string))[0]
      if (run === asked && typeof route.query.month !== 'string' && newest?.effectiveDate && monthOf(newest.effectiveDate) !== month.value) {
        invoices.value = list
        go({ month: monthOf(newest.effectiveDate) === current ? undefined : monthOf(newest.effectiveDate) })
        return
      }
    } else list = await monthInvoices(month.value, todayDay)
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
watch(customerId, () => void load())
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

/** The CNPJs of the notas read, when there is more than one: the filter shows. */
const emitters = computed(() => emittersOf(invoices.value))
const activeEmitter = computed(() => (emitters.value.some((e) => e.id === emitterId.value) ? emitterId.value : null))
const result = computed(() => monthList(invoices.value.filter((i) => byEmitter(i, activeEmitter.value)), month.value, todayDay))
const searchable = computed(() => result.value.rows.length + result.value.attention.length > SEARCH_FROM)
const rows = computed(() => (searchable.value && query.value ? result.value.rows.filter((i) => matches(i, query.value)) : result.value.rows))
const attention = computed(() => (searchable.value && query.value ? result.value.attention.filter((i) => matches(i, query.value)) : result.value.attention))
const opened = computed(() => (openId.value ? (invoices.value.find((i) => i.id === openId.value) ?? null) : null))

/**
 * nfse.invoice.share-pdf: the PDF as a file in the browser's sheet when the
 * browser can read it, else the link (as the app when the download fails);
 * WhatsApp to the customer's record phone with the link.
 */
function nfseText(invoice: NfseInvoice): string {
  const hello = invoice.customerName ? t('web.share.msgHello', { name: invoice.customerName }) : t('web.share.msgHelloNoName')
  const body = invoice.number ? t('web.share.nfseText', { number: invoice.number }) : t('web.share.nfseTextNoNumber')
  return `${hello} ${body}\n${invoice.pdfUrl ?? ''}`
}
const nfseFile = (invoice: NfseInvoice) => () => (invoice.pdfUrl ? fileFromUrl(invoice.pdfUrl, `nota-${invoice.number ?? invoice.id}.pdf`) : Promise.resolve(null))

const customerName = computed(() => invoices.value.find((i) => i.customerName)?.customerName ?? '')
const title = computed(() =>
  customerId.value
    ? t('nfseListCustomerTitle', { name: customerName.value })
    : state.value === 'ready'
    ? t('nfseListSummary', { count: result.value.issuedCount, month: monthName(month.value), value: money(result.value.issuedTotal) })
    : t('nfseListTitle'),
)

// ---------------------------------------------------------------------------
// Status words (nfse_access.dart statusText)
// ---------------------------------------------------------------------------

const statusOf = (invoice: NfseInvoice) => invoiceStatusText(invoice, todayDay)
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
  // NFS-e direct: the government's refusal in plain words, in the language on screen.
  if (invoice.refusal) return refusalMessage(invoice.refusal, locale.value)
  const known = invoice.errorCode ? REASON[invoice.errorCode] : undefined
  return known ? t(known) : invoice.statusDescription
}
const external = (invoice: NfseInvoice) => invoice.source === 'external'
const partyLine = (party: { legalName: string | null; taxId: string | null } | null) =>
  party ? [party.legalName, party.taxId ? formatTaxId(party.taxId) : null].filter(Boolean).join(' · ') : ''
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

const asking = ref<'cancel' | 'atCity' | 'reason' | null>(null)
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

// ---------------------------------------------------------------------------
// NFS-e direct: cancel with the reason, check a nota still waiting, PDF and XML
// ---------------------------------------------------------------------------

/** What the government said about the last cancel or check of the open nota. */
const panelNote = ref<{ id: string; text: string } | null>(null)
const reasonChoices = computed(() =>
  CANCEL_REASONS.map((reason) => ({ id: reason, label: t(reason === 'issueError' ? 'web.nfseDirect.reasonIssueError' : 'web.nfseDirect.reasonNotProvided') })),
)

async function cancelWithReason(reason: string) {
  const invoice = opened.value
  if (!invoice || working.value) return
  working.value = true
  asking.value = null
  try {
    await cancelDirect(invoice.id, reason as CancelReason)
    panelNote.value = null
    showToast(t('nfseCanceledToast'))
    await load()
  } catch (error) {
    panelNote.value = { id: invoice.id, text: cancelFailureText(error, locale.value) }
    await load()
  } finally {
    working.value = false
  }
}

async function reconcile() {
  const invoice = opened.value
  if (!invoice || working.value) return
  working.value = true
  try {
    const answer = await reconcileDirect(invoice.id)
    panelNote.value = answer.status === 'creating' ? { id: invoice.id, text: t('web.nfseDirect.stillWaiting') } : null
    await load()
  } catch (error) {
    panelNote.value = { id: invoice.id, text: cancelFailureText(error, locale.value) }
  } finally {
    working.value = false
  }
}

/**
 * Opens a file of the nota in a new tab. The tab opens at the click (a tab
 * opened after waiting is blocked by the browser) and goes to the file when
 * its link comes.
 */
async function openFile(kind: 'pdf' | 'xml') {
  const invoice = opened.value
  if (!invoice) return
  const tab = window.open('', '_blank')
  if (tab) tab.opener = null
  try {
    const storagePath = kind === 'pdf' ? await directPdfPath(invoice.id) : invoice.xmlPath
    if (!storagePath) throw new Error('no file')
    const url = await storageUrl(storagePath)
    if (tab) tab.location.href = url
    else window.location.assign(url)
  } catch (error) {
    tab?.close()
    showToast(error instanceof Error && error.message === 'no file' ? t('web.nfseDirect.fileMissing') : t(errorMessageKey(error)))
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
      <RouterLink v-if="can('manageCompany') && !customerId && state !== 'off'" class="link" to="/invoices/setup" data-testid="nfse-setup-link">{{ t('nfseListSetup') }}</RouterLink>
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
        <div v-if="searchable || emitters.length" class="toolbar">
          <template v-if="emitters.length">
            <label class="sr" for="nfse-emitter">{{ t('web.nfseDirect.emitterFilter') }}</label>
            <select
              id="nfse-emitter"
              class="field search-mini"
              :value="activeEmitter ?? ''"
              data-testid="nfse-emitter-filter"
              @change="go({ emitter: ($event.target as HTMLSelectElement).value || undefined })"
            >
              <option value="">{{ t('web.nfseDirect.allEmitters') }}</option>
              <option v-for="e in emitters" :key="e.id" :value="e.id">{{ e.legalName }}</option>
            </select>
          </template>
          <template v-if="searchable">
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
          </template>
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
                <span v-if="external(invoice)" class="sub block nfse-tag" data-testid="nfse-external">{{ t('web.nfseDirect.external') }}</span>
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
          <p v-if="external(opened)" class="sub nfse-tag">{{ t('web.nfseDirect.external') }}</p>
          <div class="nfse-actions">
            <button v-if="canFix(opened)" type="button" class="btn btn--primary" data-testid="nfse-fix" @click="fixing = opened">{{ t('nfseFixAndIssue') }}</button>
            <template v-if="opened.provider === 'direct'">
              <button v-if="canReconcile(opened)" type="button" class="btn btn--primary" :disabled="working" data-testid="nfse-reconcile" @click="reconcile">{{ t('web.nfseDirect.checkNow') }}</button>
              <button v-if="opened.accessKey && (opened.status === 'authorized' || opened.status === 'cancellationDenied' || opened.status === 'canceled')" type="button" class="btn btn--primary" data-testid="nfse-pdf" @click="openFile('pdf')">{{ t('nfseOpenPdf') }}</button>
              <button v-if="opened.xmlPath" type="button" class="btn" data-testid="nfse-xml" @click="openFile('xml')">{{ t('nfseOpenXml') }}</button>
            </template>
            <a v-if="opened.status === 'authorized' && opened.pdfUrl" class="btn btn--primary" :href="opened.pdfUrl" target="_blank" rel="noopener noreferrer" data-testid="nfse-pdf">{{ t('nfseOpenPdf') }}</a>
            <a v-if="opened.status === 'authorized' && opened.xmlUrl" class="btn" :href="opened.xmlUrl" target="_blank" rel="noopener noreferrer" data-testid="nfse-xml">{{ t('nfseOpenXml') }}</a>
            <ShareButtons
              v-if="opened.status === 'authorized' && opened.pdfUrl"
              :key="opened.id"
              context="invoice"
              :text="nfseText(opened)"
              :title="label(opened)"
              :copy="opened.pdfUrl"
              :customer-id="opened.customerId"
              :file="nfseFile(opened)"
              :sheet-label="t('nfseSharePdf')"
              testid="nfse-share"
            />
          </div>
        </header>
        <dl class="nfse-facts">
          <div><dt>{{ t('nfseValueLabel') }}</dt><dd class="num">{{ money(opened.value) }}</dd></div>
          <div v-if="opened.number"><dt>{{ t('nfseNumberLabel') }}</dt><dd class="num">{{ opened.number }}</dd></div>
          <div v-if="opened.emitter"><dt>{{ t('web.nfseDirect.emitter') }}</dt><dd data-testid="nfse-emitter-line">{{ partyLine(opened.emitter) }}</dd></div>
          <div v-if="opened.recipient"><dt>{{ t('web.nfseDirect.recipient') }}</dt><dd data-testid="nfse-recipient-line">{{ partyLine(opened.recipient) }}</dd></div>
          <div v-if="opened.accessKey"><dt>{{ t('web.nfseDirect.accessKey') }}</dt><dd class="num nfse-key" data-testid="nfse-key">{{ opened.accessKey }}</dd></div>
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
        <p v-if="panelNote && panelNote.id === opened.id" class="field-error" role="alert" data-testid="nfse-panel-note">{{ panelNote.text }}</p>
        <div v-if="canCancel(opened)" class="nfse-danger">
          <button type="button" class="link link--danger" :disabled="working" data-testid="nfse-cancel" @click="asking = opened.provider === 'direct' ? 'reason' : 'cancel'">{{ t('nfseCancelAction') }}</button>
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
    <ChoiceDialog
      v-if="asking === 'reason' && opened"
      :title="t('nfseCancelQuestion', { value: money(opened.value) })"
      :sub="t('web.nfseDirect.cancelWhy')"
      :choices="reasonChoices"
      @pick="cancelWithReason"
      @close="asking = null"
    />
    <IssueInvoiceDialog v-if="fixing" :order-ids="fixing.orderIds" :customer-id="fixing.customerId" :direct="fixing.provider === 'direct' || !!settings?.direct" @done="fixed" @close="fixing = null" />
  </div>
</template>
