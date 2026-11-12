<script setup lang="ts">
// Plano (#725; plan.view, plan.header-status, plan.usage-levels, plan.open-limit):
// the same as the app (plan_screen.dart), from the same rule
// (src/lib/plan-overview.ts, docs/web-app/contract-cases/plan-overview.json):
// orders this month, people and CNPJs against the plan, one notice (80%, 100%,
// the month of grace, orders waiting, talk to us) and what the next plan adds.
// No assistant counter. Buying is in the phone app for now (#664): the screen
// says where.
import { computed, onMounted, ref, shallowRef } from 'vue'
import { ChevronRight } from '@lucide/vue'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import { t, type MessageKey } from '@/i18n'
import { formatDate, formatNumber } from '@/lib/format'
import { countEmitters } from '@/lib/nfse/data'
import { PLAN_FEATURE_NAME } from '@/lib/plan-features'
import { loadLimitsSwitch } from '@/lib/plan-limits'
import { planOverview, type OverviewResource, type OverviewRow, type PlanOverview } from '@/lib/plan-overview'
import { can, session } from '@/lib/session'
import { loadCompany } from '@/lib/settings/data'
import { PLAN_NAME, planSummary, type PlanSummary } from '@/lib/settings/model'
import '@/styles/settings.css'

const summary = shallowRef<PlanSummary | null>(null)
const overview = shallowRef<PlanOverview | null>(null)
const failed = ref(false)

const country = computed(() => session.company?.country)
// Who cannot change the plan is told who can (plan.non-admin-note), as the app.
const isAdmin = computed(() => session.role === 'owner' || session.role === 'admin')
const count = (value: number) => formatNumber(value, country.value)

const header = computed(() => {
  const plan = summary.value
  if (!plan) return ''
  const name = PLAN_NAME[plan.plan]
  const date = plan.expiresAt ? formatDate(plan.expiresAt, country.value) : null
  if (plan.state === 'paymentIssue') return t('planHeaderPaymentIssue', { plan: name })
  if (!date || plan.state === 'free') return name
  if (plan.state === 'courtesy') return t('planHeaderCourtesy', { plan: name, date })
  if (plan.state === 'renewsOn') return t('planHeaderRenews', { plan: name, date })
  return t('planHeaderValidUntil', { plan: name, date })
})

const TITLE: Record<OverviewResource, MessageKey> = { orders: 'planUsageOrders', people: 'planUsageTeam', cnpjs: 'planUsageCnpjs' }

const rowOf = (resource: OverviewResource) => overview.value?.rows.find((row) => row.resource === resource)

const notice = computed(() => {
  const kind = overview.value?.notice
  if (!kind) return null
  const orders = rowOf('orders')!
  const people = rowOf('people')!
  const limit = count(kind.startsWith('orders') ? orders.limit : people.limit)
  switch (kind) {
    case 'ordersNear':
      return t('planNoticeOrdersNear', { used: count(orders.used), limit })
    case 'ordersAtLimit':
      return t('planNoticeOrdersAtLimit', { limit })
    case 'ordersGrace':
      return t('planNoticeOrdersGrace', { limit })
    case 'ordersBlocked':
      return t('planNoticeOrdersBlocked', { limit })
    case 'ordersContactUs':
      return t('planNoticeOrdersContactUs', { limit })
    case 'peopleAtLimit':
      return t('planLimitTeam', { used: count(people.used), limit })
    case 'peopleContactUs':
      return t('planNoticePeopleContactUs', { limit })
  }
  return null
})

const reached = computed(() => {
  const kind = overview.value?.notice
  return !!kind && kind !== 'ordersNear'
})

function levelText(row: OverviewRow): string {
  if (row.level === 'atLimit' || row.level === 'over') return row.resource === 'people' ? t('planUsageAtLimitInvites') : t('planUsageAtLimit')
  if (row.level === 'near') return t('planUsageNearLimit')
  if (row.level === 'unlimited') return t('planUsageUnlimited')
  return ''
}

const valueText = (row: OverviewRow) => (row.level === 'unlimited' ? count(row.used) : t('planUsageOf', { used: count(row.used), limit: count(row.limit) }))
const linkOf = (row: OverviewRow) => (row.resource === 'people' && can('manageUsers') ? '/team' : undefined)

async function load() {
  failed.value = false
  summary.value = null
  overview.value = null
  try {
    const [company, enforced, cnpjs] = await Promise.all([
      loadCompany(),
      loadLimitsSwitch(),
      // Only who reads fiscalEmitters (owner, admin, manager) sees the CNPJs; a failure hides the row.
      countEmitters().catch(() => null),
    ])
    const now = new Date()
    const plan = planSummary(company.subscription, now)
    const result = planOverview({ subscription: company.subscription, people: plan.usage.users, cnpjs: cnpjs ?? 0, enforced, now })
    summary.value = plan
    overview.value = cnpjs === null ? { ...result, rows: result.rows.filter((row) => row.resource !== 'cnpjs') } : result
  } catch (error) {
    console.error('plan: load failed', error)
    failed.value = true
  }
}

onMounted(() => void load())
</script>

<template>
  <header class="page-head">
    <div>
      <h1 class="page-title" tabindex="-1" data-page-title>{{ t('planTitle') }}</h1>
      <p v-if="summary" class="page-sub set-plan-head" :class="{ 'set-plan-head--issue': summary.state === 'paymentIssue' }" data-testid="plan-header">{{ header }}</p>
    </div>
  </header>
  <div class="workspace">
    <div class="list-pane set-page">
      <LoadingState v-if="!overview && !failed" />
      <ErrorState v-else-if="failed" :retry="load" />
      <template v-else-if="overview">
        <div v-if="notice" class="set-block" :class="{ 'set-block--danger': reached }" data-testid="plan-limit" :data-notice="overview.notice">
          <p class="set-h">{{ t('planLimitLabel') }}</p>
          <p>{{ notice }}</p>
        </div>
        <section aria-labelledby="plan-usage" class="set-section">
          <h2 id="plan-usage" class="set-h">{{ t('planUsageSection') }}</h2>
          <ul class="set-list" data-testid="plan-usage">
            <li v-for="row in overview.rows" :key="row.resource" :data-usage="row.resource">
              <component :is="linkOf(row) ? 'RouterLink' : 'div'" :to="linkOf(row)" class="set-row">
                <span class="set-text">
                  <span class="who">{{ t(TITLE[row.resource]) }}</span>
                  <span v-if="levelText(row)" class="sub set-level" :class="{ 'set-level--limit': row.level === 'atLimit' || row.level === 'over' }">
                    <span v-if="row.level !== 'unlimited' && row.level !== 'ok'" class="dot" :class="row.level === 'near' ? 'dot--warning' : 'dot--danger'" aria-hidden="true"></span>
                    {{ levelText(row) }}
                  </span>
                </span>
                <span class="set-end num">{{ valueText(row) }}</span>
                <ChevronRight v-if="linkOf(row)" :size="18" aria-hidden="true" />
              </component>
            </li>
          </ul>
        </section>
        <section v-if="overview.next && overview.next.features.length" aria-labelledby="plan-next" class="set-section" data-testid="plan-next">
          <h2 id="plan-next" class="set-h">{{ t('planNextTitle', { plan: PLAN_NAME[overview.next.plan] }) }}</h2>
          <ul class="set-list">
            <li v-for="feature in overview.next.features" :key="feature" :data-feature="feature">
              <div class="set-row">
                <span class="set-text"><span class="who">{{ t(PLAN_FEATURE_NAME[feature]) }}</span></span>
              </div>
            </li>
          </ul>
        </section>
        <p v-if="isAdmin" class="role-note" data-testid="plan-where">{{ t('web.plan.readOnly') }}</p>
        <p v-else class="role-note" data-testid="plan-ask-admin">{{ t('askAdminToChangePlan') }}</p>
      </template>
    </div>
  </div>
</template>
