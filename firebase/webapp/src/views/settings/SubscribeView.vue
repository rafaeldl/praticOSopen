<script setup lang="ts">
// Assinar plano (issue #664, docs/WEB_CHECKOUT.md): choose plan, monthly or
// yearly and how to pay, then pay on the Asaas page of Rafsoft. The plan turns
// on when Asaas confirms the payment (webhook → RevenueCat → subscription).
// Also where a web subscriber pays a pending charge, cancels, or takes the
// money back inside the 7-day guarantee. Owner and admin only (route + API).
import { computed, onMounted, ref, shallowRef, watch } from 'vue'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import ConfirmDialog from '@/components/orders/ConfirmDialog.vue'
import { t } from '@/i18n'
import { PLAN_TABLES, PLAN_TABLE_CURRENT_VERSION } from '@/generated/plan-table'
import { errorMessageKey } from '@/lib/api'
import { formatDate, formatMoney, formatNumber } from '@/lib/format'
import { session } from '@/lib/session'
import { loadCompany } from '@/lib/settings/data'
import { PLAN_NAME } from '@/lib/settings/model'
import { isValidTaxId, normalizeTaxId } from '@/lib/tax-id'
import { showToast as toast } from '@/lib/toast'
import {
  canBuy,
  cancelBilling,
  loadBilling,
  methodsFor,
  monthlyEquivalent,
  startCheckout,
  type WebBillingType,
  type WebBillingView,
  type WebCycle,
  type WebPlan,
} from '@/lib/settings/billing'
import '@/styles/settings.css'

const view = shallowRef<WebBillingView | null>(null)
const failed = ref(false)
const country = computed(() => session.company?.country)
const money = (value: number) => formatMoney(value, country.value)

const cycle = ref<WebCycle>('monthly')
const plan = ref<WebPlan>('pro')
const method = ref<WebBillingType>('CREDIT_CARD')
const name = ref('')
const taxId = ref('')
const email = ref('')
const tried = ref(false)
const sending = ref(false)
const sendError = ref('')
// Buying again after a cancelled or refunded web subscription.
const choosing = ref(false)
const asking = ref<'cancel' | 'refund' | null>(null)
const working = ref(false)

const offer = computed(() => view.value?.offer ?? null)
const sub = computed(() => view.value?.subscription ?? null)
const methods = computed(() => methodsFor(offer.value, cycle.value))
const showForm = computed(() => canBuy(view.value) && (!sub.value || sub.value.status === 'refunded' || choosing.value || sub.value.status === 'pending'))

watch(methods, (list) => {
  const first = list[0]
  if (first && !list.includes(method.value)) method.value = first
})

const ROWS = PLAN_TABLES[PLAN_TABLE_CURRENT_VERSION]
function planLine(id: WebPlan): string {
  const row = ROWS?.[id]
  if (!row) return ''
  const people = row.users < 0 ? t('web.billing.peopleUnlimited') : t('web.billing.people', { count: row.users })
  const orders = row.ordersPerMonth < 0 ? t('web.billing.ordersUnlimited') : t('web.billing.orders', { count: formatNumber(row.ordersPerMonth, country.value) })
  return `${people} · ${orders}`
}

function priceLine(prices: Partial<Record<WebCycle, number>>): string {
  const value = prices[cycle.value]
  if (value === undefined) return ''
  if (cycle.value === 'yearly') return t('web.billing.perYear', { price: money(value), monthly: money(monthlyEquivalent(value)) })
  return t('web.billing.perMonth', { price: money(value) })
}

const METHOD_TEXT: Record<WebBillingType, 'web.billing.methodCard' | 'web.billing.methodPix' | 'web.billing.methodBoleto'> = {
  CREDIT_CARD: 'web.billing.methodCard',
  PIX: 'web.billing.methodPix',
  BOLETO: 'web.billing.methodBoleto',
}

const nameError = computed(() => (tried.value && name.value.trim().length < 2 ? t('web.billing.nameRequired') : ''))
const taxIdError = computed(() => (tried.value && !isValidTaxId(normalizeTaxId(taxId.value)) ? t('web.billing.taxIdInvalid') : ''))
const emailError = computed(() => (tried.value && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.value.trim()) ? t('web.billing.emailInvalid') : ''))

const status = computed(() => {
  const current = sub.value
  if (!current) return ''
  const planName = PLAN_NAME[current.plan]
  const until = current.paidUntil ? formatDate(current.paidUntil, country.value) : ''
  if (current.status === 'pending') return t('web.billing.statusPending', { plan: planName })
  if (current.status === 'active') {
    const next = current.nextDueDate ? formatDate(`${current.nextDueDate}T12:00:00`, country.value) : until
    return t('web.billing.statusActive', { plan: planName, price: money(current.value), date: next })
  }
  if (current.status === 'cancelled') return t('web.billing.statusCancelled', { plan: planName, date: until })
  return t('web.billing.statusRefunded')
})

async function load() {
  failed.value = false
  view.value = null
  try {
    const [billing, company] = await Promise.all([loadBilling(), loadCompany().catch(() => null)])
    view.value = billing
    if (billing.subscription && billing.subscription.status !== 'refunded') {
      plan.value = billing.subscription.plan
      cycle.value = billing.offer?.cycles.includes(billing.subscription.cycle) ? billing.subscription.cycle : 'monthly'
    }
    if (company && !name.value) name.value = company.name ?? ''
    if (company && !email.value) email.value = company.email ?? ''
  } catch (error) {
    console.error('subscribe: load failed', error)
    failed.value = true
  }
}

async function pay() {
  tried.value = true
  sendError.value = ''
  if (nameError.value || taxIdError.value || emailError.value) return
  sending.value = true
  try {
    const { checkoutUrl } = await startCheckout({
      plan: plan.value,
      cycle: cycle.value,
      billingType: method.value,
      name: name.value.trim(),
      taxId: normalizeTaxId(taxId.value),
      email: email.value.trim(),
    })
    window.location.assign(checkoutUrl)
  } catch (error) {
    sendError.value = t(errorMessageKey(error))
    sending.value = false
  }
}

async function cancel(refund: boolean) {
  asking.value = null
  working.value = true
  try {
    await cancelBilling(refund)
    toast(t(refund ? 'web.billing.refundedToast' : 'web.billing.cancelledToast'))
    choosing.value = false
    await load()
  } catch (error) {
    toast(t(errorMessageKey(error)))
  } finally {
    working.value = false
  }
}

onMounted(load)
</script>

<template>
  <header class="page-head">
    <div>
      <h1 class="page-title" tabindex="-1" data-page-title>{{ t('web.billing.title') }}</h1>
      <p v-if="view && showForm && offer" class="page-sub" data-testid="billing-lead">{{ t('web.billing.lead', { days: offer.guaranteeDays }) }}</p>
    </div>
  </header>
  <div class="workspace">
    <div class="list-pane set-page">
      <LoadingState v-if="!view && !failed" />
      <ErrorState v-else-if="failed" :retry="load" />
      <template v-else-if="view">
        <p v-if="view.block === 'STORE_SUBSCRIPTION_ACTIVE'" class="set-block" data-testid="billing-store">{{ t('web.billing.storeNote') }}</p>
        <p v-else-if="!view.enabled && !sub" class="set-block" data-testid="billing-closed">{{ t('web.billing.closed') }}</p>

        <section v-if="sub && sub.status !== 'refunded'" class="set-section" aria-labelledby="billing-current" data-testid="billing-current">
          <h2 id="billing-current" class="set-h">{{ t('web.billing.yourSubscription') }}</h2>
          <p class="set-status" :data-status="sub.status">{{ status }}</p>
          <p v-if="sub.status === 'active'" class="sub">{{ t(METHOD_TEXT[sub.billingType]) }} · {{ t('web.billing.invoiceByEmail') }}</p>
          <div class="set-actions">
            <a v-if="sub.status === 'pending' && sub.checkoutUrl" :href="sub.checkoutUrl" class="btn btn--primary" data-testid="billing-pay-pending">{{ t('web.billing.payNow') }}</a>
            <button v-if="sub.refundEligible" type="button" class="btn" :disabled="working" data-testid="billing-refund" @click="asking = 'refund'">{{ t('web.billing.refund') }}</button>
            <button v-if="sub.status === 'active' || sub.status === 'pending'" type="button" class="btn btn--ghost set-danger" :disabled="working" data-testid="billing-cancel" @click="asking = 'cancel'">{{ t('web.billing.cancel') }}</button>
            <button v-if="sub.status === 'cancelled' && canBuy(view) && !choosing" type="button" class="btn" data-testid="billing-again" @click="choosing = true">{{ t('web.billing.subscribeAgain') }}</button>
          </div>
        </section>
        <p v-else-if="sub?.status === 'refunded'" class="set-block" data-testid="billing-refunded">{{ status }}</p>

        <form v-if="showForm && offer" class="set-section billing-form" novalidate data-testid="billing-form" @submit.prevent="pay">
          <fieldset v-if="offer.cycles.length > 1" class="billing-cycle">
            <legend class="set-h">{{ t('web.billing.cycleQuestion') }}</legend>
            <label v-for="item in offer.cycles" :key="item" class="check-row billing-pill">
              <input v-model="cycle" type="radio" name="billing-cycle" :value="item" :data-testid="`billing-cycle-${item}`" />
              <span>{{ t(item === 'monthly' ? 'web.billing.monthly' : 'web.billing.yearly') }}</span>
            </label>
          </fieldset>

          <fieldset>
            <legend class="set-h">{{ t('web.billing.planQuestion') }}</legend>
            <ul class="set-list">
              <li v-for="item in offer.plans" :key="item.plan">
                <label class="set-row billing-option" :data-testid="`billing-plan-${item.plan}`">
                  <input v-model="plan" type="radio" name="billing-plan" :value="item.plan" />
                  <span class="set-text">
                    <span class="who">{{ PLAN_NAME[item.plan] }}</span>
                    <span class="sub">{{ planLine(item.plan) }}</span>
                  </span>
                  <span class="set-end num">{{ priceLine(item.prices) }}</span>
                </label>
              </li>
            </ul>
          </fieldset>

          <fieldset>
            <legend class="set-h">{{ t('web.billing.methodQuestion') }}</legend>
            <ul class="set-list">
              <li v-for="item in methods" :key="item">
                <label class="set-row billing-option" :data-testid="`billing-method-${item}`">
                  <input v-model="method" type="radio" name="billing-method" :value="item" />
                  <span class="set-text"><span class="who">{{ t(METHOD_TEXT[item]) }}</span></span>
                </label>
              </li>
            </ul>
            <p v-if="cycle === 'monthly' && methods.length === 1 && methods[0] === 'CREDIT_CARD'" class="sub">{{ t('web.billing.monthlyCardOnly') }}</p>
          </fieldset>

          <fieldset class="billing-who">
            <legend class="set-h">{{ t('web.billing.whoQuestion') }}</legend>
            <label class="field-label" for="billing-name">{{ t('web.billing.name') }}</label>
            <input id="billing-name" v-model="name" class="field" autocomplete="organization" :aria-invalid="!!nameError" data-testid="billing-name" />
            <p v-if="nameError" class="field-error" role="alert">{{ nameError }}</p>
            <label class="field-label" for="billing-taxid">{{ t('web.billing.taxId') }}</label>
            <input id="billing-taxid" v-model="taxId" class="field" inputmode="numeric" :aria-invalid="!!taxIdError" data-testid="billing-taxid" />
            <p v-if="taxIdError" class="field-error" role="alert">{{ taxIdError }}</p>
            <label class="field-label" for="billing-email">{{ t('web.billing.email') }}</label>
            <input id="billing-email" v-model="email" class="field" type="email" autocomplete="email" :aria-invalid="!!emailError" data-testid="billing-email" />
            <p v-if="emailError" class="field-error" role="alert">{{ emailError }}</p>
            <p class="sub">{{ t('web.billing.invoiceHint') }}</p>
          </fieldset>

          <div class="set-block billing-guarantee" data-testid="billing-guarantee">
            <p class="set-h">{{ t('web.billing.guaranteeTitle', { days: offer.guaranteeDays }) }}</p>
            <p>{{ t('web.billing.guaranteeText', { days: offer.guaranteeDays }) }}</p>
          </div>

          <p v-if="sendError" class="field-error" role="alert" data-testid="billing-error">{{ sendError }}</p>
          <div class="set-actions">
            <button type="submit" class="btn btn--primary" :disabled="sending" data-testid="billing-pay">{{ sending ? t('web.billing.opening') : t('web.billing.goToPayment') }}</button>
          </div>
          <p class="sub">{{ t('web.billing.paymentHint') }}</p>
        </form>
      </template>
    </div>
  </div>

  <ConfirmDialog
    v-if="asking === 'cancel' && sub"
    :title="t('web.billing.cancelQuestion')"
    :body="sub.refundEligible ? t('web.billing.cancelBodyRefund') : t('web.billing.cancelBody', { date: sub.paidUntil ? formatDate(sub.paidUntil, country) : '' })"
    :confirm="t('web.billing.cancel')"
    :keep="t('web.billing.keep')"
    danger
    @confirm="cancel(false)"
    @close="asking = null"
  />
  <ConfirmDialog
    v-if="asking === 'refund' && sub"
    :title="t('web.billing.refundQuestion')"
    :body="t('web.billing.refundBody', { plan: PLAN_NAME[sub.plan] })"
    :confirm="t('web.billing.refund')"
    :keep="t('web.billing.keep')"
    danger
    @confirm="cancel(true)"
    @close="asking = null"
  />
</template>

<style scoped>
.billing-form { gap: 1.25rem; }
.billing-form fieldset { border: 0; margin: 0; padding: 0; min-width: 0; display: grid; gap: 0.4rem; }
.billing-cycle { grid-auto-flow: column; justify-content: start; gap: 0.5rem 1rem; }
.billing-option { cursor: pointer; }
.billing-option input, .billing-pill input { flex: none; width: 1.1rem; height: 1.1rem; accent-color: var(--color-accent); }
.billing-pill { min-height: 2.75rem; }
.billing-who .field-label { margin-top: 0.4rem; }
.billing-guarantee p { margin: 0; }
.set-status { margin: 0; font-weight: 600; }
</style>
