<script setup lang="ts">
// Plano (plan.view, plan.header-status, plan.usage-levels, plan.ai-usage,
// plan.open-limit): the plan in force and what the company uses, read only.
// Buying, prices and limits are the owner's decision: nothing to buy here.
// Usage comes from the counters the server keeps (subscription.usage), the
// assistant from GET /v1/app/ai/status. Team and checklists open only for who
// manages them.
import { computed, onMounted, ref, shallowRef } from 'vue'
import { ChevronRight } from '@lucide/vue'
import ErrorState from '@/components/ErrorState.vue'
import LoadingState from '@/components/LoadingState.vue'
import { t, type MessageKey } from '@/i18n'
import { formatDate, formatNumber } from '@/lib/format'
import { can, session } from '@/lib/session'
import { loadAiStatus, loadCompany, type AiStatus } from '@/lib/settings/data'
import { PLAN_NAME, planSummary, usageLevel, type PlanSummary, type UsageLevel } from '@/lib/settings/model'
import '@/styles/settings.css'

type Resource = 'ai' | 'team' | 'photos' | 'checklists'

const summary = shallowRef<PlanSummary | null>(null)
const failed = ref(false)
const ai = shallowRef<AiStatus | null>(null)
const aiFailed = ref(false)

const country = computed(() => session.company?.country)
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

interface Row {
  resource: Resource
  title: MessageKey
  used: number
  limit: number
  level: UsageLevel
  to?: string
}

const rows = computed<Row[]>(() => {
  const plan = summary.value
  if (!plan) return []
  const list: Row[] = []
  const usage = ai.value?.enabled ? ai.value.usage : undefined
  if (usage) list.push({ resource: 'ai', title: 'planUsageAi', used: usage.used, limit: usage.limit, level: usageLevel(usage.used, usage.limit) })
  list.push({ resource: 'team', title: 'planUsageTeam', used: plan.usage.users, limit: plan.limits.users, level: usageLevel(plan.usage.users, plan.limits.users), to: can('manageUsers') ? '/team' : undefined })
  list.push({ resource: 'photos', title: 'planUsagePhotos', used: plan.usage.photos, limit: plan.limits.photosPerMonth, level: usageLevel(plan.usage.photos, plan.limits.photosPerMonth) })
  list.push({
    resource: 'checklists',
    title: 'planUsageChecklists',
    used: plan.usage.checklists,
    limit: plan.limits.formTemplates,
    level: usageLevel(plan.usage.checklists, plan.limits.formTemplates),
    to: can('manageForms') ? '/checklists' : undefined,
  })
  return list
})

const reached = computed(() => rows.value.find((row) => row.level === 'atLimit') ?? null)

const LIMIT_TEXT: Record<Resource, MessageKey> = { ai: 'planLimitAi', team: 'planLimitTeam', photos: 'planLimitPhotos', checklists: 'planLimitChecklists' }

function levelText(row: Row): string {
  if (row.level === 'atLimit') return row.resource === 'team' ? t('planUsageAtLimitInvites') : t('planUsageAtLimit')
  if (row.level === 'near') return t('planUsageNearLimit')
  if (row.level === 'unlimited') return t('planUsageUnlimited')
  return ''
}

const valueText = (row: Row) => (row.level === 'unlimited' ? count(row.used) : t('planUsageOf', { used: count(row.used), limit: count(row.limit) }))

async function load() {
  failed.value = false
  summary.value = null
  try {
    const company = await loadCompany()
    summary.value = planSummary(company.subscription, new Date())
  } catch (error) {
    console.error('plan: load failed', error)
    failed.value = true
  }
}

async function loadAi() {
  aiFailed.value = false
  try {
    ai.value = await loadAiStatus()
  } catch (error) {
    // The app hides the row on a failure; here it says so.
    console.warn('plan: assistant status failed', error)
    aiFailed.value = true
  }
}

onMounted(() => {
  void load()
  void loadAi()
})
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
      <LoadingState v-if="!summary && !failed" />
      <ErrorState v-else-if="failed" :retry="load" />
      <template v-else-if="summary">
        <div v-if="reached" class="set-block set-block--danger" data-testid="plan-limit">
          <p class="set-h">{{ t('planLimitLabel') }}</p>
          <p>{{ t(LIMIT_TEXT[reached.resource], { used: count(reached.used), limit: count(reached.limit) }) }}</p>
        </div>
        <section aria-labelledby="plan-usage" class="set-section">
          <h2 id="plan-usage" class="set-h">{{ t('planUsageSection') }}</h2>
          <ul class="set-list" data-testid="plan-usage">
            <li v-for="row in rows" :key="row.resource" :data-usage="row.resource">
              <component :is="row.to ? 'RouterLink' : 'div'" :to="row.to" class="set-row">
                <span class="set-text">
                  <span class="who">{{ t(row.title) }}</span>
                  <span v-if="levelText(row)" class="sub set-level" :class="{ 'set-level--limit': row.level === 'atLimit' }">
                    <span v-if="row.level === 'atLimit' || row.level === 'near'" class="dot" :class="row.level === 'atLimit' ? 'dot--danger' : 'dot--warning'" aria-hidden="true"></span>
                    {{ levelText(row) }}
                  </span>
                </span>
                <span class="set-end num">{{ valueText(row) }}</span>
                <ChevronRight v-if="row.to" :size="18" aria-hidden="true" />
              </component>
            </li>
          </ul>
          <p v-if="aiFailed" class="sub" role="status" data-testid="plan-ai-failed">
            {{ t('web.plan.aiFailed') }} <button type="button" class="link" @click="loadAi">{{ t('web.tryAgain') }}</button>
          </p>
        </section>
        <p class="role-note">{{ t('web.plan.readOnly') }}</p>
      </template>
    </div>
  </div>
</template>
